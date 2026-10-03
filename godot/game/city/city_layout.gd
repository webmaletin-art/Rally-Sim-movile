extends RefCounted
## Dream City, el mundo abierto: la ciudad se genera igual en todos los teléfonos a partir de una semilla (el online depende de eso: todos ven las mismas
## calles, edificios y salidas en las mismas coordenadas). Es un laberinto de calles: una plaza redonda en el centro, ocho avenidas que salen de ella, anillos
## que las cruzan, calles secundarias entre medio, una costanera sobre el mar, un camino con curvas que sube a una colina y cuatro rutas rurales que salen de
## la ciudad y terminan en una «Salida» numerada (para conectar con otras ciudades).
## Ejes: x al este, z al sur (el norte es −z). Todo se mide en metros. El suelo de todo el mundo es la función height(x, z): las calles se apoyan en ella.
##
## Numeración: avenidas «Avenida 1…8» (de este a oeste girando hacia el sur), anillos «Calle 10, 20 … 80», secundarias «Calle 101…108» y «Calle 201…216»,
## costanera «Costanera 90», colina «Camino de la Colina 300», rutas «Ruta 20 / 40 / 60 / 80» (el número de la Salida donde terminan).
## Cada calle se mide en cuadras de 100 m: locate(x, z) dice en qué calle y cuadra estás.

const CELL := 160.0 # lado de una cuadra de carga (la unidad de la carga por trozos)
const STEP := 8.0 # distancia entre puntos de una calle
const PLAZA_R := 48.0
const PARK_R := 44.0 # radio de la calle que rodea al Parque del Drift
const AVE := [[12.0, 1.0], [30.0, 1.0], [9.0, 2.0], [36.0, 1.0], [14.0, 2.0], [26.0, 1.0], [10.0, 2.0], [32.0, 1.0]] # por avenida: [desvío máximo (m), vueltas de curva cada 260 m]: no todas salen igual
const GRID_A0 := 135.0 # el barrio de manzanas cuadradas ocupa el sector entre la avenida 4 (135°) y la 5 (180°)
const GRID_A1 := 180.0
const POCKET := Vector2(6000.0, 0.0) # centro del túnel en cruz: un «bolsillo» del mundo, lejos de la ciudad (se entra y se sale por las bocas, con un fundido)
const HALL_C := Vector2(6000.0, 3000.0) # centro del estacionamiento subterráneo (otro bolsillo)
const HALL_R := 42.0
const TUNNEL_HALF := 900.0 # cada brazo de la cruz mide 900 m desde el centro
const RINGS := [130.0, 260.0, 390.0, 520.0, 650.0, 780.0, 910.0, 1040.0]
const COAST_R := 1120.0
const RURAL_END := 2300.0
const HILL_C := Vector2(-1086.0, -1086.0) # centro de la colina (al noroeste)
const HILL_R := 430.0
const HILL_H := 72.0
const SEA_Z := 1260.0

const WALLS := [Color(0.93, 0.78, 0.52), Color(0.96, 0.90, 0.76), Color(0.82, 0.47, 0.34), Color(0.93, 0.70, 0.66), Color(0.70, 0.80, 0.88),
	Color(0.72, 0.86, 0.76), Color(0.95, 0.94, 0.92), Color(0.70, 0.38, 0.30), Color(0.88, 0.78, 0.64), Color(0.98, 0.84, 0.55)]
const OLD_WALLS := [Color(0.96, 0.66, 0.52), Color(0.98, 0.80, 0.62), Color(0.97, 0.90, 0.74), Color(0.94, 0.62, 0.60), Color(0.99, 0.86, 0.70), Color(0.90, 0.72, 0.56), Color(0.96, 0.78, 0.74)]
const ROOFS := [Color(0.72, 0.34, 0.24), Color(0.62, 0.30, 0.22), Color(0.55, 0.50, 0.48), Color(0.78, 0.45, 0.30)]

var seed_v := 20261004
var roads: Array = [] # {id, name, num, kind, hw, sw, pts (x,y,z cada STEP), cum, nj (cerca de un cruce: PackedByteArray)}
var junctions: Array = [] # {pos: Vector2, y, roads: [ids], major: bool}
var pois: Array = [] # {id, kind, name, pos, yaw, size, color}
var exits: Array = [] # {num, name, pos, yaw, road}
var buildings: Dictionary = {} # Vector2i (cuadra) -> Array de {x, z, y, yaw, w, d, h, wall: Color, roof: Color, kind, seed, hip}
var building_count := 0
# bocas de túnel y estacionamiento: lugares donde el auto «pasa» a otro lado (con un fundido a negro)
var links: Array = [] # {id, pos: Vector2, r: float, to: [x, z, yaw], label: String}
var mouths: Array = [] # estructuras de entrada: {id, pos: Vector2, dir: Vector2 (hacia adentro de la boca), kind: "tunnel" | "park"}
var halls: Array = [] # {pos, r, h}
# objetos de la calle (farolas, árboles, semáforos, bolardos): el id es el índice; salen igual en todos los teléfonos
var prop_type := PackedByteArray()
var prop_x := PackedFloat32Array()
var prop_z := PackedFloat32Array()
var prop_y := PackedFloat32Array()
var prop_yaw := PackedFloat32Array()
var prop_seed := PackedFloat32Array()
var props_in: Dictionary = {} # Vector2i (cuadra) -> PackedInt32Array de ids

# índice espacial de los puntos de las calles
var s_x := PackedFloat32Array()
var s_y := PackedFloat32Array()
var s_z := PackedFloat32Array()
var s_road := PackedInt32Array()
var s_next := PackedInt32Array() # siguiente punto de la misma calle (−1 = el último)
var s_prev := PackedInt32Array() # punto anterior (−1 = el primero)
var _hash: Dictionary = {}
const HC := 32.0

var _rng := RandomNumberGenerator.new()

# ───────────────────────── el suelo de todo el mundo ─────────────────────────
## Altura del terreno en (x, z): una meseta (la ciudad), el mar al sur, lomas suaves afuera y una colina al noroeste
func height(x: float, z: float) -> float:
	if x > 3000.0:
		return 0.0 # el bolsillo de los túneles y del estacionamiento es plano
	var r := sqrt(x * x + z * z)
	var h := 9.0 * smoothstep(SEA_Z, SEA_Z - 220.0, z)
	h += 1.4 * sin(x * 0.0021 + 1.0) * cos(z * 0.0017)
	var d := Vector2(x, z).distance_to(HILL_C)
	var out := smoothstep(1100.0, 1500.0, r) * smoothstep(HILL_R, HILL_R + 300.0, d) # las lomas de afuera no se meten en la colina
	h += out * (11.0 * sin(x * 0.0031 + z * 0.0023) + 6.0 * sin(x * 0.0057 - z * 0.0049 + 2.0))
	h -= 12.0 * smoothstep(SEA_Z + 40.0, SEA_Z + 260.0, z) # el fondo del mar
	if d < HILL_R:
		h += HILL_H * (1.0 - d / HILL_R)
	return h

## Zona de la ciudad (decide la altura y el estilo de los edificios): 0 centro · 1 intermedio · 2 barrio · 3 costa · 4 colina · 5 afuera
func zone_of(x: float, z: float) -> int:
	var r := sqrt(x * x + z * z)
	if Vector2(x, z).distance_to(HILL_C) < HILL_R + 60.0:
		return 4
	if r > 1180.0:
		return 5
	if z > 760.0 and absf(x) < 900.0:
		return 3
	if r < 400.0:
		return 0
	if r < 800.0:
		return 1
	return 2

# ───────────────────────── armado ─────────────────────────
func build() -> void:
	_rng.seed = seed_v
	_make_roads()
	_index()
	_mark_junction_samples()
	_place_pois()
	_place_facades()
	_place_props()

