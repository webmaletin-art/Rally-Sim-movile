# Modo Aventura — Dream Racing (plan, aún sin implementar)

Reemplaza al modo historia (que sigue bloqueado). Lo pidió el dueño; se arranca cuando él diga «continúa con el modo aventura».

## Idea
Una sola ruta larguísima, lineal, de ida: arranca en un pueblo y recorre asfalto → montaña con túnel → tierra con la cantera/mina → nieve.
**10 etapas de ~5 min** (≈50 min de una pasada; con reintentos ~2 h). La idea es la sensación de manejar, no ganar: en cada etapa
hay un rival adelante al que hay que pasar antes de llegar a la estación de servicio del final.

## Reglas de cada etapa
- El rival va adelante «al filo»: si manejás con cuidado, él maneja con cuidado; si apretás al límite del auto, él también aprieta.
  Sólo se le puede pasar de verdad en el último tramo (a ~85 %) o si lo apurás mucho antes. El rival tiene un ritmo base propio
  (habilidad por etapa) y un «director» que le sube o baja la velocidad según la distancia y el avance (la goma elástica de la IA,
  ya existente, pero hacia adelante).
- Si llegás a la estación primero: cinemática (la cámara cambia sola, el auto entra, carga combustible, se guarda el avance, sale y
  te devuelve el control). Si llega él primero: la etapa se reinicia desde la estación anterior.
- Antes de la primera etapa: cinemática del piloto manejando (cámara interior 3D, curvas, velocidad), cámara lejana, y una pantalla con
  la explicación (cuántas etapas, duración, cómo se gana, el mapa y los puntos).

## Cómo se construye (en pasos, cada uno sale en una APK)
1. **Datos de la ruta**: un generador (`tools/godot/make_adventure.py`) produce la ruta como tramos (cada uno con su spline, ancho,
   superficie: asfalto / tierra / nieve, y zonas especiales). `RouteTrack` ya hace splines largas; se le agregan *zonas de superficie*
   (agarre, textura y banquina distintos por tramo) y *zonas de túnel*.
2. **Carga por tramos** (para que no vaya lento): sólo se construye lo que está adelante (~1000–1500 m). Mientras manejás se arma el
   tramo siguiente en hilos (terreno y árboles) y se libera el que quedó atrás. Pista «sólo camino» (sin mundo a los costados): franja de
   árboles y un límite lateral.
3. **Etapas y director de IA**: rival por etapa, ritmo, estación de servicio, reintentos, guardado en el perfil.
4. **Cinemáticas**: introducción, entrada/salida de la estación, con cámaras guionadas y la IA manejando tu auto.
5. **Túneles, puente subterráneo, bifurcaciones**: carteles con flecha («TÚNEL»). Atajo por un túnel o seguir por la ruta normal
   (dos variantes del tramo entre dos nodos; se usa la más cercana al auto).
6. **Minimapa de toda la ruta** + barra de etapas, jefes por etapa, subtítulos/voces.

## Pendiente de decidir con el dueño sobre la marcha
Nombres de las etapas y de los rivales, autos de los jefes, clima por etapa, recompensas (créditos/piezas), cuántas bifurcaciones.
