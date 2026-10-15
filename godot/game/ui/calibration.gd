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
const CrashLog := preload("res://game/diag/crash_log.gd")

var race: Node
var back := "home"
var target := 60.0
var searcher: RefCounted # Autotune.PresetSearch (15/10/2026: mide ALTA → ULTRA o NORMAL → BAJA y después busca la escala de la opción 60 FPS)
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
	searcher = Autotune.PresetSearch.new(target)

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
			(ui["bar"] as ProgressBar).value = clampf((float(_n_probe) - 1.0 + _t / Autotune.MEASURE_S) / 4.0, 0.0, 1.0) # (3 a 5 mediciones)
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
	var r: int = searcher.next()
	if r < 0:
		_finish()
		return
	_start_probe(r)

func _start_probe(r: int) -> void:
	_rung = r
	_n_probe += 1
	_t = 0.0
	state = "settle"
	var P: Dictionary = searcher.preset(r) # (la 60 FPS con la escala 3D que calculó la búsqueda)
	var st: Dictionary = race.profile.d["settings"]
	for k in P:
		if k != "n" and k != "d":
			st[k] = P[k]
	st["autoFrame"] = 0
	if not _kept.has("worldLife"):
		_kept["worldLife"] = st.get("worldLife", true)
	st["worldLife"] = searcher.life60 if r == 0 else _kept["worldLife"] # (la 60 FPS puede apagar el tránsito si el límite es el procesador)
	race._apply_quality_settings() # partículas, texturas, sombras y ESCALA 3D (los mismos ajustes de siempre)
	if race.get("life") != null:
		race.life.apply_setting("quality") # tránsito y peatones según la calidad (LOW / MEDIUM / HIGH)
		race.life.apply_setting("worldLife")
	if race.track is CityTrack:
		race._set_city_view(Autotune.view_k_for(int(P["autoTier"])))
	var fp: Vector2i = _res_of(r)
	(ui["res"] as Label).text = "%s %d×%d" % [CalibUi.Tr.t("Resolución:"), fp.x, fp.y]
	CrashLog.mark("calib", "%s · %d×%d · escala 3D %.2f · sombras %s · texturas %s · partículas %d · árboles %d · vida %s" % [str(P["n"]), fp.x, fp.y,
		float(P["autoRes"]), str(P["autoShadows"]), str(P["autoTex"]), int(P["autoParticles"]), int(P["autoTrees"]), str(st["worldLife"])])
	(ui["perf"] as Label).text = CalibUi.Tr.t("Rendimiento: calibrando...")
	(ui["quality"] as Label).text = "%s %s" % [CalibUi.Tr.t("Calidad visual:"), CalibUi.Tr.t(str(P["n"]))]

## Terminó de medir: la pantalla de elección con la recomendada marcada y los FPS de lo medido; lo que elija el jugador queda guardado
func _finish() -> void:
	state = "done"
	if _kept.has("worldLife"):
		race.profile.d["settings"]["worldLife"] = _kept["worldLife"] # (lo que se elija decide; la 60 FPS lo apaga al guardarse si hizo falta)
	result = searcher.result()
	var rec: int = int(result["rec"])
	var info := Autotune.preset_info(result)
	CrashLog.mark("calib", "recomendada %s · 60 FPS a escala %.2f · %s" % [str(Autotune.PRESETS[rec]["n"]), float(result["k60"]), str(info)])
	(ui["root"] as Control).queue_free()
	CalibUi.pick(layer, Autotune.presets_for(result), rec, func(i: int) -> void:
		Autotune.save_preset(race.profile, i, result)
		race.exit_requested.emit(back), info, true, Callable(), Autotune.preset_order(rec))

## Resolución del mundo 3D de la calidad r (pantalla × escala 3D)
func _res_of(r: int) -> Vector2i:
	var k: float = searcher.res_of(r)
	var scr := Vector2(DisplayServer.window_get_size())
	return Vector2i(int(round(scr.x * k)), int(round(scr.y * k)))
