# Vistas — `stock` — Odoo 19

## Resumen de vistas principales

| ID XML                                       | Tipo     | Modelo              | Descripción                                   |
|----------------------------------------------|----------|---------------------|-----------------------------------------------|
| `stock.view_picking_form`                    | form     | `stock.picking`     | Formulario completo de transferencia          |
| `stock.vpicktree`                            | list     | `stock.picking`     | Lista de transferencias con multi-edición     |
| `stock.view_picking_internal_search`         | search   | `stock.picking`     | Filtros y agrupaciones                        |
| `stock.stock_picking_type_kanban`            | kanban   | `stock.picking.type`| Dashboard por tipo de operación              |
| `stock.view_warehouse_form`                  | form     | `stock.warehouse`   | Configuración de almacén                      |
| `stock.view_warehouse_tree`                  | list     | `stock.warehouse`   | Lista de almacenes                            |
| `stock.view_location_form`                   | form     | `stock.location`    | Formulario de ubicación                       |
| `stock.view_location_tree2`                  | list     | `stock.location`    | Lista de ubicaciones                          |
| `stock.view_move_form`                       | form     | `stock.move`        | Detalle de movimiento                         |
| `stock.view_move_tree`                       | list     | `stock.move`        | Lista de movimientos                          |
| `stock.quant_search_view`                    | search   | `stock.quant`       | Búsqueda en inventario actual                 |
| `stock.view_stock_quant_tree_editable`       | list     | `stock.quant`       | Inventario editable (conteo físico)           |
| `stock.view_lot_form`                        | form     | `stock.lot`         | Detalle de lote/número de serie               |

---

## Dashboard de operaciones: `stock.stock_picking_type_kanban`

Tarjeta por tipo de operación (Recepciones, Entregas, Transferencias Internas, etc.):

- Nombre del tipo de operación
- Contador de transferencias: Listas / En espera / Tardías
- Colores: verde (listo), naranja (en espera), rojo (tarde)
- Acciones: Nueva transferencia, Ver todo, Configurar

---

## Formulario de transferencia: `stock.view_picking_form`

### Header

**Barra de estado:**
```
[Borrador] → [Listo] → [Hecho]
                        [Cancelado]
```

**Botones de acción:**

| Botón                      | Método                     | Visible cuando                              |
|----------------------------|----------------------------|---------------------------------------------|
| Validar                    | `button_validate()`        | `state == 'assigned'`                       |
| Verificar disponibilidad   | `action_assign()`          | `show_check_availability == True`           |
| Liberar reserva            | `do_unreserve()`           | `state == 'assigned'`                       |
| Retorno                    | wizard de devolución       | `state == 'done'`                           |
| Imprimir                   | `do_print_picking()`       | siempre                                     |
| Cancelar                   | `action_cancel()`          | `state not in ('done', 'cancel')`           |

**Smart buttons (estadísticas):**
- Devoluciones (cantidad)
- Desechos
- Paquetes
- Asignación de demanda
- Trazabilidad

### Campos principales

| Campo               | Editable          | Notas                                           |
|---------------------|-------------------|-------------------------------------------------|
| `partner_id`        | draft / assigned  | Cliente o proveedor                             |
| `origin`            | draft / assigned  | Referencia al documento origen                  |
| `scheduled_date`    | draft / assigned  | Fecha programada                                |
| `date_deadline`     | draft / assigned  | Fecha límite de entrega                         |
| `location_id`       | draft             | Origen (restringido por tipo de operación)      |
| `location_dest_id`  | draft             | Destino                                         |
| `picking_type_id`   | draft             | Tipo de operación                               |

### Pestaña: Operaciones

Lista de `move_line_ids`:

| Columna             | Editable | Notas                                                  |
|---------------------|----------|--------------------------------------------------------|
| `product_id`        | Sí       | Solo editable si no hay reserva activa                 |
| `lot_id`            | Sí       | Grupo `group_production_lot`                           |
| `package_id`        | Sí       | Paquete origen (grupo `group_tracking_lot`)            |
| `result_package_id` | Sí       | Paquete destino                                        |
| `location_id`       | Sí       | Grupo `group_stock_multi_locations`                    |
| `location_dest_id`  | Sí       | Grupo `group_stock_multi_locations`                    |
| `quantity`          | Sí       | Cantidad real procesada                                |
| `picked`            | Sí       | Marcar como recogido                                   |

**Botones en pie:**
- `Empacar` — `action_put_in_pack()`
- `Añadir una línea`

