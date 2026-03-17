# Módulo: `sale` — Odoo 19

> **Versión del módulo:** 1.2
> **Categoría:** Sales/Sales
> **Licencia:** LGPL-3
> **Fuente:** Odoo Community

## Propósito

Núcleo del proceso de ventas. Gestiona el ciclo completo desde cotización hasta factura: creación de presupuestos, confirmación de órdenes, envío al cliente, seguimiento de entregas y generación de facturas.

## Dependencias

| Módulo           | Rol en la dependencia                            |
|------------------|--------------------------------------------------|
| `sales_team`     | Grupos de seguridad de ventas y equipos          |
| `account_payment`| Integración con facturas y pagos en línea        |
| `utm`            | Rastreo de campañas (source, medium, campaign)   |

> **Módulos opcionalmente enriquecidos:** `stock` (entregas), `crm` (oportunidades), `project` (servicios), `analytic` (distribución analítica)

## Modelos principales

| Modelo            | Descripción                                   |
|-------------------|-----------------------------------------------|
| `sale.order`      | Cotización u orden de venta                   |
| `sale.order.line` | Línea de producto, sección, nota o anticipo   |
| `sale.report`     | Vista analítica para reportes (read-only)     |

## Flujo de estados de `sale.order`

```
draft (Cotización)
    ↓ action_quotation_send()
sent (Enviada)
    ↓ action_confirm()
sale (Orden confirmada)
    ↓ _create_invoices()
[Facturación en account.move]
    ↓ action_cancel()
cancel (Cancelada)
```

## Integraciones clave

- **`account.move`** — las órdenes generan facturas via `_create_invoices()`
- **`payment.transaction`** — pago en línea desde el portal del cliente
- **`stock.picking`** — las líneas generan movimientos de entrega (requiere `stock`)
- **`crm.lead`** — órdenes vinculadas a oportunidades (requiere `crm`)
- **`account.analytic`** — distribución analítica por línea de orden
