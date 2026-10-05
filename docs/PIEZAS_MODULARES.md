# Personalización modular de piezas

**Idea:** una pieza se registra UNA vez y sirve para varios autos. Nada de `Genesis_spoiler_01.glb`, `Hatch_spoiler_01.glb`… El auto define dónde se monta (a partir de sus medidas) y la pieza dice cómo se adapta.

## Piezas del sistema (`godot/game/car/`)
| Archivo | Rol |
|---|---|
| `data/parts.json` | **Catálogo**: categorías (`wheel`, `front_bumper`, `rear_bumper`, `spoiler`, `hood`, `side_skirt`) y piezas |
| `part_catalog.gd` | Lee el catálogo una vez; `part(id)`, `parts_in(cat)`, `rule_compatible()`, `validate()` (para registrar piezas nuevas) |
| `vehicle_mounts.gd` | **Puntos de montaje** de cada auto, calculados de `models/cars/<id>.json` + física (largo, alto, semiancho, ejes, radio). Excepciones sólo en `data/vehicle_mounts.json`. `fit()` calcula escala/desplazamiento/rotación |
| `vehicle_customization.gd` | Configuración instalada (`state["mods"]`), `install/remove/sanitize`, `wheel_override`, `attach` (cuelga los nodos del cuerpo) |
| `car_parts.gd` / `car_visual.gd` / `car.gd` | Aceptan `mods`: una llanta instalada cambia el estilo y el tamaño de las ruedas; el resto de las piezas se cuelga del cuerpo |

## Una pieza en el catálogo
```json
"spoiler_gt_01": {
  "category": "spoiler", "name": "Alerón GT",
  "source": {"type": "glb", "path": "res://game/models/parts/spoiler_gt_01.glb"},   // o {"type":"rim","style":"..."} para llantas
  "base": {"scale": 1.0, "offset": [0, 0, 0], "rot": [0, 0, 0]},                  // pivote/orientación del modelo
  "fit":  {"mode": "width", "ref": 1.2, "ratio": 0.8, "min": 0.8, "max": 1.6},    // escala PROPORCIONAL: ancho del modelo → 80 % del ancho del auto
  "compat": {"vehicles": ["*"], "exclude": ["truck"]},
  "fit_overrides": {"hatch": {"offset": [0, 0.05, 0]}},                           // sólo si hace falta (por auto)
  "variants": [], "price": 2500, "shop": "paint", "tier": 1
}
```
- **No deforma:** sólo escala proporcional dentro de `[min, max]`; si no entra, el auto queda **incompatible** con esa pieza (`fit().ok == false`).
- **Modos de ajuste:** `none`, `width`, `length`, `height`, `wheel` (radio de la llanta).
- **Espejo:** los faldones usan un montaje izquierdo y otro derecho (el izquierdo se espeja).
- **Modelo (GLB/OBJ):** con el pivote en el punto de montaje, +z hacia adelante, +y arriba, unidades en metros. Se ajusta con `base`.
- Los autos sin carrocería propia (Genesis y T1+, que usan la del Volt) **todavía no admiten piezas** (`supports()`); queda para cuando tengan su GLB.

## Guardado
`state["mods"] = {"wheel": {"id": "rim_dish8", "v": 0}, "spoiler": {"id": "...", "v": 0}}` dentro del estado del auto (`profile.json`). Al cargar siempre pasa por `sanitize()`: lo que ya no existe o no entra se descarta. **El mismo formato lo usarán las instancias de auto online** (offline y online separados; ahí lo valida el servidor).

## Prueba corta
`godot --headless --script res://tests/parts_test.gd` (catálogo, montajes en los 9 autos, adaptación al ancho, incompatibilidad, instalar/guardar/cargar, llantas, nodos espejados). Corre en CI. Las piezas `dev_*` (ocultas) sirven para ver los montajes sin modelos reales.
