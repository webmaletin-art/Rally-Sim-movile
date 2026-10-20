# Trabajo en paralelo: dos chats sobre la misma rama

Desde el 19/10/2026 trabajan **dos chats de Claude** sobre el mismo juego y la misma rama:

| Chat | Quién es | Firma en commits y registro |
|---|---|---|
| **A** | El chat de la cuenta principal del dueño (el que hizo las fases 1–6 y la versión candidata) | `[A]` |
| **B** | El chat de la otra cuenta | `[B]` |

**Rama de trabajo:** `ccr-e7ae3f10-45afj2` (la de la versión candidata). **Nunca `main`** sin autorización expresa del dueño.

Este archivo es el **tablero**: antes de tocar un sistema, cada chat lo anota acá, hace commit y push.
Así el otro lo ve con `git pull` y no se pisan.

---

## 1. Antes de empezar cada tarea (siempre, en este orden)

1. `git fetch origin && git pull --rebase origin ccr-e7ae3f10-45afj2`. Nunca trabajar sobre una copia vieja.
2. Leer la sección 4 de este archivo («Tomado ahora») y la sección 5 («Avisos para el otro chat»).
3. Si el sistema o archivo que vas a tocar está **tomado por el otro chat**, no lo edites.
   - Elegí otra tarea, o
   - dejá un aviso en la sección 5 y decíselo al dueño.
4. Anotá tu tarea en «Tomado ahora». Poné:
   - el sistema y los archivos que vas a tocar;
   - tu letra;
   - la fecha y la hora UTC.

   Hacé commit (`[A] Tablero: tomo …` / `[B] Tablero: tomo …`) y push **antes** de editar código.
5. Al terminar, borrá tu fila de «Tomado ahora». Si queda algo pendiente para el otro chat, anotalo en «Avisos».

## 2. Mientras trabajás

- **Commits chicos y frecuentes**, con mensaje en español que diga qué y por qué, empezando con tu letra: `[B] Policía: …`.
- **Antes de cada push:** `git pull --rebase origin ccr-e7ae3f10-45afj2`. Si hay conflicto:
  - **En documentos** (`REGISTRO_TECNICO.md`, `ESTADO_ACTUAL.md`, `CLAUDE.md`, este archivo): quedate con **los dos** textos. Lo más nuevo va arriba.
  - **En código:** no pises lo del otro. Entendé qué hizo (lo explica `git log -p` y su entrada del registro) y combiná las dos cosas. Si no podés combinarlas sin romper algo, pará y preguntale al dueño.
  - **Nunca:** `git push --force`, `git reset --hard` sobre trabajo ajeno, `git checkout -- .`, ni borrar ramas.
- **Si el push lo rechaza** porque el otro subió algo: `pull --rebase` y otra vez. Si falla por la red: reintentar con espera.
- **Compilaciones:** cada push a la rama arma el APK RC en GitHub Actions (`build-godot.yml`, unos 30 min). Un push nuevo **cancela** la compilación anterior de la rama.
  - Agrupá los cambios y no empujes cada 2 minutos: así no se cancelan entre los dos.
  - El APK RC siempre sale del último commit de la rama, o sea, con lo de los dos.

## 3. Archivos «calientes» (los dos los usan seguido: tomarlos SIEMPRE en el tablero antes de editarlos)

| Archivo | Por qué es delicado |
|---|---|
| `godot/game/data/catalog.json` | JSON **compacto en una sola línea**: cualquier cambio de los dos choca entero. Editar con un script que reemplace el texto exacto, sin reformatear. |
| `godot/game/data/vehicles.json` | Física de los 28 autos. No cambiar la física global por un problema de un auto. |
| `godot/game/data/profile.gd`, `rewards.gd`, `release.gd`, `car_build.gd` | Economía, premios, qué se vende y qué se desbloquea. |
| `godot/game/online/account_econ.gd`, `online.gd` | Cuenta y sincronización con el servidor. |
| `godot/game/city/city_modes.gd`, `city_events.gd` | Eventos del servidor y carreras del mapa. |
| `godot/game/ui/menu.gd` | Menú principal, grande y compartido. |
| `.github/workflows/*.yml` | La compilación y la firma. Un error rompe el APK para los dos. |
| `supabase/migrations/*` | El servidor real. Ver sección 6. |
| `CLAUDE.md`, `docs/REGISTRO_TECNICO.md`, `docs/ESTADO_ACTUAL.md`, `docs/INDICE_TECNICO.md` | Los dos escriben. Agregar, nunca reescribir lo del otro. |

