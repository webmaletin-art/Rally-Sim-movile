extends RefCounted
## Policía del mundo abierto (docs/POLICIA.md). Controles en las rutas largas que unen pueblos y ciudades de la región: si pasás por uno, los patrulleros
## salen a perseguirte; te encierran, te chocan y se te cruzan adelante. Si te frenan (o se te pegan demasiado) te arrestan: pagás la multa y aparecés con tu auto
## frente a la comisaría de Dream City. Sólo los mejores pasan: hay que ir a fondo y escaparse a más de ESCAPE_R metros durante ESCAPE_T segundos.
## Cuantos más pueblos y ciudades cruzás desde que saliste de Dream City, más patrulleros (2 → 5) y más rápidos.
## Es un servicio de la ciudad (city_services.gd): setup(race) / update(dt). Los patrulleros son autos de verdad (race.add_ai_car) con police_driver.gd.

const WavLoop := preload("res://game/audio/wav_loop.gd")
const PoliceDriver := preload("res://game/ai/police_driver.gd")
const WorldGps := preload("res://game/city/world_gps.gd")
const CityGps := preload("res://game/city/city_gps.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CrashLog := preload("res://game/diag/crash_log.gd")
const Sectors := preload("res://game/region/sectors.gd")

const VID := "police"
const CLASSES := [1, 2, 3] # autopista, ruta, provincial (RegionData.CLS_NAMES)
const SETTLE_KINDS := [3, 4] # ciudad, pueblo (RegionData.KIND_NAMES)
const MIN_LEN := 2500.0 # sólo los tramos largos tienen control
const ARM_R := 650.0 # a esta distancia del control ya están los patrulleros (estacionados, con las balizas)
const DISARM_R := 1100.0
const TRIGGER_R := 60.0 # pasar a menos de esto del control dispara la persecución
const SETTLE_R := 700.0 # entrar a un pueblo o ciudad
const CITY_R := 3600.0 # dentro de Dream City (hasta la circunvalación) se borra el nivel
const BUST_R := 8.5 # patrullero pegado
const BUST_SPEED := 6.9 # m/s (25 km/h): más despacio que esto con un patrullero pegado → te arrestan en BUST_T s
const BUST_T := 1.6
const STICK_R := 4.5 # pegado de verdad (te están encerrando): también llena la barra, más lento
const STICK_T := 6.0
const ESCAPE_R := 480.0
const ESCAPE_T := 10.0
const LOST_R := 1400.0 # un patrullero que quedó así de lejos se pierde (sale de la persecución)
const COOLDOWN := 240.0 # un control del que te escapaste no vuelve a salir por un rato
const FINE_BASE := 2000
const FINE_LEVEL := 1500
const STATION := Vector2(70.0, 60.0) # comisaría de Dream City (cerca de la plaza; se usa la calle más cercana)
const PROP_ID := 960000 # círculos sólidos de los patrulleros estacionados en la comisaría
const ROLES := ["ram", "block", "side", "ram", "block"]

var race
var track
var region
var gps
var enabled := true
var suspended := false # durante una carrera del mundo abierto no se arman controles (city_events.gd)
var checkpoints: Array = [] # {p: Vector2, dir: Vector2, ei: int, hw: float}
var _cells := {} # Vector2i (2 km) -> índices de controles
var _settle: Array = [] # Vector2 de pueblos y ciudades
var state := "idle" # idle | armed | chase
var cp := -1
var units: Array = [] # {car, drv, lights: Array}
var visited := {}
var heat := 0
var bust := 0.0
var lose_t := 0.0
var chase_t := 0.0
var _spawn_t := 0.0
var _icpt_t := 0.0
var cool := {}
var _route_i := 0
var _route_t := 0.0
var _flash := 0.0
var _settle_t := 0.0
var _phase := ""
var _phase_t := 0.0
var _fine := 0
var station_pose: Array = []
var stats := {"chases": 0, "arrests": 0, "escapes": 0}
var siren: AudioStreamPlayer3D
var _hud: CanvasLayer
var _hud_l: Label
var _hud_bar: ProgressBar

func setup(p_race) -> void:
	race = p_race
	track = race.track
	region = track.get("region")
	if region == null or race.cfg.get("police", true) == false or not race.vehicles.has(VID):
		enabled = false
		return
	var ch = race.race_hud.city_hud if race.race_hud != null else null
	gps = ch.gps if ch != null and ch.get("gps") != null else WorldGps.new(CityGps.new(track.city), region)
	_build_checkpoints()
	for n in region.nodes:
		if int(n[3]) in SETTLE_KINDS:
			_settle.append(Vector2(float(n[1]), float(n[2])))
	station_pose = track.nearest_road_pose(STATION, 0.0)
	_build_station()
	_build_hud()

## Un control por cada tramo largo de autopista, ruta o provincial, lo más lejos posible de los pueblos y fuera de Dream City
func _build_checkpoints() -> void:
	for ei in region.edges.size():
		var e: Array = region.edges[ei]
		if not (int(e[2]) in CLASSES) or float(e[8]) < MIN_LEN:
			continue
		var L := float(e[8])
		for f in [0.5, 0.38, 0.62, 0.28, 0.72]:
			var r: Array = region.point_at(ei, L * f)
			var q: Vector2 = r[0]
			if q.length() < CITY_R + 400.0 or region.in_town(q.x, q.y) or not Sectors.is_open(q):
				continue
			var ci := Vector2i(floori(q.x / 2000.0), floori(q.y / 2000.0))
			if not _cells.has(ci):
				_cells[ci] = []
			(_cells[ci] as Array).append(checkpoints.size())
			checkpoints.append({"p": q, "dir": r[1], "ei": ei, "hw": float(region.e_hw[ei])})
			break

func _near_cp(p: Vector2) -> int:
	var c0 := Vector2i(floori(p.x / 2000.0), floori(p.y / 2000.0))
	var best := -1
	var bd := ARM_R
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for i in _cells.get(c0 + Vector2i(dx, dz), []):
				var d: float = (checkpoints[i]["p"] as Vector2).distance_to(p)
				if d < bd and not cool.has(i):
					bd = d
					best = i
	return best

func update(dt: float) -> void:
	if not enabled or race.cars.is_empty():
		return
	if _phase != "":
		_arrest_anim(dt)
		return
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	if suspended and state != "chase":
		if state == "armed":
			_clear()
		_hud_update()
		return
	_heat(dt, p)
	for k in cool.keys():
		cool[k] = float(cool[k]) - dt
		if float(cool[k]) <= 0.0:
			cool.erase(k)
	_flash += dt
	match state:
		"idle":
			var c := _near_cp(p)
			if c >= 0:
				_arm(c, me)
		"armed":
			var d := p.distance_to(checkpoints[cp]["p"])
			if d > DISARM_R:
				_clear()
			elif d < TRIGGER_R:
				_start_chase(me)
		"chase":
			_chase(dt, p, me)
	_lights()
	_hud_update()

## Nivel: pueblos y ciudades que cruzaste desde que saliste de Dream City
func _heat(dt: float, p: Vector2) -> void:
	_settle_t -= dt
	if _settle_t > 0.0:
		return
	_settle_t = 1.0
	if p.length() < CITY_R:
		if state != "chase":
			visited.clear()
			heat = 0
		return
	for i in _settle.size():
		if not visited.has(i) and (_settle[i] as Vector2).distance_to(p) < SETTLE_R:
			visited[i] = true
	heat = mini(visited.size(), 3)

func wanted() -> int:
	return clampi(2 + heat, 2, 5)

func _mods() -> Dictionary:
	var v: Dictionary = race.vehicles[VID]
	return {"mu": float(v["mu"]) * (1.2 + 0.03 * float(heat)), "powerScale": 1.12 + 0.06 * float(heat)} # agarran más que cualquier auto: es la policía

## Patrulleros estacionados en la banquina del control, mirando hacia donde va el jugador (para salir detrás de él)
func _arm(c: int, me) -> void:
	cp = c
	state = "armed"
	var ck: Dictionary = checkpoints[c]
	var dir: Vector2 = ck["dir"]
	var fwd := Vector2(sin(me.yaw), cos(me.yaw))
	var toward := dir if (ck["p"] - Vector2(me.px, me.pz)).dot(dir) > 0.0 else -dir # el sentido en que viene el jugador
	var lat := Vector2(toward.y, -toward.x)
	var n := wanted()
	var hw := float(ck["hw"])
	var first_side := 1.0 if (int(ck["ei"]) % 2) == 0 else -1.0
	for k in n:
		# todos controlan desde la orilla (pedido del dueño, 14/10/2026: «desde la orilla de la ruta, no en el medio»): estacionados en las dos
		# banquinas, uno de cada lado y escalonados, con la trompa apuntando un poco hacia la ruta para salir enseguida detrás del que pasa
		var side := first_side if k % 2 == 0 else -first_side
		var q: Vector2 = ck["p"] + toward * (float(k / 2) * 16.0 + (0.0 if k % 2 == 0 else 7.0)) + lat * side * (hw + 2.2)
		var yaw := atan2(toward.x, toward.y) - side * 0.45
		_spawn(q, yaw, ROLES[k % ROLES.size()])
	CrashLog.mark("policia", "control armado · %d patrulleros · nivel %d" % [n, heat])
	if fwd.dot(toward) < -0.5:
		pass # (viene de espaldas al control: igual se arman; salen cuando pase)

func _spawn(q: Vector2, yaw: float, role: String) -> void:
	var drv := PoliceDriver.new()
	drv.role = role
	drv.side = 1.0 if units.size() % 2 == 0 else -1.0
	var mods := _mods()
	drv.grip = float(mods["mu"]) * 0.9 # (lo que de verdad da en una curva, con el auto cargado)
	var car = race.add_ai_car(VID, q.x, q.y, yaw, drv, Color(0.95, 0.95, 0.95), mods)
	if car == null:
		return
	units.append({"car": car, "drv": drv, "lights": _add_lights(car.visual)})

## Balizas: dos esferas (roja y azul) que titilan sobre el techo; baratas (sin luces reales)
func _add_lights(vis: Node3D) -> Array:
	var out: Array = []
	var body: Node3D = vis.get("body")
	if body == null:
		return out
	var h := 1.42
	var meta: Variant = vis.get("meta")
	if meta is Dictionary and (meta as Dictionary).has("H"):
		h = float(meta["H"]) + 0.02
	for k in 2:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.16
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.12, 0.1) if k == 0 else Color(0.15, 0.35, 1.0)
		mi.material_override = mat
		mi.position = Vector3(-0.32 if k == 0 else 0.32, h, -0.15)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		out.append(mi)
	return out

