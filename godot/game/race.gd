extends Node3D
## Prueba de fuego de la versión Godot: circuito, autos con la física verificada (la misma de la versión HTML),
## el Volt con su modelo real, pilotos, bosque y controles táctiles. El contador de arriba a la izquierda
## muestra FPS, milisegundos y objetos dibujados; los botones de la derecha cambian la carga
## (autos, árboles, pilotos, sombras) para medir hasta dónde llega el teléfono.

const CircuitTrack := preload("res://game/track/circuit_track.gd")
const RouteTrack := preload("res://game/track/route_track.gd")
const DriftTrack := preload("res://game/track/drift_track.gd")
const CityTrack := preload("res://game/track/city_track.gd")
const CitySession := preload("res://game/city_session.gd")
const OnlineSocial := preload("res://game/online/online_social.gd")
const CityDriver := preload("res://game/ai/city_driver.gd")
const CityShops := preload("res://game/city/city_shops.gd")
const CityLinks := preload("res://game/city/city_links.gd")
const CityDrift := preload("res://game/city/city_drift.gd")
const RemoteCars := preload("res://game/online/remote_cars.gd")
const WorldLife := preload("res://game/world/world_life.gd")
const ParkedCars := preload("res://game/world/parked_cars.gd")
const CivilTraffic := preload("res://game/world/civil_traffic.gd")
const WorldLifeConfig := preload("res://game/world/world_life_config.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const CityFuel := preload("res://game/city/city_fuel.gd")
const CityTires := preload("res://game/city/city_tires.gd")
const CityActivities := preload("res://game/city/city_activities.gd")
const CityClock := preload("res://game/city/city_clock.gd")
const CityToll := preload("res://game/city/city_toll.gd")
const DriftSession := preload("res://game/drift_session.gd")
const PaperTrack := preload("res://game/track/paper_track.gd")
const Drag := preload("res://game/data/drag.gd")
const PaperWorld := preload("res://game/track/paper_world.gd")
const DreamTrack := preload("res://game/track/dream_track.gd")
const DreamWorld := preload("res://game/track/dream_world.gd")
const FantasyWorld := preload("res://game/track/fantasy_world.gd")
const DriftBot := preload("res://game/ai/drift_bot.gd")
const MeshChunks := preload("res://game/track/mesh_chunks.gd")
const PerfBench := preload("res://game/perf_bench.gd")
const PerfResults := preload("res://game/ui/perf_results.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const RingDriver := preload("res://game/ai/ring_driver.gd")
const Pilot := preload("res://game/car/pilot.gd")
const DebugPanel := preload("res://game/ui/debug_panel.gd")
const Controls := preload("res://game/ui/controls.gd")
const Effects := preload("res://game/fx/effects.gd")
const Weather := preload("res://game/fx/weather.gd")
const Lens := preload("res://game/fx/lens.gd")
const Cockpit := preload("res://game/car/cockpit.gd")
const Capture := preload("res://game/capture.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CarAudio := preload("res://game/audio/car_audio.gd")
const CameraRig := preload("res://game/car/camera_rig.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const AiCars := preload("res://game/data/ai_cars.gd")
const Session := preload("res://game/session.gd")
const RaceHud := preload("res://game/ui/race_hud.gd")
const UiSfx := preload("res://game/audio/ui_sfx.gd")
const AdvTrack := preload("res://game/adventure/adv_track.gd")
const AdvWorld := preload("res://game/adventure/adv_world.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const Adventure := preload("res://game/adventure/adventure.gd")

## La carrera terminó (result: value, medal, position, time, etc.; lo arma _make_result) o se pidió salir al menú
signal finished(result: Dictionary)
signal exit_requested(back: String)
## Carga del mapa por etapas (la pantalla de carga muestra el avance); «loaded» avisa que ya se puede largar
signal load_progress(frac: float, text: String)
signal loaded

## Configuración de la carrera (la arma el menú): car, state, track, weather, ai, laps, seg, type, event, tier…
## Vacía = escena de pruebas (la de los argumentos --shot, --bench, etc.)
var is_loaded := false
var cfg: Dictionary = {}
var profile: RefCounted
var online: Node # app.gd: la conexión online (sólo se usa en el mundo online)
var social: Node # online_social.gd: chat, presencia, amigos, reportes y mercado
var menu_mode := false
var session # Session (carreras) o DriftSession
var race_hud: Control
var paused := false
var done_t := 0.0
var sim_hold := false
var rival_info: Array = [] # {name, color} por auto

var track # CircuitTrack o RouteTrack
var track_id := "prueba"
var auto_player := false
var track_root: Node3D
var terrain_task := -1
var terrain_rows: Array = []
var terrain_r := 0
var track_maps: Dictionary
var cars: Array = []
var vehicles: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var hud: Control # panel de pruebas
var controls: Control # controles de manejo
var trees_node: Node3D
var fx: Node3D # humo, polvo y marcas
var weather: Node3D
var env: Environment
var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var weather_name := "dia"
var force_steer := 0.0
var cam_yaw := 0.0
var cam_ready := false
var phys_us := 0
var phys_frames := 0
var shown_phys_ms := 0.0
var stat_timer := 0.0
var frame_count := 0
var shot_path := ""
var shot_frames := 0
var bench := false
var fps_sum := 0.0
var fps_n := 0
var cars_n := 4
var trees_n := 3000
var pilots_on := true
var hi_model := true
var cam_mode := ""
var threaded := true
var manual_gearbox := false
var drag_mode := false # picada: caja manual obligatoria, ventana de cambio en la barra de vueltas y calidad de cada cambio
var drag_rpm := 0.0 # vueltas del cuadro anterior (antes de que el cambio las baje)
var drag_shifts := 0
var drag_perfect := 0
var nitro_test := false
var world: SubViewport # el mundo 3D se dibuja acá, a menor resolución que la pantalla (el HUD queda nítido)
var view_rect: TextureRect
var res_scale := 0.5
var bench_i := -1 # índice de la prueba automática en curso (-1 = apagada)
var bench_t := 0.0
var _bench_samples: Array = []
var report_body: Array = [] # líneas detalladas por configuración
var bench_results: Array = []
var no_body := false
var force_gas := false
var force_hb := false
var dirt_test := false
var autobench := false
var fx_hold := 0.0 # segundos sin partículas después de poner los autos en la largada
var pb_active := false # prueba de rendimiento completa (cfg type = bench)
var pb_plan: Array = []
var pb_i := -1
var pb_t := 0.0
var pb_samples: Array = []
var pb_results: Array = []
var pb_ui: Control
var pb_report := ""
var pb_user_fx: Array = [0, 0, 0]
var pb_user_level := 0
var acc := 0.0
var step_n := 0
var fx_on := true
var res_auto := true # la resolución del mundo 3D se ajusta sola según los cuadros por segundo
var script_ms := 0.0
var cockpit: Node3D
var audio: Node
var sfx: Node
var pl_events: Array = []
var pl_impact := 0.0
var audio_on := true
var audiorec_path := ""
var audiorec: AudioEffectRecord
var cam_rig: RefCounted
var was_inside := false
var was_onboard := false
var cam_index := 1
var lab_state: Dictionary = {} # taller de prueba de la pausa: estado del auto con ajustes (vacío = el auto tal cual)
var lab_orig: Dictionary = {}
var _pausetest_done := false
var wall_on := false # pista solo de camino: límite lateral con árboles (se activa en las carreras del menú)
var track_arg := ""
var view_at := -1.0 # prueba (vistas previas de las pistas): pone el auto en esta fracción del recorrido
var fx_arg := "" # prueba: efectos 2.0 por argumento (p. ej. --fx=11,3,0)
var lens_auto := true # el filtro se apaga solo si el teléfono no llega
var lens: Node # filtro de cámara (Lente Rally)
var adv_mode := false # modo aventura (etapa de la Ruta de los Sueños)
var adv_world: Node3D # mundo por tramos de la aventura
var adv: Node # controlador de la aventura (etapa, rival, estaciones, cinemáticas)
var adv_alt # pista del ramal de la bifurcación (o null)
var adv_world_alt: Node3D

## Vista de la pista del jugador: en la aventura puede pasar al ramal de una bifurcación
func player_view():
	var v = track.make_view()
	if adv_alt != null:
		v.link_other(adv_alt.make_view())
	return v

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--shopshot="):
			shopshot = a.substr(11) # prueba: al volver de un taller se saca una captura y se cierra
		elif a.begins_with("--audiorec="):
			audiorec_path = a.substr(11)
		elif a == "--autobench":
			autobench = true
		elif a.begins_with("--steer="):
			force_steer = float(a.substr(8))
		elif a.begins_with("--weather="):
			weather_name = a.substr(10)
		elif a == "--dirt":
			dirt_test = true
		elif a == "--hb":
			force_hb = true
		elif a == "--gas":
			force_gas = true
		elif a == "--nobody":
			no_body = true
		elif a == "--bench":
			bench = true
		elif a.begins_with("--cam="):
			cam_mode = a.substr(6)
			cam_index = {"onboard": 0, "cabin": 0, "chase": 1, "near": 2, "far": 3, "aerial": 4, "rear": 6, "hood": 7, "bumper": 8}.get(cam_mode, 1)
		elif a == "--auto":
			auto_player = true
		elif a.begins_with("--fx="):
			fx_arg = a.substr(5)
		elif a.begins_with("--viewat="):
			view_at = float(a.substr(9))
		elif a.begins_with("--track="):
			track_id = a.substr(8)
			track_arg = track_id
		elif a.begins_with("--cars="):
			cars_n = int(a.substr(7))
		elif a.begins_with("--trees="):
			trees_n = int(a.substr(8))
		elif a.begins_with("--adv=") and cfg.is_empty():
			# prueba: arranca directo una etapa de la aventura (--adv=3 o --adv=3:0.4 para empezar en esa fracción)
			var parts := a.substr(6).split(":")
			cfg = {"type": "adventure", "stage": int(parts[0]), "back": "home"}
			if parts.size() > 1:
				cfg["at"] = float(parts[1])
			if OS.get_cmdline_user_args().has("--advintro"):
				cfg["intro"] = true
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	track_maps = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	menu_mode = not cfg.is_empty()
	adv_mode = str(cfg.get("type", "")) == "adventure"
	pb_active = str(cfg.get("type", "")) == "bench"
	if adv_mode:
		Adventure.prepare_cfg(cfg, profile)
	if menu_mode:
		track_id = track_arg if track_arg != "" else str(cfg.get("track", "forest"))
		weather_name = {"day": "dia", "overcast": "nublado", "rain": "lluvia", "sunset": "atardecer", "dusk": "ocaso", "snow": "nieve"}.get(str(cfg.get("sky", "day")), "dia")
		cars_n = 1 + int(cfg.get("ai", 0))
		trees_n = 3000
		wall_on = true
		if cam_mode == "":
			cam_index = int(profile.setting("camera")) if profile != null else 1
		manual_gearbox = profile != null and str(profile.setting("gearbox")) == "manual"
		drag_mode = cfg.get("drag", false) == true
		manual_gearbox = manual_gearbox or drag_mode
	load_progress.emit(0.04, "Armando el recorrido…")
	await get_tree().process_frame
	_make_track()
	load_progress.emit(0.16, "Construyendo camino, banquinas y guardarraíl…")
	await get_tree().process_frame
	_setup_viewport()
	_build_world()
	load_progress.emit(0.34, "Preparando los controles…")
	await get_tree().process_frame
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	controls = Controls.new()
	layer.add_child(controls)
	if menu_mode:
		race_hud = RaceHud.new()
		layer.add_child(race_hud)
		race_hud.resume_pressed.connect(_toggle_pause)
		race_hud.restart_pressed.connect(_restart)
		race_hud.quit_pressed.connect(_quit)
		race_hud.camera_pressed.connect(_next_camera)
		race_hud.cine_pressed.connect(_toggle_cine)
		race_hud.edit_controls_pressed.connect(_edit_controls)
		race_hud.cam_step.connect(func(d: int) -> void:
			if cam_rig != null:
				cam_rig.next(d)
				_save_cam_adj())
		race_hud.camadj_changed.connect(_save_cam_adj)
		race_hud.lab_changed.connect(_lab_apply)
		race_hud.lab_reset.connect(_lab_reset)
		controls.pause_pressed.connect(_toggle_pause)
	hud = DebugPanel.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)
	if menu_mode:
		_show_tests(false) # el panel de pruebas queda escondido; se abre desde la pausa
	hud.option_changed.connect(_on_option)
	hud.bench_pressed.connect(_bench_start)
	hud.copy_pressed.connect(_copy_report)
	controls.camera_pressed.connect(_next_camera)
	controls.cam_drag.connect(func(rel: Vector2) -> void:
		if cam_rig != null and not paused:
			cam_rig.drag(rel))
	controls.cam_zoom.connect(func(f: float) -> void:
		if cam_rig != null and not paused:
			cam_rig.zoom(f))
	controls.shot_pressed.connect(_take_shot)
	controls.show_shot = menu_mode and profile != null and profile.setting("capBtn") == true
	load_progress.emit(0.44, "Clima y efectos…")
	await get_tree().process_frame
	fx = Effects.new()
	world.add_child(fx)
	fx.setup(track)
	fx.set_quality("media")
	weather = Weather.new()
	world.add_child(weather)
	weather.setup(env, sun, cam, track, fx, road_mat, ground_mat)
	if track is DreamTrack:
		weather_name = "dia" # el Vórtice de Ensueño tiene su propio cielo: sin lluvia ni nubes del clima común
	weather.apply(weather_name, true)
	if track is PaperTrack:
		_paper_atmosphere()
	if track is DreamTrack:
		_dream_atmosphere()
	if track is CityTrack:
		_city_atmosphere()
	audio = CarAudio.new()
	add_child(audio)
	sfx = UiSfx.new()
	add_child(sfx)
	if menu_mode:
		sfx.volume = float(profile.setting("volume")) / 100.0
		race_hud.setup_options(profile, sfx)
		race_hud.options_changed.connect(_apply_live_settings)
		if not adv_mode and not pb_active and (cfg.get("testCar", false) == true or cfg.get("quick", false) == true):
			_lab_init()
	if audiorec_path != "":
		audiorec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, audiorec)
		audiorec.set_recording_active(true)
	audio.rain(weather_name == "lluvia")
	if menu_mode:
		# opciones del jugador
		lens.apply_settings(profile)
		lens_auto = true
		var rs := float(profile.setting("res"))
		if rs > 0.0:
			res_auto = false
			res_scale = rs
			_on_resize()
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(profile.setting("volume")) / 80.0, 0.001)))
		_apply_quality_settings()
		_apply_controls_settings()
	if fx_arg != "":
		var fa: Array = []
		for t in fx_arg.split(","):
			fa.append(int(t))
		while fa.size() < 3:
			fa.append(0)
		lens.fx = fa
	load_progress.emit(0.56, "Plantando el bosque…")
	await get_tree().process_frame
	if adv_mode:
		# el mundo de la aventura se arma por tramos: los primeros ~900 m antes de largar
		var s_from: float = float(cfg.get("s_load", 0.0))
		var c0: int = adv_world._chunk_at(s_from - 250.0)
		var c1: int = adv_world._chunk_at(s_from + 900.0)
		for ci in range(c0, c1 + 1):
			adv_world._build_chunk_sync(ci)
			load_progress.emit(0.56 + 0.14 * float(ci - c0 + 1) / float(c1 - c0 + 1), "Armando la ruta… %d m" % int(float(ci - c0 + 1) * 120.0))
			await get_tree().process_frame
	else:
		_rebuild_trees()
	load_progress.emit(0.70, "Armando los autos y los rivales…")
	await get_tree().process_frame
	_rebuild_cars()
	load_progress.emit(0.80, "Armando el terreno…")
	await get_tree().process_frame
	# el terreno se calcula en hilos: se espera a que termine (sin congelar la pantalla) y se agrega
	while terrain_task != -1 and not WorkerThreadPool.is_group_task_completed(terrain_task):
		await get_tree().process_frame
	_check_terrain()
	load_progress.emit(0.92, "Compilando efectos…")
	# unos cuadros con todo ya dibujado (tapados por la pantalla de carga): ahí se compilan los shaders y no hay tirones al largar
	for i in 6:
		fx.tick(cam.position) # precalienta los emisores de partículas mientras la pantalla de carga los tapa
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--hidecars"):
		for c in cars:
			c.visual.visible = false
	if OS.get_cmdline_user_args().has("--nohud"):
		controls.visible = false
		hud.visible = false
		if race_hud != null:
			race_hud.visible = false
	if autobench:
		_bench_start()
	if pb_active:
		_pb_start()
	is_loaded = true
	if OS.get_cmdline_user_args().has("--labtest"):
		print("LABTEST: carga lista, sesión ", session)
	load_progress.emit(1.0, "Listo")
	loaded_emit_deferred()

