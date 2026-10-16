# Auditoría del ciclo de juego, progresión, economía y equilibrio competitivo

*15/10/2026 · Fase 1: SOLO diagnóstico y propuestas. No se tocó código, física, precios, premios, migraciones ni `main`.*

**Cómo se hizo.** Se leyeron CLAUDE.md, INDICE_TECNICO, ESTADO_ACTUAL, REGISTRO_TECNICO, COMO_FUNCIONA_EL_JUEGO, ONLINE_POR_EVENTOS,
PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL, COSTOS_ONLINE, CARRERAS_MUNDO_ABIERTO, MODO_AVENTURA y CUENTA_Y_ECONOMIA, y se inspeccionó el código y las migraciones.

**Mediciones con el motor (sin tocar el repo):**
- `CarBuild.perf_of` para los 28 autos: de serie y con todo mejorado.
- `OW.build` para los 79 eventos reales del mapa: premio, tipo, largo y distancia.

**Leyenda:** ✔ = comprobado en código o medido · ≈ = estimación con fórmula, falta medirlo jugando · ❓ = hipótesis a verificar.

Nada de esto está probado en Android. Lo que se dice de «cómo se siente» es hipótesis hasta que el dueño lo juegue.

---

## A. Diagnóstico ejecutivo

**El ciclo existe y casi no tiene paredes duras.**
- ✔ Ninguna carrera del mapa, ningún evento del servidor y ningún concesionario exige clase, nivel o rango.
- ✔ Los rivales del mapa y de la carrera rápida se adaptan al índice de rendimiento (PI) de tu auto.
- ✔ El único requisito de auto está en las copas de CARRERA. Pide un PI máximo, no un mínimo: se arregla bajando piezas (gratis) o usando otro auto.
- ✔ Las paredes reales son las de pago:
  - Continental, Leyenda y Camiones;
  - etapas 4–12 de la Aventura (y con ellas el Bisonte XR);
  - los autos premium.
- No hay bloqueo económico al principio: el saldo inicial y la Copa Debut alcanzan para el primer cambio de auto.

**Dónde se rompe (lo más importante):**
1. **Encontrar un objetivo cuesta, sobre todo al principio.**
   - ✔ 64 de las 79 carreras están a más de 33 km de Dream City; solo 3 están en la ciudad.
   - ✔ Las carreras no se ven en el mapa hasta descubrirlas (pasar a menos de 90 m).
   - ✔ No hay tutorial ni un «qué hago ahora».
   - El jugador nuevo sale a la ciudad y no sabe adónde ir.
2. **Las actividades pagan muy distinto por minuto.**
   - ✔ Una carrera del mapa ganada por primera vez paga ~$5.000 (mediana).
   - ✔ Travesía X paga $600–1.200 por 30–40 minutos.
   - ✔ Carrera rápida: tope de $400.
   - ✔ Etapa de Aventura: $500–1.600.
   - ❓ Escapar de la policía podría convertirse en una «granja» (ver C3).
3. **La economía tiene dos agujeros comprobados:**
   - ✔ Los reglajes bloqueados se pueden mover y se cobran, pero no hacen nada.
   - ✔ Medallas, logros y «ya ganaste esta carrera» viven sólo en el teléfono: al reinstalar se vuelven a cobrar (logros $205.500, carreras del mapa $398.700) y, a la vez, el jugador pierde ese progreso.
4. **Los récords no son comparables.** ✔ La tabla de cada carrera mezcla un R2 de serie (PI 487) con un Veltor GTR mejorado (PI 886), y no guarda ni la clase ni el modo arcade o simulación.
5. **Hay autos que no tienen razón de existir, incluidos dos que se pagan con dinero real.** ✔ El hyper (US$3,99, el más caro: $260.000) es peor en todo lo de asfalto que el Veltor Max Sport ($185.000). El gt3 (US$2,99) es peor que el Trilux Pro GT ($118.000).

---

