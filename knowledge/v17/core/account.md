# Módulo: account — Odoo 17

## Propósito

Contabilidad general de doble partida. Gestiona facturas, pagos, asientos contables, plan de cuentas, impuestos y reportes financieros.

## Modelos principales

### `account.move`
Asiento contable. Unifica facturas, notas de crédito y asientos manuales.

| Campo                  | Tipo         | Descripción                                              |
|------------------------|--------------|----------------------------------------------------------|
| `name`                 | Char         | Número de documento (ej. INV/2024/00001)                 |
| `move_type`            | Selection    | `entry`, `out_invoice`, `out_refund`, `in_invoice`, `in_refund`, `out_receipt`, `in_receipt` |
| `state`                | Selection    | `draft`, `posted`, `cancel`                              |
| `partner_id`           | Many2one     | Cliente o proveedor                                      |
| `invoice_date`         | Date         | Fecha de la factura                                      |
| `invoice_date_due`     | Date         | Fecha de vencimiento                                     |
| `journal_id`           | Many2one     | Diario contable                                          |
| `currency_id`          | Many2one     | Moneda del documento                                     |
| `amount_untaxed`       | Monetary     | Subtotal sin impuestos                                   |
| `amount_tax`           | Monetary     | Total de impuestos                                       |
| `amount_total`         | Monetary     | Total con impuestos                                      |
| `amount_residual`      | Monetary     | Saldo pendiente de pago                                  |
| `payment_state`        | Selection    | `not_paid`, `in_payment`, `paid`, `partial`, `reversed` |
| `line_ids`             | One2many     | Líneas del asiento (account.move.line)                   |
| `invoice_line_ids`     | One2many     | Líneas de factura (filtro sobre line_ids)                |

### `account.move.line`
Línea individual de un asiento o factura.

| Campo              | Tipo       | Descripción                              |
|--------------------|------------|------------------------------------------|
| `move_id`          | Many2one   | Asiento padre                            |
| `account_id`       | Many2one   | Cuenta contable                          |
| `name`             | Char       | Descripción de la línea                  |
| `quantity`         | Float      | Cantidad                                 |
| `price_unit`       | Float      | Precio unitario                          |
| `price_subtotal`   | Monetary   | Subtotal                                 |
| `tax_ids`          | Many2many  | Impuestos aplicados                      |
| `debit`            | Monetary   | Debe                                     |
| `credit`           | Monetary   | Haber                                    |
| `balance`          | Monetary   | Balance (debit - credit)                 |
| `partner_id`       | Many2one   | Contacto asociado a la línea             |
| `analytic_distribution` | Json  | Distribución analítica                   |

### `account.account`
Plan de cuentas contable.

| Campo            | Tipo        | Descripción                                  |
|------------------|-------------|----------------------------------------------|
| `code`           | Char        | Código de la cuenta (ej. 101.01)             |
| `name`           | Char        | Nombre descriptivo                           |
| `account_type`   | Selection   | `asset_cash`, `liability_payable`, `income`, `expense`, etc. |
| `currency_id`    | Many2one    | Moneda específica (opcional)                 |
| `reconcile`      | Boolean     | Si permite conciliación                      |
| `company_id`     | Many2one    | Empresa propietaria                          |

### `account.journal`
Diarios contables (ventas, compras, banco, caja, etc.).

| Campo           | Tipo        | Descripción                               |
|-----------------|-------------|-------------------------------------------|
| `name`          | Char        | Nombre del diario                         |
| `type`          | Selection   | `sale`, `purchase`, `cash`, `bank`, `general` |
| `code`          | Char        | Código corto (ej. VEN, BNK)               |
| `currency_id`   | Many2one    | Moneda del diario                         |
| `default_account_id` | Many2one | Cuenta contable por defecto             |

### `account.tax`
Configuración de impuestos.

| Campo           | Tipo        | Descripción                                  |
|-----------------|-------------|----------------------------------------------|
| `name`          | Char        | Nombre (ej. IVA 16%)                         |
| `type_tax_use`  | Selection   | `sale`, `purchase`, `none`                   |
| `amount_type`   | Selection   | `percent`, `fixed`, `division`               |
| `amount`        | Float       | Tasa (ej. 16.0 para 16%)                     |
| `tax_group_id`  | Many2one    | Grupo de impuestos para reportes             |
| `invoice_repartition_line_ids` | One2many | Distribución en facturas         |
| `refund_repartition_line_ids`  | One2many | Distribución en notas de crédito |

### `account.payment`
Pagos (clientes y proveedores).

| Campo             | Tipo       | Descripción                                 |
|-------------------|------------|---------------------------------------------|
| `payment_type`    | Selection  | `inbound`, `outbound`                       |
| `partner_type`    | Selection  | `customer`, `supplier`                      |
| `amount`          | Monetary   | Monto del pago                              |
| `date`            | Date       | Fecha del pago                              |
| `journal_id`      | Many2one   | Diario de pago                              |
| `partner_id`      | Many2one   | Cliente o proveedor                         |
| `move_id`         | Many2one   | Asiento contable generado                   |
| `state`           | Selection  | `draft`, `posted`, `cancel`                 |

## Vistas

- Lista y formulario de facturas de cliente (`out_invoice`)
- Lista y formulario de facturas de proveedor (`in_invoice`)
- Lista y formulario de pagos
- Plan de cuentas
- Diarios contables
- Reportes: Balance, P&L, Mayor, Libro diario

## Seguridad

| Grupo                              | Descripción                          |
|------------------------------------|--------------------------------------|
| `account.group_account_user`       | Contable: acceso básico              |
| `account.group_account_manager`    | Gerente contable: configuración      |
| `account.group_account_readonly`   | Solo lectura contable                |
| `account.group_show_line_subtotals_tax_selection` | Mostrar impuestos en líneas |

## Puntos de extensión

### Agregar campo a la factura

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    pedido_cliente = fields.Char('N° Pedido Cliente', tracking=True)
    aprobado_por = fields.Many2one('res.users', 'Aprobado por')

    def action_post(self):
        # Validación antes de publicar
        for move in self:
            if move.move_type == 'out_invoice' and not move.pedido_cliente:
                raise UserError('Debe ingresar el N° de pedido del cliente')
        return super().action_post()
```

### Override del número de secuencia

```python
def _get_sequence_prefix(self):
    if self.move_type == 'out_invoice':
        return 'FAC'
    return super()._get_sequence_prefix()
```

### Hook post-validación (asiento publicado)

```python
def action_post(self):
    result = super().action_post()
    for move in self:
        if move.move_type in ('out_invoice', 'out_refund'):
            move._enviar_al_sat()  # integración SAT/DTE/DIAN
    return result
```

### Agregar campo a línea de factura

```python
class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    proyecto_id = fields.Many2one('project.project', 'Proyecto')
```

## Dependencias

- `base`
- `mail`
- `analytic`
- `digest`

## Notas v17

- `account.invoice` fue eliminado en v13; en v17 todo es `account.move`
- `analytic_distribution` reemplaza a `account.analytic.line` directo — ahora es JSON
- Nuevo modelo `account.bank.statement.line` para importación bancaria
- Los reportes financieros usan `account.report` (motor nuevo vs. v16)
- `account.move` tiene campo `quick_edit_mode` para edición rápida de facturas