func loaded_emit_deferred() -> void:
	await get_tree().process_frame
	loaded.emit()

## En celulares de gama media dibujar a la resolución nativa (2400x1080) es lo que más pesa: el mundo 3D se dibuja en un
## SubViewport a una fracción de la pantalla y se estira; el HUD se dibuja aparte, a resolución completa.
func _setup_viewport() -> void:
	var l0 := CanvasLayer.new()
	l0.layer = 0
	add_child(l0)
	world = SubViewport.new()
	world.msaa_3d = Viewport.MSAA_DISABLED
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	view_rect = TextureRect.new()
	view_rect.texture = world.get_texture()
	view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l0.add_child(view_rect)
	lens = Lens.new()
	add_child(lens)
	lens.attach(view_rect, world)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	world.size = Vector2i(maxi(320, int(win.x * res_scale)), maxi(180, int(win.y * res_scale)))
	if lens != null:
		lens.resize_to_world()
	view_rect.position = Vector2.ZERO
	view_rect.size = get_viewport().get_visible_rect().size

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.83, 0.92)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.93)
	env.fog_density = 0.0016
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_opacity = 0.42 # sombra clara y suave, no negra
	sun.shadow_blur = 2.5
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 1200.0
	world.add_child(cam)
	cam.make_current()
	_build_track_nodes()

## Vórtice de Ensueño: cielo con Júpiter gigante, niebla pastel, sol dorado y reflejos de sol sobre las flores
## Alcance de la vista de los mapas fantasía según la calidad: 0,6 (teléfonos flojos) · 0,8 · 1,0. Achica las distancias de visibilidad y la niebla para ahorrar dibujo.
func _view_k() -> float:
	var q := str(profile.setting("quality")) if profile != null else "mid"
	var dq: float = float({"low": 0.5, "high": 1.0}.get(q, 0.75)) if q != "auto" else float([0.5, 0.75, 1.0][clampi(int(profile.setting("autoTier")), 0, 2)])
	return lerpf(0.6, 1.0, (dq - 0.5) / 0.5)

func _dream_atmosphere() -> void:
	var th: String = str(track.theme)
	if th == "dream":
		DreamWorld.atmosphere(env, sun, cam, world)
	else:
		FantasyWorld.atmosphere_of(th, env, sun, cam, world, _view_k()) # Marte, la Luna o el anillo de Júpiter

## Dream City: cielo de día y niebla que cierra las calles a la distancia en que se arman las cuadras (más cerca en teléfonos flojos)
func _city_atmosphere() -> void:
	var vk := _view_k()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.40, 0.62, 0.90)
	psm.sky_horizon_color = Color(0.86, 0.90, 0.95)
	psm.ground_horizon_color = Color(0.80, 0.84, 0.86)
	psm.ground_bottom_color = Color(0.70, 0.74, 0.74)
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.82, 0.87, 0.92)
	env.fog_depth_begin = 160.0 * vk
	env.fog_depth_end = 560.0 * vk
	cam.far = 1600.0
	if menu_mode and profile != null:
		clock = CityClock.new()
		clock.setup(self, psm)

## Paper Race: cielo y niebla de papel (la selva se cierra a lo lejos), luz suave y pareja
func _paper_atmosphere() -> void:
	env.background_color = Color(0.88, 0.91, 0.84)
	env.fog_enabled = true
	env.fog_light_color = Color(0.84, 0.89, 0.80)
	env.fog_density = 0.0062
	env.ambient_light_color = Color(0.86, 0.88, 0.82)
	env.ambient_light_energy = 0.8
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)

## Crea la pista elegida (el circuito de prueba o una de las rutas de la versión web)
func _make_track() -> void:
	if adv_mode:
		track = AdvTrack.new(int(cfg.get("stage", 0)))
		track_id = "adv"
		adv_alt = null
		if not track.forks.is_empty():
			# la etapa tiene una bifurcación: el ramal es otra variante de la pista (mismo principio y mismo final)
			adv_alt = AdvTrack.new(int(cfg.get("stage", 0)), int(track.forks[0]["fork"]))
			track.cross_clear(adv_alt)
			adv_alt.cross_clear(track)
		return
	if track_id == "aurelia":
		track = CityTrack.new() # el mundo abierto: Dream City (no figura en routes.json: no es una pista de carrera)
		if profile != null and not cfg.has("resume"):
			# se aparece dentro del Estacionamiento Central: en la sala que se eligió en el menú (por defecto la planta baja)
			track.spawn_i = int(cfg.get("spawn", 0)) % track.city.spawns.size()
		return
	if track_id == "prueba" or not track_maps.has(track_id):
		track_id = "prueba"
		track = CircuitTrack.new()
		if dirt_test:
			track.outside_surf = 1.0
		return
	var m: Dictionary = track_maps[track_id]
	if str(m.get("kind", "")) == "drift":
		track = DriftTrack.new()
		return
	if str(m.get("kind", "")) == "dream":
		track = DreamTrack.new(str(m["route"]), str(m["mode"]), false, 0.0) # mapas fantasía: el Vórtice de Ensueño, Marte, la Luna y el anillo de Júpiter
		track.theme = str(m.get("world", "dream"))
		track.title = str(m.get("name", "")).to_upper()
		return
	if str(m.get("kind", "")) == "paper":
		track = PaperTrack.new(str(m["route"]), str(m["mode"]), false, 0.6) # Paper Race: selva de papel, ruta y tierra
		return
	track = RouteTrack.new(str(m["route"]), str(m["mode"]), m.get("reverse", false) == true, float(m.get("hills", 1.0)) if menu_mode else 0.0)
	if m.has("strip"):
		cfg["seg"] = track.seg_between_x(float(m["strip"][0]), float(m["strip"][1])) # picada: el tramo recto de la ruta, de una marca a otra (x en metros)

## Suelo, camino, banquina y terreno de la pista (el terreno se calcula en hilos y aparece cuando está listo)
func _build_track_nodes() -> void:
	if track_root != null:
		track_root.queue_free()
	track_root = Node3D.new()
	world.add_child(track_root)
	terrain_task = -1
	if adv_mode:
		adv_world = AdvWorld.new()
		if adv_alt != null:
			adv_world.cross = adv_alt.make_view()
		var q := str(profile.setting("quality")) if profile != null else "mid"
		adv_world.setup(track, {"low": 0.6, "high": 1.3}.get(q, 1.0))
		track_root.add_child(adv_world)
		road_mat = adv_world.road_mat
		ground_mat = adv_world.terrain_mat
		if adv_alt != null:
			adv_world_alt = AdvWorld.new()
			adv_world_alt.branch = true
			adv_world_alt.cross = track.make_view()
			adv_world_alt.setup(adv_alt, adv_world.quality)
			track_root.add_child(adv_world_alt)
		return
	if track is CityTrack:
		var cw: Node3D = track.build_world()
		cw.view_k = _view_k()
		track_root.add_child(cw)
		var spw: Array = track.start_pose(0)
		var wp := Vector3(float(spw[0]), 0.0, float(spw[1]))
		if cfg.has("resume"):
			wp = Vector3(float(cfg["resume"][0]), 0.0, float(cfg["resume"][1])) # se vuelve de un taller: las cuadras de ese lugar
		cw.warm(wp) # las cuadras de alrededor ya armadas antes de largar
		road_mat = track.road_mat
		ground_mat = track.ground_mat
		return
	if track is DriftTrack:
		track_root.add_child(track.build_world())
		road_mat = track.road_mat
		ground_mat = track.ground_mat
		return
	if track is DreamTrack:
		var dw: Node3D = DreamWorld.new() if track.theme == "dream" else FantasyWorld.new()
		var dq_q := str(profile.setting("quality")) if profile != null else "mid"
		var dq: float = float({"low": 0.5, "high": 1.0}.get(dq_q, 0.75)) if dq_q != "auto" else float([0.5, 0.75, 1.0][clampi(int(profile.setting("autoTier")), 0, 2)])
		if track.theme == "dream":
			dw.view_k = _view_k()
			dw.setup(track, dq, DreamWorld.SUN)
		else:
			dw.setup_world(track, dq, track.theme, _view_k())
		track_root.add_child(dw)
		road_mat = StandardMaterial3D.new()
		ground_mat = StandardMaterial3D.new()
		track_root.add_child(track.build_start_gate(0, str(track.title)))
		return
	if track is PaperTrack:
		var pw := PaperWorld.new()
		var qd: float = float({"low": 0.55, "high": 1.15}.get(str(profile.setting("quality")) if profile != null else "mid", 0.85))
		pw.setup(track, qd)
		track_root.add_child(pw)
		road_mat = StandardMaterial3D.new() # el clima no toca los materiales de papel
		ground_mat = StandardMaterial3D.new()
		track_root.add_child(track.build_start_gate(0, "DREAM RACING"))
		return
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.21, 0.35, 0.15)
	gm.roughness = 1.0
	ground.material_override = gm
	ground_mat = gm
	track_root.add_child(ground)
	var road := MeshInstance3D.new()
	road.mesh = track.build_road_mesh()
	if track is RouteTrack:
		var miny := 1e9
		for sp in track.samples:
			miny = minf(miny, sp.y)
		ground.position = Vector3(track.center_xz().x, miny - 6.0, track.center_xz().y)
		road_mat = (road.mesh as ArrayMesh).surface_get_material(0)
		road.material_override = road_mat
		var sh := MeshInstance3D.new()
		sh.mesh = track.build_shoulder_mesh()
		track_root.add_child(_chunked(sh))
		var g0 := 0
		var g1 := -1
		if menu_mode and cfg.get("seg") is Array:
			g0 = int(floor(float(cfg["seg"][0]) * float(track.n)))
			g1 = int(floor(float(cfg["seg"][1]) * float(track.n)))
		track_root.add_child(track.build_start_gate(g0, "LARGADA" if g1 >= 0 else "DREAM RACING"))
		if g1 >= 0:
			track_root.add_child(track.build_start_gate(g1, "📸 RADAR" if str(cfg.get("type")) == "trap" else "META", Color(1.0, 0.35, 0.3)))
		if wall_on:
			var gr: Node3D = track.build_guardrail(rail_off(), track.mode == "dirt")
			MeshChunks.chunk_children(gr)
			track_root.add_child(gr)
			var tn := 1500 if (menu_mode and str(profile.setting("quality")) == "low") else (6000 if (menu_mode and str(profile.setting("quality")) == "high") else 3500)
			track_root.add_child(track.build_tufts(tn, rail_off() + 0.6, 4242))
		var dims: Dictionary = track.terrain_dims()
		terrain_r = int(dims["R"])
		terrain_rows.clear()
		terrain_rows.resize(terrain_r + 1)
		terrain_task = WorkerThreadPool.add_group_task(_terrain_row_job, terrain_r + 1, -1, true, "terreno")
	else:
		var rm := StandardMaterial3D.new()
		rm.vertex_color_use_as_albedo = true
		rm.roughness = 0.9
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		road.material_override = rm
		road_mat = rm
	track_root.add_child(_chunked(road) if track is RouteTrack else road)

## Un objeto largo de la pista partido en tramos (el motor descarta los que no se ven): ver MeshChunks
func _chunked(mi: MeshInstance3D) -> Node3D:
	var holder := Node3D.new()
	holder.add_child(mi)
	MeshChunks.chunk_children(holder)
	return holder

func _terrain_row_job(iz: int) -> void:
	terrain_rows[iz] = track.terrain_row(iz, terrain_r)

func _check_terrain() -> void:
	if terrain_task == -1 or not WorkerThreadPool.is_group_task_completed(terrain_task):
		return
	WorkerThreadPool.wait_for_group_task_completion(terrain_task)
	terrain_task = -1
	var mi := MeshInstance3D.new()
	mi.mesh = track.build_terrain_mesh(terrain_rows, terrain_r)
	ground_mat = (mi.mesh as ArrayMesh).surface_get_material(0)
	if weather != null:
		weather.set_ground_mat(ground_mat)
	track_root.add_child(mi)
	terrain_rows.clear()

## Bosque con tres capas de detalle según la distancia (zonas de 200 m; cada capa se dibuja solo dentro de su rango):
##   cerca  (0–190 m)     tronco + copa, con forma
##   media  (170–520 m)   un solo cono chato por árbol (barato) — con la niebla parece bosque
##   lejos  (500–950 m)   una cuarta parte de los árboles, más grandes: una "cortina" que se nota que hay bosque
## Al acercarte, las capas se cambian solas. Antes se dibujaba todo el campo.
const CHUNK := 200.0

## Distancia del guardarraíl al centro del camino (sobre el borde de la banquina)
func rail_off() -> float:
	return float(track.half_width + track.shoulder) - 0.3

## El auto no puede pasar de acá: el guardarraíl está a un metro de su centro
func wall_dist() -> float:
	return rail_off() - 1.0

## Niveles de simulación (se eligen antes de largar): ayudas del auto del jugador
const SIM_PRESETS := {
	"arcade": {"abs": true, "tc": 80.0, "stab": 90.0, "line": 60.0},
	"mid": {"abs": true, "tc": 50.0, "stab": 30.0, "line": 25.0},
	"pro": {"abs": false, "tc": 0.0, "stab": 0.0, "line": 0.0},
	"adv": {"abs": true, "tc": 30.0, "stab": 20.0, "line": 0.0}, # aventura: simulación total con un poco de ayuda
}

func _sim_assists() -> Dictionary:
	var lv := str(cfg.get("sim", profile.setting("simLevel")))
	if SIM_PRESETS.has(lv):
		return SIM_PRESETS[lv]
	return {"abs": profile.setting("abs") == true, "tc": float(profile.setting("tc")), "stab": float(profile.setting("stab")), "line": float(profile.setting("lineAssist"))}

## Cambio de una ayuda en las opciones: el nivel pasa a «personalizado» conservando los valores del nivel anterior en las otras
func _assist_changed(key: String) -> void:
	var lv := str(cfg.get("sim", profile.setting("simLevel")))
	if SIM_PRESETS.has(lv):
		var P: Dictionary = SIM_PRESETS[lv]
		var map := {"abs": "abs", "tc": "tc", "stab": "stab", "lineAssist": "line"}
		for k in map:
			if k != key:
				profile.set_setting(k, P[map[k]] if k == "abs" else int(P[map[k]]))
		profile.set_setting("simLevel", "custom")
		cfg["sim"] = "custom"
	_apply_assists()

