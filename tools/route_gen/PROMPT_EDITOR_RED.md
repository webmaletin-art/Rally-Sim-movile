# PROMPT PARA DEEPSEEK — «Editor de RED de rutas» (Dream Racing)

> Copiá todo lo que está debajo de la línea y pegáselo a DeepSeek. Te va a devolver UN solo archivo `editor_red.html`.
> Cuando lo tengas: lo abrís en el navegador del teléfono, trazás tu red, tocás «EXPORTAR» y me mandás el `.json`.
> (Esto reemplaza a los editores anteriores —`PROMPT_DEEPSEEK.md` y `PROMPT_EDITOR_V3.md`—: ésos eran de UN solo camino; éste es una RED de caminos con cruces, T, rotondas y salidas.)

---

Quiero que programes **un único archivo `editor_red.html`** (HTML + CSS + JavaScript puro, sin librerías ni CDN, funciona sin internet, sin build) que sea un **editor 2D de redes de rutas para un juego de autos** (visto desde arriba, con la grilla de trazado). No tiene visor 3D: es solo un plano donde dibujo con el dedo (o el mouse) y exporto un `.json` que después lee mi juego, que se encarga de decorar todo (árboles, vegetación, guardarraíles, banquinas, edificios, cartelería). **Todo el texto de la interfaz va en español rioplatense.**

El editor se usa **sobre todo en el teléfono (táctil)**: botones grandes (mínimo 44 px), nada de hover, nada de clic derecho, nada de teclas obligatorias (los atajos de teclado son un extra para la computadora). Tiene que andar fluido con una red de hasta **1000 km** de calles.

## 1. Qué tiene que poder hacer (lo más importante: SIN LÍMITES)

1. **Trazar con el dedo, a mano alzada.** Apoyo el dedo y arrastro: se dibuja una línea. **Levanto el dedo = termina ese tramo.** Puedo empezar otro tramo donde quiera, cambiar el tipo de superficie, el ancho o el entorno entre un trazo y otro, y seguir. Cada trazo se suaviza solo (filtro de ruido + simplificación Ramer-Douglas-Peucker + curva suave tipo Catmull-Rom/Chaikin) para que no quede «temblorosa», pero **NO se limita nada**: ni el ángulo de las curvas, ni la cantidad de curvas, ni el largo, ni la cantidad de trazos, ni la cantidad de cruces. Curvas cerradísimas, horquillas, rulos, ochos, espirales: todo se puede. Si una curva es demasiado cerrada para un auto, solo **avisa** (marca en naranja y lo lista en «Revisar»), pero **nunca la bloquea ni la corrige sola**.
2. **Intersecciones, cruces en T, en Cruz (+), en Y, de varias bocas, y rotondas**, sin límite y en cualquier ángulo (incluso rasantes de 5°). Ver sección 4.
3. **Salidas en cualquier dirección**: puedo arrancar un trazo nuevo desde cualquier punto de cualquier calle ya dibujada y sale para donde yo quiera (se arma una T automáticamente).
4. **Unión automática (se «pegan solos»)**: si termino un trazo cerca (imán de ~14 px en pantalla) del extremo libre de otro, de un nodo o de cualquier punto de otra calle, **se conecta solo** (mostrar un imán/círculo verde antes de soltar). Si empiezo un trazo cerca de un extremo libre, **continúa esa calle con la tangente alineada** (la primera parte del trazo nuevo se mezcla suavemente con la dirección con la que terminaba la anterior, para que no queden «desfasadas» ni con un escalón). Si cambia el ancho entre una y otra, se hace una **transición gradual de 30 m**. Esto vale también al pasar de asfalto a tierra, de zona urbana a rural, etc.: el camino «continúa» solo, sin que yo tenga que arreglar nada a mano.
5. **Cambiar el tipo en medio de una calle ya dibujada**: herramienta «Tramo» (ver 3): marco un tramo de una calle (dos toques sobre ella) y le cambio superficie/ancho/entorno; el editor parte la calle ahí con **nodos de transición** automáticos.
6. **Rutas largas**: de norte a sur, de 600 km o 1000 km o más, sin tope. Todo el mundo en coordenadas `float64` de JavaScript (metros). Zoom continuo desde **1 píxel = 5 cm** hasta **1 píxel = 2 km** (que entren más de 1000 km en la pantalla).
7. **Zoom con pellizco (dos dedos) y arrastre con dos dedos** para mover la vista; en la compu rueda del mouse y arrastre con botón del medio o con la herramienta «Mano». **Con un dedo dibujo, con dos dedos muevo/zoomeo** (en cuanto aparece un segundo dedo se cancela el trazo en curso sin guardarlo).
8. **La grilla y la escala siempre dicen la distancia real**: grilla adaptativa (10 m, 50 m, 100 m, 500 m, 1 km, 5 km, 10 km, 50 km, 100 km, según el zoom) con etiquetas («500 m», «2 km»…), **barra de escala** abajo a la izquierda («━━━ 5 km») que cambia al hacer zoom, y los ejes con orientación: **arriba = Norte** (una flecha N siempre visible). Herramienta **«Medir»**: toco dos puntos (o varios) y me da la distancia en m/km, en línea recta y siguiendo la ruta si los puntos están sobre calles. Indicador fijo de **largo total de la red en km**, separado por tipo de superficie y por ancho.
9. **Deshacer / rehacer ilimitado** (botones grandes ↶ ↷). Borrar un trazo entero (herramienta «Borrar»: toco una calle y se borra el tramo entre nodos; mantener = borra toda la calle), mover un nodo, arrastrar un punto de control para curvar distinto, seleccionar y cambiar atributos de cualquier calle/nodo/estación/zona.
10. **Autoguardado** continuo en `localStorage`/IndexedDB (si falla, que no rompa nada), y botones **IMPORTAR .json** (para seguir editando algo que ya exporté) y **EXPORTAR .json** (descarga con `Blob`; nombre `<id>.json`). Al abrir, preguntar si continuar el último trabajo guardado.

