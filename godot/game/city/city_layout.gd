extends RefCounted
## Puerto Aurelia, el mundo abierto: la ciudad se genera igual en todos los teléfonos a partir de una semilla (el online depende de eso: todos ven las mismas
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
const RINGS := [130.0, 260.0, 390.0, 520.0, 650.0, 780.0, 910.0, 1040.0]
const COAST_R := 1120.0
const RURAL_END := 2300.0
const HILL_C := Vector2(-1086.0, -1086.0) # centro de la colina (al noroeste)
const HILL_R := 430.0
const HILL_H := 72.0
const SEA_Z := 1260.0

const WALLS := [Color(0.93, 0.78, 0.52), Color(0.96, 0.90, 0.76), Color(0.82, 0.47, 0.34), Color(0.93, 0.70, 0.66), Color(0.70, 0.80, 0.88),
	Color(0.72, 0.86, 0.76), Color(0.95, 0.94, 0.92), Color(0.70, 0.38, 0.30), Color(0.88, 0.78, 0.64), Color(0.98, 0.84, 0.55)]
const ROOFS := [Color(0.72, 0.34, 0.24), Color(0.62, 0.30, 0.22), Color(0.55, 0.50, 0.48), Color(0.78, 0.45, 0.30)]

var seed_v := 20261004
var roads: Array = [] # {id, name, num, kind, hw, sw, pts (x,y,z cada STEP), cum, nj (cerca de un cruce: PackedByteArray)}
var junctions: Array = [] # {pos: Vector2, y, roads: [ids], major: bool}
var pois: Array = [] # {id, kind, name, pos, yaw, size, color}
var exits: Array = [] # {num, name, pos, yaw, road}
var buildings: Dictionary = {} # Vector2i (cuadra) -> Array de {x, z, y, yaw, w, d, h, wall: Color, roof: Color, kind, seed, hip}
var building_count := 0

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
	_place_buildings()

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

