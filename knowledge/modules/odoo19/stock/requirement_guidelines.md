# Guía para desarrolladores — `stock` — Odoo 19

Lee esto **antes** de escribir cualquier código que toque movimientos, transferencias o inventario.

---

## Lo que NUNCA debes hacer

### No modifiques `stock.quant` directamente sin `inventory_mode`

```python
# MAL — rompe la integridad del inventario
quant.write({'quantity': 50})

# BIEN — ajuste controlado via modo inventario
quant_with_ctx = quant.with_context(inventory_mode=True)
quant_with_ctx.write({'inventory_quantity': 50})
quant_with_ctx.action_apply_inventory()
```

Los `stock.quant` son el libro mayor del inventario. Modificarlos directamente omite la creación del `stock.move` de ajuste, lo que deja el historial inconsistente.

### No elimines `stock.move` en estado `done`

```python
# MAL
done_move.unlink()
```

Un movimiento `done` ya actualizó quants, puede estar vinculado a una factura de valoración de inventario y es parte del historial de trazabilidad. El sistema no lo permite por diseño.

### No valides transferencias con `write({'state': 'done'})`

```python
# MAL
picking.write({'state': 'done'})

# BIEN
picking.button_validate()
```

`button_validate()` actualiza quants, genera backorders, crea movimientos de valoración contable, dispara reglas push y envía notificaciones.

### No crees `stock.move.line` sin pasar por `_action_assign()`

Las líneas de detalle (con lotes, ubicaciones específicas) deben ser generadas por la reserva de stock:

```python
# BIEN — reservar genera las move_lines con stock disponible
picking.action_assign()

# Si necesitas forzar sin reserva:
move._set_quantity_done(qty)  # Actualiza/crea líneas para la validación
```

### No rompas la cadena de movimientos `move_orig_ids` / `move_dest_ids`

Esta cadena conecta: PO → Recepción → Transferencia interna → Entrega. Si la rompes, los movimientos encadenados ya no se cancelarán/confirmarán en cascada.

---

## Campos críticos — no cambiar su lógica

| Campo                  | Modelo           | Por qué es crítico                                                    |
|------------------------|------------------|-----------------------------------------------------------------------|
| `state`                | `stock.picking`  | Controla qué acciones están disponibles y la visibilidad en UI       |
| `state`                | `stock.move`     | Determina si el stock está reservado o consumido                     |
| `quantity`             | `stock.quant`    | El inventario real; solo debe cambiar vía movimientos validados       |
| `reserved_quantity`    | `stock.quant`    | Reservas activas; modificar directamente deja movimientos sin stock   |
| `in_date`              | `stock.quant`    | Base para FIFO/FEFO; cambiarlo altera el orden de consumo            |
| `move_orig_ids`        | `stock.move`     | Cadena de trazabilidad hacia atrás                                   |
| `move_dest_ids`        | `stock.move`     | Cadena de trazabilidad hacia adelante                                |
| `lot_id`               | `stock.move.line`| Trazabilidad del número de serie; asociado a garantías y recalls     |
| `procurement_group_id` | `stock.picking`  | Vincula la transferencia al documento origen (SO, PO, etc.)          |

---

## Conceptos clave para entender `stock`

### Quant = unidad mínima de inventario

Un `stock.quant` es único por la combinación:
```
(product_id, location_id, lot_id, package_id, owner_id)
```

Dos unidades del mismo producto en la misma ubicación pero con lotes distintos → dos quants separados.

### Move → Move.line = demanda → detalle de ejecución

```
stock.move (demanda: 10 unidades del producto X)
    ├── move.line (5 unidades del lote L001 desde ubicación A-01-01)
    └── move.line (5 unidades del lote L002 desde ubicación A-01-02)
```

Al confirmar (`action_confirm`), el move existe pero sin lines.
Al reservar (`action_assign`), se crean las lines con los quants específicos.
Al validar (`button_validate`), las lines definen exactamente qué se movió.

### Estado `waiting` en `stock.move`

Un move en `waiting` significa que depende de otro movimiento previo que aún no está `done`. Esto ocurre en flujos de múltiples pasos:

```
Recepción (done)
    ↓
Transferencia a QC (waiting → assigned cuando recepción done)
    ↓
Transferencia a Stock (waiting → assigned cuando QC done)
```

No confundas `waiting` con un error — es el comportamiento esperado en flujos de 2-3 pasos.

---

## Flujos que requieren atención especial

### Flujo Sale → Stock (cómo se conectan)

```
sale.order (confirmed)
    ↓ _action_launch_stock_rule()
procurement.group
    ↓ stock.rule (pull, make_to_stock)
stock.picking (out_type)
    └── stock.move (product_id, qty, location_dest=customer)
```