## 2. Pantalla y herramientas (táctil, mobile-first)

Pantalla completa: el mapa ocupa todo; barra superior fina (nombre del mapa, largo total km, botón ☰ menú); **barra de herramientas** abajo/lateral (que se pueda deslizar si no entra) con íconos grandes + texto corto:

`✏️ Trazar` · `✋ Mano` · `👆 Elegir` · `✂️ Tramo` · `⭕ Rotonda` · `⛽ Estación` · `🏙️ Zona` · `🏁 Largada/Meta` · `📏 Medir` · `🗑️ Borrar` · `↶ ↷` · `🔍 Revisar` · `⬇ Exportar`

Panel de propiedades que sube desde abajo (bottom sheet) con lo que corresponde a la herramienta o a lo elegido. En **Trazar**, siempre visibles y a un toque:

- **Superficie** (chips de color): `Asfalto` (gris oscuro con línea central blanca discontinua) · `Tierra` (marrón claro) · `Ripio/Grava` (beige) · `Barro` (marrón oscuro) · `Arena` (amarillo).
- **Ancho** (3 opciones, exactamente éstas):
  - `Angosta` → **6 m**
  - `Normal` → **9 m**
  - `Autopista` → **18 m** (el doble de la normal; se dibuja con línea central doble y/o un divisor, calzada visualmente el doble de ancha)
- **Entorno** (qué rodea a la calle; lo usa el juego para decorar): `Rural` · `Bosque` · `Desierto` · `Periurbano` · `Urbano`.
- Opcional, en «Más…»: **Altura** (ver sección 6) y **Velocidad sugerida** (solo una etiqueta numérica, la usa la IA).

La calle se dibuja en el editor **a escala real**: el ancho en metros se ve proporcional al zoom (a zoom lejano mínimo 2 px para que se vea siempre). Bordes y color según superficie. Las calles de autopista, más anchas. Mostrar los nodos solo si hay zoom suficiente (si no, ensucia).

## 3. Modelo de datos interno (para que todo sea consistente)

Es un **grafo**:

