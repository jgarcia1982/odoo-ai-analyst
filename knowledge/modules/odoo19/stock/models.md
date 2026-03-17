# Modelos — `stock` — Odoo 19

## Diagrama de relaciones

```
stock.warehouse
    ├──→ stock.location (lot_stock_id, wh_input_stock_loc_id, ...)
    └──→ stock.picking.type (in_type_id, out_type_id, pick_type_id, ...)

stock.picking ──────────────────────────────────────────────────┐
    ├── picking_type_id → stock.picking.type                    │
    ├── location_id / location_dest_id → stock.location         │
    ├── partner_id → res.partner                                │
    ├── move_ids ──────────────────────────→ stock.move         │
    │                                           │               │
    │                                           ├── product_id → product.product
    │                                           ├── location_id / location_dest_id
    │                                           └── move_line_ids → stock.move.line
    │                                                   ├── lot_id → stock.lot
    │                                                   ├── package_id → stock.package
    │                                                   └── owner_id → res.partner
    │
    └── backorder_id → stock.picking (self-reference)

stock.quant
    ├── product_id → product.product
    ├── location_id → stock.location
    ├── lot_id → stock.lot
    └── package_id → stock.package
```

---

## `stock.warehouse`

```
Tabla BD: stock_warehouse
```

### Campos de identidad

| Campo        | Tipo     | Req. | Descripción                                |
|--------------|----------|:----:|--------------------------------------------|
| `name`       | Char     | Sí   | Nombre del almacén (único por empresa)     |
| `code`       | Char     | Sí   | Código corto (máx. 5 chars, único por empresa) |
| `active`     | Boolean  | —    | Activo/inactivo                            |
| `company_id` | Many2one | Sí   | Empresa propietaria (readonly)             |
| `sequence`   | Integer  | —    | Orden de visualización                     |
| `partner_id` | Many2one | —    | Dirección asociada al almacén              |

### Campos de configuración de pasos

| Campo               | Tipo      | Valores                                      |
|---------------------|-----------|----------------------------------------------|
| `reception_steps`   | Selection | `one_step` · `two_steps` · `three_steps`     |
| `delivery_steps`    | Selection | `ship_only` · `pick_ship` · `pick_pack_ship` |

### Ubicaciones del almacén

| Campo                    | Tipo     | Descripción                              |
|--------------------------|----------|------------------------------------------|
| `view_location_id`       | Many2one | Ubicación raíz virtual del almacén       |
| `lot_stock_id`           | Many2one | Ubicación principal de stock             |
| `wh_input_stock_loc_id`  | Many2one | Entrada/recepción (paso 2 y 3)           |
| `wh_qc_stock_loc_id`     | Many2one | Control de calidad (paso 3)              |
| `wh_output_stock_loc_id` | Many2one | Salida/envío (pick_ship / pick_pack_ship)|
| `wh_pack_stock_loc_id`   | Many2one | Empaque (pick_pack_ship)                 |

### Tipos de operación

| Campo            | Tipo     | Descripción                          |
|------------------|----------|--------------------------------------|
| `in_type_id`     | Many2one | Recepciones                          |
| `out_type_id`    | Many2one | Entregas                             |
| `int_type_id`    | Many2one | Transferencias internas              |
| `pick_type_id`   | Many2one | Picking (recolección)                |
| `pack_type_id`   | Many2one | Empaque                              |
| `store_type_id`  | Many2one | Almacenamiento                       |
| `xdock_type_id`  | Many2one | Cross-docking                        |

### Campos de rutas y reabastecimiento

| Campo                | Tipo      | Descripción                                    |
|----------------------|-----------|------------------------------------------------|
| `route_ids`          | Many2many | Rutas activas del almacén                      |
| `reception_route_id` | Many2one  | Ruta de recepción                              |
| `delivery_route_id`  | Many2one  | Ruta de entrega                                |
| `mto_pull_id`        | Many2one  | Regla Make-to-Order del almacén                |
| `resupply_wh_ids`    | Many2many | Almacenes que reabastecen a este               |
| `resupply_route_ids` | One2many  | Rutas de reabastecimiento entre almacenes      |

