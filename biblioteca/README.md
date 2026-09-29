# Biblioteca de personajes y animaciones

Archivos de origen para usar en este juego y en proyectos futuros.
**Esta carpeta NO va dentro del APK**: el build solo empaqueta `vendor`, `models`, `audio`, `js` y `css`.
Cuando un personaje o animación se usa en el juego, se convierte, se achica y se copia a `models/`.

## Estructura

```
biblioteca/
  personajes/
    hombres/   mujeres/   otros/
  animaciones/
    parado/        idle, respirar, esperar
    hablar/        hablar, discutir, reírse
    gestos/        señalar, brazos cruzados, sí/no con la cabeza, encogerse de hombros, bronca
    festejo/       victoria, puño arriba, aplaudir
    derrota/       manos en la cabeza, decepción, patear el piso
    interaccion/   dar/recibir objeto, apretón de manos, saludar, apoyarse, hablar por teléfono/radio
    caminar/       caminar, trotar, correr (siempre "In Place")
    conducir/      sentado manejando, subir/bajar del auto
    accion/        saltar, caer, esquivar (para otros juegos)
    otras/         todo lo que no entre arriba
  indice.md        lista de lo que hay (se actualiza con cada descarga)
```

## Cómo bajar de Mixamo (para la sesión que descarga)

1. Iniciar sesión con la cuenta que dé el dueño. **Nunca** escribir la contraseña en ningún archivo del repo.
2. **Personajes** → `personajes/<hombres|mujeres|otros>/`
   - Format: **FBX Binary (.fbx)** · Pose: **T-pose**
   - Nombre: `nombre_en_minusculas.fbx` (ej. `personajes/mujeres/kaya.fbx`)
3. **Animaciones** → `animaciones/<categoria>/`
   - Bajarlas con el personaje estándar **Y Bot** seleccionado (así todas comparten el mismo esqueleto).
   - Format: **FBX Binary (.fbx)** · Skin: **Without Skin** · Frames per Second: **30** · Keyframe Reduction: **none**
   - Caminar/trotar/correr: marcar **In Place**.
   - Nombre: el de Mixamo en minúsculas y con guiones bajos (ej. `animaciones/hablar/talking_01.fbx`).
4. Anotar cada archivo en `indice.md`: carpeta, nombre, nombre original en Mixamo y una línea de qué hace.

## Límites (importante)

- GitHub no acepta archivos de más de **100 MB**.
- Este repo se clona completo en cada sesión y en cada build del APK. Hay que mantener la biblioteca **por debajo de ~1 GB**. Si se quiere bajar TODO Mixamo (miles de animaciones, varios GB), va en un repositorio aparte y privado.
- La licencia de Mixamo permite usar las animaciones en tus juegos, pero no publicar los archivos sueltos. Por eso el repo tiene que ser **privado**.
