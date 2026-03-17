# Análisis de Módulo: `{{module_name}}`

> **Versión de Odoo:** {{odoo_version}}
> **Fecha de análisis:** {{date}}
> **Analista:** {{analyst}}

---

## 1. Propósito del módulo

<!-- Qué problema resuelve, qué proceso de negocio cubre -->

**Descripción breve:**
> [1-2 oraciones que un no-técnico pueda entender]

**Descripción técnica:**
> [Qué hace el módulo desde el punto de vista del ORM, qué extiende, qué introduce]

**Categoría funcional:**
- [ ] Contabilidad y Finanzas
- [ ] Ventas y CRM
- [ ] Inventario y Logística
- [ ] Compras
- [ ] Recursos Humanos
- [ ] Manufactura
- [ ] Proyectos
- [ ] Configuración / Base
- [ ] Integración externa
- [ ] Otro: ___________

**Tipo de módulo:**
- [ ] Módulo estándar de Odoo
- [ ] Módulo de extensión (hereda de estándar)
- [ ] Módulo completamente nuevo
- [ ] Módulo de localización

---

## 2. Dependencias

### Dependencias directas (`depends` en __manifest__.py)

| Módulo           | Propósito en esta dependencia               | ¿Crítica? |
|------------------|---------------------------------------------|-----------|
| `base`           | ORM fundamental                             | Sí        |
| `{{dep_module}}` | {{why_needed}}                              | Sí / No   |

### Dependencias opcionales o sugeridas

| Módulo           | Qué habilita si está instalado              |
|------------------|---------------------------------------------|
| `{{opt_module}}` | {{what_it_unlocks}}                         |

### Módulos que dependen de este

> Módulos del sistema que a su vez requieren `{{module_name}}` (impacto de cambios)

| Módulo           | Por qué depende de este módulo              |
|------------------|---------------------------------------------|
| `{{child_mod}}`  | {{reason}}                                  |

---

## 3. Modelos principales

> Lista ordenada por importancia en el flujo de negocio.

### `{{model.name}}` — {{Descripción en una línea}}

```
Tabla BD: {{model_name_underscore}}
Hereda de: {{parent_model}} (si aplica)
Mixins: mail.thread / mail.activity.mixin / (ninguno)
```

| Campo              | Tipo           | Requerido | Descripción                              |
|--------------------|----------------|-----------|------------------------------------------|
| `name`             | Char           | Sí        | Nombre o referencia del registro         |
| `state`            | Selection      | Sí        | Estado en el flujo de trabajo            |
| `partner_id`       | Many2one       | Sí        | Contacto asociado (res.partner)          |
| `company_id`       | Many2one       | Sí        | Empresa (multi-empresa)                  |
| `{{field_name}}`   | {{field_type}} | Sí / No   | {{description}}                          |

**Estados del flujo** (si aplica):
```
{{estado_1}} → {{estado_2}} → {{estado_3}}
    (condición)      (condición)
```

**Relaciones entre modelos:**
```
{{model.a}} ──(One2many)──→ {{model.b}}
{{model.a}} ──(Many2one)──→ res.partner
{{model.b}} ──(Many2many)─→ {{model.c}}
```

---

<!-- Repetir sección "3" para cada modelo principal -->

---

## 4. Campos críticos

> Campos cuya modificación o eliminación rompe funcionalidad central del módulo o de módulos dependientes.

| Modelo             | Campo              | Tipo       | Por qué es crítico                                    |
|--------------------|--------------------|------------|-------------------------------------------------------|
| `{{model.name}}`   | `state`            | Selection  | Controla transiciones, permisos y visibilidad de UI   |
| `{{model.name}}`   | `company_id`       | Many2one   | Aislamiento multi-empresa                             |
| `{{model.name}}`   | `{{field}}`        | {{type}}   | {{reason}}                                            |

**Campos computados con `store=True`** (requieren recómputo en migración):

| Modelo           | Campo          | Depende de               | Impacto si cambia la lógica            |
|------------------|----------------|--------------------------|----------------------------------------|
| `{{model.name}}` | `{{field}}`    | `{{dependency_fields}}`  | {{impact}}                             |

---

## 5. Flujos de negocio

> Los procesos principales que el módulo implementa, desde el punto de vista del usuario y del sistema.

### Flujo: {{nombre_del_flujo}}

**Actor:** {{usuario o sistema que inicia}}
**Desencadenante:** {{qué acción del usuario o evento del sistema lo inicia}}

