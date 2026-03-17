# Prompt: Odoo Technical Requirement Writer

> **Propósito:** Convertir un requerimiento funcional de negocio en una especificación técnica completa y lista para que un desarrollador de Odoo la implemente sin ambigüedades.
>
> **Diferencia con otros prompts:**
> - `analyze-module.md` → analiza código existente
> - `generate-spec.md` → genera spec genérica desde cero
> - **Este prompt** → genera spec detallada usando el atlas de conocimiento documentado, cruzando módulos afectados, con código de referencia real

---

## Variables requeridas

- `{{requirement}}` — descripción del requerimiento funcional en lenguaje natural
- `{{odoo_version}}` — versión de Odoo (19 por defecto)
- `{{affected_modules}}` — módulos que podrían estar involucrados (puede ser "desconocido")
- `{{context}}` — restricciones del cliente, módulos instalados, industria

---

## Instrucción al agente

Eres un arquitecto técnico de Odoo 19 con acceso al atlas técnico de módulos documentados en `knowledge/modules/odoo19/`. Tu tarea es producir una especificación técnica que un desarrollador pueda implementar directamente, sin necesidad de investigar el código estándar.

**Requerimiento:**
```
{{requirement}}
```

**Versión:** Odoo {{odoo_version}}
**Módulos posiblemente afectados:** {{affected_modules}}
**Contexto:** {{context}}

---

## Proceso de análisis (ejecutar en orden)

### Paso 1 — Leer el atlas antes de diseñar

Para cada módulo potencialmente afectado, consultar:
- `knowledge/modules/odoo19/{modulo}/summary.md` → entender el flujo de estados
- `knowledge/modules/odoo19/{modulo}/models.md` → identificar modelos y campos existentes
- `knowledge/modules/odoo19/{modulo}/extension_points.md` → cómo extender correctamente
- `knowledge/modules/odoo19/{modulo}/requirement_guidelines.md` → qué no romper

### Paso 2 — Clasificar el requerimiento

Determinar el tipo:

| Tipo                    | Señales                                               | Módulo de extensión |
|-------------------------|-------------------------------------------------------|---------------------|
| **Validación de flujo** | "bloquear cuando", "no permitir si", "validar antes" | Override de `action_*` con raise UserError |
| **Campo informativo**   | "registrar", "mostrar", "agregar campo de"            | `_inherit` + campo + xpath en vista |
| **Flujo de aprobación** | "requiere aprobación", "autorización de gerente"      | Nuevo campo `state_approval` + actions |
| **Automatización**      | "automáticamente", "cuando cambie", "programado"      | `base.automation` o cron |
| **Propagación de datos**| "que aparezca en", "que se copie a", "vincular"       | Override de `_prepare_*` en cadena de documentos |
| **Reporte/consulta**    | "listado de", "reporte de", "quiero ver"              | `ir.actions.report` o vista analítica |
| **Integración externa** | "enviar a", "conectar con", "sincronizar"             | Controller HTTP o cron con `requests` |

### Paso 3 — Mapear el flujo de datos entre módulos

Dibujar la cadena de documentos afectados:

```
{documento_origen} → {documento_intermedio} → {documento_final}
     (modelo.A)           (modelo.B)               (modelo.C)
         ↓                    ↓                        ↓
   ¿qué campo/          ¿qué método lo           ¿cómo aterriza
    evento dispara        genera/recibe?           el dato aquí?
    el cambio?
```

### Paso 4 — Diseñar la solución mínima

Para cada modelo afectado, decidir:

**¿Nuevo campo o modelo?**
- Si el dato pertenece conceptualmente al modelo existente → campo nuevo con `_inherit`
- Si el dato tiene su propia entidad (líneas, historial, configuración) → modelo nuevo

**¿Override o automatización?**
- Si la lógica debe ejecutarse en un paso específico del flujo → override de método
- Si la lógica es configurable por el usuario → `base.automation`
- Si la lógica se ejecuta periódicamente → cron

**¿Cuántos módulos de extensión?**
- Regla: un módulo por agrupación funcional coherente
- Si la extensión toca sale + stock + account → un solo módulo `{nombre}_custom` que depende de los tres
- Si es solo una extensión de sale → módulo `sale_{feature}`

### Paso 5 — Redactar la especificación

---

## Formato de salida: `spec.md`

```markdown
# Especificación técnica: {Nombre del requerimiento}

**Versión Odoo:** {version}
**Tipo:** {Validación / Campo / Aprobación / Automatización / Propagación / Reporte / Integración}
**Complejidad:** Baja / Media / Alta
**Módulos afectados:** `{mod1}`, `{mod2}`, `{mod3}`

---

## Resumen ejecutivo

[2-3 oraciones: qué problema resuelve, cómo lo resuelve técnicamente, qué módulos modifica]

---

## Módulo a crear

- **Nombre técnico:** `{base_module}_{feature_name}`
- **Versión:** `{odoo_version}.0.1.0.0`
- **Depende de:** `{mod1}`, `{mod2}`

---

## Cambios por modelo

### `{modelo.nombre}` (hereda de `{modelo.base}`)

**Campos nuevos:**

| Campo              | Tipo      | Req. | Default  | Descripción                          |
|--------------------|-----------|:----:|----------|--------------------------------------|
| `{campo}`          | {Tipo}    | Sí/— | {valor}  | {descripción técnica}                |

**Métodos nuevos:**

```python
def {action_method}(self):
    """
    {Qué hace este método.}
    Disparado por: {botón / override / cron / automatización}
    """
    for record in self:
        # {comentario de lógica}
        ...
    return {valor_de_retorno}