## B. Mapa del ciclo real

| Etapa | Qué hace hoy el jugador (✔) | Estado | Qué lo corta |
|---|---|---|---|
| 1. Salir a conducir | Entra a Dream City (las otras ciudades se habilitan al llegar manejando). Policía, peajes, nafta, gomas. | ✅ funciona | — |
| 2. Encontrar un objetivo | Carreras ocultas hasta pasar a 90 m. Eventos del servidor con cartel. Actividades de la ciudad: radares, entregas, contrarreloj Panorámica, auto secreto. | ⚠️ débil | 64/79 carreras lejos; el mapa no muestra lo no descubierto; sin tutorial; el inicio sólo sugiere «CARRERA» (copas). |
| 3. Prepararse | Garaje y taller completos: 10 mejoras, 6 gomas, reglajes, piezas y diseños. Probar cualquier auto gratis. | ✅ con fallas | Reglajes bloqueados que se cobran sin efecto; el mapa no dice qué gomas convienen. |
| 4. Competir o explorar | 8 tipos de carrera del mapa, persecuciones, fugas, cacerías, contrarreloj, drift, copas, Aventura, Travesía X. | ✅ variado | La cacería con un auto inicial es casi imposible: la IA es rápida y tiene +15 % de potencia. |
| 5. Recompensa | Créditos validados por el servidor (topes), medallas, récords, premios de eventos (autos, vale, diseños, alquileres). | ✅ | No se ve el puesto online al terminar una carrera común; los récords hechos sin conexión se pierden. |
| 6. Progresar | Comprar autos (2,08 M para tenerlos todos), mejoras ($210.000 por auto), variantes de concesionario. | ✅ | Autos dominados; arriba el PI se satura, así que la versión «Llamas» no suma en los autos tope. |
| 7. Nuevo objetivo | Copas por estrellas, temporada semanal, carrera de la semana, colección. | ⚠️ parcial | No hay metas intermedias visibles («te faltan $X para…», «próxima carrera a 2 km»). |
| 8. Volver a competir | Repetir paga 35 % (mapa) o baja hasta 20 % (copas). Rivales adaptables ±3 %. | ✅ | Pasada la primera vuelta de premios, el ingreso cae fuerte (ver E). |

---

## C. Bloqueos de progresión

### C1. Paredes duras (impiden seguir)
| Dónde | Condición | Salida | Tipo |
|---|---|---|---|
| Copas Continental / Leyenda / Camiones (`menu_career.gd`, `release.gd`) | compra `dr_adventure` o `dr_full`; Camiones además exige el Mamut 6x6 (premium) | Ninguna sin pagar. Igual queda mucho para hacer (mapa, eventos, Debut, Nacional). | intencional (venta) |
| Aventura, etapas 4–12, y el Bisonte XR (`release.gd:6`) | compra | Ninguna; el Bisonte no se vende | intencional |
| Autos premium truck, gt3, hyper | compra en la tienda | — | intencional, pero ver E2: dos de ellos son malos |

### C2. Paredes blandas (se pasan jugando)
| Dónde | Condición | Costo de la salida | Tiempo estimado |
|---|---|---|---|
| Copa Nacional | 12 ⭐ | 0 (estrellas de Debut) | ≈ 1 sesión |
| Copas con PI máximo (Debut ≤ 599, Nacional ≤ 699) | tu auto pasa el máximo | bajar piezas (gratis) u otro auto | inmediato |
| Aparecer en otra ciudad | haber llegado manejando | manejar | 17–25 min de ruta ≈ |
| Peaje sin plata | barrera cerrada | volver ($0) o ganar $30–66 | — |
| Sin nafta | el auto no acelera | carga de emergencia gratis del 8 % | — |

