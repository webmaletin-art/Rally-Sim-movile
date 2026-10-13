# Región de Dream City (mundo abierto ampliado)

Alrededor de Dream City hay una región enorme de rutas (~2.700 km), pensada para el modo ruta y las misiones del mundo abierto (que es el mismo del online).
Es el **mismo mundo**: se maneja sin cortes desde la plaza hasta la costa, la sierra o la quebrada del norte.

## Qué hay
- **Circunvalación** AU-1 (radio 3,3 km) unida a las salidas de la ciudad, y las autopistas costeras hacia Puerto Alba y Bahía Ámbar.
- **8 ciudades, 25 pueblos y ~60 villas** (de 4–5 cuadras con casas bajas tipo Villa Aurora). Cada pueblo tiene **cerco bajo a los costados**: ahí está la pared invisible, pegada a las casas (`RegionData.TOWN_WALL`).
- **Autopistas (AU), rutas nacionales (RN), provinciales y caminos (RP), tierra, montaña (abismos, curvas cerradas, subidas y bajadas) y calles**; asfalto, ripio y tierra, anchas y angostas. Todas conectadas: sin callejones sin salida, con cruces limpios.
- **Curvas con carácter**: cada ruta se genera «recta», «suave», «curva» o «sinuosa» (`network.meander`); las autopistas son las más largas y rectas, los caminos y la montaña, los más sinuosos.
- **5 secretos** en villas (`secret_sites`): un monumento al final de una calle lateral; pasar a menos de 22 m lo descubre una sola vez (historia local o un coleccionista que paga $2500 por un auto abandonado, más fama). Los peajes de montaña, de cobro más caro, también son secretos.
- Estaciones de servicio, gomerías, **peajes** (más caros donde hay algo secreto), carteles «a tantos km», paraje de la Aventura (la salida 20 de la ciudad lleva al comienzo del modo Aventura).
- **GPS compuesto** (`world_gps.gd`): sigue al auto en tiempo real, da distancia y tiempo estimado con la velocidad real (piso 14 m/s), y arma la ruta pasando por las salidas de la ciudad.
- **Mapa grande** con la vista general de la región (`region_map.png`) y botón «REFERENCIAS» que oculta lugares y marcas (se guarda en `mapRefs`).
- **Aparecer**: en «¿DÓNDE APARECER?» se elige un pueblo con un mapa que marca el lugar (`menu_world.gd`, `spawns.json`).

## Cómo está armado
- Generador offline (Python, determinista): `tools/world_gen/` → `build_region.py` escribe `godot/game/data/region/region_1.bin` (+ `region_map.png`, `spawns.json`).
  - `terrain.py`: relieve (llanura, sierra al oeste, montañas al norte, mar al sur) que empalma exacto con el de la ciudad.
  - `network.py`: A* con pendiente máxima, atajos, curvas con radio mínimo por clase, meandros.
  - `topo.py`: cruces, villas, calles de pueblos, perfil de alturas, servicios, peajes, carteles.
- Juego: `game/region/` (`region_data.gd` datos y paredes, `region_world.gd` mundo por cuadrados de 256 m armados en hilos con 3 niveles de detalle, `region_services.gd` servicios inyectados a la ciudad).
- Más allá de 2,25 km de la plaza `CityLayout.height()` usa el relieve de la región. Los túneles y estacionamientos se mudaron a x = 75.000 (`POCKET_X0`). `WORLD_VERSION = 6`.
- Pruebas: `region_test` (datos, rutas, alturas), `region_drive_test` (un auto automático recorre circunvalación, autopista y montaña con la física real), `region_perf_test` (tiempos por cuadrado), `spawn_menu_test`.

## Estaciones, gomerías y lugares para aparecer: acceso a la calle (`region_services.gd`)
Las estaciones (110 entre estaciones y gomerías) se anotaron en el generador sobre el **eje recto** de cada pueblo, no sobre el camino de verdad: unas quedaban encima de una ruta (9) y casi todas
separadas de la banquina por pasto (de 0,1 a 45 m) y rodeadas de pared invisible, así que aparecer ahí te dejaba encerrado (sólo 4 de los 33 lugares para aparecer tenían salida). Ahora, al armar la pista (`RegionServices.install`):
- Si el playón **pisa una calle** se lo corre hacia el lado contrario hasta dejar 3 m de la banquina (`_clear_of_roads`); se actualizan `poi.x/z/h`, el GPS y el lugar para aparecer.
- Cada playón tiene un **camino de acceso** de 10 m de ancho hecho de discos de pavimento que se pisan (`_driveway`, `DRIVE_R` 5 m cada 3 m) desde adentro del playón hasta el borde del asfalto de la calle más cercana
  (en los pueblos de ruta cortada es un camino de hasta ~70 m hasta el final de la calle del pueblo). El playón queda a la altura de la calle donde empalma.
- Se **aparece mirando hacia la salida** (el rumbo del acceso), 3 m adelante del centro de la estación.
- **La pared invisible es la unión de los corredores** (`RegionData.corridor()`): un auto cabe si cabe en el corredor de alguna calle (calzada + banquina + 9 m; 3,2 en pueblos; 2,6 en montaña) **o** de algún playón (radio + 0,3 m); sólo se lo empuja si se sale de todos
  (antes sólo valía el de mayor holgura y un playón que no se cruzaba con la banquina por unos centímetros te encerraba). En `CityTrack._push_locked` pasa igual entre el corredor de la ciudad y los de la región: antes la pared de la región empujaba también
  **adentro** de la calle de la ciudad entre los 2,25 km y el empalme (la punta de las rutas 20, 40 y 80): ahí se trababa el auto o no podía dar marcha atrás.
- Los **árboles de la región** (`RegionWorld._trees`) no caen sobre las rutas de la ciudad que cruzan la región ni a menos de 14 m de su banquina (`CityLayout.verge_clearance`): había árboles en el medio de la Ruta 40.
- Prueba: `tests/open_world_access_test.gd` (CI): desde el frente de cada estación y gomería, y desde cada uno de los 33 lugares para aparecer, se llega a una calle por donde pasa un auto; las estaciones de la ciudad también; un auto automático sale solo de tres lugares y de la ciudad por las rutas 20, 40 y 80; la calzada de las rutas rurales, atajos y panorámica no tiene nada que frene; ningún árbol cae sobre ellas.

## Pendiente
- Misiones (paquetes, buscar personas), regalar un auto de verdad en los secretos (hoy pagan créditos), tránsito en las rutas, nafta/taller en cada estación (el flujo anda, falta probarlo con calma), textos nuevos sólo en español.
- Autos de otros jugadores (online) en la región: cerrado hasta el tiempo real.
