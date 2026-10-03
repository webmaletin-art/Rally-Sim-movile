extends Node
## Entrada del juego: menú principal ↔ carrera. Con argumentos de prueba (--shot, --bench, --track…) arranca directo la carrera
## de pruebas (así siguen andando las capturas y el informe de rendimiento).

const Profile := preload("res://game/data/profile.gd")
const MenuScript := preload("res://game/ui/menu.gd")
const Rewards := preload("res://game/data/rewards.gd")
const Loading := preload("res://game/ui/loading.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const RACE_SCENE := preload("res://game/race.tscn")
const Tr := preload("res://game/i18n/tr.gd")
const Release := preload("res://game/data/release.gd")
const Billing := preload("res://game/store/billing.gd")
const Online := preload("res://game/online/online.gd")

var autorace_used := false
var profile: RefCounted
var offer_shown := false # el cartel de ofertas sale una vez por sesión
var billing: Node # compras de Google Play (sin plugin queda «no disponible»)
var online: Node # modo online (Supabase): rankings; apagado si no hay configuración o el jugador no participa
var menu: Node
var race: Node

func _ready() -> void:
	profile = Profile.new()
	Tr.setup(profile)
	Release.sync_cars(profile)
	billing = Billing.new()
	add_child(billing)
	billing.setup(profile)
	online = Online.new()
	online.profile = profile
	add_child(online)
	var dbg := false
	var menu_forced := false
	for a in OS.get_cmdline_user_args():
		if a == "--menu":
			menu_forced = true
		elif a.begins_with("--") and not a.begins_with("--manifest=") and not a.begins_with("--screen="):
			dbg = true
	if dbg and not menu_forced:
		_start_race({})
		return
	show_menu()

func show_menu(screen := "home") -> void:
	AdvData.practice = {} # la práctica de la Ruta de los Sueños no deja rastro
	if race != null:
		race.queue_free()
		race = null
	if menu != null:
		menu.queue_free()
	menu = MenuScript.new()
	menu.app = self
	menu.profile = profile
	menu.start_screen = screen
	add_child(menu)

## cfg: ver race.gd (car, state, track, weather, ai, laps, seg, type, event, tier…). {} = escena de pruebas
func _start_race(cfg: Dictionary) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	var loading: CanvasLayer = null
	if not cfg.is_empty():
		# pantalla de carga: se dibuja antes de armar el mapa, que se hace por etapas sin congelar la pantalla
		loading = Loading.new()
		loading.cfg = cfg
		loading.track_name = str(Menu_maps().get(str(cfg.get("track", "")), {}).get("name", ""))
		if str(cfg.get("type", "")) == "adventure":
			var si := int(cfg.get("stage", 0))
			loading.track_name = "Etapa %d · %s" % [si + 1, str(AdvRoute.STAGES[si]["name"])]
		add_child(loading)
		await get_tree().process_frame
		await get_tree().process_frame
	race = RACE_SCENE.instantiate()
	race.cfg = cfg
	race.profile = profile
	race.finished.connect(_on_race_finished)
	race.exit_requested.connect(_on_race_exit)
	if loading != null:
		race.load_progress.connect(loading.set_progress)
		race.loaded.connect(func() -> void:
			if is_instance_valid(loading):
				loading.queue_free())
	add_child(race)

func Menu_maps() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]

func start_race(cfg: Dictionary) -> void:
	_start_race(cfg)

var last_cfg: Dictionary
var city_return: Dictionary = {} # cfg de Dream City al entrar a un taller o concesionario (para volver a la calle)

var pending_result: Dictionary

func _on_race_finished(result: Dictionary) -> void:
	last_cfg = race.cfg
	pending_result = Rewards.apply(profile, last_cfg, result)
	_submit_online(last_cfg, result)
	race.queue_free()
	race = null
	show_menu("results")

## Manda la marca al ranking online (sin esperar la respuesta ni molestar si falla). No cuenta el modo desarrollador, las pruebas de autos ni la aventura.
func _submit_online(cfg: Dictionary, result: Dictionary) -> void:
	if online == null or not online.enabled() or profile.setting("dev") == true:
		return
	var board: String = Online.board_for(str(result.get("type", "")), cfg)
	if board == "":
		return
	var v := float(result.get("value", 0.0)) if board == "drift" else float(result.get("time", 0.0))
	if v <= 0.0:
		return
	var build := ""
	if FileAccess.file_exists("res://game/build_id.txt"):
		build = FileAccess.get_file_as_string("res://game/build_id.txt").strip_edges()
	online.submit_score(str(cfg.get("track", "")), board, v, str(cfg.get("car", "")), int(result.get("laps", 1)), build)

func _on_race_exit(back: String) -> void:
	if back.begins_with("shop:") and race != null:
		city_return = (race.cfg as Dictionary).duplicate(true) # el auto queda frente al local: se vuelve ahí
	else:
		city_return = {}
	show_menu(back)
