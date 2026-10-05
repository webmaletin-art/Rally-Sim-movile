# GSkorp Rally — Hoja de ruta

Ideas del dueño del proyecto, ordenadas. Lo marcado ✅ ya está en el juego.

## Hecho en la evolución progresiva (Etapas 1–23)
- ✅ **Vida del mundo** (`docs/WORLD_LIFE.md`, `docs/TRAFICO.md`, `docs/PEATONES.md`, `docs/AUDIO_MUNDO.md`): reloj y semilla deterministas, semáforos, autos estacionados, tránsito civil, rutinas, peatones de papel, clima, audio ambiente; presupuesto de CPU con estrangulamiento automático (`docs/OPTIMIZACION_ANDROID.md`).
- ✅ **Personalización modular** (`docs/PIEZAS_MODULARES.md`): 15 llantas, alerones, paragolpes, difusor, polleras; Mixamo en el menú (`docs/ANIMACIONES_MIXAMO.md`); gomas con desgaste (`docs/DESGASTE_GOMAS.md`).
- ✅ **Mundo abierto** (`docs/MUNDO_ABIERTO.md`): guardarraíles, Ruta Panorámica con gasolineras, superficies, actividades, fama.
- ✅ **Economía online autoritativa** (`docs/ECONOMIA_ONLINE.md`): billetera, autos por instancia, talleres y mercado validados en el servidor.
- ✅ **Arquitectura** (`docs/ARQUITECTURA.md`): dónde vive cada cosa.
- ⏳ Falta probar todo en el APK: Aventura, Dream City, online (regalo diario, taller, mercado), peatones, audio, FPS con «Vida del mundo» SÍ/NO.

