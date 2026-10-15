extends RefCounted
## Modos del mundo abierto contra la IA (15/10/2026, pedido del dueño: «por si el online se rompe, partidas contra la IA»). Se prenden y se apagan desde la pausa
## (no en el mundo online). Detalle en docs/MODOS_MUNDO_ABIERTO.md.
##
##  · FUGITIVO: hacé lío por la ciudad y la policía te caza (city_police.gd → desmadre, el doble de sensible y la cacería llega igual aunque manejes bien).
##    Cada vez que te escapás cobrás (más cuanto más dura y más alto el nivel) y la próxima cacería viene más fuerte; si te agarran, se corta la racha.
##  · CAZA RECOMPENSAS: un auto de la IA anda suelto por el mapa (ciudad y región) y huye de vos. Hay que mantenerse pegado (a menos de STICK_R m) HOLD_S segundos
##    en total: lo atrapás y el auto es tuyo (si ya lo tenés, cobrás una parte de su precio). La policía sigue activa: si andás como loco, te persigue a vos.
##    El servidor de la cuenta valida el auto ganado (evento give_car «bounty»: 1 por día y hasta $150.000; migración 20261018000000_bounty_car.sql).
## Es un servicio de la ciudad (city_services.gd): setup(race) / update(dt).

const PoliceDriver := preload("res://game/ai/police_driver.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CrashLog := preload("res://game/diag/crash_log.gd")

# fugitivo
const ESC_BASE := 1500
const ESC_LEVEL := 1000
const ESC_PER_S := 20
# caza
const STICK_R := 22.0 # «pegado»
const HOLD_S := 30.0 # segundos pegado (en total) para atraparlo
const LOST_R := 2500.0 # más lejos que esto…
const LOST_T := 25.0 # …durante tanto tiempo: se escapó
const TIME_MAX := 720.0 # 12 minutos
const FLEE_R := 140.0 # más cerca que esto, huye para el otro lado
const PRICE_MAX := 150000 # el servidor tampoco da autos más caros (premium y premios de la aventura, nunca)
const NO_BOUNTY := ["truck", "gt3", "hyper", "genesis", "police", "f1", "t1plus"]
const DAY_S := 86400
const DUP_K := 0.25 # si ya tenés ese auto (o ya ganaste uno hoy): esta parte de su precio

var race
var mode := "" # "" · "fugitivo" · "caza"
var stats := {"escapes": 0, "arrests": 0, "caught": 0, "lost": 0}
# fugitivo
var streak := 0
var _esc0 := 0
var _arr0 := 0
var _chase_t := 0.0
# caza
var target: Dictionary = {} # {car, drv, vid, name, price}
var hold := 0.0
var t := 0.0
var _lost_t := 0.0
var _route_t := 0.0
var _gps_t := 0.0
var _end_t := 0.0
var _label: Label3D
var _hud: CanvasLayer
var _hud_l: Label
var _banner: Label
var _banner_t := 0.0

func setup(p_race) -> void:
	race = p_race
	_build_hud()

## ¿Se pueden usar acá? (mundo abierto sin conexión, con la policía de la región)
func available() -> bool:
	return race.get("police") != null and bool(race.police.enabled) and race.cfg.get("online", false) != true

## Los botones de la pausa: [[texto, modo]]
func pause_buttons() -> Array:
	if not available():
		return []
	return [[Tr.t("🚨  TERMINAR FUGITIVO") if mode == "fugitivo" else Tr.t("🚨  MODO FUGITIVO"), "fugitivo"],
		[Tr.t("🎯  TERMINAR CAZA") if mode == "caza" else Tr.t("🎯  CAZA RECOMPENSAS"), "caza"]]

func toggle(m: String) -> void:
	if mode == m:
		stop(true)
		return
	if mode != "":
		stop(true)
	start(m)

func start(m: String) -> void:
	if not available() or race.cars.is_empty():
		return
	var ev = race.get("ow_events")
	if ev != null and ev.busy():
		_toast(Tr.t("Terminá la carrera antes de empezar un modo"))
		return
	mode = m
	var pol = race.police
	if m == "fugitivo":
		pol.fugitive = true
		pol.fugitive_level = 0
		streak = 0
		_esc0 = int(pol.stats["escapes"])
		_arr0 = int(pol.stats["arrests"])
		_chase_t = 0.0
		_big(Tr.t("🚨 MODO FUGITIVO\nHacé lío por la ciudad: la policía te va a cazar.\nCada escape paga y la próxima viene más fuerte."), 5.0)
	else:
		if not _spawn_target():
			mode = ""
			_toast(Tr.t("No hay un auto para cazar cerca: probá en otra calle"))
			return
		hold = 0.0
		t = 0.0
		_lost_t = 0.0
		_end_t = 0.0
		_arr0 = int(pol.stats["arrests"])
		_big(Tr.t("🎯 CAZA RECOMPENSAS\nAnda suelto un %s ($%d).\nPegate %d s en total y es tuyo. Ojo con la policía.") % [str(target["name"]), int(target["price"]), int(HOLD_S)], 5.5)
	CrashLog.mark("modo", "empieza %s" % m)

## Termina el modo (por el jugador desde la pausa, o solo: atrapado, escapado, arrestado)
func stop(by_player := false) -> void:
	if mode == "":
		return
	var pol = race.get("police")
	if pol != null:
		pol.fugitive = false
		pol.fugitive_level = 0
	if mode == "fugitivo" and by_player:
		_big(Tr.t("🚨 FIN DEL MODO FUGITIVO · racha de %d escapes") % streak, 3.5)
	_drop_target()
	var ch = _ch()
	if ch != null and ch.has_method("clear_dest"):
		ch.clear_dest()
	CrashLog.mark("modo", "termina %s" % mode)
	mode = ""
	_hud.visible = false

func update(dt: float) -> void:
	if _banner != null:
		_banner_t -= dt
		_banner.visible = _banner_t > 0.0
	if mode == "" or race.cars.is_empty():
		if _hud != null:
			_hud.visible = false
		return
	var pol = race.police
	if mode == "fugitivo":
		_fugitive(dt, pol)
	else:
		_hunt(dt, pol)

# ───────────────────────── fugitivo ─────────────────────────
func _fugitive(dt: float, pol) -> void:
	if str(pol.state) == "chase":
		_chase_t += dt
	if int(pol.stats["escapes"]) > _esc0:
		_esc0 = int(pol.stats["escapes"])
		streak += 1
		stats["escapes"] += 1
		var pay := escape_reward(int(pol.heat), _chase_t)
		race.profile.earn(float(pay), "fugitivo")
		race.profile.add_xp(float(pay) * 0.2)
		race.profile.save()
		pol.fugitive_level = mini(3, streak)
		_big(Tr.t("😎 ¡ESCAPASTE! + $%d\nRacha: %d · la próxima viene más fuerte") % [pay, streak], 4.0)
		_chase_t = 0.0
		if race.has_method("update_credits_hud"):
			race.update_credits_hud()
	if int(pol.stats["arrests"]) > _arr0:
		_arr0 = int(pol.stats["arrests"])
		stats["arrests"] += 1
		_big(Tr.t("🚔 TE AGARRARON · la racha quedó en %d") % streak, 4.0)
		streak = 0
		pol.fugitive_level = 0
		_chase_t = 0.0
	_hud.visible = true
	var st := Tr.t("en persecución · %d s") % int(_chase_t) if str(pol.state) == "chase" else Tr.t("la policía te busca: %d %%") % int(minf(pol.rage, 1.0) * 100.0)
	_hud_l.text = Tr.t("🚨 FUGITIVO · racha %d · %s") % [streak, st]

static func escape_reward(level: int, chase_s: float) -> int:
	return int(round(float(ESC_BASE + ESC_LEVEL * clampi(level, 0, 3) + ESC_PER_S * int(clampf(chase_s, 0.0, 300.0))) / 50.0) * 50)

# ───────────────────────── caza recompensas ─────────────────────────
## Autos que pueden andar sueltos: los del catálogo hasta PRICE_MAX, sin los premium ni los especiales (el servidor aplica las mismas reglas)
static func bounty_pool(vehicles: Dictionary) -> Array:
	var out: Array = []
	var cars: Dictionary = CarBuild.catalog()["cars"]
	for id in cars:
		var sid := str(id)
		if NO_BOUNTY.has(sid) or not vehicles.has(sid):
			continue
		var pr := int((cars[id] as Dictionary).get("price", 0))
		if pr > 0 and pr <= PRICE_MAX:
			out.append(sid)
	out.sort()
	return out

## Qué se gana al atraparlo: {"car": id} (el auto) o {"credits": n} (ya lo tenés, o ya ganaste un auto hoy)
static func bounty_prize(vid: String, price: int, owned: bool, last_unix: int, now_unix: int) -> Dictionary:
	if not owned and now_unix - last_unix >= DAY_S:
		return {"car": vid}
	return {"credits": int(round(float(price) * DUP_K / 50.0) * 50)}

func _spawn_target() -> bool:
	var pool := bounty_pool(race.vehicles)
	if pool.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# prefiere uno que todavía no tengas
	var not_owned: Array = pool.filter(func(id) -> bool: return not race.profile.owns(str(id)))
	var vid := str((not_owned if not not_owned.is_empty() else pool)[rng.randi() % (not_owned if not not_owned.is_empty() else pool).size()])
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var fwd := Vector2(sin(me.yaw), cos(me.yaw))
	for tries in 6:
		var a := rng.randf_range(-1.2, 1.2)
		var q := p + fwd.rotated(a) * rng.randf_range(420.0, 700.0)
		var pose: Array = race.track.nearest_road_pose(q, me.yaw + a)
		if pose.is_empty() or Vector2(pose[0], pose[1]).distance_to(p) < 250.0:
			continue
		var drv := PoliceDriver.new()
		drv.mode = "parked"
		drv.grip = 1.0
		drv.pace = 1.02
		drv.errors = true
		var cat: Dictionary = CarBuild.catalog()["cars"][vid]
		var car = race.add_ai_car(vid, float(pose[0]), float(pose[1]), float(pose[2]), drv, Color(str(Profile.new_car_state(vid)["paint"]["body"])), {"powerScale": float(race.vehicles[vid].get("powerScale", 1.0)) * 1.06})
		if car == null:
			continue
		target = {"car": car, "drv": drv, "vid": vid, "name": "%s %s" % [str(cat.get("brand", "")), str(cat.get("model", vid))], "price": int(cat.get("price", 0))}
		_label = Label3D.new()
		_label.text = "🎯"
		_label.font_size = 96
		_label.pixel_size = 0.012
		_label.outline_size = 16
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.position = Vector3(0, 2.6, 0)
		car.visual.add_child(_label)
		_route_t = 0.0
		return true
	return false

func _drop_target() -> void:
	if target.is_empty():
		return
	var car = target["car"]
	if car != null and race.cars.has(car):
		race.remove_car(car)
	target = {}
	_label = null

## Los autos se rehicieron (taller de prueba, cambio de auto): el que andaba suelto ya no está en la lista
func forget() -> void:
	target = {}
	_label = null
	if mode == "caza":
		mode = ""
		_hud.visible = false

func _hunt(dt: float, pol) -> void:
	if target.is_empty() or not race.cars.has(target["car"]):
		stop()
		return
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var tc = target["car"]
	var q := Vector2(tc.phys.px, tc.phys.pz)
	var d := q.distance_to(p)
	if _end_t > 0.0:
		_end_t -= dt
		tc.phys.vx *= 0.9
		tc.phys.vz *= 0.9
		if _end_t <= 0.0:
			stop()
		return
	t += dt
	if int(pol.stats["arrests"]) > _arr0:
		stats["lost"] += 1
		_big(Tr.t("🚔 Te agarró la policía: el %s se escapó") % str(target["name"]), 4.0)
		stop()
		return
	hold = minf(HOLD_S, hold + dt) if d < STICK_R else maxf(0.0, hold - dt * 0.25)
	_lost_t = _lost_t + dt if d > LOST_R else 0.0
	if hold >= HOLD_S:
		_caught()
		return
	if _lost_t > LOST_T or t > TIME_MAX:
		stats["lost"] += 1
		_big(Tr.t("💨 Se te escapó el %s") % str(target["name"]), 4.0)
		stop()
		return
	# el que huye: va lejos por las calles y, si lo tenés encima, dobla para el otro lado
	var drv = target["drv"]
	_route_t -= dt
	if _route_t <= 0.0 or (drv.mode == "path" and drv.idx >= (drv.path as PackedVector2Array).size() - 2):
		_route_t = 3.0 if d < FLEE_R else 9.0
		var away := (q - p).normalized() if d > 1.0 else Vector2(sin(tc.phys.yaw), cos(tc.phys.yaw))
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for tries in 5: # (un destino al azar puede caer en el mar o sin camino: se prueban varios, cada uno sobre la calle más cercana)
			var spread := 0.9 + 0.5 * float(tries)
			var dest := q + away.rotated(rng.randf_range(-spread, spread)) * rng.randf_range(1200.0, 3000.0)
			var pose: Array = race.track.nearest_road_pose(dest, 0.0)
			if not pose.is_empty():
				dest = Vector2(float(pose[0]), float(pose[1]))
			var r: Dictionary = pol.gps.route(q, dest) if pol.gps != null else {}
			var pts: PackedVector2Array = r.get("pts", PackedVector2Array())
			if pts.size() > 1:
				drv.path = pts
				drv.idx = 0
				drv.mode = "path"
				break
	# GPS y minimapa: el destino es el auto
	_gps_t -= dt
	var ch = _ch()
	if _gps_t <= 0.0 and ch != null:
		_gps_t = 2.0
		if not bool(ch.get("has_dest")) or (ch.get("dest") as Vector2).distance_to(q) > 40.0:
			ch.set_dest(q, "🎯 " + str(target["name"]), bool(ch.get("has_dest"))) # (el primer aviso sí se muestra)
	if _label != null and is_instance_valid(_label):
		_label.modulate = Color(0.3, 1.0, 0.4) if d < STICK_R else Color(1.0, 0.85, 0.2)
	_hud.visible = true
	_hud_l.text = Tr.t("🎯 CAZA · %s · %d m · pegado %d/%d s · %d:%02d") % [str(target["name"]), int(d), int(hold), int(HOLD_S), int(TIME_MAX - t) / 60, int(TIME_MAX - t) % 60]

func _caught() -> void:
	stats["caught"] += 1
	var vid := str(target["vid"])
	var prof = race.profile
	var prize := bounty_prize(vid, int(target["price"]), prof.owns(vid), int(prof.d.get("bounty_last", 0)), int(Time.get_unix_time_from_system()))
	var msg := ""
	if prize.has("car"):
		prof.d["bounty_last"] = int(Time.get_unix_time_from_system())
		prof.give(vid, "bounty")
		msg = Tr.t("🎯 ¡LO ATRAPASTE!\nEl %s es tuyo: ya está en tu garaje") % str(target["name"])
	else:
		var n := int(prize["credits"])
		prof.earn(float(n), "caza")
		msg = Tr.t("🎯 ¡LO ATRAPASTE! + $%d\n(ya tenés ese auto o ya ganaste uno hoy: cobrás una parte)") % n
	prof.add_xp(1500.0)
	prof.save()
	if race.has_method("update_credits_hud"):
		race.update_credits_hud()
	_big(msg, 5.0)
	CrashLog.mark("modo", "caza: atrapado %s · %s" % [vid, JSON.stringify(prize)])
	target["drv"].mode = "parked"
	_end_t = 3.0

# ───────────────────────── HUD ─────────────────────────
func _ch():
	return race.race_hud.city_hud if race.race_hud != null else null

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	_hud_l = Label.new()
	_hud_l.anchor_left = 0.5
	_hud_l.anchor_right = 0.5
	_hud_l.offset_left = -330.0
	_hud_l.offset_right = 330.0
	_hud_l.offset_top = 176.0 # (debajo del velocímetro y del cartel de la policía)
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 20)
	_hud_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_hud_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_l.add_theme_constant_override("outline_size", 6)
	_hud_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hud_l)
	_hud.visible = false
	race.add_child(_hud)
	var lay := CanvasLayer.new() # el cartel grande va aparte: se ve aunque el modo ya haya terminado
	lay.layer = 3
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -420.0
	_banner.offset_right = 420.0
	_banner.offset_top = -150.0
	_banner.offset_bottom = 10.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	lay.add_child(_banner)
	race.add_child(lay)

func _big(s: String, secs: float) -> void:
	_banner.text = s
	_banner_t = secs
	_banner.visible = true

func _toast(s: String) -> void:
	if race.race_hud != null:
		race.race_hud.toast(s)
