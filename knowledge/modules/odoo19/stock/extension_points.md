# Puntos de extensión — `stock` — Odoo 19

## Modelos recomendados para extender

| Modelo           | Cuándo extender                                                    |
|------------------|--------------------------------------------------------------------|
| `stock.picking`  | Agregar campos a transferencias, modificar el flujo de validación  |
| `stock.move`     | Cambiar comportamiento de movimientos, agregar campos              |
| `stock.move.line`| Agregar datos de detalle por línea (lote, ubicación, etc.)         |
| `stock.warehouse`| Agregar configuración de almacén                                   |
| `stock.location` | Agregar atributos a ubicaciones                                    |
| `stock.quant`    | Extender el inventario actual                                      |
| `stock.rule`     | Agregar lógica de rutas personalizada                              |

---

## Métodos recomendados para override

### `stock.picking`

#### `button_validate()` — Validar antes de completar

```python
class StockPicking(models.Model):
    _inherit = 'stock.picking'

    def button_validate(self):
        for picking in self:
            if picking.picking_type_code == 'outgoing':
                if not picking.signed_by:
                    raise UserError('Se requiere firma del cliente antes de entregar')
        return super().button_validate()
```

#### `_action_done()` — Hook post-validación

```python
def _action_done(self):
    result = super()._action_done()
    # Después del super(), los movimientos ya están en estado 'done'
    # y los quants ya fueron actualizados
    for picking in self.filtered(lambda p: p.picking_type_code == 'outgoing'):
        picking._notificar_sistema_externo()
    return result
```

#### `_create_backorder()` — Personalizar backorders

```python
def _create_backorder(self, backorder_moves=None):
    backorders = super()._create_backorder(backorder_moves)
    for bo in backorders:
        # Copiar campo personalizado al backorder
        bo.mi_campo = self.mi_campo
    return backorders
```

---

### `stock.move`

#### `_get_available_quantity()` — Modificar lógica de disponibilidad

```python
class StockMove(models.Model):
    _inherit = 'stock.move'

    def _get_available_quantity(self, location_id, lot_id=None,
                                 package_id=None, owner_id=None,
                                 strict=False, allow_negative=False):
        qty = super()._get_available_quantity(
            location_id, lot_id, package_id, owner_id, strict, allow_negative
        )
        # Aplicar restricción adicional (ej. cuarentena)
        if location_id.en_cuarentena:
            qty = 0.0
        return qty
```

#### `_push_apply()` — Agregar regla push personalizada

Después de que un movimiento se complete, se pueden agregar movimientos adicionales automáticos:

```python
def _push_apply(self):
    super()._push_apply()
    for move in self.filtered(lambda m: m.location_dest_id.requiere_inspeccion):
        # Crear movimiento de inspección automáticamente
        move._create_inspeccion_move()
```

---

### `stock.warehouse`

#### `_get_global_route_rules_values()` — Agregar reglas de ruta personalizadas

```python
class StockWarehouse(models.Model):
    _inherit = 'stock.warehouse'

    def _get_global_route_rules_values(self):
        rules = super()._get_global_route_rules_values()
        # Agregar regla de cross-docking personalizada
        rules['mi_regla_custom'] = {
            'depends': ['delivery_steps'],
            'create_values': {...},
            'update_values': {...},
        }
        return rules
```

---

## Extensión de vistas (xpaths recomendados)

### Agregar campo en el formulario de transferencia