### Métodos clave

| Método                                          | Descripción                                                  |
|-------------------------------------------------|--------------------------------------------------------------|
| `create(vals_list)`                             | Crea almacén con todas sus ubicaciones, rutas y tipos        |
| `write(vals)`                                   | Actualiza almacén y propaga cambios en cascada               |
| `_get_locations_values(vals, code)`             | Genera configuración de ubicaciones                          |
| `_update_location_reception(new_step)`          | Activa/desactiva ubicaciones según pasos de recepción        |
| `_update_location_delivery(new_step)`           | Activa/desactiva ubicaciones según pasos de entrega          |
| `_create_or_update_route()`                     | Crea o actualiza rutas del almacén                           |
| `get_rules_dict()`                              | Devuelve definición de reglas para cada combinación de pasos |
| `create_resupply_routes(supplier_warehouses)`   | Crea rutas de reabastecimiento entre almacenes               |

---

## `stock.location`

```
Tabla BD: stock_location
Jerarquía: campo location_id (padre), child_ids (hijos)
```

| Campo                        | Tipo      | Req. | Descripción                                       |
|------------------------------|-----------|:----:|---------------------------------------------------|
| `name`                       | Char      | Sí   | Nombre de la ubicación                            |
| `complete_name`              | Char      | —    | Nombre jerárquico completo (computado, stored)    |
| `location_id`                | Many2one  | —    | Ubicación padre                                   |
| `child_ids`                  | One2many  | —    | Ubicaciones hijas                                 |
| `usage`                      | Selection | Sí   | Tipo: `internal` · `supplier` · `customer` · `transit` · `inventory` · `production` · `view` |
| `active`                     | Boolean   | —    | Activo/inactivo                                   |
| `company_id`                 | Many2one  | —    | Empresa                                           |
| `barcode`                    | Char      | —    | Código de barras (único por empresa)              |
| `removal_strategy_id`        | Many2one  | —    | Estrategia de salida (FIFO/FEFO/LIFO/más cercano) |
| `putaway_rule_ids`           | One2many  | —    | Reglas de guardado automático (putaway)           |
| `storage_category_id`        | Many2one  | —    | Categoría de almacenamiento                       |
| `warehouse_id`               | Many2one  | —    | Almacén propietario (computado, stored)           |
| `quant_ids`                  | One2many  | —    | Quantas en esta ubicación                         |
| `cyclic_inventory_frequency` | Integer   | —    | Días entre conteos cíclicos                       |
| `last_inventory_date`        | Date      | —    | Última fecha de inventario físico                 |
| `next_inventory_date`        | Date      | —    | Próxima fecha de conteo (computado)               |
| `replenish_location`         | Boolean   | —    | Es punto de reabastecimiento (computado)          |
| `is_empty`                   | Boolean   | —    | Sin stock en este momento (computado)             |
| `net_weight`                 | Float     | —    | Peso neto actual (computado)                      |

### Método de putaway

```python
location._get_putaway_strategy(
    product,        # producto a guardar
    quantity,       # cantidad
    package,        # paquete (opcional)
    packaging,      # embalaje (opcional)
    additional_qty, # cantidad adicional en tránsito
) → stock.location  # ubicación óptima calculada
```

---

## `stock.picking`

```
Tabla BD: stock_picking
Mixins  : mail.thread, mail.activity.mixin
```

### Campos de identidad y estado

| Campo             | Tipo      | Req. | Descripción                                           |
|-------------------|-----------|:----:|-------------------------------------------------------|
| `name`            | Char      | —    | Referencia del documento (ej. WH/OUT/00001)           |
| `state`           | Selection | —    | `draft` · `assigned` · `done` · `cancel` (computado) |
| `priority`        | Selection | —    | `0` Normal · `1` Urgente                             |
| `picking_type_id` | Many2one  | Sí   | Tipo de operación (recepción, entrega, etc.)          |
| `picking_code`    | Selection | —    | `incoming` · `outgoing` · `internal` (relacionado)   |

