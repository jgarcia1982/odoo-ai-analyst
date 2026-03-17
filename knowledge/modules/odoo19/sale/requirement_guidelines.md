# Guía para desarrolladores — `sale` — Odoo 19

Qué saber antes de tocar este módulo. Lee esto antes de escribir código.

---

## Lo que NO debes hacer

### No modifiques los valores de `state`

```python
# MAL — nunca hagas esto
state = fields.Selection([
    ('draft', 'Quotation'),
    ('sent', 'Quotation Sent'),
    ('sale', 'Sales Order'),
    ('cancel', 'Cancelled'),
    ('mi_estado', 'Mi Estado'),  # ← PELIGROSO
])
```

El campo `state` es referenciado por más de 15 módulos estándar. Si cambias sus valores, romperás `stock`, `account`, `crm`, `mrp` y otros. Si necesitas estados adicionales, **agrega un campo separado** para tu flujo.

### No llames `write({'state': ...})` directamente

Usa los métodos de acción existentes:

```python
# MAL
order.write({'state': 'sale'})

# BIEN
order.action_confirm()
```

Los métodos de acción disparan emails, crean movimientos de inventario, actualizan analítico y ejecutan automatizaciones.

### No hagas override sin llamar `super()`

```python
# MAL — el flujo base nunca se ejecuta
def action_confirm(self):
    self.write({'state': 'sale'})

# BIEN
def action_confirm(self):
    # validación previa
    return super().action_confirm()
```

### No toques `price_subtotal`, `price_total`, `price_tax`

Son campos computados de `sale.order.line`. Si necesitas un total diferente, agrega un campo computado propio que use `price_subtotal` como base.

---

## Lo que SÍ debes hacer

### Agrega campos en un módulo de extensión separado

```
mi_modulo/
├── __manifest__.py          # depends: ['sale']
├── models/
│   ├── sale_order.py        # _inherit = 'sale.order'
│   └── sale_order_line.py   # _inherit = 'sale.order.line'
└── views/
    └── sale_order_views.xml # inherit_id ref="sale.view_order_form"
```

Nunca edites los archivos originales del módulo `sale`.

### Usa `tracking=True` para campos auditables

```python
mi_campo = fields.Char('Mi Campo', tracking=True)
```

Cualquier cambio quedará registrado en el chatter automáticamente.

### Declara dependencias explícitas en `@api.depends`

```python
@api.depends('order_line.price_subtotal', 'mi_campo')
def _compute_mi_total(self):
    ...
```

Si omites dependencias, el campo no se recomputa cuando cambian los valores relacionados.

---

## Campos críticos — no cambiar su lógica

| Campo                | Modelo              | Por qué es crítico                                               |
|----------------------|---------------------|------------------------------------------------------------------|
| `state`              | `sale.order`        | Controla permisos, visibilidad, integraciones con stock/account  |
| `invoice_status`     | `sale.order`        | Determina si la orden aparece en "A facturar"                    |
| `qty_delivered`      | `sale.order.line`   | Base para `invoice_status` cuando `invoice_policy = 'delivery'` |
| `qty_invoiced`       | `sale.order.line`   | Computado desde facturas en estado `posted`                      |
| `price_unit`         | `sale.order.line`   | Computado desde pricelist; cambiarlo puede romper recotizaciones |
| `product_id`         | `sale.order.line`   | Dispara cascada de onchanges (precio, impuestos, descripción)    |

---

## Flujos que requieren atención especial

### Flujo de facturación

El `invoice_status` de la orden se calcula así:

```
Si TODAS las líneas son 'invoiced'          → order.invoice_status = 'invoiced'
Si ALGUNA línea es 'to invoice'             → order.invoice_status = 'to invoice'
Si ALGUNA línea es 'upselling'              → order.invoice_status = 'upselling'
Si ninguna línea tiene pendiente            → order.invoice_status = 'no'
```

Si agregas lógica que modifica `qty_delivered` o `qty_invoiced`, verifica que `invoice_status` siga siendo correcto.

### Flujo de pago en portal

```
Cliente abre la orden en portal
    ↓
Si require_payment=True → debe pagar antes de confirmar
    ↓ payment.transaction → state='done'
    ↓ _is_confirmation_amount_reached() → True
    ↓ action_confirm() automático
```

Si extiendes `action_confirm()`, considera que puede ser llamado automáticamente por el sistema de pagos.

### Módulo `sale` + `stock` (instalados juntos)

Cuando `stock` está instalado, `sale.order.line` adquiere:
- `move_ids` — movimientos de stock relacionados
- `qty_delivered_method` cambia a `'stock_move'` para productos storable
- `_compute_qty_delivered()` calcula desde `move_ids`

Si personalizas `qty_delivered`, verifica que no entre en conflicto con la lógica de `stock`.

---

## Configuraciones que afectan el comportamiento

Estas configuraciones de `res.config.settings` cambian el comportamiento del módulo:

| Configuración                    | Efecto                                                    |
|----------------------------------|-----------------------------------------------------------|
| `group_discount_per_so_line`     | Muestra/oculta el campo `discount` en líneas              |
| `group_proforma_sales`           | Activa botón de pro-forma                                 |
| `group_auto_done_setting`        | Bloquea órdenes al confirmar                              |
| `group_warning_sale`             | Muestra alertas de producto/cliente                       |
| `sale.async_emails`              | Activa cron para emails asíncronos                        |
| `sale.automatic_invoice`         | Activa facturación automática al pagar                    |
| `default_invoice_policy`         | `'order'` (por pedido) o `'delivery'` (por entrega)       |

---

## Patrones de implementación recomendados

### Para agregar un flujo de aprobación

```python
class SaleOrder(models.Model):
    _inherit = 'sale.order'

    estado_aprobacion = fields.Selection([
        ('pendiente', 'Pendiente de aprobación'),
        ('aprobado', 'Aprobado'),
        ('rechazado', 'Rechazado'),
    ], default='pendiente', tracking=True)

    def action_confirm(self):
        for order in self:
            if order.amount_total > 10000 and order.estado_aprobacion != 'aprobado':
                raise UserError('Órdenes > $10,000 requieren aprobación del gerente')
        return super().action_confirm()

    def action_aprobar(self):
        self.estado_aprobacion = 'aprobado'
```

### Para agregar un reporte PDF personalizado

```python
# report/sale_order_report.py
class SaleOrderReport(models.AbstractModel):
    _name = 'report.mi_modulo.report_saleorder_document'
    _description = 'Reporte de orden de venta personalizado'

    def _get_report_values(self, docids, data=None):
        orders = self.env['sale.order'].browse(docids)
        return {'docs': orders, 'data': data}
```

### Para agregar campo computado en la orden basado en sus líneas

```python
@api.depends('order_line.mi_campo_linea')
def _compute_mi_campo_orden(self):
    for order in self:
        order.mi_campo_orden = sum(order.order_line.mapped('mi_campo_linea'))
```

---

## Checklist antes de entregar un módulo de extensión de `sale`

- [ ] El módulo declara `'sale'` en `depends` del `__manifest__.py`
- [ ] Todas las vistas usan `inherit_id` y `xpath` (no reemplazos totales)
- [ ] Se llama `super()` en todos los métodos overrideados
- [ ] Los campos nuevos tienen `tracking=True` si son relevantes para auditoría
- [ ] Se probó el flujo completo: crear cotización → confirmar → facturar
- [ ] Se probó con usuario tipo `group_sale_salesman` (no solo con admin)
- [ ] Si hay campos `store=True`, se verificó que se recomputan correctamente
- [ ] No se modificaron valores del campo `state`
