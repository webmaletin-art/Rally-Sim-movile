# Prompt para que DeepSeek (o cualquier IA) arme el GENERADOR / EDITOR DE MAPAS de Dream Racing en un solo HTML

Copiá desde «=== PROMPT ===» hasta «=== FIN ===» y pegalo. Si la IA deja adjuntar archivos, subile `dreamracing_route_assets.zip` (si no, no hace falta: el HTML mismo lo carga con un botón).
Pedile **un único archivo `generador_mapas.html`** completo. Cuando ande, dibujá/generá un mapa, tocá EXPORTAR y subí el `.json` que baja a la carpeta `godot/game/data/custom_maps/` del repositorio: el juego lo lee solo (la CI lo valida y lo prueba con la IA antes de compilar). Si querés que reemplace un evento de la carrera, elegilo en el HTML (campo «Evento de la carrera»); si no, queda en Carrera rápida.

=== PROMPT ===

Programá **UN SOLO ARCHIVO `generador_mapas.html`** (HTML + CSS + JavaScript, sin servidor ni instalación: se abre con doble clic y anda en el navegador del celular, con el dedo). Es el **editor y generador de mapas** de mi juego de carreras «Dream Racing» (motor Godot). Los mapas se exportan como UN archivo JSON con un formato FIJO (sección 3) que el juego lee automáticamente desde una carpeta. Todo el texto de la interfaz en **español rioplatense**. Estilo oscuro (fondo grafito #0c1017, paneles #151b26, acento naranja #ff7a1a, dorado #ffd24a), botones grandes (táctil), sin librerías pesadas: **JSZip** (cdnjs) para el ZIP de recursos y **three.js** (cdnjs/jsdelivr) para el visor 3D. Todo lo demás en JS puro.

## 1. Pantalla dividida con divisoria deslizable (lo más importante)
- La pantalla se parte en dos: **izquierda = plano de dibujo 2D sobre una GRILLA**; **derecha = visor 3D** del mapa. Entre las dos hay una **divisoria que se desliza con el dedo/mouse** (izquierda↔derecha) para achicar o agrandar cada lado (mínimo 0 %, máximo 100 %: se puede ocultar un lado). Doble toque en la divisoria = 50/50. Guardá la posición en localStorage. En pantalla vertical (celular parado) la divisoria pasa a ser horizontal (arriba plano, abajo 3D) con la misma lógica.
- Ambos lados se actualizan en vivo (sin botón «actualizar»). La cámara 3D es libre (arrastrar = girar, pellizco/rueda = zoom, dos dedos = mover) y hay un botón «Recorrer» que pasea una cámara por el camino a ras de suelo, y «Seguir al auto» (un cubito que avanza) para ver el mapa como se corre.
- La grilla del plano: líneas cada 100 m y más marcadas cada 500 m, reglas con metros, zoom (rueda/pellizco) y desplazamiento (arrastrar con dos dedos o con la herramienta «Mano»). Escala visible (por ej. «barra de 500 m»). Coordenadas bien: **x = horizontal, z = vertical del plano, y = altura**.

## 2. Dibujar el recorrido con el dedo (herramienta «Trazar»)
- Se elige primero la **superficie del pincel** (asfalto, tierra, grava, barro, arena) con botones de color, y se traza una línea con el dedo/mouse sobre la grilla. El trazo **no tiene que ser preciso**: al soltar el dedo se lo **simplifica** (Ramer–Douglas–Peucker) y se lo ajusta a **puntos de control** (distancia entre puntos de 40 a 260 m; objetivo ~120 m) con una curva suave Catmull-Rom (ver 4).
- **Los trazos se CONECTAN siempre**: el primer trazo define el punto A; cada trazo nuevo **empieza donde terminó el anterior** (si el dedo cae cerca —imán de 40 px / ~60 m— del extremo libre del recorrido, se pega ahí; si cae lejos, el trazo se mueve para que empiece justo en ese extremo, avisando con un breve resaltado). Así uno puede trazar una recta de asfalto, después otra de tierra, después barro, y quedan unidas sin que importe la puntería.
- **Cerrar el lazo**: cuando el extremo del último trazo se acerca al punto A (imán), se ofrece «Cerrar circuito»; el juego necesita un lazo CERRADO. También hay un botón «Cerrar automáticamente» que une el extremo con A con una curva suave (si no cumple las reglas, avisar qué falta).
- Cada trazo (con su superficie) pasa a ser un **tramo** de la lista de tramos. Se puede **dividir** un tramo en un punto, **unir** dos tramos, **cambiarle la superficie**, **borrar el último trazo**, **deshacer/rehacer** (Ctrl+Z y botones), y **editar puntos** (herramienta «Editar»: arrastrar un punto, agregar con toque largo, borrar con doble toque, suavizar). Los puntos del recorrido nunca quedan sueltos: siempre forman una cadena conectada.
- La **altura** se edita en un **perfil de altura** (gráfico altura vs. distancia debajo del plano, estilo editor de curvas): arrastrar puntos del perfil sube/baja el camino; botones «Suavizar», «Aplanar» y «Subida/bajada» (rampa entre dos puntos). Por defecto el trazo nuevo sale con altura suave interpolada.

## 3. Panel de TRAMOS y de CONFIGURACIÓN (todo ya configurado antes de exportar)
**Por cada tramo** (lista editable, un tramo seleccionado se resalta en plano y 3D): nombre (etiqueta), superficie (asfalto/tierra/grava/barro/arena), **densidad de árboles** (slider 0–100 %), y su largo en metros.
**Del mapa:** nombre, ícono (emoji), id automático (minúsculas, números y _; 3–24 caracteres), tipo (**Circuito** o **Punto a punto A→B**), ancho del camino y banquina (con los límites de la sección 5), superficie base, **tipo de árboles** (`none` ninguno · `pine` pinos · `broadleaf` hojas anchas · `mixed` mezcla), densidad general, suelo del entorno (pasto/tierra/arena), **vueltas** (1–5, sólo circuito) o el **tramo que se corre** (punto a punto: B se elige moviendo un marcador sobre el camino), **cantidad de rivales** (0–7) y **dificultad con una BARRA de 1 % a 100 %** (con el número y una etiqueta: 1–25 Fácil, 26–45 Media, 46–70 Difícil, 71–90 Extrema, 91–100 Imposible; y mostrá a qué copa se parece: Debut ≈ 33 %, Nacional ≈ 52 %, Continental ≈ 67 %, Leyenda ≈ 81 %).
**Evento de la carrera (opcional):** un desplegable «¿Reemplaza algún evento de la carrera?» con la lista de `eventosDeLaCarrera` del archivo `referencias/mapas_del_juego.json` del ZIP (id, copa, tipo, nombre), más «Ninguno (sólo Carrera rápida)». Si elige uno, se exporta el bloque `career` (copa, evento, cielo y si se corre inversa) y se **copian automáticamente** las vueltas/rivales/dificultad como los de ese evento (editables). Casilla «Agregar también la versión inversa».

## 4. LA CURVA (idéntica a la del juego)
El camino es la **curva Catmull-Rom uniforme CERRADA** que pasa por los puntos de control, aplicada a x, y y z por separado:
`P(t) = 0.5 * ( 2·P1 + (−P0+P2)·t + (2·P0−5·P1+4·P2−P3)·t² + (−P0+3·P1−3·P2+P3)·t³ )`, t∈[0,1], `P0=pts[i−1], P1=pts[i], P2=pts[i+1], P3=pts[i+2]` (índices circulares), 24 pasos por tramo. Dibujá el camino con ese muestreo, con ancho real `2·halfWidth` y la banquina `shoulder` a cada lado. Las fracciones de los tramos (`from`/`to`, 0–1) se miden sobre el **largo recorrido del lazo** desde el punto A (punto 0).

## 5. FORMATO DE EXPORTACIÓN (exacto, versión 2)
```json
{
  "format": "dreamracing-route", "version": 2,
  "id": "cantera_sur", "name": "Cantera del Sur", "icon": "⛏️",
  "type": "circuit",                       // "circuit" | "point_to_point"
  "surface": "dirt",                       // superficie base: "asphalt" | "dirt"
  "route": { "halfWidth": 3.6, "shoulder": 2.0, "points": [[x, y, z], ...] },   // lazo CERRADO; y = altura
  "sections": [ { "from": 0.0, "to": 0.15, "surface": "asphalt", "label": "Largada", "density": 0.3 }, ... ],  // seguidos de 0 a 1
  "scenery": { "trees": "mixed", "density": 0.6, "ground": "grass" },
  "race": { "laps": 2 },                   // punto a punto: { "seg": [0, 0.55] }
  "rivals": { "count": 5, "difficulty": 0.62 },     // difficulty = porcentaje/100
  "career": { "tier": "continental", "event": "c1", "sky": "day", "reverse": false },   // opcional
  "reverse": true,                         // opcional: agrega la versión inversa
  "meta": { "generator": "generador_mapas.html", "seed": 12345, "lengthM": 4321, "stats": { "...": "las estimaciones del panel" } }
}
```
- Superficies de tramo: `asphalt dirt gravel mud sand`. Árboles: `none pine broadleaf mixed`. Cielo: `day overcast sunset dusk rain`. Copas: `debut nacional continental leyenda camiones`.
- **Nombre del archivo exportado: `<id>.json`** (exacto). Indentación de 1 espacio, números con 1 decimal. No agregues campos nuevos fuera de `meta`.
- `y` es la ALTURA en metros (0–250). `x`,`z` el plano (±1500 m).

## 6. REGLAS DE VALIDACIÓN (panel «Validación» en vivo, ✔/✖; el botón **EXPORTAR queda deshabilitado mientras haya un ✖**; cada ✖ explica qué hacer y, si se puede, resalta el lugar en rojo en el plano y en el 3D)
1. 12 a 48 puntos de control; entre puntos consecutivos (incluido último→primero) **40 a 260 m**. (Al trazar, el simplificador debe respetar esto: si un tramo recto es muy largo, intercalar puntos.)
2. |x|,|z| ≤ 1500; altura entre 0 y 250.
3. Largo del lazo (curva muestreada): circuito **1800–7000 m**; punto a punto **4000–12000 m** y la parte que se corre (`seg`) **1800–6000 m**.
4. **Radio de curva mínimo** en planta (circunradio de tres muestras separadas ~10 m): asfalto ≥ 22 m; si hay algún tramo de tierra/grava/barro/arena, ≥ 18 m.
5. **Pendiente máxima 12 %** (|Δy/Δs| promediado en ventanas de 20 m).
6. **El camino no se toca ni se cruza**: dos muestras separadas por más de 60 m de recorrido a ≥ `2·(halfWidth+shoulder)+12` m en planta.
7. Los **primeros 150 m desde A casi rectos** (radio ≥ 90 m) para la parrilla.
8. `halfWidth`: asfalto 4.2–5.6, tierra 3.0–4.4 (si el mapa mezcla, usá el de tierra: 3.0–4.4); `shoulder` 1.6–2.6.
9. **Tramos**: seguidos, sin huecos, de 0 a 1; **cada uno ≥ 80 m**; máximo 24; superficie válida; densidad 0–1.
10. `laps` 1–5; `rivals.count` 0–7; `rivals.difficulty` 0–1; `id` válido y único; `name` no vacío.

## 7. GENERADOR AUTOMÁTICO (con lógica, por semilla)
Panel «Generar»: **semilla** (número + botón 🎲 al azar), tipo (circuito / punto a punto), **largo objetivo** (km), «curvilínea» 0–100 %, desnivel 0–100 %, ancho, y **mezcla de superficies** (porcentaje de asfalto, tierra, grava, barro y arena y cantidad de cambios de superficie), tipo y densidad de árboles. Botones «Generar», «Variar» (misma configuración, otra semilla) y «Usar como base» (pasa el resultado al editor para retocarlo a mano). El generador **siempre devuelve un mapa válido** (reintenta con sub-semillas hasta 3000 veces; si no puede, dice cuál regla le falla).
Algoritmo recomendado: lazo base con radio polar ondulado (armónicos k = 2..5, amplitudes decrecientes) y estiramiento; mezclar rectas largas, curvas amplias, horquillas abiertas (radio ≥ 40 m) y eses; alturas con 1–3 armónicos suaves que cierran el lazo (y(0)=y(1)); **elegir como punto A la zona más recta**; partir el lazo en tramos de superficie en lugares donde el camino es recto o de curva suave (los cambios de superficie en medio de una curva cerrada se evitan), con transiciones asfalto→tierra→barro razonables (el barro y la arena van en tramos de 150–600 m, no más de 35 % del mapa cada uno por defecto); la densidad de árboles se reparte por tramo (más en tierra/bosque, menos en arena y asfalto de ciudad). Para punto a punto: elegir B de modo que `seg` cumpla el largo y el tramo A→B tenga variedad.

## 8. ESTADÍSTICAS Y COMPARACIÓN CON LOS MAPAS DEL JUEGO (panel «Rendimiento», en vivo)
El ZIP trae `referencias/mapas_del_juego.json` con 5 mapas reales medidos en el juego (Bosque, Lago, Cantera, Montaña Asfalto y **Bajada de los Badenes**, que da **5,13 km por vuelta**) y el modelo de costo. Mostrá, para el mapa actual **y al lado de cada mapa de referencia** (tabla + barras horizontales comparables):
- **Distancia por vuelta (km)** del lazo, **distancia total de la carrera** (vueltas o `seg`), **tiempo estimado** (a 110 km/h de media en asfalto, 90 tierra, 70 grava, 55 arena, 40 barro, por tramo), **desnivel** total y altura máxima/mínima, cantidad de puntos de control, cantidad y largo de tramos por superficie (barra apilada de colores), curvas cerradas (radio < 40 m).
- **Árboles**: «hasta N» = presupuesto del teléfono × densidad media (mostrá los tres: 1500 / 3000 / 6000) y árboles por km.
- **Costo estimado (draw calls, primitivas e índice)**: usá el `modeloDeCosto` del JSON: `draws = 110 + 0.027·L`, `prims = 135000 + 10.5·T + 6·L` (L = largo del lazo en metros, T = árboles con presupuesto 3000 × densidad media), `índice = 100·(0.5·draws/232 + 0.5·prims/211045)` (100 = Bajada de los Badenes). Mostrá cada número con «± 25 %» y el índice con un semáforo (verde ≤ 90, amarillo 91–110, rojo > 110 «puede pesar en teléfonos flojos»). Explicá en un tooltip que la **resolución del 3D (pixel ratio) no depende del mapa**: la fija el perfil gráfico del teléfono (0.5–0.9 de la pantalla).
- Aviso si el mapa es muy largo: «el juego lo carga por partes con barra de carga» (no hay que hacer nada especial).
Exportá estas estimaciones dentro de `meta.stats`.

## 9. ZIP DE RECURSOS Y VISOR 3D
Botón «Importar ZIP de recursos» (y arrastrar-soltar) que lee `dreamracing_route_assets.zip` con JSZip: `arboles/<especie>_<ángulo>.png` (9 especies × 8 vistas cada 45°; 192×192 con transparencia; se dibujan como **carteles que giran hacia la cámara**, eligiendo la vista según el ángulo cámara-árbol) y `arboles/trees.json` (alto real `h` en metros), `horizonte/horizon_a.png` y `horizon_b.png` (bosque lejano, repetir en el horizonte), `suelo/asphalt.png`, `dirt.png`, `grass.png` (128×128, repetir), `referencias/mapas_del_juego.json`, `ejemplos/*.json`, `rutas_del_juego/*.json` y `FORMATO.md`. Sin el ZIP todo anda con colores lisos y círculos verdes.
- Visor 3D: el camino como cinta con la textura de cada superficie (asfalto con líneas blancas; tierra, grava, barro oscuro y arena clara: usá `dirt.png` teñida), banquinas con cordón rojo/blanco, pasto de `grass.png`, árboles de cartel según `trees` (`pine` → pino/ciprés; `broadleaf` → roble/hoja_ancha/abedul/álamo; `mixed` → ambos) con la densidad de **cada tramo**, **cartel/arco de SALIDA en A** y **arco de META en B** (o en A en un circuito), horizonte, niebla leve y cielo. El juego dibuja sus propios cordones, carteles y árboles: lo del visor es sólo vista previa.
- «Cargar mapa…» importa un `.json` del formato (v2; también aceptá la v1 convirtiéndola) para seguir editando. Autoguardado en localStorage con botón «Nuevo». También «Cargar ejemplos / rutas del juego».

## 10. PICADA (opcional, al final)
Modo «Picada / aceleración»: recta de largada con **cambios manuales**, **cinta de llegada** y **reloj**; largo 201, 402 u 804 m; superficie y entorno. Sólo vista previa y exporta `{ "type": "drag", "drag": { "lengthM": 402 }, "surface", "scenery" }` (sin `route`). **El juego todavía no lo importa**: lo adapto yo cuando mande uno.

## 11. Entrega
- Un solo `generador_mapas.html`, comentado en español, ordenado en secciones (zip, geometría y spline, validación, trazado a dedo, tramos, generador, estadísticas, visor 3D, divisoria, exportación).
- No inventes campos fuera de `meta`. No cambies nombres de superficies, de árboles, de copas ni límites.
- Probá mentalmente: (a) el generador nunca exporta un mapa inválido, (b) la curva es la Catmull-Rom cerrada de la sección 4, (c) `y` es la altura, (d) los trazos siempre quedan conectados, (e) la divisoria se puede arrastrar con el dedo y los dos lados se actualizan, (f) el botón EXPORTAR descarga `<id>.json`.

=== FIN ===