### Campos de ubicación y fechas

| Campo               | Tipo      | Req. | Descripción                                         |
|---------------------|-----------|:----:|-----------------------------------------------------|
| `location_id`       | Many2one  | Sí   | Ubicación de origen                                 |
| `location_dest_id`  | Many2one  | Sí   | Ubicación de destino                                |
| `partner_id`        | Many2one  | —    | Cliente o proveedor                                 |
| `origin`            | Char      | —    | Documento origen (ej. S00023, PO/00012)             |
| `scheduled_date`    | Datetime  | —    | Fecha programada de la operación                    |
| `date_deadline`     | Datetime  | —    | Fecha límite de entrega                             |
| `date_done`         | Date      | —    | Fecha real de validación                            |

### Campos de movimientos

| Campo             | Tipo     | Descripción                                          |
|-------------------|----------|------------------------------------------------------|
| `move_ids`        | One2many | Movimientos de stock (stock.move)                    |
| `move_line_ids`   | One2many | Líneas de detalle (stock.move.line)                  |
| `backorder_id`    | Many2one | Picking original (si este es un backorder)           |

### Campos de disponibilidad (computados)

| Campo                       | Tipo    | Descripción                                      |
|-----------------------------|---------|--------------------------------------------------|
| `products_availability`     | Html    | Estado visual de disponibilidad de stock         |
| `products_availability_state`| Selection | `available` · `expected` · `late`             |
| `is_locked`                 | Boolean | No se pueden editar movimientos                  |
| `show_check_availability`   | Boolean | Mostrar botón "Verificar disponibilidad"         |
| `shipping_weight`           | Float   | Peso total del envío                             |
| `shipping_volume`           | Float   | Volumen total del envío                          |

### Métodos clave

| Método                      | Descripción                                              |
|-----------------------------|----------------------------------------------------------|
| `action_confirm()`          | Confirma la transferencia (→ `assigned` o `waiting`)     |
| `action_assign()`           | Verifica disponibilidad y reserva stock                  |
| `button_validate()`         | Valida la transferencia (→ `done`)                       |
| `action_cancel()`           | Cancela la transferencia                                 |
| `do_unreserve()`            | Libera las reservas de stock                             |
| `action_put_in_pack()`      | Empaca los productos en un paquete                       |
| `_check_backorder()`        | Verifica si quedan cantidades pendientes (backorder)     |
| `_create_backorder()`       | Crea transferencia de backorder con movimientos restantes|
| `_sanity_check()`           | Valida consistencia antes de validar                     |
| `_action_done()`            | Proceso interno de completado                            |

---

## `stock.move`

```
Tabla BD: stock_move
```

### Campos de identidad y estado

| Campo             | Tipo      | Req. | Descripción                                              |
|-------------------|-----------|:----:|----------------------------------------------------------|
| `reference`       | Char      | —    | Referencia del movimiento (computado)                    |
| `state`           | Selection | —    | `draft` · `confirmed` · `waiting` · `assigned` · `done` · `cancel` |
| `priority`        | Selection | —    | Urgencia (computado desde picking)                       |
| `date`            | Datetime  | Sí   | Fecha programada del movimiento                          |
| `date_deadline`   | Datetime  | —    | Fecha límite (readonly)                                  |

### Campos de producto y cantidad

| Campo              | Tipo     | Req. | Descripción                                           |
|--------------------|----------|:----:|-------------------------------------------------------|
| `product_id`       | Many2one | Sí   | Producto                                              |
| `product_uom_qty`  | Float    | Sí   | Cantidad demandada (en la UdM del movimiento)         |
| `product_uom`      | Many2one | Sí   | Unidad de medida del movimiento                       |
| `product_qty`      | Float    | —    | Cantidad en la UdM por defecto del producto (computado)|
| `quantity`         | Float    | —    | Cantidad real procesada (computado/editable)           |

### Campos de ubicación y picking

