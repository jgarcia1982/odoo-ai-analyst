# Modelos — `account` — Odoo 19

## Diagrama de relaciones

```
res.company ──────────────────────────────────────┐
res.partner ──────────────────────────────────────┤
                                                  ↓
account.journal ──────────────→ account.move ←── account.payment.term
account.fiscal.position ──────→      │
                                     │
              ┌──────────────────────┤
              ↓                      ↓
  account.move.line          account.payment
       │   │   │                     │
       │   │   └──→ account.tax      └──→ account.journal
       │   └──────→ account.account
       └──────────→ res.partner

account.partial.reconcile ←── account.move.line (matched_debit/credit_ids)
account.full.reconcile    ←── account.move.line (full_reconcile_id)
```

---

## `account.move`

```
Tabla BD  : account_move
Mixins    : portal.mixin, mail.thread.main.attachment, mail.activity.mixin,
            sequence.mixin, product.catalog.mixin, account.document.import.mixin
Índices BD: (journal_id, state, payment_state, move_type, date)
            UNIQUE (name, journal_id) WHERE state = 'posted'
```

### Campos de identidad

| Campo         | Tipo      | Req. | Descripción                                                      |
|---------------|-----------|:----:|------------------------------------------------------------------|
| `name`        | Char      | —    | Número del asiento (computado por secuencia, ej. INV/2024/0001)  |
| `ref`         | Char      | —    | Referencia libre (factura del proveedor, PO, etc.)               |
| `move_type`   | Selection | Sí   | `entry` · `out_invoice` · `out_refund` · `in_invoice` · `in_refund` · `out_receipt` · `in_receipt` |
| `state`       | Selection | Sí   | `draft` · `posted` · `cancel`                                    |

### Campos contables

| Campo                      | Tipo      | Req. | Descripción                                              |
|----------------------------|-----------|:----:|----------------------------------------------------------|
| `journal_id`               | Many2one  | Sí   | Diario contable (account.journal)                        |
| `company_id`               | Many2one  | Sí   | Empresa (indexado)                                       |
| `date`                     | Date      | Sí   | Fecha contable (computada desde `invoice_date`)          |
| `fiscal_position_id`       | Many2one  | —    | Posición fiscal del cliente/proveedor                    |
| `line_ids`                 | One2many  | —    | Líneas del asiento (account.move.line)                   |

### Campos de factura

| Campo                      | Tipo      | Req. | Descripción                                              |
|----------------------------|-----------|:----:|----------------------------------------------------------|
| `invoice_date`             | Date      | —    | Fecha de la factura (para facturas de cliente/proveedor) |
| `invoice_date_due`         | Date      | —    | Fecha de vencimiento (computada desde condiciones pago)  |
| `delivery_date`            | Date      | —    | Fecha de entrega                                         |
| `partner_id`               | Many2one  | —    | Cliente o proveedor (res.partner)                        |
| `partner_shipping_id`      | Many2one  | —    | Dirección de entrega                                     |
| `partner_bank_id`          | Many2one  | —    | Cuenta bancaria del destinatario                         |
| `invoice_payment_term_id`  | Many2one  | —    | Condiciones de pago (account.payment.term)               |
| `invoice_origin`           | Char      | —    | Referencia al documento origen (ej. S00023)              |
| `invoice_user_id`          | Many2one  | —    | Vendedor asignado (res.users)                            |
| `narration`                | Html      | —    | Términos y condiciones / notas al pie                    |

### Campos de montos

| Campo               | Tipo      | Descripción                                                     |
|---------------------|-----------|-----------------------------------------------------------------|
| `currency_id`       | Many2one  | Moneda del documento                                            |
| `amount_untaxed`    | Monetary  | Subtotal sin impuestos (computado, stored)                      |
| `amount_tax`        | Monetary  | Total de impuestos (computado, stored)                          |
| `amount_total`      | Monetary  | Total con impuestos (computado, stored)                         |
| `amount_residual`   | Monetary  | Saldo pendiente de pago (computado, stored)                     |
| `amount_total_words`| Char      | Total en letras                                                 |
| `invoice_currency_rate` | Float | Tipo de cambio en el momento del documento                    |
| `direction_sign`    | Integer   | Multiplicador de signo: `1` (salida) · `-1` (entrada)           |

