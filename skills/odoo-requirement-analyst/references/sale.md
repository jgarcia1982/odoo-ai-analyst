# Reference: sale module — Odoo 19 Community

## Models

### `sale.order`

**States:** `draft` → `sent` → `sale` → `cancel`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `partner_id` | Many2one `res.partner` | Use `commercial_partner_id` for credit checks |
| `state` | Selection | Never modify directly — use action methods |
| `invoice_status` | Selection | `upselling/invoiced/to invoice/nothing` |
| `amount_total` | Monetary | |
| `user_id` | Many2one `res.users` | Salesperson |
| `company_id` | Many2one `res.company` | Always filter queries by this |
| `order_line` | One2many `sale.order.line` | |
| `picking_ids` | Many2many `stock.picking` | Generated on confirm |

**Action methods (never use write on state):**
- `action_confirm()` → creates stock pickings, sends email, sets state='sale'
- `action_cancel()` → cancels order and pickings
- `action_draft()` → resets to draft

### `sale.order.line`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `product_id` | Many2one `product.product` | |
| `product_uom_qty` | Float | Ordered quantity |
| `qty_delivered` | Float | Computed from stock or timesheets |
| `qty_invoiced` | Float | Computed |
| `price_unit` | Float | |
| `discount` | Float | Percentage 0–100 |
| `price_subtotal` | Monetary | Computed |
| `move_ids` | One2many `stock.move` | Available when sale_stock is installed |

---

## Extension points

### Override `action_confirm()` — block before confirming

```python
class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def action_confirm(self):
        for order in self:
            if <condition>:
                raise UserError(_('Message'))
        return super().action_confirm()  # NEVER omit super()
```

### Override `_prepare_invoice()` — add data to the generated invoice

```python
def _prepare_invoice(self):
    vals = super()._prepare_invoice()
    vals['my_field'] = self.my_field
    return vals
```

### Override `_prepare_invoice_line()` — add data to invoice lines

```python
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_invoice_line(self, **optional_values):
        vals = super()._prepare_invoice_line(**optional_values)
        vals['my_field'] = self.my_field
        return vals
```

### Override `_prepare_procurement_values()` — propagate fields to stock.move

```python
def _prepare_procurement_values(self, group_id=False):
    vals = super()._prepare_procurement_values(group_id=group_id)
    vals['my_field'] = self.my_field
    return vals
```

---

## View extension — key xpaths

```xml
<!-- inherit_id: sale.view_order_form -->

<!-- Button before Confirm -->
<xpath expr="//button[@name='action_confirm']" position="before">
    <button name="action_my_action" string="My Action" type="object"
            invisible="state != 'draft'"/>
</xpath>

<!-- Field after partner -->
<xpath expr="//field[@name='partner_id']" position="after">
    <field name="my_field"/>
</xpath>

<!-- Section in "Other Info" tab -->
<xpath expr="//page[@name='other_information']//group[last()]" position="after">
    <group string="My Section">
        <field name="my_field_a"/>
    </group>
</xpath>

<!-- Column in order lines -->
<xpath expr="//field[@name='order_line']/list//field[@name='price_subtotal']" position="before">
    <field name="my_line_field" optional="show"/>
</xpath>
```

---

## Security

Groups hierarchy: `group_sale_salesman` ⊂ `group_sale_manager`

New group pattern:
```xml
<record id="group_my_role" model="res.groups">
    <field name="name">My Role</field>
    <field name="category_id" ref="base.module_category_sales_sales"/>
    <field name="implied_ids" eval="[(4, ref('sales_team.group_sale_manager'))]"/>
</record>
```

---

## Critical antipatterns

- ❌ `order.write({'state': 'sale'})` — use `action_confirm()`
- ❌ Override without `super()` — loses stock picking creation, emails, automations
- ❌ `store=True` field without `@api.depends` — computed field never updates
- ❌ Query `account.move` without `company_id` filter — breaks multi-company
- ✅ Use `partner_id.commercial_partner_id` + `child_of` for credit checks across contacts
