extends RefCounted
## La Plaza de Drift del mundo abierto (al final de la Ruta 60): conos con física y puntaje de derrape mientras el auto está adentro. Es la misma cuenta que drift_session.gd
## (velocidad × ángulo × multiplicador, combo hasta ×5, chocar pierde el derrape, un cono golpeado baja el multiplicador) pero sin cuenta regresiva ni tiempo límite: se derrapa cuando se quiere.

const ConeField := preload("res://game/track/cone_field.gd")
const Tr := preload("res://game/i18n/tr.gd")

var race
var city
var cones: ConeField
var c := Vector2.ZERO
var r := 90.0
var total := 0.0 # puntos cobrados en esta visita
var cur := 0.0
var mult := 1
var combo := 0.0
var idle := 0.0
var inside := false
var active := false # el auto está en la plaza (se actualizan los conos y el puntaje)

func setup(p_race, p_world: Node, p_city) -> void:
	race = p_race
	city = p_city
	if city.drift.is_empty():
		return
	c = city.drift["c"]
	r = float(city.drift["r"])
	cones = ConeField.new()
	cones.setup(city.drift["cones"])
	cones.position.y = float(city.drift["h"]) # la plaza es plana: los conos se apoyan a esa altura
	p_world.add_child(cones)
	active = true

func update(dt: float) -> void:
	if cones == null or race.cars.is_empty():
		return
	var ph = race.cars[0].phys
	var d := Vector2(ph.px, ph.pz).distance_to(c)
	inside = d < r - 1.0
	if d > r + 40.0:
		if cur > 0.0:
			_bank()
		return # lejos de la plaza: los conos no se calculan
	cones.update(dt, race.cars)
	if cones.new_hits > 0:
		_on_cones(cones.new_hits)
		cones.new_hits = 0
	var hud = race.race_hud
	if not inside:
		if cur > 0.0:
			_bank()
		hud.drift_l.text = ""
		return
	var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	var beta := absf(atan2(ph.vLat, maxf(0.5, absf(ph.vLong))))
	var drifting: bool = sp > 6.0 and beta > 0.17 and beta < 1.7 and ph.contacts >= 2
	if drifting:
		cur += dt * sp * beta * 57.3 * 0.11 * float(mult)
		combo += dt
		idle = 0.0
		var nm := mini(5, 1 + int(floor(combo / 2.2)))
		if nm > mult:
			mult = nm
			hud.toast(Tr.t("x%d COMBO") % mult, "up")
	else:
		idle += dt
		if idle > 0.8 and cur > 0.0:
			_bank()
	if cur > 0.0:
		hud.drift_l.text = "%d  ·  %d°" % [roundi(cur), int(rad_to_deg(beta))]
		hud.drift_l.add_theme_color_override("font_color", [Color(0.55, 0.85, 1.0), Color(0.55, 0.85, 1.0), Color(1.0, 0.9, 0.4), Color(1.0, 0.7, 0.25), Color(1.0, 0.5, 0.2), Color(1.0, 0.35, 0.3)][clampi(mult, 0, 5)])
	else:
		hud.drift_l.text = ""

func _bank() -> void:
	var pts := roundf(cur)
	if pts > 0.0:
		total += pts
		var prof = race.profile
		if prof != null:
			var st: Dictionary = prof.d["stats"]
			if pts > float(st.get("driftBest", 0)):
				st["driftBest"] = pts
				prof.save()
		if pts > 600.0:
			race.race_hud.toast(Tr.t("🌀 +%d pts") % int(pts), "up")
	cur = 0.0
	mult = 1
	combo = 0.0

func on_wall(speed: float) -> void:
	if not inside or speed < 2.0 or cur <= 0.0:
		return
	race.race_hud.toast(Tr.t("💥 Chocaste: perdiste el derrape"), "down")
	cur = 0.0
	mult = 1
	combo = 0.0
	idle = 0.0

func _on_cones(k: int) -> void:
	if mult > 1 and k > 0:
		mult -= 1
		combo = float(mult - 1) * 2.2
		race.race_hud.toast(Tr.t("Cono: multiplicador x%d") % mult, "down")