### C3. Riesgos económicos (no son bloqueos, pero rompen el ciclo)
- **❓ Granja de escapes.**
  - ✔ A 170 km/h en la ciudad el medidor de desmadre se llena en 10 s y empieza una persecución.
  - ✔ Para escaparse alcanza con estar lejos de los patrulleros 10 s.
  - ✔ Cada escape paga $1.500 + $1.000 × nivel + $20/s, de $1.500 a $10.500, sin enfriamiento entre escapes pagos.
  - Si un ciclo dura ~1 min, ganaría más que cualquier otra actividad y chocaría el tope de $300.000/h. **Hay que medirlo con la prueba automática de la policía antes de tocar nada.**
- **✔ Reinstalar vuelve a pagar** logros ($205.500) y primeras victorias del mapa ($398.700). Los topes del servidor ($1,2 M por día) lo permiten.
- **✔ Horarios fijos:** las cacerías son a las 22 y a las 16 (Argentina). No bloquean, porque esos autos también se venden, pero dejan afuera a quien no puede a esa hora.

### C4. Recorrido completo (≈ fórmulas, faltan mediciones en el teléfono)
**Premios de una sola vez disponibles gratis:**

| Fuente | Monto |
|---|---|
| Carreras del mapa | $398.700 |
| Logros | $205.500 |
| Copa Nacional | $48.475 |
| Copa Debut | $25.200 |
| Bonos de rango | $5.100 |
| Panorámica | $3.100 |
| Aventura (3 etapas) | $1.800 |
| **Total** | **≈ $688.000** |

**Hitos de compra:**
1. **R2 Rally ($24.000), el primer cambio:** con Debut, en ≈ 1 sesión. ✅
2. **Auto de gama media (KL5 $98.000 / Trilux Pro GT $118.000):** ≈ 3–6 h, con viajes. ✅
3. **Súper deportivo (Veltor GTR $225.000) + todas las mejoras ($210.000):** se consigue sobre todo con la primera vuelta de premios. Después, repitiendo, el ingreso estimado es ≈ $15–25.000/h. Comprar todos los autos (≈ $2,08 M) lleva ≈ 70–100 h.
   - Es un objetivo de colección razonable, pero **sin metas intermedias se siente como trabajo**.

---

## D. Matriz de actividades

| Actividad | Qué aporta único | Repetible | Dificultad progresiva | Premio (✔) | $/min aprox. | Auto especial | Nuevo | Avanzado | Horario | Sin conexión |
|---|---|---|---|---|---|---|---|---|---|---|
| Carreras del mapa (79, 8 tipos) | descubrir el mapa, variedad de tramos | sí (35 %) | rivales ±3 % | $1.600–7.000 (mediana 5.000) | 1.ª vez ≈ 700–1.200, repetida ≈ 250–400 | no | sí (pero lejos) | sí | no | sí |
| Copas (CARRERA) | campeonato con estrellas y PI máximo | sí (baja a 20 %) | por copa | $25k–88k por copa | ≈ 600–1.000 | PI máximo | sí | sí (si paga) | no | sí |
| Carrera rápida | practicar circuitos | sí | IA según PI | ≤ $400 | ≈ 100 | no | sí | poco | no | sí |
| Aventura | historia lineal con jefes | baja | sí | $500–1.600 por etapa + $20.000 | ≈ 150–300 | usa el Bisonte | sí (3 etapas) | sí | no | sí |
| Travesía X | convoy largo | baja | no | $600–1.200 | **≈ 20–40** | no | sí | poco | no | sí |
| Policía: desmadre y escapes | tensión, riesgo y recompensa | sí | nivel 0–3 | $1.500–10.500 | ❓ hasta 3.000+ | no | sí | sí | no | sí |
| Fugas (servidor) | aguantar N minutos | intentos | no | $12k, Interceptor 3 días, $50k de vale | — | no | difícil | sí | no (24 h) | **no** |
| Cacería (servidor) | autos que no se compran con plata | 1 por auto | IA muy rápida | el auto | — | no, pero en la práctica sí | **casi imposible** | sí | **fijo** | no |
| Contrarreloj entre ciudades | ruta larga con límite | 3 intentos | no | $20.000 | — | no | sí | sí | no | no |
| Carrera de la semana | récord semanal | sí | — | top 3: $25k / 12k / 6k | — | no (mezcla clases) | difícil ganar | sí | no | no |
| Desafío de drift | habilidad, 90 s | sí | — | top 3: KL5, gomas, vale | — | no | sí | sí | no | no |
| Temporada | une todo en una semana | — | — | top 5 | — | no | difícil | sí | no | no |
| Radares, entregas, Panorámica, auto secreto | cosas que hacer en la ciudad | diarias | rango ×1,24 | $150–1.800 | ≈ 200–500 | no | **sí, cerca** | poco | no | sí |
| Plaza de Drift libre | práctica | sí | — | **$0** (sólo récord local) | 0 | no | sí | — | no | sí |

