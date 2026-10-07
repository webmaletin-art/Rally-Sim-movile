# Prompt para que DeepSeek (o cualquier IA) arme el EDITOR DE TRAZADOS de Dream Racing (formato v3, sin visor 3D)

Copiá desde «=== PROMPT ===» hasta «=== FIN ===» y pegalo entero. **No hace falta ningún ZIP**: el editor es sólo la grilla (no dibuja árboles, ni 3D, ni texturas). Pedile **un único archivo `editor_trazados.html`**.
Cuando ande: dibujás el trazado, ponés alturas, superficies, clima, estilo de carrera y rivales, tocás EXPORTAR y me pasás el `.json` (o lo subís a `godot/game/data/custom_maps/`). El juego lo lee solo: **los árboles, la vegetación y el borde del camino (guardarraíl, cerco o banquina) los pone el juego al azar y optimizado para cada teléfono.** Formato completo: `tools/route_gen/FORMATO_V3.md`. Reglas que valida la CI: `tools/route_gen/route_spec3.py`.

=== PROMPT ===

Programá **UN SOLO ARCHIVO `editor_trazados.html`** (HTML + CSS + JavaScript puro, SIN librerías externas ni CDN: tiene que abrirse con doble clic y andar sin internet en el navegador del celular, con el dedo). Es el **editor de trazados** de mi juego de carreras «Dream Racing» (motor Godot). **NO hay visor 3D**: sólo una GRILLA 2D donde se dibuja el camino, un perfil de alturas y paneles de configuración. Se exporta UN archivo JSON con un formato FIJO (sección 8) que el juego lee solo. Toda la interfaz en **español rioplatense**. Estilo oscuro (fondo #0c1017, paneles #151b26, acento naranja #ff7a1a, dorado #ffd24a), botones grandes y táctiles. Mapa **sin límites**: no hay tope de curvas ni de puntos (hasta 3000), ni de tamaño del mapa (hasta ±20000 m).

## 1. Pantalla
- Arriba: barra de herramientas (ver 2). En el centro: **plano de dibujo sobre una GRILLA** que ocupa casi todo. Abajo (se puede achicar/ocultar con una divisoria deslizable): **perfil de alturas** (altura vs. distancia) y debajo una **cinta de tramos** (el camino «desenrollado» en una barra horizontal, coloreada por superficie). Panel lateral desplegable (en el celular, un cajón que sube desde abajo) con **CONFIGURACIÓN**, **ESTADÍSTICAS** y **VALIDACIÓN**.
- Grilla: líneas finas cada 100 m, gruesas cada 500 m, con números en metros en los bordes y una barra de escala. Zoom (rueda / pellizco) y desplazamiento (arrastrar con dos dedos o con la herramienta «Mano»), infinito. **x = horizontal, z = vertical del plano, y = altura.** Todo se mide en METROS reales.
- Todo se actualiza en vivo. Se guarda solo en localStorage (proyecto actual) y hay botones «Nuevo», «Guardar proyecto», «Abrir proyecto» (archivo .json del propio editor) e «Importar .json exportado» (para seguir editando un mapa ya exportado).

## 2. Trazar con el dedo (herramientas)
- **Trazar (mano alzada)**: se dibuja con UN dedo / mouse. El trazo no tiene que ser prolijo: al soltar se lo **simplifica** (Ramer–Douglas–Peucker, tolerancia ~4 m) y se lo reparte en **puntos de control** con distancia entre ellos de **30 a 300 m** (objetivo: ~50 m en curvas cerradas y ~150 m en rectas, adaptado a la curvatura; NUNCA menos de 30 ni más de 300 m: intercalá puntos en rectas largas). El camino que se ve es la curva suave de la sección 5.
- **Los trazos se continúan**: el primer trazo define **A (largada)**; cada trazo nuevo **sigue desde el último punto** (si el dedo cae lejos, se mueve para empezar justo en el extremo, con un resaltado). Así se arma el camino por partes. «Continuar desde acá»: tocar un punto intermedio y seguir dibujando desde ahí borra lo que venía después (pidiendo confirmación).
- **Recta**: toque en dos puntos = recta (con puntos intercalados cada ~150 m). **Curva guiada**: toque en tres puntos = arco suave.
- **Editar puntos**: arrastrar un punto de control; toque largo = agregar punto; doble toque = borrar; botón «Suavizar» (Chaikin sobre lo seleccionado o todo) y **«Arreglar curvas cerradas»** (suaviza automáticamente donde el radio sea menor al mínimo).
- **Borrar tramo**: arrastrar un rectángulo sobre un pedazo del camino lo borra y deja el hueco listo para volver a trazar.
- **Deshacer / Rehacer** (botones y Ctrl+Z / Ctrl+Y), **Invertir sentido**, **Mover la largada** (en un circuito, A puede ponerse en cualquier punto: rota la lista de puntos), **Mover / escalar todo el mapa** (para centrarlo).
- **Tipos de mapa** (selector):
  - **Circuito**: lazo CERRADO (el último punto se une con el primero; no repitas el primer punto al final). Cuando el extremo se acerca a A (imán de ~40 px) se ofrece **«Cerrar circuito»**; también «Cerrar automáticamente» (une el extremo con A con una curva suave; si no cumple las reglas, avisa qué falta).
  - **Punto a punto A→B**: camino ABIERTO (no se cierra). El primer punto es **A (largada)** y el último es **B (meta)**. El juego agrega solo 200 m de camino recto antes de A (para la parrilla) y 200 m después de B (para frenar); dibujalos en gris punteado como «lo agrega el juego».
- **EL CAMINO PUEDE CRUZARSE CONSIGO MISMO**: no hay límite de forma. Se puede dibujar un **8**, una **cruz**, un trébol, lo que sea; un tramo puede pasar «por encima» de otro en el dibujo. En el juego eso es un **cruce a nivel** (como una esquina: se puede seguir derecho o doblar hacia cualquiera de los dos lados). Marcá cada cruce en el plano con un símbolo ✖ y mostrá su ángulo; los cruces tienen reglas (sección 7, reglas 9 a 11). **No hay puentes**: en un cruce los dos caminos están a la misma altura.

## 3. Alturas (bajadas y subidas)
- **Perfil de alturas** (abajo): eje horizontal = distancia recorrida desde A (en m/km), eje vertical = altura (m). Se ven los puntos de control; **arrastrar un punto hacia arriba/abajo sube o baja el camino**. Se puede arrastrar también un tramo entero (se suaviza). Marcadores A y B. Escala vertical ajustable.
- Botones: **Plano**, **Subida constante** y **Bajada constante** (pide la altura de A y de B o el % de pendiente; la rampa va entre A y B), **Colinas** (ondas suaves con amplitud y largo de onda a elegir), **Suavizar**, **Aleatoria suave (semilla)**. Campos numéricos: **altura en A**, **altura en B** (o final del circuito), **altura máxima**.
- El camino en el plano se colorea por **pendiente** (verde < 5 %, amarillo 5–9 %, naranja 9–12 %, rojo > 12 %). Pendiente máxima permitida **12 %** (promedio en 20 m): si se pasa, resaltá en el perfil y en el plano; el botón **«Arreglar pendientes»** la reparte suavemente.
- **Cruces**: en un cruce las dos alturas se IGUALAN solas (promedio de las dos y suavizado de ±80 m a cada lado, repitiendo 3 veces, recortando a 12 % de pendiente). Mostrá en el cruce «misma altura: xx m». Si la diferencia original era > 8 m, avisá que se movió mucho el camino.
- Altura permitida: 0 a 600 m. Al crear el trazo la altura sale suave e interpolada (por defecto 30 m).

## 3b. MODO DESCENSO / ASCENSO con VARILLA (para hacer bajadas y subidas fácil)
- Un selector grande **«Pendiente: Libre · Descenso · Ascenso»**. En **Libre** las alturas se editan como en la sección 3. En **Descenso** o **Ascenso** el mapa pasa solo a **Punto a punto A→B** y **toda la ruta se construye con una inclinación constante**: a medida que trazás (y cada vez que cambiás los grados), la altura de cada punto es `y = alturaA − s·tan(grados)` en descenso (o `+` en ascenso), donde `s` es la distancia recorrida por el camino desde A. El perfil de alturas se ve como una recta inclinada y queda bloqueado (botón «Desbloquear alturas» lo pasa a Libre).
- **Inclinación**: slider de **0,5° a 6,8°** (paso 0,1°) más un campo numérico, y siempre tres lecturas juntas: **grados**, **porcentaje** (`100·tan(grados)`, ej. 4° = 7,0 %) y **metros por kilómetro** (`1000·tan(grados)`, ej. 70 m/km). Límite duro 6,8° (= 12 %): arriba de eso no deja subir el slider.
- **LA VARILLA (inclinómetro)**: un dibujo grande al lado del slider: una **línea horizontal** de referencia y una **varilla gruesa** que sale de un pivote y se inclina exactamente el ángulo elegido (hacia abajo en descenso, hacia arriba en ascenso), con un **arco graduado** de 0° a 7° con marcas cada 1°, el ángulo escrito al lado y un cartelito. El arco se colorea por zonas: **verde 0–3° (suave)**, **amarillo 3–5° (fuerte)**, **naranja 5–6,8° (muy fuerte)**, **rojo > 6,8° (no permitido)**. Debajo, una frase: «Bajada de los Badenes: 3,5° (6 %) · máximo permitido: 6,8° (12 %)». La varilla se mueve en vivo al arrastrar el slider. Opcional: un cochecito dibujado sobre la varilla para dar la idea de escala.
- Campos del modo: **Altura de A** (descenso: defecto 300 m; ascenso: 20 m) y, abajo, el cálculo en vivo: **desnivel total** (m), **altura de B**, largo y tiempo estimado. Si en descenso la altura de B quedaría bajo 0 m, el editor **sube solo la altura de A** y avisa; si en ascenso B pasaría de 600 m, avisa en rojo.
- **Pendiente por tramo (opcional)**: casilla «Cambiar la inclinación por tramo»: cada tramo de la cinta (sección 4) tiene su propia varilla/slider y las alturas se integran tramo a tramo con un empalme suave de ~40 m en los cambios (ej. 2° en la salida, 5° en el medio y 3° al final).
- En descenso/ascenso **el camino no puede cruzarse** (las dos pasadas quedarían a alturas distintas): el editor marca el cruce en rojo y dice «en una bajada continua no se puede cruzar el camino».
- Se exporta como `"slope": { "mode": "descent", "deg": 4.0 }` (`mode`: `free` · `descent` · `ascent`; `deg` = grados promedio, 0–6.9). Las alturas reales de los puntos siempre van en `route.points` (el juego usa esas); `slope` sirve para volver a abrir el mapa en el editor con la varilla puesta.
- Después de exportar, el mapa se corre como **contrarreloj** (`race.style: "timetrial"`) o **carrera** (`"race"`, o `"adventure"` para una sola pasada con rivales): elegilo en la configuración.

## 4. Superficies por tramo (asfalto, tierra, grava, barro, arena)
- Elegí una **superficie del pincel** (botones de color: asfalto gris, tierra marrón, grava gris claro, barro marrón oscuro, arena amarilla) y **pintá sobre el camino**: arrastrar el dedo a lo largo del camino pinta esa superficie (en el plano y en la cinta de tramos). También se puede **seleccionar un pedazo en la cinta** (dos manijas arrastrables) y tocar una superficie para cambiarlo; o escribir desde–hasta en metros.
- «**Continuar**»: tocar el final de un tramo y elegir una superficie hace que **el resto del camino hacia adelante** siga con esa superficie hasta el próximo cambio; así se arma «asfalto → tierra → barro → asfalto…». Los tramos son **consecutivos, sin huecos**, de 0 a 1 (fracciones del largo recorrido: del lazo en circuito, de A→B en punto a punto). Cada tramo mide **al menos 60 m** (si el pincel deja uno menor, se junta con el vecino), máximo 200 tramos.
- Lista de tramos editable: nombre opcional (`label`), superficie, **densidad de árboles del tramo** (slider 0–100 %: sólo es una pista para el juego), largo en m. Seleccionar un tramo lo resalta en el plano.
- Al **mezclar superficies** la banquina y el ancho se validan con las reglas de tierra (sección 7).

## 5. La curva (idéntica a la del juego)
- **Circuito**: curva **Catmull-Rom uniforme CERRADA** que pasa por los puntos, aplicada a x, y y z por separado: `P(t) = 0.5 * ( 2·P1 + (−P0+P2)·t + (2·P0−5·P1+4·P2−P3)·t² + (−P0+3·P1−3·P2+P3)·t³ )`, `P0=pts[i−1], P1=pts[i], P2=pts[i+1], P3=pts[i+2]` (índices circulares), 24 pasos por tramo (`t = k/24`). 
- **Punto a punto (camino ABIERTO)**: se usa la misma fórmula Catmull-Rom, con dos puntos «fantasma» antes de A y dos después de B. Con `n` puntos `pts[0..n−1]` (A = `pts[0]`, B = `pts[n−1]`): `tA = unitario(pts[1] − pts[0])`, `tB = unitario(pts[n−1] − pts[n−2])` (sólo x,z); `sA`/`sB` = pendiente (dy/ds) del primer / último tramo, limitada a ±0.12. La lista de control queda: `[A − 400·tA, A − 200·tA, pts…, B + 200·tB, B + 400·tB]`, con la altura de los puntos extra = `A.y − sA·distancia` (antes de A) y `B.y + sB·distancia` (después de B). Se evalúa la curva Catmull-Rom de esa lista **sólo entre el 2º punto y el penúltimo** (de A − 200 m a B + 200 m); los dos extremos extra nada más dan forma. El largo que se corre es el de A a B.
- Dibujá el camino con ese muestreo, con su ancho real (`2·halfWidth`) y la banquina (`shoulder`) a cada lado. El «largo» siempre es el de la curva muestreada (suma de distancias entre muestras), no el de los puntos.

## 6. Configuración (todo antes de exportar)
**Del mapa:** nombre, ícono (emoji), **id** automático desde el nombre (minúsculas, números y `_`; 3–24 caracteres; el archivo exportado se llama `<id>.json`), tipo (circuito / A→B), **ancho del camino** (`halfWidth` 3.0–5.6 m, defecto 4.6) y **banquina** (`shoulder` 1.6–2.6, defecto 2.0).
**Clima:** `weather.sky`: **día soleado** `day`, **nublado** `overcast`, **atardecer** `sunset`, **anochecer** `dusk`, **lluvia** `rain` (botones con ícono).
**Escenografía (la decide el juego, vos sólo das la tendencia):** tipo de árboles (`none` ninguno · `pine` pinos · `broadleaf` hojas anchas · `mixed` mezcla), densidad general 0–100 %, **borde del camino** `decor.edge`: `auto` (el juego elige al azar, recomendado) · `guardrail` (guardarraíl de chapa) · `wood` (tablón de madera) · `fence` (cerco de postes y alambres) y **vegetación** `decor.vegetation` 0–100 % (matas de pasto/arbustos junto al camino). Aclará en la interfaz: «Los árboles, la vegetación y el borde los pone el juego al azar según la potencia de cada celular.»
**Estilo de carrera** (`race.style`) con sus opciones:
- `race` **Carrera**: contra rivales. Circuito: **vueltas** 1–5.
- `timetrial` **Contrarreloj**: solo, contra el reloj. Circuito: vueltas 1–5.
- `adventure` **Aventura**: recorrido de **una sola pasada** (ideal A→B, de largada a meta, sin vueltas) con rivales.
- `chase` **Persecución** (un solo rival): al principio vos perseguís al rival; **si el de adelante se escapa a más de `maxGapM` metros, gana** (si te escapás vos, ganás vos). Si lo pasás, los roles se cambian: ahora te persigue a vos, pegado, y de a ratos intenta pasarte, y así hasta que uno se vaya más lejos que el otro. Opción **«Distancia de escape»** `race.chase.maxGapM`: slider de 60 m a 1000 m (mostrar también en km).
- `elimination` **Eliminación**: cada `race.elimination.everySec` segundos (15–120, defecto 30) sale el que va último, y así hasta que queda uno: ese es el primero. Pide 3, 5 o 7 rivales. Opción **«Cada cuántos segundos»**.
**Rivales:** `rivals.count` 0–7 (persecución: 1) y **dificultad con una BARRA de 1 % a 100 %** (guardala como 0.01–1.0), con etiquetas: 1–25 Fácil · 26–45 Media · 46–70 Difícil · 71–90 Extrema · 91–100 Imposible. En persecución la dificultad cambia el ritmo del rival y qué tan fuerte intenta escaparse.
**Circuito:** casilla «Agregar también la versión inversa» (`reverse`; sólo circuitos).
**Evento de la carrera (opcional):** desplegable «¿Reemplaza algún evento de la carrera?» (bloque `career`): copa (`debut nacional continental leyenda camiones`), id del evento (texto, ej. `c1`), cielo y «correrla inversa». Por defecto «Ninguno (sólo Carrera rápida)».

## 7. VALIDACIÓN en vivo (panel con ✔/✖; el botón **EXPORTAR queda deshabilitado mientras haya un ✖**; cada ✖ explica qué hacer y resalta el lugar en rojo en el plano y en el perfil)
1. **Puntos**: circuito 8–3000, A→B 4–3000. Entre consecutivos **30 a 300 m** (en un circuito incluye último→primero; en A→B no hay vuelta).
2. |x|,|z| ≤ 20000; altura 0–600; `halfWidth` 3.0–5.6; `shoulder` 1.6–2.6.
3. **Largo**: circuito ≥ 1000 m (el lazo); A→B ≥ 800 m (lo que se corre, de A a B). Más de 15 km = **aviso** (no error): «mapa largo, carga más lenta en celulares flojos».
4. **Radio de curva mínimo** en planta (circunradio de tres muestras a ±10 m sobre la curva de la sección 5): **22 m si TODOS los tramos son asfalto; 18 m si hay algún tramo de tierra, grava, barro o arena**.
5. **Pendiente máxima 12 %** (|Δy/Δs| promediado en 20 m; 12 % = 6,8°).
6. **Largada**: los primeros **150 m desde A casi rectos** (radio ≥ 90 m) para la parrilla.
7. **Tramos**: consecutivos de 0 a 1, ≥ 60 m cada uno, superficie válida, máx. 200; densidad 0–1.
8. Rangos de configuración: laps 1–5 (sólo circuito); `maxGapM` 60–1000; `everySec` 15–120; rivals 0–7; difficulty 0–1; `reverse` sólo circuito.
9. **Cruces** (el camino pasa cerca de otra parte de sí mismo): se detecta con las muestras de la curva (cada una con su recorrido acumulado): dos muestras con **más de 160 m de recorrido entre ellas** y a **menos de `2·(halfWidth+shoulder)+3` m en planta** forman un cruce (agrupá las muestras consecutivas en UN cruce). Para cada cruce calculá el **ángulo** entre las dos direcciones (0°–90°).
10. **Ángulo mínimo 35°**: si dos partes se pisan casi en paralelo (< 35°) es un ✖ «dos partes del camino se pisan casi en paralelo: alejalas o cruzalas de frente». (Un camino que pasa cerca de otro sin llegar a tocarse es válido.)
11. **Cruces a la misma altura**: el editor las iguala solo (sección 3); si aún así la diferencia es > 8 m, ✖; entre 2 y 8 m, aviso.
12. **Pendiente continua**: si `slope.mode` es `descent` o `ascent`, el tipo tiene que ser A→B, `deg` entre 0 y 6.9 y el camino no puede tener cruces.
13. **A y B fuera de los cruces**: la largada A no puede estar en un cruce ni a menos de 150 m de uno; la meta B (A→B) no a menos de 100 m de uno.
Mostrá los avisos (⚠) aparte de los errores.

## 8. FORMATO DE EXPORTACIÓN (exacto, versión 3)
```json
{
  "format": "dreamracing-route", "version": 3,
  "id": "ocho_del_lago", "name": "Ocho del Lago", "icon": "♾️",
  "type": "circuit",                        // "circuit" | "point_to_point"
  "route": { "halfWidth": 4.6, "shoulder": 2.0,
             "points": [[x, y, z], [x, y, z], ...] },   // circuito: lazo CERRADO sin repetir el primero · A→B: abierto, primero = A, último = B · y = ALTURA en metros
  "sections": [ { "from": 0.0, "to": 0.5, "surface": "asphalt", "label": "Largada", "density": 0.6 },
                { "from": 0.5, "to": 0.8, "surface": "mud",     "label": "Barrial", "density": 1.0 },
                { "from": 0.8, "to": 1.0, "surface": "dirt" } ],   // consecutivos de 0 a 1
  "weather": { "sky": "day" },
  "scenery": { "trees": "mixed", "density": 0.6 },
  "decor":   { "edge": "auto", "vegetation": 1.0 },
  "slope":   { "mode": "free", "deg": 0 },     // opcional: "free" | "descent" | "ascent" + grados (ver 3b)
  "race":    { "style": "chase", "laps": 2, "chase": { "maxGapM": 150 }, "elimination": { "everySec": 30 } },
  "rivals":  { "count": 1, "difficulty": 0.6 },
  "career":  { "tier": "continental", "event": "c1", "sky": "day", "reverse": false },   // opcional
  "reverse": true,                          // opcional, sólo circuitos
  "meta": { "generator": "editor_trazados.html", "lengthM": 2202, "stats": { } }
}
```
- Superficies: `asphalt dirt gravel mud sand`. Árboles: `none pine broadleaf mixed`. Bordes: `auto guardrail wood fence`. Cielos: `day overcast sunset dusk rain`. Estilos: `race timetrial adventure chase elimination`. Copas: `debut nacional continental leyenda camiones`.
- **Nombre del archivo: `<id>.json`** (exacto). Indentación de 1 espacio, coordenadas con 1 decimal. Siempre exportá `race.laps` en circuitos (1–5); exportá `race.chase`/`race.elimination` sólo si el estilo los usa. **No agregues campos nuevos fuera de `meta` (salvo `slope`).** El JSON tiene que ser JSON puro (sin comentarios).
- Enteros como enteros (`"laps": 2`, `"count": 5`, nunca `2.0`).
- Botones: **EXPORTAR** (baja el archivo), **COPIAR JSON** (al portapapeles) y **VISTA PREVIA del texto**.

## 9. Estadísticas (panel, se actualizan en vivo)
Largo del circuito (o de A→B) en km · distancia total de la carrera (largo × vueltas) · tiempo estimado (largo / 28 m/s) · desnivel total, altura mínima y máxima · pendiente máxima · cantidad de curvas cerradas (radio < 40 m) · **cantidad de cruces** · superficie por superficie (km y %) · tamaño del mapa (ancho × alto en km) · **comparación**: «tu mapa mide X % de la Bajada de los Badenes (5,13 km)». Si el mapa tiene más de 15 km avisar el costo de carga.

## 10. Generador al azar (ayuda opcional)
Botón «Generar al azar» con **semilla** (número editable, botón de dado): circuito suave de N curvas; **ocho**; **trébol** (dos cruces); A→B serpenteante con subida y bajada. Los generados ya salen válidos (con las reglas de la sección 7) y se pueden editar como cualquier trazo.

## 11. Calidad
- Un solo archivo, sin dependencias, anda offline en Chrome/Firefox del celular. Eventos `pointer` (táctil + mouse), `touch-action: none` en el plano, sin zoom de la página. Rendimiento fluido con 3000 puntos (dibujá en un `<canvas>` con requestAnimationFrame; la validación puede correr con un pequeño retardo al soltar el dedo).
- Probalo con estos casos antes de entregar: (1) un circuito simple de 12 puntos; (2) un ocho que se cruza a 90° en el centro y queda a una sola altura; (3) un A→B de 3 km con bajada del 6 %; (4) un camino que se pisa en paralelo (tiene que dar ✖); (5) una curva demasiado cerrada (✖); (6) un circuito con tramos asfalto → barro → arena y la cinta bien coloreada; (7) exportar e importar de nuevo da lo mismo; (8) un descenso A→B de 4,6 km a 4°: el desnivel total tiene que dar ~320 m, la varilla se inclina 4° y la altura de B da A − 320 m.

=== FIN ===
