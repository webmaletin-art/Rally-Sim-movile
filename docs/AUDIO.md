# Sonido del auto — qué hay, cómo se mide y qué se arregló

El sonido del auto del jugador lo arma `godot/game/audio/car_audio.gd` (el del mundo abierto, `world_ambient.gd`, está en `docs/AUDIO_MUNDO.md`). No sintetiza nada en tiempo real: reproduce
**muestras cortas en bucle** (`godot/game/audio/samples/*.wav`, las genera `tools/godot/make_audio.py`) y sólo cambia el volumen y la velocidad de reproducción de cada una según la física
(motor de audio en C++: casi no gasta procesador y no se corta).

| Voz | Muestra | Qué es |
|---|---|---|
| `engine` | ciclo de 1050 muestras | el motor (5 osciladores + modulación + saturación); la velocidad sigue las vueltas |
| `engnoise` | ruido 12 s | ruido mecánico del motor (sube con la carga) |
| `roll` | ruido 24 s | rodado de las gomas sobre asfalto (retumbo grave, sube con la velocidad hasta 108 km/h) |
| `gravel` | crujidos + ruido 24 s | tierra / ripio / pasto |
| `squeal` | ruido de banda angosta 12 s | chillido de gomas al derrapar en asfalto |
| `wind` | ruido grave 24 s | soplido del aire, sube con la velocidad (casi nada hasta 20 km/h) |
| `rain` | ruido + gotas 24 s | lluvia (carrera con lluvia y clima del mundo abierto) |
| `turbo` | ruido 12 s | soplido del turbo |
| `whistle` | seno | silbido del turbo |
| `whine1/2`, `gwe` | seno / triángulo | zumbido de la caja de cambios |
| flutter, pop, thump | un disparo | «tu-tu-tu» al soltar con turbo, petardeos, golpes |

## Motor por capas, caja, freno motor y estampidos (14/10/2026, pedido del dueño)

*«Los sonidos son muy finos, muy robóticos; quiero oír motor real, caja de cambios, turbo… como en Real Racing; la caja hace un silbido muy bonito al acelerar y en inercia;
el freno motor al soltar; si piso el acelerador de manera intermitente hace explosiones y se siente el poder del motor».*

- **Por qué sonaba a robot:** el motor era UN ciclo de 1050 muestras repetido idéntico (5 osciladores + saturación). Un motor de verdad son explosiones sueltas, cada una distinta.
- **Ahora** (`tools/godot/make_engine_audio.py` → `eng_on0..6`, `eng_off0..6`, `overrun`, `gearwhine`, `backfire`): bucles de 2,5 s fabricados explosión por explosión a 7 frecuencias de encendido
  (32 → 750 Hz: de un V8 en ralentí a un V12 al corte), **con carga** (acelerando: más abierto, admisión y ruido mecánico) y **sin carga** (soltando: pulsos débiles y desparejos, alguna que falla,
  más apagado = freno motor). Cada explosión varía en tiempo (±1–3 %) y fuerza; cada cilindro empuja distinto (patrón de 4) → el ronroneo grave por debajo de la frecuencia de encendido;
  el escape son resonancias de los tubos (115/340/780/1650 Hz) y un silenciador. `car_audio.gd` toma los dos bucles más cercanos a la frecuencia de explosiones real
  (`rpm/60 × cilindros/2`; `firingOrder` es la cantidad de cilindros) y los mezcla a igual potencia, y pasa de «con carga» a «sin carga» según el pedal y la carga.
- **Caja** (`gearwhine`): engranajes rectos con armónicos 2 y 3, bandas laterales y temblor (no un seno quieto), sube con la velocidad, más fuerte soltando (inercia) y en 1ª–2ª; fundamental ≤ 1,5 kHz;
  un tono quieto baja hasta la mitad. Medido: soltando −42 (hatch) … −32 dBFS (Veltor GTR); parejo a 220 km/h ≤ −41.
- **Freno motor** (`overrun`): crepitar del escape soltando con vueltas (más con más vueltas).
- **Estampidos** (`backfire`): al soltar desde vueltas altas; pisando y soltando seguido salen más y más fuertes (hasta 4 por vez, cada 0,45 s como mínimo). El soplido del turbo al soltar suena en
  cualquier marcha (antes sólo en 1ª–2ª).