### Campos de pago y conciliación

| Campo                     | Tipo      | Descripción                                              |
|---------------------------|-----------|----------------------------------------------------------|
| `payment_state`           | Selection | `not_paid` · `in_payment` · `paid` · `partial` · `reversed` · `blocked` |
| `origin_payment_id`       | Many2one  | Pago que originó este asiento                            |
| `matched_payment_ids`     | Many2many | Pagos conciliados con esta factura                       |
| `statement_line_id`       | Many2one  | Línea de extracto bancario relacionada                   |
| `payment_count`           | Integer   | Cantidad de pagos reconciliados (computado)              |

### Campos de publicación automática

| Campo           | Tipo      | Descripción                                                    |
|-----------------|-----------|----------------------------------------------------------------|
| `auto_post`     | Selection | `no` · `at_date` · `monthly` · `quarterly` · `yearly`         |
| `auto_post_until` | Date    | Publicar automáticamente hasta esta fecha                      |

### Campos de seguridad / inalterabilidad

| Campo                    | Tipo    | Descripción                                               |
|--------------------------|---------|-----------------------------------------------------------|
| `restrict_mode_hash_table` | Boolean | Activado desde el diario: habilita hash de asientos     |
| `inalterable_hash`       | Char    | Hash encadenado para detectar alteraciones                |
| `secure_sequence_number` | Integer | Número de secuencia de inalterabilidad                    |
| `secured`                | Boolean | True si el asiento ya tiene hash (computado)              |

### Métodos clave

| Método                         | Tipo      | Descripción                                               |
|--------------------------------|-----------|-----------------------------------------------------------|
| `action_post()`                | Acción    | Publica el asiento: valida, asigna secuencia, crea hash   |
| `button_draft()`               | Acción    | Regresa a borrador (solo si no tiene hash)                |
| `button_cancel()`              | Acción    | Cancela el asiento                                        |
| `_reverse_moves()`             | Negocio   | Crea asiento de reversión                                 |
| `_compute_amount()`            | Compute   | Calcula `amount_untaxed`, `amount_tax`, `amount_total`, `amount_residual` |
| `_compute_payment_state()`     | Compute   | Determina el estado de pago via SQL de conciliación       |
| `_compute_name()`              | Compute   | Asigna el número secuencial del asiento                   |
| `_compute_date()`              | Compute   | Calcula la fecha contable desde `invoice_date`            |
| `_get_accounting_date()`       | Negocio   | Ajusta la fecha según período bloqueado                   |
| `is_invoice()`                 | Helper    | True si `move_type` es factura o nota de crédito          |
| `is_sale_document()`           | Helper    | True si es factura de cliente o recibo de venta           |
| `is_purchase_document()`       | Helper    | True si es factura de proveedor                           |

---

## `account.move.line`

```
Tabla BD: account_move_line
Índices : (move_id), (account_id), (company_id), (journal_id, date)
```

### Campos de identificación

| Campo           | Tipo      | Req. | Descripción                                                     |
|-----------------|-----------|:----:|------------------------------------------------------------------|
| `move_id`       | Many2one  | Sí   | Asiento padre (ondelete: cascade, indexado)                      |
| `journal_id`    | Many2one  | —    | Diario (relacionado desde move_id, stored)                       |
| `company_id`    | Many2one  | —    | Empresa (stored, indexado)                                       |
| `date`          | Date      | —    | Fecha (relacionada desde move_id, stored)                        |
| `sequence`      | Integer   | —    | Orden de la línea                                                |
| `name`          | Char      | —    | Descripción / etiqueta de la línea                               |

### Campos contables