## 4. Tomado ahora

| Chat | Sistema / tarea | Archivos | Desde (UTC) |
|---|---|---|---|

## 5. Avisos para el otro chat

- [B] 20/10 (cuarta tanda, versión para publicar; sin filas tomadas): `CityWorld.update_around(p, max_new, budget_ms)` ahora es **por hilos** (una cuadra se calcula en un `WorkerThreadPool` y el hilo principal arma las mallas por partes: las cuadras aparecen primero con el terreno, las calles y los edificios y los locales y árboles un poco después; `CityWorld.threaded = false` vuelve al armado de antes; `warm()` sigue armando todo de golpe). `Autotune.VERSION` pasó a 4 (todos los teléfonos recalibran una vez). Nuevo ajuste `steerAngle` (Ángulo de dirección, 0 = el del auto, 70–130 %) y la página de física ya **no** está en Opciones: las ayudas se eligen sólo al largar cada carrera (`race_hud._fill_pause` ya no trae reglajes fuera de la carrera rápida y las pruebas). `Release.ADVENTURE_STAGES` = 5 etapas libres. `CityHud.in_course()` y `OwEvents.CIRCUITS` (circuitos por cruces de calles). Textos nuevos en `tools/i18n/batches/b70_publicar.py`. Archivos calientes que toqué: `profile.gd`, `release.gd`, `menu.gd`, `.github/workflows/build-godot.yml` (5 pruebas nuevas: `city_leaks_test`, `city_stream_test`, `police_bust_test`, `adv_rules_test`, `sim_level_test`). Detalle en `docs/REGISTRO_TECNICO.md` → 20/10 05:30 [B]. **Nada probado en un teléfono; no se mergeó a `main` ni se aplicó ninguna migración.**
- [B] 20/10: terminé la tercera tanda de calles/colisiones/terreno (sin filas tomadas). Nuevo `godot/game/world/terrain_cap.gd` (`TerrainCap.point`, lo usan `region_world.gd` y `city_world.gd`); `CityLayout` tiene `fillets`/`clip_obstacles`/`wall_push` y `WorldSurfaces` `snow_k`/`side_color`. Detalle en `docs/REGISTRO_TECNICO.md` → 20/10 01:00 [B].
- [B] 19/10: los eventos del servidor (`city_modes.gd`) ahora sólo corren con `cfg.events` = true (el mundo se abrió desde el MODO ONLINE: `menu_world.events_entry`). Si armás otro camino al mundo abierto desde el online, poné `events_entry = true`. En la pantalla de juego ya no hay `_big` por anuncios: usar la pausa → EVENTOS (`event_cards`). Detalle en `docs/REGISTRO_TECNICO.md` → 19/10 [B].
- [A] 19/10: la versión candidata está en la release `godot-apk-rc` (commit `2ae3c00`). El dueño todavía no la probó en el teléfono. Las migraciones 20261022, 20261023 y 20261024 **no están aplicadas** (esperan su autorización). La cacería `caza_inicial` queda apagada hasta publicar. Todo en `docs/VERSION_CANDIDATA.md`.

## 6. Migraciones del servidor (Supabase)

- **Nombres:** para que no choquen los nombres:
  - el chat **A** usa la hora `…000000` (ej. `20261025000000_x.sql`);
  - el chat **B** usa `…120000` (ej. `20261025120000_x.sql`).

  Antes de crear una, mirá cuál es la última en `supabase/migrations/` después de un `pull`.
- **Siempre aditivas y repetibles:** `if not exists`, `on conflict do nothing`, y un bloque de autoprueba `do $$ … $$`. Nada destructivo.
- **Nunca se aplican al servidor real** sin que el dueño lo autorice con esas palabras. Se aplican con el flujo «Supabase · aplicar migraciones».
- **Ojo con `_acct_one`:** es un envoltorio de `_acct_one_base` (desde 20261021). Una migración que reemplace `_acct_one` entera tiene que conservar ese envoltorio.
- **Pruebas:** toda migración nueva se prueba en `tools/online/account_test.sql` o `economy_test.sql`. Las corre GitHub («Economía online · prueba SQL») en un Postgres de prueba.
- **Servidor compartido:** el APK estable usa el mismo servidor. Algo que el APK viejo no entienda se deja apagado hasta publicar la versión nueva.