## Corteza: vetas verticales marrones con nudos (se repite sin costura)
func _bark_tex() -> ImageTexture:
	var N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in N:
		for x in N:
			var fx := float(x) / float(N) * TAU
			var streak := 0.5 + 0.5 * sin(fx * 11.0 + sin(float(y) / float(N) * TAU * 2.0) * 1.3) * sin(fx * 5.0 + 0.7)
			var v := 0.34 + 0.22 * streak + 0.07 * rng.randf()
			img.set_pixel(x, y, Color(v * 1.0, v * 0.76, v * 0.55))
	for k in 18: # nudos / grietas oscuras
		var bx := rng.randi() % N
		var by := rng.randi() % N
		for j in 9:
			var c := img.get_pixel((bx + j / 4) % N, (by + j) % N)
			img.set_pixel((bx + j / 4) % N, (by + j) % N, c.darkened(0.45))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Copa del pino: tres conos superpuestos, cada uno más angosto; más oscuros abajo (sombra propia falsa)
func _crown_mesh(seg: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := [[1.75, 2.0, 0.0], [1.35, 1.9, 1.35], [0.95, 1.7, 2.6]] # radio, alto, altura de la base
	for L in layers:
		var r: float = L[0]
		var h: float = L[1]
		var y0: float = L[2] - 2.3
		for i in seg + 3:
			var a0 := TAU * float(i) / float(seg + 3)
			var a1 := TAU * float(i + 1) / float(seg + 3)
			var p0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			var tip := Vector3(0, y0 + h, 0)
			var nrm := ((p1 - p0).cross(tip - p0)).normalized()
			for v in [p0, tip, p1]:
				var shade := 0.62 + 0.38 * clampf((v.y - y0) / h, 0.0, 1.0)
				st.set_color(Color(shade, shade, shade))
				st.set_normal(nrm)
				st.add_vertex(v)
	return st.commit()

func _rebuild_trees() -> void:
	if trees_node != null:
		trees_node.queue_free()
	trees_node = Node3D.new()
	world.add_child(trees_node)
	if trees_n <= 0 or adv_mode or track is DriftTrack or track is PaperTrack or track is DreamTrack:
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.26
	trunk.height = 2.6
	trunk.radial_segments = 7
	trunk.rings = 1
	trunk.cap_top = false
	var crown := _crown_mesh(4)
	# árboles nuevos (los de la aventura): pinos con polleras desparejas y árboles de hojas con varias copas
	var AdvProps := preload("res://game/adventure/adv_props.gd")
	var tree_mat := StandardMaterial3D.new()
	tree_mat.vertex_color_use_as_albedo = true
	tree_mat.roughness = 1.0
	var pine_mesh: ArrayMesh = AdvProps.pine(17).commit(tree_mat)
	var pine_b: ArrayMesh = AdvProps.pine(41).commit(tree_mat)
	var broad_mesh: ArrayMesh = AdvProps.broadleaf(5).commit(tree_mat)
	var pine_lo: ArrayMesh = AdvProps.pine(17, false, true).commit(tree_mat)
	var low := CylinderMesh.new()
	low.top_radius = 0.0
	low.bottom_radius = 1.8
	low.height = 6.4
	low.radial_segments = 4
	low.rings = 1
	low.cap_top = false
	low.cap_bottom = false
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _bark_tex()
	tm.albedo_color = Color(0.85, 0.78, 0.7)
	tm.uv1_scale = Vector3(2.0, 3.0, 1.0)
	tm.roughness = 1.0
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.11, 0.34, 0.13)
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 1.0
	trunk.material = tm
	crown.surface_set_material(0, cm)
	low.material = cm
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var cells := {}
	var route := track is RouteTrack
	var grid := {}
	var near_min := 0.0
	if route:
		near_min = track.half_width + track.shoulder + 4.0
		for si in range(0, track.n, 2):
			var sp: Vector3 = track.samples[si]
			var gk := Vector2i(floori(sp.x / 30.0), floori(sp.z / 30.0))
			if not grid.has(gk):
				grid[gk] = []
			grid[gk].append(si)
		track.hint = -1
	for i in trees_n:
		var px := 0.0
		var pz := 0.0
		var py := 0.0
		if route:
			var ok := false
			for attempt in 6:
				var si: int = rng.randi() % int(track.n)
				var sp: Vector3 = track.samples[si]
				var l: Vector3 = track.laterals[si]
				var off := rng.randf_range(near_min, near_min + 250.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				if wall_on:
					# pista solo de camino: árboles hasta el límite, con una franja densa justo ahí (el "muro de árboles")
					var wl := rail_off()
					off = (rng.randf_range(wl + 3.5, wl + 12.0) if rng.randf() < 0.55 else rng.randf_range(wl + 11.0, wl + 26.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
				px = sp.x + l.x * off
				pz = sp.z + l.z * off
				# que no caiga sobre otro tramo de la pista (curvas cerradas y cruces)
				var clear := true
				var gk2 := Vector2i(floori(px / 30.0), floori(pz / 30.0))
				for gx in range(gk2.x - 1, gk2.x + 2):
					for gz in range(gk2.y - 1, gk2.y + 2):
						var lst: Array = grid.get(Vector2i(gx, gz), [])
						for sj in lst:
							var q: Vector3 = track.samples[sj]
							if (q.x - px) * (q.x - px) + (q.z - pz) * (q.z - pz) < near_min * near_min:
								clear = false
								break
						if not clear:
							break
					if not clear:
						break
				if clear:
					track.hint = si
					py = track.ground_smooth(px, pz)
					ok = true
					break
			if not ok:
				continue
		else:
			var th := rng.randf() * TAU
			var off2 := rng.randf_range(11.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var c: Vector2 = track.center(th)
			var t: Vector2 = track.tangent(th)
			var pp := c + Vector2(-t.y, t.x) * off2
			px = pp.x
			pz = pp.y
		var key := Vector2i(floori(px / CHUNK), floori(pz / CHUNK))
		if not cells.has(key):
			cells[key] = []
		cells[key].append([px, pz, rng.randf_range(0.8, 1.7), py])
	for key in cells:
		var list: Array = cells[key]
		var center := Vector3((float(key.x) + 0.5) * CHUNK, 0.0, (float(key.y) + 0.5) * CHUNK)
		if route:
			var ysum := 0.0
			for e in list:
				ysum += float(e[3])
			center.y = ysum / float(list.size())
		# cerca: pinos de dos formas y algunos árboles de hojas (con tronco incluido)
		var la: Array = []
		var lb: Array = []
		var lc: Array = []
		for k in list.size():
			var e: Array = list[k]
			var hsh := fposmod(float(e[0]) * 0.731 + float(e[1]) * 0.377, 1.0)
			if hsh < 0.18:
				lc.append(e)
			elif hsh < 0.6:
				la.append(e)
			else:
				lb.append(e)
		for pair in [[pine_mesh, la], [pine_b, lb], [broad_mesh, lc]]:
			var L: Array = pair[1]
			if not L.is_empty():
				_add_tree_layer(_multimesh(pair[0], L, center, -0.15, 0.85, 1), center, 0.0, 200.0)
		# media: el mismo pino simplificado
		_add_tree_layer(_multimesh(pine_lo, list, center, -0.15, 0.85, 1), center, 180.0, 520.0)
		# lejos: uno de cada cuatro, más grande
		if list.size() >= 4:
			_add_tree_layer(_multimesh(low, list, center, 3.2, 1.7, 4), center, 500.0, 950.0)

## MultiMesh con los árboles de una zona (posiciones relativas al centro de la zona); cada "step"-ésimo árbol
func _multimesh(mesh: Mesh, list: Array, center: Vector3, y_off: float, size_k: float, step: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var n := int(ceil(float(list.size()) / float(step)))
	mm.instance_count = n
	for j in n:
		var e: Array = list[j * step]
		var sc: float = float(e[2]) * size_k
		var yaw := fposmod(float(e[0]) * 1.37 + float(e[1]) * 0.71, TAU) # cada árbol girado distinto
		mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), Vector3(float(e[0]) - center.x, y_off * sc + float(e[3]) - center.y, float(e[1]) - center.z)))
		var tv := 0.82 + 0.36 * fposmod(float(e[0]) * 0.137 + float(e[1]) * 0.291, 1.0) # cada árbol con su tono de verde
		mm.set_instance_color(j, Color(tv, tv * (0.95 + 0.1 * fposmod(float(e[1]) * 0.53, 1.0)), tv * 0.95))
	return mm

func _add_tree_layer(mm: MultiMesh, center: Vector3, r_begin: float, r_end: float) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.position = center # la distancia de visibilidad se mide hasta el origen del nodo: va en el centro de la zona
	inst.visibility_range_begin = r_begin
	inst.visibility_range_end = r_end
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # las sombras son solo de los autos
	trees_node.add_child(inst)

## Datos de cada auto de la parrilla: params (Dictionary de VehicleParams), paint, rim, name, visual_type, ai (opciones)
func _car_setups() -> Array:
	if adv_mode:
		return Adventure.car_setups(self)
	var out: Array = []
	if not menu_mode:
		var d: Dictionary = vehicles["t1plus"].duplicate()
		if nitro_test:
			d["nitroCap"] = 8.0
			d["nitroBoost"] = 0.35
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var paints := [Color(0.10, 0.31, 0.88), Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.1), Color(0.15, 0.7, 0.35), Color(0.9, 0.9, 0.92), Color(0.6, 0.2, 0.8), Color(0.95, 0.45, 0.1), Color(0.1, 0.75, 0.8)]
		for i in cars_n:
			out.append({"params": d, "paint": paints[i % paints.size()], "rim": Color(1.0, 0.42, 0.03), "name": "Rival %d" % i, "visual_type": "t1plus", "ai": {"skill": 0.92 + 0.02 * float(i % 4), "lane": (float(i % 3) - 1.0) * 1.6, "aggr": 0.3 + 0.1 * float(i % 5)}})
		return out
	var sa := _sim_assists()
	var assists := {"abs": sa["abs"], "tc": sa["tc"], "stab": sa["stab"]}
	var pid := str(cfg["car"])
	var pst: Dictionary = cfg["state"]
	if not lab_state.is_empty():
		pst = lab_state # taller de prueba de la pausa: el mismo auto con todos los ajustes liberados
	var pp: Dictionary = pst.get("paint", {"body": "#1a4fe0", "rim": "#ff6a08"})
	out.append({"params": CarBuild.build_params(vehicles[pid], pst, assists), "paint": Color(str(pp["body"])), "rim": Color(str(pp.get("rim", "#2a2d33"))), "name": str(profile.d["name"]), "finish": str(pp.get("finish", "gloss")), "visual_type": str(vehicles[pid].get("visualType", pid)), "ai": {},
		"livery": int(pp.get("livery", 0)), "accent": Color(str(pp.get("accent", "#ff6a08"))), "tire": Color(str(pp.get("tire", "#141516"))), "parts": pp})
	var n_ai := int(cfg.get("ai", 0))
	if n_ai > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cfg.get("seed", 7)) * 7919 + 13
		var picks := AiCars.pick(vehicles, n_ai, int(cfg.get("maxPI", 999)), str(cfg.get("aiCar", "")), track.mode, rng)
		for i in picks.size():
			var pk: Dictionary = picks[i]
			var st: Dictionary = pk["state"]
			out.append({"params": CarBuild.build_params(vehicles[pk["id"]], st, AiCars.ASSISTS), "paint": Color(str(st["paint"]["body"])), "rim": Color(str(st["paint"]["rim"])),
				"name": AiCars.NAMES[(i + int(cfg.get("seed", 7))) % AiCars.NAMES.size()], "visual_type": str(vehicles[pk["id"]].get("visualType", pk["id"])),
				"ai": {"skill": minf(1.08, float(cfg.get("skill", 0.9)) * (0.96 + rng.randf() * 0.06)), "lane": (float(i % 3) - 1.0) * 1.6, "aggr": rng.randf()}})
	return out

func _rebuild_cars() -> void:
	_finish_physics()
	if fx != null:
		fx.reset()
	for c in cars:
		c.visual.queue_free()
	cars.clear()
	cockpit = null
	var setups := _car_setups()
	cars_n = setups.size()
	rival_info.clear()
	var s0 := 0
	if menu_mode and cfg.get("seg") is Array:
		s0 = int(floor(float(cfg["seg"][0]) * float(track.n)))
	if view_at >= 0.0 and track is RouteTrack:
		s0 = int(floor(view_at * float(track.n)))
	for i in cars_n:
		var su: Dictionary = setups[i]
		var d: Dictionary = su["params"]
		var paint: Color = su["paint"]
		var lo := (i > 0) or not hi_model
		var route := track is RouteTrack
		var car_view = (player_view() if (adv_mode and i == 0) else track.make_view()) if route else track
		var car := Car.new(car_view, VehicleParams.from_dict(d), i == 0, lo, paint, su["rim"], str(su.get("finish", "gloss")), (cfg.get("state", {}) as Dictionary).get("mods", {}) if i == 0 and cfg.get("state") is Dictionary else {})
		rival_info.append({"name": su["name"], "color": paint})
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--livery=") and i == 0:
				su["livery"] = int(a.substr(9)) # prueba: rotulado del auto del jugador
				su["accent"] = Color(1.0, 0.5, 0.1)
		if int(su.get("livery", 0)) > 0:
			car.visual.set_livery(int(su["livery"]), paint, su.get("accent", Color(1.0, 0.5, 0.1)), str(su.get("finish", "gloss")))
		if su.has("tire"):
			car.visual.set_tire_color(su["tire"])
		if su.has("parts"):
			car.visual.set_parts(su["parts"])
		if i > 0:
			if route:
				car.driver = AIDriver.new(track.make_view(), car.phys, su["ai"])
			elif track is DriftTrack:
				car.driver = DriftBot.new(22.0 + float((i * 5) % 18), float(i) * 1.7)
			else:
				car.driver = RingDriver.new(track, 20.0 + float((i * 7) % 9), (float((i * 5) % 7) - 3.0) * 0.9)
		# parrilla: en las carreras el jugador sale último; en contrarreloj, adelante
		var slot := i
		if menu_mode and cars_n > 1 and str(cfg.get("type")) == "race":
			slot = cars_n - 1 if i == 0 else i - 1
		var sp: Array = track.start_pose(slot, s0) if route else track.start_pose(slot)
		if track is CityTrack and cfg.has("resume") and i == 0:
			sp = [float(cfg["resume"][0]), float(cfg["resume"][1]), float(cfg["resume"][2])]
		if adv_mode:
			sp = Adventure.start_pose(track, i, cfg)
		car.place(sp[0], sp[1], sp[2])
		if OS.has_environment("DR_POS") and i == 0: # prueba: DR_POS=x,z,yaw (grados)
			var dp := OS.get_environment("DR_POS").split_floats(",")
			car.place(dp[0], dp[1], deg_to_rad(dp[2]))
		car.restart_history(sim_t)
		world.add_child(car.visual)
		if no_body:
			car.visual.body.get_child(0).visible = false
		# los vidrios son oscuros: la tripulación y el habitáculo solo se dibujan con las cámaras interiores del jugador
		if i == 0:
			var Vp: VehicleParams = car.phys.V
			cockpit = Cockpit.new(str(su["visual_type"]), paint, su["rim"])
			cockpit.position = Vector3(0, -Vp.comHeight + Vp.rideOffset, 0)
			car.visual.add_child(cockpit)
			cockpit.set_engine(Vp.maxRpm, Vp.shiftUpRpm, Vp.nitroCap)
			cockpit.raining = weather_name == "lluvia"
			cockpit.set_inside(false, false)
			cam_rig = CameraRig.new(cam, player_view() if adv_mode else track)
			cam_rig.visual = car.visual
			cam_rig.cockpit = cockpit
			cam_rig.ground_off = -Vp.comHeight + Vp.rideOffset
			cam_rig.mount = car.visual.compute_mounts(float(cockpit.C["cowlZ"]), float(cockpit.C["eyeY"]))
			if menu_mode and profile != null and profile.setting("camAdj") is Dictionary:
				cam_rig.adj = (profile.setting("camAdj") as Dictionary).duplicate(true)
			cam_rig.set_preset(cam_index)
			if race_hud != null:
				race_hud.rig = null if adv_mode else cam_rig
			was_inside = false
			_load_cabin_cfg()
		if track is DriftTrack:
			car.solid = true
		if wall_on and route:
			car.wall = wall_dist()
			if i == 0:
				assist_view = track.make_view()
		cars.append(car)
		if auto_player and i == 0 and route:
			car.driver = AIDriver.new(track.make_view(), car.phys, {"skill": 0.95})
		if i <= 3 and fx != null:
			fx.prepare(i)
	var all_phys: Array = []
	for c in cars:
		all_phys.append(c.phys)
	for c in cars:
		if c.driver is AIDriver:
			c.driver.others = all_phys
	if not cars.is_empty():
		cars[0].phys.manual = manual_gearbox
		controls.manual = manual_gearbox
		controls.has_nitro = cars[0].phys.V.nitroCap > 0.0
	cam_ready = false
	fx_hold = 1.5
	_start_session()