func _lights() -> void:
	var on := int(_flash / 0.18) % 2 == 0
	for u in units:
		var l: Array = u["lights"]
		for k in l.size():
			if is_instance_valid(l[k]):
				(l[k] as Node3D).visible = on == (k == 0)

func _start_chase(me) -> void:
	state = "chase"
	bust = 0.0
	lose_t = 0.0
	chase_t = 0.0
	_spawn_t = 0.0
	_icpt_t = 2.0
	stats["chases"] += 1
	for u in units:
		u["drv"].target = me
		u["drv"].mode = "chase"
	_siren_on()
	_toast(Tr.t("🚨 ¡CONTROL POLICIAL! Te persiguen %d patrulleros") % units.size())
	CrashLog.mark("policia", "persecución · %d patrulleros · nivel %d" % [units.size(), heat])

func _chase(dt: float, p: Vector2, me) -> void:
	chase_t += dt
	_spawn_t += dt
	var sp := sqrt(me.vx * me.vx + me.vz * me.vz)
	var dmin := 1e9
	var near := 0
	for u in units.duplicate():
		var c = u["car"]
		var q := Vector2(c.phys.px, c.phys.pz)
		var d := q.distance_to(p)
		if d > LOST_R:
			_remove(u)
			continue
		dmin = minf(dmin, d)
		if d < BUST_R:
			near += 1
		# lejos aprietan (para no quedar atrás); pegados, igual que el jugador
		c.phys.powerMul = 1.0 + clampf((d - 30.0) / 250.0, 0.0, 1.0) * (0.9 + 0.15 * float(heat))
	# refuerzos: si perdió alguno (o subió el nivel), llega otro por atrás, fuera de la vista
	if units.size() < wanted() and _spawn_t > 16.0:
		_spawn_t = 0.0
		var back := p - Vector2(sin(me.yaw), cos(me.yaw)) * 320.0
		var pose: Array = track.nearest_road_pose(back, me.yaw)
		if not pose.is_empty() and Vector2(pose[0], pose[1]).distance_to(p) > 200.0:
			_spawn(Vector2(pose[0], pose[1]), float(pose[2]), ROLES[units.size() % ROLES.size()])
			var u: Dictionary = units[units.size() - 1]
			u["drv"].target = me
			u["drv"].mode = "chase"
	# interceptor: un patrullero que viene de frente desde adelante (al empezar y, con nivel, cada 40 s)
	_icpt_t -= dt
	if _icpt_t <= 0.0 and sp > 15.0 and units.size() < wanted() + 1:
		_icpt_t = 40.0 if heat > 0 else 1e9
		var fwd := Vector2(me.vx, me.vz) / maxf(sp, 0.1)
		var pose2: Array = track.nearest_road_pose(p + fwd * 750.0, atan2(-fwd.x, -fwd.y))
		if not pose2.is_empty() and Vector2(pose2[0], pose2[1]).distance_to(p) > 450.0:
			_spawn(Vector2(pose2[0], pose2[1]), float(pose2[2]), "block")
			var ui: Dictionary = units[units.size() - 1]
			ui["drv"].target = me
			ui["drv"].mode = "chase"
	# caminos del GPS: uno por vez, cada 0,3 s
	_route_t -= dt
	if _route_t <= 0.0 and not units.is_empty():
		_route_t = 0.3
		var u: Dictionary = units[_route_i % units.size()]
		_route_i += 1
		var q := Vector2(u["car"].phys.px, u["car"].phys.pz)
		if q.distance_to(p) > PoliceDriver.NEAR * 0.7:
			var r: Dictionary = gps.route(q, p)
			u["drv"].path = r.get("pts", PackedVector2Array())
			u["drv"].idx = 0
		else:
			u["drv"].path = PackedVector2Array()
	# arresto
	if near > 0 and sp < BUST_SPEED:
		bust += dt / BUST_T
	elif dmin < STICK_R:
		bust += dt / STICK_T
	else:
		bust -= dt / 5.0
	bust = clampf(bust, 0.0, 1.0)
	if bust >= 1.0:
		_arrest()
		return
	# escape
	if dmin > ESCAPE_R or units.is_empty():
		lose_t += dt
	else:
		lose_t = maxf(0.0, lose_t - dt * 2.0)
	if lose_t >= ESCAPE_T:
		_escaped()

