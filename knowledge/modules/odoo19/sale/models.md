# Modelos — `sale` — Odoo 19

## Diagrama de relaciones

```
res.partner ──────────────────────┐
                                  ↓
product.pricelist ──────→ sale.order ←── crm.team (equipo)
                              │  │
                              │  └──(One2many)──→ sale.order.line
                              │                        │
                              │                        ├──→ product.product
                              │                        ├──→ account.tax (Many2many)
                              │                        └──→ account.move.line (invoice)
                              │
                              └──(Many2many)──→ account.move (facturas)
                              └──(Many2many)──→ payment.transaction
```

---

## `sale.order`

```
Tabla BD : sale_order
Mixins   : mail.thread, mail.activity.mixin, portal.mixin
```

### Campos de identificación y estado

| Campo             | Tipo          | Requerido | Descripción                                               |
|-------------------|---------------|:---------:|-----------------------------------------------------------|
| `name`            | Char          | Sí        | Referencia (ej. S00001), generada por secuencia           |
| `state`           | Selection     | Sí        | `draft` · `sent` · `sale` · `cancel`                      |
| `locked`          | Boolean       | —         | Si True, la orden es de solo lectura (modo bloqueado)     |
| `company_id`      | Many2one      | Sí        | Empresa propietaria                                       |

### Campos de cliente y direcciones

| Campo                 | Tipo      | Requerido | Descripción                                         |
|-----------------------|-----------|:---------:|-----------------------------------------------------|
| `partner_id`          | Many2one  | Sí        | Cliente principal (res.partner)                     |
| `partner_invoice_id`  | Many2one  | Sí        | Dirección de facturación (res.partner)              |
| `partner_shipping_id` | Many2one  | Sí        | Dirección de entrega (res.partner)                  |

### Campos de precio y moneda

| Campo             | Tipo      | Requerido | Descripción                                               |
|-------------------|-----------|:---------:|-----------------------------------------------------------|
| `pricelist_id`    | Many2one  | —         | Lista de precios aplicada                                 |
| `currency_id`     | Many2one  | —         | Computado desde `pricelist_id`                            |
| `currency_rate`   | Float     | —         | Tipo de cambio en el momento de la orden                  |
| `amount_untaxed`  | Monetary  | —         | Subtotal sin impuestos (computado)                        |
| `amount_tax`      | Monetary  | —         | Total de impuestos (computado)                            |
| `amount_total`    | Monetary  | —         | Total con impuestos (computado)                           |
| `tax_totals`      | Json      | —         | Resumen de impuestos para la vista (computado)            |

### Campos de fechas

| Campo              | Tipo      | Requerido | Descripción                                              |
|--------------------|-----------|:---------:|----------------------------------------------------------|
| `date_order`       | Datetime  | Sí*       | Fecha de la orden (*requerido si `state == 'sale'`)      |
| `validity_date`    | Date      | —         | Fecha de vencimiento del presupuesto                     |
| `commitment_date`  | Datetime  | —         | Fecha prometida de entrega al cliente                    |
| `expected_date`    | Datetime  | —         | Fecha esperada (computada desde las líneas)              |

### Campos de comercial

| Campo        | Tipo      | Requerido | Descripción                                                    |
|--------------|-----------|:---------:|----------------------------------------------------------------|
| `user_id`    | Many2one  | —         | Vendedor asignado (res.users)                                  |
| `team_id`    | Many2one  | —         | Equipo de ventas                                               |
| `tag_ids`    | Many2many | —         | Etiquetas CRM (crm.tag)                                        |

### Campos de facturación

| Campo              | Tipo          | Descripción                                                        |
|--------------------|---------------|--------------------------------------------------------------------|
| `invoice_ids`      | Many2many     | Facturas relacionadas (account.move)                               |
| `invoice_status`   | Selection     | `upselling` · `invoiced` · `to invoice` · `no` (computado)        |
| `invoice_count`    | Integer       | Cantidad de facturas (computado)                                   |

### Campos de pago en línea (portal)

| Campo                | Tipo      | Descripción                                              |
|----------------------|-----------|----------------------------------------------------------|
| `transaction_ids`    | Many2many | Transacciones de pago (payment.transaction)              |
| `require_signature`  | Boolean   | Exigir firma electrónica en el portal                    |
| `require_payment`    | Boolean   | Exigir pago para confirmar desde portal                  |
| `prepayment_percent` | Float     | Porcentaje de anticipo requerido (0.0–1.0)               |
| `signature`          | Image     | Firma digital del cliente                                |
| `signed_by`          | Char      | Nombre del firmante                                      |
| `signed_on`          | Datetime  | Fecha y hora de la firma                                 |

### Campos UTM (trazabilidad de marketing)

| Campo          | Tipo     | Descripción                           |
|----------------|----------|---------------------------------------|
| `campaign_id`  | Many2one | Campaña de marketing (utm.campaign)   |
| `medium_id`    | Many2one | Medio de marketing (utm.medium)       |
| `source_id`    | Many2one | Fuente de marketing (utm.source)      |

### Métodos clave