## Cuenta regresiva + vueltas + meta (solo con el menú; la escena de pruebas anda libre)
func _start_session() -> void:
	session = null
	if pb_active:
		return # la prueba de rendimiento maneja sola, sin cuenta regresiva ni puestos
	if adv_mode:
		if adv != null:
			adv.queue_free()
		adv = Adventure.new()
		add_child(adv)
		adv.setup(self)
		return
	if menu_mode and track is CityTrack:
		session = CitySession.new(track, cfg, cars.size())
		session.names[0] = rival_info[0]["name"]
		if race_hud != null:
			race_hud.setup(session, cfg, rival_info)
			if cfg.has("gpsdrive") and race_hud.city_hud != null: # prueba: el auto va solo por el GPS hasta ese lugar
				_city_drive_test(str(cfg["gpsdrive"]))
			shops = CityShops.new()
			shops.setup(self, track.world_node, track.city)
			links = CityLinks.new()
			links.setup(self, track.world_node, track.city)
			fuel = CityFuel.new()
			fuel.setup(self, track.city)
			tires = CityTires.new() # desgaste de gomas (Etapa 13)
			tires.setup(self)
			acts = CityActivities.new() # radares, contrarreloj y encargos (Etapa 15)
			acts.setup(self, track.city, track.world_node)
			tolls = CityToll.new()
			tolls.setup(self, track.world_node, track.city)
			city_drift = CityDrift.new()
			city_drift.setup(self, track.world_node, track.city)
			if cfg.get("online", false) == true and online != null and profile != null:
				social = OnlineSocial.new()
				add_child(social)
				social.setup(online, profile)
				if social.active:
					race_hud.setup_online(social, profile)
					var rc := RemoteCars.new() # los autos de los otros jugadores
					rc.setup(self, social, track.city)
					add_child(rc)
			world_life = WorldLife.new() # un solo núcleo para offline y online (online: el servidor da id, versión, semilla y hora al entrar)
			world_life.setup(profile, CityLayout.CELL)
			var pk = ParkedCars.new() # autos estacionados deterministas (Etapa 8)
			pk.attach(track.city, track, track.world_node)
			world_life.register_system(pk)
			var ct = CivilTraffic.new() # tránsito civil cinemático (Etapa 9)
			ct.attach(track.city, track, track.world_node)
			world_life.register_system(ct)
			world_life.set_enabled(profile.setting("worldLife") != false)
			if social != null and social.active:
				world_life.join_online(online)
			if cfg.has("bigmap") and race_hud.city_hud != null:
				race_hud.city_hud.set_dest(race_hud.city_hud.city.pois[0]["front"], str(race_hud.city_hud.city.pois[0]["name"]))
				race_hud.city_hud.call_deferred("_set_big", true)
		return
	if menu_mode and track is DriftTrack:
		session = DriftSession.new(track, cfg, cars.size())
		session.names[0] = rival_info[0]["name"]
		(track as DriftTrack).cones.reset()
		if OS.get_cmdline_user_args().has("--finishtest"):
			session.limit = 6.0 # prueba: termina a los 6 s
		session.beep.connect(_on_beep)
		session.go.connect(_on_go)
		session.player_finished.connect(_on_player_finished)
		if race_hud != null:
			race_hud.setup(session, cfg, rival_info)
		return
	if not menu_mode or not (track is RouteTrack):
		return
	var t := str(cfg.get("type", "race"))
	session = Session.new(track, cfg, cars.size())
	for i in cars.size():
		session.names[i] = rival_info[i]["name"]
	session.init_cars(cars)
	if OS.get_cmdline_user_args().has("--finishtest"):
		session.race_len = 120.0 # prueba: meta a los 120 m
	session.beep.connect(_on_beep)
	session.go.connect(_on_go)
	session.player_finished.connect(_on_player_finished)
	for c in cars:
		if c.driver is AIDriver:
			c.driver.enabled = false
	if race_hud != null:
		race_hud.setup(session, cfg, rival_info)

func _on_beep(k: int) -> void:
	race_hud.big(str(k))
	sfx.play("beep")

func _on_go() -> void:
	race_hud.big("¡YA!")
	sfx.play("go")
	for c in cars:
		if c.driver is AIDriver:
			c.driver.enabled = true

func _on_player_finished(_v: float) -> void:
	done_t = 0.0
	race_hud.big("META" if str(cfg.get("type")) != "race" else "%d°" % session.position_of(0, cars.size()))

## Prueba automática: recorre varias cargas (cada una 6 s, descartando el primer segundo y medio) y muestra la tabla.
## [autos, árboles, pilotos, sombras, hilos, resolución]
## El 7º dato son cosas que se APAGAN para medir cuánto cuestan: e = efectos, c = cielo, n = niebla, h = controles/HUD, m = mundo 3D,
## f = filtro de cámara, a = sonido.
const BENCH_CFGS := [
	[1, 0, 0, 0, 1, 1.0, ""], [1, 0, 0, 0, 1, 0.5, ""], [1, 3000, 1, 0, 1, 0.5, ""], [4, 3000, 1, 0, 1, 0.5, ""],
	[8, 3000, 1, 0, 1, 0.5, ""], [8, 8000, 1, 0, 1, 0.5, ""], [8, 3000, 0, 0, 1, 0.5, ""], [8, 3000, 1, 0, 0, 0.5, ""], [4, 3000, 1, 1, 1, 0.5, ""],
	[1, 3000, 0, 0, 1, 0.5, ""], [1, 3000, 0, 0, 1, 0.5, "e"], [1, 3000, 0, 0, 1, 0.5, "c"], [1, 3000, 0, 0, 1, 0.5, "n"],
	[1, 3000, 0, 0, 1, 0.5, "f"], [1, 3000, 0, 0, 1, 0.5, "h"], [1, 3000, 0, 0, 1, 0.5, "m"], [1, 3000, 0, 0, 1, 0.5, "a"], [1, 3000, 0, 0, 1, 0.5, "ecnfa"]]

func _bench_start() -> void:
	DisplayServer.screen_set_keep_on(true) # que no se apague la pantalla durante la prueba
	bench_i = -1
	bench_results.clear()
	report_body.clear()
	_bench_next()

func _bench_next() -> void:
	bench_i += 1
	if bench_i >= BENCH_CFGS.size():
		bench_i = -1
		var lines := ["RESULTADOS (mandame una captura de esto)", "autos · árboles · pilotos · sombras · hilos · resolución  →  FPS · ms/cuadro · física ms · llamadas · triángulos"]
		for r in bench_results:
			lines.append(r)
		lines.append("LISTO. El informe ya quedó copiado (pegalo en el chat). INFORME lo vuelve a copiar.")
		hud.result_text = "\n".join(lines)
		hud.stats_text = ""
		hud.banner = ""
		_copy_report() # queda copiado solo: ya se puede pegar en el chat
		if autobench:
			await get_tree().create_timer(0.5).timeout
			if shot_path != "":
				get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
		return
	var c: Array = BENCH_CFGS[bench_i]
	var new_trees: int = c[1]
	cars_n = c[0]
	pilots_on = c[2] == 1
	sun.shadow_enabled = c[3] == 1
	threaded = c[4] == 1
	res_scale = c[5]
	res_auto = false
	_apply_diag(str(c[6]))
	_on_resize()
	if new_trees != trees_n or trees_node == null:
		trees_n = new_trees
		_rebuild_trees()
	_rebuild_cars()
	# el jugador también maneja solo, así la escena está siempre en movimiento
	if not cars.is_empty():
		cars[0].driver = AIDriver.new(track.make_view(), cars[0].phys, {"skill": 0.95}) if track is RouteTrack else RingDriver.new(track, 26.0, 0.0)
	bench_t = 0.0

## Apaga a propósito partes del juego para medir cuánto cuesta cada una (ver BENCH_CFGS)
func _apply_diag(flags: String) -> void:
	fx_on = not flags.contains("e")
	if not fx_on:
		fx.reset()
	weather.set_sky_enabled(not flags.contains("c"))
	env.fog_enabled = not flags.contains("n")
	controls.visible = not flags.contains("h")
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED if flags.contains("m") else SubViewport.UPDATE_ALWAYS
	lens.enabled = not flags.contains("f")
	audio_on = not flags.contains("a")
	audio.set_active(audio_on)

func _bench_tick(dt: float) -> void:
	bench_t += dt
	var left := int(ceil(float(BENCH_CFGS.size() - bench_i) * 7.5 - bench_t))
	hud.banner = "PRUEBA %d/%d · faltan %d s · NO TOQUES LA PANTALLA" % [bench_i + 1, BENCH_CFGS.size(), maxi(left, 0)]
	if bench_t > 1.5 and bench_t < 6.0:
		if bench_i >= 0:
			_bench_samples.append([dt, shown_phys_ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), script_ms])
	if bench_t >= 6.0:
		var dts: Array = []
		for smp in _bench_samples:
			dts.append(smp[0])
		dts.sort()
		var n := _bench_samples.size()
		var sdt := 0.0
		var sph := 0.0
		var sdc := 0.0
		var stri := 0.0
		var sscr := 0.0
		for s in _bench_samples:
			sdt += s[0]
			sph += s[1]
			sdc += s[2]
			stri += s[3]
			sscr += s[4]
		var c: Array = BENCH_CFGS[bench_i]
		if n > 0:
			bench_results.append("%2d autos · %5d árb · pil %s · som %s · hilos %s · res %3d%%%s  →  %3d FPS · %5.1f ms · fis %4.1f · código %4.1f ms · %4d llam · %dk tri" % [
				c[0], c[1], "sí" if c[2] == 1 else "no", "sí" if c[3] == 1 else "no", "sí" if c[4] == 1 else "no", int(c[5] * 100.0),
				(" · SIN " + str(c[6])) if str(c[6]) != "" else "",
				int(round(float(n) / sdt)), sdt / n * 1000.0, sph / n, sscr / n, int(sdc / n), int(stri / n / 1000.0)])
			var slow := 0
			var slow20 := 0
			for d in dts:
				if d > 0.0334:
					slow += 1
				if d > 0.0205:
					slow20 += 1
			report_body.append("  #%d: cuadros %d · p50 %.1f ms · p95 %.1f ms · p99 %.1f ms · peor %.1f ms · cuadros >20 ms (bajan de 50 FPS) %.1f%% · cuadros >33 ms (tirones) %d (%.1f%%) · memoria de video %d MB · texturas %d MB" % [
				bench_i + 1, n, float(dts[n / 2]) * 1000.0, float(dts[int(n * 0.95)]) * 1000.0, float(dts[mini(n - 1, int(n * 0.99))]) * 1000.0, float(dts[n - 1]) * 1000.0, 100.0 * slow20 / n, slow, 100.0 * slow / n,
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0)])
		_bench_samples.clear()
		_bench_next()

# ───────────────────────── prueba de rendimiento completa ─────────────────────────
## Corre la lista de PerfBench.plan(): cada paso arma una configuración (pista, autos, resolución, cámara, filtros…), espera 1,5 s,
## mide ~4 s y pasa al siguiente. Al final arma el informe de texto y lo muestra con un botón para copiarlo.
func _pb_start() -> void:
	pb_user_fx = (lens.fx as Array).duplicate()
	pb_user_level = lens.level
	pb_plan = PerfBench.plan(str(cfg.get("bench_mode", "full")))
	pb_results.clear()
	pb_i = -1
	res_auto = false
	_pb_trees_now = trees_n
	RenderingServer.viewport_set_measure_render_time(world.get_viewport_rid(), true)
	DisplayServer.screen_set_keep_on(true) # que no se apague la pantalla durante la prueba
	hud.visible = true # solo dibuja el cartel de avance
	hud.set_process_input(false)
	race_hud.visible = false
	_pb_next()

func _pb_next() -> void:
	pb_i += 1
	if pb_i >= pb_plan.size():
		_pb_finish()
		return
	var s: Dictionary = pb_plan[pb_i]
	var trk := str(s["track"])
	cfg["ai"] = int(s["cars"]) - 1
	trees_n = int(s["trees"])
	if track_id != trk:
		cfg["track"] = trk
		_change_track(trk) # arma pista, árboles y autos
	else:
		if trees_n != _pb_trees_now:
			_rebuild_trees()
		_rebuild_cars() # autos de nuevo en la línea de largada: cada paso repite el mismo recorrido y los números se pueden comparar
	_pb_trees_now = trees_n
	if track is DriftTrack:
		(track as DriftTrack).cones.reset()
	if not cars.is_empty():
		cars[0].driver = AIDriver.new(track.make_view(), cars[0].phys, {"skill": 0.95}) if track is RouteTrack else DriftBot.new(26.0, 0.0)
	pilots_on = bool(s["pilots"])
	sun.shadow_enabled = bool(s["shadows"])
	threaded = bool(s["threads"])
	res_scale = float(s["res"])
	_on_resize()
	_apply_diag(str(s["flags"]))
	# filtros de cámara: apagados salvo que el paso los pida
	if bool(s["user_lens"]):
		lens.apply_settings(profile)
		lens.level = pb_user_level
		lens.fx = pb_user_fx
	else:
		lens.fx_on = [true, true, true]
		lens.fx_amt = [1.0, 1.0, 1.0]
		lens.level = int(s["lens_level"])
		lens.fx = s["fx"]
	lens.enabled = bool(s["lens_on"]) and not str(s["flags"]).contains("f")
	if cam_rig != null:
		cam_rig.set_preset(int(s["cam"]))
	pb_t = 0.0
	pb_samples.clear()

var _pb_trees_now := -1

func _pb_tick(dt: float) -> void:
	pb_t += dt
	var s: Dictionary = pb_plan[pb_i]
	var left := int(ceil(float(pb_plan.size() - pb_i) * PerfBench.step_s() - pb_t))
	hud.banner = "PRUEBA %d/%d · %s · faltan %d:%02d · NO TOQUES LA PANTALLA" % [pb_i + 1, pb_plan.size(), str(s["name"]), maxi(left, 0) / 60, maxi(left, 0) % 60]
	if pb_t > PerfBench.warm_s() and dt < 1.0:
		pb_samples.append([dt, shown_phys_ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), script_ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_measured_render_time_cpu(world.get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(world.get_viewport_rid())])
	if pb_t >= PerfBench.step_s():
		pb_results.append({"track": str(s["track"]), "grp": str(s["grp"]), "name": str(s["name"]), "ref": bool(s["ref"]), "stats": PerfBench.summarize(pb_samples),
			"vmem": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0), "tmem": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0)})
		_pb_next()

