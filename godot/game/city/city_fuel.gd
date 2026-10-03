extends RefCounted
## Nafta de Dream City. El tanque dura mucho (unos 80 km manejando normal), se guarda en el perfil y se carga en las gasolineras: frenás sobre un círculo verde, la carga tarda
## unos segundos y se paga con créditos. Si se acaba el auto no acelera, pero se avisa antes (y el GPS marca la gasolinera más cercana) para no andar mirando el tanque.

const Tr := preload("res://game/i18n/tr.gd")
const CityNames := preload("res://game/city/city_names.gd")
const Release := preload("res://game/data/release.gd")

const PER_M := 1.0 / 80000.0 # fracción del tanque por metro a gas medio
const PRICE_FULL := 120.0 # créditos de un tanque entero (1 por cada 1 %)
const FAST_PRICE_K := 1.3 # la carga rápida cuesta un 30 % más...
const TOLL_PASSES := 2 # ...y regala un pase: los dos próximos peajes a mitad de precio
const R_IN := 3.2 # radio del círculo verde (m)
const R_OUT := 5.5 # si te alejás tanto la carga se corta
const LOW := 0.15
const EMERGENCY := 0.08 # sin nafta ni créditos: una ayuda para volver a andar

var race
var city
var level := 1.0
var refueling := false
var progress := 0.0 # 0..1 de la carga en curso
var _target := 0.0
var _from := 0.0
var _rate := 0.0 # fracción del tanque por segundo
var _hold := 0.0
var _armed := true
var _saved_t := 0.0
var _warned_low := false
var _warned_empty := false
var _free := false # esta carga no se cobra (modo desarrollador o ayuda de emergencia)
var _near_fast := false # el último punto de carga encontrado es de carga rápida
var _fast := false # la carga en curso es de la gasolinera de carga rápida

func setup(p_race, p_city) -> void:
	race = p_race
	city = p_city
	level = clampf(float(race.cfg.get("fuel", race.profile.d.get("fuel", 1.0))), 0.0, 1.0)
	_warned_low = level < LOW
	_warned_empty = empty()

func empty() -> bool:
	return level <= 0.0005

## el acelerador no responde con el tanque vacío ni mientras se carga
func blocks_throttle() -> bool:
	return empty() or refueling

func _hud():
	return race.race_hud.city_hud

func _nearest_station() -> Dictionary:
	var best := {}
	var bd := 1e18
	var pos := Vector2(race.cars[0].phys.px, race.cars[0].phys.pz)
	for p in city.pois:
		if str(p["kind"]) != "fuel":
			continue
		var d := pos.distance_squared_to(p["pos"])
		if d < bd:
			bd = d
			best = p
	return best

func _toast(s: String, kind := "") -> void:
	race.race_hud.toast(s, kind)

func update(dt: float) -> void:
	if race.cars.is_empty():
		return
	var ph = race.cars[0].phys
	var pos := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	if ph.px > 3000.0:
		return # bajo tierra (túnel, estacionamiento): no se gasta
	if refueling:
		_refuel_step(dt, pos, spd)
	else:
		# consumo: más con el acelerador a fondo, casi nada al soltarlo
		var th := clampf(float(race.controls.gas), 0.0, 1.0)
		level = maxf(0.0, level - spd * dt * PER_M * (0.35 + 1.3 * th))
		if level < LOW and not _warned_low:
			_warned_low = true
			var st := _nearest_station()
			if not st.is_empty():
				_toast(Tr.t("⛽ Poca nafta: GPS a %s") % CityNames.t(str(st["name"])), "down")
				if _hud() != null and not _hud().has_dest:
					_hud().set_dest(st["pos"], CityNames.t(str(st["name"])))
		if empty() and not _warned_empty:
			_warned_empty = true
			_toast(Tr.t("⛽ ¡Sin nafta! Llegá a una gasolinera"), "down")
		_try_start(dt, pos, spd)
	if _hud() != null:
		_hud().set_fuel(level, progress if refueling else -1.0)
	_saved_t += dt
	if _saved_t > 10.0:
		save()