- **Turbo:** silbido +1,6 dB y soplido +1 dB (dentro de los topes de la prueba).
- **Sonoridad medida** (`audio_render` acelerando, dBA): hatch −23,3 (antes −27,6), muscle −21,3, Veltor GTR −20,8; las bandas graves (< 400 Hz) ahora pesan como en un motor de verdad.
- **«Audio simple»** sólo si el jugador lo pide: antes se prendía solo tras un cierre de golpe, pero el registro mostró que el cierre no era del audio y así el dueño no oía el sonido nuevo.
  El audio simple sigue usando el motor de antes (un ciclo, liviano). `DR_OLD_ENGINE=1` en las pruebas compara con el de antes.
- **Pruebas:** `audio_levels_test` (nuevo: la caja con armónicos ≤ 1,5 kHz, bajo tope andando, se oye al soltar sin tapar al motor, baja si queda quieta, parado no suena); `audio_render --scene=blips` (pisar y soltar).

## Qué pasaba («viento fuerte que se repite» y «silbido que se queda»)

El dueño avisó: *«algo se pone en loop y suena feo como si fuera viento fuerte… un silbido se queda en loop»*. Se midió grabando lo que suena (ver abajo) y se encontró:

1. **Todos los ruidos eran bucles de 2 s EXACTOS** (correlación 1,0000 entre una vuelta y la siguiente). El rodado de las gomas, que a velocidad de ruta es lo más fuerte después del motor,
   volvía idéntico cada 2 s: un retumbo parejo de ~400 Hz que se repetía. A 140 km/h estaba a sólo 3,6 dB del motor.
2. **Los ruidos de fondo sonaban tan fuertes como el motor** (todos en dBA, medidos de a uno): rodado −31,5 (motor −27,9), tierra −30,3, lluvia −29,5 (y en el mundo abierto con tormenta aún más fuerte:
   hasta −23 dBFS de siseo). Eran bandas anchas con mucho en 1–8 kHz, justo donde el oído y el parlante del teléfono son más sensibles: un «shhhh» continuo = viento.
3. **El silbido era un seno puro**: a fondo en una ruta el silbido del turbo se clavaba en **8 kHz** (42 dB por encima del resto del espectro) y no se movía mientras el turbo estuviera cargado;
   el zumbido de la caja seguía a la velocidad hasta 4,2 kHz (se medió una línea fija en 4,1–4,2 kHz durante 22 s). Un tono puro que no cambia es un silbido.
4. **Los controles no controlaban**: «Viento» sólo afectaba al viento (que a valor normal casi no se oía: −73 dBA); el rodado y la lluvia no tenían control, y «Gomas y tierra» sólo la tierra.
   Aunque el dueño bajara «Viento» no cambiaba nada de lo que oía.
5. Chico: la tierra cambiaba de volumen al azar en cada cuadro (temblor), y los golpes graves podían encadenarse al rozar una pared.

## Qué se cambió

- **Bucles largos y parejos**: rodado, tierra, viento y lluvia de 24 s; soplido, chillido y ruido del motor de 12 s. Todos son ruido hecho en el dominio de la frecuencia (exactamente periódico: el bucle
  no tiene costura) y arrancan en un punto al azar. Adentro no se repiten (parecido entre tramos < 0,2, antes 1,0). Los de abajo de 1 kHz se guardan a 22,05 kHz.
- **Formas más suaves**: el rodado es un retumbo (pasabanda 330 Hz con corte fuerte arriba de ~1 kHz, antes llegaba hasta 3 kHz); la tierra son **crujidos de piedritas** sobre un colchón medio (antes ruido
  blanco filtrado en 2,5 kHz); la lluvia no tiene nada arriba de 7 kHz y lleva gotas sueltas; el soplido del turbo es de banda ancha (2,6 kHz, Q 1) y el viento queda entre 120 y 900 Hz.
- **Niveles**: todos los ruidos de fondo están grabados a RMS 0,10 (volumen 1,0 = −20 dBFS). Rodado −11 dB, tierra −11 dB, lluvia −16 dB (y la lluvia del mundo abierto −15 dB), soplido del turbo −5 dB en el pico;
  viento de tormenta del mundo abierto −10 dB; con cielo despejado no se oye.
- **Silbido del turbo**: nunca pasa de 3,3 kHz (antes 8 kHz), 12 dB más bajo en el pico y **sólo se oye mientras la carga del turbo se mueve** (cargando o vaciándose); con el turbo estable queda al 20 %
  (−24 dB en total contra el de antes).
- **Caja de cambios**: nunca pasa de 2,4 kHz (antes 4,2 kHz), −14 dB, y **un zumbido que no cambia de altura se va apagando solo** (hasta 30 % en 2,5 s) y vuelve entero cuando la velocidad se mueve.
- **Controles que mandan**: «Gomas y tierra» → rodado + chillido + tierra; «Viento y lluvia» (antes «Viento») → viento + lluvia. En «Silencio» no suenan.
- Ráfagas lentas de viento (dos ondas que no se alinean), tierra sin temblor, y los golpes graves ya no se juntan (mínimo 0,15 s entre golpes).
- Los `.wav` se importan **sin comprimir** (`[importer_defaults]` en `godot/project.godot`; los `.import` no se suben al repositorio): sin costo de descompresión en el teléfono y tablas cortas exactas.

