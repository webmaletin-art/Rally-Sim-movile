# Audio del mundo abierto (Etapa 20)

`godot/game/audio/world_ambient.gd` (se crea sólo en Dream City, junto a la vida del mundo). Reusa las muestras que ya existen: **no suma archivos**.

| Capa | Qué hace |
|---|---|
| Ruido de ciudad | rodado grave filtrado; sube con los autos del tránsito que hay a menos de 150 m, baja de noche y a alta velocidad el viento lo tapa |
| Motores del tránsito en 3D | los 2/3/4 autos civiles más cercanos (según calidad LOW/MEDIA/ALTA, a menos de 60 m) suenan de donde vienen (`AudioStreamPlayer3D`), con tono según su velocidad y **efecto Doppler** (cálculo propio, barato). Un auto que ya suena se conserva hasta 75 m (no parpadea) |
| Viento ambiente | un poco siempre; más con nubes, tormenta y altura (la Ruta Panorámica sube) |
| Lluvia | la del auto, ahora con volumen según cuánto llueve (clima del mundo) |
| Truenos | sólo en tormenta; salen de la **semilla y la hora del mundo**: todos los jugadores online oyen el mismo trueno a la vez |
| Eco bajo tierra | un reverb en el Master que se enciende sólo dentro de túneles y estacionamientos |

Opción: **Ambiente del mundo** (Silencio / Bajo / Normal / Fuerte) en Opciones → Sonido. En pausa o con el sonido apagado, todo se silencia.
Prueba: `godot/tests/world_ambient_test.gd` (decisiones puras: quién suena, Doppler, ruido de ciudad, truenos iguales para todos).
Pendiente (necesita muestras nuevas): bocinas, sirenas, grillos de noche, pájaros de día, sonido propio de cada gasolinera.