```
[Paso 1] Usuario hace X
    ↓ método: action_x()
[Paso 2] Sistema valida Y (raise UserError si falla)
    ↓ ORM: write({'state': 'confirmado'})
[Paso 3] Se notifica por email / se crea actividad
    ↓ message_post() / activity_schedule()
[Paso 4] Registro queda en estado Z
```

**Reglas de negocio involucradas:**
- Solo se puede pasar a `confirmado` si el campo X está completo
- El usuario requiere el grupo `{{group}}` para ejecutar esta acción
- {{otra_regla}}

**Métodos Python relevantes:**
```python
# modelo: {{model.name}}
def action_confirmar(self):   # botón "Confirmar"
def _check_stock(self):       # @api.constrains
def _onchange_partner(self):  # @api.onchange('partner_id')
```

---

<!-- Repetir sección "5" para cada flujo principal -->

---

## 6. Vistas

### Resumen de vistas

| ID XML                              | Tipo     | Modelo           | Descripción                         |
|-------------------------------------|----------|------------------|-------------------------------------|
| `{{module}}.view_{{model}}_form`    | form     | `{{model.name}}` | Formulario principal                |
| `{{module}}.view_{{model}}_tree`    | list     | `{{model.name}}` | Lista con columnas básicas          |
| `{{module}}.view_{{model}}_kanban`  | kanban   | `{{model.name}}` | Tablero por estado                  |
| `{{module}}.view_{{model}}_search`  | search   | `{{model.name}}` | Filtros y agrupaciones              |
| `{{module}}.view_{{model}}_pivot`   | pivot    | `{{model.name}}` | Análisis cruzado                    |

### Formulario principal: `{{module}}.view_{{model}}_form`

**Campos visibles (pestaña principal):**
- `name` — Referencia
- `state` — Estado (barra de estado en header)
- `partner_id` — Cliente/Proveedor
- `{{field}}` — {{label}}

**Pestañas adicionales:**
- **{{tab_name}}:** campos {{field1}}, {{field2}}
- **Historial** (chatter): mensajes, actividades, seguidores

**Botones de acción en header:**
| Botón          | Método invocado        | Visible cuando              |
|----------------|------------------------|-----------------------------|
| Confirmar      | `action_confirmar()`   | `state == 'borrador'`       |
| Cancelar       | `action_cancelar()`    | `state in ('borrador', 'confirmado')` |
| {{button}}     | `{{method}}()`         | `{{condition}}`             |

### Menús y acciones

| Menú                              | Acción                     | Modelo           |
|-----------------------------------|----------------------------|------------------|
| {{App}} > {{Sección}} > {{Menú}} | `action_{{model}}_list`    | `{{model.name}}` |

---

## 7. Seguridad

### Grupos definidos en este módulo

| ID XML                          | Nombre visible               | Descripción del rol                     |
|---------------------------------|------------------------------|-----------------------------------------|
| `{{module}}.group_user`         | {{Módulo}}: Usuario          | Acceso operativo básico                 |
| `{{module}}.group_manager`      | {{Módulo}}: Gerente          | Configuración y acceso total            |
| `{{module}}.group_readonly`     | {{Módulo}}: Solo lectura     | Consulta sin modificación               |

**Jerarquía de grupos:**
```
group_manager
    └── group_user
            └── group_readonly
```

### Permisos por modelo (`ir.model.access.csv`)

| Modelo           | Grupo              | Create | Read | Write | Delete |
|------------------|--------------------|:------:|:----:|:-----:|:------:|
| `{{model.name}}` | `group_user`       |   ✓    |  ✓   |   ✓   |        |
| `{{model.name}}` | `group_manager`    |   ✓    |  ✓   |   ✓   |   ✓    |
| `{{model.name}}` | `group_readonly`   |        |  ✓   |       |        |

### Reglas de registro (`ir.rule`)

| Regla                          | Modelo           | Dominio                                      | Aplica a           |
|--------------------------------|------------------|----------------------------------------------|--------------------|
| Multi-empresa                  | `{{model.name}}` | `[('company_id', 'in', company_ids)]`        | Todos los grupos   |
| Solo propios registros         | `{{model.name}}` | `[('user_id', '=', user.id)]`               | `group_user`       |
| `{{rule_name}}`                | `{{model.name}}` | `{{domain}}`                                 | `{{group}}`        |

### Campos restringidos por grupo

