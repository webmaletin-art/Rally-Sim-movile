extends Node
## Calibración de la configuración gráfica automática (ver autotune.gd). Vive dentro de la carrera de calibración (Dream City, en el centro del pueblo: el peor caso razonable,
## con el HUD real, el tránsito, los edificios, los árboles, la niebla y el horizonte). Prueba unos pocos escalones de la escalera, de a uno: aplica el perfil, deja pasar el tiempo de
## estabilización, mide cuadros por segundo unos segundos y sigue la búsqueda binaria. Al terminar muestra el resultado y, con JUGAR, guarda el perfil (que queda FIJO) y vuelve.
## No hay adaptación mientras se juega: esta es la única medición.

const Autotune := preload("res://game/autotune.gd")
const CalibUi := preload("res://game/ui/calib_ui.gd")
const DiagSpots := preload("res://game/city/diag_spots.gd")
const CityTrack := preload("res://game/track/city_track.gd")
const FrameRes := preload("res://game/ui/frame_res.gd")

var race: Node
var back := "home"
var target := 60.0
var searcher: Autotune.Searcher
var layer: CanvasLayer
var ui := {}
var state := "load"
var result := {}

var _t := 0.0
var _rung := -1
var _times := PackedFloat32Array()
var _n_probe := 0
var _kept: Dictionary = {} # los ajustes del jugador antes de calibrar (si se cierra sin terminar, el perfil guardado no se tocó)

func begin(p_race: Node) -> void:
	race = p_race
	back = str(race.cfg.get("calibBack", "home"))
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	ui = CalibUi.progress(layer)
	target = Autotune.target_fps()
	searcher = Autotune.Searcher.new(target, Autotune.LADDER.size())

func _process(dt: float) -> void:
	if race == null or not is_instance_valid(race):
		return
	match state:
		"load":
			if bool(race.get("is_loaded")):
				_t += dt
				if _t > 1.5:
					_setup()
		"settle":
			_t += dt
			if _t >= (Autotune.FIRST_SETTLE_S if _n_probe <= 1 else Autotune.SETTLE_S):
				_t = 0.0
				_times = PackedFloat32Array()
				state = "measure"
		"measure":
			_t += dt
			_times.append(dt) # los tirones también cuentan: son parte de lo que se siente
			(ui["bar"] as ProgressBar).value = clampf((float(_n_probe) - 1.0 + _t / Autotune.MEASURE_S) / 4.0, 0.0, 1.0)
			if _t >= Autotune.MEASURE_S:
				var st := Autotune.stats(_times)
				searcher.report(_rung, st)
				(ui["perf"] as Label).text = "%s %d FPS" % [CalibUi.Tr.t("Rendimiento:"), int(round(float(st["avg"])))]
				_next()

func _setup() -> void:
	# el peor caso razonable: el centro del pueblo, de día y despejado (siempre igual para poder comparar), con el tránsito y los peatones de siempre
	var spot: Dictionary = {}
	for sp in DiagSpots.spots(race.track.city):
		if "CENTRO" in str((sp as Dictionary)["label"]).to_upper():
			spot = sp
	if spot.is_empty():
		spot = DiagSpots.spots(race.track.city)[0]
	race.track.world_node.warm(Vector3(float(spot["x"]), 0.0, float(spot["z"])))
	race.cars[0].place(float(spot["x"]), float(spot["z"]), float(spot["yaw"]))
	race.on_teleport()
	if race.clock != null:
		race.clock.set_manual_weather("clear")
		race.clock.set_manual_hour(12.5)
	Autotune.reset_to_auto(race.profile) # sólo en memoria: lo del jugador se guarda recién con JUGAR
	_next()

func _next() -> void:
	var r := searcher.next()
	if r < 0:
		_finish()
		return
	_start_probe(r)

func _start_probe(r: int) -> void:
	_rung = r
	_n_probe += 1
	_t = 0.0
	state = "settle"
	var s := Autotune.rung_settings(r)
	var st: Dictionary = race.profile.d["settings"]
	for k in s:
		st[k] = s[k]
	race._apply_quality_settings() # partículas, texturas, sombras, ESCALA 3D del perfil y RESOLUCIÓN DE FRAME (todo por los mismos ajustes de siempre)
	if race.track is CityTrack:
		race._set_city_view(Autotune.view_k_for(int(s["autoTier"])))
	var fp: Vector2i = race.frame_rig.size_of(int((Autotune.LADDER[r] as Array)[0]))
	(ui["res"] as Label).text = "%s %d×%d" % [CalibUi.Tr.t("Resolución:"), fp.x, fp.y]
	(ui["perf"] as Label).text = CalibUi.Tr.t("Rendimiento: calibrando...")
	(ui["quality"] as Label).text = "%s %s" % [CalibUi.Tr.t("Calidad visual:"), Autotune.rung_name(r)]

func _finish() -> void:
	state = "done"
	result = searcher.finish()
	var r: int = int(result["rung"])
	var L: Array = Autotune.LADDER[r]
	var fp: Vector2i = race.frame_rig.size_of(int(L[0]))
	(ui["root"] as Control).queue_free()
	var summary := "%s: %s · %s %d×%d (%d%%)" % [CalibUi.Tr.t("Perfil"), Autotune.rung_name(r), CalibUi.Tr.t("imagen a"), fp.x, fp.y, int(round(FrameRes.fraction_of(int(L[0])) * 100.0))]
	if not bool(result["stable"]):
		summary += "\n" + CalibUi.Tr.t("Este dispositivo no llega a mantener 60 cuadros por segundo: se eligió la mejor configuración estable que logró.")
	CalibUi.done(layer, summary, _play)

func _play() -> void:
	Autotune.save_result(race.profile, result, target) # aplica, guarda y deja FIJO el perfil (Automático)
	race.exit_requested.emit(back)
