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

## Cruces parejos, subidas y rutas paralelas (`tools/world_gen/fix_heights.py`, `add_connectors.py`)
El dueño probó el APK y vio: autos que **saltan en los cruces**, subidas mal hechas y rutas paralelas sin conexión. Mediciones sobre el mapa generado: 242 cruces tenían escalones de hasta 18 m a pocos metros del nodo
(cada ruta llevaba la altura de su propio terreno y se juntaban a distinta altura) y pendientes de más del 30 % pegadas a los nodos. Ahora:
- **Alturas nuevas** (`fix_heights.py`, se corre solo al final de `build_region.py` y es idempotente): la altura de cada nodo se relaja bajo la pendiente máxima de las rutas que llegan; cada cruce tiene un **playón plano** (el disco del cruce a una sola altura);
  el perfil de cada ruta sigue el terreno pero limitado por una envolvente de pendiente máxima por clase (anillo 5 %, autopista 5,5 %, ruta 7 %, provincial 8,5 %, camino 10 %, tierra 11 %, montaña 11,5 %, calle 8 %, conector 7 %) y con las crestas y hondonadas redondeadas (saltos de curvatura limitados).
- **Rutas paralelas** (`add_connectors.py`, parche sobre `region_1.bin` que no regenera el mapa; `binio.py` lee y escribe el archivo): detecta tramos de 450 m o más a menos de 260 m uno del otro sin forma de pasar de uno al otro (la red tarda más de 2,5 km o 6 veces la separación),
  parte las dos rutas en un nodo nuevo (cruce) y las une con un **empalme** recto (clase «conector», 9,5 m) casi perpendicular a las dos, lejos de pueblos y de otras rutas, con uno cada ~1–2 km a lo largo de un tramo largo (31 empalmes; quedan 5 tramos paralelos de montaña con curvas encadenadas donde un empalme recto cruzaría otra ruta). Después rehace las alturas.
  `build_region.py` corre los dos al final (alturas y después empalmes), así que el mapa se puede regenerar igual.
- **Pared invisible en los cruces** (`RegionData._build_junction_discs`): en un cruce de 3 o más calles fuera de los pueblos la pared es la unión de las calles **y un círculo** (medio ancho + 18 m) alrededor del nodo: un auto que dobla a 55 km/h en una curva cerrada de montaña (pared pegada a 2,6 m del guardarraíl) cortaba la esquina y raspaba una pared que no se ve.
- Pruebas (CI): `region_junction_test` (pendientes por clase, altura de las rutas a 3–12 m del nodo, sin escalones de más de 15 cm caminando por el centro del cruce en 466 cruces) y `region_connectors_test` (cada empalme une sus dos rutas en el router y un auto maneja 9 de ellos de punta a punta sin parar ni rozar la pared).

## Terreno, calles y objetos sobre la ruta (`region_world.gd`)
El dueño vio **tierra y pasto sobre el asfalto**, cercos y casas sobre las calles, y que las estaciones se atravesaban. Se midió (`region_terrain_test`) y se arregló:
- **El terreno no tapa la calzada** (`_road_caps`): la malla es una grilla de triángulos de 8, 16 o 32 m y una ruta de 7 m sobre una ladera no cabe en una grilla así: entre un vértice sobre la calzada y otro más alto afuera, la malla pasaba por encima del asfalto
  (en el 0,8 % de los puntos de la calzada en el nivel cercano, 1,8 % en el medio y 3,8 % en el lejano, hasta 7 m de tierra encima). Ahora, para cada punto de la calzada y de la banquina (cada 1,5 m), se calcula la altura de la malla ahí (combinación de los 3 vértices del triángulo)
  y, si queda por encima del camino, se baja el «nivel de corte» de los vértices más altos del triángulo (los de abajo no se tocan) hasta que la malla pase por debajo. También los playones de las estaciones y los discos de los cruces. Los puntos salen sólo de la geometría y la grilla lleva un anillo de más: el cuadrado vecino llega a los mismos valores en los bordes (sin escalones).
  En las laderas la ruta queda como cortada en el cerro (con la barranca a un lado). Costo: igual que antes (los tiempos de armado de cada cuadrado no cambiaron).
- **Capas**: la banquina queda 5 cm más abajo y el asfalto 2 cm más arriba que los caminos de tierra y ripio (`_road_off`): ya no se ven tiras de tierra cruzando el asfalto en los cruces. Las rayas de una calle que termina contra otra se cortan en la boca del cruce (`_is_through`).
- **Guardarraíles** (`_rail_clear`) no se arman donde otra calle pasa por encima de ese costado. **Cercos** de los pueblos: las dos puntas del tramo de 6 m tienen que seguir a la misma calle. **Casas**: las cuatro esquinas tienen que quedar a más de 1,5 m de toda calzada.
  (Había 113 vértices de casas y cercos adentro de calzadas en los cuadrados de pueblos revisados; ahora 0.) **Árboles**: tampoco dentro de ningún corredor (playones y círculos de los cruces).
- **Estaciones, gomerías y peajes con colisión**: los surtidores (0,9 m), columnas (1 m) y bloques del kiosco (3 m) de las estaciones de la región, las paredes del galpón de cada gomería (círculos de 1,7 m pegados) y la cabina y los postes de cada peaje son objetos sólidos
  (`_station_props`, `_shop_solids`, `_toll_solids`: ids desde 40.000.000 en `CityTrack.add_prop`, no se rompen; se sacan al borrar el cuadrado). Antes sólo chocaban los de las estaciones de la ciudad (los pone `CityWorld` al armar cada cuadra, que más allá de 3,75 km no arma nada) y el auto atravesaba todas las de la región.
  Los surtidores ahora se dibujan (antes sólo el techo y el kiosco).
- Pruebas (CI): `region_terrain_test` (el terreno no pasa por encima de la calzada en los tres niveles, los bordes de cuadrados vecinos coinciden, ni casas, cercos ni guardarraíles sobre una calzada) y `open_world_access_test` (los 33 lugares para aparecer salen a la calle con un auto de verdad, todos los surtidores, columnas, bloques, galpones y cabinas chocan y desde cada estación y gomería se sigue llegando a la calle).

## Pendiente
- Misiones (paquetes, buscar personas), regalar un auto de verdad en los secretos (hoy pagan créditos), tránsito en las rutas, nafta/taller en cada estación (el flujo anda, falta probarlo con calma), textos nuevos sólo en español.
- Autos de otros jugadores (online) en la región: cerrado hasta el tiempo real.
