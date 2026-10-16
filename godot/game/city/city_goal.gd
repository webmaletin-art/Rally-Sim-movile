extends RefCounted
## «PRÓXIMO OBJETIVO», consejos de una sola vez y ayuda (auditoría del ciclo de juego, 16/10/2026: «el jugador siempre sabe qué hacer»).
## Una tarjeta chica a la izquierda (debajo de la hora): el objetivo que más conviene ahora (game/city/next_goal.gd elige entre lo que ya existe), con IR (GPS) y ✕
## (otro objetivo). No aparece mientras corrés una carrera, te persigue la policía, hay una cacería o un contrarreloj en curso, ni yendo rápido.
## Consejos: la primera vez (profile.d["tutorial"] = {clave: true}) y se vuelven a ver con «❓ AYUDA» en la pausa. Sólo en el mundo abierto sin conexión.

const NextGoal := preload("res://game/city/next_goal.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Release := preload("res://game/data/release.gd")
const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CityModes := preload("res://game/city/city_modes.gd")

const REFRESH := 2.0
const FAST_KMH := 75.0
const DISMISS_S := 600.0
const TIP_S := 15.0 # un consejo se va solo (y cuenta como visto): nunca queda pegado mientras manejás

## consejos: [clave, texto]; se muestran de a uno, la primera vez que tocan
const TIPS := {
	"start": "👋 Las carreras se descubren manejando: los ❓ del mapa son carreras por descubrir. Tocá el minimapa.",
	"gps": "📍 En el mapa grande tocá un lugar o una carrera y el GPS te lleva. Acá, IR hace lo mismo.",
	"ring": "🏁 Para largar, frená adentro del círculo del piso. Sirve cualquier auto: los rivales se adaptan.",
	"events": "📅 Los eventos del servidor llegan solos. En la pausa: 📅 EVENTOS EN VIVO.",
	"garage": "🔧 Con lo que ganaste mejorá el auto en un taller o comprá otro en el concesionario.",
	"police": "🚨 Chocar o romper farolas llama a la policía: si te escapás cobrás, si te agarran, multa.",
}
const TIP_ORDER := ["start", "gps", "ring", "events", "garage", "police"]

var race
var goals: Array = []
var shown: Dictionary = {}
var dismissed: Dictionary = {} # clave → hasta cuándo (segundos de juego)
var tip_key := ""
var _tip_t := 0.0
var _t := 0.0
var _clock := 0.0
var _fast_t := 0.0
var _seen_ring := false
var card: PanelContainer
var _icon: Label
var _title: Label
var _sub: Label
var _go: Button
var _x: Button

func setup(p_race) -> void:
	race = p_race
	if not active():
		return
	var ch = _ch()
	if ch == null:
		return
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.78)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(1.0, 0.75, 0.2, 0.7)
	sb.border_width_left = 3
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(14.0, 100.0 + 176.0 + 12.0) # debajo del minimapa: lejos del volante táctil (abajo a la izquierda)
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE # el panel deja pasar los toques: sólo IR y ✕ los toman
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	_icon = Kit.label("", 26, Color.WHITE)
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := Kit.label(Tr.t("PRÓXIMO OBJETIVO"), 11, Kit.GOLD)
	col.add_child(head)
	_title = Kit.label("", 15, Color.WHITE)
	_title.clip_text = true
	_title.custom_minimum_size.x = 190
	col.add_child(_title)
	_sub = Kit.label("", 12, Kit.MUTED)
	_sub.clip_text = true
	_sub.custom_minimum_size.x = 190
	col.add_child(_sub)
	_go = Kit.button(Tr.t("IR"), _on_go, true, 14, Vector2(52, 36))
	row.add_child(_go)
	_x = Kit.button("✕", _on_x, false, 14, Vector2(36, 36))
	row.add_child(_x)
	card.visible = false
	ch.add_child(card)

## Sólo en el mundo abierto sin conexión, con el perfil del jugador (no en pruebas de autos)
func active() -> bool:
	return race != null and race.get("ow_events") != null and race.cfg.get("online", false) != true and race.cfg.get("testCar") == null and race.profile != null

