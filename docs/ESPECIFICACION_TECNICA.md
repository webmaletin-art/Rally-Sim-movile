# GSkorp Rally — Especificación técnica

## En una línea
Es un juego **web (HTML5 + JavaScript)** con gráficos 3D en **WebGL usando Three.js**. Se empaqueta como **app de Android con Capacitor**. No usa Unity, Unreal ni Godot: el motor del juego (física, IA, cámaras, sonido) está programado a mano en JavaScript.

## Tecnologías
| Parte | Qué se usa |
|---|---|
| Lenguaje | JavaScript moderno (ES Modules), HTML5 y CSS. Sin TypeScript y sin frameworks (ni React ni similares). |
| Gráficos 3D | **Three.js r160** sobre **WebGL**, incluido en `vendor/` (funciona sin internet). |
| Física | Motor propio a **120 pasos por segundo** (paso fijo). |
| Sonido | **Web Audio API**. El motor, turbo, caja, ruedas, viento y golpes se sintetizan en vivo, sin grabaciones. |
| Voces | Copiloto e historia: frases pregeneradas con **Piper TTS** (voz en español) y guardadas como `.ogg`/`.wav`. |
| Modelos 3D | Formato **GLB (glTF)**, optimizados con gltf-transform + meshoptimizer. Cada uno tiene versión liviana (`_lo`). |
| App Android | **Capacitor 8**: el juego corre dentro del WebView de Android, que es Chrome. `MainActivity.java` propia para pantalla completa y horizontal. |
| Compilación | **GitHub Actions** (Node 22, Java 21, Gradle): cada cambio en `main` genera el APK automáticamente. |
| Guardado | `localStorage` del teléfono: autos, plata, mejoras, ajustes y progreso de la historia. |

## Cómo corre
1. Android abre la app y el WebView carga `index.html` (el juego).
2. Se cargan los modelos 3D (pilotos y autos) y aparece el menú con el garaje en 3D.
3. **Bucle principal**, sincronizado con la pantalla (`requestAnimationFrame`, 60 fps o lo que dé el teléfono):
   - **Física a 120 Hz** (paso fijo, independiente de los FPS): si un cuadro tarda más, se hacen más pasos de física, así el auto se maneja igual en cualquier teléfono.
   - **IA** de los rivales, cámaras, pilotos animados, partículas y sonido.
   - **Dibujado** con Three.js y, si están activados, efectos de cámara, espejos y cámara trasera.
4. **Controles:** táctiles (volante, pedal, cambios, freno de mano y nitro, movibles y agrandables), inclinación del teléfono (acelerómetro/giroscopio, con calibración) y teclado si se juega en PC.

## Cómo funciona por dentro

### Física del auto
- **Cuatro ruedas independientes.** Cada una tiene suspensión (resorte, amortiguador, barra estabilizadora y recorrido), contacto con el piso y velocidad de giro propia.
- **Neumáticos.** Fórmula tipo **Pacejka simplificada** («magic formula»): la fuerza depende de cuánto patina la rueda hacia adelante y de costado. El agarre cambia según la superficie (asfalto, tierra, pasto, barro), la carga sobre la rueda, la presión y la caída (camber).
- **Motor y transmisión:**
  - curva de torque, turbo y limitador;
  - caja automática o manual secuencial, con neutro y reversa;
  - embrague, diferencial autoblocante y reparto de tracción (delantera, trasera o 4x4).
- **Carrocería:**
  - masa, centro de gravedad e inercia;
  - aerodinámica (carga y resistencia);
  - vuelco, saltos y aterrizajes.
- **Ayudas:** ABS, control de tracción y de estabilidad, regulables.
- **Mejoras y ajustes:** cambian los números de la física (potencia, peso, resortes, relación final, etc.). No son solo cosméticas.

### Pistas y mundo
- Se generan por código a partir de curvas: circuitos, tramos de rally, bajada con badenes, mundo abierto con rutas, trinchera con túneles, estacionamiento y drift.
- Tipos de superficie por zona. Clima (lluvia) y hora del día.