## Evento «Huida» (carreras del mundo abierto): la persecución arranca ya, con patrulleros detrás (fuera de la vista) y uno de frente
func event_chase(me, level: int) -> void:
	_clear()
	heat = clampi(level, 0, 3)
	var p := Vector2(me.px, me.pz)
	var fwd := Vector2(sin(me.yaw), cos(me.yaw))
	for k in wanted():
		var back := p - fwd * (140.0 + 45.0 * float(k))
		var pose: Array = track.nearest_road_pose(back, me.yaw)
		if not pose.is_empty():
			_spawn(Vector2(pose[0], pose[1]), float(pose[2]), ROLES[k % ROLES.size()])
	cp = _near_cp(p) if _near_cp(p) >= 0 else 0
	_start_chase(me)

func _escaped() -> void:
	stats["escapes"] += 1
	cool[cp] = COOLDOWN
	_toast(Tr.t("😎 ¡Los perdiste! La policía abandona la persecución"))
	CrashLog.mark("policia", "escape · %.0f s" % chase_t)
	_clear()

func _arrest() -> void:
	stats["arrests"] += 1
	_fine = FINE_BASE + FINE_LEVEL * heat
	_phase = "out"
	_phase_t = 0.0
	CrashLog.mark("policia", "arresto · multa %d · nivel %d" % [_fine, heat])