func _pb_finish() -> void:
	var extra: Array = []
	extra.append("")
	var pid := str(cfg.get("car", ""))
	extra.append("Auto de la prueba: %s · calidad general: %s · resolución del mundo 3D en los pasos: fija (la automática se apaga)" % [pid, str(profile.setting("quality"))])
	extra.append("Tu lente: nivel %d · tus efectos: %s · humo/polvo (ajuste del jugador): %s" % [pb_user_level, str(pb_user_fx), str(profile.setting("particles"))])
	extra.append("Prueba %s: %d pasos de %.1f s (se descarta el primer %.1f s de cada uno). Pistas: Circuito del Lago (asfalto), Drift Plaza%s." % [
		"COMPLETA" if str(cfg.get("bench_mode", "full")) == "full" else "RÁPIDA", pb_plan.size(), PerfBench.step_s(), PerfBench.warm_s(), " y Bosque (tierra)" if str(cfg.get("bench_mode", "full")) == "full" else ""])
	extra.append("Todos los autos manejan solos; la plaza de drift usa conos con física y derrapes.")
	pb_report = PerfBench.report(_report_header(), pb_results, extra)
	DisplayServer.clipboard_set(pb_report)
	var f := FileAccess.open("user://informe_rendimiento.txt", FileAccess.WRITE)
	if f:
		f.store_string(pb_report)
		f.close()
	print(pb_report)
	pb_i = -1
	hud.banner = ""
	hud.visible = false
	lens.enabled = true
	lens.apply_settings(profile)
	controls.visible = false
	pb_ui = PerfResults.new()
	pb_ui.report = pb_report
	pb_ui.exit_pressed.connect(_quit)
	pb_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(pb_ui)
	add_child(layer)
	if autobench or shot_path != "":
		await get_tree().create_timer(0.8).timeout
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

## Informe completo: datos del teléfono + versión del juego + tabla de la prueba. Se copia al portapapeles y se guarda en un archivo.
## Datos del teléfono y del juego (encabezado de todos los informes)
func _report_header() -> Array:
	var v := "completo (todo adentro)"
	if FileAccess.file_exists("user://content_version.txt"):
		v = FileAccess.get_file_as_string("user://content_version.txt").strip_edges()
	var mem := OS.get_memory_info()
	var out: Array = []
	out.append("=== INFORME DREAM RACING (Godot) ===")
	out.append("Fecha: " + Time.get_datetime_string_from_system())
	out.append("Juego: versión %s" % v)
	out.append("Motor: Godot %s · renderizador %s" % [Engine.get_version_info()["string"], str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))])
	var ver := OS.get_version()
	if ver == "" and OS.has_method("get_version_alias"):
		ver = str(OS.call("get_version_alias"))
	out.append("Teléfono: %s · %s %s" % [OS.get_model_name(), OS.get_name(), ver])
	var cpu := OS.get_processor_name()
	if cpu.strip_edges() == "":
		cpu = _proc_value("/proc/cpuinfo", ["Hardware", "model name", "Processor"])
	var freqs: Array = []
	for i in OS.get_processor_count():
		var f := "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq" % i
		if FileAccess.file_exists(f):
			freqs.append(str(int(FileAccess.get_file_as_string(f).strip_edges().to_int() / 1000)))
	out.append("Procesador: %s · %d núcleos%s" % [cpu if cpu != "" else "(no informa)", OS.get_processor_count(), (" · MHz máx.: " + ", ".join(freqs)) if freqs.size() > 0 else ""])
	var mem_total := int(float(mem.get("physical", 0)) / 1048576.0)
	var mem_free := int(float(mem.get("available", mem.get("free", 0))) / 1048576.0)
	if mem_total <= 0:
		mem_total = int(_proc_value("/proc/meminfo", ["MemTotal"]).to_int() / 1024)
		mem_free = int(_proc_value("/proc/meminfo", ["MemAvailable"]).to_int() / 1024)
	out.append("Memoria: %s" % (("%d MB en total · %d MB libres" % [mem_total, mem_free]) if mem_total > 0 else "(este teléfono no la informa)"))
	out.append("GPU: %s · %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	var hz := DisplayServer.screen_get_refresh_rate()
	out.append("Dibujado del mundo 3D a %d%% de la pantalla" % int(res_scale * 100.0))
	out.append("Pantalla: %dx%d · %s Hz" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y, ("%.0f" % hz) if is_finite(hz) and hz > 0.0 else "?"])
	return out

func _build_report() -> String:
	var out: Array = _report_header()
	out.append("")
	if bench_results.is_empty():
		out.append("(No se corrió la prueba automática. Estado actual:)")
		out.append(hud.stats_text.replace("\n", " | "))
	else:
		out.append("PRUEBA AUTOMÁTICA (cada configuración 6 s, sin contar el primer segundo y medio)")
		out.append("autos · árboles · pilotos · sombras · hilos · resolución  →  FPS · ms/cuadro · física ms · código ms · llamadas · triángulos")
		for r in bench_results:
			out.append(r)
		out.append("")
		out.append("(SIN e=efectos c=cielo n=niebla f=filtro de cámara h=controles m=mundo 3D: se apaga a propósito para medir cuánto cuesta; código = tiempo del script por cuadro)")
		out.append("(fís = milisegundos por cuadro que el hilo principal pierde esperando a la física; con hilos debería ser ~0)")
		out.append("DETALLE (p50/p95/p99 = tiempo de cuadro del 50%, 95% y 99% de los cuadros; cuadros lentos = tirones)")
		for r in report_body:
			out.append(r)
	return "\n".join(out)

## Lee un valor de /proc (Android lo deja leer): busca la primera línea "clave: valor"
func _proc_value(path: String, keys: Array) -> String:
	if not FileAccess.file_exists(path):
		return ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		for k in keys:
			if line.begins_with(k):
				var parts := line.split(":", true, 1)
				if parts.size() == 2:
					return parts[1].strip_edges()
	return ""