| Campo           | Tipo      | Req. | Descripción                                                     |
|-----------------|-----------|:----:|------------------------------------------------------------------|
| `account_id`    | Many2one  | Sí   | Cuenta contable (account.account, indexado)                      |
| `partner_id`    | Many2one  | —    | Contacto asociado a la línea                                     |
| `display_type`  | Selection | —    | `product` · `tax` · `payment_term` · `line_section` · `line_note` · `rounding` · `non_deductible_tax` |

### Campos de monto

| Campo              | Tipo      | Descripción                                                   |
|--------------------|-----------|---------------------------------------------------------------|
| `debit`            | Monetary  | Debe (moneda de la empresa)                                   |
| `credit`           | Monetary  | Haber (moneda de la empresa)                                  |
| `balance`          | Monetary  | `debit - credit` (computado)                                  |
| `amount_currency`  | Monetary  | Monto en la moneda del documento                              |
| `currency_id`      | Many2one  | Moneda de la línea                                            |

### Campos de conciliación

| Campo                  | Tipo      | Descripción                                               |
|------------------------|-----------|-----------------------------------------------------------|
| `amount_residual`      | Monetary  | Saldo sin conciliar (computado, stored)                   |
| `reconciled`           | Boolean   | True si está totalmente conciliado                        |
| `full_reconcile_id`    | Many2one  | Conciliación completa (account.full.reconcile)            |
| `matched_debit_ids`    | One2many  | Conciliaciones parciales en el debe                       |
| `matched_credit_ids`   | One2many  | Conciliaciones parciales en el haber                      |
| `matching_number`      | Char      | Número de match: `'P'` (parcial) o nombre del full match  |

### Campos de impuesto

| Campo                      | Tipo      | Descripción                                           |
|----------------------------|-----------|-------------------------------------------------------|
| `tax_ids`                  | Many2many | Impuestos aplicados a esta línea                      |
| `tax_line_id`              | Many2one  | Si esta línea es el resultado de un impuesto          |
| `tax_repartition_line_id`  | Many2one  | Línea de distribución del impuesto                    |
| `tax_tag_ids`              | Many2many | Tags para cuadrículas de reporte fiscal               |
| `tax_base_amount`          | Monetary  | Base imponible de esta línea de impuesto              |

### Otros campos

| Campo                     | Tipo      | Descripción                                            |
|---------------------------|-----------|--------------------------------------------------------|
| `product_id`              | Many2one  | Producto de la línea (si aplica)                       |
| `payment_id`              | Many2one  | Pago relacionado (account.payment)                     |
| `analytic_distribution`   | Json      | Distribución analítica (centro de costo / proyecto)    |

---

## `account.journal`

```
Tabla BD: account_journal
Mixins  : portal.mixin, mail.alias.mixin.optional, mail.thread, mail.activity.mixin
```

| Campo                             | Tipo      | Req. | Descripción                                            |
|-----------------------------------|-----------|:----:|--------------------------------------------------------|
| `name`                            | Char      | Sí   | Nombre del diario                                      |
| `code`                            | Char      | Sí   | Prefijo de secuencia (máx. 5 chars, ej. `INV`, `BNK`) |
| `type`                            | Selection | Sí   | `sale` · `purchase` · `cash` · `bank` · `credit` · `general` |
| `active`                          | Boolean   | —    | Activo/inactivo                                        |
| `sequence`                        | Integer   | —    | Orden de visualización                                 |
| `default_account_id`              | Many2one  | —    | Cuenta contable por defecto                            |
| `suspense_account_id`             | Many2one  | —    | Cuenta de suspenso para conciliación bancaria          |
| `profit_account_id`               | Many2one  | —    | Cuenta de ganancias de caja                            |
| `loss_account_id`                 | Many2one  | —    | Cuenta de pérdidas de caja                             |
| `currency_id`                     | Many2one  | —    | Moneda del diario (si difiere de la empresa)           |
| `company_id`                      | Many2one  | Sí   | Empresa propietaria                                    |
| `bank_account_id`                 | Many2one  | —    | Cuenta bancaria asociada (res.partner.bank)            |
| `refund_sequence`                 | Boolean   | —    | Secuencia separada para notas de crédito               |
| `payment_sequence`                | Boolean   | —    | Secuencia separada para pagos                          |
| `restrict_mode_hash_table`        | Boolean   | —    | Habilitar inalterabilidad con hash                     |
| `inbound_payment_method_line_ids` | One2many  | —    | Métodos de pago de entrada                             |
| `outbound_payment_method_line_ids`| One2many  | —    | Métodos de pago de salida                              |
| `invoice_template_pdf_report_id`  | Many2one  | —    | Plantilla PDF personalizada                            |

