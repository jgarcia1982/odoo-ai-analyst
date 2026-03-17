# Guía para Generar Especificaciones Técnicas de Odoo

Esta guía define el proceso completo para convertir un requerimiento funcional en una especificación técnica lista para desarrollo, usando el atlas técnico de este repositorio.

---

## Cuándo usar esta guía

Usa esta guía cuando:
- Un cliente describe qué quiere que haga el sistema (requerimiento funcional)
- Un desarrollador necesita saber exactamente qué crear (especificación técnica)
- Hay que decidir si personalizar un módulo existente o crear uno nuevo

---

## Proceso completo (5 pasos)

### Paso 1 — Clasificar el requerimiento

Antes de escribir código, determina el tipo de cambio:

| Tipo                    | Señales en el requerimiento                                         | Complejidad |
|-------------------------|---------------------------------------------------------------------|-------------|
| **Automatización**      | "que se envíe automáticamente", "que cambie solo cuando..."         | Baja        |
| **Campo nuevo**         | "necesito registrar X", "agregar un campo de..."                    | Baja        |
| **Reporte**             | "quiero ver un listado de...", "necesito una tabla con..."          | Baja-Media  |
| **Extensión de flujo**  | "agregar un paso de aprobación", "validar antes de..."              | Media       |
| **Nuevo módulo**        | Funcionalidad que no existe en ningún módulo estándar               | Alta        |
| **Integración externa** | "conectar con SAT/DIAN/API de tercero"                              | Alta        |

> **Regla de oro:** si existe un módulo estándar que cubre el 70% del requerimiento, extiéndelo. No crees módulos nuevos innecesariamente.

---

### Paso 2 — Identificar el módulo base

Consulta el atlas técnico en `knowledge/modules/odoo19/` para encontrar el módulo más cercano:

| Si el requerimiento es sobre...         | Módulo base probable      |
|-----------------------------------------|---------------------------|
| Cotizaciones, órdenes de venta          | `sale`                    |
| Facturas, pagos, contabilidad           | `account`                 |
| Inventario, entregas, almacén           | `stock`                   |
| Órdenes de compra, proveedores          | `purchase`                |
| Empleados, contratos, nómina            | `hr`, `hr_payroll`        |
| Proyectos, tareas                       | `project`                 |
| Clientes, oportunidades, pipeline       | `crm`                     |
| Fabricación, listas de materiales       | `mrp`                     |
| Configuración, parámetros del sistema   | `base`, `base_setup`      |

Luego revisa en el atlas:
- `knowledge/modules/odoo19/{modulo}/models.md` — qué campos ya existen
- `knowledge/modules/odoo19/{modulo}/extension_points.md` — cómo extenderlo
- `knowledge/modules/odoo19/{modulo}/requirement_guidelines.md` — qué no tocar

---

### Paso 3 — Diseñar la solución mínima

Para cada componente, responde estas preguntas:

**Modelos:**
- ¿Necesito un modelo nuevo o puedo agregar campos a uno existente?
- Si es nuevo: ¿necesita chatter (`mail.thread`)? ¿necesita actividades (`mail.activity.mixin`)?
- ¿Qué relaciones tiene con modelos existentes?
- ¿Tiene estados? ¿Cuáles y cuáles son las transiciones?

**Campos:**
- ¿Cuál es el nombre técnico en snake_case?
- ¿Cuál es el tipo ORM correcto? (ver tabla abajo)
- ¿Es requerido? ¿Tiene valor por defecto?
- ¿Necesita `tracking=True`?
- ¿Es computado? ¿De qué depende? ¿Necesita `store=True`?

**Vistas:**
- ¿Dónde aparece el campo en la UI? (formulario, lista, kanban)
- ¿Es editable o solo lectura?
- ¿Bajo qué condición es visible?
- ¿Se agrega a una pestaña existente o requiere una nueva?

**Seguridad:**
- ¿Qué grupos pueden ver este dato?
- ¿Qué grupos pueden editarlo?
- ¿Hay restricciones por empresa o por usuario?

#### Tipos de campo ORM — referencia rápida

| Tipo ORM          | Cuándo usarlo                                         | Ejemplo                          |
|-------------------|-------------------------------------------------------|----------------------------------|
| `Char`            | Texto corto (< 255 chars), sin formato                | Código, nombre, referencia       |
| `Text`            | Texto largo sin formato                               | Notas internas                   |
| `Html`            | Texto con formato rico                                | Descripción, términos            |
| `Integer`         | Número entero                                         | Cantidad, días                   |
| `Float`           | Número decimal                                        | Precio unitario, porcentaje      |
| `Monetary`        | Valor monetario (requiere `currency_field`)           | Total, monto de factura          |
| `Boolean`         | Verdadero / Falso                                     | Activo, requerido                |
| `Date`            | Solo fecha                                            | Fecha de entrega                 |
| `Datetime`        | Fecha y hora                                          | Fecha de confirmación            |
| `Selection`       | Lista fija de opciones                                | Estado, tipo                     |
| `Many2one`        | Relación con un registro de otro modelo               | Cliente, empresa                 |
| `One2many`        | Lista de registros hijos (inverso de Many2one)        | Líneas de orden                  |
| `Many2many`       | Relación con varios registros de otro modelo          | Impuestos, etiquetas             |
| `Binary`          | Archivo binario (PDF, imagen, etc.)                   | Adjunto, firma                   |
| `Image`           | Imagen con soporte de thumbnails                      | Foto de producto, logo           |