Resultado medido en una carrera real de bosque (tierra, 80 s, la IA manejando; `forest_old` vs `forest_new`): picos de repetición a 2,0 / 4,0 / 6,0 s (0,17 / 0,16 / 0,14) → ninguno (< 0,02);
energía en 2–4 kHz −9 dB, 4–8 kHz −21 dB, > 8 kHz −25 dB; el motor (lo que dominaba) queda igual.

Medidos de a una voz (hatch, ajustes por defecto; dBA):

| Voz | antes | ahora |
|---|---|---|
| rodado a 140 km/h | −31,5 | −42,8 |
| tierra a 90 km/h | −30,3 | −41,7 |
| lluvia | −29,5 | −45,6 |
| silbido del turbo a fondo, parado | −32,3 (8 kHz) | −55,9 (≤ 3,3 kHz) |
| soplido del turbo a fondo, parado | −40,1 | −52,7 |
| viento a 216 km/h | −70,2 | −57,4 (apenas; en 140 km/h −64,6; con «Muy fuerte» +8,5 dB) |
| motor (sin cambios) | −27,9 | −27,9 |

## Cómo se mide (sin oídos)

- `godot/tests/audio_render.gd` arma un `CarAudio`, le va pasando estados del auto inventados (acelerar, crucero, a fondo, soltar, derrapar, tierra, lluvia, frenar y parar) y graba lo que sale por el Master
  a un `.wav`. Se puede dejar sonar **una sola voz** (`--solo=wind,roll`), cambiar los controles (`--wind=80`), poner un rival cerca (`--rival=6,900`) y volcar el nivel de cada voz (`--log`).
  `godot --headless --path godot --script res://tests/audio_render.gd -- --car=hatch --scene=cruise --secs=20 --out=/tmp/x.wav`
- `tools/audio/analyze_audio.py a.wav [b.wav …]` mide pico/RMS/dBA, energía por banda (< 150 … > 8 kHz), **tonos que duran** (líneas finas del espectro: el «silbido») y **repetición**
  (autocorrelación de 0,4 a 9 s sin lo grave: un bucle corto aparece como un pico en 2,0 / 4,0 / 6,0 s).
- Para una carrera de verdad: `xvfb-run godot --rendering-driver opengl3 --resolution 480x270 --max-fps 60 --audio-driver Dummy --path godot game/race.tscn -- --auto --track=forest --cars=1 --frames=2400 --audiorec=/tmp/x.wav`
  (en `--headless` la carrera no dibuja cuadros y nunca termina).
- Prueba automática: `godot/tests/audio_levels_test.gd` (en la compilación de GitHub): bucles largos y sin repeticiones adentro, RMS 0,10, importados sin comprimir, y con 4 autos (hatch, rally80,
  veltor_gtr, truck) a fondo / acelerando / soltando / parados: silbido y caja por debajo de su tope, sin pasar de 3,3 / 2,4 kHz, el tono quieto se apaga, parado no suena nada, los controles en 0 callan y
  el viento del mundo abierto queda bajo.

## Para ajustar (sin tocar el código de la física)

Los niveles están en `SND` al principio de `car_audio.gd` (volumen 1,0 = −20 dBFS; los controles «Gomas y tierra» / «Viento y lluvia» valen ×1 en 30). El carácter de cada ruido (filtros, crujidos, largo)
está en `tools/godot/make_audio.py` (después: `python3 tools/godot/make_audio.py`, reimportar y `audio_levels_test.gd`). Los textos del control están en `options_ui.gd` (traducidos en `game/i18n`).

## Límites honestos

- Esto se midió con instrumentos, no de oído: los números dicen que la repetición y los tonos fijos desaparecieron y que el siseo bajó mucho, pero cómo suena de verdad lo decide el dueño en el APK
  (¿queda muy «limpio»? se sube «Gomas y tierra» o `SND["tires"]`/`SND["gravel"]`; ¿se extraña el silbido? se sube `SND["whistle"]` o «Turbo» en Opciones → Sonido).
- Si el hilo principal se traba (carga de un tramo del mundo), el motor de audio sigue con los últimos valores hasta que vuelve: es un motor que sigue sonando un instante, no un bucle; no se tocó.
- El motor del rival cerca de la largada (grave, < 150 Hz) no se tocó.
