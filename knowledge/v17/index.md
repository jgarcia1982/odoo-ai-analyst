# Odoo 17 — Índice de Módulos

## Núcleo (siempre presentes)

| Módulo       | Descripción                          | Archivo                  |
|--------------|--------------------------------------|--------------------------|
| `base`       | Modelos fundamentales del ORM        | [base.md](core/base.md)  |
| `mail`       | Mensajería, chatter, notificaciones  | [mail.md](core/mail.md)  |
| `web`        | Frontend, vistas, widgets            | pendiente                |
| `base_setup` | Configuración inicial                | pendiente                |

## Contabilidad y Finanzas

| Módulo              | Descripción                          | Archivo                          |
|---------------------|--------------------------------------|----------------------------------|
| `account`           | Contabilidad general                 | [account.md](core/account.md)    |
| `account_payment`   | Pagos y reconciliación               | pendiente                        |
| `account_tax`       | Gestión de impuestos                 | pendiente                        |

## Ventas

| Módulo        | Descripción                  | Archivo    |
|---------------|------------------------------|------------|
| `sale`        | Órdenes de venta             | pendiente  |
| `sale_crm`    | CRM integrado con ventas     | pendiente  |
| `crm`         | Pipeline de oportunidades    | pendiente  |

## Inventario y Logística

| Módulo         | Descripción                    | Archivo    |
|----------------|--------------------------------|------------|
| `stock`        | Inventario y movimientos       | pendiente  |
| `purchase`     | Órdenes de compra              | pendiente  |
| `mrp`          | Fabricación                    | pendiente  |

## RRHH

| Módulo       | Descripción                | Archivo    |
|--------------|----------------------------|------------|
| `hr`         | Empleados                  | pendiente  |
| `hr_payroll` | Nómina                     | pendiente  |
| `hr_leave`   | Vacaciones y ausencias     | pendiente  |

## Cambios destacados en v17

- Nueva arquitectura de vistas con Owl 2 (framework JS)
- `account.move` consolidado — eliminado `account.invoice`
- `mail.thread` refactorizado, nuevos mixins de chatter
- Acciones de servidor con soporte mejorado para código Python
- `base.automation` rediseñado