---

## `account.account`

```
Tabla BD: account_account
```

| Campo          | Tipo      | Req. | Descripción                                                          |
|----------------|-----------|:----:|----------------------------------------------------------------------|
| `name`         | Char      | Sí   | Nombre de la cuenta (tracked)                                        |
| `code`         | Char      | Sí   | Código (máx. 64 chars, tracked), ej. `101.01`                        |
| `account_type` | Selection | Sí   | Ver tabla de tipos abajo                                             |
| `reconcile`    | Boolean   | —    | Permite conciliación (obligatorio en cuentas por cobrar/pagar)       |
| `currency_id`  | Many2one  | —    | Fuerza una sola moneda en esta cuenta                                |
| `company_ids`  | Many2many | —    | Empresas donde está disponible (multi-empresa compartida)            |
| `tax_ids`      | Many2many | —    | Impuestos por defecto para esta cuenta                               |
| `tag_ids`      | Many2many | —    | Tags personalizadas (account.account.tag)                            |
| `group_id`     | Many2one  | —    | Grupo contable (computado desde código)                              |
| `active`       | Boolean   | —    | Activo/inactivo                                                      |
| `non_trade`    | Boolean   | —    | Cuenta por cobrar/pagar no comercial                                 |

### Tipos de cuenta (`account_type`)

| Valor                    | Categoría  | Descripción                     |
|--------------------------|------------|---------------------------------|
| `asset_receivable`       | Activo     | Cuentas por cobrar              |
| `asset_cash`             | Activo     | Efectivo y banco                |
| `asset_current`          | Activo     | Activo corriente                |
| `asset_non_current`      | Activo     | Activo no corriente             |
| `asset_prepayments`      | Activo     | Anticipos pagados               |
| `asset_fixed`            | Activo     | Activo fijo                     |
| `liability_payable`      | Pasivo     | Cuentas por pagar               |
| `liability_credit_card`  | Pasivo     | Tarjeta de crédito              |
| `liability_current`      | Pasivo     | Pasivo corriente                |
| `liability_non_current`  | Pasivo     | Pasivo no corriente             |
| `equity`                 | Capital    | Capital contable                |
| `equity_unaffected`      | Capital    | Utilidades retenidas            |
| `income`                 | Ingresos   | Ingresos operativos             |
| `income_other`           | Ingresos   | Otros ingresos                  |
| `expense`                | Gastos     | Gastos operativos               |
| `expense_other`          | Gastos     | Otros gastos                    |
| `expense_depreciation`   | Gastos     | Depreciación                    |
| `expense_direct_cost`    | Gastos     | Costo directo (COGS)            |
| `off_balance`            | Fuera      | Cuentas de orden                |

---

## `account.tax`

```
Tabla BD: account_tax
```

