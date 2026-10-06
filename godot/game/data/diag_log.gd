extends RefCounted
## Registro MANUAL de rendimiento (menú «Diagnóstico»): el juego sólo anota lo que el jugador hace y los FPS que midió; no prueba nada solo.
## Una SESIÓN por escena (mundo abierto, cada carrera…): las anteriores no se borran (quedan en user://diag_log.json y sobreviven al cierre de la app).
## Una PRUEBA es lo que se anota con «📸 CAPTURAR»: las condiciones (interruptores, clima, hora, zona) + FPS promedio y mínimo medidos desde el último cambio o captura.
## De cada prueba se calcula la diferencia con la anterior, y al exportar se arma un resumen de impactos («Árboles: +8 FPS al desactivarlos») con las pruebas
## consecutivas en las que cambió una sola cosa. Todo es estático: lo ven el panel del juego y la pantalla del menú.

const PATH := "user://diag_log.json"
const MAX_SESSIONS := 40
const MAX_EVENTS := 700

## Interruptores del mundo (clave, nombre, qué apaga exactamente: va en el texto exportado para que se sepa qué se midió)
const SWITCHES := [
	["trees", "Árboles", "los árboles de imagen de las calles y las rutas (y su choque)"],
	["buildings", "Edificios", "las fachadas de los edificios (la pared invisible de la calle sigue)"],
	["cars", "Autos civiles", "el tránsito y los autos estacionados (sistemas «traffic» y «parked» de la vida del mundo, apagados de verdad)"],
	["veg", "Vegetación", "flores, arbustos y pasto de las calles y el bosque lejano del horizonte"],
	["decor", "Decoración", "farolas, semáforos, bolardos, vallas y carteles de la calle (con sus luces de noche)"],
	["peds", "Peatones", "los peatones (sistema «peds» de la vida del mundo, apagado de verdad)"],
	["asphalt", "Asfalto", "la calzada de las calles pavimentadas (los cuadriláteros de asfalto de cada tramo, con la textura asphalt.png); las veredas, los cordones y las marcas viales son otras cosas y NO se apagan; tampoco el disco de asfalto de la plaza de drift"],
	["dirt", "Caminos de tierra", "la banquina de tierra (beige) al costado de las rutas rurales: en la ciudad no hay caminos de tierra como malla propia, lo único de tierra transitable es esa banquina; la calzada, el césped y las veredas de calle NO se apagan"],
	["terrain", "Terreno / césped", "la malla del terreno natural de cada cuadra (grilla de 16 m, 200 triángulos por cuadra); queda el plano de suelo lejano (color de la lejanía) y el mar; la vegetación NO se apaga"],
	["fog", "Niebla", "la niebla del mundo (la de siempre, sin cambiar su color ni sus distancias); apagada se ve todo hasta el horizonte"],
	["horizon", "Horizonte / montañas", "las lomas del horizonte (72 triángulos) y los dos anillos del bosque lejano; el cielo, el plano de suelo, el mar y la cámara NO se tocan"],
]

static var sessions: Array = []
static var cur: Dictionary = {}
static var _t0_ms := 0
static var _loaded := false

# ───────────────────────── sesiones y eventos ─────────────────────────
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Array:
		sessions = parsed

static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(sessions))
		f.close()

static func now_s() -> float:
	return float(Time.get_ticks_msec() - _t0_ms) / 1000.0

## Empieza una sesión nueva (al entrar a otra escena). Devuelve su número.
static func begin_session(scene: String, circuit: String, cond: Dictionary) -> int:
	ensure_loaded()
	_t0_ms = Time.get_ticks_msec()
	var n := 1
	for s in sessions:
		n = maxi(n, int((s as Dictionary).get("n", 0)) + 1)
	cur = {"n": n, "scene": scene, "circuit": circuit, "date": Time.get_datetime_string_from_system(false, true), "ev": [], "tests": [], "cond": cond.duplicate()}
	sessions.append(cur)
	while sessions.size() > MAX_SESSIONS:
		sessions.pop_front()
	event("inicio", _cond_text(cond), -1)
	save()
	return n