func _ch():
	return race.race_hud.city_hud if race.race_hud != null else null

func _tut() -> Dictionary:
	if not (race.profile.d.get("tutorial") is Dictionary):
		race.profile.d["tutorial"] = {}
	return race.profile.d["tutorial"]

func update(dt: float) -> void:
	if card == null or race.cars.is_empty():
		return
	_clock += dt
	_t -= dt
	var ph = race.cars[0].phys
	var kmh := sqrt(ph.vx * ph.vx + ph.vz * ph.vz) * 3.6
	_fast_t = _fast_t + dt if kmh > FAST_KMH else 0.0
	var busy := _busy()
	# consejos de una sola vez
	if tip_key == "" and not busy:
		var k := _next_tip()
		if k != "":
			tip_key = k
			_tip_t = 0.0
			_show_tip(k)
	if tip_key != "":
		_tip_t += dt
		if _tip_t >= TIP_S:
			_on_go()
	if _t <= 0.0 and tip_key == "":
		_t = REFRESH
		goals = NextGoal.pick(_ctx())
		_show_goal()
	card.visible = not busy and (_fast_t < 3.0 or tip_key != "") and (tip_key != "" or not goals.is_empty())

## ¿Hay algo en curso que no hay que interrumpir?
func _busy() -> bool:
	var ev = race.get("ow_events")
	if ev != null and ev.busy():
		return true
	var pol = race.get("police")
	if pol != null and str(pol.state) == "chase":
		return true
	var md = race.get("modes")
	if md != null:
		if not (md.targets as Array).is_empty():
			return true
		if not (md._reach as Dictionary).is_empty() and int(md._reach.get("run", -1)) >= 0:
			return true
		if not (md._drift as Dictionary).is_empty():
			return true
	return false

func _next_tip() -> String:
	var tut := _tut()
	for k in TIP_ORDER:
		if tut.has(k):
			continue
		match k:
			"start":
				return k
			"gps":
				if _clock > 40.0:
					return k
			"ring":
				if _near_ring():
					return k
			"events":
				var md = race.get("modes")
				if _clock > 150.0 or (md != null and not (md.events as Array).is_empty()):
					return k
			"garage":
				if int(race.profile.credits) >= 12000 and _clock > 60.0:
					return k
			"police":
				var pol = race.get("police")
				if pol != null and float(pol.rage) >= 0.3:
					return k
	return ""

func _near_ring() -> bool:
	var ev = race.get("ow_events")
	if ev == null:
		return false
	var p := Vector2(race.cars[0].phys.px, race.cars[0].phys.pz)
	for e in ev.events:
		if p.distance_to(e["start"]) < 200.0:
			return true
	return false

func _show_tip(k: String) -> void:
	_icon.text = "💡"
	_title.visible = false # (el 💡 ya dice que es un consejo: un renglón menos, lejos del volante)
	_sub.text = Tr.t(str(TIPS[k]))
	_sub.clip_text = false
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size.x = 210
	_sub.max_lines_visible = 3
	_go.text = Tr.t("OK")

func _show_goal() -> void:
	_sub.clip_text = true
	_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sub.max_lines_visible = -1
	_sub.custom_minimum_size.x = 190
	_go.text = Tr.t("IR")
	_title.visible = true
	if goals.is_empty():
		return
	var g: Dictionary = goals[0]
	_icon.text = str(g["icon"])
	_title.text = Tr.t(str(g["title"]))
	_sub.text = Tr.t(str(g["sub"]))
	_go.visible = g.get("pos") is Vector2
	shown[str(g["key"])] = true

func _on_go() -> void:
	if tip_key != "":
		_tut()[tip_key] = true
		race.profile.save()
		tip_key = ""
		_t = 0.0
		return
	if goals.is_empty():
		return
	var g: Dictionary = goals[0]
	var ch = _ch()
	if g.get("pos") is Vector2 and ch != null and ch.has_method("set_dest"):
		ch.set_dest(g["pos"], Tr.t(str(g["title"])))