---

### Paso 4 — Redactar la especificación

Usa esta estructura estándar para el documento `spec.md`:

```markdown
# Spec: [Nombre del requerimiento]
**Versión Odoo:** 19
**Módulo:** nombre_modulo
**Tipo:** extensión de `sale` / nuevo módulo / automatización
**Complejidad:** Baja / Media / Alta

## Resumen
[2-3 oraciones: qué se va a hacer y por qué]

## Módulo
- **Nombre técnico:** `base_module_mi_feature`
- **Hereda de:** `base_module`
- **Depende de:** `base_module`, [otros]

## Modelos

### `nombre.modelo`
_inherit = 'modelo.base' (si es extensión)

| Campo          | Tipo      | Requerido | Default | Descripción             |
|----------------|-----------|:---------:|---------|-------------------------|
| `campo_a`      | Char      | Sí        | —       | Descripción             |
| `campo_b`      | Selection | Sí        | 'x'     | Valores: x, y, z        |

**Métodos nuevos:**
- `action_mi_accion()` — describe qué hace

**Overrides:**
- `action_confirm()` — agrega validación de campo_a antes del super()

## Vistas

### Formulario `nombre.modelo`
- Extiende: `base_module.view_modelo_form`
- Cambios: agregar campo_a después de name; nueva pestaña "X" con campo_b

## Seguridad

| Modelo         | Grupo             | C | R | W | D |
|----------------|-------------------|---|---|---|---|
| `nombre.modelo`| `base.group_user` | ✓ | ✓ | ✓ |   |

## Archivos a crear

```
nombre_modulo/
├── __manifest__.py
├── __init__.py
├── models/
│   ├── __init__.py
│   └── nombre_modelo.py
├── views/
│   └── nombre_modelo_views.xml
└── security/
    └── ir.model.access.csv
```

## Consideraciones técnicas
- [Advertencias, edge cases, qué no romper]

## Complejidad: Baja
- 1 modelo extendido, 2 campos nuevos, 1 vista extendida
```

---

### Paso 5 — Validar la especificación

Antes de entregar al desarrollador, verifica:

#### Checklist técnico

- [ ] Los nombres de campo están en `snake_case`
- [ ] Los nombres de clase Python están en `PascalCase`
- [ ] El nombre del módulo sigue la convención: `{base}_{feature}` (ej. `sale_approval`)
- [ ] La versión del módulo sigue: `19.0.1.0.0`
- [ ] Todos los modelos nuevos tienen `_name` y `_description`
- [ ] Los `_inherit` son del modelo correcto (verificar en el atlas)
- [ ] Los campos `Monetary` tienen `currency_field` declarado
- [ ] Los campos `One2many` tienen su `Many2one` correspondiente en el modelo hijo
- [ ] Los overrides de métodos llaman `super()`
- [ ] Los campos con `store=True` tienen `@api.depends` completo
- [ ] El `__manifest__.py` lista todos los archivos XML en `data`
- [ ] El `ir.model.access.csv` tiene permisos para todos los modelos nuevos

#### Checklist funcional

- [ ] El flujo descrito cubre el requerimiento completo
- [ ] Se considera el caso cuando el usuario no tiene todos los permisos
- [ ] Se considera el comportamiento en multi-empresa
- [ ] Se especificó qué pasa cuando el usuario cancela a mitad del flujo
- [ ] Los campos computados tienen un valor coherente cuando el registro es nuevo

---

## Niveles de complejidad — referencia

| Nivel  | Características                                                        | Tiempo estimado |
|--------|------------------------------------------------------------------------|-----------------|
| **Baja**   | 1-2 modelos extendidos, campos simples, sin lógica compleja        | 0.5 - 2 días    |
| **Media**  | Nuevo modelo con estado, vistas múltiples, lógica de negocio       | 3 - 7 días      |
| **Alta**   | Múltiples modelos, integraciones externas, flujos complejos        | 2 - 4 semanas   |
| **Crítica**| Modificaciones a flujos core (account, stock), migraciones de datos | Evaluar caso por caso |

---

## Antipatrones comunes — evítalos

| Antipatrón                                          | Consecuencia                                              | Solución                                |
|-----------------------------------------------------|-----------------------------------------------------------|-----------------------------------------|
| Modificar directamente `sale`, `account`, `stock`   | Imposible actualizar Odoo                                 | Siempre crear módulo de extensión       |
| Cambiar valores del campo `state`                   | Rompe integraciones con otros módulos                     | Crear campo de estado separado          |
| `_inherit` sin `super()` en overrides               | El flujo base no se ejecuta                               | Siempre llamar `super()`                |
| `position="replace"` en vistas                      | Rompe extensiones de otros módulos en cascada             | Usar `after`, `before`, `inside`        |
| Campo `Monetary` sin `currency_field`               | Error en runtime al calcular conversiones                 | Declarar `currency_field='currency_id'` |
| `store=True` sin `@api.depends` completo            | Datos desactualizados silenciosamente                     | Declarar todas las dependencias         |
| Lógica en `__init__` del módulo                     | Se ejecuta en import, no en instalación                   | Usar `post_init_hook` en manifest       |
