# Skills — OpenClaw

Skills desplegables en `~/.openclaw/skills/`. Cada skill es un archivo JSON que define un comando reutilizable para el agente.

## Despliegue

```bash
# Desde el VPS donde corre OpenClaw
cp skills/*.json ~/.openclaw/skills/

# O sincronizar desde este repo
rsync -av skills/*.json user@vps:~/.openclaw/skills/
```

## Skills disponibles

| Archivo                          | Comando                       | Descripción                                                   |
|----------------------------------|-------------------------------|---------------------------------------------------------------|
| `odoo-analyze.json`              | `/odoo-analyze`               | Analiza un módulo Odoo y genera documentación                 |
| `odoo-spec.json`                 | `/odoo-spec`                  | Genera spec técnica desde requerimiento funcional             |
| `odoo-extend.json`               | `/odoo-extend`                | Diseña extensión de modelo existente                          |
| `odoo-requirement-analyst.json`  | `/odoo-requirement-analyst`   | Analiza requerimientos cross-módulo (sale+account+stock)      |

## Skill principal: `odoo-requirement-analyst`

El skill más completo. Usa el atlas técnico documentado para generar specs que:
- Identifican qué modelos se afectan en cada módulo
- Proponen el tipo de cambio correcto (override, campo, aprobación, etc.)
- Incluyen código Python y XML listo para usar
- Documentan la cadena de propagación de datos entre documentos
- Señalan riesgos y casos límite

**Cuándo usar cada skill:**

| Necesito...                                  | Skill                          |
|----------------------------------------------|--------------------------------|
| Entender cómo funciona un módulo existente   | `/odoo-analyze`                |
| Una spec simple de extensión de un modelo    | `/odoo-extend`                 |
| Una spec desde un req. funcional informal    | `/odoo-requirement-analyst`    |
| Una spec genérica sin contexto del atlas     | `/odoo-spec`                   |

## Formato de skill

```json
{
  "name": "nombre-del-skill",
  "description": "Qué hace el skill",
  "version": "1.0.0",
  "prompt": "Instrucción al agente...",
  "parameters": [
    {
      "name": "param",
      "description": "Qué es este parámetro",
      "required": true
    }
  ]
}
```