**Duplicados y vacíos:**
- **Escapar de la policía en tres formas:** Huida del mapa, desmadre y fugas del servidor. Se complementan (corta, libre, larga) si se comunican bien.
- **Persecución del mapa y cacería:** se parecen en «seguir a la IA», pero premian distinto. Se complementan.
- **Vacíos:**
  - no hay cacería ni desafío accesible para autos de serie de clase C/B;
  - la Plaza de Drift libre no paga nada;
  - no hay récords por tramo ni por clase.

---

## E. Vehículos, economía y equilibrio competitivo

### E1. Qué es real en la física (✔ `car_build.gd`)
- **Todas las mejoras actúan sobre la física:**
  - motor y turbo → potencia;
  - peso → masa e inercias;
  - frenos → torque de freno;
  - suspensión, caja, diferencial, aerodinámica, nitro, ángulo de dirección.
- **Pagos que no rinden:**
  - **Stance nivel 1** sólo habilita una comba que **quita** agarre.
  - **Diferencial nivel 2** habilita «split», que ya está libre siempre.
- **Gomas reales por superficie:** slick 1,18 en asfalto y 0,62 en barro; tierra 1,18 en tierra.
- **Reglajes:**
  - **Libres para todos:** presión, dirección, reparto de freno, **reparto de tracción** (cualquier auto puede ser FWD, RWD o AWD) y **agarre delantero y trasero hasta 110 %** (+10 % de agarre gratis, que sube el PI).
  - **Bloqueados por mejora** (resortes, amortiguadores, barras, altura, comba, convergencia, relación final, LSD, aero, stance): el código sólo los aplica si están desbloqueados, pero **la pantalla deja moverlos y cobra la tarifa** (no se encontró ningún chequeo de `req` en la interfaz). Es un bug.
- **PI y clase:** el PI se calcula de verdad (aceleración, velocidad, agarre, freno, aero). Las clases son D/C/B/A/S/X, con cortes en 400/500/600/700/800.
  - Arriba se satura: vmax ≥ 300 y relación potencia/peso ≥ 700 topean.
  - Por eso la versión Llamas de los autos tope no cambia el PI.

### E2. Autos dominados (✔ medido: más caros y peores o iguales en PI, potencia, vmax, relación potencia/peso y 0-100)
| Caro | Lo domina | Nota |
|---|---|---|
| clasico60 $30k | hatch2 $24k | |
| camo $46k | kodiak $44k | también en tierra |
| trilux $78k | buggy $50k, rally80 $64k, gt $72k | |
| trilux_s $104k | gt $72k, kl5 $98k | |
| **gt3 $130k (US$2,99)** | trilux_gt $118k | **auto pago peor que uno de plata** |
| **hyper $260k (US$3,99)** | veltor_s $185k, veltor_gtr $225k | **el más caro y pago, peor en asfalto** |
| genesis $190k (premio) | veltor_s, en todo menos potencia | |

Cambiar esto toca la física o los precios: **hace falta autorización del dueño**. Propuesta: darle a cada uno un rol (ver F) antes que tocar números.

