# Seguridad — `sale` — Odoo 19

## Grupos definidos en este módulo (`security/res_groups.xml`)

Estos grupos son **configuraciones opcionales**, no niveles de acceso:

| ID XML                              | Nombre visible               | Qué habilita                                          |
|-------------------------------------|------------------------------|-------------------------------------------------------|
| `sale.group_auto_done_setting`      | Bloquear ventas confirmadas  | Bloquea automáticamente las órdenes al confirmarlas   |
| `sale.group_discount_per_so_line`   | Descuento en líneas          | Muestra campo `discount` por línea en la orden        |
| `sale.group_warning_sale`           | Advertencias en ventas       | Muestra alertas de producto/cliente en la orden       |
| `sale.group_proforma_sales`         | Facturas Pro-forma           | Habilita botón "Enviar Pro-forma"                     |

## Grupos de acceso (heredados de `sales_team`)

Estos son los grupos que controlan el acceso al módulo:

| ID XML                                        | Nombre visible             |
|-----------------------------------------------|----------------------------|
| `sales_team.group_sale_salesman`              | Ventas: Usuario            |
| `sales_team.group_sale_manager`               | Ventas: Administrador      |
| `sales_team.group_sale_salesman_all_leads`    | Ventas: Ver todos los pedidos |

**Jerarquía:**
```
group_sale_manager
    └── group_sale_salesman_all_leads
            └── group_sale_salesman
```

---

## Permisos CRUD por modelo (`ir.model.access.csv`)

### `sale.order`

| Grupo                                    | Create | Read | Write | Delete |
|------------------------------------------|:------:|:----:|:-----:|:------:|
| `base.group_portal`                      |        |  ✓   |   ✓   |        |
| `account.group_account_readonly`         |        |  ✓   |       |        |
| `account.group_account_invoice`          |        |  ✓   |   ✓   |        |
| `account.group_account_user`             |        |  ✓   |   ✓   |        |
| `sales_team.group_sale_salesman`         |  ✓     |  ✓   |   ✓   |        |
| `sales_team.group_sale_manager`          |  ✓     |  ✓   |   ✓   |   ✓    |

### `sale.order.line`

| Grupo                                    | Create | Read | Write | Delete |
|------------------------------------------|:------:|:----:|:-----:|:------:|
| `base.group_portal`                      |        |  ✓   |       |        |
| `account.group_account_readonly`         |        |  ✓   |       |        |
| `account.group_account_invoice`          |        |  ✓   |   ✓   |        |
| `account.group_account_user`             |        |  ✓   |   ✓   |        |
| `sales_team.group_sale_salesman`         |  ✓     |  ✓   |   ✓   |        |
| `sales_team.group_sale_manager`          |  ✓     |  ✓   |   ✓   |   ✓    |

### Modelos auxiliares — acceso de vendedores

| Modelo                       | Create | Read | Write | Delete | Notas                      |
|------------------------------|:------:|:----:|:-----:|:------:|----------------------------|
| `account.move`               |        |  ✓   |       |        | Vendedores: solo lectura    |
| `account.move.line`          |        |  ✓   |       |        | Vendedores: solo lectura    |
| `account.journal`            |        |  ✓   |       |        |                             |
| `account.payment.term`       |        |  ✓   |       |        |                             |
| `account.tax`                |        |  ✓   |       |        |                             |
| `product.pricelist`          |  ✓     |  ✓   |   ✓   |   ✓    | Solo managers               |
| `product.pricelist.item`     |  ✓     |  ✓   |   ✓   |   ✓    | Solo managers               |
| `res.partner`                |        |  ✓   |       |        | Vendedores: solo lectura    |
| `res.partner`                |  ✓     |  ✓   |   ✓   |        | Managers: sin delete        |
| `payment.transaction`        |        |  ✓   |       |        | Vendedores: lectura         |

---

## Reglas de dominio (`ir.rule`)

### Reglas multi-empresa

| Regla                             | Modelo       | Dominio                                         | Aplica a       |
|-----------------------------------|--------------|-------------------------------------------------|----------------|
| `sale.sale_order_company_rule`    | `sale.order` | `[('company_id', 'in', company_ids)]`           | Todos          |

### Reglas de portal (cliente externo)

| Regla                                      | Modelo       | Dominio                                                    | Permisos          |
|--------------------------------------------|--------------|------------------------------------------------------------|-------------------|
| `sale.sale_order_portal_rule`              | `sale.order` | `[('partner_id', 'child_of', [user.partner_id.id])]`       | read, write       |

> El usuario portal solo ve sus propias órdenes. No puede crear.

### Reglas de vendedores

| Regla                                      | Modelo       | Dominio                                                    | Aplica a                          |
|--------------------------------------------|--------------|------------------------------------------------------------|-----------------------------------|
| `sale.sale_order_personal_rule`            | `sale.order` | `['|', ('user_id', '=', user.id), ('user_id', '=', False)]` | `group_sale_salesman`            |
| `sale.sale_order_see_all_rule`             | `sale.order` | `[(1, '=', 1)]` (sin restricción)                          | `group_sale_salesman_all_leads`   |

> **Importante:** Un vendedor estándar solo ve sus propios pedidos o los no asignados. Un vendedor con `group_sale_salesman_all_leads` ve todos.

### Reglas de facturas para vendedores

| Regla                                      | Modelo         | Dominio                                                   | Aplica a                  |
|--------------------------------------------|----------------|-----------------------------------------------------------|---------------------------|
| Facturas propias                           | `account.move` | `[('invoice_user_id', '=', user.id)]`                     | `group_sale_salesman`     |
| Todas las facturas                         | `account.move` | `[(1, '=', 1)]`                                           | `group_sale_manager`      |

---

## Campos con restricción de grupo en vistas

| Campo              | Modelo              | Grupo requerido                         | Tipo de restricción         |
|--------------------|---------------------|-----------------------------------------|-----------------------------|
| `discount`         | `sale.order.line`   | `sale.group_discount_per_so_line`       | invisible si no tiene grupo |
| Lista de precios   | Formulario          | `product.group_product_pricelist`       | invisible si no tiene grupo |
| Botón Pro-forma    | Formulario          | `sale.group_proforma_sales`             | invisible si no tiene grupo |
| Menú Configuración | Menús               | `sales_team.group_sale_manager`         | menú no visible             |
| Menú Reportes      | Menús               | `sales_team.group_sale_manager`         | menú no visible             |