## Fundido a negro, multa, comisaría y vuelta (igual que las bocas de túnel: city_links.gd)
func _arrest_anim(dt: float) -> void:
	_phase_t += dt
	var ch = race.race_hud.city_hud if race.race_hud != null else null
	if _phase == "out":
		if ch != null:
			ch.set_fade(clampf(_phase_t / 0.6, 0.0, 1.0))
		race.cars[0].phys.vx *= 0.9
		race.cars[0].phys.vz *= 0.9
		if _phase_t >= 0.6:
			_to_station()
			_phase = "in"
			_phase_t = 0.0
	elif _phase == "in":
		if ch != null:
			ch.set_fade(clampf(1.0 - (_phase_t - 0.8) / 0.6, 0.0, 1.0))
		if _phase_t >= 1.4:
			_phase = ""
			if ch != null:
				ch.set_fade(0.0)

func _to_station() -> void:
	_clear()
	var prof = race.profile
	var paid := 0
	if prof != null:
		paid = mini(_fine, int(prof.credits))
		if paid > 0:
			prof.spend(paid, "fine")
	visited.clear()
	heat = 0
	bust = 0.0
	if not station_pose.is_empty():
		var w = track.world_node
		if w != null and w.has_method("warm"):
			w.warm(Vector3(float(station_pose[0]), 0.0, float(station_pose[1])))
		race.cars[0].place(float(station_pose[0]), float(station_pose[1]), float(station_pose[2]))
		race.cars[0].restart_history(race.sim_t)
		race.on_teleport()
	if race.has_method("update_credits_hud"):
		race.update_credits_hud()
	_toast(Tr.t("🚔 ARRESTADO · pagaste la multa: $%d. Estás frente a la comisaría de Dream City") % paid)

