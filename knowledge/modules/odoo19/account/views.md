# Vistas — `account` — Odoo 19

## Resumen de vistas principales

| ID XML                                       | Tipo     | Modelo              | Descripción                                 |
|----------------------------------------------|----------|---------------------|---------------------------------------------|
| `account.view_move_form`                     | form     | `account.move`      | Formulario completo de asiento/factura       |
| `account.view_out_invoice_tree`              | list     | `account.move`      | Lista de facturas de cliente                |
| `account.view_in_invoice_tree`               | list     | `account.move`      | Lista de facturas de proveedor              |
| `account.view_account_move_filter`           | search   | `account.move`      | Filtros y agrupaciones                      |
| `account.view_journal_form`                  | form     | `account.journal`   | Configuración de diario                     |
| `account.view_journal_list`                  | list     | `account.journal`   | Lista de diarios                            |
| `account.account_account_form`               | form     | `account.account`   | Cuenta del plan contable                    |
| `account.account_account_tree`               | list     | `account.account`   | Plan de cuentas                             |
| `account.view_account_tax_form`              | form     | `account.tax`       | Configuración de impuesto                   |
| `account.view_tax_tree`                      | list     | `account.tax`       | Lista de impuestos                          |
| `account.view_account_payment_form`          | form     | `account.payment`   | Formulario de pago                          |
| `account.view_account_payment_tree`          | list     | `account.payment`   | Lista de pagos                              |
| `account.view_account_journal_dashboard_kanban` | kanban | `account.journal`  | Dashboard de diarios                        |

---

## Formulario de factura: `account.view_move_form`

### Header

**Barra de estado:**
```
[Borrador] → [Publicado] → [Cancelado]
```

**Botones:**

| Botón                  | Método                       | Visible cuando                                        |
|------------------------|------------------------------|-------------------------------------------------------|
| Confirmar              | `action_post()`              | `state == 'draft'`                                    |
| Enviar e Imprimir      | `action_send_and_print()`    | `state == 'posted'`, `move_type` es factura           |
| Registrar Pago         | `action_register_payment()`  | `state == 'posted'` y `payment_state in ('not_paid', 'partial')` |
| Restablecer a Borrador | `button_draft()`             | `state == 'posted'` (solo si no tiene hash)           |
| Cancelar               | `button_cancel()`            | `state != 'cancel'`                                   |
| Añadir Nota de Crédito | `_reverse_moves()`           | `state == 'posted'`                                   |
| Vista Previa           | acción portal                | siempre en facturas                                   |

### Sección principal

| Campo                     | Editable          | Notas                                              |
|---------------------------|-------------------|----------------------------------------------------|
| `partner_id`              | draft             | Bloquea al publicar                                |
| `invoice_date`            | draft             | Requerida para publicar facturas                   |
| `invoice_date_due`        | draft             | Calculada desde condiciones de pago                |
| `invoice_payment_term_id` | draft             | Alterna con `invoice_date_due`                     |
| `journal_id`              | draft             | Determina el tipo de asiento                       |
| `currency_id`             | draft             | Afecta todos los montos                            |
| `ref`                     | siempre           | Referencia libre del proveedor                     |
| `narration`               | siempre           | Términos y condiciones                             |

### Líneas de factura (pestaña principal)

Columnas en la lista embebida:

| Campo                | Editable | Notas                                                    |
|----------------------|----------|----------------------------------------------------------|
| `product_id`         | Sí       | Carga cuenta, impuestos y descripción automáticamente    |
| `name`               | Sí       | Descripción de la línea                                  |
| `account_id`         | Sí       | Cuenta contable (filtrada por tipo de factura)           |
| `quantity`           | Sí       | Cantidad                                                 |
| `product_uom_id`     | Sí       | Unidad de medida                                         |
| `price_unit`         | Sí       | Precio unitario                                          |
| `discount`           | Sí       | Descuento % (grupo `group_discount_per_so_line`)         |
| `tax_ids`            | Sí       | Impuestos aplicados                                      |
| `price_subtotal`     | No       | Computado                                                |
| `analytic_distribution` | Sí    | Distribución por centros de costo                        |

**Botones:**
- `Agregar línea` — nueva línea de producto
- `Agregar sección` / `Agregar nota`
- `Agregar líneas de` — importar desde PO u otros documentos

