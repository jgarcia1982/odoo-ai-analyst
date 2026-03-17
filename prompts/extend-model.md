# Prompt: Diseñar Extensión de Modelo

## Variables requeridas
- `{{base_module}}` — módulo base a extender (ej. `sale`, `account`, `stock`)
- `{{model_name}}` — modelo a extender (ej. `sale.order`, `account.move`)
- `{{requirement}}` — qué se necesita agregar o cambiar
- `{{odoo_version}}` — versión de Odoo

---

Eres un arquitecto técnico de Odoo especializado en extensiones de módulos. Diseña la extensión correcta para el modelo `{{model_name}}` del módulo `{{base_module}}` en Odoo `{{odoo_version}}`.

## Requerimiento de extensión
{{requirement}}

---

## Criterios de diseño

Al diseñar la extensión, considera:

1. **Mínima invasión** — solo tocar lo necesario del módulo base
2. **Compatibilidad con actualizaciones** — evitar monkey-patching frágil
3. **Usar `_inherit` correctamente** — no `_inherits` a menos que se requiera delegación
4. **Respetar la secuencia de módulos** — declarar dependencia en `__manifest__.py`
5. **No romper vistas existentes** — extender con `inherit_id`, no reemplazar

---

## Formato de salida

### Código Python del modelo extendido

```python
# models/{{model_name_snake}}.py
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError

class {{ModelClass}}(models.Model):
    _inherit = '{{model_name}}'

    # Nuevos campos
    campo_nuevo = fields.Char(
        string='Nombre visible',
        tracking=True,  # si el modelo hereda mail.thread
    )

    # Computed fields
    campo_computado = fields.Float(
        string='Campo Computado',
        compute='_compute_campo_computado',
        store=True,  # True si se necesita búsqueda/ordenamiento
    )

    @api.depends('campo_base', 'campo_nuevo')
    def _compute_campo_computado(self):
        for rec in self:
            rec.campo_computado = rec.campo_base + 1

    # Override de método existente
    def action_existente(self):
        # Validación previa
        for rec in self:
            if not rec.campo_nuevo:
                raise UserError('Falta campo_nuevo')
        return super().action_existente()

    # Constraint
    @api.constrains('campo_nuevo')
    def _check_campo_nuevo(self):
        for rec in self:
            if rec.campo_nuevo and len(rec.campo_nuevo) < 3:
                raise ValidationError('campo_nuevo debe tener al menos 3 caracteres')
```

### Vista XML extendida

```xml
<!-- views/{{model_name_snake}}_views.xml -->
<odoo>
    <!-- Extender formulario existente -->
    <record id="view_{{model_name_snake}}_form_inherit" model="ir.ui.view">
        <field name="name">{{model_name}}.form.inherit.{{module_name}}</field>
        <field name="model">{{model_name}}</field>
        <field name="inherit_id" ref="{{base_module}}.view_{{model_name_snake}}_form"/>
        <field name="arch" type="xml">
            <!-- Agregar campo después de campo_existente -->
            <xpath expr="//field[@name='campo_existente']" position="after">
                <field name="campo_nuevo"/>
            </xpath>

            <!-- Agregar pestaña nueva -->
            <xpath expr="//notebook" position="inside">
                <page string="Mi Extensión" name="mi_extension">
                    <group>
                        <field name="campo_nuevo"/>
                        <field name="campo_computado"/>
                    </group>
                </page>
            </xpath>
        </field>
    </record>

    <!-- Extender vista de lista -->
    <record id="view_{{model_name_snake}}_list_inherit" model="ir.ui.view">
        <field name="name">{{model_name}}.list.inherit.{{module_name}}</field>
        <field name="model">{{model_name}}</field>
        <field name="inherit_id" ref="{{base_module}}.view_{{model_name_snake}}_tree"/>
        <field name="arch" type="xml">
            <xpath expr="//field[@name='name']" position="after">
                <field name="campo_nuevo" optional="show"/>
            </xpath>
        </field>
    </record>
</odoo>
```

### Permisos de acceso para campos nuevos

Si el campo debe estar restringido por grupo:

```xml
<!-- Solo visible para gerentes -->
<field name="campo_sensible" groups="{{base_module}}.group_manager"/>
```

### __manifest__.py

```python
{
    'name': 'Extensión {{base_module}} - {{feature_name}}',
    'version': '17.0.1.0.0',
    'depends': ['{{base_module}}'],
    'data': [
        'views/{{model_name_snake}}_views.xml',
    ],
}
```

### Advertencias

Lista de riesgos o consideraciones especiales para esta extensión específica.