- **Nodo** `{id, x, z, y, kind}`: `kind` ∈ `end` (extremo libre/ciego), `junction` (intersección de 3+ calles), `transition` (grado 2, donde cambia superficie/ancho/entorno), `roundabout_port`.
- **Calle (edge)** `{id, a, b, pts, surface, width, env, speed?, name?}`: va del nodo `a` al nodo `b`; `pts` es la polilínea suavizada **incluyendo los dos extremos** (que coinciden exactamente con la posición de los nodos), en metros `[x, z]`. El editor **siempre mantiene el grafo partido en los nodos**: cuando un trazo nuevo cruza o toca otra calle, ambas se parten ahí y se crea un nodo `junction`. No hay calles solapadas: si dibujo paralelo y pegadísimo a otra, igual lo respeto (son dos calles) y lo marco en «Revisar» como «se pisan en paralelo».
- Coordenadas: **x hacia el Este, z hacia el Sur** (como en pantalla: abajo = z crece, arriba = Norte). Unidades: **metros**. Origen (0,0) = donde empiezo a dibujar (o el centro que elija). Redondear al **decímetro** al exportar.
- Espaciado de puntos al exportar: **entre 4 y 40 m** (más juntos en curvas cerradas, más separados en rectas; una recta larga puede tener un punto cada 40 m). El juego vuelve a suavizar con Catmull-Rom, así que no hace falta más.

**Rendimiento (obligatorio, hasta 1000 km y 60 000 puntos):** índice espacial (grilla uniforme, por ejemplo celdas de 1 km con listas de segmentos) para detectar cruces, imán y selección; dibujar **solo lo visible** (recorte por viewport); a zoom lejano simplificar polilíneas (un punto cada ≥ 2 px); repintar con `requestAnimationFrame` solo cuando algo cambió; detección de cruces solo contra segmentos cercanos al trazo nuevo; mantener 30+ fps en un teléfono de gama media. Nada de crear miles de elementos DOM: todo en un `<canvas>` (más un segundo canvas para la grilla/overlay si ayuda).

## 4. Intersecciones, cruces y rotondas (lo más delicado)

**Detección automática** al levantar el dedo: busco todos los puntos donde el trazo nuevo cruza otras calles (o a sí mismo), y todos los lugares donde su inicio/fin cae cerca (imán) de otra calle o de un nodo. En cada uno:

- Si el trazo **termina o empieza sobre otra calle** → **T** (nodo de 3 bocas).
- Si **cruza de lado a lado** → **Cruz (+)** (nodo de 4 bocas). Con 5 o más bocas (varias salidas en el mismo punto, ej. una estrella) → nodo de N bocas. Todo en cualquier ángulo.
- Si el trazo **toca solo con el extremo** el de otro → continuación (nodo de grado 2 = transición) o empalme.

**Cada intersección tiene opciones**, que se muestran **en un cartel emergente apenas termino el trazo** (una fila por cada cruce nuevo, con un número que parpadea en el mapa para saber de cuál se trata) y que después puedo cambiar tocando el nodo con la herramienta `👆 Elegir`:

1. **Tipo de empalme:**
   - `Cruce a nivel` (por defecto): las calles se atraviesan en el mismo plano; el juego deja limpio el cruce (asfalto continuo, sin guardarraíl en medio, marcas de cruce).
   - `Puente`: una calle pasa **por encima** de la otra, sin conexión entre ellas (pasos a distinto nivel). Elijo cuál va arriba (🔼 A o 🔼 B). Se dibuja en el editor con un trazo más oscuro/borde y la calle de abajo «cortada» en el cruce.
2. **Cuál prevalece / queda arriba** (solo en `Cruce a nivel`): elijo **qué calle manda visualmente en el cruce**: por ejemplo, la de asfalto sobre la de tierra (el asfalto sigue continuo y la tierra «se corta» ahí), o la de tierra sobre la de asfalto. Se guarda como `priority`: el `id` de la calle que prevalece. Por defecto manda la de **mejor superficie** (asfalto > ripio > tierra > arena > barro) y, si empatan, la **más ancha**. En el editor se dibuja el cruce con esa calle continua por encima.
3. **Dirección de prioridad de paso** (opcional): `Ninguna` (por defecto) · `Pare en las secundarias` · `Semáforo`. Solo una etiqueta que el juego usa para señalizar (`control`).
4. **Radio de esquina** (cuánto se redondean las esquinas del cruce, para que no queden «picos»): `0 m` / `6 m` / `12 m` / `20 m` (por defecto 8 m en cruces urbanos y 4 m en rurales). Guardar `cornerRadius`.

