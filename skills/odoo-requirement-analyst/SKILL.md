---
name: odoo-requirement-analyst
description: Converts a functional requirement into a complete technical specification for Odoo 19. Use when the user describes a business need involving sale, account, or stock modules and needs a spec with Python code, XML views, and implementation guidance ready for a developer.
---

# Odoo Requirement Analyst

Use this skill when the user provides a functional requirement for Odoo 19 and needs a full technical specification.

## Step 1 — Load the knowledge base

Before analyzing anything, read the following reference files:

- `references/sale.md`
- `references/account.md`
- `references/stock.md`

These contain the exact models, fields, methods, and antipatterns for Odoo 19 Community. Use them as your source of truth — do not rely on memory for API details.

## Step 2 — Analyze the requirement

After reading the references, reason through:

1. **Módulos afectados** — Which models are involved? At what point in the state flow does the change happen? Does data flow between modules?
2. **Tipo de cambio** — One of: Validación de flujo / Campo informativo / Aprobación / Automatización / Propagación de datos / Reporte / Integración externa
3. **Solución mínima** — For each affected model: new fields (technical name, ORM type, constraints), which method to override and why, which view to extend with which xpath, how data propagates via `_prepare_*` methods.

## Step 3 — Generate spec.md

Produce a file named `spec.md` using this exact structure:

```
# Especificación técnica: [nombre]

**Tipo:** [clasificación]
**Complejidad:** [Baja / Media / Alta]
**Módulos afectados:** [lista]

## Resumen ejecutivo
[2-3 sentences]

## Módulo a crear
- Nombre: `[base]_[feature]`
- Depende de: [lista]

## Cambios por modelo
[For each model: new fields in a table, override methods with complete Python code]

## Vistas
[Complete XML xpaths ready to copy]

## Archivos a crear
[Directory tree]

## Flujo completo de datos
[ASCII diagram]

## Casos límite
[Table of edge cases]

## Puntos de riesgo
[Table with mitigation]

## Complejidad: [nivel]
[Justification with count of models/fields/overrides]
```

## Mandatory rules for generated code

- Field names: `snake_case`
- Python class names: `PascalCase`
- Every override calls `super()`
- Xpaths use `position='after|before|inside'` — never `replace` without explicit justification
- Module version: `19.0.1.0.0`
- Never modify standard module files — always use `_inherit`
- Never call `write({'state': '...'})` — use action methods
- `store=True` requires `@api.depends`
- Multi-company queries always filter by `company_id`
- Use `commercial_partner_id` + `child_of` for partner credit checks

## Step 4 — Self-review before output

Before writing the final spec, verify every item against your generated code. Fix any violation in the code itself — do not just mention it as a risk.

**Check 1 — Partner credit domain must use `child_of`, not `=`**

```python
# ❌ WRONG — misses subsidiaries and contacts of the same company
('partner_id', '=', self.partner_id.commercial_partner_id.id),

# ✅ CORRECT
('partner_id', 'child_of', self.partner_id.commercial_partner_id.id),
```

**Check 2 — Every `account.move` query must include `company_id`**

```python
# ✅ REQUIRED — always add this line to every account.move search
('company_id', '=', self.company_id.id),
```

**Check 3 — `action_confirm()` never returns a wizard**

```python
# ❌ WRONG — action_confirm() returning a wizard breaks Odoo's standard flow
def action_confirm(self):
    if condition:
        return {'type': 'ir.actions.act_window', ...}  # NEVER DO THIS

# ✅ CORRECT — action_confirm() only raises or calls super()
def action_confirm(self):
    for order in self:
        if order.overdue_amount > 0 and not order.exception_granted:
            raise UserError(_('Cannot confirm. Use the "Grant Exception" button first.'))
    return super().action_confirm()

# ✅ CORRECT — a separate button in the view opens the wizard
def action_open_exception_wizard(self):
    return {
        'type': 'ir.actions.act_window',
        'res_model': 'my.exception.wizard',
        'view_mode': 'form',
        'target': 'new',
        'context': {'default_order_id': self.id},
    }
```

The view has two separate buttons:
```xml
<button name="action_open_exception_wizard" string="Grant Exception" type="object"
        groups="my_module.group_credit_manager"
        invisible="exception_granted or overdue_amount == 0"/>
<button name="action_confirm" string="Confirm" type="object"
        invisible="state != 'draft'"/>
```

- [ ] Domain uses `child_of` not `=` for partner queries
- [ ] Every `account.move` search includes `company_id` filter
- [ ] `action_confirm()` does not return a wizard — separate button used instead
- [ ] Every override calls `super()`
- [ ] No `write({'state': '...'})` in generated code