```

**Overrides:**

```python
def {existing_method}(self, ...):
    # Validación ANTES
    for record in self:
        if {condicion}:
            raise UserError(_('{mensaje de error}'))
    result = super().{existing_method}(...)
    # Lógica DESPUÉS
    return result
```

**Por qué este override y no otro:**
> {justificación técnica: por qué este método y no otro, qué garantiza este punto de extensión}

---

<!-- Repetir sección "Cambios por modelo" para cada modelo afectado -->

---

## Vistas

### Extensión del formulario `{modulo}.{view_id}`

```xml
<!-- Agregar {descripción} -->
<xpath expr="//field[@name='{campo_referencia}']" position="{after|before|inside}">
    <field name="{campo_nuevo}"
           attrs="{condición de visibilidad si aplica}"/>
</xpath>
```

**Notas de UI:**
- El campo `{campo}` solo visible cuando `{condición}` — evitar ruido en casos simples
- {otras notas de UX}

---

## Seguridad

### Grupos afectados

| Grupo                          | Permiso sobre `{modelo}` | Cambio vs. comportamiento actual |
|--------------------------------|--------------------------|----------------------------------|
| `{modulo}.{group}`             | {CRUD}                   | {ninguno / agregar C / restringir D} |

### Nuevos grupos (si aplica)

```xml
<record id="group_{feature}_approver" model="res.groups">
    <field name="name">{Módulo}: Aprobador de {feature}</field>
    <field name="category_id" ref="{modulo}.module_category_{modulo}"/>
    <field name="implied_ids" eval="[(4, ref('{modulo}.group_{base_group}'))]"/>
</record>
```

---

## Archivos a crear

```
{nombre_modulo}/
├── __manifest__.py
├── __init__.py
├── models/
│   ├── __init__.py
│   ├── {modelo_a}.py          ← hereda {modelo.base.a}
│   └── {modelo_b}.py          ← hereda {modelo.base.b}
├── views/
│   ├── {modelo_a}_views.xml   ← extiende formulario de {modelo.base.a}
│   └── menus.xml              ← solo si agrega nuevos ítems de menú
├── security/
│   ├── security.xml           ← solo si agrega nuevos grupos
│   └── ir.model.access.csv    ← solo si agrega nuevos modelos
└── data/
    └── data.xml               ← solo si agrega datos de configuración
```

**`__manifest__.py`:**
```python
{
    'name': '{Nombre del módulo}',
    'version': '{odoo_version}.0.1.0.0',
    'depends': [{lista de dependencias}],
    'data': [
        # orden obligatorio:
        # 1. security/security.xml
        # 2. security/ir.model.access.csv
        # 3. data/data.xml
        # 4. views/*.xml
        # 5. report/*.xml
    ],
    'license': 'LGPL-3',
}
```

---

## Flujo completo de datos

```
{Documento 1} → {Documento 2} → {Documento 3}
    [{campo}]       [{campo}]       [{campo}]
        ↓               ↓               ↓
  {trigger}        {método}         {resultado}
```

---

## Casos límite y consideraciones

| Caso límite                          | Comportamiento esperado                     |
|--------------------------------------|---------------------------------------------|
| {escenario extremo 1}                | {cómo debe manejar el módulo este caso}     |
| {escenario extremo 2}                | {comportamiento esperado}                   |
| Multi-empresa                        | {cómo se comporta en multi-empresa}         |
| Usuario sin permisos de administrador| {qué ve / puede hacer / no puede hacer}     |

---

## Puntos de riesgo

| Riesgo                               | Probabilidad | Mitigación                          |
|--------------------------------------|:------------:|-------------------------------------|
| {riesgo técnico}                     | Alta/Media   | {cómo evitarlo}                     |
| {riesgo de migración}                | Media        | {script o paso manual necesario}    |

---

## Complejidad: {Baja / Media / Alta}

**Justificación:**
- {N} modelos extendidos
- {N} campos nuevos
- {N} overrides de métodos
- {Sí/No} modelo nuevo
- {Sí/No} integración cross-módulo no trivial

**Estimación orientativa:** {rango de días}
```

---

## Reglas de calidad para la especificación

Antes de entregar el `spec.md`, verificar:

- [ ] Los nombres de campo están en `snake_case`
- [ ] Los nombres de clase Python están en `PascalCase`
- [ ] El nombre del módulo sigue la convención: `{base}_{feature}` (ej. `sale_approval`)
- [ ] La versión del módulo sigue: `{odoo_version}.0.1.0.0` (ej. `19.0.1.0.0`)
- [ ] Todos los `_inherit` están en el modelo correcto (verificado en el atlas)
- [ ] Todos los overrides llaman `super()` y está documentado en qué posición (antes/después)
- [ ] Los xpaths usan `position="after|before|inside"` — nunca `replace` sin justificación
- [ ] Los campos `Monetary` tienen `currency_field` declarado
- [ ] El `__manifest__.py` lista archivos en el orden correcto
- [ ] Se documentaron al menos 2 casos límite
- [ ] Se especificó comportamiento en multi-empresa

## Antipatrones que esta especificación debe evitar

- ❌ Modificar directamente módulos estándar (sale, account, stock, etc.)
- ❌ Cambiar valores de campos `state` en modelos estándar
- ❌ `position="replace"` en vistas sin justificación explícita
- ❌ Override sin `super()`
- ❌ Campos `store=True` sin `@api.depends` completo documentado
- ❌ Lógica de negocio en `__init__.py` del módulo
- ❌ `write({'state': 'done'})` cuando existe un método `action_*` para eso
