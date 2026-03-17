# Reference: account module — Odoo 19 Community

## Models

### `account.move`

**States:** `draft` → `posted` → `cancel`

**move_type values:**
| Value | Meaning |
|---|---|
| `out_invoice` | Customer invoice |
| `out_refund` | Customer credit note |
| `in_invoice` | Vendor bill |
| `in_refund` | Vendor credit note |
| `entry` | Journal entry |

**payment_state values:** `not_paid` / `in_payment` / `paid` / `partial` / `reversed` / `blocked`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `partner_id` | Many2one `res.partner` | |
| `move_type` | Selection | See table above |
| `state` | Selection | Never modify directly |
| `payment_state` | Selection | Computed — never modify directly |
| `amount_residual` | Monetary | Outstanding balance |
| `invoice_date_due` | Date | Payment due date |
| `invoice_date` | Date | Invoice date |
| `company_id` | Many2one `res.company` | Always filter queries by this |
| `invoice_line_ids` | One2many `account.move.line` | Customer-facing lines |
| `line_ids` | One2many `account.move.line` | All accounting lines |
| `invoice_origin` | Char | Reference to source document (e.g. sale order name) |

**Useful helpers:**
- `is_invoice()` → True for out_invoice, out_refund, in_invoice, in_refund
- `is_sale_document()` → True for out_invoice, out_refund

### `account.move.line`

Key fields:
| Field | Type | Notes |
|---|---|---|
| `product_id` | Many2one `product.product` | |
| `quantity` | Float | |
| `price_unit` | Float | |
| `discount` | Float | |
| `price_subtotal` | Monetary | Computed |
| `tax_ids` | Many2many `account.tax` | |
| `account_id` | Many2one `account.account` | Accounting account |
| `move_id` | Many2one `account.move` | Parent move |

**CRITICAL:** Lines of a posted move are immutable (protected by `inalterable_hash`). Never modify lines after `action_post()`.

---

## Extension points

### Override `action_post()` — validate before posting

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    def action_post(self):
        for move in self:
            if move.is_invoice() and not move.my_required_field:
                raise UserError(_('Field X is required before posting'))
        return super().action_post()  # assigns sequence, creates hash, sends emails
```

### Query overdue invoices for a partner (credit check pattern)

**Always use `commercial_partner_id` + `child_of`** — never `partner_id =` directly.
`commercial_partner_id` is the top-level company contact. Using `child_of` catches all
subsidiaries and contact persons under the same company. Using `= partner_id.id` directly
only checks invoices billed to that exact contact, missing the rest of the group's debt.

```python
from odoo import fields
from datetime import timedelta

today = fields.Date.today()
cutoff = today - timedelta(days=30)

moves = self.env['account.move'].search([
    ('partner_id', 'child_of', order.partner_id.commercial_partner_id.id),  # ← commercial_partner_id + child_of
    ('move_type', 'in', ('out_invoice', 'out_refund')),
    ('state', '=', 'posted'),
    ('payment_state', 'in', ('not_paid', 'partial')),
    ('invoice_date_due', '<', cutoff),
    ('company_id', '=', order.company_id.id),  # ← always filter by company
])
total_overdue = sum(moves.mapped('amount_residual'))
```

### Add field to invoice line

```python
class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    my_field = fields.Char(string='My Field', readonly=True, copy=False)
```

### Propagate data from sale.order to account.move

```python
# In the module that extends sale.order (NOT in account module)
class SaleOrder(models.Model):
    _inherit = 'sale.order'

    def _prepare_invoice(self):
        vals = super()._prepare_invoice()
        vals['my_invoice_field'] = self.my_order_field
        return vals
```

### Create invoice programmatically

```python
from odoo.fields import Command

move = self.env['account.move'].create({
    'move_type': 'out_invoice',
    'partner_id': partner.id,
    'invoice_date': fields.Date.today(),
    'invoice_origin': self.name,
    'invoice_line_ids': [
        Command.create({
            'product_id': product.id,
            'quantity': 1.0,
            'price_unit': 100.0,
            'tax_ids': [Command.set(product.taxes_id.ids)],
        }),
    ],
})
move.action_post()
```

---

## View extension — key xpaths

```xml
<!-- inherit_id: account.view_move_form -->

<!-- Button before Post -->
<xpath expr="//button[@name='action_post']" position="before">
    <button name="action_my_validation" string="Validate" type="object"
            invisible="state != 'draft'"/>
</xpath>

<!-- Field after partner (only on customer invoices) -->
<xpath expr="//field[@name='partner_id']" position="after">
    <field name="my_field"
           invisible="move_type not in ['out_invoice', 'out_refund']"/>
</xpath>

<!-- Column in invoice lines -->
<xpath expr="//field[@name='invoice_line_ids']//tree//field[@name='quantity']" position="after">
    <field name="my_line_field" optional="show" readonly="1"/>
</xpath>
```

---

## Critical antipatterns

- ❌ `move.write({'state': 'posted'})` — use `action_post()`
- ❌ Modifying lines of a posted move — raises integrity error
- ❌ Query without `company_id` filter — breaks multi-company
- ❌ Using `payment_state` to determine if a move is paid via direct write — it's computed
- ❌ `('partner_id', '=', partner.id)` in credit check — misses subsidiaries and contacts of the same company
- ✅ Use `amount_residual > 0` + `payment_state in ('not_paid', 'partial')` for outstanding balance
- ✅ Always pass `invoice_origin` when creating invoices from other documents
- ✅ Always use `commercial_partner_id` + `child_of` when querying debt for a partner