## Hecho recientemente
- ✅ **Plaza de Drift física al final de la Ruta 60** (conos con física y puntaje de derrape en el mundo), **hub online con apodo**, **ÚLTIMA UBICACIÓN**, **otros jugadores visibles** (autos de papel con apodo, posiciones cada 2 s), **árboles de ruta de papel cruzado** y **carteles de orientación** en las rutas. Pendiente: fusión física de la Aventura, Realtime para los autos de otros jugadores.
- ✅ **Mundo online (Etapas 1–3)** — sin probar en el APK todavía: modo online con cuenta obligatoria → elegir dónde aparecer → Dream City con **Estacionamiento Central unido a la ruta** (3 salas, rampas, sin teletransporte), salidas abiertas a Aventura (Ruta 20) y Drift (Ruta 60), mapa grande con zoom/arrastre y GPS vivo, calles limpias (sin árboles en la ciudad), rutas con cerco, carteles y horizonte falso, cámara que no atraviesa edificios, faros nuevos, arreglo de parpadeos, editor de controles, FPS opcional, y en la pausa online: **chat mundial/privado con filtro y bloqueos, jugadores, amigos, reportes con evidencia y mercado de autos** (`docs/MUNDO_ABIERTO.md`, `docs/ONLINE_SUPABASE.md`, `tools/online/report_view.py`). Falta: ver a los otros autos en el mapa y fusionar físicamente Drift/Aventura.
- ✅ **Modo online cableado con Supabase** (`docs/ONLINE_SUPABASE.md`): base con RLS y funciones validadas (probada en un Postgres real), cliente del juego con sesión anónima, envío de marcas, rankings y «Probar conexión», compilación que inyecta las claves desde secretos y flujo para aplicar migraciones. Migraciones aplicadas y claves cargadas; falta probarlo en el APK.
- ✅ **Cuenta con correo (opcional)**: se ofrece una vez al primer inicio y vive en Modo online → Cuenta (crear, iniciar sesión, olvidé contraseña, cerrar sesión, borrar cuenta). Suma el correo al usuario anónimo (conserva las marcas). Pendiente: **entrar con Google Play Games** (plugin nativo + cliente OAuth + proveedor Google en Supabase) y **copia del progreso en la nube**.
- ✅ **Primer inicio lindo y sin tirones** (`game/autotune.gd`, `tests/autotune_test.gd`): los gráficos arrancan en automático según el teléfono (GPU, núcleos, memoria, pantalla → nivel bajo/medio/alto) y en el menú se miden los cuadros por segundo unos segundos y se sube o baja un nivel, así la primera carrera ya sale bien. Perfil nuevo: sin efectos de cámara ni filtros y con la cámara de adentro donde se ven piloto y copiloto. Botón «Ajuste automático para mi teléfono» en Opciones → Gráficos.
- ✅ **Mapas fantasía** (`docs/MAPAS_FANTASIA.md`): sección propia en el inicio con el Vórtice de Ensueño, **Marte (Monte Olimpo)**, **la Luna (Mar de la Tranquilidad)** y el **Anillo de Júpiter**, todos en papel (62 piezas nuevas), con cielo propio (planeta, lunas, estrellas), pórticos, escenografía, rivales a la par y su ranking online. Falta probarlos en el teléfono (rendimiento y ritmo de los rivales).
- ✅ **Vórtice de Ensueño** (`docs/MAPA_ENSUENO.md`): mapa fantasía de 9,7 km con subida de 300 m, cresta peraltada, bajada brutal y vuelta inmensa; 61 flores/árboles/bambúes/hongos en papel, cielo con Júpiter, agujero negro en un mar de gas, reflejos de sol, pétalos flotando, arcos de globos y un rival que siempre queda a la par. Carrera rápida y Serie Continental.
- ✅ **Arreglo del export**: las piezas `.pap` del papel no entraban al APK (la selva de Paper Race salía vacía); ahora van con `include_filter`.
- ✅ **Picada de 400 m** (`game/data/drag.gd`, mapa «Picada» en `data/routes.json`): caja manual obligatoria, zona verde de cambio perfecto en la barra de vueltas, rival a la par, dos eventos de copa. Prueba `tests/drag_test.gd`.
- ✅ **Duelo de drift** contra un bot adaptativo (`drift_session.gd`: la mitad del puntaje del bot sigue tu ritmo, con ventaja según el nivel).
- ✅ **Idiomas francés, italiano y alemán** (todos los textos del juego; `tools/i18n/batches/b15…b21`).
- 🗒 **Falta**: voz del copiloto en el idioma elegido (el copiloto hablado todavía no está portado a Godot; ver `docs/PLAN_V1.md`), carreras A→B/checkpoints en la ruta de aventura, y el menú nuevo cuando llegue el zip de assets.
- ✅ **Paper Race** (`docs/PAPER_RACE.md`): pista de papel (papercraft) de 1,9 km con tramos de ruta y tierra y una selva muy tupida hecha con todo el pack de vegetación convertido a papel; en Carrera rápida. Íconos del menú principal guardados en `biblioteca/ui/menu_principal/` para la próxima actualización.
- 🗒 **Plan 1.0 y assets**: `docs/PLAN_V1.md` (decisiones y pendientes), `docs/assets/` (lista de íconos con nombres de archivo, nombres de autos y prompt para generar los PNG sin fondo). Paquete `com.srg.dreamracing`.
- ✅ **Preparado para Google Play** (guía en `docs/PLAY_STORE.md`): preset «Google Play (AAB)» + flujo «Build Play Store AAB» con firma por secretos, API 36, versión automática; versión `store` (sin modo desarrollador, sin prueba de rendimiento, sin descargas ni Internet); compras dentro del juego con Google Play Billing (`store/`, pantalla COMPRAS: `dr_full` + bolsas de créditos); textos legales con compras y web de privacidad/términos; íconos y gráfico de la ficha (`tools/play`, `store_listing/`). Falta: secretos de firma, activar Pages, crear la app y los productos en Play Console, probar compras en «Prueba interna», capturas desde el teléfono.
- ✅ **Pausa nueva** (`ui/race_hud.gd`): panel a la izquierda con botones grandes de a dos (SEGUIR, CÁMARA / AJUSTAR CÁMARA, CINE / OPCIONES, TALLER DE PRUEBA, REINICIAR / SALIR) que se desliza si no entra. «Pruebas y ajustes» pasó a ser **AJUSTAR CÁMARA**: por cada cámara, distancia (largo), altura, lado y ángulo de visión; se guarda en el perfil (`camAdj`). **Cámara libre** de verdad: con el juego en marcha, un dedo arrastrando gira y dos dedos pellizcando acercan (`controls.gd` → `camera_rig.gd`).
- ✅ **Guías fáciles de ajuste**: debajo de cada barra del taller (y del taller de prueba) dice qué pasa si la bajás (▼) y si la subís (▲), en palabras para quien no sabe de autos (campos `lo`/`hi` de `data/catalog.json`).
- ✅ **Taller de prueba** (`ui/lab_panel.gd`): en la pausa de las pruebas de autos de la tienda y de Carrera rápida (incluida la plaza de drift): potencia, peso, resistencia al aire, agarre total, gomas, presión, caída, convergencia, altura, resortes, amortiguación, barras, recorrido, frenos, dirección, reparto de tracción, diferencial, relación final y aerodinámica, todo liberado y sin guardar. Cada cambio rearma el auto en el mismo lugar. Esas pruebas no dan premios ni cuentan para récords.
- ✅ **Tienda y pruebas**: el DR Bisonte XR (el de la aventura) se ve en la tienda como el más caro ($250.000) y se puede probar, pero se compra recién al terminar la aventura (en modo desarrollador se compra); todos los autos se prueban en Asfalto, Tierra o Drift antes de comprar, y Carrera rápida tiene selector de auto (los de la tienda se prueban sin premios).
- ✅ **Carrera rápida → «Ruta de los Sueños (aventura)»**: elegís la etapa y la corrés completa como práctica (estado descartable `AdvData.practice`: no toca el avance ni da premios; vuelve a Carrera rápida).
- ✅ **Sonido**: las explosiones de escape ya no suenan sin parar («tractor»): enfriamiento entre ráfagas y solo en cambios bajos o al levantar el pie.
- ✅ **Prueba de rendimiento completa** (menú de inicio → RENDIMIENTO; `game/perf_bench.gd`, `ui/menu_perf.gd`, `ui/perf_results.gd`): maneja sola por el Lago, el Bosque (solo en la completa) y la plaza de drift. Mide primero sin filtros de cámara (autos, resolución, sombras, hilos, árboles), después cada cámara, cada componente apagado y por último el lente y cada efecto solo y en combos; repite la base al final para detectar calentamiento. Rápida ≈ 4 min, completa ≈ 8 min. El informe queda copiado al portapapeles, en pantalla (con botón COPIAR TODO) y en `user://informe_rendimiento.txt`. Para probarla en la compu: `PB_FAST=1 godot … -- --menu --perf=quick|full`.
- ✅ **Pista de drift grande** (`godot/game/track/drift_track.gd`): playón de 240 × 240 m con aros pintados y conos con física (`cone_field.gd`: salen volando y quedan tirados), paredes, y por la boca del norte una ciudad chica con avenida, rotonda con isla y árboles, calles, manzanas de edificios con ventanas, veredas, faroles y cruces. Sesión de drift (`drift_session.gd`): puntos por ángulo × velocidad, combo hasta ×5, los conos bajan el multiplicador y chocar pierde el derrape. Va en la Carrera (eventos d5, n5, c4) y en Carrera rápida (pista «Drift Plaza»). Falta: público/tribuna, más eventos de drift, el estacionamiento de varios pisos (esperando los modelos de Sweet Home 3D).
- ✅ **Autos nuevos limpios**: los GLB originales eran mallas cerradas; ahora se sueldan los vértices y se rehace la piel con voxeles antes de reducir (sin rajaduras negras ni paragolpes arrugados). Interior con el mismo encuadre que los autos viejos y jaula alineada con los parantes. Pilotos con 30 % menos de calidad (70 % de triángulos, texturas de 768 px).
- ✅ **Cierres del juego**: había una carrera de hilos al armar el terreno (cada hilo anotaba su vista en una lista compartida) que corrompía la memoria; corregida (0 abortos en 56 corridas, antes ~25 %).
- 🚧 **Migración a Godot** (carpeta `godot/`, ver `godot/README.md`): física portada y verificada contra la versión HTML; APK liviano que descarga el juego; prueba de rendimiento en camino. La versión HTML se retira cuando la de Godot la iguale.
- ✅ **Interior más real**: habitáculo más ancho (menos ventanilla a los costados), capó ancho y largo que se ve de punta a punta, cámaras de adentro con ángulo de simulador (antes se veía casi todo el habitáculo), display del tablero más chico.
- ✅ **Freno de mano**: palanca más adelante y el codo va para atrás al tirar (antes se deformaba el brazo). **Copiloto** se ataja con la mano en el tablero en las frenadas fuertes.
- ✅ **Android**: la ventana se configura una sola vez (antes titilaba) y las barras se esconden al instante si aparecen.
- ✅ **Silbido metálico de la caja** (engranajes rectos de rally): sube con la velocidad, se nota más al levantar el pie y se corta en cada cambio. Distinto por auto. Volumen en Opciones → Caja de cambios.
- ✅ **Turbo**: silbido que sube con la carga (con retardo, como un turbo de verdad) y «flutter» (tu-tu-tu) al soltar el acelerador y entre cambios. Cada auto suena distinto (el camión grave y lento, el Genesis agudo y rápido); la mejora de turbo lo hace más fuerte. Volumen en Opciones → Turbo.
- ✅ **Interior con techo alto** en las dos cámaras interiores (atrás del piloto y casco): techo, marco y jaula 12 cm más arriba y el espejo más alto, así no tapa el horizonte. Elegido por el dueño. Las cámaras «Chasis 3D» se quitaron; la cabina 3D queda solo como respaldo en biblioteca/modelos/cabina_base.glb.
- ✅ Android: los botones del sistema se vuelven a esconder solos si aparecen; los bordes de abajo no disparan el gesto de «atrás».
- ✅ Pantalla de ajuste antes de correr con barritas; controles en pantalla movibles; manos que cambian de agarre; neutro; calibración del acelerómetro.
- ✅ Pilotos más vivos: el cuerpo se va para atrás al acelerar, para adelante al frenar y al costado en curva; mano al freno de mano y a la palanca, pie derecho en acelerador/freno (sin atravesar el piso); el copiloto mira al frente con movimientos chicos de cabeza.
- ✅ Menos humo de ruedas (para teléfonos gama baja) y vibración regulable de la «Cámara de acción cruda» (Opciones → Vibración de la cámara cruda).
- ✅ Biblioteca: pack de Mesh2Motion (178 animaciones CC0, esqueleto Mixamo) en biblioteca/animaciones/mesh2motion.
- ✅ **Optimización para celulares**: humo con tamaño tope (antes crecía sin límite y tapaba la pantalla), pilotos livianos cuando se ven desde afuera (de 55.000 a 13.000 triángulos), tripulaciones fuera de cámara sin cálculo, sombras reales solo para tu auto (Máxima: todos), búsqueda de pista 6× más rápida, calidad automática apuntando a 60 FPS.
- ✅ **IA más real**: mide bien las curvas (antes subestimaba el vértice), deja margen de agarre como un piloto, no clava el volante ni cruza la cola, se pone prudente después de un susto y no pasa en curva. Casi no se salen de la pista y van más rápido.
- ✅ Génesis más alto: 40 cm libres al piso, ruedas de 40" en llantas de 18", amortiguadores que ya no atraviesan el capó.
- ✅ Mundo abierto: el cruce de las dos rutas ya no es una loma que te hace volar; bordes de ruta más suaves. Unión de las pistas cerradas sin escalón.
- ✅ **Duelos en el mundo abierto**: el Buitre, la Hiena, la Sombra y el Tanque en sus bases (trompos, saltos en rampa, ochos). Te acercás despacio → RETAR → escena con voces → arcos de control de a uno (5 a 10) → premio en efectivo. Los que no conociste en la historia te piden avanzar primero.
- ✅ Copiloto con 756 frases según la situación (Opciones → Charla del copiloto).
- ✅ Modo historia capítulos 2 a 4 (12 misiones) con voces por personaje.
- ✅ Genesis con el modelo 3D del dueño (el conceptual queda guardado: GENESIS_CONCEPT en main.js) y cubierta limpia.
- ✅ Pasto, cinta y estacas ya no atraviesan el auto.
- ✅ Android: pantalla completa y siempre horizontal.
- ✅ Pantalla de carga con consejos (menús, modos, efectos, mecánicas) y carga de pistas más rápida.
- ✅ Pausa: silencio total; cámara en vivo al cambiarla.
- ✅ Autos iniciales con limitador de fábrica (170 km/h) que se libera en el Taller; cajas escalonadas reales.
- ✅ Vista previa de efectos con tu auto andando.
- ✅ Espejos retrovisores (central + laterales), opción para apagarlos; cámara trasera en pantalla opcional (apagada por defecto).
- ✅ Estilo visual **Cámara de acción cruda** (grano, viñeta, imagen blanda, bruma verdosa, vibración). El estilo "Claude" queda igual.

