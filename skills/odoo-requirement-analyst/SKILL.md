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

Before writing the final spec, verify every item in this checklist against your generated code. Fix any violation — do not just mention it as a risk or consideration.

- [ ] Every `account.move` query includes `('company_id', '=', order.company_id.id)`
- [ ] Partner credit queries use `('partner_id', 'child_of', partner.commercial_partner_id.id)` — never `('partner_id', '=', partner.id)`
- [ ] `action_confirm()` only raises `UserError` or calls `super()` — it never returns a wizard action
- [ ] If user input is needed before confirming (exception note, approval reason), a **separate button** in the view opens the wizard — not `action_confirm()`
- [ ] Every override of `action_confirm()`, `action_post()`, or `button_validate()` calls `super()`
- [ ] No `write({'state': '...'})` anywhere in the generated code
