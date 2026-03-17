# Especificación técnica: Aprobación de descuentos en órdenes de venta

**Tipo:** Flujo de aprobación
**Complejidad:** Media-Alta
**Módulos afectados:** `sale`
**Versión Odoo:** 19.0
**Módulo a crear:** `sale_discount_approval`

---

## Resumen ejecutivo

Las órdenes de venta con alguna línea que supere el 20% de descuento deben pasar por un flujo de aprobación antes de poderse confirmar. Se agrega un campo `approval_state` independiente al `state` estándar de `sale.order`. El vendedor solicita aprobación; el gerente aprueba o rechaza con nota. Solo tras aprobación puede ejecutarse `action_confirm()`. `stock` y `account` no se modifican: el bloqueo opera en el único punto de entrada (`action_confirm()`).

---

## Módulo a crear

- **Nombre técnico:** `sale_discount_approval`
- **Depende de:** `sale`
- **Licencia:** LGPL-3
- **Versión:** `19.0.1.0.0`

> `stock` y `account` **no se modifican ni se declaran como dependencias.** El bloqueo en `action_confirm()` impide la creación del picking y de la futura factura sin que esos módulos necesiten saber nada del flujo de aprobación.

---

## Árbol de directorio

```
sale_discount_approval/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   └── sale_order.py              # Campos + métodos + override action_confirm
├── security/
│   ├── ir.model.access.csv        # No necesario (no hay modelo nuevo)
│   └── sale_discount_approval_security.xml   # Grupo group_discount_approver
├── views/
│   └── sale_order_views.xml       # Barra de estado secundaria + botones condicionales
└── data/
    └── mail_template_data.xml     # Plantilla de notificación al rechazar
```

---

## Cambios por modelo

### `sale.order` — Campos nuevos

| Campo               | Tipo        | Atributos                                             | Propósito                                        |
|---------------------|-------------|-------------------------------------------------------|--------------------------------------------------|
| `approval_state`    | `Selection` | `default='not_required'`, `copy=False`, `tracking=True` | Estado del flujo de aprobación                 |
| `requires_approval` | `Boolean`   | `compute`, `store=True`, `@api.depends(order_line.discount)` | True si alguna línea supera el 20%        |
| `approval_user_id`  | `Many2one`  | `res.users`, `readonly=True`, `copy=False`, `tracking=True` | Quién aprobó                              |
| `rejection_reason`  | `Text`      | `copy=False`, `tracking=True`                         | Motivo del rechazo (registrado en chatter)       |

**Valores de `approval_state`:**

```python
[
    ('not_required', 'No requerida'),
    ('pending',      'Pendiente de aprobación'),
    ('approved',     'Aprobada'),
    ('rejected',     'Rechazada'),
]
```

**Diagrama de estados del flujo de aprobación** (paralelo al `state` estándar):

```
                    requires_approval = False
                  ┌─────────────────────────────────┐
                  │                                  │
[not_required] ───┤  action_request_approval()       │
                  │  (solo si requires_approval=True) │
                  └──────────► [pending]             │
                                    │                │
                           ┌────────┴────────┐       │
                    approve │                │ reject │
                           ▼                ▼        │
                       [approved]       [rejected]   │
                           │                │        │
                  action_confirm()    Notifica vendedor
                           │          → vuelve a not_required
                           ▼          si vendedor ajusta descuentos
                    [sale.order state='sale']
```

---

## Código Python completo

### `models/sale_order.py`

