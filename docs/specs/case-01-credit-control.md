# Especificación técnica: Control de crédito en ventas

**Versión Odoo:** 19
**Tipo:** Validación de flujo + Flujo de excepción
**Complejidad:** Baja
**Módulos afectados:** `sale`, `account`
**Generado con:** `/odoo-requirement-analyst` — Case 01

---

## Resumen ejecutivo

Se extiende `sale.order` para bloquear la confirmación de órdenes cuando el cliente tiene facturas de cliente vencidas por más de 30 días. El bloqueo muestra el monto total vencido. Un usuario con el rol **Gerente de Crédito** puede otorgar una excepción documentada directamente en la orden, tras lo cual el vendedor puede confirmarla normalmente. No se crea un flujo de estados nuevo ni se modifica `sale.order.state`.

---

## Análisis de módulos

### Cadena de datos

```
sale.order
    ├── partner_id → res.partner
    │       └── commercial_partner_id   ← agrupa todos los contactos del cliente
    │
    └── action_confirm()
            ↓ consulta
        account.move
            ├── move_type in ('out_invoice', 'out_refund')
            ├── state = 'posted'
            ├── payment_state in ('not_paid', 'partial')
            ├── invoice_date_due < hoy - 30 días
            ├── company_id = orden.company_id
            └── partner_id.commercial_partner_id = cliente.commercial_partner_id
                    ↓
            SUM(amount_residual) → credit_overdue_amount
```

### Por qué `action_confirm()` y no otro método

- Es el único punto donde `state` pasa de `draft/sent` → `sale`
- Es **previo** a la creación del `stock.picking` y posterior facturación
- Si el bloqueo se pusiera después, ya habría entrega generada y habría que revertirla

### Por qué no se usa `@api.constrains`

Las constraints se ejecutan en cada `write()`, incluyendo modificaciones menores del formulario. Bloquear con constraint generaría errores al guardar cambios no relacionados con la confirmación. El override de `action_confirm()` es quirúrgico: solo bloquea en el momento correcto.

---

## Módulo a crear

- **Nombre técnico:** `sale_credit_control`
- **Versión:** `19.0.1.0.0`
- **Depende de:** `sale`, `account`
- **Licencia:** LGPL-3

---

## Cambios por modelo

### `sale.order` (hereda de `sale.order`)

#### Campos nuevos

| Campo                    | Tipo      | Req. | Default | Descripción                                               |
|--------------------------|-----------|:----:|---------|-----------------------------------------------------------|
| `credit_overdue_amount`  | Monetary  | —    | 0.0     | Monto vencido >30 días del cliente (computado, store=False)|
| `credit_currency_id`     | Many2one  | —    | —       | Moneda para `credit_overdue_amount` (related de company)  |
| `credit_exception`       | Boolean   | —    | False   | True si un Gerente de Crédito otorgó excepción            |
| `credit_exception_note`  | Text      | —    | —       | Justificación obligatoria de la excepción                 |
| `credit_approver_id`     | Many2one  | —    | —       | Usuario que otorgó la excepción (res.users, readonly)     |
| `credit_approved_on`     | Datetime  | —    | —       | Fecha y hora de la excepción (readonly)                   |

#### Implementación Python completa