### E3. Ejemplos concretos (✔ medido)
| Ejemplo | PI | Clase | Potencia | Vmax | 0-100 | Precio |
|---|---|---|---|---|---|---|
| R2 Turbo de serie (inicial) | 487 | C | 222 hp | 209 | 5,5 s | $9.000 |
| R2 Turbo con todo | 657 | A | 321 hp | 232 | 4,8 s | +$210.000 |
| Pampero Yaguareté (camioneta) de serie | 454 | C | 511 hp | 170 (limitada) | 5,6 s | $34.000 |
| Pampero con todo | 674 | — | 741 hp | 248 | — | — |
| Kaze Zero GT (deportivo) de serie | 645 | A | 516 hp | 264 | 4,4 s | $72.000 |
| Kaze Zero GT con todo | 820 | X | — | — | — | — |
| Veltor GTR (premio de la temporada) de serie | 805 | X | 1.252 hp | 357 | 4,0 s | $225.000 |
| Veltor GTR con todo | 886 | — | — | — | — | — |

- El R2 Turbo con todo **no cabe en la Copa Debut** (≤ 599) si no se le sacan piezas.
- **Métricas que faltan:** tiempos reales por vuelta de cada auto en las mismas pistas, y el efecto real de cada mejora en segundos. Se pueden sacar con la IA en pruebas automáticas.

### E4. ¿Domina un superdeportivo las tablas? (✔)
- **Carreras contra la IA:** no. Los rivales se eligen por tu PI + 20 (mapa y carrera rápida) y las copas tienen PI máximo.
- **Récords y tablas:** sí.
  - Cada récord guarda sólo el id del auto. No guarda PI, clase, mejoras, gomas ni modo de manejo.
  - La tabla del mapa (`ow:<id>`) y la carrera de la semana son únicas para todos, así que las ganan los autos tope.
- **Arcade y simulación (✔):**
  - **Premios iguales:** ninguna recompensa mira el nivel de simulación.
  - **Cambiar de modo no borra nada:** es sólo un ajuste.
  - **Sólo cambia ayudas:** ABS, control de tracción, estabilidad y ayuda de línea. No cambia agarre ni potencia, y el PI es igual.
  - **Duda:** la ayuda de línea (60 % en arcade) y la estabilidad (90 %) pueden hacer más rápido a un jugador casual y más lento a uno experto. **No hay datos** para decir si los tiempos son comparables.

### E5. Economía (✔ fórmulas y precios)
- **Costo de manejar una hora (~100 km):**
  - nafta ≈ $150;
  - peajes ≈ $30–130;
  - gomas ≈ $25–300 (según el tipo).
  - **Menos de $600 por hora.** Los errores comunes no castigan fuerte; una multa son $2.000–6.500.
- **Gastos ausentes:** no hay reparaciones (el tipo «repair» existe pero nada lo usa). Pasada la colección, la plata deja de tener destino.
- **Topes del servidor:** $60.000 por premio, $300.000 por hora, $1,2 M por día. Frenan a un tramposo, pero no frenan reinstalar ni la granja de escapes.
- **Premios de eventos:** se dan en el servidor ($200.000 máximo por premio). Son proporcionados.

---

## F. Propuesta de eventos y progresión (sin actividades nuevas: reusar lo que hay)

### F1. Calendario sugerido (se configura en `wev_templates`, sin APK)
Como mucho **3 renglones en el HUD**, con prioridad: el evento que estás jugando > el que empieza en menos de 5 min > la temporada.

| Escala | Qué | Frecuencia |
|---|---|---|
| Largo (semana) | Temporada + carrera de la semana | siempre una de cada |
| Mediano (2–3 días) | Desafío de drift **o** fuga larga (alternados) | uno a la vez |
| Corto (horas) | Contrarreloj entre ciudades, fuga de 5 min | 1–2 por día |
| Cita | Cacería | 2 por día **en horarios que roten** (no siempre 16 y 22), así juegan otros husos y rutinas |

