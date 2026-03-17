# Vistas — `sale` — Odoo 19

## Resumen de vistas

| ID XML                              | Tipo     | Modelo         | Descripción                              |
|-------------------------------------|----------|----------------|------------------------------------------|
| `sale.view_order_form`              | form     | `sale.order`   | Formulario completo de orden/cotización  |
| `sale.sale_order_tree`              | list     | `sale.order`   | Lista base de órdenes                    |
| `sale.view_order_tree`             | list     | `sale.order`   | Lista de órdenes confirmadas             |
| `sale.view_quotation_tree`          | list     | `sale.order`   | Lista de cotizaciones (draft/sent)       |
| `sale.view_sale_order_kanban`       | kanban   | `sale.order`   | Tablero kanban por estado                |
| `sale.view_sale_order_calendar`     | calendar | `sale.order`   | Calendario mensual con actividades       |
| `sale.view_sale_order_graph`        | graph    | `sale.order`   | Gráfico: ventas por cliente              |
| `sale.view_sale_order_pivot`        | pivot    | `sale.order`   | Pivote: fecha × monto                    |
| `sale.sale_order_view_activity`     | activity | `sale.order`   | Vista de actividades                     |
| `sale.view_sales_order_filter`      | search   | `sale.order`   | Filtros y agrupaciones                   |
| `sale.view_order_line_tree`         | list     | `sale.order.line` | Líneas de orden (embebida)            |
| `sale.view_order_line_form`         | form     | `sale.order.line` | Formulario de línea (embebido)        |

---

## Formulario principal: `sale.view_order_form`

### Header (barra de estado y botones)

**Barra de estado:**
```
[Cotización] → [Cotización enviada] → [Orden de Venta] → [Cancelada]
```

**Botones de acción:**

| Botón                  | Método                     | Visible cuando                           |
|------------------------|----------------------------|------------------------------------------|
| Confirmar              | `action_confirm()`         | `state in ('draft', 'sent')`             |
| Enviar por email       | `action_quotation_send()`  | `state in ('draft', 'sent')`             |
| Crear Factura          | `action_create_invoice()`  | `state == 'sale'` y `invoice_status == 'to invoice'` |
| Enviar Pro-forma       | action pro-forma           | grupo `group_proforma_sales`             |
| Vista previa           | `action_preview_sale_order()` | siempre en draft/sent                 |
| Capturar pago          | `payment_action_capture()` | transacciones en estado `authorized`     |
| Anular pago            | `payment_action_void()`    | transacciones en estado `authorized`     |
| Cancelar               | `action_cancel()`          | `state != 'cancel'`                      |
| Bloquear               | `action_lock()`            | `state == 'sale'` y `locked == False`    |
| Desbloquear            | `action_unlock()`          | `locked == True`                         |
| Restablecer a borrador | `action_draft()`           | `state == 'cancel'`                      |

### Sección principal (header del documento)

| Campo                 | Visible/Editable | Notas                                          |
|-----------------------|------------------|------------------------------------------------|
| `partner_id`          | siempre          | Bloquea cuando `locked` o `state == 'sale'`    |
| `validity_date`       | draft/sent       | Fecha de vencimiento del presupuesto           |
| `date_order`          | siempre          | Solo lectura si `locked`                       |
| `partner_invoice_id`  | siempre          | Computado desde `partner_id`                   |
| `partner_shipping_id` | siempre          | Computado desde `partner_id`                   |
| `pricelist_id`        | siempre          | Grupo `product.group_product_pricelist`        |
| `currency_id`         | solo lectura     | Relacionado con `pricelist_id`                 |
| `payment_term_id`     | siempre          | Condiciones de pago                            |

### Pestaña: Líneas de orden

**Widget:** `sol_o2m` con tres modos: list, form, kanban

Columnas de la lista embebida:

