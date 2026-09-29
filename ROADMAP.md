# GSkorp Rally — Hoja de ruta

Ideas del dueño del proyecto, ordenadas. Lo marcado ✅ ya está en el juego.

## Hecho recientemente
- ❌ **Cámaras «Chasis 3D» quitadas** (no convencieron). La cabina 3D queda solo como respaldo en biblioteca/modelos/cabina_base.glb. El interior dibujado sigue como estaba.
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
- **Interior del auto**: el dueño va a pasar material para rehacerlo (volante, tablero, palanca, espejos).
- ⏳ **PENDIENTE — techo en la cámara «Interior (atrás del piloto)»** (regla del dueño):
  - Solo en esa cámara, donde se ven los dos: esconder un poquito más para arriba la parte del techo que queda en el borde de arriba de la pantalla (la de atrás, sobre la cabeza), para que no se sienta «el techo en la frente».
  - NO agrandar el parabrisas, NO estirar nada, NO mover el espejo: el parabrisas y el marco de adelante quedan exactamente como están.
  - La cámara del conductor («Onboard (casco)») no se toca: está bien como estaba.
  - Un poquito nomás, sin agrandar nada. (Un intento subiendo todo el techo 12 cm fue rechazado: estiraba el parabrisas y el espejo.)
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