func _copy_report() -> void:
	var txt := _build_report()
	DisplayServer.clipboard_set(txt)
	var f := FileAccess.open("user://informe_gskorp.txt", FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	hud.show_toast("Informe copiado ✔  Pegalo en el chat")
	print(txt)

## Humo/polvo/marcas: el propio siempre; los rivales solo si están cerca y a la vista (y a menor ritmo). Los rivales muy
## lejanos ni se dibujan.
func _update_fx(dt: float) -> void:
	if not fx_on:
		return
	var cp := cam.position
	fx.tick(cp)
	if fx_hold > 0.0:
		fx_hold -= dt # el auto recién puesto en la largada se asienta: sin humo ni polvo
		return
	for i in cars.size():
		var c: Car = cars[i]
		var pos := Vector3(c.snap.px, c.snap.py, c.snap.pz)
		var d := pos.distance_to(cp)
		if i > 0:
			c.visual.visible = d < 380.0
		if i == 0:
			fx.emit_from(0, c.snap, dt, 0.325)
		elif i <= 3 and d < 60.0 and cam.is_position_in_frustum(pos):
			fx.emit_from(i, c.snap, dt, 0.325, 0.5)

## Cambia de pista: se rehace el suelo, el bosque y los autos
func _change_track(id: String) -> void:
	track_id = id
	_finish_physics()
	_make_track()
	_build_track_nodes()
	fx.track = track
	weather.track = track
	weather.road_mat = road_mat
	weather.ground_mat = ground_mat
	weather.set_ground_mat(ground_mat)
	weather.apply(weather.current, true)
	_rebuild_trees()
	_rebuild_cars()

## Rivales a la par (Vórtice de Ensueño): cada rival ajusta su ritmo según la distancia que lo separa del jugador. Si se escapa, afloja; si se queda,
## aprieta (hasta un 12 % más rápido que su ritmo cómodo). Apunta a ir apenas adelante, con una ondita lenta para que la pelea se sienta viva.
func _pace_rivals(dt: float) -> void:
	for i in range(1, cars.size()):
		var d = cars[i].driver
		if d is AIDriver:
			var gap: float = session.prog[i] - session.prog[0] # > 0: el rival va adelante
			var want := 8.0 + 10.0 * sin(session.time * 0.15 + float(i))
			var target: float = AIDriver.pace_target(gap, want)
			d.pace = lerpf(d.pace, target, clampf(dt * 1.5, 0.0, 1.0))
			cars[i].phys.powerMul = lerpf(cars[i].phys.powerMul, AIDriver.power_target(gap, want), clampf(dt * 1.0, 0.0, 1.0))

## Sesión: cuenta regresiva, vueltas, posiciones y fin. Después de la meta el auto frena solo y a los 2,5 s sale el resultado.
## Prueba de manejo de Dream City: el auto sigue el GPS hasta un lugar y se informa si llegó o se trabó
func _city_drive_test(poi_id: String) -> void:
	var ch = race_hud.city_hud
	if poi_id.begins_with("link:"):
		# prueba de las bocas: el auto va hasta la primera; ya adentro sigue por el túnel hasta la segunda (formato link:boca_este>punta_oeste)
		var ids := poi_id.substr(5).split(">")
		_link_test = ids
		ch.arrive_r = 2.0
		for l in ch.city.links:
			if str(l["id"]) == str(ids[0]):
				ch.set_dest(l["pos"], str(l["id"]))
		var d0 := CityDriver.new()
		d0.hud = ch
		for l in ch.city.links:
			if str(l["id"]) == str(ids[0]):
				d0.goal = l["pos"] # al terminar el camino, derecho hasta la boca
		cars[0].driver = d0
		_cd_t = 0.0
		return
	if poi_id.begins_with("shop:"):
		poi_id = poi_id.substr(5)
		ch.arrive_r = 2.0 # prueba de entrar a un local: el auto llega hasta el círculo verde y se detiene encima
	for p in ch.city.pois:
		if str(p["id"]) == poi_id:
			ch.set_dest(p["front"], str(p["name"]))
	for ex in ch.city.exits:
		if "salida_%d" % int(ex["num"]) == poi_id:
			ch.set_dest(ex["pos"], str(ex["name"]))
	var d := CityDriver.new()
	d.hud = ch
	cars[0].driver = d
	_cd_t = 0.0

var _cd_t := 0.0
var _link_test: PackedStringArray = PackedStringArray()
var _link_stage := 0
var shops # CityShops (solo en Dream City)
var links # CityLinks: bocas de túnel y estacionamiento
var fuel # CityFuel: nafta y gasolineras
var tires # CityTires: desgaste de las gomas puestas
var acts # CityActivities: radares, contrarreloj panorámica y encargos
var tolls # CityToll: peajes de las rutas
var city_drift # CityDrift: la Plaza de Drift al final de la Ruta 60
var world_life # WorldLife: la capa de vida del mundo (reloj, semilla, sectores, sistemas de vida); sólo en Dream City
var clock # CityClock: ciclo de día y noche
var _ug := 0.0 # 0 = afuera · 1 = bajo tierra (el sol y el cielo se apagan)
var _ug_base: Array = [] # luz del sol, luz ambiente, niebla (color, inicio, fin) de afuera
var shopshot := ""
var _shopshot_f := 0

var _fps_l: Label

## Contador de FPS en una esquina (opción «Mostrar FPS» de Gráficos; viene apagado)
func _update_fps_label(fps: float) -> void:
	var on: bool = profile != null and profile.setting("showFps") == true
	if not on:
		if _fps_l != null:
			_fps_l.visible = false
		return
	if _fps_l == null:
		var cl := CanvasLayer.new()
		cl.layer = 60
		add_child(cl)
		_fps_l = Label.new()
		_fps_l.add_theme_font_size_override("font_size", 20)
		_fps_l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_fps_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_fps_l.add_theme_constant_override("outline_size", 6)
		_fps_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(_fps_l)
	_fps_l.visible = true
	_fps_l.position = Vector2(get_viewport().get_visible_rect().size.x - 190.0, 118.0)
	_fps_l.text = "%d FPS" % int(fps) + ((" · VIDA " + ("ON" if world_life.is_enabled() else "OFF")) if world_life != null else "")

var _gate_go := false
var _gate_t := 0.0 # fundido a negro al cruzar un portón abierto (en vez de cambiar de pantalla de golpe)
var _gate_to := ""

## Las salidas abiertas de las rutas: al llegar al final de la ruta se pasa a otro mapa (Aventura o Drift)
func _check_gates() -> void:
	if _gate_go and _gate_to != "":
		_gate_t -= get_process_delta_time()
		if race_hud.city_hud != null:
			race_hud.city_hud.set_fade(clampf(1.0 - _gate_t / 0.6, 0.0, 1.0))
		if _gate_t <= 0.0:
			var to := _gate_to
			_gate_to = ""
			if fuel != null:
				fuel.save()
			cfg.erase("gpsdrive")
			exit_requested.emit("gate:" + to)
		return
	if _gate_go or cars.is_empty() or not (track is CityTrack):
		return
	var ph = cars[0].phys
	var pos := Vector2(ph.px, ph.pz)
	for ex in (track as CityTrack).city.exits:
		var to := str(ex.get("to", ""))
		if to != "" and to != "plaza" and pos.distance_to(ex["pos"]) < 12.0:
			_gate_go = true
			_gate_t = 0.6
			_gate_to = to
			return

## Se entra a un local (taller o concesionario): se sale al menú de ese local y después se vuelve a la calle (ver app.gd)
func enter_shop(id: String, resume: Array) -> void:
	cfg["resume"] = resume
	if fuel != null:
		fuel.save()
	cfg.erase("gpsdrive") # (la prueba automática no sigue al volver)
	exit_requested.emit("shop:" + id)

## Luz de afuera ↔ luz de túnel: abajo el sol casi se apaga y la niebla es oscura y corta
func _underground_light(dt: float) -> void:
	if cars.is_empty() or env == null:
		return
	if _ug_base.is_empty():
		_ug_base = [sun.light_energy, env.ambient_light_energy, env.fog_light_color, env.fog_depth_begin, env.fog_depth_end]
	if clock != null:
		_ug_base[0] = clock.sun_e
		_ug_base[1] = clock.amb_e
		_ug_base[2] = clock.fog_col
		if clock.fog_b > 0.0:
			_ug_base[3] = clock.fog_b
			_ug_base[4] = clock.fog_e
	var inside: bool = cars[0].phys.px > 3000.0
	_ug = move_toward(_ug, 1.0 if inside else 0.0, dt * 3.0)
	sun.light_energy = lerpf(float(_ug_base[0]), 0.10, _ug)
	env.ambient_light_energy = lerpf(float(_ug_base[1]), 0.30, _ug)
	env.fog_light_color = (_ug_base[2] as Color).lerp(Color(0.03, 0.03, 0.04), _ug)
	env.fog_depth_begin = lerpf(float(_ug_base[3]), 25.0, _ug)
	env.fog_depth_end = lerpf(float(_ug_base[4]), 170.0, _ug)

func on_teleport() -> void:
	_ug_base = _ug_base # (la luz cambia sola con la posición)

func _exit_tree() -> void:
	if social != null and is_instance_valid(social):
		social.leave()
	if track is CityTrack and profile != null and not cars.is_empty() and str(cfg.get("type", "")) == "city":
		var lp = cars[0].phys # la última ubicación: se puede volver a aparecer ahí desde el menú
		profile.d["lastPos"] = [snappedf(lp.px, 0.1), snappedf(lp.pz, 0.1), snappedf(lp.yaw, 0.01), CityLayout.WORLD_VERSION]
		if world_life != null:
			world_life.save(profile)
		profile.save()

func _tick_session(dt: float) -> void:
	if shops != null:
		shops.update(dt)
		links.update(dt)
		fuel.update(dt)
		if tires != null:
			tires.update(dt)
		if acts != null:
			acts.update(dt)
		tolls.update(dt)
		if city_drift != null:
			city_drift.update(dt)
		_check_gates()
		if social != null and not cars.is_empty():
			var sp0 = cars[0].phys
			social.set_state(sp0.px, sp0.pz, sqrt(sp0.vx * sp0.vx + sp0.vz * sp0.vz) * 3.6)
		if world_life != null and not cars.is_empty():
			var wp = cars[0].phys
			var tsys = world_life.get_system("traffic")
			if tsys != null:
				tsys.player_vel = Vector2(wp.vx, wp.vz) # para que el tránsito reaccione al jugador (frena, esquiva, se golpea)
			world_life.update(dt, Vector2(wp.px, wp.pz))
		if clock != null:
			clock.update(dt)
		_underground_light(dt)
	if shopshot != "" and cfg.has("resume"):
		_shopshot_f += 1
		if _shopshot_f == 90:
			get_viewport().get_texture().get_image().save_png(shopshot)
			print("SHOPBACK pos=(%d,%d)" % [int(cars[0].phys.px), int(cars[0].phys.pz)])
			get_tree().quit()
	if _link_test.size() > 1 and session is CitySession:
		var chl = race_hud.city_hud
		var phl = cars[0].phys
		_cd_t += dt
		if int(_cd_t) % 5 == 0 and fmod(_cd_t, 1.0) < dt:
			print("LINKTEST t=%d pos=(%d,%d) v=%d km/h calle=%s" % [int(_cd_t), int(phl.px), int(phl.pz), int(sqrt(phl.vx * phl.vx + phl.vz * phl.vz) * 3.6), chl.street_l.text])
		if _link_stage == 0 and phl.px > 3000.0:
			_link_stage = 1
			for l in chl.city.links:
				if str(l["id"]) == str(_link_test[1]):
					chl.set_dest(l["pos"], str(l["id"]))
					if cars[0].driver != null and cars[0].driver.get("goal") != null:
						cars[0].driver.goal = l["pos"]
					chl.arrive_r = 2.0
			print("LINKTEST entró al subsuelo en t=%d s" % int(_cd_t))
		elif _link_stage == 1 and phl.px < 3000.0:
			print("LINKTEST salió a la superficie en (%d,%d) t=%d s" % [int(phl.px), int(phl.pz), int(_cd_t)])
			get_tree().quit()
		elif _cd_t > 400.0:
			print("LINKTEST no terminó: pos=(%d,%d) etapa %d" % [int(phl.px), int(phl.pz), _link_stage])
			get_tree().quit()
	if session is CitySession and cfg.has("gpsdrive") and _link_test.is_empty():
		_cd_t += dt
		var ch = race_hud.city_hud
		var ph = cars[0].phys
		if int(_cd_t * 2.0) != int((_cd_t - dt) * 2.0) and int(_cd_t) % 4 == 0 and fmod(_cd_t, 1.0) < dt:
			print("CITYDRIVE t=%d pos=(%d,%d) v=%d km/h calle=%s" % [int(_cd_t), int(ph.px), int(ph.pz), int(sqrt(ph.vx * ph.vx + ph.vz * ph.vz) * 3.6), ch.street_l.text])
		if not ch.has_dest and _cd_t > 3.0 and ch.arrive_r < 5.0:
			pass # prueba de un local: el auto se queda en el círculo y los locales hacen el resto
		elif not ch.has_dest and _cd_t > 3.0:
			print("CITYDRIVE LLEGÓ en %.0f s, recorrió %.0f m, golpes %d" % [_cd_t, session.odo, session.hits])
			get_tree().quit()
		elif _cd_t > 240.0:
			print("CITYDRIVE NO LLEGÓ en 240 s: pos=(%d,%d)" % [int(ph.px), int(ph.pz)])
			get_tree().quit()
	session.update(dt, cars)
	if track is DriftTrack:
		var cf = (track as DriftTrack).cones
		cf.update(dt, cars)
		if cf.new_hits > 0:
			session.on_cones(cf.new_hits)
			cf.new_hits = 0
	if session.state == "run" and str(cfg.get("type")) == "race":
		# goma elástica suave: nadie se escapa demasiado
		for i in range(1, cars.size()):
			var d = cars[i].driver
			if d is AIDriver:
				var gap: float = session.prog[i] - session.prog[0]
				d.boost = 0.93 if gap > 140.0 else (1.05 if gap < -160.0 else 1.0)
	if session.state == "run" and track is DreamTrack and str(cfg.get("type")) == "race":
		_pace_rivals(dt)
	race_hud.update_hud(dt, cars.size(), cars)
	if _dbg_finish and Engine.get_frames_drawn() % 30 == 0:
		print("SES ", session.state, " t=", snappedf(session.time, 0.1), " prog=", int(session.prog[0]), "/", int(session.race_len), " v=", int(absf(cars[0].snap.vLong) * 3.6), " dt=", snappedf(dt, 0.001))
	if session.state == "done":
		done_t += dt
		if done_t > 2.5 and not _result_sent:
			_result_sent = true
			finished.emit(_make_result())

var _result_sent := false
var _dbg_finish := OS.get_cmdline_user_args().has("--finishtest")

func _make_result() -> Dictionary:
	var n := cars.size()
	var pl = cars[0]
	var t := str(cfg.get("type", "race"))
	var r := {"type": t, "time": session.finish_time[0], "max_kmh": session.max_kmh, "odo": session.odo,
		"value": 0.0, "pos": session.position_of(0, n), "n": n, "track": track_id, "laps": session.laps, "standings": []}
	match t:
		"race":
			r["value"] = float(r["pos"])
		"trap":
			r["value"] = roundf(session.trap_kmh)
		"drift":
			r["value"] = roundf(session.total)
			if session.duel:
				r["duel"] = true
				r["bot"] = roundf(session.bot_score)
				r["win"] = session.duel_won
		_:
			r["value"] = session.finish_time[0]
	if drag_mode:
		r["drag"] = true
		r["shifts"] = drag_shifts
		r["perfect"] = drag_perfect
	for id in session.standings(n):
		r["standings"].append({"name": session.names[id], "time": session.finish_time[id] if session.finished[id] else -1.0, "player": id == 0, "color": rival_info[id]["color"].to_html(false)})
	return r

## Calidad (baja/media/alta/automática), texturas y volúmenes elegidos en Opciones
func _apply_quality_settings() -> void:
	var q := str(profile.setting("quality"))
	var tree_q := {"low": 1500, "mid": 3000, "high": 6000, "auto": int(profile.setting("autoTrees"))}
	var cap := {"low": 0.45, "mid": 0.65, "high": 0.85, "auto": 0.8}
	var t = profile.setting("trees")
	trees_n = int(tree_q.get(q, 3000)) if str(t) == "auto" else int(t)
	var sh = profile.setting("shadowsQ")
	sun.shadow_enabled = (q == "high" or (q == "auto" and profile.setting("autoShadows") == true)) if str(sh) == "auto" else sh == true
	_ar_cap = float(profile.setting("autoRes")) if q == "auto" else float(cap.get(q, 0.8))
	if res_auto:
		res_scale = minf(res_scale, _ar_cap)
		if q == "low":
			res_scale = 0.4
		_on_resize()
	var tx := str(profile.setting("textures"))
	if tx == "auto":
		tx = str(profile.setting("autoTex"))
	fx.intensity = _particle_level() / 10.0
	world.anisotropic_filtering_level = {"low": Viewport.ANISOTROPY_DISABLED, "mid": Viewport.ANISOTROPY_4X, "high": Viewport.ANISOTROPY_16X}.get(tx, Viewport.ANISOTROPY_4X)
	audio.mix["eng"] = float(profile.setting("volEngine")) / 100.0
	audio.mix["surf"] = float(profile.setting("volSurf")) / 100.0
	audio.mix["wind"] = float(profile.setting("volWind")) / 100.0
	audio.mix["turbo"] = float(profile.setting("volTurbo")) / 100.0
	audio.mix["gear"] = float(profile.setting("volGear")) / 100.0

## Un cambio de Opciones hecho durante la carrera: se aplica en el momento
func _apply_live_settings(key: String) -> void:
	match key:
		"fx":
			lens.apply_settings(profile)
			lens_auto = false
		"quality", "trees", "shadowsQ", "textures":
			if world_life != null:
				world_life.set_profile(WorldLifeConfig.profile_for(profile)) # LOW / MEDIUM / HIGH según la calidad
			var old := trees_n
			_apply_quality_settings()
			if trees_n != old:
				_rebuild_trees()
		"res":
			var rs := float(profile.setting("res"))
			res_auto = rs <= 0.0
			if not res_auto:
				res_scale = rs
			_on_resize()
		"worldLife":
			if world_life != null:
				world_life.set_enabled(profile.setting("worldLife") != false)
		"particles":
			fx.intensity = _particle_level() / 10.0
		"abs", "tc", "stab", "lineAssist":
			_assist_changed(key)
		"recal":
			controls.recalibrate_gyro()
			race_hud.toast("Acelerómetro calibrado: sostené el teléfono como para jugar")
		"capBtn":
			controls.show_shot = profile.setting("capBtn") == true
		"lang":
			Tr.set_language(str(profile.setting("lang")))
		"gearbox", "steerMode", "gyro", "gyroSens", "gyroDead", "gyroCurve", "gyroSmooth", "units", "wheelSize", "pedalSize":
			_apply_controls_settings()
		"volume", "volEngine", "volSurf", "volWind", "volTurbo", "volGear":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(profile.setting("volume")) / 80.0, 0.001)))
			audio.mix["eng"] = float(profile.setting("volEngine")) / 100.0
			audio.mix["surf"] = float(profile.setting("volSurf")) / 100.0
			audio.mix["wind"] = float(profile.setting("volWind")) / 100.0
			audio.mix["turbo"] = float(profile.setting("volTurbo")) / 100.0
			audio.mix["gear"] = float(profile.setting("volGear")) / 100.0
			sfx.volume = float(profile.setting("volume")) / 100.0
		"camera":
			cam_index = int(profile.setting("camera"))
			if cam_rig != null:
				cam_rig.set_preset(cam_index)
				race_hud.toast("🎥 " + cam_rig.cam_name())

## ABS, control de tracción y estabilidad del auto del jugador (la simulación está quieta: se está en pausa)
func _apply_assists() -> void:
	if cars.is_empty():
		return
	_finish_physics()
	var V: VehicleParams = cars[0].phys.V
	var sa := _sim_assists()
	V.abs = sa["abs"] == true
	V.tractionControl = float(sa["tc"]) > 0.0
	V.tcSlip = float(vehicles[str(cfg["car"])]["tcSlip"]) * (1.6 - float(sa["tc"]) / 100.0)
	V.stabilityAssist = float(sa["stab"]) / 100.0

func _apply_controls_settings() -> void:
	manual_gearbox = str(profile.setting("gearbox")) == "manual" or drag_mode
	if not cars.is_empty():
		_finish_physics()
		cars[0].phys.manual = manual_gearbox
	controls.manual = manual_gearbox
	controls.steer_mode = "wheel" if str(profile.setting("steerMode")) == "wheel" else "slider"
	controls.gyro_on = (profile.setting("gyro") == true)
	controls.gyro_sens = float(profile.setting("gyroSens"))
	controls.gyro_dead = float(profile.setting("gyroDead"))
	controls.gyro_curve = float(profile.setting("gyroCurve"))
	controls.gyro_smooth = float(profile.setting("gyroSmooth"))
	controls.use_mph = str(profile.setting("units")) == "mph"
	controls.wheel_scale = float(profile.setting("wheelSize")) / 100.0
	controls.pedal_scale = float(profile.setting("pedalSize")) / 100.0
	var lay: Variant = profile.setting("ctrlLayout")
	controls.layout = (lay as Dictionary).duplicate(true) if lay is Dictionary else {}
	if controls.gyro_on:
		controls.recalibrate_gyro()

## Vibración del teléfono como un volante con fuerza de retorno: aprieta con la carga lateral y el patinaje, zumba con los pozos y
## la tierra suelta y da un golpe seco con los impactos. Apagada por defecto (opción «Vibración tipo volante»).
var _hap_t := 0.0
func _haptics(dt: float, p, impact: float) -> void:
	var lv := int(profile.setting("haptics"))
	if lv <= 0:
		return
	_hap_t -= dt
	var k: float = [0.0, 0.5, 0.85, 1.2][clampi(lv, 0, 3)]
	if impact > 2.2:
		Input.vibrate_handheld(110, clampf(0.45 + impact * 0.08, 0.5, 1.0))
		_hap_t = 0.15
		return
	if _hap_t > 0.0:
		return
	var sp := sqrt(p.vx * p.vx + p.vz * p.vz)
	if sp < 2.0:
		return
	var load := clampf(absf(p.aLat) / 14.0, 0.0, 1.0) # carga lateral: el volante «pesa» en las curvas
	var rough := 0.0
	var slip := 0.0
	for i in 4:
		var o := i * 8
		if p.wheel_fx[o] < 0.5:
			continue
		if int(p.wheel_fx[o + 1]) != 0:
			rough += 0.12 # tierra, pasto, nieve: zumbido
		slip = maxf(slip, maxf(absf(p.wheel_fx[o + 3]), absf(p.wheel_fx[o + 4])))
	var amp: float = (load * 0.55 + clampf(rough, 0.0, 0.4) * clampf(sp / 25.0, 0.0, 1.0) + clampf(slip - 0.15, 0.0, 0.6) * 0.5) * k
	if amp > 0.07:
		Input.vibrate_handheld(55, clampf(amp, 0.0, 1.0))
		_hap_t = 0.065

## Nivel de partículas 0–10 (polvo, humo de gomas, rocío, piedritas). En automático es el que el juego aprendió que aguanta el teléfono.
func _particle_level() -> int:
	var v = profile.setting("particles")
	return int(profile.setting("autoParticles")) if str(v) == "auto" else int(v)

## Calidad automática: si el teléfono no llega, primero baja partículas, después resolución, después texturas, y al final quita las
## partículas. Lo aprendido se guarda en el perfil (no vuelve a subir solo). Devuelve true si cambió algo.
func _auto_degrade() -> bool:
	if not menu_mode or str(profile.setting("quality")) != "auto":
		return false
	var steps := [10, 7, 4, 2, 0]
	var p_auto := str(profile.setting("particles")) == "auto"
	var p := int(profile.setting("autoParticles"))
	var pi := steps.find(p)
	if pi < 0:
		pi = 0
	if p_auto and p > 4:
		_set_auto_particles(int(steps[pi + 1]))
		return true
	if res_auto and res_scale > 0.5:
		return false # que baje primero la resolución (lo hace _auto_res)
	if p_auto and p > 2:
		_set_auto_particles(int(steps[pi + 1]))
		return true
	if track is CityTrack and track.world_node != null and float(track.world_node.view_k) > 0.62:
		_set_city_view(maxf(0.6, float(track.world_node.view_k) - 0.2)) # Dream City: se arman menos cuadras y la niebla cierra antes
		return true
	var tx := str(profile.setting("autoTex"))
	if str(profile.setting("textures")) == "auto" and tx != "low":
		profile.set_setting("autoTex", "mid" if tx == "high" else "low")
		_apply_quality_settings()
		return true
	if p_auto and p > 0:
		_set_auto_particles(int(steps[pi + 1]))
		return true
	return false

## Alcance de la vista de Dream City (1,0 = completo · 0,6 = el mínimo): cuántas cuadras se arman a la redonda y a qué distancia cierra la niebla
func _set_city_view(vk: float) -> void:
	track.world_node.view_k = vk
	env.fog_depth_begin = 160.0 * vk
	env.fog_depth_end = 560.0 * vk
	if not _ug_base.is_empty():
		_ug_base[3] = env.fog_depth_begin
		_ug_base[4] = env.fog_depth_end