| Campo                            | Tipo      | Req. | Descripción                                              |
|----------------------------------|-----------|:----:|----------------------------------------------------------|
| `name`                           | Char      | Sí   | Nombre del impuesto (tracked)                            |
| `type_tax_use`                   | Selection | Sí   | `sale` · `purchase` · `none`                             |
| `amount_type`                    | Selection | Sí   | `percent` · `fixed` · `division` · `group`               |
| `amount`                         | Float     | —    | Tasa (16.0 para 16%, o monto fijo)                        |
| `sequence`                       | Integer   | —    | Orden de cálculo cuando hay múltiples impuestos          |
| `price_include`                  | Boolean   | —    | Precio ya incluye el impuesto                            |
| `include_base_amount`            | Boolean   | —    | Agrega este impuesto a la base del siguiente             |
| `is_base_affected`               | Boolean   | —    | Es afectado por impuestos anteriores con `include_base`  |
| `tax_exigibility`                | Selection | —    | `on_invoice` (devengado) · `on_payment` (base caja)      |
| `cash_basis_transition_account_id` | Many2one | —  | Cuenta de transición para impuesto base caja             |
| `tax_group_id`                   | Many2one  | Sí   | Grupo de impuesto (para reportes y UI)                   |
| `country_id`                     | Many2one  | —    | País al que aplica                                       |
| `company_id`                     | Many2one  | Sí   | Empresa                                                  |
| `children_tax_ids`               | Many2many | —    | Impuestos hijos (cuando `amount_type = 'group'`)         |
| `invoice_repartition_line_ids`   | One2many  | Sí   | Distribución en facturas                                 |
| `refund_repartition_line_ids`    | One2many  | Sí   | Distribución en notas de crédito                         |
| `active`                         | Boolean   | —    | Activo/inactivo                                          |

---

## `account.payment`

```
Tabla BD: account_payment
```

| Campo                    | Tipo      | Req. | Descripción                                              |
|--------------------------|-----------|:----:|----------------------------------------------------------|
| `name`                   | Char      | —    | Número del pago (computado por secuencia)                |
| `date`                   | Date      | Sí   | Fecha del pago                                           |
| `state`                  | Selection | Sí   | `draft` · `in_process` · `paid` · `canceled` · `rejected` |
| `payment_type`           | Selection | Sí   | `inbound` (cobro) · `outbound` (pago)                    |
| `partner_type`           | Selection | —    | `customer` · `supplier`                                  |
| `partner_id`             | Many2one  | —    | Cliente o proveedor                                      |
| `journal_id`             | Many2one  | Sí   | Diario de banco o caja                                   |
| `currency_id`            | Many2one  | —    | Moneda del pago                                          |
| `amount`                 | Monetary  | Sí   | Monto del pago                                           |
| `amount_signed`          | Monetary  | —    | Monto con signo (positivo = cobro, negativo = pago)      |
| `move_id`                | Many2one  | —    | Asiento contable generado                                |
| `payment_method_line_id` | Many2one  | —    | Método de pago (cheque, transferencia, etc.)             |
| `payment_reference`      | Char      | —    | Referencia (número de cheque, transferencia)             |
| `memo`                   | Char      | —    | Nota del pago                                            |
| `partner_bank_id`        | Many2one  | —    | Cuenta bancaria del destinatario                         |
| `invoice_ids`            | Many2many | —    | Facturas asociadas                                       |
| `reconciled_invoice_ids` | Many2many | —    | Facturas conciliadas (computado)                         |

---

## Modelos auxiliares relevantes

| Modelo                       | Descripción                                                    |
|------------------------------|----------------------------------------------------------------|
| `account.fiscal.position`    | Mapea impuestos y cuentas según el país/región del cliente     |
| `account.payment.term`       | Define plazos de pago (30 días, 50% ahora + 50% en 30 días)   |
| `account.partial.reconcile`  | Registro de una conciliación parcial entre dos líneas          |
| `account.full.reconcile`     | Conciliación completa de una cuenta por cobrar/pagar           |
| `account.tax.repartition.line`| Define a qué cuenta va cada porción de un impuesto            |
| `account.tax.group`          | Agrupa impuestos para mostrar en la UI (ej. "IVA", "ISR")      |
| `account.bank.statement.line`| Línea importada de un extracto bancario                        |
| `account.group`              | Agrupa cuentas contables por nivel (computado desde código)    |
