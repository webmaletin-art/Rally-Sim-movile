# Policía del mundo abierto

Pedido del dueño (14/10/2026): que ir de un pueblo a otro por las rutas largas sea «una hazaña»: controles policiales lejos de las ciudades, 2 o 3 patrulleros que te
cortan, te chocan y se te cruzan adelante; si te agarran pagás la multa y aparecés con tu auto frente a la comisaría de Dream City. Cuantas más ciudades cruzás, más difícil.

## Cómo funciona
- **Controles** (`game/city/city_police.gd`, `_build_checkpoints`): uno por cada tramo de autopista, ruta o provincial de la región de más de 2,5 km (176 controles, 1.488 km de rutas),
  en el punto del tramo más lejos de los pueblos (mitad, o 38/62/28/72 % si cae en un pueblo), nunca dentro de Dream City (3,6 km) ni de un pueblo.
- **Armado**: a 650 m del control aparecen los patrulleros (autos de verdad, `race.add_ai_car` con el modelo `police`, balizas que titilan) y el cartel «⚠ CONTROL POLICIAL ADELANTE · N m».
  **Todos esperan en la banquina** (pedido del dueño, 14/10/2026: «controlando desde la orilla de la ruta, no en el medio»): uno de cada lado, escalonados cada 16 m, con la trompa
  apuntando un poco hacia la ruta para salir enseguida. (Antes los dos primeros quedaban atravesados en la calzada como barrera.)
- **Persecución**: al pasar a menos de 60 m del control salen todos (sirena 3D, `audio/samples/siren.wav`). Cada patrullero tiene un papel (`ai/police_driver.gd`):
  «ram» (apunta a la cola, de costado, para hacerte trompear), «block» (se adelanta, se cruza adelante y frena) y «side» (se pega al costado). Lejos siguen el camino del GPS
  (`WorldGps.route`, uno por vez cada 0,3 s); a menos de 38 m van directo. Al empezar sale además un **interceptor de frente** desde 750 m adelante; con nivel ≥ 1, otro cada 40 s.
  Si pierden alguno llega un refuerzo por atrás (fuera de la vista) cada 16 s.
- **Por qué es tan difícil**: agarran 20 % más que el patrullero de la tienda (+3 % por nivel) y, cuando quedan lejos, empujan más (hasta ×1,9 de potencia +15 % por nivel; pegados, igual que vos).
  No se teletransportan: siempre manejan con la misma física.
- **Arresto**: con un patrullero a menos de 8,5 m y vos a menos de 25 km/h, la barra se llena en 1,6 s; con uno pegado a menos de 4,5 m (aunque vayas rápido) en 6 s.
  Multa = $2.000 + $1.500 por nivel (si no te alcanza, se cobra lo que tengas; pasa por `profile.spend(…, "fine")`, que la cuenta del servidor valida como cualquier gasto).
  Fundido a negro y aparecés parado frente a la **comisaría de Dream City** (`STATION` = (70, 60), sobre la calle más cercana; cartel «COMISARÍA · POLICÍA DE DREAM CITY»).
- **Escape**: todos a más de 480 m durante 10 s seguidos. Ese control no vuelve a salir por 4 minutos.
- **Nivel**: pueblos y ciudades (`kind` ciudad/pueblo) por los que pasaste a menos de 700 m desde que saliste de Dream City (máx. 3). Patrulleros = 2 + nivel (máx. 5). Volver a Dream City lo borra.
- Se puede apagar por configuración (`cfg.police = false`, lo usan las pruebas). Corre también en el mundo online (cada teléfono tiene su propia policía; los patrulleros no viajan por la red).
- **Online, varios jugadores yendo a otra ciudad** (pregunta del dueño): cada uno ve y sufre SU propia policía (los patrulleros son locales, no viajan por la red); los demás ven tu auto pero no a los patrulleros que te persiguen.
  Si arrestan a uno, sólo ese aparece en la comisaría; los otros siguen. Para que los patrulleros sean los mismos para todos hace falta que el servidor los coordine (pendiente, junto con los eventos del online).
- **Ciudades alcanzadas** (`game/city/city_reach.gd`, pedido del dueño): las ciudades y pueblos de la región se habilitan para aparecer recién cuando llegás manejando (a menos de 450 m de su estación de servicio).
  Al llegar sale «🏙 ¡Llegaste a …! · ya podés aparecer acá desde el menú» y queda en el perfil (ajuste `reached`). En «¿DÓNDE APARECER?» los que faltan se ven grises con 🔒 en el mapa y no se pueden elegir
  (en modo desarrollador están todos). Dream City siempre está habilitada. Prueba: `tests/city_reach_test.gd`.

## Pruebas
`tests/police_test.gd` (en la compilación): 176 controles, ninguno en Dream City ni en pueblos, la comisaría sobre una calle; un auto llega al control → se arma → al pasar empieza la persecución
→ los patrulleros esperan en la banquina (ninguno en la calzada) → parado lo arrestan (8,3 s) → paga $2.000 y aparece en la comisaría; un **Veltor Max Pro GTR manejado por la IA a fondo**
tiene a los patrulleros encima 18 s (sin barrera, un buen conductor con un auto muy rápido puede pasar: lo que pidió el dueño);
escape a más de 480 m durante 10 s; nivel 0 = 2 patrulleros, 2 pueblos = 4. La prueba usa una física de choques simplificada (la del juego es `race._resolve_collisions`).
Captura en el juego: `DR_POS=43507.9,-1891.2,162.5 tools/godot/run_shot.sh out.png --world --gas --cam=chase`.

## Pendiente
- Probar en el APK: ¿se siente imposible?, ¿te cortan bien el paso?, ¿la multa y la comisaría?, ¿FPS con 5 patrulleros?
- Persecución policial como modo de carrera del online (huir de la policía con otros jugadores): la estructura de eventos del online todavía no existe.
- La comisaría es un cartel sobre la calle: falta un edificio propio cuando se reorganice el centro.