```python
# models/sale_order.py
from datetime import timedelta
from odoo import models, fields, api, _
from odoo.exceptions import UserError, ValidationError


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # ── Campos de crédito ────────────────────────────────────────────────────

    credit_overdue_amount = fields.Monetary(
        string='Deuda vencida del cliente',
        currency_field='credit_currency_id',
        compute='_compute_credit_overdue_amount',
        store=False,   # Siempre en tiempo real; no tiene sentido almacenarlo
        help='Total de facturas de cliente vencidas más de 30 días.',
    )
    credit_currency_id = fields.Many2one(
        related='company_id.currency_id',
        string='Moneda',
    )
    credit_exception = fields.Boolean(
        string='Excepción de crédito autorizada',
        default=False,
        copy=False,
        tracking=True,
    )
    credit_exception_note = fields.Text(
        string='Justificación de excepción',
        copy=False,
        tracking=True,
    )
    credit_approver_id = fields.Many2one(
        'res.users',
        string='Autorizado por',
        readonly=True,
        copy=False,
        tracking=True,
    )
    credit_approved_on = fields.Datetime(
        string='Fecha de autorización',
        readonly=True,
        copy=False,
    )

    # ── Compute ──────────────────────────────────────────────────────────────

    @api.depends('partner_id', 'company_id')
    def _compute_credit_overdue_amount(self):
        today = fields.Date.today()
        cutoff = today - timedelta(days=30)
        for order in self:
            if not order.partner_id:
                order.credit_overdue_amount = 0.0
                continue
            commercial = order.partner_id.commercial_partner_id
            # Buscar facturas de cliente vencidas (out_invoice) o notas
            # de crédito pendientes (out_refund) del mismo cliente comercial
            moves = self.env['account.move'].search([
                ('partner_id', 'child_of', commercial.id),
                ('move_type', 'in', ('out_invoice', 'out_refund')),
                ('state', '=', 'posted'),
                ('payment_state', 'in', ('not_paid', 'partial')),
                ('invoice_date_due', '<', cutoff),
                ('company_id', '=', order.company_id.id),
            ])
            # amount_residual es positivo en facturas y negativo en NC;
            # la suma da el neto real vencido
            order.credit_overdue_amount = sum(moves.mapped('amount_residual'))

    # ── Acciones ─────────────────────────────────────────────────────────────

    def action_confirm(self):
        """
        Override del método de confirmación.
        Bloquea si el cliente tiene deuda vencida > 30 días
        y no hay excepción de crédito autorizada.
        """
        for order in self:
            if order.credit_overdue_amount > 0 and not order.credit_exception:
                raise UserError(_(
                    'No se puede confirmar la orden %(name)s.\n\n'
                    'El cliente %(partner)s tiene %(amount)s en facturas vencidas '
                    'por más de 30 días.\n\n'
                    'Contacte a un Gerente de Crédito para obtener una excepción.',
                    name=order.name,
                    partner=order.partner_id.name,
                    amount=order.currency_id.format(order.credit_overdue_amount),
                ))
        return super().action_confirm()

    def action_grant_credit_exception(self):
        """
        Otorga excepción de crédito.
        Solo ejecutable por usuarios con grupo_credit_manager.
        Requiere nota de justificación.
        """
        self.ensure_one()
        if not self.credit_exception_note:
            raise ValidationError(_(
                'Debe ingresar una justificación para otorgar la excepción de crédito.'
            ))
        self.write({
            'credit_exception': True,
            'credit_approver_id': self.env.uid,
            'credit_approved_on': fields.Datetime.now(),
        })
        self.message_post(
            body=_(
                '<b>Excepción de crédito autorizada</b><br/>'
                'Autorizado por: %(user)s<br/>'
                'Justificación: %(note)s',
                user=self.env.user.name,
                note=self.credit_exception_note,
            ),
            message_type='comment',
            subtype_xmlid='mail.mt_note',
        )

    def action_revoke_credit_exception(self):
        """
        Revoca la excepción de crédito (por si se necesita auditar o corregir).
        Solo para Gerente de Crédito.
        """
        self.ensure_one()
        self.write({
            'credit_exception': False,
            'credit_approver_id': False,
            'credit_approved_on': False,
        })
        self.message_post(
            body=_('Excepción de crédito revocada por %s.', self.env.user.name),
            message_type='comment',
            subtype_xmlid='mail.mt_note',
        )
```

---

### `res.partner` — campo de alerta informativa (opcional)

> **Decisión de diseño:** No se extiende `res.partner` para este MVP. La información de deuda se consulta en tiempo real desde `sale.order`. Agregar un campo computado en `res.partner` sería ruido innecesario para una complejidad Baja.

