# Seguridad — `stock` — Odoo 19

## Grupos del módulo (`security/stock_security.xml`)

### Grupos de acceso principal

```
group_stock_manager (Administrador de inventario)
    └── group_stock_user (Usuario de inventario)
            └── base.group_user
```

| ID XML                          | Nombre visible                 | Qué puede hacer                                         |
|---------------------------------|--------------------------------|---------------------------------------------------------|
| `stock.group_stock_user`        | Inventario: Usuario            | Validar transferencias, ver stock, recepciones, entregas |
| `stock.group_stock_manager`     | Inventario: Administrador      | Configurar almacenes, rutas, ubicaciones, reabastecimiento |

### Grupos de configuración opcional (habilitan funcionalidades)

| ID XML                               | Nombre visible                     | Qué habilita                                          |
|--------------------------------------|------------------------------------|-------------------------------------------------------|
| `stock.group_stock_multi_locations`  | Ubicaciones de almacén múltiples   | Mostrar y editar ubicaciones detalladas               |
| `stock.group_stock_multi_warehouses` | Almacenes múltiples                | Crear y gestionar más de un almacén                   |
| `stock.group_production_lot`         | Números de lote y serie            | Campo `lot_id` en transferencias y quants             |
| `stock.group_tracking_lot`           | Gestión de paquetes                | Empacar productos, rastrear paquetes                  |
| `stock.group_adv_location`           | Rutas de inventario avanzadas      | Configurar rutas push/pull, reglas de aprovisionamiento |
| `stock.group_tracking_owner`         | Propietarios de stock distintos    | Campo `owner_id` en quants y movimientos              |
| `stock.group_stock_lot_print_gs1`    | Imprimir etiquetas GS1             | Etiquetas de lote con código de barras GS1            |
| `stock.group_lot_on_delivery_slip`   | Lotes en albarán de entrega        | Mostrar números de lote en PDF de entrega             |
| `stock.group_stock_sign_delivery`    | Firma en entrega                   | Capturar firma del cliente al entregar                |
| `stock.group_reception_report`       | Reporte de recepción               | Ver reporte de asignación al recibir                  |
| `stock.group_warning_stock`          | Advertencias de stock              | Mostrar alertas en productos para operadores          |

---

## Permisos CRUD por modelo (`ir.model.access.csv`)

### `stock.picking`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |   ✓    |  ✓   |   ✓   |   ✓    |

### `stock.move`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |   ✓    |  ✓   |   ✓   |        |
| `base.group_user`               |        |  ✓   |       |        |

> Usuarios de stock no pueden borrar movimientos — son parte del historial contable.

### `stock.move.line`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |   ✓    |  ✓   |   ✓   |   ✓    |

### `stock.quant`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |   ✓    |  ✓   |   ✓   |        |
| `base.group_user`               |        |  ✓   |       |        |

> El stock disponible es visible para cualquier usuario interno (necesario para forecasts en ventas).

### `stock.location`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |        |  ✓   |       |        |
| `base.group_user`               |        |  ✓   |       |        |

### `stock.warehouse`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |        |  ✓   |       |        |

### `stock.lot`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |   ✓    |  ✓   |   ✓   |        |
| `base.group_user`               |        |  ✓   |       |        |

### `stock.rule` / `stock.route`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |        |  ✓   |       |        |

### `stock.warehouse.orderpoint`

| Grupo                           | Create | Read | Write | Delete |
|---------------------------------|:------:|:----:|:-----:|:------:|
| `stock.group_stock_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `stock.group_stock_user`        |        |  ✓   |       |        |

---

## Reglas de dominio (`ir.rule`)

### Multi-empresa

| Regla                          | Modelo              | Dominio                                          | Notas                                  |
|--------------------------------|---------------------|--------------------------------------------------|----------------------------------------|
| `stock_picking_comp_rule`      | `stock.picking`     | `[('company_id', 'in', company_ids)]`            |                                        |
| `stock_picking_type_comp_rule` | `stock.picking.type`| `[('company_id', 'in', company_ids)]`            |                                        |
| `stock_warehouse_comp_rule`    | `stock.warehouse`   | `[('company_id', 'in', company_ids)]`            |                                        |
| `stock_location_comp_rule`     | `stock.location`    | `[('company_id', 'in', company_ids + [False])]`  | `False` = ubicaciones sin empresa (virtuales) |
| `stock_move_comp_rule`         | `stock.move`        | `[('company_id', 'in', company_ids)]`            |                                        |
| `stock_move_line_comp_rule`    | `stock.move.line`   | `[('company_id', 'in', company_ids + [False])]`  |                                        |
| `stock_quant_comp_rule`        | `stock.quant`       | `[('company_id', 'in', company_ids + [False])]`  | `False` = quants sin empresa (propietario externo) |
| `stock_lot_comp_rule`          | `stock.lot`         | `[('company_id', 'in', company_ids + [False])]`  |                                        |
| `stock_rule_comp_rule`         | `stock.rule`        | `[('company_id', 'in', company_ids + [False])]`  |                                        |
| `stock_route_comp_rule`        | `stock.route`       | `[('company_id', 'in', company_ids + [False])]`  |                                        |
| `stock_package_comp_rule`      | `stock.package`     | `[('company_id', 'in', company_ids + [False])]`  |                                        |

> **Patrón `+ [False]`:** Las ubicaciones, quants y lotes sin `company_id` son accesibles por todas las empresas. Esto permite ubicaciones compartidas (ej. proveedor externo, cliente común).

---

## Visibilidad de campos según grupo

| Campo / Sección                     | Grupo requerido                         | Efecto si no tiene el grupo           |
|-------------------------------------|-----------------------------------------|---------------------------------------|
| Campo `lot_id` en transferencias    | `stock.group_production_lot`            | Invisible                             |
| Campo `package_id` / empacar        | `stock.group_tracking_lot`              | Invisible                             |
| Campo `owner_id`                    | `stock.group_tracking_owner`            | Invisible                             |
| Tab de ubicaciones (formulario picking) | `stock.group_stock_multi_locations` | Invisible                             |
| Menú de rutas y reglas              | `stock.group_adv_location`              | No visible                            |
| Configuración de almacenes múltiples| `stock.group_stock_multi_warehouses`    | Un solo almacén visible               |
| Firma en entrega                    | `stock.group_stock_sign_delivery`       | Sin botón de firma                    |
| Reporte de recepción                | `stock.group_reception_report`          | Sin botón de reporte                  |
| Configuración de inventario         | `stock.group_stock_manager`             | Solo lectura                          |
