# Módulo: `stock` — Odoo 19

> **Versión del módulo:** 1.1
> **Categoría:** Supply Chain/Inventory
> **Licencia:** LGPL-3
> **Fuente:** Odoo Community

## Propósito

Gestión de inventario y logística de almacén. Controla el ciclo completo de movimientos de producto: recepciones, transferencias internas, entregas, devoluciones, ajustes de inventario y trazabilidad por lote/número de serie.

## Dependencias

| Módulo                       | Rol en la dependencia                              |
|------------------------------|----------------------------------------------------|
| `product`                    | Productos, variantes, unidades de medida           |
| `barcodes_gs1_nomenclature`  | Soporte de códigos de barras GS1 en ubicaciones    |
| `digest`                     | KPIs para reportes periódicos por email            |

> **Módulos que enriquecen `stock`:** `sale` (órdenes de entrega desde ventas), `purchase` (recepciones desde compras), `mrp` (consumos de producción), `account` (valoración de inventario)

## Modelos principales

| Modelo                      | Descripción                                              |
|-----------------------------|----------------------------------------------------------|
| `stock.warehouse`           | Almacén con rutas, ubicaciones y tipos de operación      |
| `stock.location`            | Ubicación física o virtual en la jerarquía del almacén   |
| `stock.picking`             | Transferencia: conjunto de movimientos a procesar        |
| `stock.move`                | Movimiento individual de un producto entre ubicaciones   |
| `stock.move.line`           | Línea de detalle con lote, paquete y cantidad real       |
| `stock.quant`               | Cantidad disponible de un producto en una ubicación      |
| `stock.lot`                 | Lote o número de serie de un producto                    |
| `stock.rule`                | Regla de reabastecimiento (pull/push)                    |
| `stock.warehouse.orderpoint`| Punto de reorden (stock mínimo)                          |

## Flujo de estados de `stock.picking`

```
draft (Borrador)
    ↓ action_confirm()
assigned (Listo / Disponible)  ←── action_assign() si hay stock
    ↓ button_validate()
done (Validado)
    ↓ action_cancel()
cancel (Cancelado)
```

## Flujo de estados de `stock.move`

```
draft → confirmed → waiting → assigned → done
                      ↑           ↑
               (esperando     (stock
                movimiento     reservado)
                anterior)
```

## Pasos de almacén configurables

### Recepción (`reception_steps`)
| Valor         | Flujo                                             |
|---------------|---------------------------------------------------|
| `one_step`    | Proveedor → Stock                                 |
| `two_steps`   | Proveedor → Entrada → Stock                       |
| `three_steps` | Proveedor → Entrada → Control de calidad → Stock  |

### Entrega (`delivery_steps`)
| Valor           | Flujo                                            |
|-----------------|--------------------------------------------------|
| `ship_only`     | Stock → Cliente                                  |
| `pick_ship`     | Stock → Salida → Cliente                         |
| `pick_pack_ship`| Stock → Empaque → Salida → Cliente               |

## Tipos de ubicación (`usage`)

| Valor        | Descripción                                    |
|--------------|------------------------------------------------|
| `internal`   | Ubicación física real del almacén              |
| `supplier`   | Ubicación virtual de proveedores (origen)      |
| `customer`   | Ubicación virtual de clientes (destino)        |
| `transit`    | Tránsito entre almacenes o empresas            |
| `inventory`  | Ajustes de inventario                          |
| `production` | Consumo/producción en manufactura              |
| `view`       | Agrupador jerárquico virtual                   |

## Integraciones clave

- **`sale.order`** → genera `stock.picking` tipo salida al confirmar
- **`purchase.order`** → genera `stock.picking` tipo recepción al confirmar
- **`account.move`** → la valoración de movimientos crea asientos contables (si `perpetual inventory`)
- **`mrp.production`** → consume y produce `stock.move` como componentes y productos terminados