---

## Seguridad

### Nuevo grupo

```xml
<!-- security/security.xml -->
<record id="group_credit_manager" model="res.groups">
    <field name="name">Ventas: Gerente de Crédito</field>
    <field name="category_id" ref="base.module_category_sales_sales"/>
    <field name="implied_ids" eval="[(4, ref('sales_team.group_sale_salesman'))]"/>
</record>
```

### Campos protegidos por grupo en la vista

| Campo / Botón               | Grupo requerido                            | Comportamiento sin el grupo |
|-----------------------------|--------------------------------------------|-----------------------------|
| Botón "Autorizar excepción" | `sale_credit_control.group_credit_manager` | Invisible                   |
| Botón "Revocar excepción"   | `sale_credit_control.group_credit_manager` | Invisible                   |
| `credit_approver_id`        | todos                                      | Visible, readonly siempre   |
| `credit_exception_note`     | todos (editable solo por credit_manager antes de autorizar) | Visible |

### `ir.model.access.csv`

No se crean modelos nuevos, solo se extiende `sale.order`. No requiere entradas nuevas en el CSV.

---

## Vistas

### Extensión del formulario: `sale.view_order_form`

```xml
<!-- views/sale_order_views.xml -->
<odoo>
    <record id="view_order_form_inherit_credit_control" model="ir.ui.view">
        <field name="name">sale.order.form.inherit.credit_control</field>
        <field name="model">sale.order</field>
        <field name="inherit_id" ref="sale.view_order_form"/>
        <field name="arch" type="xml">

            <!-- 1. Banner de alerta de crédito (visible antes de confirmar) -->
            <xpath expr="//div[hasclass('o_statusbar_status')]" position="before">
                <div class="alert alert-warning mb-0"
                     role="alert"
                     attrs="{'invisible': [
                         '|',
                         ('credit_overdue_amount', '<=', 0),
                         ('credit_exception', '=', True),
                         ('state', 'not in', ['draft', 'sent'])
                     ]}">
                    <i class="fa fa-exclamation-triangle me-1"/>
                    <strong>Alerta de crédito:</strong>
                    Este cliente tiene
                    <field name="credit_overdue_amount" widget="monetary"
                           options="{'currency_field': 'credit_currency_id'}"
                           nolabel="1"/>
                    en facturas vencidas por más de 30 días.
                    <span groups="sale_credit_control.group_credit_manager">
                        Puede autorizar una excepción abajo.
                    </span>
                </div>

                <!-- Badge de excepción autorizada -->
                <div class="alert alert-success mb-0"
                     role="alert"
                     attrs="{'invisible': [('credit_exception', '=', False)]}">
                    <i class="fa fa-check-circle me-1"/>
                    <strong>Excepción de crédito autorizada</strong>
                    por <field name="credit_approver_id" nolabel="1" readonly="1"/>
                    el <field name="credit_approved_on" nolabel="1" readonly="1" widget="datetime"/>.
                </div>
            </xpath>

            <!-- 2. Botones en el header -->
            <xpath expr="//button[@name='action_confirm']" position="before">
                <!-- Botón para autorizar excepción (solo gerente de crédito) -->
                <button name="action_grant_credit_exception"
                        string="Autorizar excepción de crédito"
                        type="object"
                        class="btn-warning"
                        groups="sale_credit_control.group_credit_manager"
                        attrs="{'invisible': [
                            '|',
                            ('credit_exception', '=', True),
                            ('credit_overdue_amount', '<=', 0),
                            ('state', 'not in', ['draft', 'sent'])
                        ]}"
                        confirm="¿Confirma que autoriza la excepción de crédito para esta orden?"/>

                <!-- Botón para revocar excepción (solo gerente de crédito) -->
                <button name="action_revoke_credit_exception"
                        string="Revocar excepción"
                        type="object"
                        class="btn-secondary"
                        groups="sale_credit_control.group_credit_manager"
                        attrs="{'invisible': [
                            '|',
                            ('credit_exception', '=', False),
                            ('state', 'not in', ['draft', 'sent'])
                        ]}"/>
            </xpath>

            <!-- 3. Sección de excepción en pestaña "Otra información" -->
            <xpath expr="//page[@name='other_information']//group[1]" position="after">
                <group string="Control de crédito"
                       attrs="{'invisible': [
                           '&amp;',
                           ('credit_overdue_amount', '<=', 0),
                           ('credit_exception', '=', False)
                       ]}">
                    <field name="credit_overdue_amount"
                           widget="monetary"
                           options="{'currency_field': 'credit_currency_id'}"
                           attrs="{'invisible': [('credit_overdue_amount', '=', 0)]}"/>
                    <field name="credit_exception" readonly="1"/>
                    <field name="credit_exception_note"
                           placeholder="Justificación de la excepción (requerida antes de autorizar)"
                           attrs="{
                               'readonly': [('credit_exception', '=', True)],
                               'required': [('credit_exception', '=', False),
                                            ('credit_overdue_amount', '>', 0)]
                           }"/>
                    <field name="credit_approver_id" readonly="1"
                           attrs="{'invisible': [('credit_exception', '=', False)]}"/>
                    <field name="credit_approved_on" readonly="1"
                           attrs="{'invisible': [('credit_exception', '=', False)]}"/>
                </group>
            </xpath>

        </field>
    </record>
</odoo>
```