```xml
<record id="view_picking_form_inherit_mi_modulo" model="ir.ui.view">
    <field name="name">stock.picking.form.inherit.mi_modulo</field>
    <field name="model">stock.picking</field>
    <field name="inherit_id" ref="stock.view_picking_form"/>
    <field name="arch" type="xml">

        <!-- Campo junto al cliente -->
        <xpath expr="//field[@name='partner_id']" position="after">
            <field name="mi_campo_picking"/>
        </xpath>

        <!-- Nueva pestaña -->
        <xpath expr="//page[@name='operations']" position="after">
            <page string="Mi Módulo" name="mi_modulo">
                <group>
                    <field name="mi_campo_a"/>
                </group>
            </page>
        </xpath>

        <!-- Botón de acción adicional -->
        <xpath expr="//button[@name='button_validate']" position="before">
            <button name="action_mi_prevalidacion"
                    string="Pre-validar"
                    type="object"
                    class="btn-secondary"
                    attrs="{'invisible': [('state', '!=', 'assigned')]}"/>
        </xpath>

    </field>
</record>
```

### Agregar columna en las líneas de operaciones

```xml
<xpath expr="//field[@name='move_line_ids']/list//field[@name='quantity']"
       position="before">
    <field name="mi_campo_linea" optional="show"/>
</xpath>
```

---

## Crear transferencias programáticamente

### Transferencia de entrega simple

```python
picking = self.env['stock.picking'].create({
    'picking_type_id': warehouse.out_type_id.id,
    'partner_id': partner.id,
    'location_id': warehouse.lot_stock_id.id,
    'location_dest_id': self.env.ref('stock.stock_location_customers').id,
    'origin': self.name,
    'move_ids': [
        Command.create({
            'name': product.name,
            'product_id': product.id,
            'product_uom': product.uom_id.id,
            'product_uom_qty': 5.0,
            'location_id': warehouse.lot_stock_id.id,
            'location_dest_id': self.env.ref('stock.stock_location_customers').id,
        }),
    ],
})
picking.action_confirm()
picking.action_assign()  # Reservar stock disponible
```

### Ajuste de inventario (corregir stock directamente)

```python
quant = self.env['stock.quant'].with_context(inventory_mode=True).create({
    'product_id': product.id,
    'location_id': location.id,
    'inventory_quantity': 50.0,
})
quant.action_apply_inventory()
```

### Movimiento interno entre ubicaciones

```python
picking = self.env['stock.picking'].create({
    'picking_type_id': warehouse.int_type_id.id,
    'location_id': origen.id,
    'location_dest_id': destino.id,
    'move_ids': [
        Command.create({
            'name': 'Transferencia interna',
            'product_id': product.id,
            'product_uom': product.uom_id.id,
            'product_uom_qty': 10.0,
            'location_id': origen.id,
            'location_dest_id': destino.id,
        }),
    ],
})
picking.action_confirm()
```

---

## Integración con `sale.order` — cómo `sale` genera pickings

```python
# En sale.order_line, al confirmar la orden:
def _action_launch_stock_rule(self, previous_product_uom_qty=False):
    # Genera procurement.group y llama a stock.rule para crear pickings
    ...

# Personalizar valores de los movimientos generados desde ventas:
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_procurement_values(self, group_id=False):
        vals = super()._prepare_procurement_values(group_id=group_id)
        vals['mi_campo_en_move'] = self.mi_campo
        return vals
```

---

## Agregar campo en `stock.move` propagado desde `sale.order.line`

```python
# 1. Agregar campo en stock.move
class StockMove(models.Model):
    _inherit = 'stock.move'
    mi_campo = fields.Char('Mi Campo')

# 2. Propagarlo desde sale.order.line
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_procurement_values(self, group_id=False):
        vals = super()._prepare_procurement_values(group_id=group_id)
        vals['mi_campo'] = self.mi_campo_linea
        return vals
```

---

## Subtipos de mensaje en pickings

| XML ID                          | Evento                            | Default |
|---------------------------------|-----------------------------------|---------|
| `stock.mt_picking_done`         | Transferencia validada            | Sí      |

Para notificar al responsable cuando se valida:

```python
picking.message_post(
    body=_('Transferencia %s completada') % picking.name,
    message_type='notification',
    subtype_xmlid='stock.mt_picking_done',
    partner_ids=[picking.partner_id.id],
)
```
