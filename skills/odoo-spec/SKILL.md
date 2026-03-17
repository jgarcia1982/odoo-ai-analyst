---
name: odoo-spec
description: Generates a technical specification for an Odoo development requirement without needing the full module atlas. Use for quick specs involving modules not yet in the knowledge base, or when the user needs a fast structured output from an informal requirement.
---

# Odoo Spec Generator

Use this skill when the user has a functional requirement for Odoo and needs a technical spec, but the modules involved are not `sale`, `account`, or `stock`.

For requirements involving `sale`, `account`, or `stock` use `/odoo-requirement-analyst` instead — it has a richer knowledge base for those modules.

## What the user provides

- The functional requirement in plain language
- The Odoo version (default: 19)
- Optional: installed modules, industry, known constraints

## Process

### 1. Classify the change type
One of: New module / Extension / Flow modification / Integration / Report / Automation

### 2. Identify affected modules and models
List which standard Odoo modules are involved and which models will be touched.

### 3. Design the minimum solution
For each affected model:
- New fields: technical name (snake_case), ORM type, constraints
- Method overrides: which method and why
- View changes: which view, what xpath
- Security: new groups if needed

### 4. Generate `spec.md`

Use this exact structure:

```
# Especificación técnica: [name]

**Tipo:** [classification]
**Complejidad:** [Baja / Media / Alta]
**Módulos afectados:** [list]

## Resumen ejecutivo
[2-3 sentences]

## Módulo a crear
- Nombre: `base_feature`
- Depende de: [list]

## Cambios por modelo
[Fields table + Python code for overrides]

## Vistas
[XML xpaths ready to copy]

## Archivos a crear
[Directory tree]

## Flujo de datos
[ASCII diagram if data moves between models]

## Casos límite
[Edge cases table]

## Puntos de riesgo
[Risk table with mitigation]

## Complejidad: [level]
[Justification: count of models/fields/overrides]
```

## Mandatory rules

- Field names: `snake_case`
- Class names: `PascalCase`
- Every override calls `super()`
- Xpaths use `position='after|before|inside'` — never `replace` without justification
- Module version: `19.0.1.0.0`
- Never modify standard module files — always `_inherit`
- `store=True` requires `@api.depends`
- Multi-company queries always filter by `company_id`
- `action_confirm()` and similar methods: only raise `UserError` or call `super()` — never return a wizard
