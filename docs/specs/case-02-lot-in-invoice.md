# Especificación técnica: Trazabilidad de lote en línea de factura

**Tipo:** Propagación de datos
**Complejidad:** Media
**Módulos afectados:** `sale`, `stock`, `account`
**Versión Odoo:** 19.0
**Módulo a crear:** `sale_stock_lot_invoice`

---

## Resumen ejecutivo

Cuando se genera una factura desde una orden de venta, cada línea de factura debe mostrar los números de lote o serie del producto entregado en el albarán asociado. El dato vive en `stock.move.line.lot_id` y debe propagarse a `account.move.line` sin que el módulo `account` dependa de `stock`. La propagación ocurre en `sale.order.line._prepare_invoice_line()`, que ya tiene acceso a los movimientos de stock asociados.

---

## Módulo a crear

- **Nombre técnico:** `sale_stock_lot_invoice`
- **Depende de:** `sale_stock` (que ya incluye `sale`, `stock`, `account`)
- **Licencia:** LGPL-3
- **Versión:** `19.0.1.0.0`

> **Nota de diseño:** Se usa `sale_stock` como dependencia en lugar de `sale + stock + account` por separado porque `sale_stock` ya provee el puente entre `sale.order.line` y `stock.move`. Esto garantiza que `_prepare_invoice_line()` ya ha sido enriquecido por `sale_stock` antes de nuestro override.

---

## Árbol de directorio

```
sale_stock_lot_invoice/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   ├── account_move_line.py       # Campo numero_lotes
│   └── sale_order_line.py         # Override _prepare_invoice_line()
└── views/
    └── account_move_views.xml     # Columna opcional en líneas de factura
```

---

## Cambios por modelo

### `account.move.line` — Campo nuevo

| Campo          | Tipo    | Atributos                                    | Propósito                              |
|----------------|---------|----------------------------------------------|----------------------------------------|
| `numero_lotes` | `Char`  | `readonly=True`, `copy=False`, `store=False` | Número(s) de lote del producto entregado |

**Decisión `store=False`:** El dato viene del albarán; si se almacena puede quedar desincronizado si se modifica el albarán tras facturar. Siempre se recalcula desde el origen. No se puede usar `@api.depends` porque requeriría que `account` dependa de `stock` — en su lugar, el valor se inyecta en `_prepare_invoice_line()` y se guarda en el registro.

> **Corrección respecto al test case:** Aunque la guía dice `store=False`, para que el valor persista en la base de datos (y sea visible al abrir la factura) el campo **debe ser `store=True`** con valor inyectado en `create`/`write` via `_prepare_invoice_line()`. Con `store=False` sin `@api.depends`, el campo siempre mostraría vacío al releer el registro. Se usa `store=True` + el valor se setea una sola vez al crear la línea de factura. **No se recalcula después** — esto es correcto porque los lotes entregados no cambian tras facturar.

**Definición final:**

```python
numero_lotes = fields.Char(
    string='Lotes / Series',
    readonly=True,
    copy=False,
    help='Números de lote o serie del producto entregado en el albarán.',
)
```

---

### `sale.order.line` — Override de `_prepare_invoice_line()`

Este método construye el diccionario `vals` que se usará para crear cada `account.move.line`. Es el punto correcto para inyectar `numero_lotes` porque:

1. `self` es la `sale.order.line` que origina la línea de factura.
2. Recibe `**optional_values` (incluye `move_id` desde Odoo 17+).
3. Ya tiene acceso a `self.move_ids` (los `stock.move` asociados) gracias a `sale_stock`.

**Flujo de datos:**

```
sale.order.line
    └── move_ids                        # stock.move asociados (via sale_stock)
            └── move_line_ids           # stock.move.line (detail)
                    └── lot_id.name     # "LOT001", "LOT002"
                            ↓
        _prepare_invoice_line() → vals['numero_lotes'] = "LOT001, LOT002"
                            ↓
        account.move.line.numero_lotes
```

---

## Código Python completo

### `models/account_move_line.py`

```python
# © 2026 — sale_stock_lot_invoice
# License LGPL-3.0 or later (https://www.gnu.org/licenses/lgpl).

from odoo import fields, models


class AccountMoveLine(models.Model):
    _inherit = 'account.move.line'

    numero_lotes = fields.Char(
        string='Lotes / Series',
        readonly=True,
        copy=False,
        help='Números de lote o serie del producto entregado en el albarán.',
    )
```

### `models/sale_order_line.py`

