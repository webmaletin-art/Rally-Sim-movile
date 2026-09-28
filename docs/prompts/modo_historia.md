Sos diseñador de videojuegos para celular y guionista. Tenés que escribir el MODO HISTORIA completo de "GSkorp Rally", un juego de rally realista para Android (Play Store), pensando en lo que funciona hoy en el mercado de juegos de autos para celular: misiones cortas, progresión clara, rivales con personalidad, jefes, cliffhangers al final de cada capítulo y recompensas que den ganas de seguir.

ANTES DE ESCRIBIR
1. Analizá brevemente (máximo 10 puntos) qué buscan hoy los jugadores de juegos de rally y carreras en Play Store: duración de las partidas, tipos de historia que retienen, qué hace que vuelvan cada día, qué frustra y hace desinstalar. Usá ese análisis para decidir la estructura.
2. Después escribí la historia respetando TODAS las restricciones técnicas de abajo, porque cada misión la tiene que poder armar el motor del juego tal como está.

LO QUE YA EXISTE (continuidad obligatoria)
- Capítulo 1 "La Fuga" (ya hecho): el piloto y su copiloto son descubiertos por un grupo rival; una cinemática manejada por la IA los muestra escapando por una montaña (curvas de tierra, un salto con rampa, bajada de asfalto) con tres autos persiguiéndolos y embistiendo. Entran a una mina abandonada ("La Trinchera": caminos hundidos, túneles, islas de roca que dividen el camino) y ahí el jugador toma el control. Tiene que salir de la mina con el auto entero mientras lo embisten; si el auto llega a 0% lo atrapan. Termina con "Siguiente misión: próximamente".
- Continuá desde ahí: ¿quiénes son los perseguidores?, ¿por qué los buscan?, ¿qué esconde la mina? Vos lo decidís.

RESTRICCIONES TÉCNICAS (el motor del juego)
- NO hay personajes caminando ni caras: los pilotos siempre están dentro de los autos, con casco. Los personajes existen por VOZ (radio / intercomunicador) y SUBTÍTULOS. El copiloto es la voz principal.
- Todo es apto para todo público: sin armas, sin sangre, sin muertes, sin policía disparando. Persecuciones, embestidas, rivalidades, trampas y secretos sí.
- Cada misión dura entre 1 y 4 minutos de juego.
- Tipos de misión que el motor ya soporta (usá estos nombres exactos en el campo "tipo"):
  - "carrera": contra 1 a 5 rivales, 1 a 3 vueltas o un tramo.
  - "contrarreloj": contra el reloj (puede tener tiempo objetivo).
  - "drift": sumar puntos derrapando en un tiempo límite.
  - "radar": pasar por un radar a la mayor velocidad posible.
  - "banderas": juntar banderas antes de que se termine el tiempo.
  - "estacionar": estacionar en un lugar marcado sin tocar nada.
  - "escape": escapar hasta un punto con perseguidores que embisten; barra del auto de 100% a 0%.
  - "cinematica": escena manejada por la IA (el jugador mira), con planos de cámara y diálogos.
  - Podés proponer como máximo 2 tipos NUEVOS si hacen falta para la historia; marcá "nuevo": true y explicá en una línea cómo funcionarían.
- Mapas disponibles (usá estas claves exactas en "mapa"):
  - "forest" (Bosque de Tierra), "asphaltLong" (Montaña Asfalto), "descent" (Bajada de los Badenes: asfalto en bajada con lomas), "lake" (Circuito del Lago, asfalto), "quarry" (Cantera Roja, tierra), "trinchera" (la mina: caminos hundidos y túneles), "offroad" (Valle Abierto: mundo abierto), "drift" (Drift Plaza), "parking" (Estacionamiento).
  - Varios tienen versión inversa agregando "Rev": "forestRev", "asphaltRev", "quarryRev".
