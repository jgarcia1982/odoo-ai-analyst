# Puntos de extensión — `sale` — Odoo 19

## Modelos recomendados para extender

| Modelo            | Cuándo extender                                          |
|-------------------|----------------------------------------------------------|
| `sale.order`      | Agregar campos a la orden, modificar el flujo de estados |
| `sale.order.line` | Agregar campos por línea, cambiar cálculo de precio      |
| `res.partner`     | Agregar configuración de ventas al cliente               |
| `res.company`     | Agregar configuración global de ventas                   |

---

## Métodos recomendados para override

### `sale.order`

#### `action_confirm()` — Validación antes de confirmar

```python
class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def action_confirm(self):
        for order in self:
            if not order.campo_requerido:
                raise UserError('Debe completar el campo X antes de confirmar')
        return super().action_confirm()
```

> **Nunca omitas `super()`** — el método base crea movimientos de stock, envía emails de confirmación y dispara automatizaciones.

#### `_prepare_invoice()` — Agregar datos a la factura generada

```python
def _prepare_invoice(self):
    invoice_vals = super()._prepare_invoice()
    invoice_vals['mi_campo_extra'] = self.mi_campo_extra
    return invoice_vals
```

#### `_send_order_confirmation_mail()` — Hook post-confirmación

```python
def _send_order_confirmation_mail(self):
    super()._send_order_confirmation_mail()
    # Lógica adicional: notificar a almacén, crear tarea, etc.
    for order in self:
        order._crear_tarea_de_seguimiento()
```

#### `_get_invoiceable_lines()` — Controlar qué líneas se facturan

```python
def _get_invoiceable_lines(self, final=False):
    lines = super()._get_invoiceable_lines(final=final)
    # Filtrar líneas según lógica propia
    return lines.filtered(lambda l: not l.excluir_de_factura)
```

---

### `sale.order.line`

#### `_compute_price_unit()` — Personalizar cálculo de precio

```python
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    @api.depends('product_id', 'product_uom_qty', 'product_uom_id', 'order_id.pricelist_id')
    def _compute_price_unit(self):
        super()._compute_price_unit()
        for line in self:
            if line.order_id.tipo_cliente == 'vip':
                line.price_unit *= 0.9  # descuento VIP
```

#### `_prepare_invoice_line()` — Agregar datos a la línea de factura

```python
def _prepare_invoice_line(self, **optional_values):
    vals = super()._prepare_invoice_line(**optional_values)
    vals['proyecto_id'] = self.order_id.proyecto_id.id
    return vals
```

#### `_compute_qty_delivered()` — Método de entrega personalizado

```python
@api.depends('qty_delivered_method', 'analytic_line_ids.so_line',
             'analytic_line_ids.unit_amount', 'analytic_line_ids.product_uom_id')
def _compute_qty_delivered(self):
    super()._compute_qty_delivered()
    for line in self:
        if line.qty_delivered_method == 'mi_metodo':
            line.qty_delivered = line._calcular_entrega_custom()
```

---

## Extensión de vistas (xpaths recomendados)

### Agregar campo en el formulario de la orden

```xml
<record id="view_order_form_inherit_mi_modulo" model="ir.ui.view">
    <field name="name">sale.order.form.inherit.mi_modulo</field>
    <field name="model">sale.order</field>
    <field name="inherit_id" ref="sale.view_order_form"/>
    <field name="arch" type="xml">

        <!-- Después del campo cliente -->
        <xpath expr="//field[@name='partner_id']" position="after">
            <field name="mi_campo"/>
        </xpath>

        <!-- Nueva pestaña en el notebook -->
        <xpath expr="//notebook" position="inside">
            <page string="Mi Módulo" name="mi_modulo">
                <group>
                    <field name="mi_campo_a"/>
                    <field name="mi_campo_b"/>
                </group>
            </page>
        </xpath>

        <!-- Columna adicional en la lista de líneas -->
        <xpath expr="//field[@name='order_line']/list//field[@name='price_subtotal']"
               position="before">
            <field name="mi_campo_linea" optional="show"/>
        </xpath>

    </field>
</record>
```

### Agregar botón de acción en el header

```xml
<xpath expr="//button[@name='action_confirm']" position="before">
    <button name="action_mi_accion"
            string="Mi Acción"
            type="object"
            class="btn-secondary"
            attrs="{'invisible': [('state', '!=', 'draft')]}"/>
</xpath>
```

### Agregar filtro en la vista de búsqueda

```xml
<record id="view_sales_order_filter_inherit_mi_modulo" model="ir.ui.view">
    <field name="name">sale.order.search.inherit.mi_modulo</field>
    <field name="model">sale.order</field>
    <field name="inherit_id" ref="sale.view_sales_order_filter"/>
    <field name="arch" type="xml">
        <xpath expr="//filter[@name='my_sale_orders_filter']" position="after">
            <filter string="Mi Filtro"
                    name="mi_filtro"
                    domain="[('mi_campo', '=', True)]"/>
        </xpath>
    </field>
</record>
```

---

## Subtipos de mensaje configurados

| XML ID                                  | Evento                                      | Default |
|-----------------------------------------|---------------------------------------------|---------|
| `sale.mt_order_confirmed`               | Orden confirmada                            | Sí      |
| `sale.mt_order_invoice`                 | Factura creada desde la orden               | Sí      |

Para suscribir al cliente automáticamente:

```python
def action_confirm(self):
    result = super().action_confirm()
    for order in self:
        # Asegura que el cliente sea seguidor
        order.message_subscribe(partner_ids=[order.partner_id.id])
    return result
```

---

## Automatizaciones sin código (base.automation)

Eventos disponibles para reglas automáticas sobre `sale.order`:

| Evento                  | Cuándo se dispara                           |
|-------------------------|---------------------------------------------|
| Al crear registro       | Al crear una nueva cotización               |
| Al actualizar registro  | Al cambiar `state`, `invoice_status`, etc.  |
| Basado en tiempo        | X días antes/después de `validity_date`     |

Ejemplo de uso típico:
- Recordatorio 3 días antes de `validity_date` si sigue en draft
- Notificar al gerente cuando `amount_total > 50000`
- Crear actividad cuando `invoice_status == 'to invoice'`

---

## Agregar campo de entrega personalizado (`qty_delivered_method`)

Para registrar un nuevo método de cálculo de entregas:

```python
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    @api.depends('product_id')
    def _compute_qty_delivered_method(self):
        super()._compute_qty_delivered_method()
        for line in self:
            if line.product_id.tipo_entrega == 'mi_tipo':
                line.qty_delivered_method = 'mi_metodo'

    @api.depends(...)
    def _compute_qty_delivered(self):
        super()._compute_qty_delivered()
        for line in self.filtered(lambda l: l.qty_delivered_method == 'mi_metodo'):
            line.qty_delivered = ...
```
