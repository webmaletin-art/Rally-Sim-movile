# Peatones ambientales 2.5D (Etapa 21)

`godot/game/world/ambient_peds.gd` (un sistema más de World Life) + `fx/city_peds.gdshader`.

* **Figuras de papel**: una tarjeta que siempre mira a la cámara (sólo gira sobre el eje vertical) con la figura dibujada en el shader (sin texturas): cabeza, torso, brazos y piernas que se balancean al caminar, contorno oscuro, mochila / bolsa / gorro, y **paraguas** cuando llueve. Mira hacia donde camina, visto desde la cámara.
* **Deterministas y sin estado**: cada tramo de vereda (26 m) de las calles chicas, anillos, avenidas y la costanera tiene a lo sumo un peatón que va y viene entre dos puntos; su color, velocidad y fase salen de `WORLD_SEED` + calle + tramo, y su posición es una **función pura de la hora del mundo**. Todos los jugadores online ven a la misma gente en el mismo lugar.
* **Rutina**: poca gente de madrugada, más a la mañana, al mediodía y a la tarde; los fines de semana más paseos a la tarde; con lluvia casi nadie (los que hay llevan paraguas). Los de poca gente son un subconjunto de los de mucha.
* **Presupuesto**: un solo `MultiMesh` (una llamada de dibujo) sólo con los sectores activos, tope por perfil `max_pedestrians`: LOW 16 · MEDIA 32 · ALTA 56, y no se dibujan a más de 120 m. De noche se ven más oscuros.
* **Con el auto**: si te acercás rápido se hacen un paso atrás; si los tocás quedan acostados un rato (dibujito de papel, sin violencia) y se levantan. Es sólo local: no se comparte ni se guarda.
* Se apagan con **Vida del mundo = NO**.
* Prueba: `godot/tests/ambient_peds_test.gd` (reglas, subconjunto, vereda, misma gente en otro teléfono, tope, apagado).
* Pendiente: cruces con semáforo (cruzan cuando el semáforo de los autos está en rojo), peatones en las veredas de otras ciudades, reacciones a bocinas.