- Clima / hora ("cielo"): "day", "sunset", "overcast", "rain", "dusk".
- Autos disponibles ("auto"): "pickup" (Titan Raptor X, camioneta 4x4), "t1plus" (Volt Raid Ultimate, prototipo de raid), "truck" (Colossus Master 6x6, camión Dakar), "genesis" (Genesis X Skorpio, hiperdeportivo). También podés usar "cualquiera" (el auto que tenga el jugador).
- Planos de cámara para las cinemáticas ("planos"): "interior" (casco del piloto, se ve la mano metiendo los cambios), "detras_piloto", "persecucion_cerca", "persecucion_lejos", "aerea", "helicoptero", "costado_pista" (cámara fija al costado de la curva), "dos_autos" (de costado, dos autos juntos), "de_frente" (el auto viene hacia la cámara con los perseguidores atrás), "salto_camara_lenta", "capo", "paragolpes".
- Diálogos: frases CORTAS (máximo 14 palabras) porque se leen con voz sintética. Español rioplatense con voseo. Sin números en dígitos, sin emojis, sin comillas ni paréntesis dentro de las frases. Cada frase dice quién habla ("copiloto", "rival", "radio" u otro personaje que inventes, siempre por radio).

QUÉ TENÉS QUE ENTREGAR
1. Análisis del mercado (máximo 10 puntos).
2. Resumen de la historia (máximo 15 líneas): conflicto, villano o grupo rival, secreto de la mina, final.
3. Personajes (máximo 6), todos solo por voz: nombre, rol, personalidad, cómo habla (una línea cada uno).
4. Entre 8 y 12 capítulos. Cada capítulo tiene de 3 a 5 misiones y termina con un gancho (cliffhanger). Incluí al menos 3 "jefes" (un rival que te desafía a una carrera o persecución especial).
5. Sistema de estrellas: cada misión da 1 a 3 estrellas según objetivos claros y medibles por el motor (tiempo, puesto, daño restante del auto, puntos de drift, velocidad en el radar, toques al estacionar).
6. Recompensas por misión (créditos y, a veces, desbloqueo de auto o pieza del taller), sin "pagar para ganar".

FORMATO DE SALIDA
Los puntos 1, 2 y 3 en texto corto. El punto 4 como JSON válido con este formato exacto (sin comentarios dentro del JSON):

{
  "capitulos": [
    {
      "numero": 2,
      "titulo": "Nombre del capítulo",
      "resumen": "Una o dos frases.",
      "misiones": [
        {
          "id": "c2m1",
          "titulo": "Nombre de la misión",
          "tipo": "escape",
          "mapa": "trinchera",
          "cielo": "dusk",
          "auto": "cualquiera",
          "rivales": 3,
          "vueltas": 1,
          "tiempo_limite_segundos": 0,
          "objetivo": "Qué tiene que hacer el jugador, en una frase.",
          "estrellas": ["1 estrella: ...", "2 estrellas: ...", "3 estrellas: ..."],
          "falla_si": "Cuándo se pierde.",
          "recompensa": {"creditos": 3000, "desbloquea": ""},
          "cinematica_inicio": {
            "planos": ["interior", "dos_autos", "costado_pista"],
            "dialogos": [
              {"quien": "copiloto", "texto": "Frase corta."},
              {"quien": "radio", "texto": "Frase corta."}
            ]
          },
          "dialogos_durante": [
            {"cuando": "al empezar", "quien": "copiloto", "texto": "Frase corta."},
            {"cuando": "si un rival se acerca", "quien": "rival", "texto": "Frase corta."}
          ],
          "dialogo_final_ganando": [{"quien": "copiloto", "texto": "Frase corta."}],
          "dialogo_final_perdiendo": [{"quien": "copiloto", "texto": "Frase corta."}]
        }
      ],
      "gancho_final": "Cómo termina el capítulo para que quieran jugar el siguiente."
    }
  ]
}

Si es demasiado largo para una sola respuesta, entregá los capítulos en varias partes, cada una con un JSON válido.