func _set_auto_particles(v: int) -> void:
	profile.set_setting("autoParticles", v)
	fx.intensity = float(v) / 10.0
	if race_hud != null:
		race_hud.toast("Calidad automática: partículas al %d/10" % v)

func _fx_setting() -> Array:
	var a = profile.setting("fx")
	return [int(a[0]), int(a[1]), int(a[2])] if a is Array and a.size() >= 3 else [0, 0, 0]

## Captura de pantalla (con o sin HUD según Opciones → Captura)
func _take_shot() -> void:
	if profile == null:
		return
	var path: String = await Capture.take(self, profile)
	if race_hud != null:
		race_hud.toast("📷 Captura guardada" if path != "" else "No se pudo guardar la captura")

## Modo cine: casi todo el HUD se esconde (los controles quedan casi invisibles pero siguen andando) para grabar con la grabadora del teléfono
var cine := false
func _toggle_cine() -> void:
	cine = not cine
	race_hud.set_cine(cine)
	controls.modulate.a = 0.1 if cine else 1.0
	if cine and paused:
		_toggle_pause()

func _toggle_pause() -> void:
	if not menu_mode or (session == null and adv == null):
		return
	paused = not paused
	if paused:
		_finish_physics() # la simulación queda quieta; la imagen y la cámara siguen vivas para poder cambiar de cámara
	AudioServer.set_bus_mute(0, paused)
	race_hud.set_paused(paused)
	controls.visible = not paused
	controls.set_process_input(not paused)
	controls.set_process_unhandled_input(not paused)
	if not paused:
		_show_tests(false)

## «Modificar controles» (desde la pausa): los controles se muestran y se arrastran / agrandan con los dedos; GUARDAR los deja así para siempre
func _edit_controls() -> void:
	race_hud.pause_box.visible = false
	controls.visible = true
	controls.set_process_input(true)
	controls.set_process_unhandled_input(true)
	if not controls.edit_done.is_connected(_edit_controls_done):
		controls.edit_done.connect(_edit_controls_done)
	controls.set_editing(true)

func _edit_controls_done(saved: bool) -> void:
	controls.set_editing(false)
	if saved:
		profile.set_setting("ctrlLayout", controls.layout.duplicate(true))
	else:
		var old_l: Variant = profile.setting("ctrlLayout")
		controls.layout = (old_l as Dictionary).duplicate(true) if old_l is Dictionary else {}
	controls.visible = false
	controls.set_process_input(false)
	controls.set_process_unhandled_input(false)
	race_hud.pause_box.visible = true

func _show_tests(on := true) -> void:
	hud.visible = on
	hud.set_process_input(on)
	if on:
		hud.open = true
		# el panel ocupa la pantalla: el menú de pausa se esconde hasta cerrarlo
		race_hud.pause_box.visible = false

func _restart() -> void:
	AudioServer.set_bus_mute(0, false)
	if adv != null:
		# aventura: la etapa vuelve a empezar desde la estación, con el daño que tenía el auto al salir
		var st: Dictionary = AdvData.state(profile)
		st["damage"] = (adv.dmg0 as Dictionary).duplicate()
		profile.save()
		restart_with({"type": "adventure", "stage": int(cfg["stage"]), "back": str(cfg.get("back", "adventure")), "dmg0": (adv.dmg0 as Dictionary).duplicate()})
		return
	var c := cfg
	var a := get_parent()
	a.call_deferred("start_race", c)
	queue_free()

## Arranca otra carrera/etapa (la aventura pasa a la etapa siguiente o reintenta)
func restart_with(c: Dictionary) -> void:
	AudioServer.set_bus_mute(0, false)
	if cfg.get("practice", false) == true and str(c.get("type", "")) == "adventure":
		c["practice"] = true # práctica de Carrera rápida: sigue siendo práctica y vuelve a la Carrera rápida
		c["back"] = "quick"
	var a := get_parent()
	if a.has_method("start_race"):
		a.call_deferred("start_race", c)
		queue_free()

## Túneles de la aventura: k = 0 afuera … 1 adentro (baja el sol y el cielo; las lámparas siguen)
var _light_base := {}
func set_tunnel_light(k: float) -> void:
	if k == 0.0 and _light_k == 0.0:
		_light_base = {"sun": sun.light_energy, "amb": env.ambient_light_energy}
		return
	if _light_base.is_empty():
		_light_base = {"sun": sun.light_energy, "amb": env.ambient_light_energy}
	_light_k = k
	sun.light_energy = float(_light_base["sun"]) * (1.0 - 0.82 * k)
	env.ambient_light_energy = float(_light_base["amb"]) * (1.0 - 0.45 * k)
var _light_k := 0.0

func _quit() -> void:
	if fuel != null:
		fuel.save()
	AudioServer.set_bus_mute(0, false)
	exit_requested.emit(str(cfg.get("back", "home")))

## Ajuste de cámara del jugador (pausa → AJUSTAR CÁMARA): se guarda en el perfil
func _save_cam_adj() -> void:
	if cam_rig == null or profile == null:
		return
	cam_index = cam_rig.index
	profile.set_setting("camAdj", (cam_rig.adj as Dictionary).duplicate(true))

## Taller de prueba (pausa): el estado del auto con todos los ajustes liberados; se arma al empezar y se aplica recién al primer cambio
func _lab_init() -> void:
	var base: Dictionary
	if cfg.has("lab_state"):
		base = cfg["lab_state"]
		lab_state = base
	else:
		base = (cfg["state"] as Dictionary).duplicate(true)
		base["lab"] = {"all": true}
		if not base.has("tune"):
			base["tune"] = {}
		if int((base.get("upg", {}) as Dictionary).get("aero", 0)) == 0:
			base["tune"]["aeroF"] = 0.0 # el auto no trae kit aerodinámico de fábrica: arranca en cero
			base["tune"]["aeroR"] = 0.0
	if cfg.has("lab_orig"):
		lab_orig = cfg["lab_orig"]
	else:
		lab_orig = (base as Dictionary).duplicate(true) # el auto de fábrica (para «volver»); sobrevive a un reinicio
		cfg["lab_orig"] = lab_orig
	race_hud.lab = base
	race_hud.lab_defs = CarBuild.default_tune(vehicles[str(cfg["car"])])
	race_hud.lab_on = true

## Rearma el auto con los ajustes nuevos. En drift y en las pruebas libres queda donde estaba; en una carrera vuelve a la parrilla.
func _lab_apply() -> void:
	if cars.is_empty() or race_hud == null:
		return
	lab_state = race_hud.lab
	cfg["lab_state"] = lab_state
	cfg["labbed"] = true # una prueba con el taller no da premios ni cuenta para los récords
	var keep := track is DriftTrack or str(cfg.get("type", "")) == "free"
	var ph = cars[0].phys
	var pose := [ph.px, ph.pz, ph.yaw]
	if cam_rig != null:
		cam_index = cam_rig.index
	_rebuild_cars()
	if keep and not cars.is_empty():
		cars[0].place(pose[0], pose[1], pose[2])
		if session is DriftSession:
			session.cd = minf(session.cd, 0.2) # sin cuenta regresiva de nuevo
	race_hud.toast(Tr.t("🔧 Ajuste aplicado"))

func _lab_reset() -> void:
	race_hud.lab = lab_orig.duplicate(true)
	_lab_apply()
	lab_state = {}
	cfg.erase("lab_state")

func _next_camera() -> void:
	if cam_rig == null:
		return
	if adv != null:
		if adv.state == "race":
			adv.hud.toast("🎥 " + adv.next_camera())
		return
	cam_rig.next()
	cam_index = cam_rig.index
	if menu_mode and race_hud != null:
		race_hud.toast("🎥 " + cam_rig.cam_name())
	else:
		hud.show_toast("🎥 " + cam_rig.cam_name())

func _load_cabin_cfg() -> void:
	if cockpit == null:
		return
	var cf := ConfigFile.new()
	if cf.load("user://cabina.cfg") == OK:
		cockpit.rear_dist = float(cf.get_value("cam", "rear", cockpit.rear_dist))
		cockpit.ob_dist = float(cf.get_value("cam", "ob", cockpit.ob_dist))
		cockpit.rear_fov = float(cf.get_value("cam", "rear_fov", cockpit.rear_fov))
		cockpit.ob_fov = float(cf.get_value("cam", "ob_fov", cockpit.ob_fov))
		cockpit.set_disp_off(float(cf.get_value("cam", "disp2", cockpit.disp_off)))
	hud.sliders["cam_rear"]["val"] = cockpit.rear_dist
	hud.sliders["cam_rear_fov"]["val"] = cockpit.rear_fov
	hud.sliders["cam_ob"]["val"] = cockpit.ob_dist
	hud.sliders["cam_ob_fov"]["val"] = cockpit.ob_fov
	hud.sliders["disp_x"]["val"] = cockpit.disp_off

func _save_cabin_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("cam", "rear", cockpit.rear_dist)
	cf.set_value("cam", "ob", cockpit.ob_dist)
	cf.set_value("cam", "rear_fov", cockpit.rear_fov)
	cf.set_value("cam", "ob_fov", cockpit.ob_fov)
	cf.set_value("cam", "disp2", cockpit.disp_off)
	cf.save("user://cabina.cfg")

func _on_option(key: String, value) -> void:
	match key:
		"to_menu":
			if fuel != null:
				fuel.save()
			AudioServer.set_bus_mute(0, false)
			exit_requested.emit("home")
		"panel_closed":
			if menu_mode:
				_show_tests(false)
				race_hud.pause_box.visible = paused
		"cam_rear":
			cockpit.rear_dist = float(value)
			_save_cabin_cfg()
		"cam_ob":
			cockpit.ob_dist = float(value)
			_save_cabin_cfg()
		"cam_rear_fov":
			cockpit.rear_fov = float(value)
			_save_cabin_cfg()
		"cam_ob_fov":
			cockpit.ob_fov = float(value)
			_save_cabin_cfg()
		"disp_x":
			cockpit.set_disp_off(float(value))
			_save_cabin_cfg()
		"cars":
			cars_n = int(value)
			_rebuild_cars()
		"trees":
			trees_n = int(value)
			_rebuild_trees()
		"pilots":
			pilots_on = int(value) == 1
			_rebuild_cars()
		"shadows":
			sun.shadow_enabled = int(value) == 1
		"hi":
			hi_model = int(value) == 1
			_rebuild_cars()
		"threads":
			threaded = int(value) == 1
		"res":
			res_auto = float(value) == 0.0
			if not res_auto:
				res_scale = float(value)
				_on_resize()
		"track":
			_change_track(str(value))
		"lens":
			lens.level = int(value)
			lens_auto = false
		"steer":
			controls.steer_mode = "wheel" if str(value) == "volante" else "slider"
		"gearbox":
			manual_gearbox = str(value) == "manual" or drag_mode
			if not cars.is_empty():
				cars[0].phys.manual = manual_gearbox
			controls.manual = manual_gearbox
		"gyro":
			controls.gyro_on = int(value) == 1
			controls.recalibrate_gyro()
		"nitro":
			nitro_test = int(value) == 1
			_rebuild_cars()
		"weather":
			weather.apply(str(value))
			audio.rain(str(value) == "lluvia")
			if cockpit != null:
				cockpit.raining = str(value) == "lluvia"
		"recal":
			controls.recalibrate_gyro()
			hud.show_toast("Acelerómetro calibrado: sostené el teléfono como para jugar")

## Física a 120 Hz con paso fijo propio, UN CUADRO ADELANTADA y en otros núcleos:
##  · al empezar el cuadro se espera (casi nunca) a que terminen los pasos del cuadro anterior y se toma una foto de cada auto;
##  · enseguida se lanza la física del cuadro que viene (una tarea por auto) y el hilo principal sigue con el dibujado.
## El dibujado y la cámara usan solo la foto. Costo: un cuadro (16 ms) más de retardo al girar el volante.
var phys_task := -1
var sim_t := 0.0 # hora de la simulación (múltiplo de 1/120 s)
var batch_t0 := 0.0
var render_t := 0.0
var smooth_dt := 0.016
var phys_wait_us := 0

func _finish_physics() -> void:
	if phys_task != -1:
		var t0 := Time.get_ticks_usec()
		WorkerThreadPool.wait_for_group_task_completion(phys_task)
		phys_wait_us += Time.get_ticks_usec() - t0
		phys_task = -1

## Picada: cuánto acertaste el momento del cambio (por las vueltas justo antes de subir la marcha).
## Perfecto = ventana verde de la barra: el cambio es el doble de rápido. Tarde = rebote contra el limitador: se pierde tracción un rato.
func _drag_shift_quality() -> void:
	var ph = cars[0].phys
	for e in pl_events:
		if e["type"] == "shift" and e["up"] == true and session != null and session.state == "run":
			var q: int = Drag.quality(drag_rpm, float(ph.V.shiftUpRpm))
			drag_shifts += 1
			ph.shiftT *= Drag.shift_scale(q)
			if q == Drag.Q.PERFECT:
				drag_perfect += 1
				race_hud.toast("⚡ ¡CAMBIO PERFECTO!", "up")
			elif q == Drag.Q.EARLY:
				race_hud.toast("Cambio temprano: esperá a la zona verde", "down")
			else:
				race_hud.toast("Cambio tarde: tocaste el limitador", "down")
	drag_rpm = float(ph.rpm)

func _step_physics(dt: float) -> void:
	_finish_physics()
	# eventos de la física (cambios, limitador, aterrizajes, golpes): se toman ahora, con los hilos parados
	for i in cars.size():
		var sn = cars[i].snap
		if i == 0:
			pl_events = sn.take_events()
			if drag_mode:
				_drag_shift_quality()
			pl_impact = maxf(pl_impact, sn.take_impact())
		else:
			sn.pending_events.clear()
			sn.pending_impact = 0.0
	if adv != null:
		adv.pre_physics()
	if menu_mode and cars.size() > 1 and ((session != null and session.state != "countdown") or adv != null):
		_resolve_collisions()
	for c in cars:
		if c.wall_hit > 0.0:
			if c.is_player:
				pl_impact = maxf(pl_impact, c.wall_hit * 0.55)
				if social != null and c.wall_hit > 6.0:
					social.note_event("golpe")
				if session != null and track is DriftTrack:
					session.on_wall(c.wall_hit)
				if city_drift != null:
					city_drift.on_wall(c.wall_hit)
				if adv != null:
					adv.on_hit(c.wall_hit, "wall")
			c.wall_hit = 0.0
	var h := 1.0 / 120.0
	smooth_dt = lerpf(smooth_dt, minf(dt, 0.1), 0.02)
	acc = minf(acc + dt, 0.05)
	step_n = int(acc / h)
	acc -= float(step_n) * h
	batch_t0 = sim_t
	sim_t += float(step_n) * h
	# hora que se dibuja: atrasada lo justo para que los estados que rodean esa hora ya estén calculados
	render_t = sim_t + acc - (smooth_dt * 1.3 + h)
	if step_n <= 0 or cars.is_empty():
		return
	var pl: Car = cars[0]
	pl.in_throttle = controls.gas
	pl.in_brake = controls.brake
	pl.in_steer = controls.steer
	pl.in_handbrake = controls.handbrake
	pl.in_nitro = controls.nitro
	if fuel != null and fuel.blocks_throttle():
		pl.in_throttle = 0.0 # sin nafta (o cargando) el auto no acelera
		pl.in_nitro = false
	if menu_mode and session != null and session.state == "run" and assist_view != null:
		var la := float(_sim_assists()["line"]) / 100.0
		# con el auto casi parado la ayuda no gira el volante (antes se veía el volante torcido en la largada)
		var moving := clampf((absf(pl.phys.vLong) - 2.0) / 5.0, 0.0, 1.0)
		if la > 0.0 and moving > 0.0:
			pl.in_steer = clampf(pl.in_steer + _line_steer(pl) * la * 0.85 * moving * (1.0 - absf(pl.in_steer)), -1.0, 1.0)
	if session != null and session.state == "countdown":
		pl.in_throttle = 0.0 # en la largada el auto está frenado hasta el "¡YA!"
		pl.in_brake = 1.0
		pl.in_handbrake = true
		pl.in_nitro = false
	elif session != null and session.state == "done":
		pl.in_throttle = 0.0
		pl.in_brake = maxf(controls.brake, 0.4)
		pl.in_nitro = false
	if controls.shift != 0:
		pl.in_shift = controls.shift
	if adv != null:
		pl.in_steer = clampf(pl.in_steer + adv.steer_pull(), -1.0, 1.0) # la dirección golpeada tira hacia un lado
	phys_frames += 1
	if threaded:
		phys_task = WorkerThreadPool.add_group_task(_step_car, cars.size(), -1, true, "fisica")
	else:
		var t0 := Time.get_ticks_usec()
		for i in cars.size():
			_step_car(i)
		phys_us += Time.get_ticks_usec() - t0

