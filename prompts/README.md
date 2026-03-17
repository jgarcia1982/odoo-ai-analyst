# Prompts — Plantillas de Análisis

Plantillas reutilizables para los agentes. Cada prompt está optimizado para una tarea específica del ciclo de análisis y especificación de Odoo.

## Índice

| Archivo                              | Propósito                                                        | Usado por skill              |
|--------------------------------------|------------------------------------------------------------------|------------------------------|
| `analyze-module.md`                  | Analizar un módulo Odoo existente desde su código fuente         | `/odoo-analyze`              |
| `generate-spec.md`                   | Generar especificación técnica genérica desde requerimiento      | `/odoo-spec`                 |
| `extend-model.md`                    | Diseñar extensión de modelo existente con código listo           | `/odoo-extend`               |
| `odoo_technical_requirement_writer.md` | Generar spec cross-módulo usando el atlas técnico documentado  | `/odoo-requirement-analyst`  |
| `spec-generation-guide.md`           | Guía de proceso completo para generar specs (referencia humana)  | —                            |
| `review-security.md`                 | Auditar seguridad de módulo                                      | pendiente                    |
| `estimate-effort.md`                 | Estimar esfuerzo de desarrollo                                   | pendiente                    |

## Jerarquía de prompts

```
Requerimiento funcional
        │
        ├─ Simple (1 módulo)    → extend-model.md
        │
        ├─ Mediano (1-2 módulos)→ generate-spec.md
        │
        └─ Complejo (2+ módulos,
           sale/account/stock)  → odoo_technical_requirement_writer.md
                                  (usa knowledge/modules/odoo19/ como contexto)
```

## Uso con OpenClaw

Los prompts se referencian desde los skills en `skills/*.json` mediante el campo `prompt_file`.

## Variables disponibles

Todos los prompts soportan estas variables de sustitución:

- `{{module_name}}` — nombre técnico del módulo (ej. `sale_order_custom`)
- `{{odoo_version}}` — versión de Odoo (ej. `17`)
- `{{requirement}}` — requerimiento funcional en texto libre
- `{{base_module}}` — módulo base a extender
- `{{context}}` — contexto adicional del cliente
