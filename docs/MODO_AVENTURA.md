# Modo Aventura — Dream Racing: «La Ruta de los Sueños»

Implementado (r26+). Código en `godot/game/adventure/`, menú en `godot/game/ui/menu_adventure.gd`.

## Qué es
Una sola ruta de ~80 km, lineal, de estación de servicio en estación de servicio: **12 etapas** (5–9 km, 3,5–5 min para la IA,
~5 min para una persona). Villa Aurora → campos de girasol → río y bosque → sierra → túnel del Cóndor → Ciudad del Valle →
fin del asfalto → cantera con mina y rampa → bosque con lluvia → primeras nieves → paso nevado (jefe El Lobo Blanco) →
la cumbre (final con dos jefes: La Sombra y El Lobo Blanco).

## Cómo está armado
- `adv_route.gd`: la ruta entera se arma con piezas (rectas, curvas, «auto» con curvas al azar acotadas al rumbo, estación,
  taller, túnel, mina, puente, paso bajo nivel, chacra, carteles, bifurcaciones). Muestras cada 2,5 m con ambiente, superficie,
  ancho, ensanche para estacionar, cultivos, pueblo… Las bifurcaciones generan un ramal (curva de Hermite con eses opcionales)
  que se separa y se vuelve a unir.
- `adv_track.gd`: la pista de una etapa (o la variante que toma el ramal). Terreno por ambiente mezclado de a poco, límites
  laterales por tramo, «hasta dónde dibujar» para que el terreno de un tramo no tape otro. La vista del jugador cambia sola de
  camino en una bifurcación.
- `adv_world.gd`: el mundo por tramos de 120 m, armado en otro hilo (sin tirones): camino, banquinas y terreno, guardarraíles,
  alambrados, árboles (dos niveles de detalle), casas, campos (girasol, trigo, maíz, vacas), postes de luz, tranqueras, carteles,
  flechas de curva, mojones, estaciones, talleres, túneles, puente con río, paso bajo nivel y horizonte de montañas.
- `adventure.gd`: la etapa: salida de la estación (cinemática), carrera contra el rival con «director», talleres (entrar/seguir,
  reparar cuesta tiempo), daño (motor, dirección, suspensión), llegada (cinemática, carga de combustible, guardado, guía, ajuste,
  habilidades), derrota y reintento, final con premio (el DR Bisonte XR negro queda en el garaje).
- Director del rival: hasta el 82 % de la etapa va adelante «al filo» (te espera si vas despacio, aprieta a su máximo si lo
  alcanzás); en el tramo final corre a tu propio ritmo medido contra el perfil de la ruta, con un margen que crece por etapa.
  Si lo pasás pelea un rato; la IA se abre cuando tiene un auto al lado (nunca cierra la puerta).
- Habilidades: Curvas, Aceleración, Frenada, Control, Resistencia (hasta 5; el nivel n cuesta n puntos; 5 puntos por etapa).

## Pruebas
`tests/adv_route_test.gd` (la ruta no se cruza), `tests/adv_sim_test.gd` (cada etapa con la IA), `tests/adv_fork_test.gd`
(las bifurcaciones se pueden manejar por los dos caminos). Argumentos de prueba: `--adv=K[:fracción]`, `--advgo`, `--auto`,
`--advalt`, `--advws`, `--advdmg`, `--advtab=…`, `--advintro`, `--advtop=altura`, `--advprof`.

## Pendiente / ideas
Voces del copiloto y de los rivales, más bifurcaciones, eventos en el camino (tráfico, animales), récords por etapa en línea.
