extends RefCounted
## Sesión de la Red de rutas: sin cuenta regresiva grande, sin meta. Tres modos (cfg["netMode"]):
##  · "free"  — a andar por las rutas, sin nadie.
##  · "chase" — PERSEGUÍS a un rival que va adelante. Si lo dejás a más de `limit` metros, ganás; si lo pasás se invierten los roles.
##  · "flee"  — te PERSIGUE un rival: si te saca más de `limit` metros de ventaja pierde el que va atrás… o sea: quien abre la ventaja `limit` gana.
## La ventaja se mide en línea recta entre los dos autos, con signo: «adelante» es quien tiene al otro a la espalda. Los roles cambian cuando uno pasa al otro
## y se mantiene un par de segundos (así no parpadean en un cruce). El rival maneja con NetDriver: adelante huye por la red, atrás persigue hasta pegarse.
## Mismo molde que CitySession/DriftSession para que race.gd y el HUD la traten igual (rule_text / rule_sub los dibuja RaceHud).

signal beep(k: int)
signal go
signal player_finished(value: float)

const LIMITS := [50.0, 100.0, 150.0, 250.0, 400.0, 600.0]

var state := "run"
var cd := 0.0
var time := 0.0
var type := "net"
var laps := 1
var L := 1.0
var race_len := 1.0e9
var track
var views: Array = []
var prog: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var last_s: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var finished: Array = [false, false]
var finish_time: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var names: Array = ["", ""]
var max_kmh := 0.0
var odo := 0.0
var trap_kmh := 0.0
var last_pos := 1
var messages: Array = []
var hits := 0
# reglas
var mode := "free"
var limit := 150.0
var skill := 0.9
var lead_player := false # ¿el jugador va adelante?
var gap := 0.0 # metros que le lleva el rival al jugador (negativo: el jugador va adelante)
var dist := 0.0 # distancia en línea recta entre los dos
var win := false
var note := ""
var rule_text := ""
var rule_sub := ""
var rule_warn := false
var grace := 3.0 # al arrancar el rival espera unos segundos
var respawn_req := false
var swaps := 0
var pass_t := 0.0
var close_t := 0.0
var _sign_t := 0.0
var _sign := 0
var _go_sent := false
var near_station := -1
var near_station_d := 0.0

func _init(p_track, cfg: Dictionary, _n_cars: int) -> void:
	track = p_track
	mode = str(cfg.get("netMode", "free"))
	limit = float(cfg.get("chaseGap", 150.0))
	skill = float(cfg.get("skill", 0.9))
	reset_chase()

func reset_chase() -> void:
	lead_player = (mode == "flee")
	gap = 0.0
	dist = 0.0
	_sign_t = 0.0
	_sign = 0
	pass_t = 0.0
	close_t = 0.0
	grace = 3.0
	_go_sent = false
	state = "run"

func init_cars(_cars: Array) -> void:
	pass

func standings(_n: int) -> Array:
	return [0]

func position_of(_i: int, _n: int) -> int:
	return 1

func lap_of_player() -> int:
	return 1

func on_wall(speed: float) -> void:
	if speed > 3.0:
		hits += 1

func update(dt: float, cars: Array) -> void:
	messages.clear()
	var ph = cars[0].phys
	var p := Vector2(ph.px, ph.pz)
	if state == "run":
		time += dt
		var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
		max_kmh = maxf(max_kmh, sp * 3.6)
		odo += sp * dt
	near_station = track.net.nearest_station(p)
	near_station_d = p.distance_to(track.net.stations[near_station]["pos"]) if near_station >= 0 else 0.0
	if mode == "free" or cars.size() < 2:
		rule_text = "%s · %.1f km" % [track.title, odo / 1000.0]
		return
	if state != "run":
		return
	_chase(dt, cars, p)

