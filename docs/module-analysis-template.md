# Plantilla maestra — Análisis de módulo Odoo

> Esta plantilla define la estructura **obligatoria** de los 6 archivos que componen cada análisis de módulo en el atlas técnico. Cada sección marcada con `[REQUERIDA]` debe estar presente. Las marcadas `[CONDICIONAL]` aplican solo cuando el módulo las necesita.
>
> **Referencia:** Los análisis de `sale`, `account` y `stock` son las implementaciones de referencia de esta plantilla.

---

## Archivos del análisis

```
knowledge/modules/{version}/{modulo}/
├── summary.md              ← Propósito, dependencias, flujos de estado, integraciones
├── models.md               ← Modelos ORM con campos, relaciones y métodos
├── views.md                ← Vistas, formularios, menús y búsquedas
├── security.md             ← Grupos, permisos CRUD, reglas de dominio
├── extension_points.md     ← Cómo extender: overrides, xpaths, código
└── requirement_guidelines.md ← Guía para desarrolladores antes de tocar el módulo
```

---

## 1. `summary.md`

```markdown
# Módulo: `{nombre}` — Odoo {version}

> **Versión del módulo:** {X.X}
> **Categoría:** {Categoría/Subcategoría}
> **Licencia:** LGPL-3 / LGPL-3+ / OPL-1
> **Fuente:** Odoo Community / Enterprise

## Propósito                                          [REQUERIDA]

[2-3 oraciones. Primera: qué proceso de negocio cubre. Segunda: qué ciclo gestiona. Tercera (opcional): qué casos de uso principales habilita.]

## Dependencias                                       [REQUERIDA]

| Módulo       | Rol en la dependencia                    |
|--------------|------------------------------------------|
| `{modulo}`   | {por qué es necesario}                   |

> **Módulos que enriquecen `{nombre}`:** lista de módulos opcionales que agregan funcionalidad cuando están instalados

## Modelos principales                                [REQUERIDA]

| Modelo        | Descripción                              |
|---------------|------------------------------------------|
| `{modelo}`    | {descripción en una línea}               |

## Flujo de estados del modelo principal              [REQUERIDA]

```
{estado_1} ({label})
    ↓ {method_name}()
{estado_2} ({label})
    ↓ {method_name}()
{estado_n}
```

## {Tablas de dominio específicas del módulo}         [CONDICIONAL]

[Agregar si el módulo tiene enumeraciones/configuraciones clave para entender su comportamiento:
- account: move_type, payment_state
- stock: reception_steps, delivery_steps, location usage
- sale: invoice_status]

## Integraciones clave                                [REQUERIDA]

- **`{modelo_externo}`** — {qué genera o recibe, via qué método}
```

---

## 2. `models.md`

```markdown
# Modelos — `{nombre}` — Odoo {version}

## Diagrama de relaciones                             [REQUERIDA]

[Diagrama ASCII mostrando las relaciones principales entre modelos del módulo
y sus conexiones con modelos externos. Usar flechas → y etiquetas (One2many), (Many2one)]

```
{modelo.principal}
    ├── campo_id → {modelo.externo}
    ├── linea_ids ──(One2many)──→ {modelo.linea}
    └── ...
```

---

## `{modelo.nombre}`                                  [REQUERIDA por cada modelo principal]

```
Tabla BD : {tabla_bd}
Mixins   : {mixin1}, {mixin2}    ← omitir si no tiene mixins
Índices  : {campo} (si hay índices relevantes)
```

### Campos de {categoría}                             [REQUERIDA — organizar por categoría semántica]

| Campo         | Tipo      | Req. | Descripción                              |
|---------------|-----------|:----:|------------------------------------------|
| `{campo}`     | {Tipo}    | Sí/— | {descripción}                            |

[Categorías sugeridas: identidad y estado / relaciones / montos / fechas / configuración / computed]

### Métodos clave                                     [REQUERIDA]

| Método              | Tipo      | Descripción                              |
|---------------------|-----------|------------------------------------------|
| `{metodo}()`        | Acción    | {qué hace}                               |
| `_{metodo}()`       | Compute   | {qué calcula}                            |
| `_{metodo}()`       | Negocio   | {lógica de negocio que implementa}       |

[Tipos: Acción (botón de UI), Compute (campo computado), Negocio (lógica interna), Hook (disparado automáticamente), Cron]
```

---

## 3. `views.md`