### Pestaña: Información adicional

| Campo             | Descripción                                             |
|-------------------|---------------------------------------------------------|
| `company_id`      | Empresa                                                 |
| `is_locked`       | Bloquear edición de movimientos                         |
| `backorder_id`    | Referencia al picking original (si es backorder)        |
| `move_type`       | Política de envío: `direct` (parcial) o `one`  (todo)   |

---

## Formulario de almacén: `stock.view_warehouse_form`

### Pestaña: Configuración del almacén

| Campo               | Descripción                                            |
|---------------------|--------------------------------------------------------|
| `name`              | Nombre del almacén                                     |
| `short_name`        | Código (máx. 5 chars)                                  |
| `company_id`        | Empresa                                                |
| `partner_id`        | Dirección del almacén                                  |
| `reception_steps`   | Pasos de recepción (1, 2 o 3)                          |
| `delivery_steps`    | Pasos de entrega (1, 2 o 3)                            |
| `resupply_wh_ids`   | Almacenes que reabastecen a este                        |

### Pestaña: Información técnica (solo `group_stock_manager`)

Muestra todas las ubicaciones y tipos de operación configurados:
- `lot_stock_id`, `wh_input_stock_loc_id`, `wh_output_stock_loc_id`
- `in_type_id`, `out_type_id`, `int_type_id`, `pick_type_id`, `pack_type_id`

---

## Vista de inventario actual (Quants)

### `stock.view_stock_quant_tree_editable`

Lista editable para hacer conteos físicos:

| Columna                    | Editable | Descripción                               |
|----------------------------|----------|-------------------------------------------|
| `product_id`               | No       | Producto                                  |
| `location_id`              | No       | Ubicación                                 |
| `lot_id`                   | No       | Lote/serie                                |
| `package_id`               | No       | Paquete                                   |
| `owner_id`                 | No       | Propietario                               |
| `quantity`                 | No       | Cantidad en sistema (readonly)            |
| `inventory_quantity`       | Sí       | Cantidad contada (editable para ajuste)   |
| `inventory_diff_quantity`  | No       | Diferencia (computado)                    |
| `user_id`                  | Sí       | Usuario asignado para el conteo           |
| `inventory_date`           | Sí       | Fecha del próximo conteo                  |

---

## Vista de búsqueda de transferencias

### Filtros predefinidos

| Filtro                  | Dominio                                                      |
|-------------------------|--------------------------------------------------------------|
| Mis transferencias      | `[('user_id', '=', uid)]`                                    |
| Listas                  | `[('state', '=', 'assigned')]`                               |
| En espera               | `[('state', 'in', ('draft', 'confirmed', 'waiting'))]`       |
| Tardías                 | `[('date_deadline', '<', now), ('state', '!=', 'done')]`     |
| Hoy                     | `[('scheduled_date', '<=', end_of_today)]`                   |
| Backorders              | `[('backorder_id', '!=', False)]`                            |

### Agrupaciones predefinidas

| Agrupar por         | Campo               |
|---------------------|---------------------|
| Tipo de operación   | `picking_type_id`   |
| Origen              | `origin`            |
| Cliente/Proveedor   | `partner_id`        |
| Empresa             | `company_id`        |
| Fecha programada    | `scheduled_date`    |
| Estado              | `state`             |

---

## Menú principal

```
Inventario (raíz)
├── Operaciones
│   ├── Transferencias       → todas las pickings
│   ├── Recepciones          → picking_type_code = incoming
│   ├── Entregas             → picking_type_code = outgoing
│   ├── Transferencias Int.  → picking_type_code = internal
│   └── Desechos             → stock.scrap
├── Productos
│   ├── Productos            → product.template (con stock)
│   ├── Lotes/Números Serie  → stock.lot [grupo_production_lot]
│   └── Paquetes             → stock.package [grupo_tracking_lot]
├── Reabastecimiento         [grupo_adv_location]
│   ├── Reglas de reorden    → stock.warehouse.orderpoint
│   └── Reglas de rutas      → stock.rule
├── Reportes
│   ├── Inventario actual    → stock.quant
│   ├── Historial de movimientos → stock.move
│   ├── Trazabilidad
│   └── Valoración           [con account instalado]
└── Configuración            [grupo_stock_manager]
    ├── Almacenes
    ├── Ubicaciones           [grupo_stock_multi_locations]
    ├── Tipos de operaciones
    ├── Rutas                 [grupo_adv_location]
    ├── Reglas de almacenamiento (Putaway)
    └── Ajustes
```