## Las condiciones del arranque se conocen recién cuando el mundo ya empezó a andar (la hora del mundo, el clima): se corrige el renglón de INICIO
static func refresh_start(cond: Dictionary) -> void:
	if cur.is_empty():
		return
	cur["cond"] = cond.duplicate()
	var ev: Array = cur["ev"]
	if not ev.is_empty() and str((ev[0] as Array)[1]) == "inicio":
		(ev[0] as Array)[2] = _cond_text(cond)

static func event(kind: String, text: String, fps: int) -> void:
	if cur.is_empty():
		return
	var ev: Array = cur["ev"]
	ev.append([snappedf(now_s(), 0.1), kind, text, fps])
	if ev.size() > MAX_EVENTS: # el historial no crece sin límite: se van los renglones de FPS más viejos
		for i in ev.size():
			if str((ev[i] as Array)[1]) == "fps":
				ev.remove_at(i)
				break

## El jugador cambió algo: queda anotado y las condiciones nuevas pasan a ser las de la sesión
static func change(label: String, cond: Dictionary, fps: int) -> void:
	if cur.is_empty():
		return
	cur["cond"] = cond.duplicate()
	event("cambio", label, fps)
	save()

## Anota una prueba. avg/mn: FPS promedio y mínimo medidos; n: cantidad de muestras; secs: cuánto duró la medición. Devuelve la prueba (con su diferencia con la anterior)
static func add_test(cond: Dictionary, avg: float, mn: float, n: int, secs: float) -> Dictionary:
	if cur.is_empty():
		return {}
	var tests: Array = cur["tests"]
	var t := {"n": tests.size() + 1, "t": snappedf(now_s(), 0.1), "cond": cond.duplicate(), "avg": snappedf(avg, 0.1), "min": snappedf(mn, 0.1), "samples": n, "secs": snappedf(secs, 0.1)}
	if not tests.is_empty():
		var prev: Dictionary = tests[tests.size() - 1]
		t["d_avg"] = snappedf(avg - float(prev["avg"]), 0.1)
		t["d_min"] = snappedf(mn - float(prev["min"]), 0.1)
		t["diff"] = diff_keys(prev["cond"], cond)
	tests.append(t)
	event("captura", "PRUEBA %d · prom %d · mín %d" % [int(t["n"]), int(round(avg)), int(round(mn))], int(round(avg)))
	save()
	return t

static func clear_all() -> void:
	sessions = []
	cur = {}
	save()

static func test_count() -> int:
	ensure_loaded()
	var n := 0
	for s in sessions:
		n += ((s as Dictionary)["tests"] as Array).size()
	return n

# ───────────────────────── condiciones ─────────────────────────
## Claves que cuentan para comparar dos pruebas (la ubicación fina, «where», sólo se muestra)
const CMP_KEYS := ["trees", "buildings", "cars", "veg", "decor", "peds", "asphalt", "dirt", "terrain", "fog", "horizon", "paper", "weather", "time", "zone", "surface", "res"]
const KEY_NAMES := {"trees": "Árboles", "buildings": "Edificios", "cars": "Autos civiles", "veg": "Vegetación", "decor": "Decoración", "peds": "Peatones", "asphalt": "Asfalto", "dirt": "Caminos de tierra", "terrain": "Terreno / césped", "fog": "Niebla", "horizon": "Horizonte / montañas", "paper": "Paper shader", "weather": "Clima", "time": "Hora", "zone": "Zona", "surface": "Superficie", "res": "Escala 3D"}

static func onoff(b) -> String:
	return "ON" if bool(b) else "OFF"

