# Región de Dream City (mundo abierto ampliado)

Alrededor de Dream City hay una región enorme de rutas (~2.700 km), pensada para el modo ruta y las misiones del mundo abierto (que es el mismo del online).
Es el **mismo mundo**: se maneja sin cortes desde la plaza hasta la costa, la sierra o la quebrada del norte.

## Qué hay
- **Circunvalación** AU-1 (radio 3,3 km) unida a las salidas de la ciudad, y las autopistas costeras hacia Puerto Alba y Bahía Ámbar.
- **8 ciudades, 25 pueblos y ~60 villas** (de 4–5 cuadras con casas bajas tipo Villa Aurora). Cada pueblo tiene **cerco bajo a los costados**: ahí está la pared invisible, pegada a las casas (`RegionData.TOWN_WALL`).
- **Autopistas (AU), rutas nacionales (RN), provinciales y caminos (RP), tierra, montaña (abismos, curvas cerradas, subidas y bajadas) y calles**; asfalto, ripio y tierra, anchas y angostas. Todas conectadas: sin callejones sin salida, con cruces limpios.
- **Curvas con carácter**: cada ruta se genera «recta», «suave», «curva» o «sinuosa» (`network.meander`); las autopistas son las más largas y rectas, los caminos y la montaña, los más sinuosos.
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

## Pendiente
- Misiones (paquetes, buscar personas), secretos/lore de los pueblos (los datos están en `secrets`; falta el juego), tránsito en las rutas, nafta/taller en cada estación (el flujo anda, falta probarlo con calma), textos nuevos sólo en español.
- Autos de otros jugadores (online) en la región: cerrado hasta el tiempo real.