func _on_x() -> void:
	if tip_key != "":
		_on_go()
		return
	if goals.is_empty():
		return
	dismissed[str(goals[0]["key"])] = _clock + DISMISS_S
	_t = 0.0

## Lo que sabe el juego ahora mismo, para elegir el objetivo
func _ctx() -> Dictionary:
	var p := Vector2(race.cars[0].phys.px, race.cars[0].phys.pz)
	var dis := {}
	for k in dismissed.keys():
		if float(dismissed[k]) > _clock:
			dis[k] = true
		else:
			dismissed.erase(k)
	var evs: Array = []
	var ow = race.get("ow_events")
	if ow != null:
		var sv: Dictionary = race.profile.d.get("owEvents", {}) if race.profile.d.get("owEvents") is Dictionary else {}
		for e in ow.events:
			var id := str(e["id"])
			var r: Dictionary = sv.get(id, {}) if sv.get(id) is Dictionary else {}
			evs.append({"id": id, "name": ow._title(e), "icon": str(e.get("icon", "🏁")), "pos": e["start"], "reward": int(e.get("reward", 0)), "found": r.get("found", false) == true,
				"wins": int(r.get("wins", 0)), "best": r.get("best"), "type": str(e.get("type", ""))})
	var live: Array = []
	var md = race.get("modes")
	if md != null and md._online_ok():
		var now: float = md.now_server()
		for e in md.events:
			if CityModes.phase_of(e, now) == "live" and not bool(e.get("done", false)) and str(e.get("kind", "")) != "season":
				live.append({"id": str(e["id"]), "title": str(e.get("title", "")), "icon": CityModes.kind_icon(str(e.get("kind", ""))), "ends_in": float(e.get("ends", now)) - now, "standing": CityModes.standing_text(e)})
	var fuel_pos = null
	var fl = race.get("fuel")
	var city = race.track.city if race.track != null else null
	if city != null:
		var bd := 1e18
		for st in city.stations:
			for fp in st["fuel_points"]:
				var d := p.distance_squared_to(fp)
				if d < bd:
					bd = d
					fuel_pos = fp
	var dealer_pos = null
	if city != null:
		var bd2 := 1e18
		for po in city.pois:
			if str(po.get("kind", "")) == "dealer":
				var d2 := p.distance_squared_to(po["pos"])
				if d2 < bd2:
					bd2 = d2
					dealer_pos = po["pos"]
	return {"pos": p, "fuel": float(fl.level) if fl != null else 1.0, "credits": int(race.profile.credits), "events": evs, "live": live,
		"next_car": next_car(race.profile), "fuel_pos": fuel_pos, "dealer_pos": dealer_pos, "dismissed": dis}

## El auto más barato que todavía no tenés y que se compra con plata del juego (ni premium ni premios ni especiales)
static func next_car(profile) -> Dictionary:
	var cat: Dictionary = CarBuild.catalog()
	var cars: Dictionary = cat["cars"]
	var cur_price := 0
	var cur_id := str(profile.d.get("current", ""))
	if cars.has(cur_id):
		cur_price = int(cars[cur_id].get("price", 0))
	var best := {}
	for id in cars:
		var c: Dictionary = cars[id]
		if profile.owns(str(id)) or c.get("special", false) == true or Release.REWARD_CARS.has(str(id)) or Release.PREMIUM_CARS.has(str(id)):
			continue
		var price := int(c.get("price", 0))
		if price <= cur_price:
			continue
		if best.is_empty() or price < int(best["price"]):
			best = {"id": str(id), "name": "%s %s" % [str(c.get("brand", "")), str(c.get("model", id))], "price": price}
	return best

## Ayuda (pausa): todos los consejos juntos
func help_text() -> String:
	var lines: Array = [Tr.t("❓ AYUDA")]
	for k in TIP_ORDER:
		lines.append(Tr.t(str(TIPS[k])))
	return "\n".join(lines)
