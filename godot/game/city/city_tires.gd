extends RefCounted
## Desgaste de gomas en Dream City (Etapa 13): mide cómo se maneja (distancia, curvas, frenadas, derrapes, superficie), suma desgaste al juego de gomas puesto, lo guarda en el perfil
## (por juego de gomas: cada neumático comprado conserva su propio desgaste) y le baja el agarre a la física. Se cambian en el taller de ruedas. Sólo offline: el desgaste online lo
## guardará el servidor (instancias de autos online; ver docs/ECONOMIA_ONLINE.md).

const TireWear := preload("res://game/car/tire_wear.gd")
const Tr := preload("res://game/i18n/tr.gd")

const STEP := 0.1 # s entre cálculos
const APPLY_DELTA := 0.004 # el agarre se reaplica cuando el desgaste cambió esto

var race
var active := false
var wear := 0.0
var tire_id := "street"
var _acc := 0.0
var _save_t := 0.0
var _base_surf := PackedFloat64Array()
var _applied := -1.0
var _warned := 0

func setup(p_race) -> void:
	race = p_race
	active = false
	if race.profile == null or race.cars.is_empty() or race.cfg.get("online", false) == true or race.cfg.get("testCar") != null:
		return
	var st: Dictionary = race.profile.car()
	if st.is_empty():
		return
	active = true
	tire_id = str(st.get("tires", "street"))
	wear = float((st.get("tireWear", {}) as Dictionary).get(tire_id, 0.0))
	var V = race.cars[0].phys.V
	_base_surf = (V.surfGrip as PackedFloat64Array).duplicate()
	_warned = TireWear.warn_level(wear)
	_apply(true)

func _apply(force := false) -> void:
	if absf(wear - _applied) < APPLY_DELTA and not force:
		return
	_applied = wear
	var V = race.cars[0].phys.V
	var k := TireWear.grip_factor(tire_id, wear)
	var sg := PackedFloat64Array()
	sg.resize(_base_surf.size())
	for i in _base_surf.size():
		sg[i] = _base_surf[i] * k
	V.surfGrip = sg

func update(dt: float) -> void:
	if not active or race.cars.is_empty():
		return
	_acc += dt
	if _acc < STEP:
		return
	var h := _acc
	_acc = 0.0
	var ph = race.cars[0].phys
	if ph.px > 3000.0:
		return # bajo tierra: no se gasta
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	var asphalt: bool = true
	if ph.wheels.size() > 0:
		asphalt = int(ph.wheels[0].surf) <= 0
	wear = clampf(wear + TireWear.wear_step(tire_id, spd, float(ph.aLat), float(ph.aLong), float(ph.slip), asphalt, h), 0.0, 1.0)
	_apply()
	var w := TireWear.warn_level(wear)
	if w > _warned:
		_warned = w
		race.race_hud.toast(Tr.t("🛞 ¡Gomas casi lisas! Cambialas en un taller de ruedas") if w >= 2 else Tr.t("🛞 Las gomas están gastadas: pierden agarre"), "down")
	_save_t += h
	if _save_t > 10.0:
		save()
	var hud = race.race_hud.city_hud
	if hud != null:
		hud.tire_txt = "🛞 %d%%" % roundi((1.0 - wear) * 100.0)

func save() -> void:
	_save_t = 0.0
	if not active:
		return
	var st: Dictionary = race.profile.car()
	if st.is_empty():
		return
	var tw: Dictionary = st.get("tireWear", {})
	tw[tire_id] = wear
	st["tireWear"] = tw
	# (el perfil se guarda junto con la nafta: ver CityFuel.save)

func tire_text() -> String:
	return "🛞 %d%%" % roundi((1.0 - wear) * 100.0)
