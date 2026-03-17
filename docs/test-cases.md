# Casos de prueba — Requerimientos cross-módulo

Tres requerimientos de negocio reales para validar que el agente `odoo-requirement-analyst` puede razonar correctamente sobre `sale`, `account` y `stock` juntos.

---

## Caso 1 — Control de crédito en ventas

### Requerimiento funcional

> "Necesitamos bloquear la confirmación de órdenes de venta cuando el cliente tiene facturas de cliente vencidas por más de 30 días. El bloqueo debe mostrar el monto total vencido y permitir que un usuario con el rol 'Gerente de Crédito' haga una excepción dejando una nota justificada."

### Por qué es un buen caso de prueba

- Cruza `sale` (validación en `action_confirm`) y `account` (consulta de facturas vencidas en `account.move`)
- Requiere un nuevo rol/grupo de seguridad
- Tiene un flujo de excepción (el gerente puede aprobar con nota)
- Involucra lógica de dominio sobre fechas (`invoice_date_due < today`)

### Módulos afectados

| Módulo    | Modelo              | Qué cambia                                                 |
|-----------|---------------------|------------------------------------------------------------|
| `sale`    | `sale.order`        | Override de `action_confirm()` + campo `credito_excepcion_id` + campo `nota_excepcion` |
| `sale`    | UI                  | Botón "Aprobar excepción" visible solo para `group_credit_manager` |
| `account` | `account.move`      | Método helper `_get_vencido_amount(partner_id)` — solo lectura |

### Módulo de extensión sugerido

`sale_credit_control`

### Complejidad esperada: **Baja**

- 1 modelo extendido (`sale.order`)
- 2 campos nuevos
- 1 override de `action_confirm()`
- 1 grupo nuevo
- Sin modelo nuevo

### Criterios de aceptación técnica

- [ ] El bloqueo aplica solo en `state = 'draft'` o `'sent'` → `action_confirm()`
- [ ] La consulta de deuda usa `amount_residual > 0` y `invoice_date_due < today`
- [ ] El filtro de `account.move` respeta multi-empresa (`company_id`)
- [ ] La excepción requiere nota no vacía
- [ ] El bloqueo no aplica si `credito_excepcion_id` está seteado por el gerente

---

## Caso 2 — Trazabilidad de lote en factura

### Requerimiento funcional

> "Cuando se genera una factura desde una orden de venta, queremos que cada línea de factura muestre el número de lote o número de serie del producto que fue entregado en el albarán asociado. Si hay múltiples lotes para el mismo producto, mostrarlos todos separados por coma."

### Por qué es un buen caso de prueba

- Cruza los 3 módulos: `sale` (origen), `stock` (donde viven los lotes en `stock.move.line.lot_id`), `account` (destino en `account.move.line`)
- Requiere trazar la cadena: `sale.order.line` → `stock.move.line` → `account.move.line`
- El dato está en `stock` pero debe llegar a `account` sin que `account` dependa de `stock`
- La propagación pasa por el método `_prepare_invoice_line()` de `sale.order.line`

### Cadena de datos

```
stock.move.line
    └── lot_id.name ("LOT001, LOT002")
            ↓
    sale.order.line._prepare_invoice_line()
            ↓ vals['numero_lotes'] = lotes_entregados
    account.move.line
            └── numero_lotes (Char, readonly)
```

### Módulos afectados

| Módulo    | Modelo                | Qué cambia                                                       |
|-----------|-----------------------|------------------------------------------------------------------|
| `sale`    | `sale.order.line`     | Override de `_prepare_invoice_line()` — agrega `numero_lotes`    |
| `account` | `account.move.line`   | Campo nuevo `numero_lotes` (Char, readonly)                      |
| `account` | Vista factura         | Columna `numero_lotes` en líneas (optional="show")               |
| `stock`   | —                     | Solo lectura, no se modifica nada                                |

### Módulo de extensión sugerido

`sale_stock_lot_invoice`

Depende de: `sale`, `stock`, `account`

### Complejidad esperada: **Media**

- 2 modelos extendidos (`sale.order.line`, `account.move.line`)
- 1 campo nuevo en `account.move.line`
- 1 override de `_prepare_invoice_line()` que hace una query a `stock`
- Requiere activar `group_production_lot` para que tenga sentido
- Sin modelo nuevo

### Criterios de aceptación técnica

- [ ] El campo `numero_lotes` en `account.move.line` es `store=False` (siempre viene del origen)
- [ ] Si el producto no tiene lote (`tracking == 'none'`), el campo queda vacío sin error
- [ ] Funciona con facturas parciales (solo los lotes del albarán facturado en esa línea)
- [ ] El módulo se puede instalar sin `stock` instalado (campo queda vacío)
- [ ] La columna en la factura es `optional="show"` para no contaminar el listado por defecto

---

