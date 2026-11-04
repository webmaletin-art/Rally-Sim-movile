# Informe de productos de compras de Dream Racing (para revisar ANTES de crearlos en Play Console)

Fecha: 04/11/2026 · Paquete `com.srg.dreamracing`. Fuente de los datos: `tools/play/game.json` (IDs, tipo y precio) y `godot/game/store/products.gd` (nombre y monedas). **No se creó nada en Play Console.**

## Estado real en Google Play (consulta de sólo lectura, flujo «Play · Productos», 04/11/2026)
Google Play devuelve **0 productos** para `com.srg.dreamracing`: los 10 faltan. Por eso «No se pudo iniciar la compra»: no hay nada que comprar.

## Los 10 productos (IDs EXACTOS; no se cambia ninguno)
| # | ID | Tipo | Nombre en el juego | Qué da | Precio base (USD) |
|---|---|---|---|---|---|
| 1 | `dr_full` | No consumible (se compra una vez) | Juego completo | Aventura de 12 etapas, todas las copas y los 3 autos premium | 9,99 |
| 2 | `dr_adventure` | No consumible | Aventura completa | Las 12 etapas (5 gratis) y las copas Continental y Leyenda | 4,99 |
| 3 | `dr_garage` | No consumible | Garaje premium | Mamut 6x6, GT3 RS y Aerion | 6,99 |
| 4 | `car_truck` | No consumible | Colossus Mamut 6x6 | El camión de rally | 1,99 |
| 5 | `car_gt3` | No consumible | Altair GT3 RS | Auto de carreras | 2,99 |
| 6 | `car_hyper` | No consumible | Vortex Aerion | Hypercar híbrido | 3,99 |
| 7 | `dr_coins_s` | **Consumible** (se puede comprar muchas veces) | Puñado de monedas | $ 5.000 del juego | 0,99 |
| 8 | `dr_coins_m` | Consumible | Bolsa de monedas | $ 12.000 | 1,99 |
| 9 | `dr_coins_l` | Consumible | Cofre de monedas | $ 30.000 | 3,99 |
| 10 | `dr_coins_xl` | Consumible | Baúl de monedas | $ 80.000 | 7,99 |

Los precios son los de `game.json` (que coinciden con `docs/PLAY_STORE.md`). **No se modifican.** Google convierte el precio base USD a las otras monedas; las conversiones por país las propone Play Console y se pueden revisar ahí.

## Cómo se crearían (cuando el dueño lo autorice)
- Cada producto: ID exacto, nombre y descripción (es-419 como idioma base; el juego muestra el precio que devuelve Google), tipo según la tabla, estado **Activo**, precio base de la tabla.
- Los consumibles (`dr_coins_*`) deben quedar como **consumibles**: el juego los consume después de que el servidor verifique el recibo (`verify-purchase`); si se crearan como no consumibles no se podrían volver a comprar.
- Requisitos que no dependen del código: perfil de pagos de comerciante completo, y probadores con licencia (Configuración → Pruebas de licencia) agregados a la pista interna; instalar desde el enlace de la prueba, no por APK.

## Qué NO se hace
Sin desbloqueos simulados, sin acreditar monedas sin el recibo de Google, sin cambiar IDs ni precios. El servidor sigue verificando cada compra con Google (`supabase/functions/verify-purchase`).
