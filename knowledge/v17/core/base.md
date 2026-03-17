# Módulo: base — Odoo 17

## Propósito

Núcleo del ORM de Odoo. Define los modelos fundamentales sobre los que se construye toda la plataforma. Sin este módulo no existe ningún otro.

## Modelos principales

### `res.company`
Empresa en el sistema multi-empresa.

| Campo                | Tipo          | Descripción                              |
|----------------------|---------------|------------------------------------------|
| `name`               | Char          | Nombre de la empresa                     |
| `partner_id`         | Many2one      | Contacto asociado (res.partner)          |
| `currency_id`        | Many2one      | Moneda principal                         |
| `parent_id`          | Many2one      | Empresa padre (jerarquía)                |
| `child_ids`          | One2many      | Empresas hijo                            |

### `res.partner`
Contacto universal: clientes, proveedores, empleados, empresas.

| Campo            | Tipo         | Descripción                                   |
|------------------|--------------|-----------------------------------------------|
| `name`           | Char         | Nombre completo                               |
| `company_id`     | Many2one     | Empresa a la que pertenece                    |
| `is_company`     | Boolean      | True si es empresa, False si es persona       |
| `parent_id`      | Many2one     | Empresa padre (para contactos de empresa)     |
| `email`          | Char         | Correo electrónico                            |
| `phone`          | Char         | Teléfono                                      |
| `vat`            | Char         | RFC / NIT / número de contribuyente           |
| `country_id`     | Many2one     | País                                          |
| `street`         | Char         | Dirección                                     |
| `zip`            | Char         | Código postal                                 |
| `category_id`    | Many2many    | Etiquetas del contacto                        |

### `res.users`
Usuarios del sistema. Extiende `res.partner`.

| Campo            | Tipo         | Descripción                          |
|------------------|--------------|--------------------------------------|
| `login`          | Char         | Nombre de usuario para login         |
| `password`       | Char         | Hash de contraseña                   |
| `groups_id`      | Many2many    | Grupos de seguridad asignados        |
| `company_id`     | Many2one     | Empresa activa                       |
| `company_ids`    | Many2many    | Empresas a las que tiene acceso      |
| `lang`           | Char         | Idioma preferido                     |
| `tz`             | Char         | Zona horaria                         |

### `res.groups`
Grupos de seguridad para control de acceso.

| Campo          | Tipo        | Descripción                               |
|----------------|-------------|-------------------------------------------|
| `name`         | Char        | Nombre del grupo                          |
| `category_id`  | Many2one    | Categoría (módulo al que pertenece)       |
| `users`        | Many2many   | Usuarios en este grupo                    |
| `implied_ids`  | Many2many   | Grupos implícitamente incluidos           |
| `model_access` | One2many    | Reglas de acceso a modelos               |
| `rule_groups`  | Many2many   | Reglas de registro (record rules)         |

### `ir.model`
Metadatos de modelos ORM registrados.

### `ir.model.fields`
Metadatos de campos de cada modelo.

### `ir.rule`
Reglas de dominio a nivel de registro (multi-empresa, multi-usuario).

### `ir.ui.view`
Definiciones XML de vistas.

### `ir.actions.act_window`
Acciones de ventana que abren vistas.

## Vistas

- Formulario y lista de `res.partner`
- Formulario y lista de `res.users`
- Configuración de `res.company`

## Seguridad

- `base.group_user` — Usuario interno (base para todos)
- `base.group_portal` — Usuario portal
- `base.group_public` — Usuario público
- `base.group_system` — Administrador técnico
- `base.group_erp_manager` — Administrador ERP

## Puntos de extensión

### Herencia más común

```python
# Extender res.partner
class ResPartner(models.Model):
    _inherit = 'res.partner'

    custom_field = fields.Char('Mi Campo')

# Extender res.users
class ResUsers(models.Model):
    _inherit = 'res.users'

    @property
    def SELF_READABLE_FIELDS(self):
        return super().SELF_READABLE_FIELDS + ['custom_field']
```

### Hooks del ORM

```python
# Override de create/write
@api.model_create_multi
def create(self, vals_list):
    records = super().create(vals_list)
    # lógica post-create
    return records

def write(self, vals):
    result = super().write(vals)
    # lógica post-write
    return result
```

## Dependencias

- No tiene dependencias (es el módulo raíz)

## Notas v17

- `res.partner` ahora tiene mejor soporte para jerarquías complejas
- `ir.rule` soporta expresiones de dominio más complejas con lambdas
- Nuevo modelo `ir.attachment` con deduplicación por hash