## Caso 3 — Aprobación de descuentos en ventas

### Requerimiento funcional

> "Cualquier orden de venta que tenga líneas con descuento mayor al 20% debe pasar por un flujo de aprobación antes de poderse confirmar. El vendedor puede 'Solicitar aprobación', el gerente de ventas puede 'Aprobar' o 'Rechazar'. Si se rechaza, el vendedor recibe notificación y puede ajustar los descuentos. Solo una vez aprobada puede confirmarse y generar el albarán de entrega y la eventual factura."

### Por qué es un buen caso de prueba

- Es el caso de mayor complejidad: involucra un flujo de estados paralelo al estándar
- Afecta los 3 módulos indirectamente: `sale` (bloquea confirm), `stock` (no hay picking hasta confirmar), `account` (no hay factura hasta confirmar)
- Requiere diseñar un flujo de estados que NO reemplace el `state` estándar de `sale.order`
- Usa el sistema de mensajería (`mail.thread`) para notificaciones al vendedor

### Flujo de estados propuesto

```
[Cotización - draft]
        ↓ (si descuento > 20% en alguna línea)
[Pendiente de aprobación - approval_state='pending']
        ↓ acción del Gerente
   ┌────┴────┐
[Aprobado]  [Rechazado]
   ↓              ↓
action_confirm()  Notificar vendedor
   ↓              → volver a borrador para ajustar
[Orden de venta - state='sale']
   ↓
[stock.picking generado]
   ↓
[account.move generado]
```

**Clave del diseño:** El `state` de `sale.order` **no se modifica**. Se agrega un campo `approval_state` separado. El override de `action_confirm()` valida que `approval_state == 'approved'` cuando hay descuentos altos.

### Módulos afectados

| Módulo    | Modelo            | Qué cambia                                                            |
|-----------|-------------------|-----------------------------------------------------------------------|
| `sale`    | `sale.order`      | Campo `approval_state` + métodos `action_request_approval()`, `action_approve()`, `action_reject()` |
| `sale`    | `sale.order`      | Override de `action_confirm()` — valida `approval_state`             |
| `sale`    | `sale.order`      | `@api.depends` sobre `order_line.discount` → `requires_approval`     |
| `sale`    | Vista formulario  | Botones condicionales + barra de estado secundaria                    |
| `sale`    | Seguridad         | Nuevo grupo `group_discount_approver`                                 |

### Módulo de extensión sugerido

`sale_discount_approval`

Depende de: `sale`

> `stock` y `account` **no se modifican** — el bloqueo opera en `sale.order.action_confirm()` que es el método que dispara la creación del picking y la factura eventual.

### Complejidad esperada: **Media-Alta**

- 1 modelo extendido (`sale.order`)
- 4 campos nuevos (`approval_state`, `requires_approval`, `approval_user_id`, `rejection_reason`)
- 3 métodos nuevos + 1 override
- 1 grupo nuevo
- Lógica de `mail.thread` para notificaciones
- Sin modelo nuevo (aunque podría justificarse un historial de aprobaciones)

### Criterios de aceptación técnica

- [ ] El campo `state` de `sale.order` nunca se modifica directamente
- [ ] `approval_state` es independiente: puede ser `pending` con `state='draft'`
- [ ] El botón "Solicitar aprobación" solo visible si `requires_approval == True` y `state in ('draft', 'sent')`
- [ ] El botón "Aprobar" solo visible para `group_discount_approver`
- [ ] Al rechazar: se registra `rejection_reason` en chatter con mención al vendedor
- [ ] Al aprobar: el vendedor puede ahora llamar `action_confirm()` normalmente
- [ ] Si el vendedor reduce los descuentos al < 20%, `requires_approval` vuelve a `False` y puede confirmar sin aprobación
- [ ] Se probó el flujo: solicitar → rechazar → ajustar descuento → confirmar directo

---

## Resumen comparativo

| Caso                         | Módulos     | Tipo                  | Complejidad | Modelo nuevo |
|------------------------------|-------------|-----------------------|:-----------:|:------------:|
| 1. Control de crédito        | sale+account| Validación de flujo   | Baja        | No           |
| 2. Lote en factura           | sale+stock+account | Propagación de datos | Media | No           |
| 3. Aprobación de descuentos  | sale        | Flujo de aprobación   | Media-Alta  | No*          |

*El caso 3 podría escalar a Alta si se agrega un modelo de historial de aprobaciones.

## Cómo usar estos casos

1. Ejecutar `/odoo-requirement-analyst` con el requerimiento de cada caso
2. Verificar que el `spec.md` generado:
   - Identifica los módulos correctos
   - Propone el tipo de cambio correcto
   - No modifica campos `state` estándar
   - Los overrides llaman `super()`
   - El nombre del módulo sigue la convención
3. Comparar con los "Criterios de aceptación técnica" de cada caso