**Rotondas** (herramienta `⭕ Rotonda`): toco un punto = centro; deslizo/elijo el **radio** (15–120 m, por defecto 30 m), el **ancho del anillo** (angosta/normal/autopista) y la **superficie**; se dibuja el anillo con una isleta en el centro. Después, **cualquier trazo que termine o empiece cerca del anillo se engancha a él** (el imán lo lleva al punto más cercano del círculo y la calle queda orientada hacia el centro, tipo radial); una calle que cruce el anillo se parte en dos y se engancha en dos bocas. Cada boca es un `port` con su ángulo. Mover la rotonda mueve el anillo y arrastra los extremos pegados (que se estiran para seguirla). Poder borrar o editar una rotonda existente (radio, ancho, superficie, sentido de giro: `Antihorario` por defecto (se maneja por la derecha, vista desde arriba se gira en sentido contrario a las agujas del reloj) o `Horario`; se guarda como `"ccw"` / `"cw"`).

**Regla de oro:** el editor **no corrige geometría de las calles por su cuenta** (salvo el suavizado del trazo y la tangente de la unión automática). Si el cruce es raro o el ángulo muy agudo, solo lo informa.

## 5. Estaciones de servicio, gomerías y zonas urbanas

**⛽ Estación**: toco cerca de una calle y se coloca **al costado de la calle** (el editor calcula la calle más cercana, el lado —izquierda/derecha— y la distancia `s` en metros a lo largo de ella; yo puedo mover y cambiar el lado con un botón). Cada estación tiene casilleros de **servicios**:

- `⛽ Combustible` (cargar nafta)
- `🛞 Gomería` (cambiar cubiertas/neumáticos)
- `🔧 Taller` (reparar) — opcional, desmarcado por defecto
- Nombre editable (por defecto «Estación 1», «Estación 2»…).

Combustible y gomería pueden ir **en la misma estación** (es lo normal). Puedo ponerle una **esquina**: `lado: derecha|izquierda` y la posición exacta la acomoda el juego (yo solo marco a qué calle y en qué punto). Dibujar un ícono grande ⛽/🛞 en el mapa.

**🏙️ Zona**: trazo un polígono con el dedo (tap por tap o a mano alzada cerrando) y elijo el tipo: `Urbana` (edificios) · `Periurbana` (casas bajas) · `Bosque` · `Industrial` · `Descampado`. Para `Urbana` y `Periurbana` elijo: **densidad** (0–100 %) y **altura** (`baja` 2–4 pisos · `media` 5–10 · `alta` 11–25). Lo que cae **dentro de la zona** lo decora el juego: edificios cerrados «en caja», pegados al borde de las calles que pasan por esa zona. El editor la dibuja con un relleno semitransparente de color. Además, cada calle tiene su propio `env` («Entorno» del punto 2); si una calle cruza una zona, vale lo que diga la zona. **Cuando una calle pasa de una zona a otra (urbano → rural) o yo cambio el `env` a mitad de trazo, la calle sigue conectada sola** (nodo de transición automático) para que no queden cortes.

## 6. Altura (opcional pero preparado)

En «Más…» de una calle o nodo: **Altura (m)** con un deslizador y un campo numérico, rango −50 a 3000 m. Por defecto todo en 0 (plano). Un nodo con altura propia hace que las calles que llegan interpolen suavemente (spline) entre sus alturas; mostrar la **pendiente %** de cada calle en «Revisar» y avisar si pasa de 12 % (solo aviso). Los puentes tienen altura relativa `+6 m` por defecto sobre el que cruza.

## 7. Largada / meta y recorridos

Herramienta `🏁 Largada/Meta`: toco una calle para poner una **Largada** (con dirección: flecha, que puedo girar) y/o una **Meta**; también **puntos de control** intermedios. Puedo definir varios **recorridos** (`courses`), por ejemplo: «Costa a Cordillera» (de A a B) o «Anillo» (vuelta). Un recorrido es una lista ordenada de puntos de paso `[x, z]` sobre la red; el editor los une con la **ruta más corta por la red** (Dijkstra por distancia) y la dibuja resaltada, mostrando su largo en km, así yo puedo ajustar. Tipos: `a_b` (de A a B) · `loop` (vueltas) · `libre` (mundo abierto, sin recorrido). Para un recorrido `loop`, `laps` 1–50. Para recorridos de cientos de km no hace falta que sean cerrados.

## 8. Panel «🔍 Revisar» (avisos, no bloquean nunca la exportación)