func _sample_road(id: int, name_s: String, num: int, kind: String, hw: float, sw: float, plan: PackedVector2Array) -> void:
	var pts := PackedVector3Array()
	var cum := PackedFloat32Array()
	var acc := 0.0
	for i in plan.size():
		var p := plan[i]
		pts.append(Vector3(p.x, height(p.x, p.y), p.y))
		if i > 0:
			acc += plan[i - 1].distance_to(p)
		cum.append(acc)
	roads.append({"id": id, "name": name_s, "num": num, "kind": kind, "hw": hw, "sw": sw, "pts": pts, "cum": cum, "nj": PackedByteArray()})

func _radial(r0: float, r1: float, ang: float, amp: float, phase: float, mul := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var dirv := Vector2(cos(ang), sin(ang))
	var per := Vector2(-sin(ang), cos(ang))
	var r := r0
	while r < r1 + 0.01:
		# el desvío es cero en cada múltiplo de 130 m (donde cruzan los anillos): los cruces caen justo en los puntos previstos
		var off := amp * sin(mul * PI * r / 130.0 + phase)
		out.append(dirv * r + per * off)
		r += STEP
	return out

func _ring(radius: float, a0: float, a1: float, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := int(ceil(absf(a1 - a0) * radius / STEP))
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		var rr := radius + amp * radius * 0.0067 * sin(32.0 * a) # cero en cada múltiplo de 11,25° (donde cruzan las radiales); la ondulación sigue al radio
		out.append(Vector2(cos(a), sin(a)) * rr)
	return out

## Eje de la ruta rural k (0 = este, 4 = oeste, 6 = norte, 7 = nordeste) a r metros de la plaza: al principio recta y después ondula
func _rural_pos(k: int, r: float) -> Vector2:
	var ang := float(k) * PI / 4.0
	var dirv := Vector2(cos(ang), sin(ang))
	var per := Vector2(-sin(ang), cos(ang))
	var ph := float(k) * 1.7
	var t := smoothstep(1040.0, 1300.0, r)
	var off := t * (70.0 * sin((r - 1040.0) / 230.0 + ph) + 26.0 * sin((r - 1040.0) / 83.0 + ph * 2.0))
	return dirv * r + per * off

## Camino ondulado de a hasta b (curvas de a un lado y al otro, nulas en las puntas) que se pasa 2,5 m de cada punta para cruzar la calle de ahí
func _wavy(a: Vector2, b: Vector2, amp: float, wl: float, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var dv := b - a
	var len := dv.length()
	var dn := dv / len
	var per := Vector2(-dn.y, dn.x)
	var n := int(ceil(len / STEP))
	for i in n + 1:
		var d := len * float(i) / float(n)
		var env := smoothstep(0.0, 70.0, d) * smoothstep(0.0, 70.0, len - d)
		out.append(a + dn * d + per * (amp * env * sin(TAU * d / wl + phase)))
	out[0] -= dn * 2.5
	out[out.size() - 1] += dn * 2.5
	return out

func _in_grid_sector(deg: float) -> bool:
	return deg > GRID_A0 and deg < GRID_A1

## Posición del eje de la avenida k (0..7) a r metros de la plaza (el mismo cálculo de _radial)
func _avenue_pos(k: int, r: float) -> Vector2:
	var ang := float(k) * PI / 4.0
	var off := float(AVE[k][0]) * sin(float(AVE[k][1]) * PI * r / 130.0)
	return Vector2(cos(ang), sin(ang)) * r + Vector2(-sin(ang), cos(ang)) * off

## ¿El punto está entre la avenida 4 y la 5? (con margen: negativo = hasta el eje de la avenida, así la calle la cruza)
func _in_grid(p: Vector2, margin_m: float) -> bool:
	var r := p.length()
	if r < 230.0 or r > 1030.0:
		return false
	var a := rad_to_deg(atan2(p.y, p.x))
	if a < 0.0:
		a += 360.0
	var a0 := rad_to_deg(atan2(_avenue_pos(3, r).y, _avenue_pos(3, r).x)) + rad_to_deg(margin_m / r)
	var a1 := rad_to_deg(atan2(_avenue_pos(4, r).y, _avenue_pos(4, r).x)) - rad_to_deg(margin_m / r)
	if a1 < 0.0:
		a1 += 360.0
	return a > a0 and a < a1

## Barrio de manzanas cuadradas (calles en grilla): otro estilo de ciudad, distinto de los anillos y las avenidas
func _make_grid(id: int) -> int:
	var ang := deg_to_rad((GRID_A0 + GRID_A1) * 0.5)
	var u := Vector2(cos(ang), sin(ang))
	var v := Vector2(-sin(ang), cos(ang))
	var num := 301
	var lines: Array = []
	for i in range(-5, 6): # paralelas al eje del sector
		var pts := PackedVector2Array()
		var runs: Array = []
		var s_ := 230.0
		while s_ < 1040.0:
			var p := u * s_ + v * (float(i) * 96.0)
			if _in_grid(p, -1.0):
				pts.append(p)
			elif pts.size() > 0:
				runs.append(pts)
				pts = PackedVector2Array()
			s_ += STEP
		if pts.size() > 0:
			runs.append(pts)
		lines.append_array(runs)
	for j in range(0, 9): # transversales
		var pts := PackedVector2Array()
		var runs: Array = []
		var t := -620.0
		while t < 620.0:
			var p := u * (300.0 + float(j) * 88.0) + v * t
			if _in_grid(p, -1.0):
				pts.append(p)
			elif pts.size() > 0:
				runs.append(pts)
				pts = PackedVector2Array()
			t += STEP
		if pts.size() > 0:
			runs.append(pts)
		lines.append_array(runs)
	for ln in lines:
		if (ln as PackedVector2Array).size() < 8:
			continue
		_sample_road(id, "Calle %d" % num, num, "minor", 3.8, 2.2, ln)
		id += 1
		num += 1
	return id

## Parque del Drift: una plaza redonda abierta (se maneja por adentro) con una calle alrededor y edificios que la cierran
func _make_park(id: int) -> int:
	var cen := Vector2(cos(deg_to_rad(22.5)), sin(deg_to_rad(22.5))) * 195.0
	var pl := PackedVector2Array()
	var n := int(ceil(TAU * PARK_R / STEP))
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pl.append(cen + Vector2(cos(a), sin(a)) * PARK_R)
	_sample_road(id, "Parque del Drift", 0, "plaza", 5.0, 2.5, pl)
	roads[roads.size() - 1]["center"] = cen
	open_areas.append({"pos": cen, "r": PARK_R, "name": "Parque del Drift", "paving": true})
	id += 1
	# una calle atraviesa el parque y lo une con los anillos 130 y 260 (la plaza tiene una calle adentro)
	var ang := deg_to_rad(22.5)
	_sample_road(id, "Calle 100", 100, "minor", 4.2, 2.4, _radial(130.0, 260.0, ang, 0.0, 0.0))
	return id + 1

## Túnel subterráneo en cruz: dos calles cubiertas que se cruzan en el centro, con curvas, de 1,8 km cada una. Se entra por cuatro bocas escondidas fuera del centro de la
## ciudad (este, oeste, norte y sur) y se sale por la boca del otro brazo. Es un tubo cerrado (piso, paredes y techo) y no figura en el mapa.
func _make_tunnels(id: int) -> int:
	var ends: Array = [] # por brazo: [punta, dirección hacia afuera]
	for axis in 2:
		var plan := PackedVector2Array()
		var n := int(ceil(2.0 * TUNNEL_HALF / STEP))
		for i in n + 1:
			var sp := -TUNNEL_HALF + 2.0 * TUNNEL_HALF * float(i) / float(n)
			var off := 55.0 * sin(TAU * sp / 760.0 + (0.0 if axis == 0 else 1.1)) * smoothstep(0.0, 140.0, absf(sp)) # cero en el centro: ahí las dos calles se cruzan derecho
			plan.append(POCKET + (Vector2(sp, off) if axis == 0 else Vector2(off, sp)))
		_sample_road(id, "Túnel Oeste-Este" if axis == 0 else "Túnel Norte-Sur", 0, "tunnel", 5.5, 0.0, plan)
		id += 1
		ends.append([plan[0], (plan[0] - plan[1]).normalized()])
		ends.append([plan[plan.size() - 1], (plan[plan.size() - 1] - plan[plan.size() - 2]).normalized()])
	# las cuatro bocas de la superficie: una calle cortita que sale de una ruta (o de la costanera) y termina en la boca
	var spurs: Array = []
	for k in [[0, Vector2(0, -1)], [4, Vector2(0, -1)], [6, Vector2(1, 0)]]:
		var r0 := _rural_pos(int(k[0]), 1150.0)
		spurs.append([r0, k[1]])
	var coast := road_named("Costanera 90")
	var cp: PackedVector3Array = roads[coast]["pts"]
	var cmid := Vector2(cp[cp.size() >> 1].x, cp[cp.size() >> 1].z)
	spurs.append([cmid, Vector2(0, 1)])
	# orden de los brazos: 0 oeste, 1 este, 2 norte, 3 sur (el brazo del eje 1 apunta de norte a sur)
	var names := ["oeste", "este", "norte", "sur"]
	var surf_for := [spurs[1], spurs[0], spurs[2], spurs[3]] # oeste ↔ ruta 40 · este ↔ ruta 20 · norte ↔ ruta 60 · sur ↔ costanera
	var surf_end: Array = []
	for i in 4:
		var st: Vector2 = surf_for[i][0]
		var dr: Vector2 = surf_for[i][1]
		var en := st + dr * 75.0
		var plan := PackedVector3Array()
		var cum_b := PackedFloat32Array()
		var nn := 25
		for j in nn + 1:
			var q := st + dr * (75.0 * float(j) / float(nn))
			plan.append(Vector3(q.x, height(q.x, q.y), q.y))
			cum_b.append(75.0 * float(j) / float(nn))
		roads.append({"id": roads.size(), "name": "Boca del túnel %s" % names[i], "num": 0, "kind": "bay", "hw": 4.2, "sw": 0.0, "pts": plan, "cum": cum_b, "nj": PackedByteArray()})
		var nj_b := PackedByteArray()
		nj_b.resize(plan.size())
		roads[roads.size() - 1]["nj"] = nj_b
		surf_end.append([en, dr, st])
	# enlaces: la boca de la superficie lleva a la punta de su brazo y la punta lleva de vuelta a la boca
	for i in 4:
		var tip: Vector2 = ends[i][0]
		var out_d: Vector2 = ends[i][1]
		var en: Vector2 = surf_end[i][0]
		var dr: Vector2 = surf_end[i][1]
		var st: Vector2 = surf_end[i][2]
		var inward := -out_d
		links.append({"id": "boca_" + names[i], "pos": en - dr * 4.0, "r": 4.5, "to": [tip.x + inward.x * 36.0, tip.y + inward.y * 36.0, atan2(inward.x, inward.y)], "label": ""})
		links.append({"id": "punta_" + names[i], "pos": tip + inward * 13.0, "r": 6.0, "to": [en.x - dr.x * 16.0, en.y - dr.y * 16.0, atan2(-dr.x, -dr.y)], "label": "SALIDA", "label_pos": tip, "label_yaw": atan2(inward.x, inward.y)})
		mouths.append({"id": "boca_" + names[i], "pos": en, "dir": dr, "kind": "tunnel"})
	return id

## Estacionamiento subterráneo: una sala redonda con pilares y autos de papel. La boca está en el Parque del Drift y adentro se maneja libre; se sale por el círculo verde del sur.
func _make_hall(id: int) -> int:
	var park := Vector2(cos(deg_to_rad(22.5)), sin(deg_to_rad(22.5))) * 195.0
	var mouth := park + Vector2(-26.0, 0.0)
	var d_in := Vector2(-1.0, 0.0)
	mouths.append({"id": "boca_estacionamiento", "pos": mouth, "dir": d_in, "kind": "park"})
	links.append({"id": "entrada_estacionamiento", "pos": mouth + d_in * 4.0, "r": 4.0, "to": [HALL_C.x, HALL_C.y - 14.0, 0.0], "label": ""})
	links.append({"id": "salida_estacionamiento", "pos": HALL_C + Vector2(0.0, 33.0), "r": 4.0, "to": [mouth.x - d_in.x * 16.0, mouth.y - d_in.y * 16.0, atan2(-d_in.x, -d_in.y)], "label": "SALIDA", "label_pos": HALL_C + Vector2(0.0, 40.0), "label_yaw": PI})
	halls.append({"pos": HALL_C, "r": HALL_R, "h": 5.2})
	open_areas.append({"pos": HALL_C, "r": HALL_R - 0.6, "name": "Estacionamiento subterráneo", "paving": true, "dark": true})
	return id

func _make_roads() -> void:
	var id := 0
	# plaza: la rotonda del centro
	_sample_road(id, "Plaza Aurora", 0, "plaza", 6.0, 3.0, _ring(PLAZA_R, 0.0, TAU, 0.0))
	roads[0]["center"] = Vector2.ZERO
	open_areas.append({"pos": Vector2.ZERO, "r": PLAZA_R, "name": "Plaza Aurora", "paving": false})
	id += 1
	# anillos
	for i in RINGS.size():
		var major := (i % 2) == 1
		_sample_road(id, "Calle %d" % ((i + 1) * 10), (i + 1) * 10, "ring", 6.0 if major else 4.2, 3.4 if major else 2.4, _ring(RINGS[i], 0.0, TAU, 1.0))
		id += 1
	# avenidas (ocho, cada 45°): del este girando hacia el sur
	for k in 8:
		var ang := float(k) * PI / 4.0
		var rural := k in [0, 4, 6, 7]
		var r1 := RURAL_END if rural else (COAST_R if k in [1, 2, 3] else 1040.0)
		_sample_road(id, "Avenida %d" % (k + 1), k + 1, "major", 7.0, 3.6, _radial(PLAZA_R, minf(r1, 1040.0 if rural else r1), ang, float(AVE[k][0]), 0.0, float(AVE[k][1])))
		id += 1
	# rutas rurales: continúan las avenidas 1, 5, 7 y 8 hacia afuera, con curvas largas, hasta una Salida numerada
	var rural_ids := {}
	var rn := 20
	for k in [0, 4, 6, 7]:
		var plan := PackedVector2Array()
		var r := 1040.0
		while r < RURAL_END + 0.01:
			plan.append(_rural_pos(k, r)) # al principio recta (sigue siendo la avenida) y después ondula
			r += STEP
		_sample_road(id, "Ruta %d" % rn, rn, "rural", 4.6, 1.6, plan)
		rural_ids[k] = id
		var last := plan[plan.size() - 1]
		var prev := plan[plan.size() - 2]
		exits.append({"num": rn, "name": "Salida %d" % rn, "pos": last, "yaw": atan2(last.x - prev.x, last.y - prev.y), "road": id})
		id += 1
		rn += 20
	# secundarias B (a 22,5°) desde el anillo 260 y C (a 11,25°) desde el 650
	for k in 8:
		var ang := PI / 8.0 + float(k) * PI / 4.0
		if _in_grid_sector(rad_to_deg(ang)):
			continue
		_sample_road(id, "Calle %d" % (101 + k), 101 + k, "minor", 4.2, 2.4, _radial(260.0, 1040.0, ang, 9.0 + 3.0 * float(k % 3), 0.0))
		id += 1
	for k in 16:
		var ang := PI / 16.0 + float(k) * PI / 8.0
		if _in_grid_sector(rad_to_deg(ang)) or k in [2, 11]:
			continue # el sector de la grilla las reemplaza; dos más se sacan para dejar manzanas grandes
		_sample_road(id, "Calle %d" % (201 + k), 201 + k, "minor", 3.8, 2.2, _radial(650.0, 1040.0, ang, 6.0, 0.0))
		id += 1
	id = _make_grid(id)
	id = _make_park(id)
	# atajos: caminos con curvas que unen una ruta con la de al lado (vas por una a otra ciudad y, si querés, doblás y salís por la otra)
	var sc := 1
	for sp in [[0, 1300.0, 7, 1350.0, 46.0, 210.0, 0.0], [0, 1760.0, 7, 1810.0, 40.0, 180.0, 1.3], [7, 1560.0, 6, 1610.0, 44.0, 200.0, 2.1], [7, 2020.0, 6, 2070.0, 38.0, 170.0, 0.7]]:
		_sample_road(id, "Atajo %d" % sc, sc, "shortcut", 3.8, 1.4, _wavy(_rural_pos(int(sp[0]), float(sp[1])), _rural_pos(int(sp[2]), float(sp[3])), float(sp[4]), float(sp[5]), float(sp[6])))
		id += 1
		sc += 1
	# casco viejo (al sudeste): callejones angostos y sinuosos entre los anillos 520 y 910, con fachadas bajas de colores y veredas de ladrillo
	var cv := 1
	for deg in [50.6, 61.9, 73.1, 84.4]:
		var ang := deg_to_rad(float(deg))
		var plan := PackedVector2Array()
		var dirv := Vector2(cos(ang), sin(ang))
		var per := Vector2(-sin(ang), cos(ang))
		var r := 512.0
		while r < 918.01:
			var env := smoothstep(512.0, 560.0, r) * smoothstep(918.0, 870.0, r)
			plan.append(dirv * r + per * (13.0 * env * sin(TAU * (r - 512.0) / 104.0 + float(cv))))
			r += STEP
		_sample_road(id, "Calle Vieja %d" % cv, 400 + cv, "alley", 2.5, 1.4, plan)
		id += 1
		cv += 1
	# costanera sobre el mar (de los 35° a los 145°)
	_sample_road(id, "Costanera 90", 90, "coast", 6.0, 3.6, _ring(COAST_R, deg_to_rad(35.0), deg_to_rad(145.0), 0.0))
	id += 1
	# camino de la colina: sale de la avenida 6 y sube en tres cuchillas
	_sample_road(id, "Camino de la Colina 300", 300, "hill", 4.4, 1.8, _hill_plan())
	id += 1
	id = _make_tunnels(id)
	id = _make_hall(id)

## Trazado del camino de la colina: waypoints en polares (radio, ángulo) alrededor del centro de la colina, con el radio siempre bajando (así el camino nunca baja
## para volver a subir) y las cuchillas redondeadas (Chaikin en polares). Antes arranca el tramo de la avenida 6 hasta el pie de la colina.
func _hill_plan() -> PackedVector2Array:
	var wp: Array = [[415.0, 45.0], [345.0, 105.0], [285.0, 15.0], [225.0, 105.0], [165.0, 15.0], [110.0, 95.0], [60.0, 55.0]]
	var pol: Array = []
	for w in wp:
		pol.append(Vector2(float(w[0]), deg_to_rad(float(w[1]))))
	for _it in 3:
		var nxt: Array = [pol[0]]
		for i in pol.size() - 1:
			var p: Vector2 = pol[i]
			var q: Vector2 = pol[i + 1]
			nxt.append(p * 0.75 + q * 0.25)
			nxt.append(p * 0.25 + q * 0.75)
		nxt.append(pol[pol.size() - 1])
		pol = nxt
	var pts: Array = [Vector2(1040.0, 0.0).rotated(5.0 * PI / 4.0)] # el final de la avenida 6
	for p in pol:
		pts.append(HILL_C + Vector2(cos(float(p.y)), sin(float(p.y))) * float(p.x))
	# remuestreo a igual distancia
	var out := PackedVector2Array()
	var carry := 0.0
	out.append(pts[0])
	for i in pts.size() - 1:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1]
		var seg := p.distance_to(q)
		var pos := carry
		while pos <= seg:
			out.append(p.lerp(q, pos / maxf(seg, 0.001)))
			pos += STEP
		carry = pos - seg
	return out

# ───────────────────────── índice y cruces ─────────────────────────
func _index() -> void:
	for ri in roads.size():
		_index_road(ri)

## Agrega los puntos de una calle al índice espacial (también sirve para calles que se suman después, como las entradas de los talleres)
func _index_road(ri: int) -> void:
	var pts: PackedVector3Array = roads[ri]["pts"]
	var base := s_x.size()
	for i in pts.size():
		s_x.append(pts[i].x)
		s_y.append(pts[i].y)
		s_z.append(pts[i].z)
		s_road.append(ri)
		s_next.append(base + i + 1 if i + 1 < pts.size() else -1)
		s_prev.append(base + i - 1 if i > 0 else -1)
	# las calles cerradas (anillos) cierran el círculo
	if str(roads[ri]["kind"]) in ["ring", "plaza"]:
		s_next[base + pts.size() - 1] = base
		s_prev[base] = base + pts.size() - 1
	for si in range(base, s_x.size()):
		var key := Vector2i(int(floor(s_x[si] / HC)), int(floor(s_z[si] / HC)))
		var cell: PackedInt32Array = _hash.get(key, PackedInt32Array())
		cell.append(si)
		_hash[key] = cell

## Marca los puntos de cada calle que están cerca de un cruce (ahí no se pintan rayas del medio)
func _mark_junction_samples() -> void:
	for ri in roads.size():
		var z := PackedByteArray()
		z.resize((roads[ri]["pts"] as PackedVector3Array).size())
		roads[ri]["nj"] = z
	# cruces: cada par de calles cuyo recorrido se cruza (se busca con el índice espacial)
	var seen := {}
	for si in s_x.size():
		var ni := s_next[si]
		if ni < 0:
			continue
		var a := Vector2(s_x[si], s_z[si])
		var b := Vector2(s_x[ni], s_z[ni])
		var key := Vector2i(int(floor(s_x[si] / HC)), int(floor(s_z[si] / HC)))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k2 := Vector2i(key.x + dx, key.y + dz)
				if not _hash.has(k2):
					continue
				for sj in (_hash[k2] as PackedInt32Array):
					if s_road[sj] == s_road[si] or s_road[sj] < s_road[si]:
						continue
					var nj := s_next[sj]
					if nj < 0:
						continue
					var hit: Variant = Geometry2D.segment_intersects_segment(a, b, Vector2(s_x[sj], s_z[sj]), Vector2(s_x[nj], s_z[nj]))
					if hit == null:
						continue
					var hp: Vector2 = hit
					var jk := Vector3i(int(s_road[si]), int(s_road[sj]), int(round(hp.x / 6.0)) * 1000 + int(round(hp.y / 6.0)))
					if seen.has(jk):
						continue
					seen[jk] = true
					var ra: Dictionary = roads[s_road[si]]
					var rb: Dictionary = roads[s_road[sj]]
					junctions.append({"pos": hp, "y": height(hp.x, hp.y), "roads": [int(s_road[si]), int(s_road[sj])],
						"major": float(ra["hw"]) >= 6.0 and float(rb["hw"]) >= 6.0, "hw": maxf(float(ra["hw"]), float(rb["hw"]))})
	for j in junctions:
		for rid in j["roads"]:
			var pts: PackedVector3Array = roads[rid]["pts"]
			var nj: PackedByteArray = roads[rid]["nj"]
			var reach := float(j["hw"]) + float(roads[rid]["sw"]) + 5.0
			var jp: Vector2 = j["pos"]
			for i in pts.size():
				if Vector2(pts[i].x, pts[i].z).distance_to(jp) < reach:
					nj[i] = 1
			roads[rid]["nj"] = nj

# ───────────────────────── consultas (puras: se pueden llamar desde cualquier hilo) ─────────────────────────
## El punto más "adentro" de algún corredor de calle: [holgura al borde de la vereda, distancia al eje, nx, nz hacia el eje, altura del eje, medio ancho de calzada, id de calle]
## holgura > 0: está dentro del corredor; ≤ 0: afuera (contra los edificios)
func probe(x: float, z: float) -> PackedFloat64Array:
	var best := -1e9
	var out := PackedFloat64Array([-1e9, 0.0, 0.0, 0.0, height(x, z), 0.0, -1.0])
	var kx := int(floor(x / HC))
	var kz := int(floor(z / HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				var ni := s_next[si]
				var ax := s_x[si]
				var az := s_z[si]
				var ex := 0.0
				var ez := 0.0
				var ay := s_y[si]
				var ey := 0.0
				if ni >= 0:
					ex = s_x[ni] - ax
					ez = s_z[ni] - az
					ey = s_y[ni] - ay
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var px := ax + ex * t
				var pz := az + ez * t
				var ddx := px - x
				var ddz := pz - z
				var d2 := ddx * ddx + ddz * ddz
				var rd: Dictionary = roads[s_road[si]]
				var half := float(rd["hw"]) + float(rd["sw"])
				if d2 > (half + 1.0) * (half + 1.0) and best > -1e8:
					continue
				var d := sqrt(d2)
				var slack := half - d
				if slack > best:
					best = slack
					var inv := 1.0 / maxf(d, 0.0001)
					out[0] = slack
					out[1] = d
					out[2] = ddx * inv
					out[3] = ddz * inv
					out[4] = ay + ey * t
					out[5] = float(rd["hw"])
					out[6] = float(s_road[si])
	# plazas y parques abiertos: se maneja por adentro (adentro de una zona abierta siempre hay suelo)
	for oi in open_areas.size():
		var oa: Dictionary = open_areas[oi]
		var oc: Vector2 = oa["pos"]
		var od := Vector2(x - oc.x, z - oc.y).length()
		var orr: float = oa["r"]
		if od < orr and orr - od > best:
			best = orr - od
			out[0] = best
			out[1] = 0.0
			out[2] = 0.0
			out[3] = 0.0
			out[4] = height(x, z)
			out[5] = orr
			out[6] = -2.0 - float(oi)
	return out

## Calle y cuadra de un punto: {road, name, num, cuadra, kind, dist}
func locate(x: float, z: float) -> Dictionary:
	var pr := probe(x, z)
	if pr[6] <= -2.0:
		return {"road": -1, "name": str(open_areas[int(-pr[6]) - 2]["name"]), "num": 0, "cuadra": 1, "kind": "plaza", "dist": 0.0}
	if pr[6] < 0.0 or pr[0] < -12.0:
		return {"road": -1, "name": "", "num": -1, "cuadra": 0, "kind": "", "dist": 1e9}
	var ri := int(pr[6])
	var rd: Dictionary = roads[ri]
	var pts: PackedVector3Array = rd["pts"]
	var cum: PackedFloat32Array = rd["cum"]
	var bi := 0
	var bd := 1e18
	for i in pts.size():
		var dd := (pts[i].x - x) * (pts[i].x - x) + (pts[i].z - z) * (pts[i].z - z)
		if dd < bd:
			bd = dd
			bi = i
	var dist_along := float(cum[bi])
	if str(rd["kind"]) in ["major", "rural", "minor", "hill"] and str(rd["name"]).begins_with(("Avenida")):
		dist_along = Vector2(x, z).length() # las avenidas se cuentan desde la plaza
	return {"road": ri, "name": str(rd["name"]), "num": int(rd["num"]), "cuadra": int(dist_along / 100.0) + 1, "kind": str(rd["kind"]), "dist": float(pr[1])}

func chunk_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL)), int(floor(z / CELL)))

# ───────────────────────── edificios ─────────────────────────
func _style_for(zone: int, rd: Dictionary) -> Dictionary:
	# alto, ancho y fondo por zona
	match zone:
		0:
			return {"h": [24.0, 62.0], "w": [16.0, 30.0], "d": [14.0, 22.0], "hip": 0.0}
		1:
			return {"h": [13.0, 30.0], "w": [13.0, 26.0], "d": [12.0, 18.0], "hip": 0.15}
		2:
			return {"h": [7.0, 15.0], "w": [10.0, 20.0], "d": [10.0, 16.0], "hip": 0.8}
		3:
			return {"h": [9.0, 20.0], "w": [11.0, 22.0], "d": [11.0, 16.0], "hip": 0.5}
		4:
			return {"h": [5.5, 9.0], "w": [9.0, 15.0], "d": [8.0, 13.0], "hip": 1.0}
	return {"h": [4.5, 6.5], "w": [8.0, 12.0], "d": [8.0, 11.0], "hip": 1.0}

const OCC := 40.0 # celda de la tabla de huellas de los edificios especiales
var _occ: Dictionary = {} # Vector2i(40 m) -> Array de huellas [x, z, yaw, w, d] (lugares especiales)

## Edificio especial (concesionario, taller): una caja cerrada pegada a la calle
func _add_building(cen: Vector2, w: float, d: float, h: float, yaw: float, wall: Color, roof: Color, zone: int, hip: bool, road: int, extra: Dictionary = {}) -> void:
	var ok_key := Vector2i(int(floor(cen.x / OCC)), int(floor(cen.y / OCC)))
	if not _occ.has(ok_key):
		_occ[ok_key] = []
	(_occ[ok_key] as Array).append([cen.x, cen.y, yaw, w, d])
	var key := chunk_of(cen.x, cen.y)
	if not buildings.has(key):
		buildings[key] = []
	var b := {"x": cen.x, "z": cen.y, "y": height(cen.x, cen.y), "yaw": yaw, "w": w, "d": d, "h": h, "wall": wall, "roof": roof, "kind": zone, "seed": _rng.randf(), "hip": hip, "road": road}
	for k in extra:
		b[k] = extra[k]
	(buildings[key] as Array).append(b)
	building_count += 1

## ¿Algún edificio especial cubre este punto (con margen)?
func _point_covered(x: float, z: float, margin := 0.3) -> bool:
	var ok_key := Vector2i(int(floor(x / OCC)), int(floor(z / OCC)))
	for ox in range(-1, 2):
		for oz in range(-1, 2):
			var kk := Vector2i(ok_key.x + ox, ok_key.y + oz)
			if not _occ.has(kk):
				continue
			for c in (_occ[kk] as Array):
				var yw := float(c[2])
				var dx := x - float(c[0])
				var dz := z - float(c[1])
				if absf(dx * sin(yw) + dz * cos(yw)) < float(c[3]) * 0.5 + margin and absf(dx * cos(yw) - dz * sin(yw)) < float(c[4]) * 0.5 + margin:
					return true
	return false

## Zonas abiertas donde no se construye (plazas y parques)
var open_areas: Array = [] # {pos: Vector2, r: float, name: String}
func _no_build(p: Vector2) -> bool:
	for oa in open_areas:
		if p.distance_to(oa["pos"]) < float(oa["r"]):
			return true
	return false

# ───────────────────────── frentes de edificios ─────────────────────────
## Las calles no tienen banquina: tienen frentes de edificios, pegados uno al otro y sin huecos, así el jugador nunca ve qué hay detrás (las paredes de la calle son un
## laberinto). Cada frente es una «losa»: una tira de pared sobre la línea de edificación (a 0,15 m de la vereda), con su altura, su color y un techo de poca profundidad.
## Donde cruza otra calle la pared termina justo sobre la línea de edificación de esa calle, así las esquinas quedan cerradas. Las losas vecinas de distinta altura
## muestran su costado. Detrás de la losa no hay nada: nadie lo puede ver.
const LINE_GAP := 0.15
var slabs: Dictionary = {} # Vector2i (cuadra) -> Array de losas {pts: PackedVector3Array, away: PackedVector2Array, h, wall, roof, seed, depth, house, hp, hn}
var slab_count := 0

## ¿El punto cae dentro del corredor (calzada + vereda + margen) de alguna calle que no sea own, o de un lugar especial o zona abierta?
func _blocked_line(x: float, z: float, own: int) -> bool:
	var kx := int(floor(x / HC))
	var kz := int(floor(z / HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				var rid := int(s_road[si])
				if rid == own:
					continue
				var ni := s_next[si]
				if ni < 0:
					continue
				var ax := s_x[si]
				var az := s_z[si]
				var ex := s_x[ni] - ax
				var ez := s_z[ni] - az
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var rd: Dictionary = roads[rid]
				var need := float(rd["hw"]) + float(rd["sw"]) + LINE_GAP
				if ddx * ddx + ddz * ddz < need * need:
					return true
	return _point_covered(x, z, 0.5) or _no_build(Vector2(x, z))

## ¿Hay una losa (o una pared de un lugar especial) justo en este punto de la línea de edificación? (para las pruebas)
func slab_covers(p: Vector2) -> bool:
	var key := chunk_of(p.x, p.y)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var kk := Vector2i(key.x + dx, key.y + dz)
			if not slabs.has(kk):
				continue
			for sl in (slabs[kk] as Array):
				var sp: PackedVector3Array = sl["pts"]
				for i in sp.size() - 1:
					var a := Vector2(sp[i].x, sp[i].z)
					var b := Vector2(sp[i + 1].x, sp[i + 1].z)
					if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.6:
						return true
	return false

func _facade_style(zone: int, kind: String, r: float) -> Dictionary:
	if kind == "alley":
		return {"h": [12.8, 22.4], "w": [8.0, 14.0], "depth": 7.0, "house": 0.3}
	if kind == "hill":
		return {"h": [4.5, 7.0], "w": [9.0, 14.0], "depth": 9.0, "house": 1.0}
	match zone:
		0:
			return {"h": [24.0, 62.0], "w": [14.0, 28.0], "depth": 14.0, "house": 0.0}
		1:
			return {"h": [13.0, 32.0], "w": [12.0, 24.0], "depth": 12.0, "house": 0.0}
	# afuera del centro los edificios bajan hasta ser casas bajas con techo a dos aguas
	var t := clampf((r - 700.0) / 400.0, 0.0, 1.0)
	return {"h": [lerpf(10.0, 4.0, t), lerpf(18.0, 7.0, t)], "w": [lerpf(11.0, 8.0, t), lerpf(20.0, 13.0, t)], "depth": lerpf(11.0, 9.0, t), "house": clampf(0.2 + t, 0.0, 1.0)}

func _line_pt(pts: PackedVector3Array, away: PackedVector2Array, off: float, t: float) -> Array:
	var i := clampi(int(floor(t)), 0, pts.size() - 2)
	var f := t - float(i)
	var p := Vector3(lerpf(pts[i].x, pts[i + 1].x, f), lerpf(pts[i].y, pts[i + 1].y, f), lerpf(pts[i].z, pts[i + 1].z, f))
	var a := away[i].lerp(away[i + 1], f).normalized()
	return [Vector2(p.x, p.z) + a * off, p.y, a]

func _place_facades() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		var kind := str(rd["kind"])
		if kind == "rural" or kind == "shortcut" or kind == "bay" or kind == "tunnel":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var hw := float(rd["hw"])
		var sw := float(rd["sw"])
		var off := hw + sw + LINE_GAP
		var n := pts.size()
		for side in [-1.0, 1.0]:
			var sdv: float = side
			var away := PackedVector2Array()
			for i in n:
				var a := pts[maxi(i - 1, 0)]
				var b := pts[mini(i + 1, n - 1)]
				var tn := Vector2(b.x - a.x, b.z - a.z)
				if tn.length() < 0.001:
					tn = Vector2(1, 0)
				tn = tn.normalized()
				away.append(Vector2(-tn.y, tn.x) * sdv)
			if kind == "coast" and sdv > 0.0:
				continue # del lado del mar no se edifica
			if kind == "plaza":
				# solo el lado de afuera: la plaza es un parque abierto y la rodean los edificios
				var p0 := Vector2(pts[0].x, pts[0].z) - (rd["center"] as Vector2)
				if away[0].dot(p0) < 0.0:
					continue
			var blocked: Array = []
			var line: Array = []
			for i in n:
				var lp := Vector2(pts[i].x, pts[i].z) + away[i] * off
				line.append(lp)
				blocked.append(_blocked_line(lp.x, lp.y, ri))
			# tramos libres, en parámetro continuo (índice + fracción), con los extremos exactos sobre el borde de la calle que cruza
			var runs: Array = []
			var cur_a := -1.0
			if not blocked[0]:
				cur_a = 0.0
			for i in range(n - 1):
				var b0: bool = blocked[i]
				var b1: bool = blocked[i + 1]
				if b0 and not b1:
					cur_a = float(i) + _edge_t(pts, away, off, i, true, ri)
				elif (not b0) and b1:
					runs.append([cur_a, float(i) + _edge_t(pts, away, off, i, false, ri)])
					cur_a = -1.0
			if cur_a >= 0.0:
				runs.append([cur_a, float(n - 1)])
			for r in runs:
				_slabs_in_run(kind, pts, away, off, float(r[0]), float(r[1]), sdv)

## Parámetro (0..1) dentro del tramo i→i+1 donde la línea de edificación entra (to_free = true: pasa de bloqueada a libre) o sale de una calle que cruza
func _edge_t(pts: PackedVector3Array, away: PackedVector2Array, off: float, i: int, to_free: bool, own: int) -> float:
	var lo := 0.0
	var hi := 1.0
	for it in 10:
		var mid := (lo + hi) * 0.5
		var lp: Array = _line_pt(pts, away, off, float(i) + mid)
		var bl := _blocked_line((lp[0] as Vector2).x, (lp[0] as Vector2).y, own)
		if to_free:
			if bl:
				lo = mid
			else:
				hi = mid
		else:
			if bl:
				hi = mid
			else:
				lo = mid
	return hi if to_free else lo

func _slabs_in_run(kind: String, pts: PackedVector3Array, away: PackedVector2Array, off: float, ta: float, tb: float, sdv: float) -> void:
	if tb - ta < 0.05:
		return
	var cur := ta
	var run_slabs: Array = []
	var last_h := 0.0
	while cur < tb - 0.001:
		var mid_pt: Array = _line_pt(pts, away, off, minf(cur + 1.0, tb))
		var mp: Vector2 = mid_pt[0]
		var zone := zone_of(mp.x, mp.y)
		var st := _facade_style(zone, kind, mp.length())
		var w := _rng.randf_range(float(st["w"][0]), float(st["w"][1]))
		# el tramo avanza hasta juntar el ancho (por puntos de la calle) o hasta el final
		var spts := PackedVector3Array()
		var saway := PackedVector2Array()
		var first: Array = _line_pt(pts, away, off, cur)
		spts.append(Vector3((first[0] as Vector2).x, first[1], (first[0] as Vector2).y))
		saway.append(first[2])
		var acc := 0.0
		var t := cur
		while t < tb - 0.001 and acc < w:
			var nt := minf(floorf(t + 0.0001) + 1.0, tb)
			var np: Array = _line_pt(pts, away, off, nt)
			var prev := Vector2(spts[spts.size() - 1].x, spts[spts.size() - 1].z)
			acc += prev.distance_to(np[0])
			spts.append(Vector3((np[0] as Vector2).x, np[1], (np[0] as Vector2).y))
			saway.append(np[2])
			t = nt
		if tb - t < 5.0 / STEP and t < tb - 0.001: # no dejar un resto chico: se lo come este
			var nt2 := tb
			var np2: Array = _line_pt(pts, away, off, nt2)
			spts.append(Vector3((np2[0] as Vector2).x, np2[1], (np2[0] as Vector2).y))
			saway.append(np2[2])
			t = nt2
		cur = t
		if spts.size() < 2 or acc < 1.0:
			continue
		var skip := kind == "hill" and _rng.randf() < 0.45 # en la colina hay huecos de jardín
		var hh := _rng.randf_range(float(st["h"][0]), float(st["h"][1]))
		if last_h > 0.0 and _rng.randf() < 0.75:
			hh = clampf(last_h * _rng.randf_range(0.75, 1.3), float(st["h"][0]), float(st["h"][1])) # los vecinos se parecen: no hay paredones ciegos enormes
		hh = maxf(3.2, roundf(hh / 3.2) * 3.2)
		last_h = hh
		var house := _rng.randf() < float(st["house"])
		if house:
			hh = clampf(hh, 3.2, 9.6)
		var slab := {"pts": spts, "away": saway, "h": hh, "wall": (OLD_WALLS if kind == "alley" else WALLS)[_rng.randi() % (OLD_WALLS if kind == "alley" else WALLS).size()],
			"roof": ROOFS[_rng.randi() % ROOFS.size()], "seed": _rng.randf(), "depth": float(st["depth"]), "house": house, "hp": 0.0, "hn": 0.0, "zone": zone}
		if skip:
			run_slabs.append(null)
			continue
		run_slabs.append(slab)
	# alturas de los vecinos (para mostrar el costado de la losa más alta)
	for i in run_slabs.size():
		var sl = run_slabs[i]
		if sl == null:
			continue
		if i > 0 and run_slabs[i - 1] != null:
			sl["hp"] = float(run_slabs[i - 1]["h"])
		if i + 1 < run_slabs.size() and run_slabs[i + 1] != null:
			sl["hn"] = float(run_slabs[i + 1]["h"])
		var p0: Vector3 = sl["pts"][0]
		var key := chunk_of(p0.x, p0.z)
		var arr: Array = slabs.get(key, [])
		arr.append(sl)
		slabs[key] = arr
		slab_count += 1

# ───────────────────────── objetos de la calle ─────────────────────────
func _add_prop(t: int, x: float, z: float, to_road: Vector2) -> void:
	# nunca sobre el asfalto de ninguna calle
	var pr := probe(x, z)
	if pr[6] >= 0.0 and float(pr[1]) <= float(pr[5]) + 0.2:
		return
	var id := prop_type.size()
	prop_type.append(t)
	prop_x.append(x)
	prop_z.append(z)
	var py := height(x, z)
	if pr[0] >= 0.0:
		py = float(pr[4]) + (0.16 if pr[6] >= 0.0 else 0.0) # sobre la vereda (el cordón sube 16 cm); en una plaza abierta, a ras del suelo
	prop_y.append(py)
	prop_yaw.append(atan2(to_road.x, to_road.y) if t != 1 else _rng.randf() * TAU)
	prop_seed.append(_rng.randf())
	var key := chunk_of(x, z)
	var arr: PackedInt32Array = props_in.get(key, PackedInt32Array())
	arr.append(id)
	props_in[key] = arr

## Farolas, árboles y bolardos a lo largo de las calles; semáforos en los cruces grandes
func _place_props() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		var kind := str(rd["kind"])
		if kind == "rural" or kind == "shortcut" or kind == "bay" or kind == "tunnel":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var nj: PackedByteArray = rd["nj"]
		var hw := float(rd["hw"])
		var sw := float(rd["sw"])
		var lamp_gap: float = {"plaza": 22.0, "alley": 26.0, "minor": 46.0, "coast": 30.0, "hill": 60.0}.get(kind, 40.0)
		var tree_gap := 22.0
		var acc_l := _rng.randf() * lamp_gap
		var acc_t := _rng.randf() * tree_gap
		var acc_b := 0.0
		var flip := 1.0
		var flip_t := -1.0
		for i in range(1, pts.size() - 1):
			var tn := Vector2(pts[i + 1].x - pts[i - 1].x, pts[i + 1].z - pts[i - 1].z)
			if tn.length() < 0.1:
				continue
			tn = tn.normalized()
			var nrm := Vector2(-tn.y, tn.x)
			var p := Vector2(pts[i].x, pts[i].z)
			var step := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
			acc_l += step
			acc_t += step
			acc_b += step
			var off := hw + sw * 0.5
			var near_j := nj.size() > i and nj[i] != 0
			if acc_l >= lamp_gap and not near_j:
				acc_l = 0.0
				var sd := flip
				if kind != "alley":
					flip = -flip
				_add_prop(0, p.x + nrm.x * sd * off, p.y + nrm.y * sd * off, -nrm * sd)
				if kind == "alley":
					_add_prop(0, p.x - nrm.x * sd * off, p.y - nrm.y * sd * off, nrm * sd) # callejón: faroles de los dos lados
			if acc_t >= tree_gap and not near_j and kind in ["major", "ring", "coast", "minor", "hill", "plaza"] and sw >= 2.0:
				acc_t = 0.0
				if _rng.randf() < 0.8:
					var st := flip_t
					flip_t = -flip_t
					if not (kind == "coast" and st > 0.0):
						_add_prop(1, p.x + nrm.x * st * off, p.y + nrm.y * st * off, -nrm * st)
			if kind == "alley" and acc_b >= 6.0 and not near_j:
				acc_b = 0.0
				for sd in [-1.0, 1.0]:
					var bo := hw + 0.5
					_add_prop(3, p.x + nrm.x * sd * bo, p.y + nrm.y * sd * bo, -nrm * sd)
			elif kind == "coast" and acc_b >= 10.0 and not near_j:
				acc_b = 0.0
				_add_prop(3, p.x + nrm.x * (hw + sw - 0.4), p.y + nrm.y * (hw + sw - 0.4), -nrm)
	# plaza Aurora: el monumento del centro y un anillo de árboles; el parque del drift queda libre (solo faroles en su calle)
	_add_prop(4, 0.0, 0.0, Vector2(0, 1))
	for i in 10:
		var a := TAU * (float(i) + 0.5) / 10.0
		_add_prop(1, cos(a) * 30.0, sin(a) * 30.0, Vector2(0, 1))
	# boca del estacionamiento: dos postes a cada lado (que no se rompen)
	for mo in mouths:
		if str(mo["kind"]) == "park":
			var d_in: Vector2 = mo["dir"]
			var lat := Vector2(-d_in.y, d_in.x)
			for sg in [-1.0, 1.0]:
				for off in [5.6, 8.6]:
					_add_prop(5, (mo["pos"] as Vector2).x + d_in.x * 3.0 + lat.x * float(sg) * float(off), (mo["pos"] as Vector2).y + d_in.y * 3.0 + lat.y * float(sg) * float(off), d_in)
	# estacionamiento subterráneo: pilares y autos de papel (con huecos al azar y libre el camino a la salida del sur)
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0
		_add_prop(5, HALL_C.x + cos(a) * 26.0, HALL_C.y + sin(a) * 26.0, Vector2(0, 1))
	for ring in [[37.0, 22], [17.0, 10]]:
		var rr: float = ring[0]
		var cn: int = ring[1]
		for i in cn:
			var a := TAU * float(i) / float(cn) + 0.1
			if absf(angle_difference(a, PI * 0.5)) < 0.32 or _rng.randf() < 0.3:
				continue
			_add_prop(6, HALL_C.x + cos(a) * rr, HALL_C.y + sin(a) * rr, Vector2(-cos(a), -sin(a)))
	# semáforos: cuatro por cruce grande (dos por cada calle, en esquinas opuestas)
	for j in junctions:
		if not bool(j["major"]):
			continue
		var jp: Vector2 = j["pos"]
		var rids: Array = j["roads"]
		for k in 2:
			var ra: Dictionary = roads[rids[k]]
			var rb: Dictionary = roads[rids[1 - k]]
			var pa: PackedVector3Array = ra["pts"]
			var bi := 0
			var bd := 1e18
			for i in pa.size():
				var dd := Vector2(pa[i].x, pa[i].z).distance_squared_to(jp)
				if dd < bd:
					bd = dd
					bi = i
			var a := pa[maxi(bi - 1, 0)]
			var b := pa[mini(bi + 1, pa.size() - 1)]
			var ta := Vector2(b.x - a.x, b.z - a.z).normalized()
			var na := Vector2(-ta.y, ta.x)
			var along := float(rb["hw"]) + float(rb["sw"]) + 1.6
			var offs := float(ra["hw"]) + float(ra["sw"]) * 0.5
			for sg in [1.0, -1.0]:
				_add_prop(2, jp.x + (ta.x * along + na.x * offs) * sg, jp.y + (ta.y * along + na.y * offs) * sg, -na * sg)

# ───────────────────────── puntos de interés ─────────────────────────
## Cada uno es un edificio especial pegado a una calle: [id, tipo, nombre, calle, distancia sobre la calle (m), lado, ancho, fondo, alto, color, local (ver data/shops.gd)]
## Los locales se entran: frente a cada uno hay un círculo verde; si frenás ahí se abre el portón y el auto entra al taller.
const POI_SPECS := [
	["concesionario", "dealer", "Concesionario Dream City", "Avenida 7", 150.0, 1.0, 34.0, 22.0, 9.6, Color(0.20, 0.45, 0.85), "dealer"],
	["taller_reglaje_a", "garage", "Reglaje Central", "Avenida 1", 170.0, -1.0, 26.0, 18.0, 8.0, Color(0.95, 0.50, 0.12), "tune_a"],
	["taller_pintura", "garage", "Taller de Pintura", "Avenida 3", 142.0, 1.0, 26.0, 18.0, 8.0, Color(0.85, 0.30, 0.65), "paint"],
	["taller_motor", "garage", "Taller de Motor", "Avenida 2", 277.0, -1.0, 26.0, 18.0, 8.0, Color(0.88, 0.25, 0.20), "engine"],
	["taller_transmision", "garage", "Taller de Transmisión", "Avenida 4", 142.0, 1.0, 26.0, 18.0, 8.0, Color(0.22, 0.62, 0.62), "gearbox"],
	["taller_suspension", "garage", "Suspensión y Frenos", "Avenida 6", 142.0, -1.0, 26.0, 18.0, 8.0, Color(0.30, 0.65, 0.35), "susp"],
	["taller_ruedas", "garage", "Taller de Ruedas", "Avenida 8", 142.0, 1.0, 26.0, 18.0, 8.0, Color(0.95, 0.80, 0.20), "wheels"],
	["taller_reglaje_b", "garage", "Reglaje del Puerto", "Costanera 90", 420.0, -1.0, 26.0, 18.0, 8.0, Color(0.95, 0.65, 0.15), "tune_b"],
	["mirador", "view", "Mirador de la Colina", "Camino de la Colina 300", -1.0, 1.0, 18.0, 14.0, 6.4, Color(0.95, 0.80, 0.25), ""],
]

func road_named(nm: String) -> int:
	for r in roads:
		if str(r["name"]) == nm:
			return int(r["id"])
	return -1

func _place_pois() -> void:
	pois.clear()
	for sp in POI_SPECS:
		var ri := road_named(str(sp[3]))
		if ri < 0:
			continue
		var rd: Dictionary = roads[ri]
		var pts: PackedVector3Array = rd["pts"]
		var cum: PackedFloat32Array = rd["cum"]
		var target := float(sp[4]) if float(sp[4]) >= 0.0 else float(cum[cum.size() - 1]) # −1 = el final de la calle
		var bi := 0
		for i in pts.size():
			if cum[i] <= target:
				bi = i
		var a := pts[bi]
		var b := pts[mini(bi + 1, pts.size() - 1)]
		var tn := Vector2(b.x - a.x, b.z - a.z)
		if tn.length() < 0.1:
			tn = Vector2(a.x - pts[maxi(bi - 1, 0)].x, a.z - pts[maxi(bi - 1, 0)].z)
		tn = tn.normalized()
		var side := float(sp[5])
		var nrm := Vector2(-tn.y, tn.x) * side
		var yaw0 := atan2(tn.x, tn.y)
		var back := 0.6 # se retira del borde de la vereda hasta que ninguna esquina pise una calle (en las curvas las esquinas asoman)
		var cen := Vector2(a.x, a.z) + nrm * (float(rd["hw"]) + float(rd["sw"]) + LINE_GAP + back + float(sp[7]) * 0.5)
		for it in 12:
			var ok := true
			for cx in [-0.5, 0.5]:
				for cz in [-0.5, 0.5]:
					var wp := cen + Vector2(sin(yaw0), cos(yaw0)) * (float(cx) * float(sp[6])) + Vector2(cos(yaw0), -sin(yaw0)) * (float(cz) * float(sp[7]))
					if probe(wp.x, wp.y)[0] > -0.6:
						ok = false
			if ok:
				break
			back += 0.5
			cen = Vector2(a.x, a.z) + nrm * (float(rd["hw"]) + float(rd["sw"]) + LINE_GAP + back + float(sp[7]) * 0.5)
		if str(sp[1]) == "view":
			cen = Vector2(a.x, a.z) # el mirador es la plazoleta del final del camino
		var yaw := atan2(tn.x, tn.y)
		var lane := Vector2(a.x, a.z) + nrm * (float(rd["hw"]) * 0.5)
		var door := Vector2(a.x, a.z) + nrm * (float(rd["hw"]) + float(rd["sw"]) + LINE_GAP + back) # el plano del frente del local
		pois.append({"id": str(sp[0]), "kind": str(sp[1]), "name": str(sp[2]), "pos": cen, "yaw": yaw, "size": Vector2(float(sp[6]), float(sp[7])), "color": sp[9],
			"y": height(cen.x, cen.y), "road": ri, "front": lane, "shop": str(sp[10]), "door": door, "dir": nrm, "road_yaw": yaw})
		if str(sp[10]) != "":
			# la entrada: una calle cortita desde el círculo verde hasta adentro del local (así el auto puede entrar)
			var plan := PackedVector3Array()
			var dist := lane.distance_to(door) + 7.0
			var n := int(ceil(dist / 3.0))
			var cum_b := PackedFloat32Array()
			for bi2 in n + 1:
				var q := lane + nrm * (dist * float(bi2) / float(n))
				plan.append(Vector3(q.x, height(q.x, q.y), q.y))
				cum_b.append(dist * float(bi2) / float(n))
			roads.append({"id": roads.size(), "name": "Entrada %s" % str(sp[2]), "num": 0, "kind": "bay", "hw": 3.2, "sw": 0.0, "pts": plan, "cum": cum_b, "nj": PackedByteArray([0]).duplicate()})
			var nj_b := PackedByteArray()
			nj_b.resize(plan.size())
			roads[roads.size() - 1]["nj"] = nj_b
			_index_road(roads.size() - 1)
		if str(sp[1]) != "view":
			_add_building(cen, float(sp[6]), float(sp[7]), float(sp[8]), yaw, sp[9], sp[9].darkened(0.3), zone_of(cen.x, cen.y), false, ri, {"poi": str(sp[0]), "side": -side})
