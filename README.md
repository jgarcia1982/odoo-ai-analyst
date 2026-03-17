# odoo-ai-analyst

Fuente de verdad para análisis técnico de Odoo con agentes de IA. Este repositorio alimenta al agente `odoo-analyst` en OpenClaw.

## Estructura

```
odoo-ai-analyst/
├── knowledge/          # Atlas técnico de módulos Odoo por versión
│   ├── v16/
│   ├── v17/
│   └── v18/
├── prompts/            # Plantillas de análisis y generación de specs
├── skills/             # Skills desplegables en ~/.openclaw/skills/
└── agents/             # Definiciones de agentes para OpenClaw
```

## Flujo de trabajo

```
Requerimiento funcional
        ↓
  odoo-analyst (OpenClaw)
        ↓
  [knowledge/ + prompts/]
        ↓
  Especificación técnica
        ↓
  proposal-architect (OpenClaw)
        ↓
  Propuesta lista para desarrollador
```

## Despliegue de skills

```bash
cp skills/*.json ~/.openclaw/skills/
```

## Versiones de Odoo cubiertas

| Versión | Estado       |
|---------|-------------|
| v16     | Soporte LTS |
| v17     | Activa      |
| v18     | Preview     |