Lista tocable (al tocar un ítem el mapa salta y resalta el lugar):

- Extremos libres (callejones sin salida) — informativo, no es un error.
- Curvas con radio < 12 m (naranja), < 6 m (rojo).
- Calles que se pisan en paralelo sin estar conectadas.
- Calles o grupos de calles **desconectados** de la red principal (islas): cantidad y largo de cada una.
- Pendientes > 12 %.
- Cruces sin definir (si ignoré el cartel: quedan con los valores por defecto).
- Estaciones lejos de toda calle (> 60 m).
- Resumen: **km totales**, km por superficie, km por ancho, cantidad de nodos, de cruces, de rotondas, de estaciones, de zonas, de recorridos, tamaño estimado del archivo.

## 9. FORMATO DE EXPORTACIÓN (JSON) — respetalo EXACTO

Un solo archivo. Todas las coordenadas `[x, z]` en metros, `x` Este, `z` Sur; alturas `y` en metros. Nada de comentarios. Todos los `id` son strings sin espacios (`"e12"`, `"n7"`…). Números con a lo sumo 1 decimal.

```json
{
  "format": "dreamracing-network",
  "version": 1,
  "id": "costa_cordillera",
  "name": "Costa a Cordillera",
  "icon": "🛣️",
  "units": "m",
  "origin": { "x": 0, "z": 0 },
  "bbox": { "minX": -800, "minZ": -1200, "maxX": 5200, "maxZ": 900 },

  "nodes": [
    { "id": "n1", "x": 0, "z": 0, "y": 0, "kind": "end" },
    { "id": "n2", "x": 420.5, "z": -30, "y": 0, "kind": "junction",
      "joint": { "mode": "at_grade", "priority": "e1", "control": "none", "cornerRadius": 8 } },
    { "id": "n3", "x": 1200, "z": 60, "y": 4, "kind": "transition" },
    { "id": "n4", "x": 2000, "z": 0, "y": 0, "kind": "junction",
      "joint": { "mode": "bridge", "over": "e5", "under": "e6", "dy": 6 } }
  ],

  "edges": [
    { "id": "e1", "a": "n1", "b": "n2", "surface": "asphalt", "width": "normal", "widthM": 9, "env": "rural",
      "speed": 100, "pts": [[0, 0], [30, -2], [75.5, -10], [420.5, -30]] },
    { "id": "e2", "a": "n2", "b": "n3", "surface": "dirt", "width": "narrow", "widthM": 6, "env": "forest",
      "pts": [[420.5, -30], [600, 20], [1200, 60]] }
  ],

  "roundabouts": [
    { "id": "r1", "x": 2600, "z": 40, "radius": 30, "width": "normal", "widthM": 9, "surface": "asphalt",
      "direction": "ccw", "island": true, "env": "urban",
      "ports": [ { "edge": "e8", "end": "a", "angleDeg": 180 }, { "edge": "e9", "end": "b", "angleDeg": 0 } ] }
  ],

  "stations": [
    { "id": "s1", "name": "Estación 1", "x": 880, "z": 70, "edge": "e2", "s": 455.0, "side": "right",
      "services": ["fuel", "tires"] }
  ],

  "zones": [
    { "id": "z1", "type": "urban", "density": 0.7, "height": "mid",
      "polygon": [[2300, -200], [3100, -200], [3100, 300], [2300, 300]] }
  ],

  "starts": [ { "id": "st1", "x": 10, "z": 0, "headingDeg": 90, "edge": "e1" } ],

  "courses": [
    { "id": "c1", "name": "Costa a Cordillera", "kind": "a_b", "laps": 1,
      "via": [[0, 0], [2600, 40], [5200, 900]], "lengthM": 5600.0,
      "checkpoints": [[2600, 40]] }
  ],

  "meta": { "createdWith": "editor_red", "totalKm": 5.6, "bySurface": {}, "notes": "" }
}
```

Reglas del formato (el validador mío las exige; tu editor tiene que cumplirlas siempre):

