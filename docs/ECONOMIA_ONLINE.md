# Economía online (autoritativa) — Etapas 3, 13, 18 y 19

El progreso **offline** y el **online** son separados. Comparten el catálogo base (autos, mejoras, gomas, piezas) pero cada auto online es una **instancia** (`instance_id`, uuid) con su propia pintura, mejoras, gomas, desgaste y piezas. Los créditos online viven en el **servidor**.

## Qué guarda el servidor
Migración: `supabase/migrations/20261007010000_online_economy.sql` (aditiva: no borra nada; se puede repetir).

| Tabla | Contenido |
|---|---|
| `online_cat_*` | catálogo contra el que se valida todo (autos, mejoras, gomas, piezas con su compatibilidad por auto, locales con posición, acabados). Se genera de `godot/game/data/*.json` con `tools/online/export_catalog.gd` + `gen_economy_sql.py` |
| `online_wallets` | créditos online (empieza con 25 000) y regalo diario |
| `online_vehicles` | una fila por auto: dueño, modelo, mejoras, gomas y desgaste, pintura, piezas, mods, km, estado (`garage`/`listed`) |
| `market_listings.instance_id` | cada venta apunta a una instancia real |
| `presence.instance_id` | el auto con el que está cada jugador |

Todas las tablas tienen RLS **sin políticas**: el teléfono no escribe directo. Sólo hay funciones `SECURITY DEFINER`:
`online_state`, `online_daily`, `online_buy_vehicle`, `online_buy_upgrade`, `online_buy_tires`, `online_replace_tires`, `online_set_paint`, `online_buy_part`, `online_remove_part`, `online_report_drive`, `market_list_instance`, `market_buy_instance`, `market_cancel`, `presence_beat` (con `p_instance`), `presence_list_v`.

## Qué valida el servidor
* **Dueño** del auto (`instance_id`) y que no esté en venta.
* **Catálogo**: auto, mejora, gomas, pieza, acabado; **compatibilidad** pieza↔auto; **niveles** de a uno (sin saltear); precios del catálogo (el teléfono no manda precios).
* **Local**: los trabajos de taller exigen que el jugador esté en ese local (su última posición de presencia, de hace < 2 min, dentro del radio del local) y que el local sea el que hace ese trabajo (motor, ruedas, pintura…).
* **Saldo** (`credits >= precio`, atómico) y **límite por hora** de acciones (anti-abuso). Garage máximo 12 autos; máximo 5 ventas abiertas.
* **Pintura**: sólo claves conocidas, colores `#rrggbb`, acabado del catálogo; nada de JSON arbitrario.
* **Mercado**: el servidor traspasa la instancia, cobra al comprador y paga al vendedor **en el momento** (menos 5 % de comisión). No se crean créditos: la comisión es lo único que sale del sistema. Las funciones viejas (`market_list/buy/collect`, que aceptaban un estado arbitrario del teléfono y «acreditaban» créditos de palabra) ahora **rechazan** y las ventas viejas abiertas se cancelan.
* **Autos premium (camión, GT3, hiper) y de premio (Genesis)**: no se compran con créditos online (se desbloquean con compras de Google Play / la aventura, que se validan del lado del dispositivo).
* **Desgaste de gomas** (`online_report_drive`): el teléfono informa km, segundos y exigencia; el servidor lo limita a lo físicamente posible (≤ 120 m/s, ≤ el tiempo real transcurrido) y calcula el desgaste.
* **Presencia**: los demás ven el modelo, pintura, gomas y piezas que **el servidor** sabe que tiene ese jugador (`presence_list_v`), no lo que diga el otro teléfono.

## Cómo se usa desde el juego
* `online/online_economy.gd`: llamadas al servidor y estado (`credits`, `vehicles`).
* `data/online_profile.gd`: perfil online con **el mismo interfaz** que el offline (así el garaje y los talleres de Dream City funcionan igual). Muestra un espejo del servidor; cada cambio de la interfaz se aplica al instante y al guardar se compara con lo último que confirmó el servidor y se manda la acción que corresponde. Si el servidor rechaza algo, el espejo vuelve a lo que dice el servidor y se avisa. Ajustes, nombre y estadísticas se comparten; autos, créditos, nafta, fama y posición del mundo online van aparte (`profile.d["online"]`).
* `app.gd`: `enter_online()` trae el estado al entrar al mundo online (si no hay conexión **no se entra**: no se mezcla con el offline). Al entrar a un taller desde el mundo online, el menú usa el perfil online; el servidor recibe la posición del auto antes de cada trabajo.
* Modo online → hub: **créditos online** y **regalo diario** (2000 cada 20 h; es la única fuente de créditos online además del mercado entre jugadores).
* Mercado: vender / comprar / retirar por instancia (`online_social.gd`).

## Límites actuales (a propósito)
* Los premios de carreras, actividades del mundo, nafta y peajes **no** crean ni cobran créditos online todavía (el servidor no valida esos resultados): online son gratis/no pagan. Se suman cuando el servidor valide resultados.
* La posición que usa el servidor para «estar en el local» la informa el teléfono (no hay física compartida): impide comprar desde el menú o desde el otro lado del mapa, pero no es a prueba de un cliente modificado.
* En la pantalla del garaje se muestra **un auto por modelo**; si por el mercado llegaran dos del mismo modelo, se ve el primero (el cliente bloquea comprar un modelo que ya tenés).
* El ajuste fino (presiones, alineación…) es local y gratis online.
* Los autos de los otros jugadores se dibujan con su **modelo real** sólo los 3 más cercanos (a < 80 m); el resto, de papel con el color de su pintura.

## Pruebas
* `tools/online/run_economy_test.sh` (Postgres local) o el flujo **Economía online · prueba SQL**: aplica todas las migraciones, las repite, y corre ~45 comprobaciones (compras fuera del local, saltear niveles, auto ajeno, pintura inválida, doble compra, comisión, abuso…).
* `godot/tests/online_profile_test.gd` (servidor simulado) y `remote_cars_test.gd`.
