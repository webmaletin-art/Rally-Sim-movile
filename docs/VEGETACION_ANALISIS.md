# Vegetación y edificios: cómo registrar las pruebas y cómo se va a decidir

Este documento NO trae conclusiones: los FPS son los del teléfono del dueño y todavía no hay datos. Sólo deja (1) cómo anotar resultados, (2) lo que se sabe de cada sistema por cómo está implementado (sin FPS) y (3) las reglas con las que se decide cuando lleguen los datos.

## 1. Cómo registrar (en el mapa de prueba, Rendimiento → BENCHMARK — VEGETACIÓN)
1. Elegí árboles (3D ORIGINAL · .PAP ACTUAL · 8 VISTAS PNG · CROSS 2 PLANOS) y cantidad; edificios (SIN EDIFICIOS · DRIFT / AVENTURA · DREAM CITY · PAPEL) y cantidad.
2. Conducí unos segundos con esa combinación (el contador arriba a la izquierda muestra FPS, promedio y mínimo desde el último cambio).
3. En «REGISTRO DE MIS PRUEBAS» marcá: calidad visual, tirones, cambios de textura visibles, se ve falso, problemas de transparencia y a qué distancia se empieza a notar la técnica. Tocá ANOTAR ÁRBOLES o ANOTAR EDIFICIOS.
4. **COPIAR** deja el informe en el portapapeles (pegalo en el chat). También queda guardado en el teléfono (`user://vegbench_results.json`). Cada línea lleva modelo de teléfono y GPU, la combinación completa (árboles y edificios activos), FPS promedio y mínimo, segundos medidos, llamadas de dibujo y triángulos.
Pruebas sugeridas (ninguna es obligatoria): cada sistema de árboles con 1000, 5000, 10000 y 20000 sin edificios; cada sistema de edificios con 200 y 800 con 1000 árboles de un sistema fijo; y SIN EDIFICIOS como referencia.

## 2. Lo que se sabe por la implementación (sin FPS)
**Archivos de los 5 árboles probados (A pino 11 554 tri · B bambú 5 913 · C hoja ancha 2 992 · D abedul 2 826 · E sauce 2 784):**

| | 3D original | .PAP actual | 8 vistas PNG | Cross 2 planos |
|---|---|---|---|---|
| Triángulos por árbol | 2 784 – 11 554 | 160 – 392 | 2 | 4 |
| Disco (los 5) | GLB 543 KB | .pap 70 KB | PNG 1 014 KB | PNG 247 KB |
| Memoria al cargar | malla en RAM/VRAM compartida entre instancias | malla compartida (unos 36–48 B por vértice sin índices) | 8 capas RGBA8 **sin comprimir**: 10,7 MB (A y B, 512 px) y 2,7 MB (C, D, E), con mipmaps ≈ 29,5 MB para las 5 | 2 capas: ≈ 7,5 MB para las 5 |
| Transparencia | recorte en el shader del GLB (tarjetas de hojas) | ninguna (caras opacas) | recorte alfa 0,4 sobre un cuadro grande | recorte alfa 0,4 sobre 2 cuadros |
| Luz | sol + ambiente por píxel | sol + ambiente (el shader de papel calcula la normal plana con derivadas de pantalla) | ninguna: la luz está pintada en las imágenes (no cambia con la hora del día) | ninguna (igual) |
| Sombras | apagadas en la prueba | apagadas | apagadas | apagadas |
| Instancias | MultiMesh por bloque de 250 m y especie | igual | igual | igual |

* **Disco ≠ memoria ≠ costo de dibujo.** El PNG en disco está comprimido (PNG); al cargarlo se descomprime a RGBA8 y, como las texturas de capas se arman por código, **no se comprimen para la GPU** (ni ETC2 ni ASTC): lo que ocupa en memoria no se parece al archivo. Aparte, el costo de dibujar no depende del peso del archivo sino de cuántos píxeles cubre el cuadro (incluidos los transparentes, que se descartan en el shader pero igual se procesan) y de cuántos cuadros se superponen.
* **CPU:** en las cuatro opciones cada instancia es una transformación de 48 bytes en un MultiMesh; no hay lógica por árbol ni por cuadro. Lo que pesa en la CPU es la cantidad de bloques (MultiMesh) que se recorren para descartar los que no se ven y las llamadas de dibujo (una por superficie de cada bloque visible). El 8 vistas elige la imagen en el shader de vértices (no hay cambios de material ni de textura por árbol: todas las vistas son capas de una sola textura).
* **8 vistas vs cross (por diseño, sin medir):** 8 vistas = 1 cuadro por árbol que gira hacia la cámara + 8 capas (más memoria) y un cambio de imagen cada 45° de giro alrededor del árbol (puede notarse como salto). Cross = 2 cuadros fijos (4 triángulos), 2 capas (menos memoria), y desde ciertos ángulos se ve más plano; tiene más superposición de cuadros por árbol, o sea más píxeles transparentes procesados.
* **.PAP vs 3D original:** el .PAP son entre 7 y 70 veces menos triángulos pero con caras opacas de color liso (forma de bola facetada): tiene otro aspecto, no es una versión reducida del mismo árbol.
* **Edificios:** DRIFT/AVENTURA = geometría por módulos de 3 m con una textura atlas de 512 px (más vértices por edificio y UV por baldosa, un material con textura); DREAM CITY = una caja de 5 caras con las ventanas calculadas por un shader de fragmentos (pocos vértices, más cuentas por píxel); PAPEL = cajas de color liso con el material de papel (pocos vértices, sin ventanas texturadas, sólo franjas). Los tres: sin sombras, un MeshInstance por bloque de 150 m.

## 3. Reglas para decidir (cuando haya datos)
* La meta es fluidez: ≈ 60 FPS estables; se prefieren 55–60 estables antes que picos con bajones. Pesan el promedio y, más, el mínimo y los tirones.
* Se compara calidad visual + fluidez + escalabilidad, no sólo cuál rinde más: si dos sistemas dan lo mismo, gana el que se ve mejor; si uno rinde más pero se ve claramente peor, se evalúa la diferencia.
* Si los datos no alcanzan para elegir entre dos sistemas, se dice y se indica sólo qué prueba falta. No se usan FPS de PC ni se inventan consumos.
* Salida esperada: árboles (cercanos, media distancia, lejanos, bosque denso) y edificios (cerca, medio, lejos), con LOD por distancia sólo si los datos lo justifican (0–30 m · 30–100 m · 100 m+). No se implementa en el mundo abierto hasta decidir.