func _radial(r0: float, r1: float, ang: float, amp: float, phase: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var dirv := Vector2(cos(ang), sin(ang))
	var per := Vector2(-sin(ang), cos(ang))
	var r := r0
	while r < r1 + 0.01:
		# el desvío es cero en cada múltiplo de 130 m (donde cruzan los anillos): los cruces caen justo en los puntos previstos
		var off := amp * sin(PI * r / 130.0 + phase)
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

func _make_roads() -> void:
	var id := 0
	# plaza: la rotonda del centro
	_sample_road(id, "Plaza Aurora", 0, "plaza", 6.0, 3.0, _ring(PLAZA_R, 0.0, TAU, 0.0))
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
		_sample_road(id, "Avenida %d" % (k + 1), k + 1, "major", 7.0, 3.6, _radial(PLAZA_R, minf(r1, 1040.0 if rural else r1), ang, 12.0, 0.0))
		id += 1
	# rutas rurales: continúan las avenidas 1, 5, 7 y 8 hacia afuera, con curvas largas, hasta una Salida numerada
	var rural_ids := {}
	var rn := 20
	for k in [0, 4, 6, 7]:
		var ang := float(k) * PI / 4.0
		var dirv := Vector2(cos(ang), sin(ang))
		var per := Vector2(-sin(ang), cos(ang))
		var plan := PackedVector2Array()
		var r := 1040.0
		var ph := float(k) * 1.7
		while r < RURAL_END + 0.01:
			var t := smoothstep(1040.0, 1300.0, r) # al principio recta (sigue siendo la avenida) y después ondula
			var off := t * (70.0 * sin((r - 1040.0) / 230.0 + ph) + 26.0 * sin((r - 1040.0) / 83.0 + ph * 2.0))
			plan.append(dirv * r + per * off)
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
		_sample_road(id, "Calle %d" % (101 + k), 101 + k, "minor", 4.2, 2.4, _radial(260.0, 1040.0, ang, 9.0, 0.0))
		id += 1
	for k in 16:
		var ang := PI / 16.0 + float(k) * PI / 8.0
		_sample_road(id, "Calle %d" % (201 + k), 201 + k, "minor", 3.8, 2.2, _radial(650.0, 1040.0, ang, 6.0, 0.0))
		id += 1
	# costanera sobre el mar (de los 35° a los 145°)
	_sample_road(id, "Costanera 90", 90, "coast", 6.0, 3.6, _ring(COAST_R, deg_to_rad(35.0), deg_to_rad(145.0), 0.0))
	id += 1
	# camino de la colina: sale de la avenida 6 y sube en tres cuchillas
	_sample_road(id, "Camino de la Colina 300", 300, "hill", 4.4, 1.8, _hill_plan())
	id += 1

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
	for si in s_x.size():
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
	return out

## Calle y cuadra de un punto: {road, name, num, cuadra, kind, dist}
func locate(x: float, z: float) -> Dictionary:
	var pr := probe(x, z)
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

func _clear_of_roads(px: float, pz: float, rad: float, own: int) -> bool:
	# ¿ningún corredor de otra calle toca un círculo de radio rad en (px, pz)?
	var kx := int(floor(px / HC))
	var kz := int(floor(pz / HC))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				var rid := int(s_road[si])
				var rd: Dictionary = roads[rid]
				var need := float(rd["hw"]) + float(rd["sw"]) + rad + (0.4 if rid == own else 1.2)
				var ddx := s_x[si] - px
				var ddz := s_z[si] - pz
				if ddx * ddx + ddz * ddz < need * need:
					# más cerca que el corredor: sirve solo si es la propia calle (la vereda de esa calle ya está contada en el retiro)
					if rid != own:
						return false
					if ddx * ddx + ddz * ddz < (float(rd["hw"]) + rad * 0.2) * (float(rd["hw"]) + rad * 0.2):
						return false
	return true

var _occ: Dictionary = {} # Vector2i(24 m) -> Array de huellas [x, z, yaw, w, d] de lo ya construido

static func _rects_overlap(ax: float, az: float, ayaw: float, aw: float, ad: float, bx: float, bz: float, byaw: float, bw: float, bd: float) -> bool:
	# separación de ejes (SAT) entre dos rectángulos orientados, con 0,6 m de aire
	var axes := [Vector2(sin(ayaw), cos(ayaw)), Vector2(cos(ayaw), -sin(ayaw)), Vector2(sin(byaw), cos(byaw)), Vector2(cos(byaw), -sin(byaw))]
	var d := Vector2(bx - ax, bz - az)
	for ax_v in axes:
		var ra := absf(ax_v.dot(Vector2(sin(ayaw), cos(ayaw)))) * aw * 0.5 + absf(ax_v.dot(Vector2(cos(ayaw), -sin(ayaw)))) * ad * 0.5
		var rb := absf(ax_v.dot(Vector2(sin(byaw), cos(byaw)))) * bw * 0.5 + absf(ax_v.dot(Vector2(cos(byaw), -sin(byaw)))) * bd * 0.5
		if absf(ax_v.dot(d)) > ra + rb + 0.6:
			return false
	return true

func _spot_free(cen: Vector2, w: float, d: float, yaw: float) -> bool:
	var ok_key := Vector2i(int(floor(cen.x / 24.0)), int(floor(cen.y / 24.0)))
	for ox in range(-2, 3):
		for oz in range(-2, 3):
			var kk := Vector2i(ok_key.x + ox, ok_key.y + oz)
			if _occ.has(kk):
				for c in (_occ[kk] as Array):
					if _rects_overlap(cen.x, cen.y, yaw, w, d, float(c[0]), float(c[1]), float(c[2]), float(c[3]), float(c[4])):
						return false
	return true

func _add_building(cen: Vector2, w: float, d: float, h: float, yaw: float, wall: Color, roof: Color, zone: int, hip: bool, road: int, extra: Dictionary = {}) -> void:
	var ok_key := Vector2i(int(floor(cen.x / 24.0)), int(floor(cen.y / 24.0)))
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

## ¿Las cuatro esquinas del edificio quedan afuera de todo corredor de calle? (el borde de la propia vereda está a 0,8 m)
func _corners_clear(cen: Vector2, w: float, d: float, yaw: float) -> bool:
	var tg := Vector2(sin(yaw), cos(yaw))
	var nm := Vector2(cos(yaw), -sin(yaw))
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var wp := cen + tg * (float(sx) * w) + nm * (float(sz) * d)
			if probe(wp.x, wp.y)[0] > -0.3:
				return false
	return true

func _place_buildings() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		var kind := str(rd["kind"])
		if kind == "plaza":
			continue
		var pts: PackedVector3Array = rd["pts"]
		for side in [-1.0, 1.0]:
			var sdv: float = side
			var i := int(_rng.randf_range(0.0, 3.0))
			while i < pts.size() - 1:
				var p := pts[i]
				var zone := zone_of(p.x, p.z)
				if kind == "rural" or (kind == "coast" and sdv > 0.0):
					i += int(40.0 / STEP) # las rutas no tienen edificios y la costanera no se edifica del lado del mar
					continue
				var st := _style_for(zone, rd)
				var w := _rng.randf_range(float(st["w"][0]), float(st["w"][1]))
				var d := _rng.randf_range(float(st["d"][0]), float(st["d"][1]))
				var steps := maxi(1, int(ceil((w + _rng.randf_range(0.5, 3.5)) / STEP)))
				var j := mini(i + steps, pts.size() - 1)
				var a := pts[i]
				var b := pts[j]
				var t2 := Vector2(b.x - a.x, b.z - a.z)
				if t2.length() < 4.0:
					break
				var tn := t2.normalized()
				var nrm := Vector2(-tn.y, tn.x) * sdv
				var setback := float(rd["hw"]) + float(rd["sw"]) + 0.8
				var cen := Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5) + nrm * (setback + d * 0.5)
				var rad := Vector2(w, d).length() * 0.5
				if _clear_of_roads(cen.x, cen.y, rad * 0.78, ri) and _spot_free(cen, w, d, atan2(tn.x, tn.y)) and _corners_clear(cen, w, d, atan2(tn.x, tn.y)):
					var hh := _rng.randf_range(float(st["h"][0]), float(st["h"][1]))
					hh = maxf(3.2, roundf(hh / 3.2) * 3.2) # la altura se redondea a pisos de 3,2 m
					_add_building(cen, w, d, hh, atan2(tn.x, tn.y), WALLS[_rng.randi() % WALLS.size()], ROOFS[_rng.randi() % ROOFS.size()], zone, _rng.randf() < float(st["hip"]), ri)
				i = j