1. `surface` ∈ `asphalt`, `dirt`, `gravel`, `mud`, `sand`. `width` ∈ `narrow` (6 m), `normal` (9 m), `highway` (18 m); `widthM` es ese mismo ancho en metros (siempre presente). `env` ∈ `rural`, `forest`, `desert`, `periurban`, `urban`.
2. `nodes[].kind` ∈ `end`, `junction`, `transition`. Un nodo `end` tiene grado 1; `transition` grado 2; `junction` grado ≥ 3 (o dos calles que se cruzan en puente). Las calles `pts[0]` y `pts[último]` son **exactamente** la posición de sus nodos `a` y `b`.
3. `joint` solo en los `junction`. `mode`: `at_grade` (con `priority` = id de la calle que prevalece, `control` ∈ `none|stop|signal`, `cornerRadius` en metros) o `bridge` (con `over` = id de la calle de arriba, `under` = la de abajo, `dy` metros; en ese caso `over` y `under` **no se conectan entre sí**; si sale de ese nodo también otra calle, no vale: un puente no puede tener más que las 2 calles). Un cruce `+` a nivel es un nodo con 4 calles; una T, 3; una estrella, N.
4. Cada calle recorre **un solo** tramo entre dos nodos, con superficie, ancho y entorno **constantes**; si cambian, hay un nodo `transition` en medio. Las calles de un `at_grade` que llegan a un nodo con ancho distinto: el juego hace la transición; el editor además pone transición de 30 m en la geometría al unir automáticamente.
5. `pts`: entre 2 y 4000 puntos; separación entre puntos consecutivos entre 2 m y 60 m (salvo calles de menos de 4 m, que se descartan). Sin puntos repetidos.
6. Las rotondas: `ports[].angleDeg` es el ángulo del punto de unión visto desde el centro (0 = Este, 90 = Sur). La calle conectada llega al punto `(x + r·cos, z + r·sin)` del anillo; su extremo `a` o `b` queda en ese punto (**no hay nodo `junction` en ese punto, la rotonda es el nodo**).
7. `stations[].services` ⊆ `fuel`, `tires`, `repair` (al menos uno). `side` ∈ `left|right`; `s` = metros desde el nodo `a` de la calle `edge`; `x`,`z` = punto sobre la calle (el juego la corre al costado y la dibuja).
8. `zones[].type` ∈ `urban`, `periurban`, `forest`, `industrial`, `open`; `density` 0–1; `height` ∈ `low`, `mid`, `high`; el polígono se exporta **sin repetir el primer punto**, con ≥ 3 puntos, sin autointersección (si queda con autointersección, el editor la marca en Revisar).
9. `courses[].kind` ∈ `a_b`, `loop`, `free`; `via`: lista de puntos de paso (≥ 2 para `a_b`/`loop`); `lengthM` = el largo real por la red; `checkpoints` opcionales; `laps` solo en `loop`.
10. **Límites máximos del archivo** (para que mi juego no se rompa): 20 000 calles, 60 000 puntos en total, 5 000 nodos, 500 rotondas, 500 estaciones, 500 zonas, 50 recorridos, archivo ≤ 25 MB. Si se pasa, el editor avisa al exportar y ofrece **«Exportar en partes»** (varios `.json` consecutivos `<id>_parte1.json`, `<id>_parte2.json`… cada uno con `"part": {"index": 1, "of": 3}` y las mismas reglas; las calles que cruzan el corte se asignan a una sola parte). Si te parece demasiado, dejalo como un botón «Exportar en partes (opcional)».
11. `meta.totalKm` y `meta.bySurface` (`{"asphalt": km, "dirt": km, …}`) calculados.
12. Exportar con `JSON.stringify` con `separators` compactos (sin indentación) para que pese poco; ofrecer también un botón «Exportar legible» (con sangría) para revisar.

## 10. Detalles de comportamiento que no podés dejar sin hacer

