# Índice técnico (mapa de navegación)

Para encontrar rápido el sistema de un pedido sin leer todo el repositorio. Rutas relativas a `godot/` salvo que digan otra cosa.
Orden de consulta: `CLAUDE.md` → esta tabla → la sección de `docs/ESTADO_ACTUAL.md` → antecedentes en `docs/REGISTRO_TECNICO.md` → el documento del sistema → el código.
Estructura general de carpetas: `docs/ARQUITECTURA.md`.

| Módulo | Documento | Archivos principales | Depende de | Pruebas (`tests/`) | Estado | Última modificación |
|---|---|---|---|---|---|---|
| Física del vehículo | `docs/ESPECIFICACION_TECNICA.md` | `game/physics/vehicle_physics.gd`, `vehicle_params.gd`, `track_base.gd` (altura/superficie: `ground_info`) | datos `game/data/vehicles.json` | `physics_test`, `wall_test`, `surfaces_test` | estable | — |
| Controles y dirección | `ROADMAP.md` (controles) | `game/ui/controls.gd` | física | `controls_test`, `menu_input_test` | estable | — |
| Cámaras | `docs/AUTOS.md` (cabina) | `game/car/camera_rig.gd` (`_clearance`), `game/car/cabin_cfg.gd` | pista (`camera_clear`) | `interp_test` | estable | — |
| Modelos 3D, interiores, pilotos | `docs/AUTOS.md`, `docs/PIEZAS_MODULARES.md` | `game/car/car_visual.gd`, `cockpit.gd`, `pilot.gd`, `paint_presets.gd`, `wheel_gen.gd`; modelos `game/models/cars/`; pipeline `tools/cars/` | catálogo | `cars_test`, `parts_test` | estable | — |
| Audio | `docs/AUDIO.md`, `docs/AUDIO_MUNDO.md` | `game/audio/car_audio.gd` (`simple`), `music_player.gd`, `world_ambient.gd` | — | `audio_levels_test`, `music_test` | estable | 14/10 audio simple |
| Diagnóstico de cierres | `docs/REGISTRO_TECNICO.md` («Cierre al acelerar») | `game/diag/crash_log.gd` (contenido), `bootstrap/crash_guard.gd` (sólo APK nuevo), botón en `game/ui/menu_about.gd` y `options_ui.gd` (Sonido) | `app.gd`, `race.gd` (`_diag_tick`) | `crash_log_test` | PENDIENTE DE APK | 14/10 |
| Gráficos y rendimiento Android | `docs/OPTIMIZACION_ANDROID.md`, `docs/CONFIGURACION_GRAFICA_AUTOMATICA.md`, `docs/OPTIMIZACION_MUNDO_ABIERTO.md` | `game/autotune.gd`, `game/ui/frame_res.gd`, `game/ui/calibration.gd`, `game/fx/effects.gd` (partículas) | — | `autotune_test`, `ow_opt_test`, `world_budget_test` | estable | — |
| Mundo abierto (Dream City) | `docs/MUNDO_ABIERTO.md` | `game/city/city_layout.gd` (plan de calles, `POI_SPECS`), `city_world.gd` (mallas por cuadra), `game/track/city_track.gd` (corredores/pared, `push`) | región | `city_test`, `open_world_access_test` | estable | — |
| Región y carreteras | `docs/REGION.md` | `game/region/region_data.gd`, `region_world.gd`, `region_services.gd`; datos `game/data/region/region_1.bin`; generador `tools/world_gen/` | ciudad | `region_test`, `region_junction_test`, `region_connectors_test`, `region_polish_test`, `region_terrain_test`, `region_drive_test` | estable | 13/10 retoques |
| Terreno y colisiones | `docs/REGION.md` («Terreno, calles…») | `region_world.gd` (`_road_caps`), `region_data.gd` (`corridor`), `city_track.gd` (`_push_locked`) | región | `region_terrain_test`, `wall_test` | estable | 13/10 |
| Streaming de mapas | `docs/OPTIMIZACION_MUNDO_ABIERTO.md`, `docs/RED_DE_RUTAS.md` | `city_world.gd` (cuadras 160 m), `region_world.gd` (cuadrados 256 m, hilos), `game/world/world_sector_manager.gd` | — | `region_perf_test` | estable | — |
| Gasolineras y talleres | `docs/MUNDO_ABIERTO.md` («Locales»), `docs/REGION.md` | `game/city/city_fuel.gd`, `city_shops.gd`, `city_tires.gd`, `city_toll.gd`, `region_services.gd`; `game/data/shops.gd` | ciudad, región | `open_world_access_test` | estable | — |
| Carreras y campeonatos | `docs/RUTAS_NUEVAS.md` | `game/race.gd`, `race_rules.gd`, `session.gd`, `game/data/rewards.gd`, `game/data/routes.json`, `game/ui/menu_career.gd` | física, IA | `rewards_test`, `track_test`, `custom_route_test`, `map_v3_test` | estable | — |
| IA rival y persecuciones | `docs/RED_DE_RUTAS.md`, `docs/TRAVESIA_X.md` | `game/ai/ai_driver.gd`, `city_driver.gd`, `convoy.gd`; `game/net/net_session.gd` (persecución en rutas) | física | `ai_test`, `ai_route_test`, `net_chase_test`, `travesia_test` | estable | — |
| Policía (controles en rutas) | `docs/POLICIA.md` | `game/city/city_police.gd` (servicio), `game/ai/police_driver.gd`; `race.gd` (`add_ai_car`, `remove_car`) | región (`RegionData`), GPS (`world_gps.gd`), economía (`profile.spend`) | `police_test` | 📱 por probar | 14/10 |
| Modo Aventura | `docs/MODO_AVENTURA.md` | `game/adventure/` | IA, física | `adv_route_test`, `adv_sim_test` | estable | — |
| Modo Online | `docs/ONLINE_SUPABASE.md`, `docs/ECONOMIA_ONLINE.md` | `game/online/online.gd`, `online_social.gd`, `world_sync.gd`, `realtime.gd`, `remote_cars.gd`, `remote_motion.gd`; menú `game/ui/menu_world.gd` | Supabase | `online_test`, `realtime_test`, `remote_motion_test` | cerrado (`Release.ONLINE_OPEN`) | 13/10 |
| Supabase y Realtime | `docs/ONLINE_SUPABASE.md` | `supabase/migrations/`, `supabase/functions/` (raíz del repo); flujos `.github/workflows/supabase-*.yml` | — | `economy-test.yml` | aplicado 13/10 | 13/10 |
| Cuentas y economía | `docs/CUENTA_Y_ECONOMIA.md` | `game/online/account_econ.gd`, `game/data/profile.gd`, `game/data/release.gd` | Supabase | `account_econ_test`, `login_wall_test` | hecho | 13/10 |
| Tienda y personalización | `docs/PIEZAS_MODULARES.md`, `docs/PLAY_STORE.md` | `game/ui/menu_garage.gd`, `menu_store.gd`, `game/car/paint_presets.gd`, `game/store/billing.gd`, `game/data/catalog.json` | economía | `parts_test`, `release_test` | estable | — |
| Menús | `docs/MENU_PREMIUM.md` | `game/ui/menu.gd`, `menu_chrome.gd`, `menu_*.gd`, `ui_kit.gd`, `showroom.gd` | — | `menu_ui_test`, `spawn_menu_test` | estable | — |
| Exportación Android y Google Play | `docs/PLAY_STORE.md`, `docs/MIGRACION_GODOT.md`, `docs/GUIA_SUBIR_A_PLAY.md` | `.github/workflows/build-godot.yml`, `build-aab.yml`; `export_presets.cfg`; `bootstrap/boot.gd` (APK liviano: baja `content.pck` + `cars.pck`); `tools/export/` | — | `scripts_parse_test`, `build_test` | estable | 14/10 |

## Reglas que conviene saber antes de tocar
- **El contenido descargado (`res://game`) NO puede cargar nada de `res://bootstrap/`**: el preset «Content» lo excluye y un APK viejo no lo trae (así se rompió «COPIAR REGISTRO», ver registro 14/10).
- Lo que va en `project.godot` (autoloads, registro de archivo del motor) sólo vale con un APK instalado nuevo: el contenido descargado no lo cambia.
- Ejes del mundo abierto: x al este, z al sur; la plaza Aurora en (0,0). `CityLayout.WORLD_VERSION` invalida la última ubicación guardada.
- `config/name` («GSkorp Rally») no se cambia: mueve la carpeta de guardado.