---

## Archivos a crear

```
sale_credit_control/
├── __manifest__.py
├── __init__.py
├── models/
│   ├── __init__.py
│   └── sale_order.py
├── security/
│   ├── security.xml          ← define group_credit_manager
│   └── ir.model.access.csv   ← vacío en este caso (no hay modelos nuevos)
└── views/
    └── sale_order_views.xml  ← extiende sale.view_order_form
```

### `__manifest__.py`

```python
{
    'name': 'Sale Credit Control',
    'version': '19.0.1.0.0',
    'summary': 'Bloquea confirmación de ventas si el cliente tiene facturas vencidas',
    'category': 'Sales/Sales',
    'depends': ['sale', 'account'],
    'data': [
        'security/security.xml',
        'security/ir.model.access.csv',
        'views/sale_order_views.xml',
    ],
    'license': 'LGPL-3',
    'installable': True,
    'application': False,
}
```

### `security/ir.model.access.csv`

```csv
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
```

> Vacío intencionalmente: solo hay campos nuevos en `sale.order`, que ya tiene permisos definidos en `sale`.

---

## Flujo completo de datos

```
Vendedor en borrador/enviada
        ↓ clic "Confirmar"
sale.order.action_confirm()
        ↓ _compute_credit_overdue_amount()
        ↓ consulta account.move
              WHERE partner child_of commercial_partner
              AND move_type IN (out_invoice, out_refund)
              AND state = posted
              AND payment_state IN (not_paid, partial)
              AND invoice_date_due < hoy - 30 días
              AND company_id = orden.company_id

    ┌─── credit_overdue_amount > 0 AND credit_exception = False
    │           ↓
    │     UserError con monto vencido
    │           ↓
    │     Gerente de Crédito escribe nota en credit_exception_note
    │           ↓
    │     Gerente clic "Autorizar excepción"
    │           ↓
    │     action_grant_credit_exception()
    │           → credit_exception = True
    │           → credit_approver_id = usuario actual
    │           → credit_approved_on = ahora
    │           → message_post() en chatter
    │           ↓
    └───> Vendedor vuelve a clic "Confirmar"
                ↓ credit_overdue_amount > 0 pero credit_exception = True → pasa
                ↓ super().action_confirm()
                ↓ state = 'sale'
                ↓ stock.picking generado (si sale+stock instalados)
                ↓ disponible para facturar
```

---

## Casos límite y consideraciones

