# Reference: stock module — Odoo 19 Community

## Models

### `stock.picking` (Transfer)

**States:** `draft` → `confirmed` → `assigned` → `done` / `cancel`

**picking_type_code values:** `incoming` / `outgoing` / `internal`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `picking_type_id` | Many2one `stock.picking.type` | Operation type |
| `picking_type_code` | related | `incoming/outgoing/internal` |
| `partner_id` | Many2one `res.partner` | |
| `state` | Selection | Never modify directly |
| `location_id` | Many2one `stock.location` | Source |
| `location_dest_id` | Many2one `stock.location` | Destination |
| `move_ids` | One2many `stock.move` | |
| `move_line_ids` | One2many `stock.move.line` | Detail lines (with lot/package) |
| `origin` | Char | Source document reference |

**Action methods:**
- `action_confirm()` → confirms, checks availability
- `action_assign()` → reserves stock
- `button_validate()` → validates the transfer (user-facing)
- `_action_done()` → internal hook called after validation

### `stock.move`

**States:** `draft` → `confirmed` → `waiting` → `assigned` → `done` / `cancel`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `product_id` | Many2one `product.product` | |
| `product_uom_qty` | Float | Demanded quantity |
| `quantity` | Float | Done quantity (Odoo 17+, was qty_done) |
| `state` | Selection | |
| `picking_id` | Many2one `stock.picking` | |
| `sale_line_id` | Many2one `sale.order.line` | Available when sale_stock installed |
| `move_line_ids` | One2many `stock.move.line` | Execution detail |
| `move_orig_ids` | Many2many `stock.move` | Previous moves in chain |
| `move_dest_ids` | Many2many `stock.move` | Next moves in chain |

### `stock.move.line`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `move_id` | Many2one `stock.move` | |
| `lot_id` | Many2one `stock.lot` | Lot or serial number |
| `lot_name` | Char | Lot name (related or manual) |
| `quantity` | Float | Done quantity for this line |
| `location_id` | Many2one `stock.location` | Source |
| `location_dest_id` | Many2one `stock.location` | Destination |

### `stock.quant` (Inventory truth)

**Never write directly.** Key: `product_id + location_id + lot_id + package_id + owner_id`

```python
# Correct way to adjust inventory
quant = self.env['stock.quant'].with_context(inventory_mode=True).create({
    'product_id': product.id,
    'location_id': location.id,
    'inventory_quantity': 50.0,
})
quant.action_apply_inventory()
```

---

## sale_stock bridge (when both modules installed)

`sale.order.line` gets:
- `move_ids` → One2many to `stock.move` for that line
- `qty_delivered` computed from done moves

To propagate a field from sale line to stock move:

```python
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_procurement_values(self, group_id=False):
        vals = super()._prepare_procurement_values(group_id=group_id)
        vals['my_field'] = self.my_field
        return vals
```

---

## Extension points

### Override `button_validate()` — block before validating transfer

```python
class StockPicking(models.Model):
    _inherit = 'stock.picking'

    def button_validate(self):
        for picking in self:
            if picking.picking_type_code == 'outgoing' and not picking.my_condition:
                raise UserError(_('Cannot validate: reason'))
        return super().button_validate()
```

### Override `_action_done()` — hook after validation

```python
def _action_done(self):
    result = super()._action_done()
    # At this point: moves are 'done', quants updated
    for picking in self.filtered(lambda p: p.picking_type_code == 'outgoing'):
        picking._notify_external_system()
    return result
```

### Read lot names from a sale.order.line (lot traceability pattern)

```python
# In sale.order.line._prepare_invoice_line()
lot_names = []
for stock_move in self.move_ids.filtered(lambda m: m.state == 'done'):
    for move_line in stock_move.move_line_ids:
        if move_line.lot_id and move_line.lot_id.name not in lot_names:
            lot_names.append(move_line.lot_id.name)
result = ', '.join(lot_names)  # "LOT001, LOT002"
```

### Create outgoing transfer programmatically

```python
from odoo.fields import Command

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
picking.action_assign()
```

---

## Warehouse steps

| Config | Steps |
|---|---|
| `reception_steps='one_step'` | Receive directly to stock |
| `reception_steps='two_steps'` | Input → Quality → Stock |
| `reception_steps='three_steps'` | Input → Quality → Stock |
| `delivery_steps='ship_only'` | Stock → Customer |
| `delivery_steps='pick_ship'` | Pick → Pack → Ship |
| `delivery_steps='pick_pack_ship'` | Pick → Pack → Ship |

---

## View extension — key xpaths

```xml
<!-- inherit_id: stock.view_picking_form -->

<!-- Button before Validate -->
<xpath expr="//button[@name='button_validate']" position="before">
    <button name="action_my_prevalidation" string="Pre-validate" type="object"
            invisible="state != 'assigned'"/>
</xpath>

<!-- Column in operation lines -->
<xpath expr="//field[@name='move_line_ids']/list//field[@name='quantity']" position="before">
    <field name="my_field" optional="show"/>
</xpath>
```

---

## Critical antipatterns

- ❌ `quant.write({'quantity': 50})` — use `inventory_mode=True` context
- ❌ `move.write({'state': 'done'})` — use `button_validate()` / `_action_done()`
- ❌ Delete done moves — breaks traceability audit trail
- ❌ Read `lot_id` from `stock.move` directly — it's on `stock.move.line`
- ✅ Filter `move_ids` by `state == 'done'` before reading lot names
- ✅ Use `move_line_ids` (not `move_ids`) to get lot/serial detail