func save() -> void:
	_saved_t = 0.0
	race.profile.d["fuel"] = level
	if race.clock != null:
		race.clock.save() # (la hora del día se guarda junto con la nafta)
	race.profile.save()

## el punto de carga (círculo verde) más cercano de las gasolineras, o muy lejos si no hay ninguno a mano
func _station_point(pos: Vector2) -> Vector2:
	for st in city.stations:
		for fp in st["fuel_points"]:
			if pos.distance_to(fp) < R_OUT + 1.0:
				_near_fast = bool(st["fast"])
				return fp
	return Vector2(1e9, 1e9)

func _try_start(dt: float, pos: Vector2, spd: float) -> void:
	var fp := _station_point(pos)
	var inside := fp.x < 1e8 and pos.distance_to(fp) < R_IN
	if fp.x > 1e8:
		_armed = true
	if inside and _armed and spd < 2.0 and level < 0.985:
		_hold += dt
		if _hold > 0.4:
			_begin()
	else:
		_hold = 0.0

func _begin() -> void:
	_hold = 0.0
	var afford := 1.0 - level
	_free = Release.dev(race.profile)
	_fast = _near_fast
	var price_full := PRICE_FULL * (FAST_PRICE_K if _fast else 1.0)
	if not _free:
		afford = minf(afford, float(race.profile.credits) / price_full)
		if afford < 0.01:
			if level < 0.02:
				afford = EMERGENCY # sin nafta y sin plata: una ayuda chica para poder seguir
				_free = true
				_toast(Tr.t("⛽ Sin créditos: te regalan un poco de nafta"))
			else:
				_toast(Tr.t("⛽ No te alcanzan los créditos"), "down")
				_armed = false
				return
	refueling = true
	_from = level
	_target = level + afford
	progress = 0.0
	# unos segundos: 1,5 s más 3 s por tanque entero que falte (la carga rápida: 0,6 s más 1,2 s)
	_rate = afford / ((0.6 + 1.2 * afford) if _fast else (1.5 + 3.0 * afford))
	_toast(Tr.t("⛽ Carga rápida…") if _fast else Tr.t("⛽ Cargando…"))

func _refuel_step(dt: float, pos: Vector2, spd: float) -> void:
	var fp := _station_point(pos)
	if fp.x > 1e8 or pos.distance_to(fp) > R_OUT or spd > 3.5:
		_finish()
		return
	level = minf(_target, level + _rate * dt)
	progress = clampf((level - _from) / maxf(_target - _from, 0.0001), 0.0, 1.0)
	if level >= _target - 0.0001:
		_finish()

func _finish() -> void:
	refueling = false
	progress = 0.0
	_armed = false # para cargar de nuevo hay que salir del círculo
	var added := level - _from
	var cost := 0 if _free else int(ceil(added * PRICE_FULL * (FAST_PRICE_K if _fast else 1.0)))
	if cost > 0:
		race.profile.spend(mini(cost, race.profile.credits))
	if level > LOW:
		_warned_low = false
	if level > 0.0:
		_warned_empty = false
	if added > 0.004:
		if cost > 0:
			_toast(Tr.t("⛽ Cargaste %d%% por %d créditos") % [roundi(added * 100.0), cost], "up")
		else:
			_toast(Tr.t("⛽ Cargaste %d%%") % roundi(added * 100.0), "up")
		var h = _hud()
		if h != null and h.has_dest and str(h.route_name) in _station_names():
			h.clear_dest()
	if _fast and added > 0.1:
		race.profile.d["toll_pass"] = TOLL_PASSES
		_toast(Tr.t("🎟 Pase de peaje: los próximos %d peajes a mitad de precio") % TOLL_PASSES, "up")
	save()

func _station_names() -> Array:
	var out := []
	for st in city.stations:
		out.append(CityNames.t(str(st["name"])))
	return out