func _chase(dt: float, cars: Array, p: Vector2) -> void:
	var r = cars[1]
	var rp := Vector2(r.phys.px, r.phys.pz)
	var d = r.driver
	dist = p.distance_to(rp)
	# arranque: el rival espera unos segundos (cuenta chica en el aviso)
	if grace > 0.0:
		grace -= dt
		if d != null:
			d.enabled = false
		var k := int(ceil(grace))
		if k <= 3 and k >= 1 and k != int(ceil(grace + dt)):
			messages.append([str(k), "big"])
		if grace <= 0.0:
			messages.append(["¡YA!", "big"])
			if d != null:
				d.enabled = true
		rule_text = "🎯 %s · límite %d m" % ["PERSEGUÍS" if mode == "chase" else "TE PERSIGUEN", int(limit)]
		rule_sub = ""
		return
	# quién va adelante: el que tiene al otro por delante de su trompa (no cambia hasta que se mantenga 1,5 s y a más de 12 m)
	var fwd := Vector2(sin(cars[0].phys.yaw), cos(cars[0].phys.yaw))
	var ahead_rel := (rp - p).dot(fwd) # >0: el rival está delante mío
	var s := 0
	if dist > 12.0:
		s = 1 if ahead_rel > 0.0 else -1 # 1: el rival adelante
	if s != 0 and s == _sign:
		_sign_t += dt
	else:
		_sign = s
		_sign_t = 0.0
	if _sign_t > 1.5:
		var player_ahead := _sign < 0
		if player_ahead != lead_player:
			lead_player = player_ahead
			swaps += 1
			messages.append(["⬆ ¡Lo pasaste! Ahora te persigue", "up"] if lead_player else ["⬇ ¡Te pasó! Ahora lo perseguís", "down"])
			pass_t = 0.0
			close_t = 0.0
			if d != null:
				d.route = PackedVector2Array() # que replanee con el rol nuevo
	gap = -dist if lead_player else dist
	# fin: quien abre la ventaja `limit` gana
	if dist >= limit:
		win = lead_player
		_finish("¡LO DEJASTE ATRÁS!" if win else "¡SE TE ESCAPÓ!", win)
		return
	# el rival: adelante huye por la red; atrás te persigue por la red
	if d != null:
		var diff := clampf((skill - 0.62) / 0.42, 0.0, 1.0)
		var base := lerpf(0.88, 1.0, diff)
		if lead_player:
			d.mode = "pursue"
			d.target_pos = p
			var pace := base + clampf((dist - 14.0) / 50.0, 0.0, 1.0) * 0.14
			if pass_t > 0.0:
				pass_t -= dt
				pace = base + 0.08
			else:
				close_t = close_t + dt if dist < 30.0 else maxf(0.0, close_t - dt)
				if close_t > lerpf(22.0, 9.0, diff):
					pass_t = 8.0
					close_t = 0.0
			d.pace = lerpf(d.pace, pace, clampf(dt * 1.5, 0.0, 1.0))
		else:
			d.mode = "wander"
			d.flee_from = p
			# adelante: si ya se te escapa mucho afloja un poco (para que se pueda alcanzar), si lo tenés pegado aprieta
			var pace2 := base * (1.0 - clampf((dist - 0.5 * limit) / limit, 0.0, 0.25))
			d.pace = lerpf(d.pace, pace2, clampf(dt * 1.2, 0.0, 1.0))
	# texto del HUD
	var frac := dist / limit
	rule_text = "🎯 %s · %d / %d m" % ["VAS ADELANTE" if lead_player else "PERSEGUÍS", int(dist), int(limit)]
	if not lead_player and frac > 0.66:
		rule_sub = "⚠ ¡SE ESCAPA! %d m" % int(dist)
		rule_warn = true
	elif lead_player and frac > 0.66:
		rule_sub = "¡Casi lo dejás atrás! %d m" % int(dist)
		rule_warn = false
	else:
		rule_sub = ""
		rule_warn = false

func _finish(text: String, p_win: bool) -> void:
	win = p_win
	note = text
	rule_text = text
	rule_sub = ""
	state = "done"
	finished[0] = true
	finish_time[0] = time
	messages.append([text, "big"])
