# Proyecto
Este proyecto crea agentes de IA que analizan arquitectura de Odoo y generan especificaciones técnicas para desarrolladores. Es la fuente de verdad para los skills y agentes desplegados en OpenClaw.

# Objetivo
Ayudar a convertir requerimientos funcionales en especificaciones técnicas optimizadas para desarrollo en Odoo.

# Estructura del repositorio

```
odoo-ai-analyst/
├── knowledge/      # Atlas técnico de módulos Odoo por versión (v16, v17, v18)
├── prompts/        # Plantillas de análisis: analyze-module, generate-spec, extend-model
├── skills/         # Skills JSON desplegables en ~/.openclaw/skills/
└── agents/         # Definiciones de agentes: odoo-analyst.md
```

# Reglas

Cuando analices módulos de Odoo debes:

1. Revisar __manifest__.py
2. Identificar dependencias
3. Identificar modelos principales
4. Analizar vistas XML
5. Analizar seguridad
6. Identificar puntos de extensión

Cuando agregues conocimiento al atlas (`knowledge/`):
- Organizar por versión: `knowledge/v16/`, `knowledge/v17/`, `knowledge/v18/`
- Seguir el formato de `knowledge/v17/core/base.md` como plantilla
- Actualizar el `index.md` de la versión correspondiente

Cuando crees o modifiques skills (`skills/`):
- El formato debe ser JSON compatible con OpenClaw
- Incluir `name`, `description`, `version`, `prompt`, `parameters`, `output`
- Probar el prompt antes de publicar el skill

# Resultado esperado de un análisis de módulo

- summary.md
- models.md
- views.md
- security.md
- extension_points.md
- requirement_guidelines.md

# Resultado esperado de una especificación técnica

- spec.md (con nombre técnico del módulo, modelos, campos, vistas, seguridad, árbol de archivos, complejidad)