| Campo              | Tipo     | Req. | Descripción                                           |
|--------------------|----------|:----:|-------------------------------------------------------|
| `location_id`      | Many2one | Sí   | Ubicación origen                                      |
| `location_dest_id` | Many2one | Sí   | Ubicación destino intermedia                          |
| `location_final_id`| Many2one | —    | Destino final (si hay pasos encadenados)              |
| `picking_id`       | Many2one | —    | Transferencia padre                                   |
| `picking_type_id`  | Many2one | —    | Tipo de operación (computado desde picking)           |

### Campos de procurement y encadenamiento

| Campo               | Tipo      | Descripción                                            |
|---------------------|-----------|--------------------------------------------------------|
| `procure_method`    | Selection | `make_to_stock` · `make_to_order` · `mts_else_mto`    |
| `rule_id`           | Many2one  | Regla de stock que creó este movimiento                |
| `route_ids`         | Many2many | Rutas preferidas para este movimiento                  |
| `move_dest_ids`     | Many2many | Movimientos destino (cadena forward)                   |
| `move_orig_ids`     | Many2many | Movimientos origen (cadena backward)                   |
| `propagate_cancel`  | Boolean   | Cancelar el movimiento destino al cancelar este        |
| `orderpoint_id`     | Many2one  | Punto de reorden que generó este movimiento            |

### Campos de disponibilidad

| Campo                  | Tipo     | Descripción                                          |
|------------------------|----------|------------------------------------------------------|
| `availability`         | Float    | Cantidad disponible/reservable (computado)           |
| `forecast_availability`| Float    | Disponibilidad en fecha programada (computado)       |
| `forecast_expected_date`| Datetime| Fecha esperada según forecast (computado)            |
| `picked`               | Boolean  | Si ya fue recogido del almacén (computado)           |

### Campos de líneas de detalle

| Campo          | Tipo     | Descripción                                               |
|----------------|----------|-----------------------------------------------------------|
| `move_line_ids`| One2many | Líneas con lotes, paquetes y cantidades reales             |
| `next_serial`  | Char     | Primer número de serie a generar                          |
| `next_serial_count` | Integer | Cantidad de números de serie a generar                |

### Métodos clave

| Método                          | Descripción                                             |
|---------------------------------|---------------------------------------------------------|
| `_action_assign(force_qty)`     | Reserva stock (genera `move_line_ids`)                  |
| `_action_confirm()`             | Confirma el movimiento                                  |
| `_action_done(cancel_backorder)`| Marca como hecho, actualiza quants                      |
| `_action_cancel()`              | Cancela el movimiento                                   |
| `_split(qty)`                   | Divide el movimiento en dos                             |
| `_merge_moves(merge_into)`      | Fusiona movimientos equivalentes                        |
| `_get_available_quantity()`     | Consulta disponibilidad en ubicación                    |
| `_generate_serial_numbers()`    | Crea números de serie en lote                           |
| `_push_apply()`                 | Aplica reglas push automáticas post-validación          |

---

## `stock.move.line`

```
Tabla BD: stock_move_line
```

| Campo               | Tipo     | Req. | Descripción                                        |
|---------------------|----------|:----:|----------------------------------------------------|
| `picking_id`        | Many2one | —    | Transferencia padre                                |
| `move_id`           | Many2one | —    | Movimiento padre                                   |
| `product_id`        | Many2one | —    | Producto                                           |
| `product_uom_id`    | Many2one | Sí   | Unidad de medida                                   |
| `quantity`          | Float    | —    | Cantidad real procesada en esta línea              |
| `quantity_product_uom` | Float | —    | Cantidad en la UdM del producto (computado)        |
| `location_id`       | Many2one | —    | Ubicación origen de esta línea                     |
| `location_dest_id`  | Many2one | —    | Ubicación destino de esta línea                    |
| `lot_id`            | Many2one | —    | Lote o número de serie                             |
| `lot_name`          | Char     | —    | Nombre del lote (para crear lote en el momento)    |
| `package_id`        | Many2one | —    | Paquete origen                                     |
| `result_package_id` | Many2one | —    | Paquete destino (al empacar)                       |
| `owner_id`          | Many2one | —    | Propietario del producto                           |
| `picked`            | Boolean  | —    | Marcado como recogido manualmente                  |
| `is_entire_pack`    | Boolean  | —    | Representa un paquete completo                     |
| `date`              | Datetime | —    | Fecha de la línea                                  |
| `state`             | Selection| —    | Estado (relacionado desde move_id)                 |