### Rivales (IA)
- **Seguimiento de la trazada:** el rival mira un punto adelante en el camino y gira hacia él.
- **Perfil de velocidad:** calcula a cuánto puede entrar a cada curva según el agarre real, los saltos y las lomas.
- **Corrección:** corrige sobreviraje y subviraje.
- **Carrera:** adelanta, respeta al que tiene adelante y tiene distinta habilidad por rival.

### Pilotos
- **Modelos:** piloto y copiloto 3D con esqueleto (compatible Mixamo), animados con **cinemática inversa**. Las manos siguen el volante (mano sobre mano), la palanca y el freno de mano, y los pies los pedales.
- **Reacciones:** el cuerpo reacciona a las fuerzas G (acelerar, frenar, curvas y saltos) y el copiloto se ataja en frenadas fuertes.

### Cámaras
- Afuera (varias distancias), capó, paragolpes, cámara libre y dos interiores: casco y atrás de los pilotos.

### Sonido
- **Motor:** osciladores que siguen las vueltas y la carga.
- **Turbo:** carga con retardo, silbido y flutter.
- **Caja:** silbido metálico de engranajes rectos.
- **Ruedas:** chirrido, grava y pasto.
- **Ambiente:** viento, golpes y explosiones de escape.
- **Volumen:** cada uno tiene su volumen en Opciones.

### Modos de juego
- Carrera contra IA, contrarreloj, drift, estacionamiento, rush de banderas y radar de velocidad.
- Mundo abierto con duelos contra rivales.
- Modo historia con 4 capítulos, cinemáticas y voces.
- Prueba de manejo.

### Rendimiento
- **Calidad:** Baja, Media, Máxima u **Optimizar**. Optimizar analiza el teléfono una sola vez y deja la calidad fija, sin cambiarla en carrera.
- **Modelos livianos:** se usan de lejos o en teléfonos débiles.
- **Humo y efectos:** con tope.
- **Teléfonos débiles:** las sombras, los espejos y los efectos se apagan.

## Organización de archivos
| Archivo o carpeta | Contenido |
|---|---|
| `HTML base Rally GSkorp.html` | Página del juego: pantallas, HUD y arranque. |
| `js/main.js` | Núcleo: física, pistas, autos, cámaras, sonido y bucle principal. |
| `js/cockpit.js` | Interior del auto y tripulación animada. |
| `js/pilot.js` | Esqueleto del piloto y cinemática inversa. |
| `js/ai.js` | IA de carrera. |
| `js/duels.js`, `js/duel_data.js` | Duelos del mundo abierto. |
| `js/story.js`, `js/mission.js`, `js/story_data.js` | Modo historia. |
| `js/copilot.js`, `js/pacenotes.js`, `js/codriver.js` | Notas y voces del copiloto. |
| `js/ui.js`, `css/ui.css`, `js/hudedit.js`, `js/gyrowiz.js` | Menús, opciones, editor de controles y calibración. |
| `js/data.js`, `js/carbuild.js`, `js/profile.js`, `js/events.js` | Autos, mejoras, ajustes, guardado y eventos. |
| `js/post.js` | Efectos visuales de cámara. |
| `models/` | Modelos GLB (autos, llantas y piloto; unos 5 MB). |
| `audio/` | Voces del copiloto (756 frases) y de la historia (unos 10 MB). |
| `vendor/` | Three.js. |
| `android-src/MainActivity.java` | Pantalla completa de Android. |
| `.github/workflows/build-apk.yml` | Compilación automática del APK. |
| `tools/` | Scripts para generar voces y procesar modelos 3D. |
| `biblioteca/` | Respaldo de modelos y animaciones (no va en el APK). |

## Números
- **Código:** unos 600 KB de JavaScript en 21 módulos.
- **Recursos:** unos 16 MB de modelos, sonido y librerías.
- **Física:** 120 Hz. Objetivo de 60 fps en celulares de gama media y baja.
- **Requisitos:** Android con WebView actualizado (Chrome) y WebGL.

## Cómo probarlo en PC
En la carpeta del repositorio: `python3 -m http.server 8000`. Después abrir en el navegador `http://localhost:8000/HTML base Rally GSkorp.html` (con teclado: flechas o WASD).