static func diff_keys(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in CMP_KEYS:
		if a.get(k) != b.get(k):
			out.append(k)
	return out

static func _val_text(k: String, v) -> String:
	if v is bool:
		return onoff(v)
	return str(v)

static func _cond_text(c: Dictionary) -> String:
	var parts: Array = []
	for sw in SWITCHES:
		if c.has(sw[0]):
			parts.append("%s %s" % [sw[1], onoff(c[sw[0]])])
	parts.append("Clima %s" % str(c.get("weather", "?")))
	if c.has("paper"):
		parts.append("Paper %s" % str(c["paper"]))
	parts.append("Hora %s" % str(c.get("time", "?")))
	parts.append("Escala 3D %s" % str(c.get("res", "?")))
	return " · ".join(parts)

static func _diff_text(prev: Dictionary, now: Dictionary, keys: Array) -> String:
	var parts: Array = []
	for k in keys:
		var nm: String = KEY_NAMES.get(k, k)
		if now.get(k) is bool:
			parts.append("%s %s" % [nm, onoff(now[k])])
		else:
			parts.append("%s %s → %s" % [nm, _val_text(k, prev.get(k)), _val_text(k, now.get(k))])
	return ", ".join(parts)

static func _sgn(v: float) -> String:
	return ("+%d" % int(round(v))) if v >= 0.0 else ("%d" % int(round(v)))

static func mmss(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]

# ───────────────────────── dispositivo ─────────────────────────
static func device_text() -> String:
	var model := OS.get_model_name()
	if model == "" or model == "GenericDevice":
		model = "(modelo no disponible)"
	var win := DisplayServer.window_get_size()
	var gpu := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	return "DISPOSITIVO: %s · %s %s\nGPU: %s%s\nMOTOR: Godot %s · %s · pantalla %dx%d · %d núcleos" % [
		model, OS.get_name(), OS.get_version(), gpu if gpu != "" else "(no disponible)", (" (" + vendor + ")") if vendor != "" else "",
		Engine.get_version_info()["string"], str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), win.x, win.y, OS.get_processor_count()]

# ───────────────────────── texto para pegar ─────────────────────────
static func export_text() -> String:
	ensure_loaded()
	var L: Array = []
	L.append("================================")
	L.append("DIAGNÓSTICO DE RENDIMIENTO")
	L.append("================================")
	L.append(device_text())
	L.append("")
	L.append("QUÉ APAGA CADA INTERRUPTOR:")
	for sw in SWITCHES:
		L.append("- %s: %s" % [sw[1], sw[2]])
	L.append("- ESCALA 3D: resolución a la que se dibuja el mundo 3D = pantalla × escala (0.80 = 80 %). El HUD y la ventana no cambian. AUTO = la ajusta el juego solo.")
	L.append("- PAPER SHADER: ORIGINAL = paper.gdshader como siempre · SIMPLE = variante de prueba sin normal por derivadas, sin líneas de borde, sin variación de tono por lote y con los pow() y las coordenadas de textura en el vértice (sólo materiales de papel del mundo abierto: terreno, calles, marcas, objetos; las fachadas, los árboles, el horizonte, las señales y los peatones no cambian)")
	L.append("(el promedio y el mínimo se miden en tramos de 0,5 s, desde el último cambio o captura, sin contar los 2 s siguientes a un cambio)")
	if sessions.is_empty():
		L.append("")
		L.append("(todavía no hay sesiones)")
	for s in sessions:
		_session_text(s as Dictionary, L)
	L.append("")
	L.append("================================")
	return "\n".join(L)

