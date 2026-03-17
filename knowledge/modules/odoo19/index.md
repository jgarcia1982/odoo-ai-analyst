# Atlas Técnico — Odoo 19 Community

> **Fuente:** Odoo Community Edition
> **Enterprise:** pendiente (se agregará cuando esté disponible)
> **Última actualización:** 2026-03-16

## Módulos documentados

| Módulo  | Descripción                       | Estado       | Archivos                          |
|---------|-----------------------------------|:------------:|-----------------------------------|
| `sale`    | Cotizaciones y órdenes de venta         | ✅ Completo  | [ver →](sale/)    |
| `account` | Facturas, asientos, impuestos, pagos    | ✅ Completo  | [ver →](account/) |
| `stock`   | Inventario, transferencias, trazabilidad| ✅ Completo  | [ver →](stock/)   |

## Módulos pendientes

### Núcleo
| Módulo       | Prioridad |
|--------------|-----------|
| `base`       | Alta      |
| `mail`       | Alta      |
| `web`        | Media     |

### Contabilidad
| Módulo            | Prioridad |
|-------------------|-----------|
| `account_payment` | Media     |

### Operaciones
| Módulo     | Prioridad |
|------------|-----------|
| `stock`    | Alta      |
| `purchase` | Alta      |
| `mrp`      | Media     |

### RRHH
| Módulo       | Prioridad |
|--------------|-----------|
| `hr`         | Media     |
| `hr_payroll` | Baja      |

### CRM y Marketing
| Módulo  | Prioridad |
|---------|-----------|
| `crm`   | Alta      |
| `utm`   | Baja      |

## Convención de documentación

Cada módulo tiene estos archivos:

```
{modulo}/
├── summary.md              # Propósito, dependencias, flujo de estados
├── models.md               # Modelos, campos, relaciones
├── views.md                # Vistas, menús, filtros
├── security.md             # Grupos, permisos CRUD, ir.rule
├── extension_points.md     # Cómo extender: overrides, xpaths, hooks
└── requirement_guidelines.md  # Guía para el desarrollador
```

## Enterprise (futuro)

Cuando esté disponible el código enterprise, se agregarán:

```
knowledge/modules/odoo19-enterprise/
├── account_accountant/
├── hr_payroll/
├── mrp_workorder/
└── ...
```
