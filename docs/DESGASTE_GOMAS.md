# Desgaste de gomas (Etapa 13)

**Qué es:** las gomas puestas se gastan con el uso y pierden agarre de verdad: el desgaste multiplica el agarre por superficie (`surfGrip`) que ya usa la física. Hoy corre en **Dream City, offline**.

**Reglas** (`car/tire_wear.gd`, funciones puras y baratas; `city/city_tires.gd` las aplica 10 veces por segundo):
- Familias: **STREET** (calle) · **SPORT** (deportivo y semi-slick) · **RALLY** (grava y barro) · **DRIFT**. Duración en manejo tranquilo: 90 / 60 / 75 / 35 km.
- Se gasta según la **distancia**, las **curvas** (aceleración lateral), las **frenadas y aceleraciones** (longitudinal), el **derrape** (deslizamiento) y la **superficie** (rally se come en asfalto, deportivas sufren en tierra, drift quema el compuesto).
- Agarre = 1 − (1 − mínimo)·desgaste^1,35 (mínimo: calle 66 %, deportiva 60 %, rally 66 %, drift 72 %).
- Avisos a 70 % («gastadas») y 90 % («casi lisas»); el HUD muestra `🛞 N %` (vida restante) junto a la nafta; nada de esto corre bajo tierra.

**Guardado:** `state["tireWear"] = {id de gomas: desgaste}` dentro de cada auto del perfil (offline, separado del online). Cada juego comprado conserva su propio desgaste; volver a un juego usado lo deja como estaba.

**Taller de ruedas → GOMAS:** muestra el estado del juego puesto y el botón **CAMBIAR** (la mitad del precio de las gomas, mínimo $250; las de calle, que valen 0, igual cuestan 250) que las deja nuevas.

**Online (pendiente, con las instancias de autos online):** el desgaste de un auto online lo calcula y guarda el servidor (`instance_id`), el cliente sólo manda la telemetría que ya manda (distancia/tiempo) y recibe el valor; el cambio de gomas pasa por un RPC que valida dueño, dinero y tipo. Mientras no existan esas instancias, en el modo online **no se aplica desgaste** (`cfg.online` desactiva `CityTires`). Ver `docs/ECONOMIA_ONLINE.md`.

**Prueba:** `tests/tire_wear_test.gd`.