| Campo              | Modelo           | Grupo requerido         | Restricción         |
|--------------------|------------------|-------------------------|---------------------|
| `{{field}}`        | `{{model.name}}` | `{{module}}.group_manager` | invisible / readonly |

---

## 8. Puntos de extensión

> Lugares donde se recomienda o se puede agregar funcionalidad sin modificar el módulo original.

### Modelos extensibles

| Modelo           | Cómo extender                          | Ejemplo de uso típico                  |
|------------------|----------------------------------------|----------------------------------------|
| `{{model.name}}` | `_inherit = '{{model.name}}'`          | Agregar campos del cliente             |
| `{{model.name}}` | `_inherit = ['{{model.name}}', 'mail.thread']` | Agregar chatter si no lo tiene |

### Métodos recomendados para override

```python
# action_confirmar — agregar validaciones sin romper el flujo original
def action_confirmar(self):
    # Tu lógica ANTES
    result = super().action_confirmar()
    # Tu lógica DESPUÉS
    return result

# _prepare_{{child_model}}_values — personalizar datos al crear registros hijos
def _prepare_{{child_model}}_values(self):
    values = super()._prepare_{{child_model}}_values()
    values['campo_extra'] = self.campo_extra
    return values
```

### Vistas extensibles (xpath recomendados)

```xml
<!-- Agregar campo en formulario después de 'name' -->
<xpath expr="//field[@name='name']" position="after">
    <field name="mi_campo_nuevo"/>
</xpath>

<!-- Agregar pestaña en el notebook -->
<xpath expr="//notebook" position="inside">
    <page string="Mi Extensión">
        <field name="mi_campo_nuevo"/>
    </page>
</xpath>

<!-- Agregar columna en lista -->
<xpath expr="//field[@name='name']" position="after">
    <field name="mi_campo_nuevo" optional="show"/>
</xpath>
```

### Automatizaciones sin código (base.automation)

Acciones automatizadas que se pueden configurar desde la UI:
- Al crear un registro → enviar email / asignar responsable
- Al cambiar de estado → notificar / crear actividad
- Según tiempo → recordatorios / escalamientos

### Subtipos de mensaje (mail.message.subtype)

Notificaciones que se pueden activar/desactivar por seguidor:
| Subtipo                        | Evento que lo dispara              |
|--------------------------------|------------------------------------|
| `{{module}}.mt_{{event}}`      | {{descripción del evento}}         |

---

## 9. Riesgos de personalización

> Situaciones donde una personalización incorrecta puede romper funcionalidad, corromper datos o impedir actualizaciones.

### Riesgos altos

| Riesgo                                          | Causa probable                                         | Mitigación                                              |
|-------------------------------------------------|--------------------------------------------------------|---------------------------------------------------------|
| Modificar `state` y sus valores                 | Otros módulos dependen de los valores exactos del Selection | Agregar estados nuevos, nunca renombrar existentes  |
| Override de `action_post()` / `action_confirm()` sin `super()` | El flujo base no se ejecuta               | Siempre llamar `super()` primero o al final             |
| Cambiar `_sql_constraints` en módulo instalado  | Falla en `--update` por datos existentes               | Migrar datos antes de cambiar constraints               |
| Modificar `compute=` de campo `store=True`      | Datos almacenados quedan inconsistentes                 | Ejecutar recomputación manual post-deploy               |

### Riesgos medios

| Riesgo                                          | Causa probable                                 | Mitigación                                    |
|-------------------------------------------------|------------------------------------------------|-----------------------------------------------|
| Extender vista con `position="replace"`         | Rompe extensiones de otros módulos             | Usar `position="after/before/inside"`         |
| Agregar campo `required=True` a modelo existente | Registros existentes sin valor fallan          | Proveer `default=` o migración de datos       |
| Sobreescribir `_name` en lugar de `_inherit`    | Se crea un modelo separado, no una extensión   | Revisar si la intención es heredar o crear    |

### Consideraciones de actualización de versión

- Cambios de `{{model.name}}` entre v{{prev_version}} y v{{odoo_version}}:
  - `{{field_removed}}` fue eliminado → reemplazar con `{{new_approach}}`
  - `{{method_changed}}` cambió firma → actualizar override
  - {{otras_notas}}

---

## Notas adicionales

<!-- Campo libre para observaciones del analista -->

---

*Generado con odoo-ai-analyst — [github.com/tu-usuario/odoo-ai-analyst]*
