extends Node
## Entrada del juego: menú principal ↔ carrera. Con argumentos de prueba (--shot, --bench, --track…) arranca directo la carrera
## de pruebas (así siguen andando las capturas y el informe de rendimiento).

const Profile := preload("res://game/data/profile.gd")
const MenuScript := preload("res://game/ui/menu.gd")
const Rewards := preload("res://game/data/rewards.gd")
const Loading := preload("res://game/ui/loading.gd")
const RACE_SCENE := preload("res://game/race.tscn")

var autorace_used := false
var profile: RefCounted
var menu: Node
var race: Node

func _ready() -> void:
	profile = Profile.new()
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

var pending_result: Dictionary

func _on_race_finished(result: Dictionary) -> void:
	last_cfg = race.cfg
	pending_result = Rewards.apply(profile, last_cfg, result)
	race.queue_free()
	race = null
	show_menu("results")

func _on_race_exit(back: String) -> void:
	show_menu(back)