```markdown
# Vistas — `{nombre}` — Odoo {version}

## Resumen de vistas                                  [REQUERIDA]

| ID XML                     | Tipo     | Modelo     | Descripción                  |
|----------------------------|----------|------------|------------------------------|
| `{modulo}.{view_id}`       | form     | `{modelo}` | {descripción}                |

[Tipos: form, list, kanban, search, pivot, graph, calendar, activity, map]

---

## {Dashboard o vista destacada}                      [CONDICIONAL — si existe dashboard kanban]

[Describir las tarjetas, métricas en tiempo real y acciones disponibles]

---

## Formulario principal: `{modulo}.{view_id}`         [REQUERIDA]

### Header

**Barra de estado:**
```
[{estado_1}] → [{estado_2}] → [{estado_n}]
```

**Botones de acción:**

| Botón          | Método            | Visible cuando                  |
|----------------|-------------------|---------------------------------|
| {label}        | `{method}()`      | `{dominio de visibilidad}`      |

### Sección principal

| Campo          | Editable          | Notas                           |
|----------------|-------------------|---------------------------------|
| `{campo}`      | {condición}       | {observaciones}                 |

### Pestaña: {nombre}                                 [REQUERIDA por cada pestaña]

[Describir campos visibles, widgets especiales, botones inline]

---

## Vista de búsqueda                                  [REQUERIDA]

### Filtros predefinidos

| Filtro          | Dominio                          |
|-----------------|----------------------------------|
| {nombre}        | `[({campo}, {op}, {valor})]`     |

### Agrupaciones predefinidas

| Agrupar por     | Campo          |
|-----------------|----------------|
| {label}         | `{campo}`      |

---

## Menú: `{archivo_menus.xml}`                        [REQUERIDA]

```
{App raíz} (raíz)
├── {Sección}
│   ├── {Ítem}    → {acción o modelo}
│   └── ...
└── Configuración    [grupo: {grupo}]
```
```

---

## 4. `security.md`

```markdown
# Seguridad — `{nombre}` — Odoo {version}

## Grupos del módulo                                  [REQUERIDA]

### Grupos de acceso principal

[Si hay jerarquía, mostrarla en árbol ASCII]
```
{grupo_superior}
    └── {grupo_base}
```

| ID XML                    | Nombre visible    | Qué puede hacer          |
|---------------------------|-------------------|--------------------------|
| `{modulo}.{group_id}`     | {nombre UI}       | {descripción del rol}    |

### Grupos de configuración opcional                  [CONDICIONAL — si existen]

[Grupos que habilitan funcionalidades opcionales, no niveles de acceso]

| ID XML                    | Nombre visible    | Qué habilita             |
|---------------------------|-------------------|--------------------------|
| `{modulo}.{group_id}`     | {nombre}          | {funcionalidad}          |

---

## Permisos CRUD por modelo                          [REQUERIDA]

### `{modelo.nombre}`

| Grupo                     | Create | Read | Write | Delete |
|---------------------------|:------:|:----:|:-----:|:------:|
| `{modulo}.{group}`        |   ✓    |  ✓   |   ✓   |   ✓    |

[Incluir todos los modelos principales. Nota especial si algún permiso es inusual]

---

## Reglas de dominio (`ir.rule`)                      [REQUERIDA]

### Multi-empresa

| Regla               | Modelo      | Dominio                           |
|---------------------|-------------|-----------------------------------|
| `{rule_xmlid}`      | `{modelo}`  | `[('company_id', 'in', ...)]`     |

### {Otras categorías de reglas}                      [CONDICIONAL]

[Portal, propietario, grupo específico]

---

## Campos con visibilidad restringida por grupo       [CONDICIONAL — si existen]

| Campo / Sección     | Grupo requerido       | Restricción            |
|---------------------|-----------------------|------------------------|
| `{campo}`           | `{modulo}.{group}`    | invisible / readonly   |
```

---

## 5. `extension_points.md`

```markdown
# Puntos de extensión — `{nombre}` — Odoo {version}

## Modelos recomendados para extender                 [REQUERIDA]

| Modelo       | Cuándo extender                               |
|--------------|-----------------------------------------------|
| `{modelo}`   | {caso de uso típico de extensión}             |

---

## Métodos recomendados para override                [REQUERIDA]

[Por cada modelo principal con métodos extensibles]

### `{modelo.nombre}`

#### `{method_name}()` — {qué personaliza}

```python
class {ClassName}(models.Model):
    _inherit = '{modelo.nombre}'

    def {method_name}(self, ...):
        # Lógica ANTES (validaciones, preparación)
        result = super().{method_name}(...)
        # Lógica DESPUÉS (notificaciones, side effects)
        return result
