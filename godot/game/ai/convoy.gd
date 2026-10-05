extends RefCounted
## El convoy de la Travesía X: los autos y camiones van en fila a su ritmo y el jugador tiene que ir con ellos.
##  · Cada auto de la fila sigue al de adelante (el jugador cuenta como un auto más): mantiene una distancia y copia su velocidad.
##  · El primero va todo lo fuerte que le deja el camino si el grupo está junto (si el jugador acelera, ellos también), y afloja si el último se queda
##    (te esperan), pero nunca baja de un ritmo mínimo: si andás muy lento los perdés.
##  · Se pierde el convoy si el jugador queda a más de LOSE_GAP del primero del grupo (adelante o atrás) durante LOSE_TIME. Al llegar a la meta hay que haber llegado con ellos.
## No dibuja nada: race.gd le pasa la sesión y los autos; el HUD lee `text`, `warn` y `lost`.

const FOLLOW_GAP := 26.0 # metros entre autos de la fila
const FOLLOW_K := 0.30 # 1/s: cuánto acelera por cada metro de más que lo separa del de adelante
const LEAD_MIN := 5.0 # m/s: lo mínimo cuando espera a un rezagado (18 km/h): más lento que eso y el jugador los pierde
## Velocidad máxima del primero en cada tramo (m/s) con el grupo junto: rápidos (bosque, valle, cresta) y lentos (barro, pedregal, vado, zigzag)
const SECTION_CAP := {"largada": 9.0, "bosque": 12.0, "barro1": 5.0, "pedregal": 4.4, "valle": 12.5, "vado": 4.0, "orilla": 7.5, "ascenso": 6.0, "cresta": 11.0, "descenso": 7.2, "barro2": 5.0, "final": 10.5}
const WARN_GAP := 140.0
const LOSE_GAP := 280.0
const LOSE_TIME := 9.0

var cars: Array = []
var session
var lost := false
var warn := false
var out_gap := 0.0 # metros que lo separan del primero del convoy (adelante o atrás)
var out_t := 0.0
var near_t := 0.0 # tiempo que estuvo a menos de 100 m del grupo
var total_t := 0.0
var text := ""
var lead_speed := 0.0
var section := "" # tramo en el que va el jugador
var section_new := "" # se llena un cuadro cuando entra a un tramo nuevo (el HUD lo muestra)
var _tick := 0.0

const SECTION_NAMES := {"largada": "🏁 LARGADA", "bosque": "🌲 BOSQUE RÁPIDO", "barro1": "🟤 BARRIAL", "pedregal": "🪨 PEDREGAL", "valle": "🌾 VALLE ABIERTO",
	"vado": "🌊 EL VADO DEL LAGO", "orilla": "🏖 ORILLA", "ascenso": "⛰ ASCENSO EN ZIGZAG", "cresta": "🌄 LA CRESTA", "descenso": "💨 BAJADA SUELTA",
	"barro2": "🟤 BARRO FINAL", "final": "🏁 RECTA FINAL"}

func setup(p_cars: Array, p_session) -> void:
	cars = p_cars
	session = p_session

func cohesion() -> float:
	return near_t / maxf(total_t, 1.0)

static func _speed(c) -> float:
	return sqrt(c.phys.vx * c.phys.vx + c.phys.vz * c.phys.vz)

## Cuadro de simulación (no hace falta cada cuadro: 20 Hz alcanza)
func update(dt: float) -> void:
	if session == null or session.state != "run" or lost:
		return
	_tick += dt
	if _tick < 0.05:
		return
	var h := _tick
	_tick = 0.0
	var n := cars.size()
	# fila ordenada de adelante hacia atrás (el jugador es el 0)
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return session.prog[a] > session.prog[b])
	var hi := -1e18
	for i in range(1, n):
		hi = maxf(hi, session.prog[i])
	var p0: float = session.prog[0]
	out_gap = absf(hi - p0) # distancia al primero del convoy (si el jugador va adelante de todos, al que lo sigue más de cerca)
	# el primero marca el ritmo según qué tan junto está el grupo (el último de la fila es quien lo retiene)
	var tail_p := 1e18
	for i in n:
		tail_p = minf(tail_p, session.prog[i])
	var group_gap := (hi if hi > p0 else p0) - tail_p
	var lead_i: int = int(order[0])
	var sec_cap := _section_cap(int(session.views[lead_i].r_idx) if lead_i >= 0 else 0)
	var lead_cap := _lead_cap(group_gap, sec_cap)
	for r in n:
		var i: int = int(order[r])
		if i == 0:
			continue
		var d = cars[i].driver
		if d == null:
			continue
		if r == 0:
			d.max_v = lerpf(d.max_v if d.max_v > 0.0 else lead_cap, lead_cap, clampf(h * 1.5, 0.0, 1.0))
			lead_speed = _speed(cars[i])
		else:
			var a: int = int(order[r - 1])
			var gap: float = session.prog[a] - session.prog[i]
			var want := FOLLOW_GAP + 4.0 * float(i % 3)
			var v_target := _speed(cars[a]) + FOLLOW_K * (gap - want)
			if gap < want * 0.6:
				v_target = minf(v_target, _speed(cars[a]) * 0.85) # muy pegado: afloja
			d.max_v = lerpf(d.max_v if d.max_v > 0.0 else v_target, clampf(v_target, 2.0, 30.0), clampf(h * 3.0, 0.0, 1.0))
	# tramo del jugador (cartel al entrar)
	var pi: int = session.views[0].r_idx
	for sc in session.track.sections:
		if pi >= int(sc["i0"]) and pi <= int(sc["i1"]):
			if str(sc["name"]) != section:
				section = str(sc["name"])
				section_new = str(SECTION_NAMES.get(section, section.to_upper()))
			break
	# ¿el jugador sigue con el grupo?
	total_t += h
	if out_gap < 100.0:
		near_t += h
	warn = out_gap > WARN_GAP
	if out_gap > LOSE_GAP:
		out_t += h
		if out_t >= LOSE_TIME:
			lost = true
	else:
		out_t = maxf(0.0, out_t - h * 2.0)
	if lost:
		text = "PERDISTE AL CONVOY"
	elif warn:
		var behind: bool = p0 < hi
		text = "%s · %d m · %d s" % ["¡ALCANZALOS!" if behind else "¡ESPERÁ AL CONVOY!", int(out_gap), maxi(0, int(ceil(LOSE_TIME - out_t)))]
	else:
		text = ""

## Velocidad tope del primero (m/s): máxima con el grupo junto; baja hasta el mínimo cuando el último se queda lejos
static func _lead_cap(group_gap: float, sec_cap: float) -> float:
	var t := clampf((group_gap - 60.0) / 200.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(sec_cap, minf(sec_cap, LEAD_MIN), t)

## Tope del tramo donde está la muestra idx
func _section_cap(idx: int) -> float:
	for sc in session.track.sections:
		if idx >= int(sc["i0"]) and idx <= int(sc["i1"]):
			return float(SECTION_CAP.get(str(sc["name"]), 12.0))
	return 12.0
