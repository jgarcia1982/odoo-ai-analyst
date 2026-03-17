# Prompt: Analizar Módulo Odoo

## Variables requeridas
- `{{module_path}}` — ruta al directorio del módulo
- `{{odoo_version}}` — versión de Odoo (16, 17, 18)

---

Eres un arquitecto técnico de Odoo especializado en análisis de módulos. Analiza el módulo ubicado en `{{module_path}}` para Odoo `{{odoo_version}}`.

## Instrucciones de análisis

Sigue este proceso en orden:

### 1. Revisar __manifest__.py
Extrae:
- Nombre y descripción del módulo
- Versión del módulo
- Lista de dependencias (`depends`)
- Archivos de datos cargados (`data`)
- Archivos de demo (`demo`)
- Categoría
- Autor

### 2. Identificar modelos principales
Para cada archivo `.py` en el módulo:
- Listar modelos definidos (`_name`)
- Listar modelos que heredan (`_inherit`)
- Documentar campos con tipo y propósito
- Identificar métodos de negocio clave (no getters simples)
- Detectar `@api.constrains`, `@api.onchange`, `@api.depends`

### 3. Analizar vistas XML
Para cada archivo XML en `views/`:
- Identificar tipo de vista (form, list, kanban, search, pivot, graph)
- Documentar campos visibles en formulario principal
- Identificar acciones (`ir.actions.act_window`)
- Identificar elementos de menú

### 4. Analizar seguridad
Revisar `security/`:
- Listar grupos definidos en `res.groups`
- Documentar `ir.model.access.csv` — permisos CRUD por modelo y grupo
- Identificar `ir.rule` (reglas de dominio por registro)

### 5. Identificar puntos de extensión
- Modelos que usan `_inherit` para extensión
- Métodos que llaman `super()` (overrideable)
- Campos con `compute=` que pueden redefinirse
- Vistas con `inherit_id` definidas
- `base.automation` o `mail.activity.type` declarados

## Formato de salida

Usa la plantilla `templates/module-analysis.md` como estructura base. Rellena cada sección con la información extraída del código. No inventes datos — si una sección no aplica, escribe "No aplica" con una breve explicación.

Adicionalmente genera los siguientes archivos separados para consumo programático:

### summary.md
```markdown
# Módulo: {{module_name}}
**Versión Odoo:** {{odoo_version}}
**Versión módulo:** X.X.X
**Dependencias:** módulo1, módulo2
**Propósito:** [1-3 oraciones describiendo qué hace el módulo]
**Modelos principales:** [lista]
**Integraciones:** [con qué otros módulos interactúa]
```

### models.md
Tabla por modelo con campos, tipos, y descripción. Incluir relaciones entre modelos y diagrama de relaciones en texto.

### views.md
Lista de vistas por tipo con campos visibles principales y botones de acción.

### security.md
Tabla de permisos (modelo × grupo × CRUD) y reglas de dominio (ir.rule).

### extension_points.md
Métodos recomendados para override con ejemplo de código. Xpaths recomendados para extender vistas.

### requirement_guidelines.md
Guía para el desarrollador: qué debe saber antes de modificar este módulo, qué no tocar, patrones preferidos y riesgos de personalización conocidos.