## En curso (esta tanda)
- ✅/🔧 Menú de opciones: scroll arreglado, calidad **Auto (optimizar)** / Alta / Media / Baja.
- 🔧 Efectos de cámara (GoPro, casero, cine…) en un submenú aparte: lista → explicación + vista previa → Volver / Aplicar.
- 🔧 Piloto: hombro sin deformarse, mete los cambios con la mano, reacciones a fuerzas G más fluidas (frenada brusca o progresiva, volantazo, choque).
- 🔧 Cajas de cambios reales: 1ª → 2ª → 3ª… según velocidad; reducción al frenar.
- 🔧 **Trinchera**: red de caminos hundidos (tipo cañón/mina vieja) dentro del mundo abierto, anchos para dos autos, asfalto y tierra, desvíos que se vuelven a unir, tramos subterráneos (túneles), entrada y salida al mundo abierto. Carrera de trinchera.

## Pendiente (cuando el juego base esté terminado)
### Mundo abierto con misiones (estilo MTX)
- Todas las pistas encajadas en el mundo abierto. **Cómo funciona:** al abrir el Mundo abierto se carga el mundo con todas las pistas como zonas; al jugar una carrera suelta (rápida, contrarreloj, modo carrera o historia) se carga SOLO esa pista, con sus límites (paredes, cinta, terreno), sin dibujar el mundo entero. Hoy ya es así con La Trinchera (entrada desde el mundo).
- Al acercarse a una zona aparece su misión: pista de drift → misión de drift; trinchera → carrera de trinchera; radares, saltos, etc.
- Indicadores en el mapa y en el minimapa para invitar a recorrer.
- Se mantiene también el acceso por menú (partidas cortas en el celular).