```python
# © 2026 — sale_discount_approval
# License LGPL-3.0 or later (https://www.gnu.org/licenses/lgpl).

from odoo import _, api, fields, models
from odoo.exceptions import UserError, ValidationError


DISCOUNT_THRESHOLD = 20.0  # Porcentaje máximo sin aprobación


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # ── Campos de aprobación ──────────────────────────────────────────────────

    approval_state = fields.Selection(
        selection=[
            ('not_required', 'No requerida'),
            ('pending',      'Pendiente de aprobación'),
            ('approved',     'Aprobada'),
            ('rejected',     'Rechazada'),
        ],
        string='Estado de aprobación',
        default='not_required',
        copy=False,
        tracking=True,
        help='Estado del flujo de aprobación de descuentos. '
             'Independiente del estado estándar de la orden.',
    )

    requires_approval = fields.Boolean(
        string='Requiere aprobación',
        compute='_compute_requires_approval',
        store=True,
        help='True si alguna línea de la orden tiene descuento > 20%.',
    )

    approval_user_id = fields.Many2one(
        comodel_name='res.users',
        string='Aprobado por',
        readonly=True,
        copy=False,
        tracking=True,
    )

    rejection_reason = fields.Text(
        string='Motivo de rechazo',
        copy=False,
        tracking=True,
    )

    # ── Computados ────────────────────────────────────────────────────────────

    @api.depends('order_line.discount')
    def _compute_requires_approval(self):
        for order in self:
            order.requires_approval = any(
                line.discount > DISCOUNT_THRESHOLD
                for line in order.order_line
            )

    # ── Onchange: resetear approval_state si ya no se requiere aprobación ────

    @api.onchange('order_line')
    def _onchange_order_line_discount(self):
        """Si el vendedor reduce los descuentos por debajo del umbral,
        resetear el estado de aprobación para que pueda confirmar sin aprobación."""
        for order in self:
            if not order.requires_approval and order.approval_state in ('pending', 'rejected'):
                order.approval_state = 'not_required'
                order.rejection_reason = False

    # ── Override action_confirm ───────────────────────────────────────────────

    def action_confirm(self):
        """Bloquea la confirmación si la orden requiere aprobación y no ha sido aprobada."""
        for order in self:
            if order.requires_approval and order.approval_state != 'approved':
                raise UserError(_(
                    'No se puede confirmar la orden %(name)s.\n\n'
                    'Una o más líneas tienen descuento superior al %(threshold)s%%. '
                    'La orden debe ser aprobada por el Gerente de Ventas antes de confirmar.\n\n'
                    'Estado actual: %(state)s',
                    name=order.name,
                    threshold=int(DISCOUNT_THRESHOLD),
                    state=dict(order._fields['approval_state'].selection).get(order.approval_state, ''),
                ))
        return super().action_confirm()

    # ── Acciones del flujo de aprobación ─────────────────────────────────────

    def action_request_approval(self):
        """El vendedor solicita aprobación al gerente.
        Solo disponible si requires_approval=True y state in ('draft', 'sent').
        """
        self.ensure_one()
        if not self.requires_approval:
            raise UserError(_('Esta orden no requiere aprobación de descuentos.'))
        if self.state not in ('draft', 'sent'):
            raise UserError(_('Solo se puede solicitar aprobación en borradores o cotizaciones enviadas.'))

        self.write({'approval_state': 'pending'})
        # Notificar a todos los usuarios del grupo Gerente de Ventas
        approvers = self.env.ref('sale_discount_approval.group_discount_approver').users
        self.message_post(
            body=_(
                '<b>Aprobación de descuentos solicitada</b><br/>'
                'El vendedor <b>%(user)s</b> solicita aprobación para la orden <b>%(name)s</b>.<br/>'
                'Líneas con descuento &gt; %(threshold)s%%:<br/>'
                '%(lines)s',
                user=self.env.user.name,
                name=self.name,
                threshold=int(DISCOUNT_THRESHOLD),
                lines='<br/>'.join(
                    f'• {line.product_id.display_name}: {line.discount}%%'
                    for line in self.order_line
                    if line.discount > DISCOUNT_THRESHOLD
                ),
            ),
            partner_ids=approvers.mapped('partner_id').ids,
        )

    def action_approve(self):
        """El Gerente de Ventas aprueba la orden.
        Solo disponible para usuarios del grupo group_discount_approver.
        """
        self.ensure_one()
        if self.approval_state != 'pending':
            raise UserError(_('Solo se pueden aprobar órdenes en estado "Pendiente de aprobación".'))

        self.write({
            'approval_state': 'approved',
            'approval_user_id': self.env.uid,
            'rejection_reason': False,
        })
        self.message_post(
            body=_(
                '<b>Descuentos aprobados</b><br/>'
                'Aprobado por <b>%(approver)s</b>. '
                'El vendedor puede ahora confirmar la orden.',
                approver=self.env.user.name,
            ),
            partner_ids=self.user_id.partner_id.ids,  # Notificar al vendedor
        )

    def action_reject(self):
        """El Gerente de Ventas rechaza la orden y notifica al vendedor.
        Abre un wizard para ingresar el motivo de rechazo.
        """
        self.ensure_one()
        if self.approval_state != 'pending':
            raise UserError(_('Solo se pueden rechazar órdenes en estado "Pendiente de aprobación".'))

        return {
            'type': 'ir.actions.act_window',
            'name': _('Motivo de rechazo'),
            'res_model': 'sale.discount.approval.reject.wizard',
            'view_mode': 'form',
            'target': 'new',
            'context': {'default_order_id': self.id},
        }

    def _action_do_reject(self, reason):
        """Llamado desde el wizard de rechazo. Aplica el rechazo con nota."""
        self.ensure_one()
        if not reason:
            raise ValidationError(_('El motivo de rechazo no puede estar vacío.'))

        self.write({
            'approval_state': 'rejected',
            'rejection_reason': reason,
            'approval_user_id': False,
        })
        self.message_post(
            body=_(
                '<b>Descuentos rechazados</b><br/>'
                '<b>Motivo:</b> %(reason)s<br/><br/>'
                'Por favor ajusta los descuentos o solicita nuevamente la aprobación.',
                reason=reason,
            ),
            partner_ids=self.user_id.partner_id.ids,  # Mención al vendedor
        )
```

