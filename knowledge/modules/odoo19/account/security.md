# Seguridad — `account` — Odoo 19

## Grupos del módulo (`security/res_groups.xml`)

### Grupos de acceso principal (jerarquía)

```
group_account_manager (Administrador)
    └── group_account_invoice (Facturación)
            └── group_account_basic (Básico)
                    ├── group_account_user (Contable completo)
                    └── group_account_readonly (Solo lectura)
```

| ID XML                             | Nombre visible                        | Qué puede hacer                                          |
|------------------------------------|---------------------------------------|----------------------------------------------------------|
| `account.group_account_invoice`    | Facturación                           | Crear/editar facturas y pagos, reportes básicos          |
| `account.group_account_basic`      | Básico                                | Acceso contable básico, conciliación bancaria simple     |
| `account.group_account_readonly`   | Ver funciones contables - Solo lectura| Ver TODO el módulo sin poder modificar nada              |
| `account.group_account_user`       | Ver funciones contables completas     | Contable completo: asientos, reportes, conciliación      |
| `account.group_account_manager`    | Administrador                         | Configuración total: plan de cuentas, diarios, períodos  |

### Grupos de configuración opcionales

| ID XML                                      | Nombre visible                | Qué habilita                                     |
|---------------------------------------------|-------------------------------|--------------------------------------------------|
| `account.group_account_secured`             | Funciones de inalterabilidad  | Modo de hash en asientos publicados              |
| `account.group_cash_rounding`               | Redondeo de caja              | Campo `invoice_cash_rounding_id` en facturas     |
| `account.group_partial_purchase_deductibility` | Deducibilidad parcial       | Campo de porcentaje de deducción en impuestos    |
| `account.group_validate_bank_account`       | Validar cuentas bancarias     | Flujo de validación de cuentas IBAN              |

---

## Permisos CRUD por modelo (`ir.model.access.csv`)

### `account.move`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_invoice`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_readonly`    |        |  ✓   |       |        |
| `base.group_portal`                 |        |  ✓   |       |        |

### `account.move.line`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_invoice`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_readonly`    |        |  ✓   |       |        |

### `account.journal`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_invoice`     |        |  ✓   |       |        |
| `account.group_account_readonly`    |        |  ✓   |       |        |

### `account.account`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_readonly`    |        |  ✓   |       |        |
| `base.group_user`                   |        |  ✓   |       |        |

> **Nota:** Cualquier usuario interno puede leer el plan de cuentas (necesario para dropdowns en otros módulos).

### `account.tax`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_invoice`     |        |  ✓   |       |        |
| `account.group_account_readonly`    |        |  ✓   |       |        |
| `base.group_user`                   |        |  ✓   |       |        |

### `account.payment`

| Grupo                               | Create | Read | Write | Delete |
|-------------------------------------|:------:|:----:|:-----:|:------:|
| `account.group_account_manager`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_invoice`     |   ✓    |  ✓   |   ✓   |   ✓    |
| `account.group_account_readonly`    |        |  ✓   |       |        |

---

## Reglas de dominio (`ir.rule`)

### Multi-empresa

| Regla                              | Modelo              | Dominio                                          |
|------------------------------------|---------------------|--------------------------------------------------|
| `account_move_comp_rule`           | `account.move`      | `[('company_id', 'in', company_ids)]`            |
| `account_move_line_comp_rule`      | `account.move.line` | `[('company_id', 'in', company_ids)]`            |
| `account_comp_rule`                | `account.account`   | `[('company_ids', 'parent_of', company_ids)]`    |
| `journal_comp_rule`                | `account.journal`   | `[('company_id', 'parent_of', company_ids)]`     |
| `tax_comp_rule`                    | `account.tax`       | `[('company_id', 'parent_of', company_ids)]`     |

> `parent_of` permite que las empresas hijas hereden diarios y cuentas de la empresa padre en configuración multi-empresa.

### Portal (cliente externo)

| Regla                              | Modelo              | Dominio                                                                    |
|------------------------------------|---------------------|----------------------------------------------------------------------------|
| `account_invoice_rule_portal`      | `account.move`      | `[('state', 'not in', ['draft', 'cancel']), ('partner_id', 'child_of', [user.partner_id.id])]` |
| `account_invoice_line_rule_portal` | `account.move.line` | `[('move_id.partner_id', 'child_of', [user.partner_id.id])]`              |

> El portal solo ve facturas publicadas o canceladas que son suyas. No ve borradores.

### Reglas por grupo (acceso amplio)

| Regla                                 | Modelo              | Grupo                               | Acceso      |
|---------------------------------------|---------------------|-------------------------------------|-------------|
| `account_move_see_all`                | `account.move`      | `group_account_invoice`             | Ver todo    |
| `account_move_line_see_all`           | `account.move.line` | `group_account_invoice`             | Ver todo    |
| `account_move_rule_group_readonly`    | `account.move`      | `group_account_readonly`            | Solo leer   |
| `account_move_line_rule_group_readonly`| `account.move.line`| `group_account_readonly`            | Solo leer   |

---

## Campos con visibilidad restringida por grupo

| Campo / Sección             | Modelo            | Grupo requerido                          | Restricción               |
|-----------------------------|-------------------|------------------------------------------|---------------------------|
| Asientos manuales (menú)    | UI                | `group_account_user`                     | No visible sin el grupo   |
| Reportes financieros        | UI                | `group_account_user`                     | No visible sin el grupo   |
| Plan de cuentas (editar)    | `account.account` | `group_account_manager`                  | Solo lectura sin el grupo |
| Configuración de diarios    | `account.journal` | `group_account_manager`                  | Solo lectura sin el grupo |
| Hash de inalterabilidad     | `account.move`    | `group_account_secured`                  | Invisible sin el grupo    |
| Redondeo de efectivo        | `account.move`    | `group_cash_rounding`                    | Invisible sin el grupo    |