## Ayuda de trazada: volante que apunta al centro del camino (seguimiento de punto adelantado, como la IA); se mezcla con lo que hace el jugador
var assist_view
func _line_steer(pl) -> float:
	var ph = pl.phys
	var v = assist_view
	v.nearest(ph.px, ph.pz)
	var spd := maxf(3.0, sqrt(ph.vx * ph.vx + ph.vz * ph.vz))
	var Ld := clampf(5.0 + spd * 0.55, 8.0, 32.0)
	var i: int = v.r_idx
	var acc := 0.0
	var n: int = v.n
	while acc < Ld:
		var j := (i + 1) % n
		acc += (v.samples[i] as Vector3).distance_to(v.samples[j])
		i = j
	var tg: Vector3 = v.samples[i]
	var fx := sin(ph.yaw)
	var fz := cos(ph.yaw)
	var lx := cos(ph.yaw)
	var lz := -sin(ph.yaw)
	var dx: float = tg.x - ph.px
	var dz: float = tg.z - ph.pz
	var alpha := atan2(dx * lx + dz * lz, maxf(0.5, dx * fx + dz * fz))
	var delta := atan(2.0 * ph.V.wheelBase * sin(alpha) / Ld)
	return clampf(-delta / (ph.V.maxSteer * ph.steer_scale(spd)), -1.0, 1.0)

## Choques entre autos: tres círculos por auto, impulso con rebote parcial y roce; también gira los autos según dónde pega
func _resolve_collisions() -> void:
	var n := cars.size()
	for a in n:
		var pa = cars[a].phys
		for b in range(a + 1, n):
			var pb = cars[b].phys
			var dx: float = pb.px - pa.px
			var dz: float = pb.pz - pa.pz
			if dx * dx + dz * dz > 40.0:
				continue
			var hit := 0.0
			for ia in 3:
				for ib in 3:
					hit = maxf(hit, _circle_hit(pa, pb, float(ia - 1), float(ib - 1)))
			if hit > 0.0 and (a == 0 or b == 0):
				pl_impact = maxf(pl_impact, hit * 0.7)
				if adv != null:
					adv.on_hit(hit, "car")

func _circle_hit(pa, pb, ka: float, kb: float) -> float:
	var La: float = pa.V.wheelBase + 1.5
	var Lb: float = pb.V.wheelBase + 1.5
	var ra := maxf(0.95, pa.V.trackF * 0.5 + 0.05)
	var rb := maxf(0.95, pb.V.trackF * 0.5 + 0.05)
	var oax: float = sin(pa.yaw) * ka * La * 0.34
	var oaz: float = cos(pa.yaw) * ka * La * 0.34
	var obx: float = sin(pb.yaw) * kb * Lb * 0.34
	var obz: float = cos(pb.yaw) * kb * Lb * 0.34
	var cx: float = (pb.px + obx) - (pa.px + oax)
	var cz: float = (pb.pz + obz) - (pa.pz + oaz)
	var d := sqrt(cx * cx + cz * cz)
	var over := ra + rb - d
	if over <= 0.0 or d < 0.001:
		return 0.0
	var nx := cx / d
	var nz := cz / d
	var ma: float = pa.V.mass
	var mb: float = pb.V.mass
	# separar (el liviano se mueve más)
	var wa := mb / (ma + mb)
	pa.px -= nx * over * wa
	pa.pz -= nz * over * wa
	pb.px += nx * over * (1.0 - wa)
	pb.pz += nz * over * (1.0 - wa)
	# puntos de contacto respecto de cada centro
	var rax := oax + nx * ra
	var raz := oaz + nz * ra
	var rbx := obx - nx * rb
	var rbz := obz - nz * rb
	var vax: float = pa.vx + pa.yawRate * raz
	var vaz: float = pa.vz - pa.yawRate * rax
	var vbx: float = pb.vx + pb.yawRate * rbz
	var vbz: float = pb.vz - pb.yawRate * rbx
	var rvx := vbx - vax
	var rvz := vbz - vaz
	var vn := rvx * nx + rvz * nz
	if vn >= 0.0:
		return 0.0
	var ta := raz * nx - rax * nz
	var tb := rbz * nx - rbx * nz
	var denom := 1.0 / ma + 1.0 / mb + ta * ta / float(pa.V.Izz) + tb * tb / float(pb.V.Izz)
	var j := -(1.0 + 0.22) * vn / denom
	pa.vx -= j * nx / ma
	pa.vz -= j * nz / ma
	pb.vx += j * nx / mb
	pb.vz += j * nz / mb
	pa.yawRate -= j * ta / float(pa.V.Izz)
	pb.yawRate += j * tb / float(pb.V.Izz)
	# roce lateral entre las chapas
	var vt := -rvx * nz + rvz * nx
	var jt := clampf(-vt * 0.12 / (1.0 / ma + 1.0 / mb), -0.25 * j, 0.25 * j)
	pa.vx -= -jt * nz / ma
	pa.vz -= jt * nx / ma
	pb.vx += -jt * nz / mb
	pb.vz += jt * nx / mb
	return -vn

func _step_car(i: int) -> void:
	var c: Car = cars[i]
	for k in step_n:
		c.step_and_record(1.0 / 120.0, batch_t0 + float(k + 1) / 120.0)

func _process(dt: float) -> void:
	if not is_loaded:
		return
	var t0 := Time.get_ticks_usec()
	_frame(dt)
	script_ms = lerpf(script_ms, float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	if res_auto:
		_auto_res(dt)

## Resolución automática del mundo 3D: baja si el teléfono no llega y sube de a poco si le sobra
var _ar_t := 0.0
var _ar_sum := 0.0
var _ar_n := 0
var _ar_cool := 0.0
var _ar_cap := 0.8
func _auto_res(dt: float) -> void:
	if bench_i >= 0 or pb_active or dt > 0.25:
		return
	_ar_t += dt
	_ar_sum += dt
	_ar_n += 1
	_ar_cool -= dt
	if _ar_t < 1.5:
		return
	var avg := _ar_sum / float(_ar_n)
	_ar_t = 0.0
	_ar_sum = 0.0
	_ar_n = 0
	var target := 1.0 / maxf(DisplayServer.screen_get_refresh_rate(), 30.0) if is_finite(DisplayServer.screen_get_refresh_rate()) else 0.0167
	target = clampf(target, 0.0083, 0.0167)
	if avg > target * 1.25 and _auto_degrade():
		_ar_cool = 12.0
	elif avg > target * 1.25 and res_scale <= 0.45 and lens.level > 0 and lens_auto:
		lens.level = 0 # ni bajando la resolución llega: el filtro de cámara es lo primero que se apaga
	elif avg > target * 1.25 and res_scale > 0.36:
		res_scale = maxf(0.35, res_scale - 0.05)
		_ar_cap = minf(_ar_cap, res_scale + 0.05) # ahí ya no llegaba: no vuelve a probar arriba enseguida
		_ar_cool = 20.0
		if menu_mode and str(profile.setting("quality")) == "auto":
			profile.set_setting("autoRes", res_scale)
		_on_resize()
	elif avg < target * 1.08 and res_scale < _ar_cap and _ar_cool <= 0.0:
		res_scale = minf(_ar_cap, res_scale + 0.05)
		_ar_cool = 6.0
		_on_resize()

func _frame(dt: float) -> void:
	_check_terrain()
	controls.update_inputs(dt)
	if force_gas:
		controls.gas = 1.0
	if force_steer != 0.0:
		controls.steer = force_steer
	if force_hb:
		controls.handbrake = true
	if not paused:
		_step_physics(dt)
	if bench_i >= 0:
		_bench_tick(dt)
	if pb_active and pb_i >= 0:
		_pb_tick(dt)
		if track is DriftTrack:
			(track as DriftTrack).cones.update(dt, cars) # sin sesión nadie mueve los conos: se hace acá para medir su costo
	if cars.is_empty():
		return
	if adv != null and not paused:
		adv.tick(dt)
	if session != null and not paused:
		_tick_session(dt)
		if OS.get_cmdline_user_args().has("--pausetest") and not _pausetest_done and Engine.get_process_frames() >= 100:
			_pausetest_done = true
			_toggle_pause()
			if OS.get_cmdline_user_args().has("--optstest"):
				race_hud.open_options()
				race_hud._opts_go("options", "graficos")
				profile.set_setting("fx", [9, 3, 0])
				_apply_live_settings("fx")
			if OS.get_cmdline_user_args().has("--labtest"):
				# prueba: abre el taller de la pausa, cambia ajustes, aplica y vuelve a aplicar (el auto debe quedar donde estaba)
				race_hud.open_page("lab")
				var before := [cars[0].phys.px, cars[0].phys.pz]
				race_hud.lab["tune"]["springF"] = 140.0
				race_hud.lab["tune"]["gripR"] = 80.0
				race_hud.lab["lab"]["power"] = 200.0
				race_hud.lab["tires"] = "drift"
				race_hud.lab_changed.emit()
				await get_tree().process_frame
				print("LAB: potencia %.2f resortes %.0f%% pose %s → %s · cars %d" % [cars[0].phys.V.powerScale, 140.0, str(before), str([cars[0].phys.px, cars[0].phys.pz]), cars.size()])
				race_hud.open_page("camadj")
				race_hud.cam_step.emit(1)
				cam_rig.set_adj("dist", 2.0)
				_save_cam_adj()
				print("CAMADJ: ", profile.setting("camAdj"), " cam ", cam_rig.cam_name())
				race_hud.lab_reset.emit()
				await get_tree().process_frame
				print("LAB reset: potencia %.2f" % cars[0].phys.V.powerScale)
			await get_tree().create_timer(1.0, true, false, true).timeout
			if shot_path != "":
				get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
	for c in cars:
		c.snap.sample(render_t)
		c.update_visual(0.0 if paused else dt)
	if not paused:
		_update_fx(dt)
	var p = cars[0].snap
	# cámara (las de seguimiento, capó, paragolpes, libre y las dos interiores)
	var pos := Vector3(p.px, p.py, p.pz)
	var fwd := Vector3(sin(p.yaw), 0, cos(p.yaw))
	cam_rig.aspect = float(world.size.x) / float(maxi(1, world.size.y))
	cam_rig.update(dt, p, false)
	if adv != null:
		adv.camera(dt)
	if adv_world != null:
		adv_world.update(float(adv.prog[0]) if adv != null else float(cfg.get("s_load", 0.0)))
		if adv_world_alt != null:
			adv_world_alt.update(float(adv.alt_s()) if adv != null else float(cfg.get("s_load", 0.0)))
		adv_world.follow(cam.global_position, env.fog_light_color)
	var inside: bool = cam_rig.is_inside() and cockpit != null
	var onboard: bool = cam_rig.mode() == "onboard"
	if inside != was_inside or onboard != was_onboard:
		was_inside = inside
		was_onboard = onboard
		cars[0].visual.set_inside(inside)
		controls.show_speed = not inside
		cockpit.set_inside(inside, not onboard)
	if inside:
		cockpit.update_crew(dt, p, controls.handbrake, cam_rig.time, 0.0)
		cockpit.update_cabin(dt, p, controls.handbrake, cam_rig.time)
	if cam_mode == "side":
		var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
		cam.position = pos + right * 5.0 + Vector3.UP * 0.6 + fwd * 1.0
		cam.look_at(pos + Vector3.UP * 0.1)
	elif cam_mode == "front":
		cam.position = pos + fwd * 6.0 + Vector3.UP * 1.6 + Vector3(cos(p.yaw), 0, -sin(p.yaw)) * 2.5
		cam.look_at(pos + Vector3.UP * 0.5)
	elif cam_mode == "top":
		cam.position = pos + Vector3.UP * 9.0 - fwd * 0.5
		cam.look_at(pos)
	# HUD
	controls.speed_kmh = absf(p.vLong) * 3.6
	controls.gear_text = "R" if p.gear < 0 else ("N" if p.gear == 0 else str(p.gear))
	controls.rpm_frac = p.rpm / cars[0].phys.V.maxRpm
	if drag_mode:
		var vv = cars[0].phys.V
		controls.shift_lo = Drag.LO * float(vv.shiftUpRpm) / float(vv.maxRpm)
		controls.shift_hi = minf(1.0, Drag.HI * float(vv.shiftUpRpm) / float(vv.maxRpm))
	lens.update(dt, controls.speed_kmh, 1.0 if controls.nitro else 0.0)
	if menu_mode and not paused:
		_haptics(dt, p, pl_impact)
	if audio_on and not paused:
		audio.update(p, cars[0].phys.V, dt, pl_events, pl_impact)
		pl_events = []
		pl_impact = 0.0
		# el rival más cercano (a menos de 55 m) también suena
		var nd := -1.0
		var nrpm := 0.0
		for i in range(1, cars.size()):
			var d2 := Vector2(cars[i].snap.px - p.px, cars[i].snap.pz - p.pz).length()
			if d2 < 55.0 and (nd < 0.0 or d2 < nd):
				nd = d2
				nrpm = cars[i].snap.rpm
		audio.rival(nd, nrpm, cars[0].phys.V.firingOrder)
	stat_timer += dt
	frame_count += 1
	if stat_timer >= 0.5:
		var fps := Engine.get_frames_per_second()
		_update_fps_label(fps)
		if phys_frames > 0:
			shown_phys_ms = float(phys_us + phys_wait_us) / 1000.0 / float(phys_frames)
		hud.stats_text = "FPS %d · cuadro %.1f ms · física %.2f ms/cuadro (%s)\nAutos %d · pilotos %s · árboles %d · sombras %s\nLlamadas %d · objetos %d · triángulos %dk" % [
			fps, dt * 1000.0, shown_phys_ms, "hilos" if threaded else "1 hilo", cars_n, "sí" if pilots_on else "no", trees_n, "sí" if sun.shadow_enabled else "no",
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
		phys_us = 0
		phys_wait_us = 0
		phys_frames = 0
		frame_count = 0
		stat_timer = 0.0
		if bench and Engine.get_frames_drawn() > 60:
			fps_sum += fps
			fps_n += 1
	if shot_frames > 0 and Engine.get_frames_drawn() >= shot_frames:
		if audiorec != null:
			audiorec.set_recording_active(false)
			audiorec.get_recording().save_to_wav(audiorec_path)
		print("VEL ", int(controls.speed_kmh), " km/h · marcha ", controls.gear_text, " · ", fx.debug_info())
		print("RENDER triángulos %d · llamadas %d · objetos %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		if bench and fps_n > 0:
			print("BENCH fps medio %.1f · %s" % [fps_sum / fps_n, hud.stats_text.replace("\n", " | ")])
		get_tree().quit()