---

## Wizard de rechazo

El rechazo requiere un motivo obligatorio. Se usa un wizard minimal para forzar el ingreso del texto antes de ejecutar la acción.

### `models/sale_discount_approval_reject_wizard.py`

```python
from odoo import _, api, fields, models
from odoo.exceptions import ValidationError


class SaleDiscountApprovalRejectWizard(models.TransientModel):
    _name = 'sale.discount.approval.reject.wizard'
    _description = 'Wizard — Motivo de rechazo de aprobación de descuentos'

    order_id = fields.Many2one('sale.order', required=True)
    reason = fields.Text(string='Motivo de rechazo', required=True)

    def action_confirm_reject(self):
        self.ensure_one()
        self.order_id._action_do_reject(self.reason)
        return {'type': 'ir.actions.act_window_close'}
```

### Vista del wizard — `views/sale_order_views.xml` (sección adicional)

```xml
<record id="view_sale_discount_approval_reject_wizard_form" model="ir.ui.view">
    <field name="name">sale.discount.approval.reject.wizard.form</field>
    <field name="model">sale.discount.approval.reject.wizard</field>
    <field name="arch" type="xml">
        <form string="Motivo de rechazo">
            <field name="order_id" invisible="1"/>
            <field name="reason"
                   placeholder="Explica por qué se rechaza la aprobación..."
                   nolabel="1"/>
            <footer>
                <button name="action_confirm_reject"
                        string="Rechazar orden"
                        type="object"
                        class="btn-danger"/>
                <button string="Cancelar" class="btn-secondary" special="cancel"/>
            </footer>
        </form>
    </field>
</record>
```

---

## Seguridad

### `security/sale_discount_approval_security.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="group_discount_approver" model="res.groups">
        <field name="name">Gerente de Descuentos</field>
        <field name="category_id" ref="base.module_category_sales_sales"/>
        <field name="implied_ids" eval="[(4, ref('sales_team.group_sale_manager'))]"/>
    </record>