Para rastrear la venta desde el picking: `picking.origin` contiene el número de la orden de venta. La relación inversa: `sale.order.picking_ids`.

### Flujo de devolución

```
picking_original (done)
    ↓ Wizard de devolución
picking_return (incoming desde cliente)
    └── move.origin_returned_move_id = move_original
```

Al validar la devolución, los quants se restauran en el almacén. No crea automáticamente una nota de crédito — eso lo hace el flujo de `sale` o el usuario manualmente.

### Backorder

```
picking (10 unidades pedidas, 7 disponibles)
    ↓ button_validate() con 7 done
picking_done (7 done)
picking_backorder (3 unidades pendientes, nuevo picking creado)
```

El backorder hereda el `procurement_group_id` original, manteniendo la vinculación con la orden de venta o compra.

---

## Configuraciones que afectan el comportamiento

| Configuración / Grupo                        | Efecto                                                          |
|----------------------------------------------|-----------------------------------------------------------------|
| `reception_steps` del almacén                | Cuántas transferencias se crean al recibir (1, 2 o 3)          |
| `delivery_steps` del almacén                 | Cuántas transferencias se crean al enviar (1, 2 o 3)           |
| `group_production_lot`                       | Habilita campos de lote/serie en todo el módulo                |
| `group_tracking_lot`                         | Habilita gestión de paquetes                                    |
| `group_adv_location`                         | Habilita rutas y reglas pull/push                              |
| Método de coste del producto                 | `standard`, `average`, `fifo` → determina qué quant se consume |
| `removal_strategy_id` de la ubicación        | FIFO/FEFO/LIFO/más cercano → orden de consumo de quants        |

---

## Patrones de implementación recomendados

### Agregar campo propagado desde venta hasta el albarán

```python
# 1. Campo en la orden de venta
class SaleOrder(models.Model):
    _inherit = 'sale.order'
    numero_proyecto = fields.Char('N° Proyecto')

# 2. Propagar al picking via procurement values
class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_procurement_values(self, group_id=False):
        vals = super()._prepare_procurement_values(group_id=group_id)
        vals['numero_proyecto'] = self.order_id.numero_proyecto
        return vals

# 3. Agregar campo al move y picking
class StockMove(models.Model):
    _inherit = 'stock.move'
    numero_proyecto = fields.Char('N° Proyecto')

class StockPicking(models.Model):
    _inherit = 'stock.picking'
    numero_proyecto = fields.Char(
        'N° Proyecto',
        compute='_compute_numero_proyecto',
        store=True,
    )

    @api.depends('move_ids.numero_proyecto')
    def _compute_numero_proyecto(self):
        for picking in self:
            proyectos = picking.move_ids.mapped('numero_proyecto')
            picking.numero_proyecto = proyectos[0] if proyectos else ''
```

### Bloquear validación según condición del negocio

```python
class StockPicking(models.Model):
    _inherit = 'stock.picking'

    def button_validate(self):
        for picking in self:
            if (picking.picking_type_code == 'outgoing'
                    and picking.partner_id.credito_bloqueado):
                raise UserError(
                    f'El cliente {picking.partner_id.name} tiene crédito bloqueado. '
                    'Contacte a cobranza.'
                )
        return super().button_validate()
```

### Crear regla de ruta personalizada en el warehouse

```python
class StockWarehouse(models.Model):
    _inherit = 'stock.warehouse'

    inspeccion_type_id = fields.Many2one('stock.picking.type', 'Tipo: Inspección')

    def _get_routes_values(self):
        routes = super()._get_routes_values()
        routes['inspeccion_route'] = {
            'routing_key': 'inspeccion',
            'depends': ['reception_steps'],
            'route_update_values': {
                'name': self._format_routename(name='Inspección'),
                'active': self.reception_steps == 'three_steps',
            },
            'route_create_values': {
                'product_selectable': False,
                'warehouse_selectable': True,
            },
            'rules_values': [...],
        }
        return routes
```

---

## Checklist antes de entregar un módulo que toca `stock`

- [ ] No se modifican `stock.quant` directamente (solo via `inventory_mode`)
- [ ] No se borran `stock.move` en estado `done`
- [ ] `button_validate()` llama `super()` antes de lógica adicional (post-validación)
- [ ] Los nuevos campos en `stock.move` se propagan correctamente desde `sale.order.line._prepare_procurement_values()`
- [ ] Se probó el flujo completo: SO confirmar → picking → validar → factura
- [ ] Se probó con backorder (validar menos de lo pedido)
- [ ] Se probó con devoluciones
- [ ] Se probó con `group_production_lot` activado (si el módulo toca lotes)
- [ ] Se probó con multi-almacén si el módulo agrega lógica de routing
- [ ] No se rompió la cadena `move_orig_ids` / `move_dest_ids`