# ───────────────────────── puntos de interés ─────────────────────────
## Cada uno es un edificio especial pegado a una calle: [id, tipo, nombre, calle, distancia sobre la calle (m), lado, ancho, fondo, alto, color]
const POI_SPECS := [
	["concesionario", "dealer", "Concesionario Aurelia", "Avenida 7", 150.0, 1.0, 34.0, 22.0, 9.6, Color(0.20, 0.45, 0.85)],
	["taller_centro", "garage", "Taller Central", "Avenida 1", 200.0, -1.0, 26.0, 18.0, 8.0, Color(0.95, 0.45, 0.10)],
	["taller_puerto", "garage", "Taller del Puerto", "Costanera 90", 420.0, -1.0, 26.0, 18.0, 8.0, Color(0.95, 0.45, 0.10)],
	["mirador", "view", "Mirador de la Colina", "Camino de la Colina 300", -1.0, 1.0, 18.0, 14.0, 6.4, Color(0.95, 0.80, 0.25)],
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
		var cen := Vector2(a.x, a.z) + nrm * (float(rd["hw"]) + float(rd["sw"]) + 0.8 + float(sp[7]) * 0.5)
		if str(sp[1]) == "view":
			cen = Vector2(a.x, a.z) # el mirador es la plazoleta del final del camino
		var yaw := atan2(tn.x, tn.y)
		pois.append({"id": str(sp[0]), "kind": str(sp[1]), "name": str(sp[2]), "pos": cen, "yaw": yaw, "size": Vector2(float(sp[6]), float(sp[7])), "color": sp[9],
			"y": height(cen.x, cen.y), "road": ri, "front": Vector2(a.x, a.z) + nrm * (float(rd["hw"]) * 0.5)})
		if str(sp[1]) != "view":
			_add_building(cen, float(sp[6]), float(sp[7]), float(sp[8]), yaw, sp[9], sp[9].darkened(0.3), zone_of(cen.x, cen.y), false, ri, {"poi": str(sp[0]), "side": -side})