```

> **Nota clave:** {advertencia sobre cuándo NO usar este override o qué rompe si se hace mal}

---

## Extensión de vistas (xpaths recomendados)         [REQUERIDA]

```xml
<record id="view_{modelo}_form_inherit_{mi_modulo}" model="ir.ui.view">
    <field name="name">{modelo.nombre}.form.inherit.{mi_modulo}</field>
    <field name="model">{modelo.nombre}</field>
    <field name="inherit_id" ref="{modulo}.{view_id}"/>
    <field name="arch" type="xml">

        <!-- Agregar campo después de {campo_existente} -->
        <xpath expr="//field[@name='{campo_existente}']" position="after">
            <field name="mi_campo_nuevo"/>
        </xpath>

        <!-- Nueva pestaña -->
        <xpath expr="//notebook" position="inside">
            <page string="Mi Extensión" name="mi_extension">
                <field name="mi_campo"/>
            </page>
        </xpath>

    </field>
</record>
```

---

## Crear registros programáticamente                 [REQUERIDA]

[Ejemplo canónico de cómo crear el modelo principal desde código]

```python
record = self.env['{modelo.nombre}'].create({
    '{campo_requerido}': valor,
    ...
})
record.{action_method}()
```

---

## {Integraciones cross-módulo}                      [CONDICIONAL — si el módulo se integra con otros]

[Ejemplo de cómo pasar datos de este módulo a otro, o vice versa]

---

## Subtipos de mensaje                               [CONDICIONAL — si el modelo tiene mail.thread]

| XML ID                    | Evento                | Default |
|---------------------------|-----------------------|---------|
| `{modulo}.mt_{event}`     | {descripción}         | Sí/No   |
```

---

## 6. `requirement_guidelines.md`

```markdown
# Guía para desarrolladores — `{nombre}` — Odoo {version}

Lee esto **antes** de escribir cualquier código que toque {descripción breve del módulo}.

---

## Lo que NUNCA debes hacer                          [REQUERIDA — mínimo 3 reglas]

### {Título del antipatrón}

```python
# MAL — {por qué es problemático}
{codigo_incorrecto}

# BIEN — {alternativa correcta}
{codigo_correcto}
```

[Explicación de por qué el MAL rompe algo]

---

## Campos críticos — no cambiar su lógica            [REQUERIDA]

| Campo          | Modelo     | Por qué es crítico                        |
|----------------|------------|-------------------------------------------|
| `{campo}`      | `{modelo}` | {consecuencia de modificarlo}             |

---

## {Flujos que requieren atención especial}           [REQUERIDA — mínimo 2 flujos]

[Diagramas o explicaciones de los flujos de negocio complejos donde una modificación
puede tener efectos no obvios en otros módulos]

---

## Configuraciones que afectan el comportamiento     [REQUERIDA]

| Parámetro / Grupo          | Efecto                                  |
|----------------------------|-----------------------------------------|
| `{config_key}`             | {qué cambia en el comportamiento}       |

---

## Patrones de implementación recomendados           [REQUERIDA — mínimo 2 patrones]

[Código de ejemplo para los casos de uso más frecuentes de extensión]

---

## Checklist antes de entregar                       [REQUERIDA]

- [ ] {verificación técnica 1}
- [ ] {verificación funcional 2}
- [ ] Se probó el flujo completo: {pasos del happy path}
- [ ] Se probó con usuario sin permisos de administrador
```

---

## Reglas de calidad para nuevos análisis

Al generar un nuevo análisis, verificar:

1. **Consistencia de formato:** H2 para secciones principales, H3 para subsecciones de modelos
2. **Tablas de campos:** siempre incluir columnas `Campo | Tipo | Req. | Descripción`
3. **Métodos:** siempre indicar el tipo (Acción / Compute / Negocio / Hook / Cron)
4. **Código Python:** siempre incluir `_inherit` explícito y llamada a `super()`
5. **Código XML:** siempre incluir `inherit_id` con `ref` completo
6. **Secciones CONDICIONAL:** documentar brevemente por qué se incluyó si aplica
7. **Checklist:** mínimo 5 ítems, debe incluir prueba de flujo completo y prueba con usuario sin admin

## Diferencias permitidas por tipo de módulo

| Tipo de módulo      | Secciones adicionales esperadas en `summary.md`       |
|---------------------|-------------------------------------------------------|
| Contabilidad        | Tipos de documento, estados de pago                   |
| Inventario          | Pasos de almacén, tipos de ubicación/operación        |
| RRHH                | Tipos de contrato, estructura de nómina               |
| Ventas/Compras      | Estados de facturación, política de entrega           |
| Proyectos           | Tipos de tarea, métodos de facturación                |