- **Cacería para novatos:** la misma cacería con un pool de autos de clase C/B y sin el +15 % de potencia, para que el jugador nuevo tenga chance.
- **Temporada:** sumar puntos también por participar (un intento logrado), no sólo por ganar. Ya está así; hay que comunicarlo mejor. Que no premie solo a los expertos: agregar premios por **puntaje alcanzado** (por ejemplo, 300 pts = un diseño), además del top 5.

### F2. Escalas de objetivos
| Escala | Qué existe | Cambio mínimo |
|---|---|---|
| 2–10 min | carreras del mapa, radares, entregas, fugas cortas, drift de 90 s | **mostrarlas cerca**: marcar en el mapa los tramos no descubiertos como «?» (sin datos) y un panel «cerca tuyo» |
| varias sesiones | copas por estrellas, ahorrar para un auto, subir en la temporada | **meta visible**: «próximo auto: te faltan $X» en el inicio; barra de la temporada |
| días o semanas | temporada, colección de 28 autos, récords | **colección**: «X/28 autos», «X/79 carreras ganadas», diseños; premios por hitos de colección (ya existen logros: sumar algunos) |

### F3. Roles para los autos (antes de tocar precios o física)
- **Separar las tablas por clase** (C, B, A, S, X): un R2 de serie compite con autos C. Así cada clase tiene su récord y comprar otro auto abre otra tabla.
- **Darle uso a los autos dominados con eventos que pidan su terreno.** Por ejemplo, «Contrarreloj de tierra» con gomas de tierra, donde gt3 y hyper rinden un poco más fuera del asfalto. Si igual no alcanza, proponer el ajuste con números (con autorización).

---

## G. Interfaz y claridad (mínimo necesario)

| Problema (✔) | Mejora mínima |
|---|---|
| No hay tutorial; `profile.d.tutorial` existe pero nada lo usa | 3 avisos la primera vez en Dream City: «frená en un círculo para largar», «tocá el mapa para ir con el GPS», «📅 eventos en la pausa» |
| Las carreras no descubiertas son invisibles y casi todas están lejos | «?» en el mapa para los tramos sin descubrir (sólo la posición) + distancia y premio de las descubiertas al tocarlas |
| El inicio no dice qué hacer | una tarjeta «PRÓXIMO OBJETIVO»: la carrera más cercana sin ganar, el evento en vivo o el auto que te falta, con el botón IR (GPS) |
| Un solo aviso a la vez, que pisa al anterior (2,2 s) | cola de avisos con prioridad (policía y eventos primero) |
| No se ve el puesto online al terminar una carrera común; las tablas race/timetrial/drift se juntan y nunca se muestran | mostrar «puesto X de Y» en el resultado y las tablas en RANKING |
| Reglajes bloqueados que se cobran | mostrarlos con candado y sin cobrar |
| Los récords hechos sin conexión se pierden | ponerlos en cola como los premios |

---

## H. Hoja de ruta priorizada

### P0 — Errores graves y agujeros (bajo riesgo, primero)

**1. Reglajes bloqueados que se cobran sin efecto.**
- Evidencia: los reglajes con `req` se aplican sólo si están desbloqueados, pero la interfaz no mira `req` y cobra.
- Arreglo: candado en la interfaz y no cobrarlos.
- Archivo: `menu_garage.gd`.
- Riesgo: bajo. Prueba nueva: tarifa = 0 para cambios bloqueados.
- Costo online: ninguno.

**2. Granja de escapes (medir primero).**
- Evidencia: no hay enfriamiento entre escapes pagos y se puede llenar el desmadre en 10 s.
- Paso 1: prueba automática que cuente cuánto dura un ciclo desmadre → escape y cuánto paga por hora.
- Paso 2, sólo si da desbalance: pago completo una vez cada N minutos y el resto reducido.
- Archivos: `city_modes.gd`, `police_test`.
- Riesgo: bajo.

