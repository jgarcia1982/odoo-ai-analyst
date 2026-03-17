# Knowledge Base — Atlas Técnico de Odoo

Documentación técnica de módulos Odoo organizada por versión. Esta base de conocimiento es consumida por el agente `odoo-analyst`.

## Estructura por versión

```
knowledge/
├── v16/
│   ├── index.md              # Mapa completo de módulos v16
│   └── core/                 # Módulos del núcleo
│       ├── base.md
│       ├── mail.md
│       ├── account.md
│       └── ...
├── v17/
│   ├── index.md
│   └── core/
└── v18/
    ├── index.md
    └── core/
```

## Formato de cada módulo

Cada archivo `<modulo>.md` contiene:

- **Propósito**: qué resuelve el módulo
- **Modelos principales**: lista con campos clave
- **Vistas**: tipos y nombres de vistas expuestas
- **Seguridad**: grupos y reglas de acceso
- **Puntos de extensión**: hooks, herencia sugerida, overrides comunes
- **Dependencias**: módulos requeridos y opcionales
- **Notas de versión**: cambios relevantes respecto a la versión anterior

## Plantilla de análisis

Cada entrada del atlas se basa en la plantilla:
→ [`templates/module-analysis.md`](../templates/module-analysis.md)

## Convenciones

- Nombre de archivo = nombre técnico del módulo (ej. `account_move.md`)
- Los campos se documentan como `nombre (tipo) — descripción`
- Los modelos se referencian como `module.model_name`
- Las secciones que no aplican se marcan `No aplica` con explicación breve
