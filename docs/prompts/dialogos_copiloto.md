Sos guionista de videojuegos de rally. Escribí las frases del COPILOTO de un juego de rally para celular (GSkorp Rally). Las frases se convierten a voz con un sintetizador (texto a voz) y el juego elige UNA al azar según lo que pasa en la carrera, así que tienen que ser muchas, variadas y casi nunca repetirse.

PERSONAJE
- El copiloto es argentino, experimentado, habla en español rioplatense con voseo ("frená", "acelerá", "tenés", "dale", "vamos", "agarrate").
- Es un compañero real: calmo cuando todo va bien, urgente cuando hay peligro, contento cuando se gana. Tiene algo de humor, pero nunca insulta ni dice malas palabras (el juego es apto para todo público en Play Store).
- Le habla SIEMPRE al piloto (el jugador) en segunda persona: "vos", o en plural de equipo: "vamos", "los pasamos".

REGLAS DE CADA FRASE (muy importantes, porque las lee una voz sintética)
- Cortas: entre 2 y 10 palabras. Máximo 12.
- Sin números escritos con dígitos: escribí "tercero", "dos", "cien", nunca "3" ni "100".
- Sin emojis, sin comillas, sin paréntesis, sin barras, sin abreviaturas, sin siglas, sin palabras en inglés.
- Puntuación simple: solo ¡ ! ¿ ? , . y nada más.
- Que suenen naturales dichas en voz alta dentro de un auto de carrera.
- Nada de frases que dependan de algo que el juego no sabe (nombres de rivales, marcas, clima que no es, etc.).
- No repitas la misma idea con palabras casi iguales: variá la forma de decirlo.

CAMPO "i" = INTENSIDAD
- 1 = tranquilo / informativo
- 2 = atento / enérgico
- 3 = urgente / grito
Mezclá intensidades dentro de cada situación cuando tenga sentido.

FORMATO DE SALIDA (obligatorio)
Devolvé SOLO un JSON válido (sin texto antes ni después), con exactamente estas claves y cada una con una lista de objetos {"t": "frase", "i": número}. Ejemplo del formato:

{
  "rival_atras": [
    {"t": "Tenés uno pegado atrás.", "i": 2},
    {"t": "Ojo el espejo, viene encima.", "i": 2}
  ]
}

Si el JSON completo es muy largo para una sola respuesta, dividilo en partes (Parte 1, Parte 2...) cada una con un JSON válido con parte de las claves; después se unen.

SITUACIONES (clave → cuándo suena → cantidad de frases)

LARGADA Y POSICIONES
- largada → al largar una carrera → 20
- rival_atras → un rival viene pegado atrás → 25
- rival_izquierda → un rival aparece a la par por la izquierda → 15
- rival_derecha → un rival aparece a la par por la derecha → 15
- nos_pasaron → perdimos una posición → 20
- pasamos_rival → ganamos una posición → 25
- vamos_primeros → vamos primeros → 15
- vamos_segundos → vamos segundos → 10
- vamos_terceros → vamos terceros → 10
- vamos_cuartos → vamos cuartos → 8
- vamos_quintos → vamos quintos → 8
- vamos_ultimos → vamos últimos → 12
- primero_con_ventaja → primeros y con mucha ventaja → 12
- cerca_del_de_adelante → estamos por alcanzar al de adelante → 15
- ultima_vuelta → empieza la última vuelta → 12
- falta_poco → quedan pocos metros para la meta → 12

MANEJO (el copiloto opina de cómo manejás)
- acelera_mas → recta larga y vamos lentos, podemos ir más fuerte → 20
- frena_ya → entramos muy rápido a una curva → 20
- buena_curva → curva bien hecha, limpia → 20
- buen_derrape → derrape largo y controlado → 20
- trompo → el auto dio un trompo → 12
- fuera_de_pista → nos salimos del camino → 15
- volver_a_pista → volvimos al camino después de salirnos → 10
- sentido_contrario → vamos al revés → 8
- quietos → el auto está parado mucho tiempo en carrera → 10
- muy_rapido → vamos a muchísima velocidad → 15
- nitro → activamos el nitro → 10
- cambio_superficie_tierra → pasamos de asfalto a tierra → 10
- cambio_superficie_asfalto → pasamos de tierra a asfalto → 10
- salto → el auto está en el aire → 15
- aterrizaje_fuerte → caímos fuerte de un salto → 10
- tunel → entramos a un túnel oscuro → 10
- lluvia → carrera con lluvia (se dice al principio) → 10

GOLPES Y DAÑO
- choque_leve → toque suave con otro auto o algo → 15
- choque_fuerte → golpe fuerte → 15
- pared → rozamos una pared → 12
- nos_chocaron → un rival nos chocó a propósito → 15
- auto_danado → el auto está muy dañado → 12
- reaparecer → el jugador pidió volver a la pista → 8

FINAL
- ganamos → terminamos primeros → 20
- podio → terminamos segundos o terceros → 15
- perdimos → terminamos cuartos o peor → 15
- record → nuevo mejor tiempo → 12

CONTRARRELOJ
- vamos_ganando_tiempo → vamos más rápido que el mejor tiempo → 12
- vamos_perdiendo_tiempo → vamos más lento que el mejor tiempo → 12

OTROS MODOS
- drift_combo_alto → combo de drift muy alto → 12
- drift_combo_cortado → se cortó el combo de drift → 10
- radar_cerca → se acerca el radar de velocidad → 8
- bandera_tomada → agarramos una bandera → 10
- poco_tiempo → queda poco tiempo para terminar → 12
- estacionar_despacio → hay que estacionar con cuidado → 8
- cartel_roto → rompimos un cartel en el mundo abierto → 10

CHARLA
- charla_recta → frases sueltas de compañero en una recta tranquila, sin información técnica: comentarios, humor suave, ánimo → 40
- animo → el jugador viene mal y necesita ánimo → 15