| Caso límite                                           | Comportamiento esperado                                                    |
|-------------------------------------------------------|----------------------------------------------------------------------------|
| Cliente sin facturas históricas                       | `credit_overdue_amount = 0.0` → sin bloqueo, sin alerta                   |
| Cliente con nota de crédito mayor que la factura vencida | `SUM(amount_residual)` puede ser negativo → sin bloqueo (neto favorable) |
| Varios contactos del mismo cliente (empresa + contacto) | `commercial_partner_id` agrupa todos → correcto                          |
| Multi-empresa: empresa A y B tienen facturas del mismo cliente | Solo consulta `company_id = orden.company_id` → correcto            |
| Orden confirmada antes de que se instale el módulo    | `credit_exception = False` por defecto → sin efecto retroactivo           |
| Vendedor sin permisos de Gerente de Crédito           | Botón invisible → no puede otorgarse la excepción a sí mismo              |
| Gerente de Crédito es también vendedor               | Puede otorgarse la excepción a sí mismo → diseño intencionado, auditable   |
| `credit_exception = True` pero factura ya pagada      | `credit_overdue_amount = 0` → banner verde desaparece, excepción irrelevante |
| Órden copiada desde una con excepción                 | `copy=False` en los campos de excepción → la copia sale limpia            |

---

## Puntos de riesgo

| Riesgo                                                    | Probabilidad | Mitigación                                                  |
|-----------------------------------------------------------|:------------:|-------------------------------------------------------------|
| Performance: muchas facturas de un cliente grande         | Media        | El `search` tiene dominio acotado por `company_id` y `state=posted`; índice en `invoice_date_due` |
| Vendedor descubre que puede limpiar `credit_exception` manualmente | Baja  | El campo `credit_exception` es `tracking=True`; visible en chatter. Agregar `readonly` para non-managers si es necesario |
| `credit_overdue_amount` desactualizado en pantalla        | Baja         | Es `store=False` → siempre recalculado al abrir el formulario |
| El 'Gerente de Crédito' olvida escribir nota antes de hacer click | Media  | `action_grant_credit_exception()` lanza `ValidationError` si nota vacía |
| Conflicto con otro módulo que también override `action_confirm()` | Media | Llamamos `super()` correctamente; dependería del orden de instalación de módulos — documentar en README |

---

## Complejidad: Baja

**Justificación:**
- 1 modelo extendido (`sale.order`)
- 6 campos nuevos (4 informativos, 2 de control)
- 1 override de método (`action_confirm`)
- 2 métodos nuevos (`action_grant_credit_exception`, `action_revoke_credit_exception`)
- 1 grupo nuevo (`group_credit_manager`)
- 0 modelos nuevos
- Sin integración externa
- La query a `account.move` es de solo lectura

**Estimación orientativa:** 1–2 días de desarrollo + 0.5 días de pruebas

---

## Checklist de aceptación técnica

- [ ] `action_confirm()` llama `super()` después de la validación
- [ ] La query de deuda filtra por `company_id` (multi-empresa correcto)
- [ ] La query usa `commercial_partner_id` via `child_of` (agrupa sub-contactos)
- [ ] La query filtra `invoice_date_due < today - 30 días` (no `<= today`)
- [ ] El campo `credit_exception_note` es requerido antes de autorizar (validado en Python, no solo en vista)
- [ ] Los campos de excepción tienen `copy=False` (la copia de la orden sale limpia)
- [ ] `credit_overdue_amount` tiene `store=False` (siempre tiempo real)
- [ ] Los botones de autorizar/revocar están protegidos con `groups=`
- [ ] Se probó: crear SO → confirmar con deuda → error → autorizar como gerente → confirmar exitoso
- [ ] Se probó: crear SO → confirmar sin deuda → sin bloqueo
- [ ] Se probó: crear SO → autorizar excepción → pagar todas las facturas → `credit_overdue_amount = 0` → confirmar sin problema
- [ ] Se probó con usuario tipo `group_sale_salesman` (sin ser gerente de crédito)
- [ ] Se probó en entorno multi-empresa