```python
# © 2026 — sale_stock_lot_invoice
# License LGPL-3.0 or later (https://www.gnu.org/licenses/lgpl).

from odoo import models


class SaleOrderLine(models.Model):
    _inherit = 'sale.order.line'

    def _prepare_invoice_line(self, **optional_values):
        """Inyecta los lotes entregados en el diccionario de vals de la línea de factura.

        Solo considera los stock.move en estado 'done' para no incluir
        entregas parciales pendientes. Si el producto no tiene seguimiento
        por lote/serie, el campo queda vacío sin error.
        """
        vals = super()._prepare_invoice_line(**optional_values)

        # Recolectar nombres de lote de todos los movimientos de stock 'done'
        # asociados a esta línea de venta.
        lot_names = []
        for stock_move in self.move_ids.filtered(lambda m: m.state == 'done'):
            for move_line in stock_move.move_line_ids:
                if move_line.lot_id and move_line.lot_id.name not in lot_names:
                    lot_names.append(move_line.lot_id.name)

        if lot_names:
            vals['numero_lotes'] = ', '.join(lot_names)

        return vals
```

### `__manifest__.py`

```python
{
    'name': 'Sale Stock — Lotes en factura',
    'version': '19.0.1.0.0',
    'category': 'Inventory/Inventory',
    'summary': 'Muestra los lotes/series entregados en cada línea de factura',
    'author': 'Custom',
    'license': 'LGPL-3',
    'depends': ['sale_stock'],
    'data': [
        'views/account_move_views.xml',
    ],
    'installable': True,
    'auto_install': False,
}
```

### `models/__init__.py`

```python
from . import account_move_line
from . import sale_order_line
```

---

## Vistas — XML

### `views/account_move_views.xml`

Añade la columna `numero_lotes` al listado de líneas de la factura de cliente. Se usa `optional="show"` para que aparezca por defecto pero sea ocultable por el usuario.

```xml
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <!-- Columna "Lotes / Series" en líneas de factura de cliente -->
    <record id="view_move_form_inherit_lot_invoice" model="ir.ui.view">
        <field name="name">account.move.form.inherit.lot.invoice</field>
        <field name="model">account.move</field>
        <field name="inherit_id" ref="account.view_move_form"/>
        <field name="arch" type="xml">
            <!--
                Insertamos después de la columna 'quantity' en el one2many
                de líneas de factura (invoice_line_ids).
                El xpath apunta al field 'quantity' dentro del tree de líneas.
            -->
            <xpath
                expr="//field[@name='invoice_line_ids']//tree//field[@name='quantity']"
                position="after">
                <field
                    name="numero_lotes"
                    string="Lotes / Series"
                    optional="show"
                    readonly="1"
                />
            </xpath>
        </field>
    </record>
</odoo>
```

> **Nota de xpath:** El selector apunta a `invoice_line_ids` (no `line_ids`) porque en la vista de factura de cliente las líneas facturables se muestran en ese widget. Si el contexto del proyecto usa una versión de la vista que difiera, ajustar el xpath con la herramienta de inspector de vistas de Odoo (`?debug=assets` → Technical → Views).

---

## Flujo completo de datos

```
[Orden de venta]
    sale.order.line (product_id, qty_to_invoice)
            │
            │  (al crear factura: make_invoices → _create_invoices)
            ▼
    sale.order.line._prepare_invoice_line()
            │  Itera self.move_ids (stock.move state='done')
            │      └── move_line_ids.lot_id.name
            │  → vals['numero_lotes'] = "LOT001, LOT002"
            ▼
    account.move.line (CREADA)
            └── numero_lotes = "LOT001, LOT002"  ← persiste en DB
                    │
                    ▼
            Vista de factura (columna optional="show")
```

---

## Escenario: facturas parciales

Odoo puede generar múltiples facturas para una misma orden de venta (entregas parciales). El comportamiento es correcto porque:

- `self.move_ids` contiene **todos** los `stock.move` de la `sale.order.line`.
- Al generar la primera factura (parcial), solo los `stock.move` con `state='done'` hasta ese momento son considerados.
- Al generar la segunda factura, los lotes del segundo albarán se incluyen en esa segunda factura.
- **Limitación conocida:** Si dos líneas de factura provienen de la misma `sale.order.line` (raro pero posible en facturas manuales), ambas tendrán el mismo valor `numero_lotes`. Esto es aceptable — documentar en el README del módulo.

---

## Casos límite

