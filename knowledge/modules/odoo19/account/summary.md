# Módulo: `account` — Odoo 19

> **Versión del módulo:** 1.4
> **Categoría:** Accounting/Accounting
> **Licencia:** LGPL-3
> **Fuente:** Odoo Community

## Propósito

Núcleo del sistema contable de doble partida. Gestiona el ciclo completo desde factura hasta conciliación bancaria: facturas de cliente y proveedor, pagos, asientos manuales, plan de cuentas, impuestos, posiciones fiscales y reportes financieros.

## Dependencias

| Módulo        | Rol en la dependencia                                     |
|---------------|-----------------------------------------------------------|
| `base_setup`  | Configuración inicial del sistema                         |
| `onboarding`  | Asistente de configuración inicial                        |
| `product`     | Productos en líneas de factura                            |
| `analytic`    | Distribución analítica en asientos y líneas               |
| `portal`      | Acceso de clientes a sus facturas desde el portal         |
| `digest`      | Reportes periódicos por email (KPIs)                      |

> **Módulos que enriquecen `account`:** `sale` (facturas desde órdenes), `purchase` (facturas de proveedor), `stock` (valoración de inventario), `account_accountant` (enterprise: reconciliación avanzada)

## Modelos principales

| Modelo                    | Descripción                                              |
|---------------------------|----------------------------------------------------------|
| `account.move`            | Asiento contable, factura, nota de crédito o recibo      |
| `account.move.line`       | Línea individual de un asiento (debe / haber)            |
| `account.journal`         | Diario contable (ventas, compras, banco, caja, general)  |
| `account.account`         | Cuenta del plan contable (chart of accounts)             |
| `account.tax`             | Definición de impuesto con reglas de distribución        |
| `account.payment`         | Pago registrado (cliente o proveedor)                    |
| `account.fiscal.position` | Mapeo de impuestos/cuentas por posición fiscal           |
| `account.payment.term`    | Condiciones de pago con plazos                           |

## Flujo de estados de `account.move`

```
draft (Borrador)
    ↓ action_post() / button_post()
posted (Publicado / Validado)
    ↓ button_cancel()
cancel (Cancelado)
    ↓ button_draft()
draft (Borrador)
```

## Estados de pago (`payment_state`) en facturas publicadas

```
not_paid   → ninguna conciliación
in_payment → pago registrado, aún no confirmado en banco
partial    → conciliación parcial
paid       → conciliado totalmente
reversed   → revertido por nota de crédito
blocked    → marcado como disputado (no se puede conciliar)
```

## Tipos de asiento (`move_type`)

| Valor          | Descripción                              | Diario típico  |
|----------------|------------------------------------------|----------------|
| `entry`        | Asiento contable manual                  | General        |
| `out_invoice`  | Factura de cliente                       | Ventas         |
| `out_refund`   | Nota de crédito de cliente               | Ventas         |
| `in_invoice`   | Factura de proveedor                     | Compras        |
| `in_refund`    | Nota de crédito de proveedor             | Compras        |
| `out_receipt`  | Recibo de venta (sin factura formal)     | Caja/Banco     |
| `in_receipt`   | Recibo de compra                         | Caja/Banco     |

## Integraciones clave

- **`sale.order`** → genera `account.move` tipo `out_invoice` via `_create_invoices()`
- **`purchase.order`** → genera `account.move` tipo `in_invoice`
- **`account.payment`** → crea `account.move` en diario de banco/caja y concilia con facturas
- **`account.bank.statement.line`** → importación bancaria conciliada contra pagos y facturas
- **`analytic.distribution`** → distribuye costos/ingresos entre centros analíticos por línea
