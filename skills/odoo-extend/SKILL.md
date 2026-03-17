---
name: odoo-extend
description: Designs a technical extension for an existing Odoo model. Use when the user knows exactly which model they want to extend and what they need to add or change. Returns complete Python code, XML views, manifest, and file tree ready for a developer to use.
---

# Odoo Model Extender

Use this skill when the user wants to extend a specific Odoo model with new fields, methods, or view changes.

## What the user provides

- The base module to extend (e.g. `sale`, `account`, `stock`)
- The model to extend (e.g. `sale.order`, `account.move`)
- What they need: new fields, a method override, a UI change, a constraint
- The Odoo version

## What to generate

Produce complete, copy-paste ready code for a new extension module.

### Module naming
Name the extension module as: `{base_module}_{feature}` (e.g. `sale_credit_control`, `account_dte`)

### 1. `__manifest__.py`
```python
{
    'name': '...',
    'version': '19.0.1.0.0',
    'depends': ['{base_module}'],
    'data': ['security/ir.model.access.csv', 'views/...xml'],
    'license': 'LGPL-3',
}
```

### 2. `models/{model_snake}.py`
- Use `_inherit = '{model.name}'`
- New fields in `snake_case`
- Class names in `PascalCase`
- Every override calls `super()`
- No `write({'state': '...'})` — use action methods

### 3. `views/{model_snake}_views.xml`
- Always use `inherit_id` + `xpath`
- Positions: `after`, `before`, `inside` only — never `replace` without justification
- Conditional visibility using `invisible=` attribute (Odoo 17+ syntax, not `attrs`)

### 4. `security/ir.model.access.csv`
Only needed if the extension creates a new model (`_name`, not just `_inherit`).

### 5. File tree
Show the complete directory structure of the new module.

### 6. Warnings
List any specific risks for this extension: fields that will recompute, potential conflicts with other modules, migration notes.

## Rules

- Minimum viable extension — only add what was asked, nothing more
- Never edit source files of the base module — always use `_inherit`
- `store=True` on computed fields requires `@api.depends`
- Multi-company: filter queries by `company_id`
- Partner credit queries: use `commercial_partner_id` + `child_of`
- `action_confirm()` and similar action methods: only raise `UserError` or call `super()` — never return a wizard from them
