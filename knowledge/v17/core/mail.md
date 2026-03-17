# Módulo: mail — Odoo 17

## Propósito

Sistema de mensajería interna, chatter, notificaciones por email, actividades y seguimiento de registros. Es la base del sistema social de Odoo.

## Modelos principales

### `mail.thread` (mixin)
Mixin que agrega chatter y seguimiento a cualquier modelo.

```python
class MiModelo(models.Model):
    _name = 'mi.modelo'
    _inherit = ['mail.thread', 'mail.activity.mixin']
```

Agrega al modelo:
- Historial de mensajes
- Seguidores (`message_follower_ids`)
- Campo `message_ids` con todos los mensajes
- Métodos `message_post()`, `message_subscribe()`

### `mail.message`
Mensaje individual en el chatter.

| Campo              | Tipo         | Descripción                                   |
|--------------------|--------------|-----------------------------------------------|
| `body`             | Html         | Contenido del mensaje                         |
| `author_id`        | Many2one     | Autor (res.partner)                           |
| `model`            | Char         | Modelo al que pertenece                       |
| `res_id`           | Integer      | ID del registro al que pertenece              |
| `message_type`     | Selection    | `comment`, `email`, `notification`, `auto`    |
| `subtype_id`       | Many2one     | Subtipo del mensaje                           |
| `partner_ids`      | Many2many    | Destinatarios del mensaje                     |
| `attachment_ids`   | Many2many    | Archivos adjuntos                             |
| `date`             | Datetime     | Fecha y hora                                  |

### `mail.activity`
Actividades programadas (llamadas, reuniones, tareas pendientes).

| Campo            | Tipo         | Descripción                              |
|------------------|--------------|------------------------------------------|
| `activity_type_id` | Many2one   | Tipo de actividad                        |
| `summary`        | Char         | Resumen breve                            |
| `note`           | Html         | Descripción detallada                    |
| `date_deadline`  | Date         | Fecha límite                             |
| `user_id`        | Many2one     | Usuario asignado                         |
| `res_model`      | Char         | Modelo del registro                      |
| `res_id`         | Integer      | ID del registro                          |
| `state`          | Selection    | `overdue`, `today`, `planned`            |

### `mail.activity.mixin` (mixin)
Mixin que agrega actividades al modelo.

```python
_inherit = ['mail.activity.mixin']
```

Agrega:
- `activity_ids` (One2many a `mail.activity`)
- `activity_state` (campo computado: `overdue/today/planned`)
- Botones de actividad en la vista

### `mail.followers`
Seguidores de un registro.

| Campo          | Tipo       | Descripción                           |
|----------------|------------|---------------------------------------|
| `res_model`    | Char       | Modelo seguido                        |
| `res_id`       | Integer    | ID del registro seguido               |
| `partner_id`   | Many2one   | Seguidor (res.partner)                |
| `subtype_ids`  | Many2many  | Subtipos de notificación activos      |

### `mail.template`
Plantillas de email.

| Campo           | Tipo       | Descripción                                |
|-----------------|------------|--------------------------------------------|
| `name`          | Char       | Nombre de la plantilla                     |
| `model_id`      | Many2one   | Modelo al que aplica                       |
| `subject`       | Char       | Asunto (soporta Jinja2/QWeb)               |
| `body_html`     | Html       | Cuerpo del email (soporta Jinja2/QWeb)     |
| `email_to`      | Char       | Destinatario (expresión dinámica)          |
| `attachment_ids`| Many2many  | Archivos adjuntos fijos                    |

## Vistas

- Bandeja de entrada (`mail.action_discuss`)
- Gestión de actividades
- Historial de mensajes enviados

## Seguridad

- `mail.group_mail_user` — Acceso básico al correo
- `mail.group_mail_template_editor` — Puede editar plantillas de email

## Puntos de extensión

### Agregar chatter a un modelo

```python
class SaleOrder(models.Model):
    _inherit = 'sale.order'
    _inherit = ['mail.thread', 'mail.activity.mixin']

    # Rastrear cambios en campos específicos
    state = fields.Selection(tracking=True)
    amount_total = fields.Monetary(tracking=True)
```

### Enviar mensaje programáticamente

```python
record.message_post(
    body="El pedido ha sido confirmado",
    message_type='notification',
    subtype_xmlid='mail.mt_note',
)
```

### Enviar email desde plantilla

```python
template = self.env.ref('mi_modulo.email_template_confirmacion')
template.send_mail(record.id, force_send=True)
```

### Agregar subtipo de mensaje

```xml
<record id="mt_orden_confirmada" model="mail.message.subtype">
    <field name="name">Orden Confirmada</field>
    <field name="res_model">sale.order</field>
    <field name="default" eval="True"/>
    <field name="description">Orden de venta confirmada</field>
</record>
```

### Suscribir usuario automáticamente

```python
@api.model_create_multi
def create(self, vals_list):
    records = super().create(vals_list)
    for record in records:
        record.message_subscribe(partner_ids=[record.user_id.partner_id.id])
    return records
```

## Dependencias

- `base`

## Notas v17

- Chatter completamente reescrito con Owl 2
- `mail.activity` ahora soporta actividades recurrentes
- Nuevo tipo de mensaje `whatsapp` (si módulo whatsapp instalado)
- `mail.thread.cc` mixin separado para CC en emails
- Mejoras en rendimiento con carga lazy del historial
