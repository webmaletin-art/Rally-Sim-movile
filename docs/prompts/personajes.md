# Personajes 3D y animaciones: qué necesito

Para las escenas del modo historia y de los duelos del mundo abierto. Los personajes aparecen parados al lado de los autos, hablan con gestos, festejan, se enojan y te entregan las llaves.

## Personajes (11 + 1 opcional)

| # | Archivo | Personaje | Cómo es |
|---|---------|-----------|---------|
| 1 | `protagonista_h.glb` | **Correa** (vos), versión hombre | 25–30 años, buzo de rally, campera abierta, guantes. |
| 2 | `protagonista_m.glb` | **Correa**, versión mujer (opcional) | La misma ropa y edad. Así el jugador elige. |
| 3 | `tano.glb` | **Tano Bustos**, tu copiloto | Unos 55 años, bigote, gorra, campera de rally gastada y un casco en la mano o colgado. |
| 4 | `viejo.glb` | **Aníbal "El Viejo" Correa**, tu padre | Unos 65 años, barba gris, campera de cuero vieja. Leyenda del rally. |
| 5 | `buitre.glb` | **Horacio Salvatierra, "El Buitre"**, el villano | Unos 58 años, flaco y alto, sobretodo oscuro, anteojos negros, prolijo. |
| 6 | `hiena.glb` | **La Hiena** | Mujer de unos 30 años, ruidosa, campera fucsia y negra, pelo corto y parado. |
| 7 | `tanque.glb` | **El Tanque**, camionero | Hombre enorme de unos 45 años, barba, chaleco, brazos gruesos. |
| 8 | `sombra.glb` | **La Sombra** | Mujer de unos 32 años, callada, traje de piloto violeta oscuro, capucha o el casco en la mano. |
| 9 | `aldo.glb` | **Don Aldo**, el mecánico del taller | Unos 70 años, delantal o overol, trapo en el bolsillo. |
| 10 | `cuervo_1.glb` | **Cuervo** (secuaz), hombre | Campera negra con un cuervo en la espalda. Se reutiliza para varios secuaces. |
| 11 | `cuervo_2.glb` | **Cuervo** (secuaz), mujer | La misma ropa. |
| 12 | `publico.glb` | **Público** (opcional) | Una o dos personas comunes para poner al costado de las pistas. |

## Requisitos de cada archivo

- **Formato:** `.glb` (un personaje por archivo), con las texturas adentro.
- **Esqueleto humanoide.** Tiene que ser **el mismo esqueleto que el pack de animaciones**.
  - Lo ideal es el de Mixamo (huesos `mixamorig:Hips`, `mixamorig:Spine`…).
  - Si el pack usa otro esqueleto, avisame cuál es, y que todos los personajes usen ese.
  - Con dedos, para los gestos.
- **Pose, escala y orientación:**
  - En T o en A, parado, con los pies en el piso (Y = 0), mirando hacia adelante (+Z).
  - Tamaño real en metros (1,60 a 1,95 m).
- **Para celular:**
  - 8.000 a 20.000 triángulos por personaje (30.000 como máximo).
  - Uno o dos materiales, con textura de 1024×1024 (2048 como máximo).
- **Solo el personaje.** Nada de luces, cámaras ni piso.
- **Cara (si se puede):** "blendshapes" o "morph targets" de boca (`jawOpen`, o visemas `aa`, `oh`, `ee`) y parpadeo. Con eso muevo la boca cuando hablan. Si no los tiene, alcanza con un hueso de mandíbula, y si tampoco, animo la cabeza y las manos.

## Animaciones que voy a usar del pack

Los nombres no importan, los renombro yo. Me sirven en FBX o GLB, con o sin malla, siempre que usen el mismo esqueleto.

**Para hablar (lo más importante):**
- parado respirando (2 variantes)
- hablando: normal, discutiendo o enojado, y riéndose
- escuchando o asintiendo con la cabeza, y negando con la cabeza
- brazos cruzados
- señalando a alguien
- encogerse de hombros
- puño cerrado o gesto de bronca
- carcajada

**Para ganar y perder:**
- festejo (puño arriba o saltito) y aplausos
- derrota: manos en la cabeza, patear el piso

**Con el auto y entre personajes:**
- entregar un objeto (las llaves) y recibirlo
- apretón de manos (opcional)
- apoyado contra el auto (o contra una pared)
- hablar por radio o teléfono (mano en la oreja)
- saludar con la mano

**Moverse:**
- caminar normal, caminar hablando y trotar corto

## Dónde van

- **Duelos del mundo abierto:**
  - Cada rival espera parado al lado de su auto en su base.
  - Al retarlo, hay una escena corta de los dos cara a cara.
  - Si le ganás por primera vez, te da las llaves y te regala su auto pintado con sus colores.
- **Modo historia:**
  - Escenas cortas al empezar y al terminar cada misión, con Tano y los villanos.
  - Por ejemplo: el Buitre te entrega su auto cuando le ganás, y la Sombra te da la mano.
- **Taller:** Don Aldo te recibe en el taller.

## Cómo pasármelos

En varias partes, como te quede cómodo. Por ejemplo:

1. Protagonista(s), Tano y El Viejo
2. Buitre, Hiena y Tanque
3. Sombra, Don Aldo y los Cuervos
4. El pack de animaciones

Si algún personaje trae sus propias animaciones, también me sirven. Yo reviso cada archivo, lo achico para el celular y lo acomodo.
