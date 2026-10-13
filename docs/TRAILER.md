# Tráiler de Dream Racing

Tráiler de ~3 minutos a 1080p / 30 cuadros, **hecho con el motor del juego**: las fotos Full HD las saca el propio juego (autos en la sala de exhibición, mapas, mundo abierto, pantallas del menú,
pilotos con los gestos de Mixamo), y el montaje (cortes a ritmo con la canción, zoom, destellos, aberración, brillo, color de cine, textos) se hace en código (Python: PIL + numpy), sin editor de video.
Dura lo que la música: **«Motor de Sueños»** (MusicGPT), 187 s a 138 BPM.

## Qué muestra (compás por compás de la canción)

| Compases | Segundos | Qué |
|---|---|---|
| 0–2 | 0–5 | amanecer en el mapa de fantasía · SRGAMESTUDIO PRESENTA · UN MUNDO ENTERO |
| 3–5 | 5–10 | subida: llantas y trompas de los autos, cada vez más rápido; silencio de la canción |
| 6–11 | 10,5–21 | el golpe: **DREAM RACING** · los 26 autos (uno cada medio golpe, con su nombre) · vuelta de 360° |
| 12–23 | 21–42 | **RALLY**: tierra, barro, lluvia, atardecer (el auto maneja solo, con polvo) |
| 24–35 | 42–63 | **AVENTURA** · La Ruta de los Sueños (12 etapas), rivales y jefes, habilidades |
| 36–54 | 63–96 | **DREAM CITY**: ciudad, tránsito y peatones, clima, de noche; la región (~2.700 km, 8 ciudades, 25 pueblos); «elegí dónde aparecer»; Travesía X (convoy de 44 km) |
| 55 | 96 | el silencio (la canción se corta) |
| 56–67 | 97–118 | **FANTASÍA** (mapas de otro mundo) · **DRIFT** y picadas · pico de energía |
| 68–69 | 118–122 | respiro: los pilotos («TU HISTORIA. TU AUTO.») |
| 70–81 | 122–143 | **PERSONALIZÁ**: 24 estilos de pintura, garaje, taller, reglajes, llantas |
| 82–93 | 143–163 | **ONLINE · PRÓXIMAMENTE** (mercado, taller y regalo diario) y todo lo anterior a golpe |
| 94–105 | 163–184 | **26 AUTOS** · final con el logo y «PRÓXIMAMENTE EN GOOGLE PLAY» |
| 106 | 184–186 | SRGAMESTUDIO |

Todo lo que dicen los letreros sale del juego tal como está (26 autos, 12 etapas de la aventura, 24 estilos de pintura, ~2.700 km de región, 44 km de Travesía X). El online se muestra
**sólo como «PRÓXIMAMENTE»**: sigue cerrado (`Release.ONLINE_OPEN := false`).

## Cómo se hace (todo en `tools/trailer/` y `godot/tests/trailer/director.gd`; la carpeta `tests/` no se exporta)

1. **Música**: `analyze_music.py` y `music_map.py cancion.mp3 mapa.json` miden (no «escuchan») los golpes, los compases, los cortes de energía y la curva de energía. El montaje usa ese mapa
   (`P` = un golpe = 0,434 s; los cortes caen en los golpes; el silencio del segundo 95,85 y el final de 185,25 s están marcados en el mapa).
2. **Fotos**: `director.gd` arma una escena real del juego (sala de exhibición, ruta, mundo abierto o aventura), pone la cámara donde pide un trabajo `.json` y guarda cada foto en Full HD.
   `run_jobs.py` los corre con pantalla virtual (`xvfb`, OpenGL por software; tarda varios minutos por trabajo). Los generadores de trabajos:
   `make_studio_jobs.py` (retratos, vueltas de 360° y los 24 estilos de pintura de los 26 autos) · `make_survey.py` (recorrido de cada mapa; `--only dream,anillo --fr 0.03,0.13,…` para sacar sólo algunos mapas y lugares) · `make_action.py` (el auto maneja solo por cada mapa,
   con polvo y barro) · `make_extra.py` (la Aventura, los pilotos con gestos, el derrape) · `make_scout_world.py` / `make_scout_aerial.py` (ciudad y vistas aéreas) · `make_region_spots.py` (la región: curvas de montaña con subida, ramales nuevos, autopistas, circunvalación junto al mar, un cruce con plazoleta, un pueblo, un peaje; elige los lugares sobre las rutas de `region_1.bin` y pone el auto sobre el eje con `DR_POS`) · `ui_shots.sh` (pantallas del menú con
   un perfil de vitrina de `make_profile.py`).
