# Puntos de extensión — `account` — Odoo 19

## Modelos recomendados para extender

| Modelo            | Cuándo extender                                                  |
|-------------------|------------------------------------------------------------------|
| `account.move`    | Agregar campos a facturas, modificar flujo de publicación        |
| `account.move.line` | Agregar datos por línea de factura                             |
| `account.journal` | Agregar configuración de diario                                  |
| `account.payment` | Extender proceso de pago                                         |

---

## Métodos recomendados para override

### `account.move`

#### `action_post()` — Validar antes de publicar

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    def action_post(self):
        for move in self:
            if move.is_invoice() and not move.campo_requerido:
                raise UserError('Debe completar el campo X antes de publicar')
        return super().action_post()
```

> `action_post()` es el método más crítico: asigna la secuencia, crea el hash de inalterabilidad, dispara el cron de emails. **Siempre llama `super()`**.

#### `_prepare_invoice_vals()` (o valores de creación)

Al crear facturas desde código (ej. desde `sale.order`):

```python
# En el módulo que crea facturas
def _prepare_invoice(self):
    vals = super()._prepare_invoice()
    vals['mi_campo'] = self.mi_campo
    return vals
```

#### `_compute_payment_state()` — Hook post-conciliación

```python
# Rara vez necesario, pero disponible
def _compute_payment_state(self):
    super()._compute_payment_state()
    for move in self:
        if move.payment_state == 'paid' and not move.notificacion_enviada:
            move._enviar_notificacion_pago()
```

#### Agregar campo con visibilidad condicional

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    numero_dte = fields.Char(
        string='Número DTE',
        tracking=True,
        copy=False,
    )

    @api.constrains('numero_dte', 'state')
    def _check_numero_dte(self):
        for move in self:
            if move.state == 'posted' and move.is_sale_document():
                if not move.numero_dte:
                    raise ValidationError('El DTE es obligatorio para facturas publicadas')
```

---

### `account.move.line`

#### `_prepare_base_line_for_taxes_computation()` — Personalizar cálculo de impuestos

```python
class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    def _prepare_base_line_for_taxes_computation(self, **kwargs):
        result = super()._prepare_base_line_for_taxes_computation(**kwargs)
        # Modificar base imponible si aplica exención especial
        if self.product_id.exento_especial:
            result['special_mode'] = 'total_excluded'
        return result
```

#### Agregar campo por línea de factura

```python
class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    proyecto_id = fields.Many2one(
        'project.project',
        string='Proyecto',
        # No usar store=True a menos que necesites búsquedas/reportes sobre este campo
    )
```

---

### `account.payment`

#### `_prepare_move_line_default_vals()` — Personalizar asiento del pago

```python
class AccountPayment(models.Model):
    _inherit = 'account.payment'

    def _prepare_move_line_default_vals(self, write_off_line_vals=None):
        line_vals_list = super()._prepare_move_line_default_vals(write_off_line_vals)
        # Agregar referencia personalizada a cada línea
        for line_vals in line_vals_list:
            line_vals['mi_referencia'] = self.mi_referencia
        return line_vals_list
```

---

## Extensión de vistas (xpaths recomendados)

### Agregar campo en la factura

```xml
<record id="view_move_form_inherit_mi_modulo" model="ir.ui.view">
    <field name="name">account.move.form.inherit.mi_modulo</field>
    <field name="model">account.move</field>
    <field name="inherit_id" ref="account.view_move_form"/>
    <field name="arch" type="xml">

        <!-- Campo junto al cliente -->
        <xpath expr="//field[@name='partner_id']" position="after">
            <field name="mi_campo"
                   attrs="{'invisible': [('move_type', 'not in', ['out_invoice', 'out_refund'])]}"/>
        </xpath>

        <!-- Nueva pestaña -->
        <xpath expr="//page[@name='invoice_tab']" position="after">
            <page string="Mi Módulo" name="mi_modulo"
                  attrs="{'invisible': [('move_type', '=', 'entry')]}">
                <group>
                    <field name="mi_campo_a"/>
                    <field name="mi_campo_b"/>
                </group>
            </page>
        </xpath>

        <!-- Columna en líneas de factura -->
        <xpath expr="//field[@name='invoice_line_ids']/list//field[@name='price_subtotal']"
               position="before">
            <field name="mi_campo_linea" optional="show"/>
        </xpath>

    </field>
</record>
```

### Agregar columna en líneas del asiento contable (diario)

```xml
<xpath expr="//field[@name='line_ids']/list//field[@name='debit']" position="before">
    <field name="mi_campo" optional="show"/>
</xpath>
```

### Agregar botón de acción en header de factura

```xml
<xpath expr="//button[@name='action_post']" position="before">
    <button name="action_mi_validacion"
            string="Validar DTE"
            type="object"
            class="btn-primary"
            attrs="{'invisible': ['|', ('state', '!=', 'draft'), ('move_type', '=', 'entry')]}"/>
</xpath>
```

---

## Crear facturas programáticamente

### Patrón recomendado para crear una factura de cliente

```python
move = self.env['account.move'].create({
    'move_type': 'out_invoice',
    'partner_id': partner.id,
    'invoice_date': fields.Date.today(),
    'invoice_payment_term_id': payment_term.id,
    'invoice_origin': self.name,  # referencia al documento origen
    'invoice_line_ids': [
        Command.create({
            'product_id': product.id,
            'quantity': 1.0,
            'price_unit': 100.0,
            'tax_ids': [Command.set(product.taxes_id.ids)],
        }),
    ],
})
move.action_post()  # publicar inmediatamente si no requiere revisión
```

### Crear nota de crédito desde factura

```python
# Usando el wizard estándar
reversal = self.env['account.move.reversal'].with_context(
    active_ids=invoice.ids,
    active_model='account.move',
).create({
    'reason': 'Devolución de mercancía',
    'date': fields.Date.today(),
})
result = reversal.reverse_moves()
credit_note = self.env['account.move'].browse(result['res_id'])
```

---

## Agregar impuesto personalizado a un producto desde código

```python
tax = self.env['account.tax'].create({
    'name': 'Mi Impuesto 10%',
    'type_tax_use': 'sale',
    'amount_type': 'percent',
    'amount': 10.0,
    'tax_group_id': self.env.ref('account.tax_group_taxes').id,
    'invoice_repartition_line_ids': [
        Command.create({'repartition_type': 'base', 'factor_percent': 100}),
        Command.create({'repartition_type': 'tax', 'factor_percent': 100,
                        'account_id': cuenta_impuesto.id}),
    ],
    'refund_repartition_line_ids': [
        Command.create({'repartition_type': 'base', 'factor_percent': 100}),
        Command.create({'repartition_type': 'tax', 'factor_percent': 100,
                        'account_id': cuenta_impuesto.id}),
    ],
})
```

---

## Subtipos de mensaje disponibles

| XML ID                             | Evento                              |
|------------------------------------|-------------------------------------|
| `account.mt_invoice_validated`     | Factura publicada                   |
| `account.mt_invoice_paid`          | Factura marcada como pagada         |

---

## Integrar `sale.order` → `account.move`

Si necesitas pasar datos de la orden a la factura:

```python
# En el módulo que extiende ambos
class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def _prepare_invoice(self):
        vals = super()._prepare_invoice()
        vals['mi_campo_factura'] = self.mi_campo_orden
        return vals
```

> Este es el patrón correcto. No hagas `write()` post-creación de la factura; hazlo en `_prepare_invoice()`.