static func _session_text(s: Dictionary, L: Array) -> void:
	L.append("")
	L.append("--- SESIÓN %d ---" % int(s["n"]))
	L.append("ESCENA: %s" % str(s["scene"]))
	if str(s["circuit"]) != "":
		L.append("CIRCUITO: %s" % str(s["circuit"]))
	L.append("Inicio: %s" % str(s["date"]))
	var tests: Array = s["tests"]
	var base: Dictionary = {}
	for t in tests:
		var td := t as Dictionary
		var c: Dictionary = td["cond"]
		L.append("")
		L.append("PRUEBA %d  (a los %s)" % [int(td["n"]), mmss(float(td["t"]))])
		L.append("Ubicación: %s" % str(c.get("where", "?")))
		L.append("Zona: %s · Superficie: %s" % [str(c.get("zone", "?")), str(c.get("surface", "?"))])
		L.append("Clima: %s" % str(c.get("weather", "?")))
		L.append("Hora: %s" % str(c.get("time", "?")))
		if c.has("paper"):
			L.append("PAPER: %s" % str(c["paper"]))
		L.append("ESCALA 3D: %s  (%s)" % [str(c.get("res", "(no registrada)")), str(c.get("res_px", "?"))])
		L.append("")
		for sw in SWITCHES:
			if c.has(sw[0]):
				L.append("%s: %s" % [sw[1], onoff(c[sw[0]])])
		if c.has("trees"):
			L.append("Cielo: ON (sin interruptor: queda igual en toda la ronda)")
		L.append("")
		L.append("FPS promedio: %d" % int(round(float(td["avg"]))))
		L.append("FPS mínimo: %d" % int(round(float(td["min"]))))
		L.append("(%d mediciones · %d s)" % [int(td["samples"]), int(round(float(td["secs"])))])
		if td.has("diff"):
			var prev: Dictionary = (tests[int(td["n"]) - 2] as Dictionary)["cond"]
			var dk: Array = td["diff"]
			L.append("")
			L.append("CAMBIO RESPECTO A LA PRUEBA ANTERIOR: %s" % (_diff_text(prev, c, dk) if not dk.is_empty() else "(mismas condiciones)"))
			L.append("DIFERENCIA: %s FPS promedio · %s FPS mínimo" % [_sgn(float(td["d_avg"])), _sgn(float(td["d_min"]))])
		if base.is_empty():
			base = td
		elif int(td["n"]) > 2 and _same_scene_cond(base["cond"], c):
			L.append("RESPECTO A LA PRUEBA 1 (BASE): %s FPS promedio · %s FPS mínimo" % [_sgn(float(td["avg"]) - float(base["avg"])), _sgn(float(td["min"]) - float(base["min"]))])
	var imp := _impacts(tests)
	if not imp.is_empty():
		L.append("")
		L.append("RESUMEN DE IMPACTOS (pruebas seguidas en las que cambió UNA sola cosa):")
		for l in imp:
			L.append("- " + str(l))
	L.append("")
	L.append("HISTORIAL (cronológico):")
	for e in s["ev"]:
		var ea := e as Array
		var line := "%s  " % mmss(float(ea[0]))
		match str(ea[1]):
			"cambio":
				line += "[CAMBIO] %s" % str(ea[2])
			"captura":
				line += "[CAPTURA] %s" % str(ea[2])
			"zona":
				line += "[ZONA] %s" % str(ea[2])
			"inicio":
				line += "INICIO · %s" % str(ea[2])
			_:
				line += "FPS %d" % int(ea[3])
		if str(ea[1]) in ["cambio", "inicio"] and int(ea[3]) >= 0:
			line += "  (FPS antes: %d)" % int(ea[3])
		L.append(line)

## Las mismas condiciones de escena (zona, clima, hora, superficie): sólo difieren interruptores
static func _same_scene_cond(a: Dictionary, b: Dictionary) -> bool:
	for k in ["weather", "time", "zone", "surface"]:
		if a.get(k) != b.get(k):
			return false
	return true

static func _impacts(tests: Array) -> Array:
	var out: Array = []
	for i in range(1, tests.size()):
		var td: Dictionary = tests[i]
		var dk: Array = td.get("diff", [])
		if dk.size() != 1:
			continue
		var k: String = dk[0]
		var prev: Dictionary = (tests[i - 1] as Dictionary)["cond"]
		var c: Dictionary = td["cond"]
		var da := float(td["d_avg"])
		var dm := float(td["d_min"])
		var what := ""
		if c.get(k) is bool:
			what = "al %s" % ("activarlos" if bool(c[k]) else "desactivarlos")
		else:
			what = "al pasar de %s a %s" % [_val_text(k, prev.get(k)), _val_text(k, c.get(k))]
		out.append("%s: %s FPS promedio (%s mínimo) %s  [pruebas %d → %d]" % [str(KEY_NAMES.get(k, k)).to_upper(), _sgn(da), _sgn(dm), what, i, i + 1])
	return out