- **Trazo a mano alzada**: capturar con `pointerdown/pointermove/pointerup` + `getCoalescedEvents()` si existe; `touch-action: none` en el canvas; sin scroll de página; sin zoom del navegador (`meta viewport` con `user-scalable=no`). Palm rejection básico: ignorar punteros con `width/height` enormes.
- **Suavizado**: filtro de media móvil sobre los puntos capturados, RDP con tolerancia de ~1,5 px (en metros según el zoom), luego remuestreo por longitud de arco con spline Catmull-Rom centrípeta; el espaciado final depende de la curvatura (4–40 m).
- **Imán (snap)**: radio de 14 px de pantalla (configurable en ⚙️), prioridad: nodo > extremo libre > punto sobre calle > rotonda; se muestra un círculo verde antes de soltar; mantener un modificador/alternar «Imán ON/OFF» en la barra (por si quiero que NO se pegue).
- **Auto-unión G1**: al continuar desde un extremo libre, forzar que el punto 0 coincida con el extremo y que el primer tramo siga la tangente de esa calle durante ~10–20 m, mezclando hacia el trazo real con una función suave (smoothstep). Ídem al terminar sobre un extremo libre ajeno.
- **Cruces con uno mismo**: el trazo puede cruzarse a sí mismo (un 8, un lazo): al levantar el dedo también se detectan esos cruces y se crean los nodos.
- **Cambiar atributos de una calle ya dibujada** (superficie, ancho, entorno, velocidad, nombre) con `👆 Elegir`; con `✂️ Tramo`: tocar dos puntos sobre una calle (o sobre un trazo continuo que atraviesa varios nodos) y elegir los atributos para ese tramo; el editor crea los nodos `transition` necesarios.
- **Seleccionar varias** (lazo con el dedo en `👆 Elegir` mantenido, o botón «Seleccionar todo») para cambiar atributos en conjunto.
- Mostrar siempre bajo el mapa una **línea de estado**: coordenadas del dedo (x, z en m), zoom (m/píxel) y largo del trazo en curso.
- **Colores** (aprox.): asfalto `#3b3f46` con línea central `#f2f2f2`, tierra `#a97c4f`, ripio `#c9b68a`, barro `#5b4630`, arena `#e3c76b`; bordes más oscuros; autopista con doble línea amarilla/divisor; rotondas con isleta verde; estaciones con ícono; zonas urbanas relleno azul-grisáceo 35 % de opacidad, bosque verde, industrial violeta, periurbana beige. Fondo del mapa claro (`#e9ece6`) con grilla fina gris; modo oscuro opcional.
- Pensado para **pantalla vertical y horizontal**; tipografía ≥ 14 px; botones con zonas de toque grandes; sin dependencias de fuentes externas.
- **Sin límites ocultos**: no pongas topes arbitrarios al largo, ángulo, cantidad de calles o curvas (salvo los máximos del archivo del punto 9.10, que solo se avisan al exportar).
- Código **ordenado y comentado en español**, dividido en secciones (`// ===== Vista y cámara =====`, `// ===== Grafo =====`, `// ===== Intersecciones =====`, `// ===== Exportar =====`, etc.), un solo `<script>`.

## 11. Cómo entregármelo

1. Respondé **solo con el código completo** de `editor_red.html` en un único bloque, sin recortes ni «…resto igual…». Si no entra en una respuesta, partilo en 2–3 mensajes consecutivos **cortando entre secciones** y avisando cómo unirlos.
2. Antes de entregarlo, **revisá mentalmente** estos casos y asegurate de que andan:
   - Dibujo una recta de 600 km de norte a sur (en varios trazos pegados) y el total muestra ≈ 600 km, sin trabarse.
   - Dibujo una cruz (+) con dos trazos que se cruzan: aparece el cartel de cruce con las opciones y el grafo queda con un nodo `junction` de 4 calles.
   - Dibujo un 8: el trazo se cruza consigo mismo y se crea un nodo de 4 bocas.
   - Termino un trazo sobre el costado de otra calle: se hace una T con imán verde.
   - Dibujo asfalto, levanto el dedo, cambio a tierra y sigo desde el extremo: se unen solos, con la tangente alineada y un nodo `transition` (sin escalón ni desfasaje).
   - Cruzo una calle de asfalto con una de tierra y elijo que prevalezca el asfalto: se exporta `priority` = la de asfalto.
   - Pongo una rotonda y le pego 4 calles: `ports` con 4 ángulos.
   - Pongo una estación con ⛽ y 🛞 al costado de una calle: se exporta con `edge`, `s`, `side`, `services`.
   - Trazo una zona urbana y un recorrido de A a B de varios km: se exporta con su largo.
   - Importo el `.json` que exporté: se ve **idéntico** (ida y vuelta sin pérdidas).
   - El JSON validado contra las reglas del punto 9.
3. Al final, en 5–8 líneas, listame **qué quedó sin hacer** o con limitaciones (si lo hay), así lo ajusto.