**3. Premios de una sola vez que se vuelven a cobrar al reinstalar, y progreso que se pierde.**
- Evidencia: logros, medallas, carreras del mapa ganadas y Aventura viven sólo en `profile.json`.
- Arreglo: guardar en la cuenta del servidor las marcas de «ya cobrado» (logros y primeras victorias) y devolverlas al sincronizar. Primero los logros.
- Archivos: `account_econ`, migración aditiva, `profile.gd`.
- Riesgo: medio, porque es la economía; con pruebas del servidor.
- Costo online: casi cero (viaja con la sincronización que ya existe).

### P1 — Gran impacto, bajo riesgo
4. **«PRÓXIMO OBJETIVO»** en el inicio y **«?» en el mapa**. Sólo interfaz, con datos que ya existen. Archivos: `menu.gd`, `city_hud.gd`, `city_events.gd`.
5. **Récords justos.**
   - Guardar PI, clase y nivel de ayudas con cada récord (columnas nuevas, aditivas) y tablas por clase en el mapa y en la carrera de la semana.
   - **Sin cambiar premios.**
   - Separar arcade y simulación sólo si los datos muestran diferencia.
   - Archivos: `online.gd`, `city_events.gd`, migración.
   - Costo: mismo número de llamadas.
6. **Ingreso por minuto de Travesía X, Aventura y carrera rápida.**
   - Hoy pagan 10–30 veces menos por minuto que el mapa.
   - Proponer valores con la medición del punto 2 y del tiempo real de cada actividad. Requiere autorización (economía).
7. **Cacería para novatos** y **horarios que roten.** Sólo plantillas en Supabase, sin APK.
8. **Autos pagos dominados (gt3, hyper).** Decisión del dueño: darles un rol (tierra, nitro, otro uso) o ajustar. Requiere autorización (física o precio).
9. **Récords sin conexión en cola** y **puesto online visible** al terminar.

### P2 — Mediano plazo
10. Temporada con **premios por puntaje alcanzado**, no sólo top 5.
11. **Desafíos diarios** reusando las 79 carreras: «hoy: 3 carreras de montaña en el norte, ×1,5».
12. Arreglar **stance nivel 1** y el **«split» del diferencial nivel 2**, que hoy no sirven. Afecta la física y el valor de las mejoras: requiere autorización.
13. **Rivales fantasma:** hoy no se graba ninguna carrera. Haría falta grabar una muestra por segundo (como la de la cacería) en el récord. Riesgo de trampa: medio. Tráfico: ~5–10 KB por récord.
14. **Plaza de Drift libre:** un pago chico por récord personal, con tope diario.

### P3 — Futuro
15. Reparaciones como gasto (hoy no hay daño que cobre).
16. Objetivos comunitarios («entre todos, 10.000 escapes esta semana»).
17. Pasos a distinto nivel y nuevas zonas.

---

## I. Pruebas y métricas

**Pruebas automáticas (sin red):**
- `progression_sim` (nueva): con las fórmulas reales, simula a un jugador nuevo, a uno intermedio y a uno avanzado, y calcula el tiempo hasta cada auto. Falla si algún hito pasa de un umbral que fije el dueño.
- `police_test` + nuevo caso: ciclo desmadre → escape (tiempo y $/h).
- `garage_tune_test`: tarifa 0 para reglajes bloqueados.
- Pruebas SQL para las marcas de «ya cobrado» y para las columnas nuevas de récords.

**Métricas livianas (sin datos personales, costo casi cero):**
- Ya existe `account_earns` (tipo, referencia, monto), que hoy se borra a los 3 días. Antes de borrarlo, sumarlo en una tabla diaria por tipo: **distribución de ganancias por actividad**.
- **Retorno a 1, 7 y 30 días:** con `players.created_at` y `account_econ.updated_at`.
- **Eventos:** `wev_runs` ya guarda intentos iniciados y terminados, y su abandono.
- **Bloqueos:** contar cuántas veces sale «tu auto es clase X, esta copa admite Y» (un contador local que viaja con la sincronización).
- **Autos usados:** el id de auto que ya viaja en los récords.