| Escenario                                    | Comportamiento esperado                                         | Verificado con                                        |
|----------------------------------------------|-----------------------------------------------------------------|-------------------------------------------------------|
| Producto sin seguimiento (`tracking='none'`) | `numero_lotes` queda vacío (sin error)                          | `if move_line.lot_id` en el loop                      |
| Producto con seguimiento por número de serie | Muestra múltiples series: `"SN001, SN002"`                      | Mismo código — `lot_id` aplica a serie también        |
| Varios lotes del mismo producto en un albarán | `"LOT001, LOT002"` (sin duplicados)                            | `if name not in lot_names`                            |
| Factura creada manualmente (sin origen sale)  | Campo vacío — `move_ids` estará vacío                           | Loop no itera, `lot_names` vacío                      |
| `sale_stock` no instalado                    | Módulo no instalable (depende de `sale_stock`)                  | Odoo bloquea la instalación si falta la dependencia   |
| Albarán devuelto (reverse picking)           | Los lotes del movimiento de devolución NO aparecen en la factura | Filtro `state='done'` excluye movimientos revertidos? — **Ver riesgo R-02** |
| Producto tipo servicio (sin albarán)         | `move_ids` vacío → campo vacío, sin error                       | Loop no itera                                         |
| Multi-empresa                                | Cada factura ve solo los movimientos de su propia empresa        | `move_ids` ya está filtrado por empresa en el ORM     |

---

## Puntos de riesgo

| ID    | Riesgo                                                                 | Probabilidad | Impacto | Mitigación                                                                                         |
|-------|------------------------------------------------------------------------|:------------:|:-------:|----------------------------------------------------------------------------------------------------|
| R-01  | El xpath de vista apunta a un `field[@name='quantity']` no único       | Media        | Bajo    | Verificar con Odoo debug mode. Si no es único, añadir más contexto al xpath (p.ej. `@name='invoice_line_ids'//...`) |
| R-02  | Movimientos de devolución (state='done') aparecen en el listado de lotes | Baja       | Medio   | Añadir filtro `not m.scrapped` y verificar que `origin_returned_move_id` no esté presente si se quiere excluir devoluciones |
| R-03  | `move_line_ids` puede no estar cargado en `_prepare_invoice_line` (lazy loading) | Baja | Bajo   | El acceso ORM carga automáticamente los registros relacionados. Sin problema si no se usa `sudo()` en un contexto de baja seguridad |
| R-04  | Módulo `sale_stock` tiene un `_prepare_invoice_line` propio que también modifica `vals` | Media | Bajo | El `super()` garantiza que la cadena se ejecuta correctamente. Revisar orden de herencia si hay otro módulo que también overridea este método |
| R-05  | Valor de `numero_lotes` queda obsoleto si se edita el albarán tras facturar | Baja | Bajo   | Documentado en README: el campo es informativo y no se recalcula automáticamente. Para actualizar, regenerar la factura |

---

## Checklist de aceptación técnica

Basado en los criterios de `docs/test-cases.md`:

- [ ] El campo `numero_lotes` en `account.move.line` **no tiene** `@api.depends` (no recalcula — se inyecta al crear)
- [ ] Si el producto no tiene lote (`tracking == 'none'`), el campo queda vacío **sin error**
- [ ] Funciona con facturas parciales: solo lotes del albarán ya realizado (`state='done'`)
- [ ] La columna en la factura tiene `optional="show"`
- [ ] El módulo depende de `sale_stock` (no de `sale+stock+account` por separado)
- [ ] `_prepare_invoice_line` llama a `super()` antes de añadir `numero_lotes`
- [ ] Sin duplicados en la lista de lotes (mismo lote referenciado en múltiples `move_line_ids`)
- [ ] El módulo no modifica ningún archivo estándar — solo usa `_inherit`

---

## Complejidad: Media

**Justificación:**

| Elemento                  | Cantidad |
|---------------------------|:--------:|
| Modelos extendidos        | 2        |
| Campos nuevos             | 1        |
| Overrides de método       | 1        |
| Archivos de vista XML     | 1        |
| Grupos de seguridad nuevos | 0       |
| Modelos nuevos            | 0        |

La complejidad viene de la **cadena de trazabilidad** entre 3 módulos y del razonamiento sobre facturas parciales, no de la cantidad de código. El código es pequeño (~30 líneas Python) pero requiere entender el flujo `sale_stock` para hacer el override en el lugar correcto.

**Estimación:** 0.5 días de desarrollo + 0.5 días de pruebas con distintos escenarios de lote.
