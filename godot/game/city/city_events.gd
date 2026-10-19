extends RefCounted
## Carreras del mundo abierto (docs/CARRERAS_MUNDO_ABIERTO.md). Los eventos salen de world/ow_events.gd (tramos de calles que ya existen); acá se descubren, se largan y se corren.
##  · Descubrir: pasar a menos de FIND_R de la largada lo anota para siempre (profile.d["owEvents"]) y aparece en el mapa; la primera vez sale una presentación corta.
##  · Largar: frenar adentro del círculo de largada (sin la policía encima). Cuenta regresiva, rivales con piloto automático (ai/police_driver.gd en modo «path»).
##  · Correr: recorrido marcado (GPS y columna en el próximo punto de control); salirse más de OFF_R durante OFF_T s lo anula.
##  · Premio: profile.earn(…, "owev", id) — la cuenta del servidor lo valida y lo topa; repetir un evento ganado paga REPEAT_K (no se hace plata infinita).
## Los rivales se adaptan: si les ganás, la próxima vez van más rápido; si perdés, un poco más lento (pace por evento).
## Sin conexión solamente (en el mundo online los premios los dará el servidor; ver docs/ECONOMIA_ONLINE.md).

const OW := preload("res://game/world/ow_events.gd")
const CityGps := preload("res://game/city/city_gps.gd")
const PoliceDriver := preload("res://game/ai/police_driver.gd")
const AiCars := preload("res://game/data/ai_cars.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const ClassRecords := preload("res://game/online/class_records.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CrashLog := preload("res://game/diag/crash_log.gd")
const Daily := preload("res://game/data/daily.gd")

const FIND_R := 90.0
const MARK_R := 450.0
const START_R := 12.0
const OFF_R := 70.0
const OFF_T := 6.0
const REPEAT_K := 0.35
## Un resultado que NO es victoria (2.º puesto, plata, bronce) paga entero sólo en el primer intento; desde el segundo, × LOSE_K (fase 4, 16/10/2026).
## Antes pagaba entero siempre: salir 2.º (45 %) o sacar plata (60 %) a propósito rendía MÁS que ganar repetido (35 %) — medido con
## tools/econ/progression_sim.py: la «granja de plata» daba $45.000/h, la actividad más rentable del juego. Con 0,55: 2.º 25 %, plata 33 % (< 35 %).
const LOSE_K := 0.55
const COOLDOWN := 90.0
const PLACE_K := [1.0, 0.45, 0.25, 0.1]
const MEDAL_K := [1.0, 0.6, 0.35]

var race
var track
var active := false
var events: Array = []
var _cells := {} # Vector2i (1 km) -> índices
var state := "free" # free · countdown · run · done
var cur := {} # evento en curso
var ev_i := -1
var t := 0.0
var cd := 0.0
var rivals: Array = [] # {car, drv, arc, done, time}
var arc := 0.0 # metros recorridos del jugador
var _pi := 0 # índice del punto más cercano del recorrido (jugador)
var _cum := PackedFloat32Array()
var _off_t := 0.0
var _stop_t := 0.0
var _near_t := 0.0
var _marks := {} # id → Node3D
var _gate: Node3D
var _cool := {}
var _result := {}
var _done_t := 0.0
var _catch_t := 0.0
var _arrests0 := 0
var _hud: CanvasLayer
var _hud_l: Label
var _banner: Label
var _banner_t := 0.0

func setup(p_race) -> void:
	race = p_race
	track = race.track
	if race.profile == null or race.cfg.get("online", false) == true or race.cfg.get("testCar") != null or race.cfg.get("owEvents", true) == false:
		return
	events = OW.build(track.get("region"), CityGps.new(track.city))
	for i in events.size():
		var s: Vector2 = events[i]["start"]
		var c := Vector2i(floori(s.x / 1000.0), floori(s.y / 1000.0))
		if not _cells.has(c):
			_cells[c] = []
		(_cells[c] as Array).append(i)
	active = not events.is_empty()
	_build_hud()
	_refresh_map()

func _saved() -> Dictionary:
	if not (race.profile.d.get("owEvents") is Dictionary):
		race.profile.d["owEvents"] = {}
	return race.profile.d["owEvents"]

func _rec(id: String) -> Dictionary:
	var sv := _saved()
	if not (sv.get(id) is Dictionary):
		sv[id] = {}
	return sv[id]

func found(id: String) -> bool:
	return (_saved().get(id, {}) as Dictionary).get("found", false) == true

func busy() -> bool:
	return state != "free"

func _near_events(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(floori(p.x / 1000.0), floori(p.y / 1000.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for i in _cells.get(c0 + Vector2i(dx, dz), []):
				if (events[i]["start"] as Vector2).distance_to(p) < r:
					out.append(i)
	return out

func update(dt: float) -> void:
	if not active or race.cars.is_empty():
		return
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var sp := sqrt(me.vx * me.vx + me.vz * me.vz)
	_banner_t -= dt
	if _banner != null:
		_banner.visible = _banner_t > 0.0
	match state:
		"free":
			_free(dt, p, sp)
		"countdown":
			cd -= dt
			me.vx *= 0.5
			me.vz *= 0.5
			_hud_l.text = "%s %s · %d" % [cur["icon"], _title(cur), int(ceil(cd))] if cd > 0.0 else Tr.t("¡YA!")
			if cd <= 0.0:
				_go()
		"run":
			_run(dt, p, sp)
		"done":
			_done_t -= dt
			if _done_t <= 0.0:
				_end()
	_hud.visible = state != "free"

# ───────────────────────── libre: descubrir y largar
func _free(dt: float, p: Vector2, sp: float) -> void:
	_near_t -= dt
	if _near_t > 0.0:
		return
	_near_t = 0.2
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - 0.2
		if float(_cool[k]) <= 0.0:
			_cool.erase(k)
	var near := _near_events(p, MARK_R)
	# marcas: sólo las cercanas existen
	var want := {}
	for i in near:
		want[str(events[i]["id"])] = i
	for id in _marks.keys():
		if not want.has(id):
			if is_instance_valid(_marks[id]):
				(_marks[id] as Node).queue_free()
			_marks.erase(id)
	for id in want:
		if not _marks.has(id):
			_marks[id] = _mark_node(events[want[id]])
	for i in near:
		var ev: Dictionary = events[i]
		var d: float = (ev["start"] as Vector2).distance_to(p)
		if d < FIND_R and not found(str(ev["id"])):
			_discover(ev)
		if d < START_R and sp < 2.0 and not _cool.has(str(ev["id"])):
			var pol = race.get("police")
			if pol != null and pol.state == "chase":
				_toast(Tr.t("Con la policía encima no se puede largar"))
				_cool[str(ev["id"])] = 6.0
				return
			_stop_t += 0.2
			if _stop_t >= 0.8:
				_stop_t = 0.0
				_begin(i)
			return
	_stop_t = 0.0

func _discover(ev: Dictionary) -> void:
	var r := _rec(str(ev["id"]))
	r["found"] = true
	r["title"] = _title(ev) # (el desafío del día la nombra)
	race.profile.progress("owev:" + str(ev["id"])) # queda en la cuenta: al reinstalar sigue descubierta
	race.profile.save()
	_refresh_map()
	var extra := ""
	if ev.has("gold"):
		extra = " · " + Tr.t("oro %s") % _fmt(float(ev["gold"]))
	_show_banner("%s %s\n%s · %s%s · %s\n%s" % [ev["icon"], Tr.t("¡CARRERA DESCUBIERTA!"), _title(ev), _km(float(ev["len"])) if float(ev["len"]) > 0.0 else Tr.t("%d s") % int(ev.get("time", 90.0)),
		extra, Tr.t("premio $%d") % int(ev["reward"]), Tr.t("Frená en el círculo de largada para correr")], 5.5)
	CrashLog.mark("evento", "descubierto %s" % ev["id"])

# ───────────────────────── largada
func _begin(i: int) -> void:
	ev_i = i
	cur = events[i]
	var pol = race.get("police")
	if pol != null:
		pol.suspended = cur["type"] != "huida"
	var pts: PackedVector2Array = cur["pts"]
	_cum = PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		_cum.append(_cum[k - 1] + pts[k - 1].distance_to(pts[k]))
	var me = race.cars[0]
	var yaw: float = cur["yaw"]
	var s0: Vector2 = cur["start"]
	if str(cur["type"]) != "huida":
		me.place(s0.x, s0.y, yaw)
		me.restart_history(race.sim_t)
	_spawn_rivals()
	_pi = 0
	arc = 0.0
	t = 0.0
	_off_t = 0.0
	_catch_t = 0.0
	_arrests0 = int(pol.stats["arrests"]) if pol != null else 0
	cd = 3.0 if str(cur["type"]) != "huida" else 0.6
	state = "countdown"
	var ch = _ch()
	if ch != null and pts.size() > 1 and str(cur["type"]) != "huida":
		ch.set_dest(pts[pts.size() - 1], _title(cur))
	for id in _marks.keys():
		if is_instance_valid(_marks[id]):
			(_marks[id] as Node).queue_free()
	_marks.clear()
	_banner_t = 0.0
	var md = race.get("modes")
	if md != null and md.has_method("on_ow_start"):
		md.on_ow_start(str(cur["id"])) # (si es la carrera de la semana, el intento se anota en el servidor)
	CrashLog.mark("evento", "largada %s" % cur["id"])

func _spawn_rivals() -> void:
	rivals.clear()
	var n := int(cur["rivals"])
	if n <= 0:
		return
	var pts: PackedVector2Array = cur["pts"]
	var dir := (pts[1] - pts[0]).normalized()
	var lat := Vector2(dir.y, -dir.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(cur["id"])) + int(_rec(str(cur["id"])).get("runs", 0))
	var pi_me := 600 # rivales parecidos a tu auto (índice de rendimiento)
	var cid := str(race.cfg.get("car", ""))
	if race.vehicles.has(cid) and race.cfg.get("state") is Dictionary:
		pi_me = int(CarBuild.perf_of(CarBuild.build_params(race.vehicles[cid], race.cfg["state"]))["pi"])
	var picks := AiCars.pick(race.vehicles, n, pi_me + 20, "", "asphalt", rng)
	var pace := float(_rec(str(cur["id"])).get("pace", 0.93 + 0.07 * float(cur["tier"])))
	for k in picks.size():
		var vid := str(picks[k]["id"])
		var q: Vector2
		var yaw := atan2(dir.x, dir.y)
		match str(cur["type"]):
			"picada":
				q = pts[0] + lat * 2.6
			"persecucion":
				q = _at(110.0) # el que se escapa sale 110 m adelante
			_:
				q = pts[0] + dir * (8.0 + 7.0 * float(k)) + lat * (2.2 if k % 2 == 0 else -2.2)
		var drv := PoliceDriver.new()
		drv.mode = "parked"
		drv.path = pts
		drv.grip = 1.0
		drv.pace = pace if str(cur["type"]) != "persecucion" else minf(pace + 0.04, 1.08)
		drv.errors = str(cur["type"]) != "picada"
		var car = race.add_ai_car(vid, q.x, q.y, yaw, drv, Color(str(picks[k]["state"]["paint"]["body"])))
		if car != null:
			rivals.append({"car": car, "drv": drv, "arc": 0.0, "pi": 0, "done": false, "time": 0.0})

func _go() -> void:
	state = "run"
	t = 0.0
	for r in rivals:
		r["drv"].mode = "path"
	if str(cur["type"]) == "huida":
		var pol = race.get("police")
		if pol != null:
			pol.event_chase(race.cars[0].phys, 1 + int(float(cur["tier"]) * 2.0))

# ───────────────────────── carrera
func _run(dt: float, p: Vector2, sp: float) -> void:
	t += dt
	var typ := str(cur["type"])
	var pts: PackedVector2Array = cur["pts"]
	var total := float(cur["len"]) if typ != "circuito" else float(cur["lap_len"]) * float(cur["laps"])
	if typ == "huida":
		var pol = race.get("police")
		if pol == null or int(pol.stats["arrests"]) > _arrests0:
			_finish(false, Tr.t("Te agarraron"))
			return
		if t >= float(cur["time"]) or pol.state != "chase":
			_finish(true, Tr.t("¡Aguantaste!"))
			return
		_hud_l.text = "%s %s · %s / %s" % [cur["icon"], Tr.t("Huida"), _fmt(t), _fmt(float(cur["time"]))]
		return
	# avance del jugador sobre el recorrido (para circuitos, vuelta por vuelta)
	var proj := _project(p, _pi)
	_pi = int(proj[0])
	var lap_len := float(cur.get("lap_len", total))
	var lap_base := floorf(arc / lap_len) * lap_len if typ == "circuito" else 0.0
	var a := lap_base + float(proj[1])
	if typ == "circuito" and a < arc - lap_len * 0.5:
		a += lap_len # cruzó la línea: vuelta nueva
	if a > arc and a - arc < 120.0:
		arc = a
	if float(proj[2]) > OFF_R:
		_off_t += dt
		if _off_t > OFF_T:
			_finish(false, Tr.t("Te saliste del recorrido"))
			return
	else:
		_off_t = 0.0
	# rivales
	var ahead := 0
	for r in rivals:
		var rp := Vector2(r["car"].phys.px, r["car"].phys.pz)
		var pr := _project(rp, int(r["pi"]))
		r["pi"] = int(pr[0])
		var ra := float(pr[1])
		if typ == "circuito":
			var rb := floorf(float(r["arc"]) / lap_len) * lap_len
			ra += rb
			if ra < float(r["arc"]) - lap_len * 0.5:
				ra += lap_len
			if r["drv"].idx >= pts.size() - 2 and float(r["arc"]) < lap_len * (float(cur["laps"]) - 1.0):
				r["drv"].idx = 0 # el camino de un circuito es una vuelta: vuelve a empezar
		if ra > float(r["arc"]) and ra - float(r["arc"]) < 150.0:
			r["arc"] = ra
		if not r["done"] and float(r["arc"]) >= total - 6.0:
			r["done"] = true
			r["time"] = t
		if float(r["arc"]) > arc:
			ahead += 1
	var pos := 1 + ahead
	# llegada
	match typ:
		"persecucion":
			var fug = rivals[0]["car"].phys if not rivals.is_empty() else null
			if fug != null:
				var d := Vector2(fug.px, fug.pz).distance_to(p)
				_catch_t = _catch_t + dt if d < 9.0 else maxf(0.0, _catch_t - dt)
				if _catch_t >= 1.5:
					_finish(true, Tr.t("¡Lo alcanzaste!"))
					return
				if rivals[0]["done"]:
					_finish(false, Tr.t("Llegó a destino: se te escapó"))
					return
				_hud_l.text = "%s %s · %d m · %s" % [cur["icon"], Tr.t("Persecución"), int(d), _fmt(t)]
		_:
			if arc >= total - 6.0:
				_finish(true, "")
				return
			var left := maxf(0.0, total - arc)
			var lap_txt := (" · " + Tr.t("vuelta %d/%d") % [mini(int(arc / lap_len) + 1, int(cur["laps"])), int(cur["laps"])]) if typ == "circuito" else ""
			var pos_txt := (" · %d/%d" % [pos, rivals.size() + 1]) if not rivals.is_empty() else ""
			var avg := (" · " + Tr.t("promedio %d km/h") % int(arc / maxf(t, 0.1) * 3.6)) if typ == "velocidad" else ""
			_hud_l.text = "%s %s%s%s · %s · %s%s" % [cur["icon"], _title(cur), pos_txt, lap_txt, _fmt(t), _km(left), avg]
	# tiempo de más: se anula
	var limit := float(cur.get("bronze", total / 9.0)) * 1.8 + 30.0
	if t > limit:
		_finish(false, Tr.t("Se terminó el tiempo"))
		return
	_gate_update(typ)

## Punto del recorrido más cercano (mirando cerca del anterior): [índice, metros desde la largada, distancia al recorrido]
func _project(p: Vector2, i0: int) -> Array:
	var pts: PackedVector2Array = cur["pts"]
	var best := 1e18
	var bi := i0
	var bt := 0.0
	var lo := maxi(0, i0 - 4)
	var hi := mini(pts.size() - 2, i0 + 30)
	for i in range(lo, hi + 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := p.distance_squared_to(a + ab * tt)
		if d < best:
			best = d
			bi = i
			bt = tt
	if sqrt(best) > 150.0 and hi - lo < pts.size() - 2: # perdido: busca en todo el recorrido
		lo = 0
		hi = pts.size() - 2
		for i in range(lo, hi + 1):
			var a2 := pts[i]
			var ab2 := pts[i + 1] - a2
			var tt2 := clampf((p - a2).dot(ab2) / maxf(ab2.length_squared(), 1e-6), 0.0, 1.0)
			var d2 := p.distance_squared_to(a2 + ab2 * tt2)
			if d2 < best:
				best = d2
				bi = i
				bt = tt2
	return [bi, _cum[bi] + (_cum[bi + 1] - _cum[bi]) * bt, sqrt(best)]

func _at(s: float) -> Vector2:
	var pts: PackedVector2Array = cur["pts"]
	for i in range(1, _cum.size()):
		if _cum[i] >= s:
			return pts[i - 1].lerp(pts[i], (s - _cum[i - 1]) / maxf(_cum[i] - _cum[i - 1], 0.01))
	return pts[pts.size() - 1]

# ───────────────────────── resultado y premio
## Multiplicador del premio: 1.ª victoria 100 %; victoria repetida REPEAT_K; no-victoria 100 % en el 1.er intento y LOSE_K después (runs = intentos, éste incluido)
static func pay_mult(won: bool, first_win: bool, runs: int) -> float:
	if won:
		return 1.0 if first_win else REPEAT_K
	return 1.0 if runs <= 1 else LOSE_K

func _finish(ok: bool, why: String) -> void:
	var typ := str(cur["type"])
	var id := str(cur["id"])
	var r := _rec(id)
	r["runs"] = int(r.get("runs", 0)) + 1
	var reward := 0
	var title := why
	var k := 0.0
	var won := false
	var first := false
	if ok:
		match typ:
			"rally", "montana":
				var medal := 0 if t <= float(cur["gold"]) else (1 if t <= float(cur["silver"]) else (2 if t <= float(cur["bronze"]) else 3))
				k = MEDAL_K[medal] if medal < 3 else 0.0
				title = ["🥇 " + Tr.t("¡ORO!"), "🥈 " + Tr.t("PLATA"), "🥉 " + Tr.t("BRONCE"), Tr.t("Sin medalla")][medal] + " · " + _fmt(t)
				won = medal == 0
				if not r.has("best") or t < float(r["best"]):
					r["best"] = t
			"velocidad":
				var avg := float(cur["len"]) / maxf(t, 0.1)
				var sp: Array = cur["speed"]
				var m2 := 0 if avg >= float(sp[0]) else (1 if avg >= float(sp[1]) else (2 if avg >= float(sp[2]) else 3))
				k = MEDAL_K[m2] if m2 < 3 else 0.0
				title = ["🥇", "🥈", "🥉", ""][m2] + " " + Tr.t("promedio %d km/h") % int(avg * 3.6)
				won = m2 == 0
			"huida", "persecucion":
				k = 1.0
				won = true
				title = why
			_:
				var pos := 1
				for rv in rivals:
					if rv["done"] and float(rv["time"]) < t:
						pos += 1
				k = PLACE_K[mini(pos - 1, PLACE_K.size() - 1)]
				won = pos == 1
				title = (Tr.t("🏆 ¡GANASTE!") if won else Tr.t("Llegaste %dº") % pos) + " · " + _fmt(t)
				if won and (not r.has("best") or t < float(r["best"])):
					r["best"] = t
		first = int(r.get("wins", 0)) == 0
		reward = int(round(float(cur["reward"]) * k * pay_mult(won, first, int(r["runs"])) / 10.0) * 10.0)
		if won:
			r["wins"] = int(r.get("wins", 0)) + 1
	# rivales adaptables: ganaste → la próxima van más rápido; perdiste → un poco más lento
	var pace := float(r.get("pace", 0.93 + 0.07 * float(cur["tier"])))
	r["pace"] = clampf(pace + (0.03 if won else -0.03), 0.85, 1.08)
	# el progreso viaja con el premio a la cuenta (victorias, mejor tiempo); la primera victoria avisa cuánto sería repetida: si la cuenta ya la tenía
	# (reinstalación, otro teléfono) el servidor paga eso (migración 20261022)
	var ex := {"w": int(r.get("wins", 0))}
	if r.has("best"):
		ex["b"] = float(r["best"])
	if reward > 0:
		if won and first:
			ex["first"] = true
			ex["rep"] = int(round(float(cur["reward"]) * k * REPEAT_K / 10.0) * 10.0)
		race.profile.earn(float(reward), "owev", id, ex)
		race.profile.add_xp(float(reward) * 0.2)
	elif ok:
		race.profile.progress("owev:" + id, ex)
	r["title"] = _title(cur) # (para la pantalla de ranking del menú)
	if ok:
		Daily.note(race.profile.d, "play", won, id) # desafío del día (fase 5)
	if ok and typ != "huida" and typ != "persecucion":
		_send_record(id, t)
	var md = race.get("modes")
	if md != null and md.has_method("on_ow_finish"):
		md.on_ow_finish(id, ok and typ != "huida" and typ != "persecucion", t)
	race.profile.save()
	_result = {"ok": ok, "won": won}
	_show_banner("%s %s\n%s%s" % [cur["icon"], _title(cur), title, ("\n+ $%d" % reward) if reward > 0 else ""], 4.5)
	state = "done"
	_done_t = 3.0
	_cool[id] = COOLDOWN
	CrashLog.mark("evento", "fin %s · %s · $%d" % [id, "ok" if ok else why, reward])

## Récord mundial (ranking por datos, 15/10/2026): se manda el tiempo y se avisa si es el mejor del mundo o cuál es el récord a batir
func _send_record(id: String, secs: float) -> void:
	if race.cfg.get("events", false) != true:
		return # (19/10/2026, pedido del dueño: el ranking es del modo online; las carreras del mundo abierto offline no mandan récords)
	var on = race.get("online")
	if on == null or not on.has_method("enabled") or not on.enabled() or not on.has_method("submit_record"):
		return
	var res: Dictionary
	var cls := ""
	if on.has_method("submit_class"): # récords por clase (fase 3): se compite contra autos de la misma clase
		var car := str(race.cfg.get("car", ""))
		var e := ClassRecords.meta(race.vehicles.get(car, {}), race.cfg.get("state", {}) if race.cfg.get("state") is Dictionary else {}, str(race.cfg.get("sim", "")))
		e.merge({"board": "owev", "track": id, "value": secs, "car": car})
		cls = str(e["cls"])
		res = await on.submit_class(e)
		if bool(res.get("queued", false)):
			_toast(Tr.t("📶 Sin conexión: tu tiempo se manda solo cuando vuelva la red"))
			return
		if bool(res.get("legacy", false)):
			cls = ""
	else:
		res = await on.submit_record("owev", id, secs, str(race.cfg.get("car", "")))
	if not res.get("ok", false) or not (res.get("data") is Dictionary):
		return
	var d: Dictionary = res["data"]
	var where := (Tr.t("clase %s") % cls) if cls != "" else Tr.t("mundial")
	if int(d.get("rank", 0)) == 1 and bool(d.get("saved", false)):
		_toast(Tr.t("🌍 ¡NUEVO RÉCORD %s! %s") % [where.to_upper(), _fmt(secs)])
	elif d.get("top") is Dictionary:
		var tp: Dictionary = d["top"]
		_toast(Tr.t("🌍 Récord %s: %s de %s · vos sos %dº") % [where, _fmt(float(tp.get("value", 0))), str(tp.get("name", "")), int(d.get("rank", 0))])

func _end() -> void:
	for rv in rivals:
		race.remove_car(rv["car"])
	rivals.clear()
	if is_instance_valid(_gate):
		_gate.queue_free()
	_gate = null
	var pol = race.get("police")
	if pol != null:
		pol.suspended = false
		if str(cur.get("type", "")) == "huida" and pol.state == "chase":
			pol._clear()
	var ch = _ch()
	if ch != null:
		ch.clear_dest()
	state = "free"
	cur = {}
	ev_i = -1

## Se rehicieron los autos (taller de prueba): se cancela lo que esté en curso
func forget() -> void:
	rivals.clear()
	if state != "free":
		state = "free"
		cur = {}
		var pol = race.get("police")
		if pol != null:
			pol.suspended = false

# ───────────────────────── marcas, mapa y textos
func _ch():
	return race.race_hud.city_hud if race.race_hud != null else null

func _refresh_map() -> void:
	var ch = _ch()
	if ch == null or not ("marks" in ch):
		return
	var m: Array = []
	for ev in events:
		if found(str(ev["id"])):
			var rr := _rec(str(ev["id"]))
			var won: bool = int(rr.get("wins", 0)) > 0
			# al tocarla en el mapa: tipo, largo, premio, tu mejor y que vale cualquier auto (auditoría 16/10/2026)
			var info := "%s %s · %s · $%d" % [ev["icon"], _title(ev), ("%.1f km" % (float(ev.get("len", 0.0)) / 1000.0)).replace(".", ","), int(ev.get("reward", 0))]
			if rr.has("best"):
				info += " · " + Tr.t("tu mejor %s") % _fmt(float(rr["best"]))
			info += " · " + Tr.t("cualquier auto")
			m.append({"pos": ev["start"], "name": "%s %s" % [ev["icon"], _title(ev)], "col": Color(0.35, 0.95, 0.5) if won else Color(1.0, 0.75, 0.15), "info": info})
		else:
			# por descubrir: sólo dónde está (sin nombre ni premio)
			m.append({"pos": ev["start"], "name": "❓", "col": Color(0.62, 0.7, 0.85), "unk": true})
	ch.marks = m

func _mark_node(ev: Dictionary) -> Node3D:
	var root := Node3D.new()
	var s: Vector2 = ev["start"]
	var y := float(track.ground_y(s.x, s.y))
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = START_R
	cm.bottom_radius = START_R
	cm.height = 0.06
	cm.radial_segments = 32
	cm.rings = 1
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.7, 0.1, 0.35) if found(str(ev["id"])) else Color(0.4, 0.8, 1.0, 0.3)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(s.x, y + 0.12, s.y)
	root.add_child(ring)
	var lb := Label3D.new()
	lb.text = "%s %s\n$%d" % [ev["icon"], _title(ev), int(ev["reward"])]
	lb.font_size = 56
	lb.pixel_size = 0.011
	lb.outline_size = 12
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.visibility_range_begin = 16.0 # de muy cerca no tapa la pantalla
	lb.visibility_range_end = MARK_R
	lb.no_depth_test = false
	lb.modulate = Color(1.0, 0.9, 0.55)
	lb.position = Vector3(s.x, y + 5.0, s.y)
	root.add_child(lb)
	var md = race.get("modes")
	if md != null and md.has_method("is_weekly") and md.is_weekly(str(ev["id"])):
		lb.text = "🏆 " + Tr.t("CARRERA DE LA SEMANA") + "\n" + lb.text
		lb.modulate = Color(1.0, 0.8, 0.25)
	var best: Variant = _rec(str(ev["id"])).get("best")
	if best != null:
		lb.text += "\n" + Tr.t("tu mejor: %s") % _fmt(float(best))
	_fetch_record(str(ev["id"]), lb)
	if track.world_node != null:
		track.world_node.add_child(root)
	return root

## El récord mundial de esa carrera (ranking por datos): se agrega al cartel cuando llega
func _fetch_record(id: String, lb: Label3D) -> void:
	var on = race.get("online")
	if on == null or not on.has_method("is_account") or not on.is_account():
		return
	var r: Dictionary = await on.leaderboard("ow:" + id, "owev", 1)
	if not is_instance_valid(lb) or not r.get("ok", false) or not (r.get("data") is Array) or (r["data"] as Array).is_empty():
		return
	var top: Dictionary = (r["data"] as Array)[0]
	lb.text += "\n🌍 %s · %s" % [_fmt(float(top.get("value", 0))), str(top.get("name", ""))]

func _gate_update(typ: String) -> void:
	if typ == "persecucion":
		return
	var next := minf(arc + 250.0, float(cur["len"]) if typ != "circuito" else 1e9)
	var lap_len := float(cur.get("lap_len", float(cur["len"])))
	var q := _at(fmod(next, lap_len) if typ == "circuito" else next)
	if _gate == null or not is_instance_valid(_gate):
		_gate = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.2
		cm.bottom_radius = 1.2
		cm.height = 26.0
		cm.radial_segments = 10
		cm.rings = 1
		(_gate as MeshInstance3D).mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.7, 0.1, 0.45)
		(_gate as MeshInstance3D).material_override = mat
		(_gate as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if track.world_node != null:
			track.world_node.add_child(_gate)
	_gate.position = Vector3(q.x, float(track.ground_y(q.x, q.y)) + 13.0, q.y)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -300.0
	box.offset_right = 300.0
	box.offset_top = 132.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_hud_l = Label.new()
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 22)
	_hud_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_hud_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_l.add_theme_constant_override("outline_size", 6)
	box.add_child(_hud_l)
	_hud.visible = false
	race.add_child(_hud)
	var bl := CanvasLayer.new()
	bl.layer = 4
	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -330.0
	_banner.offset_right = 330.0
	_banner.offset_top = -120.0
	_banner.offset_bottom = 40.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_banner.add_theme_constant_override("outline_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.72)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	_banner.add_theme_stylebox_override("normal", sb)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	bl.add_child(_banner)
	race.add_child(bl)

func _show_banner(txt: String, secs: float) -> void:
	if _banner == null:
		return
	_banner.text = txt
	_banner_t = secs
	_banner.visible = true

func _toast(s: String) -> void:
	if race.race_hud != null:
		race.race_hud.toast(s)

## Nombre que se muestra: el tipo traducido + el lugar (los nombres de los pueblos no se traducen); los circuitos tienen nombre propio
static func _title(ev: Dictionary) -> String:
	if str(ev["type"]) == "circuito":
		return Tr.t(str(ev["name"]))
	return "%s · %s" % [Tr.t(str(OW.TYPES[str(ev["type"])]["name"])), str(ev.get("where", ""))]

static func _fmt(secs: float) -> String:
	return "%d:%04.1f" % [int(secs / 60.0), fmod(secs, 60.0)]

static func _km(m: float) -> String:
	return ("%d m" % int(m)) if m < 1000.0 else ("%.1f km" % (m / 1000.0))