</odoo>
```

> El grupo `group_discount_approver` implica (`implied_ids`) al `group_sale_manager` — el gerente de descuentos siempre tendrá también permisos de gerente de ventas. No al revés: un gerente de ventas estándar no puede aprobar descuentos a menos que se le asigne explícitamente el nuevo grupo.

### `security/ir.model.access.csv`

```csv
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
access_sale_discount_approval_reject_wizard,sale.discount.approval.reject.wizard,model_sale_discount_approval_reject_wizard,,1,1,1,1
```

(El wizard de transiente es accesible para todos — el control de acceso ocurre en `action_reject` via la verificación de `approval_state`.)

---

## Vistas — XML

### `views/sale_order_views.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>

    <!-- 1. Barra de estado secundaria + botones de aprobación -->
    <record id="view_order_form_inherit_discount_approval" model="ir.ui.view">
        <field name="name">sale.order.form.inherit.discount.approval</field>
        <field name="model">sale.order</field>
        <field name="inherit_id" ref="sale.view_order_form"/>
        <field name="arch" type="xml">

            <!-- Botones en la cabecera -->
            <xpath expr="//header/button[@name='action_confirm']" position="before">

                <!-- Vendedor: solicitar aprobación -->
                <button name="action_request_approval"
                        string="Solicitar aprobación"
                        type="object"
                        class="btn-warning"
                        invisible="not requires_approval
                                   or approval_state not in ('not_required', 'rejected')
                                   or state not in ('draft', 'sent')"/>

                <!-- Gerente: aprobar -->
                <button name="action_approve"
                        string="Aprobar descuentos"
                        type="object"
                        class="btn-success"
                        groups="sale_discount_approval.group_discount_approver"
                        invisible="approval_state != 'pending'"/>

                <!-- Gerente: rechazar -->
                <button name="action_reject"
                        string="Rechazar"
                        type="object"
                        class="btn-danger"
                        groups="sale_discount_approval.group_discount_approver"
                        invisible="approval_state != 'pending'"/>

            </xpath>

            <!-- Bloquear el botón "Confirmar" si requiere aprobación y no está aprobada -->
            <xpath expr="//header/button[@name='action_confirm']" position="attributes">
                <attribute name="invisible">
                    (requires_approval and approval_state != 'approved') or state != 'draft'
                </attribute>
            </xpath>

            <!-- Barra de estado secundaria de aprobación -->
            <xpath expr="//header/field[@name='state']" position="after">
                <field name="approval_state"
                       widget="statusbar"
                       statusbar_visible="not_required,pending,approved,rejected"
                       invisible="not requires_approval and approval_state == 'not_required'"/>
            </xpath>

            <!-- Banner de advertencia cuando está pendiente -->
            <xpath expr="//sheet" position="before">
                <div class="alert alert-warning mb-0"
                     role="alert"
                     invisible="approval_state != 'pending'">
                    <strong>Pendiente de aprobación.</strong>
                    Esta orden contiene líneas con descuento &gt;
                    <t t-esc="'%d%%' % 20"/> y requiere la aprobación del Gerente de Descuentos.
                </div>
                <div class="alert alert-danger mb-0"
                     role="alert"
                     invisible="approval_state != 'rejected'">
                    <strong>Aprobación rechazada.</strong>
                    <t t-if="rejection_reason">
                        Motivo: <t t-esc="rejection_reason"/>
                    </t>
                    Ajusta los descuentos o solicita nueva aprobación.
                </div>
                <div class="alert alert-success mb-0"
                     role="alert"
                     invisible="approval_state != 'approved'">
                    <strong>Descuentos aprobados</strong> por
                    <t t-esc="approval_user_id.name"/>.
                </div>
            </xpath>

            <!-- Sección de información de aprobación en pestaña "Otra información" -->
            <xpath expr="//page[@name='other_information']//group[last()]" position="after">
                <group string="Aprobación de descuentos"
                       invisible="not requires_approval and approval_state == 'not_required'">
                    <field name="requires_approval"/>
                    <field name="approval_state"/>
                    <field name="approval_user_id"
                           invisible="approval_state not in ('approved',)"/>
                    <field name="rejection_reason"
                           invisible="approval_state != 'rejected'"/>
                </group>
            </xpath>

        </field>
    </record>

    <!-- 2. Vista del wizard de rechazo -->
    <record id="view_sale_discount_approval_reject_wizard_form" model="ir.ui.view">
        <field name="name">sale.discount.approval.reject.wizard.form</field>
        <field name="model">sale.discount.approval.reject.wizard</field>
        <field name="arch" type="xml">
            <form string="Motivo de rechazo">
                <field name="order_id" invisible="1"/>
                <field name="reason"
                       placeholder="Explica por qué se rechazan los descuentos..."
                       nolabel="1"/>
                <footer>
                    <button name="action_confirm_reject"
                            string="Rechazar orden"
                            type="object"
                            class="btn-danger"/>
                    <button string="Cancelar" class="btn-secondary" special="cancel"/>
                </footer>
            </form>
        </field>
    </record>