---

## J. Preguntas pendientes (sólo lo que falta para decidir)
1. ¿Las copas Continental, Leyenda y Camiones y las etapas 4–12 **siguen siendo pagas** en la versión de Play? Cambia qué es pared y qué no.
2. ¿Qué **tiempo objetivo** querés hasta el primer súper deportivo? Por ejemplo, 10 h o 30 h. Sin esto no se puede ajustar la economía.
3. ¿Se puede **tocar la física o el precio** de gt3 y hyper, o preferís darles un rol con eventos?
4. ¿Los récords se separan **por clase**? (recomendado) ¿Y **por modo** (arcade o simulación) sólo si los datos lo muestran?

---

## K. Decisión recomendada: las 3 primeras mejoras
1. **Cerrar los agujeros de la economía (P0 1–3):**
   - reglajes que se cobran sin efecto;
   - medir y, si hace falta, frenar la granja de escapes;
   - que lo de una sola vez no se vuelva a cobrar al reinstalar (y no se pierda).

   **Por qué primero:** son errores comprobados o riesgos medibles. Cualquier ajuste de premios hecho antes sería sobre números falseados.
2. **«PRÓXIMO OBJETIVO» y «?» en el mapa (P1 4).**

   **Por qué:** el problema más grande del ciclo es encontrar qué hacer. El contenido ya existe (79 carreras, $398.700 en premios) pero 64 están lejos e invisibles. Es sólo interfaz, sin tocar la economía ni la física.
3. **Récords justos por clase y con el modo registrado (P1 5).**

   **Por qué:** sin esto, las tablas, la carrera de la semana y la temporada las ganan siempre los autos tope. Cada clase con su tabla le da sentido a comprar autos distintos sin cambiar ni un precio. Además deja medido si arcade y simulación son comparables antes de decidir separarlos.

Todo lo demás (ingreso por minuto, autos dominados, calendario) conviene decidirlo **después** de tener las métricas del punto I.


---

## Resultados de la implementación — fase 4 (16/10/2026, rama ccr-e7ae3f10-45afj2)

Calculado con `tools/econ/progression_sim.py` (datos reales del juego volcados por `godot/tests/econ_dump.gd`; los supuestos están marcados en el script).

| Actividad (perfil intermedio) | Antes | Después |
|---|---|---|
| Carreras del mapa repetidas (típico) | ≈ $20.000/h (inflado por el agujero) | ≈ $17.400/h |
| Granja «2.º o plata a propósito» | **$45.000/h** (la más rentable del juego) | $24.800/h (debajo del mejor par ganado) |
| Travesía X | ≈ $1.500/h | ≈ $7.700/h |
| Copas repetidas · carrera rápida · drift rápido | $16.800 · $4.800 · $16.800/h | sin cambios |
| Escapes encadenados (medido con física) | −$145.000/h | sin cambios (no hay granja) |

| Hasta… (sólo con lo repetible) | Nuevo | Intermedio | Avanzado |
|---|---|---|---|
| Veltor (primer superdeportivo, clase S, $150.000) | 10,6 h | 8,8 h | 8,0 h |
| Veltor GTR ($225.000) | 15,9 h | 13,2 h | 12,0 h |

Autos pagos (de serie, `CarBuild.perf_of`): GT3 PI 705→745 (manejo 0,43→0,52); Hyper PI 766→821 (manejo 0,41→0,50). El Trilux GT y el Veltor GTR (gratis) siguen
siendo más rápidos en recta: nadie necesita pagar para ganar. Mejoras: diferencial nivel 2 ahora sí desbloquea el reparto de tracción; stance nivel 1 se ve y explica
su efecto real. Detalle: `docs/REGISTRO_TECNICO.md` → 16/10 (19).