---

## `stock.quant`

```
Tabla BD: stock_quant
Clave de unicidad: (product_id, location_id, lot_id, package_id, owner_id)
```

| Campo                          | Tipo     | Req. | Descripción                                     |
|--------------------------------|----------|:----:|-------------------------------------------------|
| `product_id`                   | Many2one | Sí   | Producto                                        |
| `location_id`                  | Many2one | Sí   | Ubicación de almacenamiento                     |
| `lot_id`                       | Many2one | —    | Lote o número de serie                          |
| `package_id`                   | Many2one | —    | Paquete que contiene el producto                |
| `owner_id`                     | Many2one | —    | Propietario del producto                        |
| `quantity`                     | Float    | —    | Cantidad en mano (readonly)                     |
| `reserved_quantity`            | Float    | —    | Cantidad reservada para movimientos (readonly)  |
| `available_quantity`           | Float    | —    | `quantity - reserved_quantity` (computado)      |
| `in_date`                      | Datetime | Sí   | Fecha de ingreso (para FIFO/FEFO)               |
| `inventory_quantity`           | Float    | —    | Cantidad contada en inventario físico           |
| `inventory_diff_quantity`      | Float    | —    | Diferencia conteo vs sistema (computado)        |
| `inventory_date`               | Date     | —    | Fecha del próximo conteo (computado/editable)   |
| `last_count_date`              | Date     | —    | Fecha del último conteo físico (computado)      |
| `user_id`                      | Many2one | —    | Usuario asignado para el conteo                 |

---

## `stock.rule`

```
Tabla BD: stock_rule
```

| Campo               | Tipo      | Req. | Descripción                                         |
|---------------------|-----------|:----:|-----------------------------------------------------|
| `name`              | Char      | Sí   | Nombre de la regla                                  |
| `active`            | Boolean   | —    | Activo/inactivo                                     |
| `action`            | Selection | Sí   | `pull` · `push` · `pull_push`                       |
| `procure_method`    | Selection | —    | `make_to_stock` · `make_to_order` · `mts_else_mto`  |
| `route_id`          | Many2one  | Sí   | Ruta a la que pertenece                             |
| `picking_type_id`   | Many2one  | Sí   | Tipo de operación a crear                           |
| `location_src_id`   | Many2one  | —    | Ubicación origen del movimiento                     |
| `location_dest_id`  | Many2one  | Sí   | Ubicación destino del movimiento                    |
| `warehouse_id`      | Many2one  | —    | Almacén específico                                  |
| `delay`             | Integer   | —    | Días de plazo para generar el movimiento            |
| `auto`              | Selection | —    | `manual` (el usuario crea) · `transparent` (automático)|
| `propagate_cancel`  | Boolean   | —    | Cancelar el movimiento siguiente al cancelar este   |
| `company_id`        | Many2one  | Sí   | Empresa                                             |

---

## `stock.lot`

```
Tabla BD: stock_lot
```

| Campo          | Tipo     | Req. | Descripción                                        |
|----------------|----------|:----:|----------------------------------------------------|
| `name`         | Char     | Sí   | Número de lote o serie                             |
| `product_id`   | Many2one | Sí   | Producto al que pertenece                          |
| `company_id`   | Many2one | Sí   | Empresa                                            |
| `expiration_date` | Datetime | —  | Fecha de vencimiento (si módulo `expiration`)      |
| `quant_ids`    | One2many | —    | Quantas con este lote                              |
| `product_qty`  | Float    | —    | Cantidad disponible (computado desde quants)       |