| Método                          | Tipo          | Descripción                                              |
|---------------------------------|---------------|----------------------------------------------------------|
| `action_confirm()`              | Acción        | Confirma la cotización → estado `sale`                   |
| `action_quotation_send()`       | Acción        | Abre wizard para enviar cotización por email             |
| `action_cancel()`               | Acción        | Cancela la orden                                         |
| `action_lock()`                 | Acción        | Bloquea la orden confirmada (locked=True)                |
| `action_unlock()`               | Acción        | Desbloquea la orden                                      |
| `_create_invoices()`            | Negocio       | Crea facturas agrupadas desde las líneas                 |
| `_prepare_invoice()`            | Negocio       | Prepara el diccionario de valores para la factura        |
| `_get_invoiceable_lines()`      | Negocio       | Retorna líneas facturables                               |
| `_compute_amounts()`            | Compute       | Calcula `amount_untaxed`, `amount_tax`, `amount_total`   |
| `_compute_invoice_status()`     | Compute       | Determina si la orden está facturada/pendiente           |
| `_send_order_confirmation_mail()` | Hook        | Envía email de confirmación al confirmar                 |
| `_cron_send_pending_emails()`   | Cron          | Procesa emails pendientes de forma asíncrona             |

---

## `sale.order.line`

```
Tabla BD : sale_order_line
```

### Campos de estructura

| Campo           | Tipo      | Requerido | Descripción                                                      |
|-----------------|-----------|:---------:|------------------------------------------------------------------|
| `order_id`      | Many2one  | Sí        | Orden de venta padre (ondelete: cascade)                         |
| `sequence`      | Integer   | —         | Orden de visualización                                           |
| `display_type`  | Selection | —         | `False` (línea normal) · `line_section` · `line_note`            |
| `is_downpayment`| Boolean   | —         | True si es una línea de anticipo                                 |
| `is_expense`    | Boolean   | —         | True si viene de un gasto (hr.expense)                           |

### Campos de producto

| Campo                           | Tipo      | Descripción                                              |
|---------------------------------|-----------|----------------------------------------------------------|
| `product_id`                    | Many2one  | Producto (product.product)                               |
| `product_template_id`           | Many2one  | Plantilla de producto (editable, para configurador)      |
| `product_custom_attribute_value_ids` | One2many | Valores de atributo personalizados                  |
| `product_no_variant_attribute_value_ids` | Many2many | Atributos sin variante (extras)               |
| `combo_item_id`                 | Many2one  | Elemento combo asociado (para productos bundle)          |

### Campos de cantidad y precio

| Campo               | Tipo      | Requerido | Descripción                                            |
|---------------------|-----------|:---------:|--------------------------------------------------------|
| `product_uom_qty`   | Float     | Sí        | Cantidad pedida                                        |
| `product_uom_id`    | Many2one  | Sí*       | Unidad de medida (*si línea es accountable)            |
| `price_unit`        | Float     | —         | Precio unitario (computado desde lista de precios)     |
| `discount`          | Float     | —         | Descuento en % (visible si grupo `group_discount_per_so_line`) |
| `tax_ids`           | Many2many | —         | Impuestos aplicados (computados desde producto)        |
| `price_subtotal`    | Monetary  | —         | Subtotal sin impuestos                                 |
| `price_total`       | Monetary  | —         | Total con impuestos                                    |
| `price_tax`         | Monetary  | —         | Total de impuestos                                     |
| `customer_lead`     | Float     | —         | Plazo de entrega en días                               |

### Campos de entrega y facturación

| Campo            | Tipo      | Descripción                                                    |
|------------------|-----------|----------------------------------------------------------------|
| `qty_delivered`  | Float     | Cantidad entregada (computado o manual según método)           |
| `qty_invoiced`   | Float     | Cantidad ya facturada (computado desde facturas)               |
| `qty_to_invoice` | Float     | Cantidad pendiente de facturar (computado)                     |
| `invoice_lines`  | Many2many | Líneas de factura relacionadas (account.move.line)             |
| `invoice_status` | Selection | `no` · `to invoice` · `invoiced` · `upselling` (computado)    |
| `amount_invoiced`   | Monetary | Monto ya facturado                                          |
| `amount_to_invoice` | Monetary | Monto pendiente de facturar                                 |

### Métodos clave

| Método                                    | Descripción                                                   |
|-------------------------------------------|---------------------------------------------------------------|
| `_compute_name()`                         | Genera descripción desde el producto                          |
| `_compute_price_unit()`                   | Obtiene precio desde lista de precios                         |
| `_compute_discount()`                     | Obtiene descuento desde lista de precios                      |
| `_compute_tax_ids()`                      | Aplica impuestos según posición fiscal del cliente            |
| `_compute_qty_delivered()`                | Entregado desde movimientos de stock o analítico              |
| `_compute_qty_invoiced()`                 | Facturado desde `account.move.line` en estado `posted`        |
| `_compute_invoice_status()`               | Estado de facturación por línea                               |
| `_prepare_invoice_line()`                 | Prepara valores para la línea de factura                      |
| `_get_sale_order_line_multiline_description_sale()` | Descripción multi-línea para la cotización         |

---

## `sale.report` (solo lectura)

Vista analítica que combina `sale.order` y `sale.order.line` para reportes. No tiene escritura directa — se usa únicamente en vistas de pivote, gráfico y dashboard.

Campos principales: `product_id`, `partner_id`, `user_id`, `team_id`, `date`, `price_subtotal`, `product_uom_qty`, `state`.
