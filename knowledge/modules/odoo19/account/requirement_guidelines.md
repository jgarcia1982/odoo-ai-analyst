# Guía para desarrolladores — `account` — Odoo 19

Lee esto **antes** de escribir cualquier código que toque facturas, pagos o asientos.

---

## Lo que NUNCA debes hacer

### No insertes ni modifiques `account.move.line` directamente en facturas publicadas

```python
# MAL — rompe la integridad contable
move.line_ids.write({'debit': 500})

# MAL — no se puede crear líneas en un asiento publicado
self.env['account.move.line'].create({'move_id': move.id, ...})
```

Un asiento en `state = 'posted'` es **inmutable** desde el punto de vista contable. Si tiene hash activado, cualquier cambio directo lo invalida. Para modificar: regresa a borrador (`button_draft()`), edita, vuelve a publicar.

### No cambies `state` directamente con `write()`

```python
# MAL
move.write({'state': 'posted'})

# BIEN
move.action_post()
```

`action_post()` hace mucho más que cambiar el estado: asigna la secuencia, genera el hash, registra el audit trail y dispara automatizaciones.

### No crees líneas de asiento manualmente cuando puedas usar el ORM de facturas

```python
# MAL — frágil, omite lógica de impuestos y conciliación
self.env['account.move.line'].create({
    'move_id': move.id,
    'account_id': account.id,
    'debit': 100,
})

# BIEN — usa invoice_line_ids con Command
move.write({
    'invoice_line_ids': [Command.create({
        'product_id': product.id,
        'quantity': 1,
        'price_unit': 100,
    })]
})
```

### No modifiques los tipos de `account_type`

Los 19 tipos de cuenta son referencias fijas del sistema. Módulos como `sale`, `stock`, `hr_payroll` buscan cuentas por `account_type`. Si cambias el tipo de una cuenta, romperás la contabilización automática.

### No borres `account.move.line` de impuestos directamente

Las líneas con `tax_line_id` son generadas por el ORM de impuestos. Si las eliminas manualmente, la contabilidad queda descuadrada. Para recalcular impuestos: usa `move._compute_tax_line_ids()` o trabaja sobre las líneas de producto.

---

## Campos críticos — extrema precaución

| Campo               | Modelo              | Por qué es crítico                                                    |
|---------------------|---------------------|-----------------------------------------------------------------------|
| `state`             | `account.move`      | Controla inalterabilidad, secuencia, hash                             |
| `name`              | `account.move`      | Secuencia legal; UNIQUE en publicadas por diario                      |
| `inalterable_hash`  | `account.move`      | Cadena criptográfica; romperla invalida toda la auditoría             |
| `account_type`      | `account.account`   | Referenciado por docenas de módulos para encontrar cuentas por tipo   |
| `reconcile`         | `account.account`   | Obligatorio True en `asset_receivable` y `liability_payable`          |
| `debit` / `credit`  | `account.move.line` | La suma de todas las líneas debe ser 0 (principio de doble partida)   |
| `tax_repartition_line_id` | `account.move.line` | Define cómo se distribuye el impuesto; no modificar en posted |
| `full_reconcile_id` | `account.move.line` | Resultado de la conciliación; modificar puede dejar saldos incorrectos |

---

## Reglas contables que el sistema impone

### Principio de doble partida

Todo `account.move` en `posted` debe tener la suma de `debit` = suma de `credit` en todas sus líneas. El ORM lo valida antes de publicar. Si tu código agrega líneas, asegúrate de que el asiento cuadre.

### Secuencia inmutable

Una vez publicado, `name` no puede cambiar. La secuencia es generada en `action_post()` basada en el diario y el año fiscal. No intentes asignar `name` manualmente antes de publicar.

### Conciliación y `amount_residual`

`amount_residual` es computado desde `matched_debit_ids` y `matched_credit_ids`. Nunca escribas en este campo directamente. Para conciliar: usa `account.partial.reconcile` o los métodos `reconcile()`.

---

## Flujos que requieren atención especial

### Factura → Pago → Conciliación

```
account.move (out_invoice, posted)
    ↓ action_register_payment() — wizard
account.payment (in_process)
    ↓ action_post()
account.move (entrada en diario banco)
    ↓ _reconcile_payment_lines()
account.partial.reconcile
    ↓ (si amount_residual = 0)
account.full.reconcile
    ↓ move.payment_state = 'paid'
```

