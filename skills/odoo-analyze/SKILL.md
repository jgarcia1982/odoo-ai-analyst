---
name: odoo-analyze
description: Analyzes an Odoo module from its source code and generates complete technical documentation. Use when you have access to a module's directory and need to understand what it does, which models it defines, how security is configured, and where it can be extended.
---

# Odoo Module Analyzer

Use this skill when the user provides a path to an Odoo module directory and needs full technical documentation of it.

## What to do

The user will provide:
- A path to the module directory (e.g. `/odoo/addons/sale`)
- The Odoo version (e.g. `19`)

Follow this process in order:

### 1. Read the manifest
Read `__manifest__.py` and extract: module name, version, dependencies, and data files declared.

### 2. Analyze models
Read all `.py` files inside `models/`. For each class found:
- If it has `_name` → it's a new model
- If it has `_inherit` → it's an extension of an existing model
- List all fields with their type and any notable attributes (`required`, `compute`, `related`, `tracking`)
- List methods that contain business logic (not just CRUD)

### 3. Analyze views
Read all `.xml` files inside `views/`. For each view record:
- Note the view type (form, list, kanban, search, qweb)
- Note the model it belongs to
- Note the main fields or widgets exposed

### 4. Analyze security
Read `security/ir.model.access.csv` and any `.xml` files in `security/`. Extract:
- Groups defined
- CRUD permissions per model per group
- Domain-based record rules if any

### 5. Identify extension points
Look for:
- Methods that call `super()` → can be overridden
- Computed fields with `@api.depends` → logic can be extended
- Views with `inherit_id` → already extended, note the pattern

## Output

Generate these 6 files in the current working directory:

**summary.md** — Purpose, version, dependencies, list of main models

**models.md** — Table per model: field name, type, required/compute/related flags, description

**views.md** — List of views per model with type and main fields shown

**security.md** — Groups defined, CRUD matrix per model, record rules

**extension_points.md** — Methods safe to override with example pattern, views already extended

**requirement_guidelines.md** — Rules a developer must follow before modifying this module (antipatterns, state fields not to touch, methods that must call super, etc.)

## Rules

- Only document what actually exists in the code — never invent fields or methods
- If a file is missing (e.g. no `security/` folder), note it as absent rather than skipping silently
- Use the exact technical names from the source code