### Próximo
- **Autos bloqueados**: prompts para ChatGPT (carrocería + cubierta de cada uno) en docs/prompts/autos_bloqueados.md. Esperando los GLB del dueño.
- **Interior del auto**: el dueño va a pasar material para rehacerlo (volante, tablero, palanca, espejos).
- **Ajustes finos del interior** (cuando el dueño diga): el habitáculo quedó con el techo alto (12 cm, espejo más arriba) en las dos cámaras interiores, elegido por el dueño por ser más inmersivo. Falta afinar «un par de cositas».
- **Público en el drift**: pared con colisión + tribuna con gente mirando el centro (animaciones Idle_Rail / Cheering de Mesh2Motion).
- Escenas con personajes hablando (Mesh2Motion: Idle_Talking, Head_Nod, Angry, Victory…).

### Personajes 3D (esperando los modelos)
- Lista y requisitos en docs/prompts/personajes.md: 11 personajes + pack de animaciones.
- Escenas con gestos al retar y al terminar los duelos; el rival te entrega su auto la primera vez que le ganás; escenas del modo historia.

### Modo historia
- ✅ **Capítulo 1 · La Fuga** (cinemática manejada por la IA con varias cámaras, voces con subtítulos, salto en cámara lenta, control en el túnel, perseguidores que embisten, barra del auto 100% → 0%, "Siguiente misión: próximamente").
- Próximos capítulos: seguir la historia de la mina.
- Al elegir "Modo historia": secuencia inicial manejada por la IA (no video): persecución por un rally rival o la policía.
  - Muestra la física: acelerones, frenadas, derrapes en tierra, cámara interior con el piloto metiendo 1ª-2ª-3ª, el perseguidor que embiste.
  - Entra a la trinchera/subterráneo (mina vieja) y a los pocos km le da el control al jugador.
- Primera misión: salir del subterráneo con el enemigo embistiendo. Barra de daño 100% → si llega a 0% misión fallida; llegar con daño restante = completada.
- Lore de las pistas (la mina, las arterias subterráneas) que se va ampliando con más capítulos.
- Modo libre: mundo abierto, misiones, carreras, pista, drifting.

### Autos
- Modelos 3D pendientes: Titan Raptor X (camioneta), Colossus 6x6 (camión) y los 6 bloqueados de la concesionaria. Prompt de diseño en docs/prompts/autos_3d.md.

### Arranque
- Detección automática del teléfono y calidad "Optimizar" por defecto (✅ en esta tanda).
- Tutorial breve al elegir el primer auto.

## Dream City (mundo abierto en papel)
Base lista (calles numeradas, atajos, casco viejo, cuadras de carga, fachadas, minimapa que gira, mapa grande, GPS). Ya tiene locales entrables, túnel y estacionamiento subterráneos, 4 gasolineras con nafta (se paga con créditos) y ciclo de día y noche. Pendientes y diseño online en `docs/MUNDO_ABIERTO.md`.