**Pie de página:**
- `narration` — campo de notas
- Widget `tax_totals` — desglose de impuestos por grupo
- `amount_untaxed`, `amount_tax`, `amount_total`

### Pestaña: Información de la factura

| Campo                   | Descripción                                            |
|-------------------------|--------------------------------------------------------|
| `fiscal_position_id`    | Posición fiscal aplicada                               |
| `invoice_user_id`       | Vendedor (relacionado con `sale.order`)                |
| `invoice_origin`        | Documento origen (referencia a SO, PO, etc.)           |
| `delivery_date`         | Fecha de entrega                                       |
| `partner_shipping_id`   | Dirección de entrega                                   |
| `partner_bank_id`       | Cuenta bancaria para instrucciones de pago             |

### Pestaña: Asientos contables (Diario)

Visible para `group_account_user`. Muestra las líneas contables (`line_ids`) con:
- `account_id`, `partner_id`, `debit`, `credit`, `amount_currency`
- `matching_number` — estado de conciliación
- `analytic_distribution`

### Widget de pago

Visible en facturas publicadas. Muestra:
- Pagos registrados con montos y fechas
- Notas de crédito aplicadas
- Saldo pendiente
- Botón de conciliación manual (si hay)

---

## Dashboard de diarios: `view_account_journal_dashboard_kanban`

Tarjeta por diario con datos en tiempo real:

**Diario de Ventas:**
- Borradores (cantidad y monto)
- En proceso (cantidad y monto)
- Vencidas (cantidad y monto)
- Acciones: Nueva Factura, Subir

**Diario de Compras:**
- Igual que ventas pero con facturas de proveedor

**Diario de Banco/Caja:**
- Saldo actual
- Transacciones del último mes
- Pagos por registrar
- Acciones: Nuevo pago, Importar extracto, Reconciliar

**Diario General:**
- Asientos en borrador
- Acción: Nuevo Asiento

---

## Menús principales

```
Contabilidad (raíz)
├── Panel                           → dashboard de diarios
├── Clientes
│   ├── Facturas                    → out_invoice
│   ├── Notas de Crédito            → out_refund
│   ├── Pagos                       → payment_type=inbound
│   └── Clientes                    → res.partner (customer)
├── Proveedores
│   ├── Facturas                    → in_invoice
│   ├── Notas de Crédito            → in_refund
│   ├── Pagos                       → payment_type=outbound
│   └── Proveedores                 → res.partner (supplier)
├── Contabilidad                    [grupo: group_account_user]
│   ├── Asientos de Diario          → entry
│   ├── Extractos Bancarios
│   └── Conciliación
├── Reportes                        [grupo: group_account_user]
│   ├── Balance General
│   ├── Pérdidas y Ganancias
│   ├── Libro Mayor
│   ├── Libro Diario
│   └── Impuestos
└── Configuración                   [grupo: group_account_manager]
    ├── Ajustes
    ├── Plan de Cuentas
    ├── Diarios
    ├── Impuestos
    ├── Posiciones Fiscales
    ├── Condiciones de Pago
    └── Períodos de Bloqueo
```

---

## Vista de búsqueda: `account.view_account_move_filter`

### Filtros predefinidos

| Filtro              | Dominio                                                   |
|---------------------|-----------------------------------------------------------|
| Mis facturas        | `[('invoice_user_id', '=', uid)]`                         |
| Borradores          | `[('state', '=', 'draft')]`                               |
| En proceso          | `[('payment_state', '=', 'in_payment')]`                  |
| Vencidas            | `[('payment_state', 'in', ('not_paid', 'partial')), ('invoice_date_due', '<', today)]` |
| No pagadas          | `[('payment_state', 'in', ('not_paid', 'partial'))]`      |
| Mes siguiente       | filtro por fecha contable                                 |

### Agrupaciones predefinidas

| Agrupar por       | Campo               |
|-------------------|---------------------|
| Cliente/Proveedor | `partner_id`        |
| Vendedor          | `invoice_user_id`   |
| Diario            | `journal_id`        |
| Empresa           | `company_id`        |
| Fecha de factura  | `invoice_date`      |
| Fecha contable    | `date`              |