func _remove(u: Dictionary) -> void:
	if siren != null and is_instance_valid(siren) and siren.get_parent() == u["car"].visual:
		siren.get_parent().remove_child(siren)
		siren.queue_free()
		siren = null
	race.remove_car(u["car"])
	units.erase(u)
	if state == "chase" and not units.is_empty() and siren == null:
		_siren_on()

func _clear() -> void:
	for u in units.duplicate():
		_remove(u)
	units.clear()
	state = "idle"
	cp = -1
	bust = 0.0
	lose_t = 0.0

## Se rehicieron los autos de la carrera (taller de prueba, cambio de auto): los patrulleros ya no están en la lista
func forget() -> void:
	units.clear()
	siren = null
	state = "idle"
	cp = -1
	bust = 0.0
	lose_t = 0.0

func _siren_on() -> void:
	if units.is_empty() or race.get("audio") == null:
		return
	var st: Variant = load("res://game/audio/samples/siren.wav")
	if not (st is AudioStreamWAV):
		return
	var w: AudioStreamWAV = WavLoop.make((st as AudioStreamWAV).duplicate(), (st as AudioStreamWAV).data.size() / 2) # (copia: no se toca el recurso compartido; bucle seguro, ver wav_loop.gd)
	siren = AudioStreamPlayer3D.new()
	siren.stream = w
	siren.unit_size = 14.0
	siren.max_distance = 450.0
	siren.volume_db = -7.0
	units[0]["car"].visual.add_child(siren)
	siren.play()

## Comisaría de Dream City: cartel y dos patrulleros estacionados en la vereda (sólidos)
func _build_station() -> void:
	if station_pose.is_empty() or track.world_node == null:
		return
	var root := Node3D.new()
	root.name = "comisaria"
	var x := float(station_pose[0])
	var z := float(station_pose[1])
	var yaw := float(station_pose[2])
	var fwd := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(fwd.y, -fwd.x)
	var y := float(track.ground_y(x, z))
	var sign_p := Vector2(x, z) + lat * 7.5
	var lb := Label3D.new()
	lb.text = "🚔 " + Tr.t("COMISARÍA") + "\n" + Tr.t("POLICÍA DE DREAM CITY")
	lb.font_size = 96
	lb.pixel_size = 0.012
	lb.outline_size = 18
	lb.modulate = Color(0.75, 0.85, 1.0)
	lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lb.position = Vector3(sign_p.x, y + 4.2, sign_p.y)
	root.add_child(lb)
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 3.4, 0.18)
	pole.mesh = bm
	pole.position = Vector3(sign_p.x, y + 1.7, sign_p.y)
	root.add_child(pole)
	track.world_node.add_child(root)

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -230.0
	box.offset_right = 230.0
	box.offset_top = 132.0 # (debajo del velocímetro de arriba al centro)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_hud_l = Label.new()
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 20)
	_hud_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_l.add_theme_constant_override("outline_size", 6)
	box.add_child(_hud_l)
	_hud_bar = ProgressBar.new()
	_hud_bar.custom_minimum_size = Vector2(0, 10)
	_hud_bar.max_value = 1.0
	_hud_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.2, 0.2)
	_hud_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_hud_bar)
	_hud.visible = false
	race.add_child(_hud)

func _hud_update() -> void:
	if _hud == null:
		return
	match state:
		"armed":
			_hud.visible = true
			_hud_bar.visible = false
			_hud_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			_hud_l.text = Tr.t("⚠ CONTROL POLICIAL ADELANTE · %d m") % int(Vector2(race.cars[0].phys.px, race.cars[0].phys.pz).distance_to(checkpoints[cp]["p"]))
		"chase":
			_hud.visible = true
			_hud_bar.visible = true
			_hud_bar.value = bust
			_hud_l.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if int(_flash / 0.3) % 2 == 0 else Color(0.5, 0.65, 1.0))
			var esc := "" if lose_t <= 0.5 else ("  ·  " + Tr.t("escapando %d/%d s") % [int(lose_t), int(ESCAPE_T)])
			_hud_l.text = Tr.t("🚨 PERSECUCIÓN · %d 🚓 · nivel %d") % [units.size(), heat + 1] + esc
		_:
			_hud.visible = false

func _toast(t: String) -> void:
	if race.race_hud != null:
		race.race_hud.toast(t)