</odoo>
```

---

## `__manifest__.py`

```python
{
    'name': 'Sale — Aprobación de descuentos',
    'version': '19.0.1.0.0',
    'category': 'Sales/Sales',
    'summary': 'Flujo de aprobación para órdenes de venta con descuentos superiores al 20%',
    'author': 'Custom',
    'license': 'LGPL-3',
    'depends': ['sale'],
    'data': [
        'security/sale_discount_approval_security.xml',
        'security/ir.model.access.csv',
        'views/sale_order_views.xml',
    ],
    'installable': True,
    'auto_install': False,
}
```

---

## Flujo completo de datos

```
[Cotización — state='draft']
        │
        │  El vendedor agrega línea con discount > 20%
        ▼
requires_approval = True  (compute, store=True)
approval_state = 'not_required'
        │
        │  Vendedor hace clic en "Solicitar aprobación"
        ▼
approval_state = 'pending'
message_post() → notifica a todos los usuarios de group_discount_approver
        │
        ├──────────────────────────────────────────────┐
        │ Gerente: "Aprobar descuentos"                │ Gerente: "Rechazar"
        ▼                                              ▼
approval_state = 'approved'                  wizard pide motivo
approval_user_id = gerente                            │
message_post() → notifica vendedor           approval_state = 'rejected'
        │                                    rejection_reason = motivo
        │  Vendedor confirma                 message_post() → notifica vendedor
        ▼                                            │
action_confirm()                             Vendedor ajusta descuentos
    super() → state='sale'                           │
        │                                   requires_approval vuelve a False
        ▼                                   (si discount <= 20% en todas las líneas)
[stock.picking generado]                    approval_state → 'not_required'
        │                                            │
        ▼                                   Vendedor confirma directamente