3. **Montaje**: `make_trailer.py` (`build()` es la lista de tomas, compás por compás, en español e inglés) + `compositor.py` (el motor de imagen). `sheet_dir.py` arma hojas de contactos para elegir las fotos.
4. **Sonido**: `sfx.py` sintetiza los golpes, barridos y subidas que van debajo de la canción; `make_trailer.py audio` los mezcla con la canción (con fundidos y −14 LUFS) y `mux` los une al video.

```
python3 tools/trailer/make_trailer.py sheet --times 2,6,11,22 hoja.png          # mirar fotogramas sueltos
python3 tools/trailer/make_trailer.py render --workers 4 trailer_sin_audio.mp4  # video (en tramos, en paralelo)
python3 tools/trailer/make_trailer.py audio trailer.wav                         # canción + efectos
python3 tools/trailer/make_trailer.py mux trailer_sin_audio.mp4 trailer.wav trailer.mp4
python3 tools/trailer/make_trailer.py render --lang en …                        # versión en inglés
```

`make_play_shots.py` arma las capturas de la ficha de Google Play (1920×1080, `store_listing/capturas/`) con las mejores fotos.

Las fotos y el video quedan **fuera del repositorio** (pesan cientos de MB): las fotos en `/tmp/trailer/stills` (`TRAILER_STILLS`), el video final en la carpeta `trailer_out/` (ignorada por git).

## Consejos para sacar las fotos del mundo abierto
- **El auto se dibuja «por adentro» si el perfil tiene una cámara interior** (la cámara por defecto del juego es la 6, «Interior»): sale sólo el capó, la jaula y los pilotos. El director fuerza `camera: 1` (seguimiento) en los ajustes de cada trabajo. Si algún día las fotos salen con el auto «a medias», mirar eso primero.
- **Con el auto andando (`auto`/`sim`) la cámara lo acompaña cuadro a cuadro** (`follow` en `director.gd`, respecto del auto que se DIBUJA, no del último estado de la física): antes la cámara se calculaba una sola vez y a 40 m/s el auto salía corrido varios metros y cortado en la foto.
- `wait` de cada toma son **cuadros**, no segundos: el mundo abierto (la ciudad y sobre todo la región) arma los cuadrados de a poco, así que en el **primer** tiro de un trabajo hacen falta 60–90 cuadros (los demás 10–15); con menos salen el terreno sin cargar, un plano amarillo de fondo o el auto «enterrado» (pasó con `scoutw/ruta_este` y `circunv_ring`).
- `DR_POS=x,z,grados` pone el auto: para una ruta usar un punto del eje y su rumbo (`tools/world_gen` lee `region_1.bin` con `binio.py`; la calle más cercana y su rumbo salen de ahí). Un punto a 24 m de la ruta deja al auto en el pasto.
- Con el procesador ocupado los trabajos tardan mucho: `LP_NUM_THREADS=2` en el entorno limita los hilos del dibujado por software y evita que dos trabajos en paralelo se pisen.

## Límites honestos

- No se puede **escuchar** el resultado desde acá: el ritmo está medido contra el mapa de la canción, pero cómo suena la mezcla (volumen de los efectos contra la canción) lo decide el dueño al verlo.
- La canción es de **MusicGPT**: antes de subir el tráiler a Google Play / YouTube / publicidad hay que confirmar que su plan permite uso comercial y registrar los derechos.
- Las fotos salen de un render por software (más lento y sin el post-proceso del teléfono): los colores y el brillo del tráiler son los del montaje, no los del juego en el teléfono.
- Es un video de fotos con movimiento de cámara y efectos, **no una grabación de pantalla** con el auto jugándose en tiempo real.