| Campo              | Editable | Notas                                              |
|--------------------|----------|----------------------------------------------------|
| `product_id`       | Sí       | Dispara cálculo de precio, impuestos, descripción  |
| `name`             | Sí       | Descripción (multi-línea)                          |
| `product_uom_qty`  | Sí       | Cantidad pedida                                    |
| `product_uom_id`   | Sí       | Unidad de medida                                   |
| `customer_lead`    | Sí       | Plazo de entrega                                   |
| `price_unit`       | Sí       | Precio unitario                                    |
| `discount`         | Sí       | Grupo `group_discount_per_so_line`                 |
| `tax_ids`          | Sí       | Impuestos                                          |
| `price_subtotal`   | No       | Computado                                          |
| `qty_delivered`    | Cond.    | Solo lectura si viene de stock; editable si manual |
| `qty_invoiced`     | No       | Computado                                          |
| `qty_to_invoice`   | No       | Computado                                          |

**Botones en el pie de líneas:**
- `Agregar producto` — abre selector de producto
- `Agregar sección` — inserta `line_section`
- `Agregar nota` — inserta `line_note`
- `Catálogo` — abre catálogo de productos

**Pie de página:**
- `note` — Términos y condiciones
- `tax_totals` — Widget de resumen de impuestos

### Pestaña: Otra información

| Subcampo            | Grupo                | Campo                          |
|---------------------|----------------------|--------------------------------|
| **Ventas**          |                      | `user_id`, `team_id`, `tag_ids`, `client_order_ref`, `source_id`, `medium_id`, `campaign_id` |
| **Facturación**     |                      | `invoice_status`, `fiscal_position_id`, `payment_term_id` |
| **Entrega**         |                      | `commitment_date`, `expected_date`, `warehouse_id`* |
| **Firma / Pago**    |                      | `require_signature`, `require_payment`, `prepayment_percent` |

*`warehouse_id` disponible solo si módulo `stock` instalado

### Sección de firma del cliente

Visible en órdenes `sent`/`sale` cuando `require_signature=True`:
- `signature` (imagen de firma)
- `signed_by` (nombre del firmante)
- `signed_on` (fecha)

---

## Vistas de lista

### `view_quotation_tree` — Cotizaciones
Columnas: `name`, `date_order`, `partner_id`, `user_id`, `team_id`, `amount_total`, `state`
Decoraciones: `text-muted` para canceladas, `text-info` para enviadas

### `view_order_tree` — Órdenes de venta
Columnas: `name`, `date_order`, `partner_id`, `user_id`, `amount_total`, `invoice_status`
Botón rápido: crear factura inline

---

## Vista de búsqueda: `view_sales_order_filter`

### Filtros predefinidos

| Filtro                | Dominio                                          |
|-----------------------|--------------------------------------------------|
| Mis pedidos           | `[('user_id', '=', uid)]`                        |
| Cotizaciones          | `[('state', 'in', ('draft', 'sent'))]`           |
| Órdenes de venta      | `[('state', '=', 'sale')]`                       |
| A facturar            | `[('invoice_status', '=', 'to invoice')]`        |
| Upselling             | `[('invoice_status', '=', 'upselling')]`         |

### Agrupaciones predefinidas

| Agrupar por      | Campo               |
|------------------|---------------------|
| Vendedor         | `user_id`           |
| Equipo de ventas | `team_id`           |
| Cliente          | `partner_id`        |
| Fecha de orden   | `date_order`        |

---

## Menú: `sale_menus.xml`

```
Sales (raíz, seq=30)
├── Pedidos (seq=10)
│   ├── Cotizaciones        → action_quotations_with_onboarding
│   ├── Órdenes de Venta    → action_orders
│   ├── Equipos de Ventas
│   └── Clientes
├── A Facturar (seq=20)
│   ├── Órdenes a Facturar  → action_orders_to_invoice
│   └── Órdenes Upselling   → action_orders_upselling
├── Productos (seq=30)
│   ├── Productos
│   ├── Variantes           [grupo: group_product_variant]
│   └── Listas de Precios   [grupo: group_product_pricelist]
├── Reportes (seq=40)       [grupo: group_sale_manager]
│   ├── Ventas
│   ├── Vendedores
│   ├── Productos
│   └── Clientes
└── Configuración (seq=50)  [grupo: group_sale_manager]
    ├── Ajustes             [grupo: base.group_system]
    ├── Equipos de Ventas
    ├── Pedidos: Etiquetas
    ├── Productos: Atributos, Combos, Categorías, Etiquetas, UdM
    ├── Pagos: Proveedores, Métodos, Tokens, Transacciones
    └── Actividades: Tipos, Planes
```