Si extiendes el pago, hazlo **antes** de que se cree la conciliación. Una vez creado `account.full.reconcile`, deshacer requiere borrar la conciliación completa.

### Notas de crédito y reversiones

```python
# La forma correcta de crear una nota de crédito desde código
move._reverse_moves(
    default_values_list=[{
        'invoice_date': fields.Date.today(),
        'ref': f'Reversión de {move.name}',
    }],
    cancel=True,  # True = cancela y concilia automáticamente
)
```

Con `cancel=True`, la nota de crédito se reconcilia automáticamente con la factura original y ambas quedan en `payment_state = 'reversed'`.

### Multi-empresa: usar `company_ids` vs `company_id`

- `account.account` usa `company_ids` (Many2many) → una cuenta puede ser compartida entre empresas
- `account.move` usa `company_id` (Many2one) → un asiento pertenece a una sola empresa
- `account.journal` usa `company_id` con regla `parent_of` → los hijos heredan diarios del padre

Cuando crees cuentas en un módulo que debe funcionar en multi-empresa, usa `company_ids` correctamente.

---

## Configuraciones que afectan el comportamiento

| Parámetro / Grupo                              | Efecto                                                     |
|------------------------------------------------|------------------------------------------------------------|
| `group_account_secured`                        | Activa hash de inalterabilidad por diario                  |
| `group_cash_rounding`                          | Campo de redondeo en facturas                              |
| `group_partial_purchase_deductibility`         | Deducibilidad parcial de impuestos de compra               |
| `journal.restrict_mode_hash_table`             | Habilita hash en ese diario específico                     |
| `account.use_anglo_saxon`                      | Activa contabilidad anglosajona (COGS en entrega, no PO)   |
| `account.lock_date`                            | Fecha de bloqueo: no se pueden crear asientos antes de ella |
| `account.lock_date_po`                         | Fecha de bloqueo para compras                              |

---

## Patrones de implementación recomendados

### Flujo de aprobación antes de publicar

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    estado_aprobacion = fields.Selection([
        ('pendiente', 'Pendiente'),
        ('aprobado', 'Aprobado'),
    ], default='pendiente', tracking=True)

    def action_post(self):
        for move in self:
            if (move.is_invoice()
                    and move.amount_total > 50000
                    and move.estado_aprobacion != 'aprobado'):
                raise UserError('Facturas > $50,000 requieren aprobación')
        return super().action_post()
```

### Agregar campo a la línea de factura sin afectar el asiento contable

```python
class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    numero_serie = fields.Char('N° de Serie')
    # No uses store=True para datos solo informativos — ahorra espacio y evita recomputación
```

### Enviar datos a sistema externo después de publicar

```python
class AccountMove(models.Model):
    _inherit = 'account.move'

    def action_post(self):
        result = super().action_post()
        # Después del super(), el asiento ya tiene nombre y hash
        for move in self.filtered(lambda m: m.is_invoice()):
            move._sincronizar_con_sistema_externo()
        return result

    def _sincronizar_con_sistema_externo(self):
        # Usar try/except para no bloquear la publicación si el sistema externo falla
        try:
            api_client.post('/facturas', self._prepare_payload())
        except Exception as e:
            _logger.warning('Error sincronizando factura %s: %s', self.name, e)
            # No relanzar: la factura ya está publicada en Odoo
```

---

## Checklist antes de entregar un módulo que toca `account`

- [ ] Los campos nuevos en `account.move` tienen `tracking=True` si son auditables
- [ ] Los overrides de `action_post()` llaman `super()` y su lógica extra va **después**
- [ ] No se usa `write({'state': ...})` directamente
- [ ] Los asientos creados desde código cuadran (suma debit = suma credit)
- [ ] Se probó el flujo: crear borrador → publicar → registrar pago → conciliar
- [ ] Se probó con facturas en moneda extranjera si el módulo maneja montos
- [ ] Se probó con hash activado en el diario (si el cliente usa inalterabilidad)
- [ ] Se probó el flujo de nota de crédito y reversión
- [ ] Los permisos permiten que `group_account_invoice` opere sin necesitar `group_account_manager`
- [ ] No se crearon xpaths con `position="replace"` en vistas del módulo