[account.move eventual]                     action_confirm() → sin bloqueo
```

---

## Casos límite

| Escenario                                                          | Comportamiento esperado                                                      |
|--------------------------------------------------------------------|------------------------------------------------------------------------------|
| Vendedor reduce descuento a ≤20% mientras está en `pending`        | `requires_approval` → False via `@api.depends`; `approval_state` se resetea via `_onchange_order_line_discount` en UI; en DB se actualiza al guardar |
| Gerente aprueba y luego vendedor aumenta descuento otra vez        | `requires_approval` vuelve a True, `approval_state` queda `approved` — **Riesgo R-03**: necesita lógica adicional para invalidar aprobación |
| Orden con descuento=0 en todas las líneas                          | `requires_approval=False`, `approval_state='not_required'`, botón "Solicitar" invisible, `action_confirm()` sin bloqueo |
| `action_confirm()` llamado por código (sin UI), sin aprobación     | Lanza `UserError` igual — el bloqueo está en el método, no en la vista      |
| Multi-empresa: un gerente de empresa A aprueba orden de empresa B  | El grupo `group_discount_approver` es global. Si se requiere restricción por empresa, usar `ir.rule` adicional (fuera de alcance inicial) |
| Orden duplicada (`copy()`)                                         | `approval_state`, `approval_user_id`, `rejection_reason` tienen `copy=False` → reset a `not_required` en la copia |
| Descuento exactamente igual a 20%                                  | `discount > 20.0` — el 20% exacto NO requiere aprobación (umbral estricto)  |

---

## Puntos de riesgo

| ID   | Riesgo                                                                               | Probabilidad | Impacto | Mitigación                                                                                  |
|------|--------------------------------------------------------------------------------------|:------------:|:-------:|---------------------------------------------------------------------------------------------|
| R-01 | `_onchange_order_line_discount` solo se ejecuta en UI, no al editar por código/API  | Alta         | Medio   | Documentar que `approval_state` debe resetearse manualmente si se editan descuentos por API. Alternativamente, agregar un `@api.constrains` en `action_confirm` que revalide |
| R-02 | El xpath sobre `button[@name='action_confirm']` puede romper si otro módulo ya modificó ese botón | Media | Bajo | Verificar con debug view antes de instalar. Usar xpath más específico si hay conflicto |
| R-03 | Gerente aprueba → vendedor aumenta descuento → `requires_approval` vuelve True pero `approval_state` queda `approved` | Media | Alto | Agregar `@api.depends('order_line.discount')` override que invalide la aprobación si `approval_state='approved'` y cambian los descuentos — **recomendado para v1.1** |
| R-04 | Notificaciones de chatter pueden saturar al gerente si hay muchas órdenes pendientes | Baja         | Bajo    | Considerar en v1.1 una vista de aprobaciones pendientes (lista filtrada) en lugar de solo notificaciones |
| R-05 | El wizard de rechazo (`TransientModel`) requiere acceso `ir.model.access.csv` | Alta | Bajo  | Incluido en el spec — el CSV ya cubre el modelo del wizard                                  |

---

## Checklist de aceptación técnica

Basado en los criterios de `docs/test-cases.md`:

- [ ] El campo `state` de `sale.order` **nunca se modifica directamente** en este módulo
- [ ] `approval_state` es independiente: puede ser `pending` con `state='draft'`
- [ ] El botón "Solicitar aprobación" solo visible si `requires_approval == True` y `state in ('draft', 'sent')`
- [ ] El botón "Aprobar" solo visible para `group_discount_approver`
- [ ] Al rechazar: se registra `rejection_reason` en chatter con notificación al vendedor (`user_id.partner_id`)
- [ ] Al aprobar: el vendedor puede llamar `action_confirm()` normalmente
- [ ] Si el vendedor reduce descuentos a ≤20%, `requires_approval` vuelve a False (via `@api.depends`) y puede confirmar sin aprobación
- [ ] Flujo completo probado: solicitar → rechazar → ajustar descuento → confirmar directo
- [ ] `action_confirm()` llama a `super()` después de la validación
- [ ] El wizard de rechazo tiene entrada en `ir.model.access.csv`
- [ ] Campos con `copy=False`: `approval_state`, `approval_user_id`, `rejection_reason`
- [ ] Descuento exactamente igual al umbral (20%) **no** requiere aprobación (`>`, no `>=`)

---

## Complejidad: Media-Alta

**Justificación:**

| Elemento                        | Cantidad |
|---------------------------------|:--------:|
| Modelos extendidos              | 1        |
| Modelos nuevos (TransientModel) | 1 (wizard) |
| Campos nuevos                   | 4        |
| Overrides de método             | 1 (`action_confirm`) |
| Métodos nuevos                  | 4 (`action_request_approval`, `action_approve`, `action_reject`, `_action_do_reject`) |
| Computados con `store=True`     | 1        |
| Vistas extendidas               | 1 (+ wizard form) |
| Grupos de seguridad nuevos      | 1        |
| `mail.thread` (chatter)         | Sí (ya en `sale.order`) |

La complejidad viene del **flujo de estados paralelo** y de las múltiples condiciones de visibilidad en la UI. El código es moderado en volumen pero requiere un diseño cuidadoso para no interferir con el `state` estándar.

**Estimación:** 1.5 días de desarrollo + 1 día de pruebas de flujo completo (incluyendo casos límite de onchange).
