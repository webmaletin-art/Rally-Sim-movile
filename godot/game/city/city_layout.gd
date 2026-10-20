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
const ROAD_UP := 0.04 # el asfalto se dibuja 4 cm arriba de la altura de la calle: el piso de la física (city_track.gd) sube lo mismo, así las ruedas apoyan sobre el asfalto y no adentro
const PLAZA_R := 48.0
const PARK_R := 44.0 # radio de la calle que rodea al Parque del Drift
const AVE := [[12.0, 1.0], [30.0, 1.0], [9.0, 2.0], [36.0, 1.0], [14.0, 2.0], [26.0, 1.0], [10.0, 2.0], [32.0, 1.0]] # por avenida: [desvío máximo (m), vueltas de curva cada 260 m]: no todas salen igual
const GRID_A0 := 135.0 # el barrio de manzanas cuadradas ocupa el sector entre la avenida 4 (135°) y la 5 (180°)
const GRID_A1 := 180.0
const POCKET := Vector2(90000.0, 0.0) # centro del túnel en cruz: un «bolsillo» del mundo, lejos de la ciudad y de la región (se entra y se sale por las bocas, con un fundido)
const POCKET_X0 := 75000.0 # desde acá (x) es el bolsillo
const REGION_R := 2250.0 # más allá de este radio el terreno lo da la región (si está cargada)
static func in_pocket(x: float) -> bool:
	return x > POCKET_X0
const GARAGE_RG := 26.0 # Estacionamiento Central: radio de la planta baja (al nivel de la calle)
const GARAGE_RU := 20.0 # radio de la planta alta y del subsuelo
const GARAGE_RAMP := 40.0 # largo de cada rampa entre las paredes de las salas
const GARAGE_DY := 4.4 # la planta alta está 4,4 m arriba y el subsuelo 4,4 m abajo
const RAMP_HW := 4.0
const TUNNEL_HALF := 900.0 # cada brazo de la cruz mide 900 m desde el centro
const RINGS := [130.0, 260.0, 390.0, 520.0, 650.0, 780.0, 910.0, 1040.0]
const COAST_R := 1120.0
const RURAL_END := 2300.0
const EXIT_TO := {20: "adventure", 40: "region", 60: "plaza", 80: "region"} # las salidas abiertas: la Ruta 20 sigue por la Ruta de los Sueños (Aventura); la Ruta 60 termina en la Plaza de Drift (está ahí mismo: no hay otro mapa); las rutas 40 y 80 siguen por la región hasta la circunvalación (sin portón ni cartel: la ruta sigue)
const WORLD_VERSION := 7 # sube cuando cambia el mapa (la «última ubicación» guardada de una versión anterior ya no sirve)
const DRIFT_GATE := 0.996 # la abertura de la plaza donde entra la ruta (coseno del ángulo: unos 8 m a cada lado)
const DRIFT_R := 90.0 # radio de la Plaza de Drift, al final de la Ruta 60
const HILL_C := Vector2(-1086.0, -1086.0) # centro de la colina (al noroeste)
const HILL_R := 430.0
const HILL_H := 72.0
const SEA_Z := 1260.0
const MT_A := Vector4(1950.0, 880.0, 1050.0, 72.0) # la sierra de la Ruta Panorámica: (x, z, radio, altura); cada loma es un montículo de borde suave
const MT_B := Vector4(2790.0, 1190.0, 520.0, 40.0)

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
var halls: Array = [] # {pos, r, h, y (altura del piso), gaps: [[ángulo, medio ancho]] (aberturas de la pared donde empiezan las rampas)}
var spawns: Array = [] # lugares donde aparece el jugador al entrar al mundo: dentro de un estacionamiento [x, z, rumbo]
var spawn_names: Array = [] # el nombre de cada lugar de aparición (el mismo orden que spawns)
var drift := {} # la Plaza de Drift: {c: centro, r: radio, h: altura (plana), cones: PackedVector2Array con los conos, dir: hacia donde mira la ruta}
var _flat_c := Vector2.ZERO # suelo plano de la plaza (se mezcla con el terreno alrededor)
var _flat_r := 0.0
var _flat_h := 0.0
var garage := {} # el Estacionamiento Central: {road, p (en la calle), nrm, tn, c: [centros de las tres salas], y: [alturas], r: [radios]}
var stations: Array = [] # gasolineras: {id, name, center, yaw, dir, tn, color, fuel_points: [Vector2], pumps: [Vector2], front}
# objetos de la calle (farolas, árboles, semáforos, bolardos): el id es el índice; salen igual en todos los teléfonos
var prop_signal: Dictionary = {} # id de semáforo → [id de la calle que regula, posición del cruce (Vector2)]
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
## Altura de un montículo de borde suave (0 fuera de su radio)
static func _mount(x: float, z: float, m: Vector4) -> float:
	var md := Vector2(x, z).distance_to(Vector2(m.x, m.y))
	if md >= m.z:
		return 0.0
	return m.w * (1.0 - smoothstep(0.0, m.z, md))

## Altura del terreno en (x, z): una meseta (la ciudad), el mar al sur, lomas suaves afuera y una colina al noroeste
var region # RegionData (o null): el terreno y los caminos de todo lo que rodea a la ciudad

## Altura del terreno del MUNDO: la de la ciudad y, más allá de REGION_R, la de la región (montañas, llanuras y los cortes de las rutas)
func height(x: float, z: float) -> float:
	if x > POCKET_X0:
		return 0.0 # el bolsillo de los túneles y del estacionamiento es plano
	if region != null and x * x + z * z > REGION_R * REGION_R:
		return region.height(x, z)
	return base_height(x, z)

## Altura de la ciudad sin la región (una función pura de la posición)
func base_height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var h := 9.0 * smoothstep(SEA_Z, SEA_Z - 220.0, z)
	h += 1.4 * sin(x * 0.0021 + 1.0) * cos(z * 0.0017)
	var d := Vector2(x, z).distance_to(HILL_C)
	var out := smoothstep(1100.0, 1500.0, r) * smoothstep(HILL_R, HILL_R + 300.0, d) # las lomas de afuera no se meten en la colina
	h += out * (11.0 * sin(x * 0.0031 + z * 0.0023) + 6.0 * sin(x * 0.0057 - z * 0.0049 + 2.0))
	h -= 12.0 * smoothstep(SEA_Z + 40.0, SEA_Z + 260.0, z) # el fondo del mar
	if d < HILL_R:
		h += HILL_H * (1.0 - d / HILL_R)
	var mh := _mount(x, z, MT_A)
	mh = maxf(mh, _mount(x, z, MT_B))
	h += mh
	if _flat_r > 0.0:
		var fd := Vector2(x, z).distance_to(_flat_c)
		if fd < _flat_r + 150.0:
			h = lerpf(_flat_h, h, smoothstep(_flat_r, _flat_r + 150.0, fd)) # la plaza de drift es plana y el terreno se une a ella de a poco
	return h

## ───── Terraplén de las rutas de campo (rural, atajo, panorámica, colina) · [B] 19/10/2026
## Reporte del dueño (Ruta Panorámica 70, cuadra 37): «el piso está más abajo que la ruta y salgo volando». La calle es una terraza a media ladera: al costado de abajo el terreno
## natural quedaba 1–2 m más bajo pegado al borde (un escalón) y al de arriba subía como una pared; además la malla visible se hundía junto a la calle y la física seguía el terreno
## natural, así que no coincidían. Ahora el terreno junto a estas rutas sale de UNA función (verge_height) que usan la malla (city_world._terrain_h) y el piso de la física
## (city_track.ground_info): del lado de abajo un terraplén que baja de a poco hasta el terreno natural; del lado de arriba una cuneta que sube suave hasta la ladera.
const VERGE_KINDS := ["rural", "shortcut", "scenic", "hill"]
const VERGE_LEVEL := -0.02 # el borde del terraplén queda a esta altura por debajo del eje de la calle (negativo = 2 cm arriba: a ras de la banquina, que se dibuja 16 cm arriba)
const VERGE_BW_MAX := 20.0 # hasta dónde (metros más allá de la banquina) se ablanda el terreno
var _verge_road := PackedByteArray() # por calle: 1 = ruta de campo (se arma con prepare_verge, una vez, después de build)
var _road_base := PackedInt32Array() # por calle: índice de su primer punto de muestra (s_x…)

func prepare_verge() -> void:
	var f := PackedByteArray()
	f.resize(roads.size())
	for i in roads.size():
		f[i] = 1 if str((roads[i] as Dictionary)["kind"]) in VERGE_KINDS else 0
	_verge_road = f

## Las rutas de campo cerca de (x, z): [e0, hr0, e1, hr1, …], una pareja por cada tramo distinto (la parte más cercana de cada uno), con e = metros más allá del borde (calzada + banquina;
## ≤ 0 = adentro) y hr = la altura del camino ahí. Vacío si no hay ninguna a menos de VERGE_BW_MAX m del borde.
func verge_roads(x: float, z: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if _verge_road.is_empty():
		return out
	var ids := PackedInt32Array()
	var kx := int(floor(x / HC))
	var kz := int(floor(z / HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				var rid := s_road[si]
				if _verge_road[rid] == 0:
					continue
				var ni := s_next[si]
				var ax := s_x[si]
				var az := s_z[si]
				var ex := 0.0
				var ez := 0.0
				var ey := 0.0
				if ni >= 0:
					ex = s_x[ni] - ax
					ez = s_z[ni] - az
					ey = s_y[ni] - s_y[si]
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var rd: Dictionary = roads[rid]
				var e := sqrt(ddx * ddx + ddz * ddz) - float(rd["hw"]) - float(rd["sw"])
				if e >= VERGE_BW_MAX:
					continue
				var grp := rid * 4096 + ((si - _road_base[rid]) >> 5) # (un tramo de la ruta = 32 puntos seguidos, 256 m, contados desde el primer punto de ESA calle: en una horquilla las dos ramas de la misma ruta son tramos distintos, y agregar puntos a otras calles no mueve los cortes)
				var j := ids.find(grp)
				if j < 0:
					ids.append(grp)
					out.append(e)
					out.append(s_y[si] + ey * t)
				elif e < out[j * 2]:
					out[j * 2] = e
					out[j * 2 + 1] = s_y[si] + ey * t
	return out

## La menor distancia al borde de las rutas de verge_roads (1e9 si no hay ninguna)
static func verge_min_e(v: PackedFloat64Array) -> float:
	var m := 1.0e9
	for i in range(0, v.size(), 2):
		m = minf(m, v[i])
	return m

## Altura del terreno junto a las rutas de campo: h = el terreno natural, v = verge_roads. Cada ruta aporta su terraplén (del lado de abajo) o su cuneta (del de arriba) y se mezclan
## por cercanía (así entre dos tramos de la misma ruta a distinto nivel, como en una horquilla, el terreno pasa de uno al otro sin un escalón). Igual a h si no hay ninguna cerca.
## Sobre la calzada de una de ellas no se usa (ahí manda el camino).
static func verge_height(h: float, v: PackedFloat64Array) -> float:
	var sw := 0.0
	var sh := 0.0
	for i in range(0, v.size(), 2):
		var e := maxf(v[i], 0.0)
		var low := v[i + 1] - VERGE_LEVEL
		var hv: float
		if h >= low:
			# la ladera sube del costado: una cuneta pegada a la banquina que sube suave hasta el terreno natural (ni pared ni hundimiento)
			hv = lerpf(low, h, smoothstep(6.0, 18.0, e))
		else:
			# el terreno cae del costado: un terraplén que baja de a poco (más largo cuanto más abajo está el terreno)
			var bw := clampf((low - h) * 1.7 + 6.0, 6.0, VERGE_BW_MAX)
			hv = lerpf(low, h, smoothstep(0.0, bw, e))
		var w := (1.0 - smoothstep(VERGE_BW_MAX - 6.0, VERGE_BW_MAX, e)) / (0.1 + e) # (con dos tramos a distinto nivel, esto hace una rampa pareja entre los dos; el aporte se apaga antes del límite)
		sw += w
		sh += w * hv
	if sw <= 0.0:
		return h
	# lejos de todas (cerca del límite de VERGE_BW_MAX) el aporte se desvanece hacia el terreno natural: con un peso de «terreno natural» que crece con la distancia a la más cercana
	var emin := verge_min_e(v)
	var fade := smoothstep(VERGE_BW_MAX - 4.0, VERGE_BW_MAX, emin)
	return lerpf(sh / sw, h, fade)

## ───── Paredes de la ciudad: sólo los edificios · [B] 19/10/2026
## Reporte del dueño: «hay una colisión invisible en la esquina; no me deja pasar a la otra calle ni hacer un finito de drift al edificio. Lo único que debe chocar son los edificios,
## las vallas, los guardarraíles y las banquinas». Antes la pared era el borde del corredor de la calle (calzada + vereda): en los cruces el corredor se achica en diagonal y la pared
## quedaba 1–5 m ANTES de la fachada, y donde no había edificio (esquinas, huecos) también. Ahora, en las calles de la ciudad (major, minor, alley, ring, plaza) chocan las
## losas de fachada (las mismas cajas que se dibujan) y los edificios especiales; en las rutas de campo, la costanera, las bahías y los túneles sigue la pared del corredor.
const WALL_CELL := 16.0
const DENSE_KINDS := ["major", "minor", "alley", "ring", "plaza"]
var _wq := PackedFloat32Array() # 8 números por cuadrilátero (A, B, C, D en sentido antihorario)
var _wcells: Dictionary = {} # Vector2i (16 m) -> PackedInt32Array de cuadriláteros que tocan esa celda
var _dense_road := PackedByteArray() # por calle: 1 = calle de la ciudad (la pared son los edificios)
## Huecos entre edificios (20/10/2026, pedido del dueño: «los huecos entre edificios no se pueden abrir: el jugador no puede entrar entre los edificios; si hace falta, colisión invisible, así no
## gastamos recursos del teléfono»). Con la pared hecha sólo de edificios (arriba) cada lugar de la línea de edificación SIN losa quedaba abierto y el auto se metía adentro de las manzanas
## (medido: 289 bolsillos, 100 000 m²). _close_gaps recorre lo que las losas no cubren y cierra con una pared que no se dibuja (sólo choca) todo lo que NO sea: una calle que cruza, un
## lugar especial (concesionario, taller: tienen su propia pared y su entrada), una estación (se carga nafta) ni una zona abierta del Drift (Plaza y Parque del Drift). Las plazas y parques
## que no son del Drift (la Plaza Aurora) quedan cerrados.
const GAP_WALL_T := 3.0 # espesor (m) de cada pared de relleno, hacia atrás de la línea de edificación
var _gap_quads := PackedFloat32Array() # 8 números por cuadrilátero (A, B, C, D), igual que _wq
var gap_wall_len := 0.0 # metros de pared de relleno (estadística)

func prepare_walls() -> void:
	_dense_road.resize(roads.size())
	for i in roads.size():
		_dense_road[i] = 1 if str((roads[i] as Dictionary)["kind"]) in DENSE_KINDS else 0
	_wq = PackedFloat32Array()
	_wcells = {}
	for key in slabs:
		for sl in (slabs[key] as Array):
			var pts: PackedVector3Array = sl["pts"]
			var away: PackedVector2Array = sl["away"]
			var depth: float = sl["depth"]
			for i in pts.size() - 1:
				var a := Vector2(pts[i].x, pts[i].z)
				var b := Vector2(pts[i + 1].x, pts[i + 1].z)
				if a.distance_squared_to(b) < 0.0004:
					continue
				_add_wall_quad(a, b, b + away[i + 1] * depth, a + away[i] * depth)
	for key in buildings:
		for bd in (buildings[key] as Array):
			var yaw: float = bd["yaw"]
			var tg := Vector2(sin(yaw), cos(yaw))
			var nm := Vector2(cos(yaw), -sin(yaw))
			var cen := Vector2(float(bd["x"]), float(bd["z"]))
			var w2: float = float(bd["w"]) * 0.5
			var d2: float = float(bd["d"]) * 0.5
			_add_wall_quad(cen - tg * w2 - nm * d2, cen + tg * w2 - nm * d2, cen + tg * w2 + nm * d2, cen - tg * w2 + nm * d2)
	_corr = {}
	for gi in range(0, _gap_quads.size(), 8):
		_add_gap_wall(PackedVector2Array([Vector2(_gap_quads[gi], _gap_quads[gi + 1]), Vector2(_gap_quads[gi + 2], _gap_quads[gi + 3]), Vector2(_gap_quads[gi + 4], _gap_quads[gi + 5]), Vector2(_gap_quads[gi + 6], _gap_quads[gi + 7])]))

var _corr: Dictionary = {} # punto -> el corredor (calzada + vereda) de ese tramo (corridor_poly)

## El corredor (calzada + vereda) del tramo que sale del punto si: el mismo cuadrilátero que ribbon_poly pero con el ancho de la vereda; vacío si no hay tramo o es un túnel
func corridor_poly(si: int) -> PackedVector2Array:
	if _corr.has(si):
		return _corr[si]
	var out := PackedVector2Array()
	var ni: int = s_next[si]
	var rd: Dictionary = roads[s_road[si]]
	if ni >= 0 and Vector2(s_x[ni] - s_x[si], s_z[ni] - s_z[si]).length() >= 0.05 and str(rd["kind"]) != "tunnel":
		var half := float(rd["hw"]) + float(rd["sw"])
		var ma := miter(si)
		var mb := miter(ni)
		var a := Vector2(s_x[si], s_z[si])
		var b := Vector2(s_x[ni], s_z[ni])
		var na := Vector2(ma.x, ma.y)
		var nb := Vector2(mb.x, mb.y)
		out = PackedVector2Array([a - na * (half * ma.z), b - nb * (half * mb.z), b + nb * (half * mb.z), a + na * (half * ma.z)])
	_corr[si] = out
	return out

## Pared de relleno (20/10/2026, tarde; reporte del dueño: «siguen habiendo colisión invisible»): el relleno de _close_gaps / _cap_dead_ends / _close_station_lots cierra la línea de edificación,
## pero en la boca de una calle, en una esquina o en una curva se metía adentro de una calle o de una vereda (medido: 572 de 2347 paredes, hasta 23 m² en la salida de las avenidas de la plaza).
## Ahora se recorta contra el corredor de TODAS las calles (calzada + vereda) y contra las esquinas redondeadas: queda sólo lo que está afuera, donde sí iría un edificio.
func _add_gap_wall(q: PackedVector2Array) -> void:
	var parts: Array = [q]
	var box := poly_box(q)
	var seen := {}
	# (las muestras de las calles cuyo corredor llega hasta acá pueden estar a una celda de distancia: un tramo de 8 m con su ancho llega a ~13 m)
	for kx in range(int(floor((box.position.x - 16.0) / HC)), int(floor((box.end.x + 16.0) / HC)) + 1):
		for kz in range(int(floor((box.position.y - 16.0) / HC)), int(floor((box.end.y + 16.0) / HC)) + 1):
			var lst: Variant = _hash.get(Vector2i(kx, kz))
			if lst == null:
				continue
			for sj in (lst as PackedInt32Array):
				if seen.has(sj):
					continue
				seen[sj] = true
				var cp := corridor_poly(sj)
				if cp.is_empty() or not poly_box(cp).intersects(box):
					continue
				parts = _cut_parts(parts, cp)
				if parts.is_empty():
					return
	for f in fillets_in(box):
		parts = _cut_parts(parts, f)
		if parts.is_empty():
			return
	for part in parts:
		var pp: PackedVector2Array = part
		if pp.size() == 4:
			_add_wall_quad(pp[0], pp[1], pp[2], pp[3])
			continue
		var idx := Geometry2D.triangulate_polygon(pp)
		for i in range(0, idx.size(), 3):
			var a := pp[idx[i]]
			var b := pp[idx[i + 1]]
			var c := pp[idx[i + 2]]
			if absf((b - a).cross(c - a)) < 0.002:
				continue
			_add_wall_quad(a, b, c, (a + c) * 0.5) # (un triángulo es un cuadrilátero con un vértice sobre un lado)

## Lo que queda de los polígonos `parts` después de sacarles el polígono `cut`
static func _cut_parts(parts: Array, cut: PackedVector2Array) -> Array:
	var cb := poly_box(cut)
	var next: Array = []
	for p in parts:
		var pp: PackedVector2Array = p
		if not poly_box(pp).intersects(cb):
			next.append(pp)
			continue
		for r in Geometry2D.clip_polygons(pp, cut):
			if not Geometry2D.is_polygon_clockwise(r) and poly_area(r) > 0.02:
				next.append(r)
	return next

func _add_wall_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	# sentido antihorario (área con signo positiva)
	var area := (b - a).cross(c - a) + (c - a).cross(d - a)
	if area < 0.0:
		var t := b
		b = d
		d = t
	var qi := _wq.size() / 8
	_wq.append_array(PackedFloat32Array([a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y]))
	var x0 := minf(minf(a.x, b.x), minf(c.x, d.x))
	var x1 := maxf(maxf(a.x, b.x), maxf(c.x, d.x))
	var z0 := minf(minf(a.y, b.y), minf(c.y, d.y))
	var z1 := maxf(maxf(a.y, b.y), maxf(c.y, d.y))
	for cx in range(int(floor(x0 / WALL_CELL)), int(floor(x1 / WALL_CELL)) + 1):
		for cz in range(int(floor(z0 / WALL_CELL)), int(floor(z1 / WALL_CELL)) + 1):
			var k := Vector2i(cx, cz)
			var arr: PackedInt32Array = _wcells.get(k, PackedInt32Array())
			arr.append(qi)
			_wcells[k] = arr

## ¿La calle ri es una calle de la ciudad (la pared son los edificios) y no una ruta de campo, una bahía o un túnel?
func is_dense_road(ri: int) -> bool:
	return ri >= 0 and ri < _dense_road.size() and _dense_road[ri] == 1

## Empuje de los edificios sobre un círculo (x, z, r): (nx, nz, profundidad) con la normal hacia donde hay que moverse; profundidad ≤ 0 = no toca ninguno
func wall_push(x: float, z: float, r: float) -> Vector3:
	var best := Vector3.ZERO
	if _wcells.is_empty():
		return best
	for cx in range(int(floor((x - r) / WALL_CELL)), int(floor((x + r) / WALL_CELL)) + 1):
		for cz in range(int(floor((z - r) / WALL_CELL)), int(floor((z + r) / WALL_CELL)) + 1):
			var lst: Variant = _wcells.get(Vector2i(cx, cz))
			if lst == null:
				continue
			for qi in (lst as PackedInt32Array):
				var h := _quad_push(x, z, r, qi) # (un cuadrilátero que toca dos celdas se mira dos veces: no importa)
				if h.z > best.z:
					best = h
	return best

func _quad_push(x: float, z: float, r: float, qi: int) -> Vector3:
	var o := qi * 8
	var inside := true
	var bd2 := 1.0e18
	var bdx := 0.0
	var bdz := 0.0
	var bi := 0
	var onx := 0.0
	var onz := 0.0
	for e in 4:
		var ax := _wq[o + e * 2]
		var az := _wq[o + e * 2 + 1]
		var n2 := (e + 1) % 4
		var bx := _wq[o + n2 * 2]
		var bz := _wq[o + n2 * 2 + 1]
		var ex := bx - ax
		var ez := bz - az
		var l2 := ex * ex + ez * ez
		var t := 0.0
		if l2 > 1.0e-9:
			t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
		var dx := x - (ax + ex * t)
		var dz := z - (az + ez * t)
		var d2 := dx * dx + dz * dz
		if ex * (z - az) - ez * (x - ax) < 0.0:
			inside = false
		if d2 < bd2:
			bd2 = d2
			bdx = dx
			bdz = dz
			bi = e
			var ln := sqrt(l2)
			if ln > 1.0e-6:
				onx = ez / ln # normal hacia afuera de la arista (antihorario)
				onz = -ex / ln
	if inside:
		return Vector3(onx, onz, r + sqrt(bd2))
	if bd2 >= r * r:
		return Vector3.ZERO
	var d := sqrt(bd2)
	if d < 1.0e-4:
		return Vector3(onx, onz, r)
	return Vector3(bdx / d, bdz / d, r - d)

## ───── Esquinas y cruces: calzadas, esquinas redondeadas y recortes · [B] 19/10/2026
## Reporte del dueño: «las terminaciones de la vereda están todas mal hechas, las rayas se cruzan, el camino de tierra pasa por arriba del asfalto de la otra ruta; hacelo de una vez».
## Antes cada tramo de vereda y de raya se dibujaba entero y sólo se salteaba el tramo cuyo medio caía en otra calle: en los cruces quedaban escalones, cuñas que se metían en la calle
## de al lado, rayas que cruzaban otra calzada. Ahora (city_world._road_segment):
##  · cada calle de la ciudad tiene su calzada como polígono (ribbon_poly: la misma que se dibuja);
##  · en cada cruce, la unión de las calzadas se «cierra» con un radio (FILLET_R): lo que se agrega es la esquina redondeada del pavimento (fillets);
##  · las veredas y las rayas de cada tramo se recortan contra las calzadas de las otras calles y contra esas esquinas (clip_obstacles): la vereda termina en el cordón del cruce y
##    la raya no pasa por arriba de otra calzada. El piso de la física sigue lo mismo (ground_info: la vereda a la altura del cordón, la esquina como asfalto).
## 20/10/2026, pedido del dueño («la vereda, que sea un plano nomás, sin polígonos, sin altura: necesito fluidez, no más saltos al andar fuerte»): la vereda y la banquina son un plano a 1 cm
## del asfalto (sin cordón ni escalón: ni caras verticales para dibujar ni un salto de 16 cm al cruzarla a velocidad). Antes 16 cm de cordón con su cara vertical.
const CURB := 0.05 # la vereda se dibuja a esta altura sobre el eje de la calle (el asfalto, a ROAD_UP = 0,04)
const FILLET_R := 4.5
var fillets: Array = [] # PackedVector2Array por esquina redondeada
var _fcells: Dictionary = {} # Vector2i (16 m) -> PackedInt32Array de esquinas que tocan esa celda
var _ribbons: Dictionary = {} # punto -> la calzada de ese tramo (PackedVector2Array)
var _obst: Dictionary = {} # punto -> Array de {poly, hw, fil}: lo que recorta a la vereda y las rayas de ese tramo

## Normal (hacia la derecha del avance) en el punto si, unida con la del tramo anterior para que las curvas no queden con huecos. Devuelve (nx, nz, escala del ancho)
func miter(si: int) -> Vector3:
	var ni: int = s_next[si]
	var pi: int = s_prev[si]
	var d1 := Vector2.ZERO
	var d0 := Vector2.ZERO
	# un vecino pegado al punto (la costura de una circunvalación que cierra sobre sí misma repite el primer punto) no da dirección: normalized() de un vector casi nulo apunta a cualquier lado
	if ni >= 0:
		var v1 := Vector2(s_x[ni] - s_x[si], s_z[ni] - s_z[si])
		if v1.length() >= 0.05:
			d1 = v1.normalized()
	if pi >= 0:
		var v0 := Vector2(s_x[si] - s_x[pi], s_z[si] - s_z[pi])
		if v0.length() >= 0.05:
			d0 = v0.normalized()
	if d1 == Vector2.ZERO:
		d1 = d0
	if d0 == Vector2.ZERO:
		d0 = d1
	var n1 := Vector2(-d1.y, d1.x)
	var n0 := Vector2(-d0.y, d0.x)
	var m := n0 + n1
	if m.length() < 0.05:
		return Vector3(n1.x, n1.y, 1.0)
	m = m.normalized()
	var k := clampf(1.0 / maxf(m.dot(n1), 0.55), 1.0, 1.8)
	return Vector3(m.x, m.y, k)

## La calzada del tramo que sale del punto si (cuadrilátero en x, z), igual a la que dibuja city_world; vacío si no hay tramo
func ribbon_poly(si: int) -> PackedVector2Array:
	if _ribbons.has(si):
		return _ribbons[si]
	var out := PackedVector2Array()
	var ni: int = s_next[si]
	if ni >= 0 and Vector2(s_x[ni] - s_x[si], s_z[ni] - s_z[si]).length() >= 0.05 and str((roads[s_road[si]] as Dictionary)["kind"]) != "tunnel":
		var hw := float((roads[s_road[si]] as Dictionary)["hw"])
		var ma := miter(si)
		var mb := miter(ni)
		var a := Vector2(s_x[si], s_z[si])
		var b := Vector2(s_x[ni], s_z[ni])
		var na := Vector2(ma.x, ma.y)
		var nb := Vector2(mb.x, mb.y)
		out = PackedVector2Array([a - na * (hw * ma.z), b - nb * (hw * mb.z), b + nb * (hw * mb.z), a + na * (hw * ma.z)])
	_ribbons[si] = out
	return out

static func poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5

static func poly_box(p: PackedVector2Array) -> Rect2:
	var lo := p[0]
	var hi := p[0]
	for q in p:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	return Rect2(lo, hi - lo)

## Suma el polígono p a la unión acc (lista de polígonos disjuntos)
static func _union_add(acc: Array, p: PackedVector2Array) -> Array:
	var cur := p
	var rest: Array = []
	for q in acc:
		var r: Array = Geometry2D.merge_polygons(cur, q)
		if r.size() == 1:
			cur = r[0]
		else:
			rest.append(q)
	rest.append(cur)
	return rest

## Arma las esquinas redondeadas de todos los cruces (una vez, después de build)
func prepare_fillets() -> void:
	fillets = []
	_fcells = {}
	_ribbons = {}
	_obst = {}
	for j in junctions:
		var rids: Array = j["roads"]
		var skip := false
		for rid in rids:
			if str((roads[int(rid)] as Dictionary)["kind"]) == "tunnel":
				skip = true
		if skip:
			continue
		var jp: Vector2 = j["pos"]
		var acc: Array = []
		var kx := int(floor(jp.x / HC))
		var kz := int(floor(jp.y / HC))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var k2 := Vector2i(kx + dx, kz + dz)
				if not _hash.has(k2):
					continue
				for si in (_hash[k2] as PackedInt32Array):
					if not rids.has(int(s_road[si])) or Vector2(s_x[si], s_z[si]).distance_to(jp) > 46.0:
						continue
					var poly := ribbon_poly(si)
					if not poly.is_empty():
						acc = _union_add(acc, poly)
		if acc.is_empty():
			continue
		var u: PackedVector2Array = acc[0]
		for q in acc:
			if poly_area(q) > poly_area(u):
				u = q
		var d1: Array = Geometry2D.offset_polygon(u, FILLET_R, Geometry2D.JOIN_ROUND)
		if d1.is_empty():
			continue
		var big: PackedVector2Array = d1[0]
		for q in d1:
			if poly_area(q) > poly_area(big):
				big = q
		var d2: Array = Geometry2D.offset_polygon(big, -FILLET_R, Geometry2D.JOIN_ROUND)
		if d2.is_empty():
			continue
		var closed: PackedVector2Array = d2[0]
		for q in d2:
			if poly_area(q) > poly_area(closed):
				closed = q
		for fp in Geometry2D.clip_polygons(closed, u):
			if Geometry2D.is_polygon_clockwise(fp) or poly_area(fp) < 0.8:
				continue
			_add_fillet(fp)

func _add_fillet(fp: PackedVector2Array) -> void:
	var fi := fillets.size()
	fillets.append(fp)
	var bx := poly_box(fp)
	for cx in range(int(floor(bx.position.x / 16.0)), int(floor(bx.end.x / 16.0)) + 1):
		for cz in range(int(floor(bx.position.y / 16.0)), int(floor(bx.end.y / 16.0)) + 1):
			var k := Vector2i(cx, cz)
			var arr: PackedInt32Array = _fcells.get(k, PackedInt32Array())
			arr.append(fi)
			_fcells[k] = arr

## Las esquinas redondeadas cuyo recuadro toca el recuadro r
func fillets_in(r: Rect2) -> Array:
	var out: Array = []
	var seen := {}
	for cx in range(int(floor(r.position.x / 16.0)), int(floor(r.end.x / 16.0)) + 1):
		for cz in range(int(floor(r.position.y / 16.0)), int(floor(r.end.y / 16.0)) + 1):
			var lst: Variant = _fcells.get(Vector2i(cx, cz))
			if lst == null:
				continue
			for fi in (lst as PackedInt32Array):
				if seen.has(fi):
					continue
				seen[fi] = true
				if poly_box(fillets[fi]).intersects(r):
					out.append(fillets[fi])
	return out

## Terreno junto a las calles de la ciudad: a ras del asfalto (3 cm por debajo), no 50 cm más abajo como antes: con las esquinas y los huecos entre edificios libres (CityLayout.wall_push) el
## auto puede pasar por ahí y se veía una zanja. h = el terreno natural, pr = probe(x, z). La malla (city_world._terrain_h) y el piso de la física (city_track.ground_info) usan esto.
func dense_ground(h: float, pr: PackedFloat64Array) -> float:
	var ri := int(pr[6])
	if ri < 0 or not is_dense_road(ri):
		return h
	var lim := 20.0 if float(pr[4]) < -0.3 else 7.0
	var w := smoothstep(-lim - 9.0, -lim + 3.0, float(pr[0]))
	return lerpf(h, minf(h, float(pr[4]) - 0.03), w)

## Altura del eje de la calle más cercana a q (para las esquinas redondeadas): la del punto del eje más cercano (interpolada entre los dos puntos del tramo, no la del punto de muestra más
## cercano: en una ladera eso daba escalones de 0,2–0,5 m en las esquinas de los cruces)
func road_y_near(q: Vector2) -> float:
	var best := 1.0e18
	var by := height(q.x, q.y)
	var kx := int(floor(q.x / HC))
	var kz := int(floor(q.y / HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				if str((roads[s_road[si]] as Dictionary)["kind"]) == "tunnel":
					continue
				var ni := s_next[si]
				var ax := s_x[si]
				var az := s_z[si]
				var t := 0.0
				var ey := 0.0
				if ni >= 0:
					var ex := s_x[ni] - ax
					var ez := s_z[ni] - az
					var l2 := ex * ex + ez * ez
					if l2 > 1.0e-9:
						t = clampf(((q.x - ax) * ex + (q.y - az) * ez) / l2, 0.0, 1.0)
					ey = s_y[ni] - s_y[si]
				var cx := ax + (s_x[ni] - ax) * t if ni >= 0 else ax
				var cz := az + (s_z[ni] - az) * t if ni >= 0 else az
				var d := Vector2(cx, cz).distance_squared_to(q)
				if d < best:
					best = d
					by = s_y[si] + ey * t
	return by

## ¿El punto está en una esquina redondeada (asfalto)?
func on_fillet(x: float, z: float) -> bool:
	var lst: Variant = _fcells.get(Vector2i(int(floor(x / 16.0)), int(floor(z / 16.0))))
	if lst == null:
		return false
	var p := Vector2(x, z)
	for fi in (lst as PackedInt32Array):
		if Geometry2D.is_point_in_polygon(p, fillets[fi]):
			return true
	return false

## Lo que recorta a la vereda y a las rayas del tramo que sale del punto si: las calzadas de las otras calles (o de otro tramo de la misma, como en la X de la Panorámica) y las esquinas
## redondeadas cercanas. Cada una: {poly, hw, fil}
func clip_obstacles(si: int) -> Array:
	if _obst.has(si):
		return _obst[si]
	var out: Array = []
	var ni: int = s_next[si]
	if ni >= 0:
		var own := int(s_road[si])
		var rd: Dictionary = roads[own]
		var a := Vector2(s_x[si], s_z[si])
		var b := Vector2(s_x[ni], s_z[ni])
		var reach := float(rd["hw"]) + float(rd["sw"]) + 1.0
		var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach), (b - a).abs() + Vector2(reach, reach) * 2.0)
		var mid := (a + b) * 0.5
		var kx := int(floor(mid.x / HC))
		var kz := int(floor(mid.y / HC))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k2 := Vector2i(kx + dx, kz + dz)
				if not _hash.has(k2):
					continue
				for sj in (_hash[k2] as PackedInt32Array):
					var rj := int(s_road[sj])
					if sj == si or (rj == own and absi(sj - si) <= 40):
						continue
					var poly := ribbon_poly(sj)
					if poly.is_empty() or not poly_box(poly).intersects(box):
						continue
					# (una plaza o un parque redondo recorta las rayas de cualquier calle que lo cruza, aunque su calzada sea más angosta: la avenida 2 atraviesa el Parque del Drift)
					out.append({"poly": poly, "hw": 99.0 if str((roads[rj] as Dictionary)["kind"]) == "plaza" else float((roads[rj] as Dictionary)["hw"]), "fil": false})
		for f in fillets_in(box):
			out.append({"poly": f, "hw": 99.0, "fil": true})
	_obst[si] = out
	return out

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
var _traffic: RefCounted
var _signals: RefCounted

## Grafo de tránsito de la ciudad (se arma la primera vez que se pide; ver world/traffic_graph.gd)
func traffic() -> RefCounted:
	if _traffic == null:
		_traffic = preload("res://game/world/traffic_graph.gd").new()
		_traffic.build(self)
	return _traffic

## Semáforos funcionales (fases por reloj del mundo; ver world/traffic_signals.gd)
func traffic_signals() -> RefCounted:
	if _signals == null:
		_signals = preload("res://game/world/traffic_signals.gd").new()
		_signals.build(traffic(), self)
	return _signals

func build() -> void:
	_traffic = null
	_signals = null
	_rng.seed = seed_v
	_make_roads()
	_index()
	_mark_junction_samples()
	_level_junctions()
	for ex in exits:
		ex["to"] = str(EXIT_TO.get(int(ex["num"]), "")) # a qué otro mapa lleva la Salida ("" = todavía cerrada)
	_place_pois()
	_place_stations()
	_place_tolls()
	_place_garage()
	_place_dealers()
	_place_facades()
	_close_station_lots()
	_place_props()
	_place_roadside()
	_place_guardrails()
	_place_drift_plaza()

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
	for i in range(-3, 4): # paralelas al eje del sector (más separadas: manzanas grandes y calles claras, no una trama apretada)
		var pts := PackedVector2Array()
		var runs: Array = []
		var s_ := 230.0
		while s_ < 1040.0:
			var p := u * s_ + v * (float(i) * 150.0)
			if _in_grid(p, -1.0):
				pts.append(p)
			elif pts.size() > 0:
				runs.append(pts)
				pts = PackedVector2Array()
			s_ += STEP
		if pts.size() > 0:
			runs.append(pts)
		lines.append_array(runs)
	for j in range(0, 6): # transversales
		var pts := PackedVector2Array()
		var runs: Array = []
		var t := -620.0
		while t < 620.0:
			var p := u * (300.0 + float(j) * 140.0) + v * t
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

## Plaza de Drift: un playón redondo y plano al final de la Ruta 60 (a la que se llega manejando, sin otro mapa), con conos con física. El terreno se aplana alrededor (height()).
func _make_drift_plaza() -> void:
	var r_last := 1040.0 + floorf((RURAL_END - 1040.0) / STEP) * STEP
	var last := _rural_pos(6, r_last)
	var dn := (last - _rural_pos(6, r_last - STEP)).normalized()
	var c := last + dn * (DRIFT_R - 2.0)
	_flat_r = 0.0
	_flat_h = height(c.x, c.y)
	_flat_c = c
	_flat_r = DRIFT_R
	var cones := PackedVector2Array()
	for i in 44:
		var a := TAU * float(i) / 44.0
		cones.append(c + Vector2(cos(a), sin(a)) * 62.0)
	for i in 30:
		var a := TAU * float(i) / 30.0 + 0.1
		cones.append(c + Vector2(cos(a), sin(a)) * 34.0)
	for i in 14:
		var a := TAU * float(i) / 14.0
		cones.append(c + Vector2(cos(a), sin(a)) * 10.0)
	var per := Vector2(-dn.y, dn.x)
	for i in 12: # un slalom a lo largo de la plaza
		cones.append(c + dn * (-52.0 + float(i) * 9.0) + per * (4.0 if i % 2 == 0 else -4.0))
	drift = {"c": c, "r": DRIFT_R, "h": _flat_h, "cones": cones, "dir": dn}
	open_areas.append({"pos": c, "r": DRIFT_R, "name": "Plaza de Drift", "paving": true, "flat": true, "nb": DRIFT_R + 8.0})

## Cerco de postes alrededor de la plaza (con una abertura donde entra la ruta) y el lugar en el mapa
func _place_drift_plaza() -> void:
	if drift.is_empty():
		return
	var c: Vector2 = drift["c"]
	var dn: Vector2 = drift["dir"]
	var n := int(ceil(TAU * (DRIFT_R - 1.0) / 6.0))
	for i in n:
		var a := TAU * float(i) / float(n)
		var u := Vector2(cos(a), sin(a))
		if u.dot(-dn) > DRIFT_GATE:
			continue # por acá entra la ruta
		_add_prop(13, c.x + u.x * (DRIFT_R - 1.0), c.y + u.y * (DRIFT_R - 1.0), -u)
	var front := c - dn * (DRIFT_R - 14.0)
	pois.append({"id": "plaza_drift", "kind": "drift", "name": "Plaza de Drift", "pos": c, "yaw": atan2(dn.x, dn.y), "size": Vector2(2, 2), "color": Color(0.55, 0.85, 1.0), "y": float(drift["h"]), "road": road_named("Ruta 60"),
		"front": front, "shop": "", "door": c, "dir": Vector2(-dn.y, dn.x), "road_yaw": atan2(dn.x, dn.y)})

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
	_make_drift_plaza()
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
	# Ruta Panorámica: sale del extremo este de la costanera, trepa la sierra con curvas y baja a la costa
	_sample_road(id, "Ruta Panorámica 70", 70, "scenic", 4.6, 3.6, _scenic_plan())
	id += 1
	id = _make_tunnels(id)
	_weld_loose_ends()

## Trazado de la Ruta Panorámica: waypoints suavizados (Chaikin) con ondulación; arranca 2,5 m antes del extremo de la costanera para cruzarla y termina antes de x = 3000 (el bolsillo plano de los túneles)
const SCENIC_C := Vector2(1950.0, 880.0) # centro de la sierra: el camino la rodea en espiral subiendo
func _scenic_plan() -> PackedVector2Array:
	var pts: Array = []
	var a0 := deg_to_rad(35.0)
	pts.append(Vector2(cos(a0), sin(a0)) * COAST_R + Vector2(-sin(a0), cos(a0)) * 2.5) # 2,5 m adentro de la costanera
	pts.append(Vector2(960.0, 690.0))
	# espiral: de 190° a 514° (casi una vuelta) con el radio bajando de 950 a 150 m
	var a := 190.0
	while a <= 514.0:
		var r := 950.0 - 800.0 * (a - 190.0) / 324.0
		pts.append(SCENIC_C + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * r)
		a += 6.0
	# bajada: la espiral sigue en sentido contrario al reloj... al revés: gira hacia el sur-este y se abre (el radio crece despacio al principio para no meterse en el mar)
	var da := 154.0
	while da >= 18.0:
		var u := (154.0 - da) / 136.0
		var rr := 150.0 + 560.0 * pow(u, 1.9)
		pts.append(SCENIC_C + Vector2(cos(deg_to_rad(da)), sin(deg_to_rad(da))) * rr)
		da -= 6.0
	for wp in [[2680.0, 1090.0], [2790.0, 1130.0], [2900.0, 1085.0]]: # y el tramo de costa hasta el final
		pts.append(Vector2(float(wp[0]), float(wp[1])))
	for it in 2: # Chaikin: redondea las esquinas
		var nxt: Array = [pts[0]]
		for i in range(pts.size() - 1):
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			nxt.append(p0.lerp(p1, 0.25))
			nxt.append(p0.lerp(p1, 0.75))
		nxt.append(pts[pts.size() - 1])
		pts = nxt
	var cum: Array = [0.0]
	for i in range(1, pts.size()):
		cum.append(float(cum[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
	var total := float(cum[cum.size() - 1])
	# remuestreo a STEP metros con una ondulación suave (nula en las puntas)
	var out := PackedVector2Array()
	var k := 1
	var d := 0.0
	while d <= total:
		while k < pts.size() - 1 and float(cum[k]) < d:
			k += 1
		var t := clampf((d - float(cum[k - 1])) / maxf(float(cum[k]) - float(cum[k - 1]), 0.001), 0.0, 1.0)
		var p: Vector2 = (pts[k - 1] as Vector2).lerp(pts[k], t)
		var tn: Vector2 = ((pts[k] as Vector2) - (pts[k - 1] as Vector2)).normalized()
		var env := smoothstep(0.0, 120.0, d) * smoothstep(0.0, 120.0, total - d)
		p += Vector2(-tn.y, tn.x) * (9.0 * env * sin(d / 55.0))
		out.append(p)
		d += STEP
	return out

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
	if _road_base.size() <= ri:
		_road_base.resize(ri + 1)
	_road_base[ri] = base
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
	# la Ruta Panorámica arranca en el extremo de la costanera (que termina ahí): el cruce se agrega a mano
	var sc := road_named("Ruta Panorámica 70")
	var co := road_named("Costanera 90")
	if sc >= 0 and co >= 0:
		var sp0: Vector3 = (roads[sc]["pts"] as PackedVector3Array)[0]
		junctions.append({"pos": Vector2(sp0.x, sp0.z), "y": sp0.y, "roads": [co, sc], "major": false, "hw": 6.0})
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
	# la Ruta Panorámica se cruza a sí misma (la espiral de subida con la de bajada, a ras: las dos pasan por la misma altura): ahí tampoco se pintan las rayas del medio
	# ([B] 19/10/2026: se veían dos líneas amarillas cruzadas en el medio de la calzada). No es un cruce con semáforos ni para el GPS: sólo se apagan las rayas.
	var scn := road_named("Ruta Panorámica 70")
	if scn >= 0:
		var spts: PackedVector3Array = roads[scn]["pts"]
		var snj: PackedByteArray = roads[scn]["nj"]
		var sreach := float(roads[scn]["hw"]) + float(roads[scn]["sw"]) + 5.0
		for i in range(spts.size() - 1):
			var pa := Vector2(spts[i].x, spts[i].z)
			var pb := Vector2(spts[i + 1].x, spts[i + 1].z)
			for k in range(i + 12, spts.size() - 1):
				var pc := Vector2(spts[k].x, spts[k].z)
				if pa.distance_squared_to(pc) > 900.0:
					continue
				var hit2: Variant = Geometry2D.segment_intersects_segment(pa, pb, pc, Vector2(spts[k + 1].x, spts[k + 1].z))
				if hit2 == null:
					continue
				var hp2: Vector2 = hit2
				for m in spts.size():
					if Vector2(spts[m].x, spts[m].z).distance_to(hp2) < sreach:
						snj[m] = 1
		roads[scn]["nj"] = snj

## ───── Bocas de calle y cruces a la misma altura · [B] 20/10/2026 (sexta tanda)
## Reporte del dueño con capturas: «hay pedazos de tierra en la calle, retazos de tierra en esquinas, una rampa invisible en un cruce de la Ruta 80 (cuadra 4)». Dos causas del mapa:
##  · Las avenidas 2, 4 y 8 y varias calles chicas EMPEZABAN SUELTAS, a 1–10 m de la calzada de la calle donde desembocan (la Plaza Aurora, la calle 40 del casco viejo, la calle 80 de la grilla):
##    la vereda de la otra calle cruzaba la boca como una franja beige y quedaban huecos de terreno. Ahora el extremo se prolonga hasta pasar el eje de la otra calle (_weld_loose_ends).
##  · Cada calle copia la altura del terreno a lo largo de su eje y es PLANA de lado a lado; en una ladera, dos calles que se cruzan quedan a distinta altura en la zona donde se pisan
##    (hasta 0,8 m en los cruces de los atajos con las rutas y de la avenida 3 con la costanera): el auto subía una rampa que no se ve. Ahora la calle que termina (o la más angosta)
##    pasa el cruce a la altura de la otra y vuelve a su perfil de a poco (_level_junctions).
var s_lv := PackedByteArray() # por punto de muestra: 1 = su altura se movió al nivelar un cruce (el terreno de la ciudad recorta la malla bajo esos tramos: ver CityWorld._city_caps)

## ¿El tramo que sale de este punto de muestra cambió de altura al nivelar un cruce?
func level_sample(si: int) -> bool:
	return si < s_lv.size() and s_lv[si] != 0

## ¿La malla del terreno tiene que recortarse bajo el tramo que sale de este punto? (CityWorld._city_caps) Las rutas de campo, la costanera —una calle que sigue la costa y no se hunde
## en el terreno como las del centro— y los tramos que se nivelaron en un cruce (ahí la calzada ya no sigue la ladera y la malla de 16 m podía quedar por encima).
func cap_sample(si: int) -> bool:
	var rid: int = s_road[si]
	return (rid < _verge_road.size() and _verge_road[rid] != 0) or str((roads[rid] as Dictionary)["kind"]) == "coast" or level_sample(si)

const WELD_KINDS := ["major", "minor", "alley"]
const WELD_PARALLEL := 0.85 # coseno del ángulo (unos 32°) desde el cual dos calles que se tocan se consideran la misma calle que sigue
const WELD_MAX := 12.0 # un extremo suelto a más de esto (m, medido hasta el borde de la calzada de la otra calle) se deja como calle sin salida (con su pared)
const LEVEL_BLEND := 50.0 # m en los que las calles de un cruce vuelven a su altura de siempre (lo bastante largo para que la pendiente no suba de golpe)

## Dónde un rayo (desde p hacia dir, hasta max_len m) toca el eje de otra calle (no túnel ni bahía): [punto, metros hasta ahí, id de la calle, rumbo unitario de la calle ahí] o [] si no toca ninguna
func _ray_hit_axis(p: Vector2, dir: Vector2, own: int, max_len: float) -> Array:
	var best := 1.0e18
	var out: Array = []
	var far := p + dir * max_len
	for rj in roads.size():
		if rj == own:
			continue
		var o: Dictionary = roads[rj]
		var ok := str(o["kind"])
		if ok == "tunnel" or ok == "bay":
			continue
		var op: PackedVector3Array = o["pts"]
		for i in op.size() - 1:
			var a := Vector2(op[i].x, op[i].z)
			var b := Vector2(op[i + 1].x, op[i + 1].z)
			var hit: Variant = Geometry2D.segment_intersects_segment(p, far, a, b)
			if hit == null:
				continue
			var d := p.distance_to(hit as Vector2)
			if d < best:
				best = d
				out = [hit, d, rj, (b - a).normalized()]
	return out

## Prolonga hasta la calle de al lado los extremos de avenidas y calles que quedaban sueltos a pocos metros de su calzada. Sigue en el mismo sentido que ya llevaba la calle: el primer
## eje que cruza dentro de WELD_MAX m de borde a borde. Si no hay (la calle pasa de largo, o termina lejos), se deja como calle sin salida, con su pared.
func _weld_loose_ends() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		if not (str(rd["kind"]) in WELD_KINDS):
			continue
		for e in 2:
			for _it in 2: # (dos pasadas: una calle que cruza dos calles pegadas, como una calzada doble, pasa las dos)
				var pts: PackedVector3Array = rd["pts"]
				var cum: PackedFloat32Array = rd["cum"]
				var n := pts.size()
				if n < 3:
					break
				var pe := Vector2(pts[0].x, pts[0].z) if e == 0 else Vector2(pts[n - 1].x, pts[n - 1].z)
				var pn := Vector2(pts[1].x, pts[1].z) if e == 0 else Vector2(pts[n - 2].x, pts[n - 2].z)
				var out_dir := (pe - pn).normalized() # (hacia afuera de la calle: el sentido en que sigue)
				var hit := _ray_hit_axis(pe, out_dir, ri, WELD_MAX + 12.0)
				if hit.is_empty():
					break
				var other_hw := float((roads[int(hit[2])] as Dictionary)["hw"])
				var reach: float = float(hit[1])
				if reach > other_hw + WELD_MAX:
					break # queda lejos: es una calle sin salida (con su pared)
				if absf(out_dir.dot(hit[3] as Vector2)) > WELD_PARALLEL:
					break # la otra calle sigue casi en la misma dirección: es la continuación de esta (la calle 100 y la 101), no un cruce
				# (un extremo que termina ADENTRO de la calzada de la otra pero sin pasar su eje —la avenida 7 arrancaba 0,5 m antes del eje del anillo de la plaza— tampoco forma cruce: sin esquinas
				# redondeadas y con las rayas del eje pintadas encima de la otra calzada; se prolonga igual)
				# se llega al eje de la otra calle y se pasa un poco (adentro de su calzada): el cruce queda marcado
				var tip: Vector2 = (hit[0] as Vector2) + out_dir * minf(2.0, other_hw * 0.5)
				var added := pe.distance_to(tip)
				var np := Vector3(tip.x, height(tip.x, tip.y), tip.y)
				var pts2 := pts.duplicate()
				var cum2 := cum.duplicate()
				if added <= STEP:
					# la prolongación es corta: se corre el último punto (un tramo nuevo de 2 m dejaba la «media luna» del punto siguiente metida 8 m adentro de la plaza y abría su pared)
					if e == 0:
						pts2[0] = np
						for i in range(1, cum2.size()):
							cum2[i] = cum[i] + added
					else:
						pts2[n - 1] = np
						cum2[n - 1] = cum[n - 1] + added
				elif e == 0:
					pts2 = PackedVector3Array([np])
					pts2.append_array(pts)
					cum2 = PackedFloat32Array([0.0])
					for c in cum:
						cum2.append(c + added)
				else:
					pts2.append(np)
					cum2.append(cum[cum.size() - 1] + added)
				rd["pts"] = pts2
				rd["cum"] = cum2
				roads[ri] = rd

## Altura del eje de la calle ri en el punto del eje más cercano a p (interpolada entre los dos puntos del tramo)
func _axis_y_near(ri: int, p: Vector2) -> float:
	var pts: PackedVector3Array = roads[ri]["pts"]
	var best := 1.0e18
	var by := 0.0
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var ab := b - a
		var l2 := ab.length_squared()
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1.0e-9 else 0.0
		var d := p.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			by = lerpf(pts[i].y, pts[i + 1].y, t)
	return by

## Cruces a la misma altura: cada cruce es una explanada plana (la altura del eje de la calle principal en el cruce) de un radio que cubre las dos calzadas y sus banquinas, y las dos calles
## vuelven a su altura de siempre en LEVEL_BLEND m. Así donde las dos calzadas se pisan hay UNA sola altura (no la suma de dos planos distintos). Sólo donde hace falta: si las dos calles ya
## están a menos de 6 cm de esa altura en todo el cruce (el centro de la ciudad es una meseta) no se toca nada.
func _level_junctions() -> void:
	s_lv.resize(s_x.size())
	# 1) los cruces que hay que nivelar: [posición, altura, radio de la explanada, calles]
	var act: Array = []
	for j in junctions:
		var ra: int = int((j["roads"] as Array)[0])
		var rb: int = int((j["roads"] as Array)[1])
		if str((roads[ra] as Dictionary)["kind"]) == "tunnel" or str((roads[rb] as Dictionary)["kind"]) == "tunnel":
			continue
		var jp: Vector2 = j["pos"]
		var major := ra
		if float((roads[rb] as Dictionary)["hw"]) > float((roads[ra] as Dictionary)["hw"]) + 0.01:
			major = rb
		var minor := rb if major == ra else ra
		if str((roads[major] as Dictionary)["kind"]) == "bay":
			major = minor
		var yj := _axis_y_near(major, jp)
		# (la explanada cubre el cuadrado donde se pisan las dos calzadas más las esquinas redondeadas: medio ancho de la más ancha + 4 m. Más grande, en una ladera del 4 % la calle principal
		# tenía que subir o bajar un metro de golpe en el borde de la explanada y quedaban pendientes del 15 %)
		var pad := maxf(float((roads[ra] as Dictionary)["hw"]), float((roads[rb] as Dictionary)["hw"])) + 4.0
		var worst := 0.0
		for rid in [ra, rb]:
			var rp: PackedVector3Array = (roads[rid] as Dictionary)["pts"]
			for i in rp.size():
				if Vector2(rp[i].x, rp[i].z).distance_to(jp) < pad + STEP:
					worst = maxf(worst, absf(rp[i].y - yj))
		if worst >= 0.06: # (si ya están parejas no se toca: el centro de la ciudad es una meseta)
			act.append([jp, yj, pad, [ra, rb]])
	# 1b) los cruces que se pisan (dos calles que desembocan en la misma otra a pocos metros, una calle con su bahía…) forman UNA sola explanada: centro en el medio, altura promedio
	var merged := true
	while merged:
		merged = false
		for k in act.size():
			for m in range(k + 1, act.size()):
				var ak: Array = act[k]
				var am: Array = act[m]
				var d := (ak[0] as Vector2).distance_to(am[0] as Vector2)
				if d >= float(ak[2]) + float(am[2]):
					continue
				var c := ((ak[0] as Vector2) + (am[0] as Vector2)) * 0.5
				var rr: Array = (ak[3] as Array).duplicate()
				for r in (am[3] as Array):
					if not rr.has(r):
						rr.append(r)
				act[k] = [c, (float(ak[1]) + float(am[1])) * 0.5, maxf(float(ak[2]), float(am[2])) + d * 0.5, rr]
				act.remove_at(m)
				merged = true
				break
			if merged:
				break
	# 2) cada explanada se mezcla con sus calles hasta la mitad de lo que la separa de la más cercana (así dos explanadas nunca se pisan: cada una queda exactamente plana)
	for k in act.size():
		var jk: Array = act[k]
		var blend := LEVEL_BLEND
		for m in act.size():
			if m == k:
				continue
			var jm: Array = act[m]
			var free := (jk[0] as Vector2).distance_to(jm[0] as Vector2) - float(jk[2]) - float(jm[2])
			blend = minf(blend, maxf(free * 0.5, 4.0))
		for rid in (jk[3] as Array):
			var pts: PackedVector3Array = (roads[rid] as Dictionary)["pts"]
			var base := 0
			for si in s_x.size():
				if s_road[si] == rid:
					base = si
					break
			var moved := false
			for i in pts.size():
				var e := Vector2(pts[i].x, pts[i].z).distance_to(jk[0] as Vector2)
				if e >= float(jk[2]) + blend:
					continue
				var ny := lerpf(pts[i].y, float(jk[1]), 1.0 - smoothstep(float(jk[2]), float(jk[2]) + blend, e))
				if absf(ny - pts[i].y) > 0.002:
					pts[i] = Vector3(pts[i].x, ny, pts[i].z)
					s_y[base + i] = ny
					s_lv[base + i] = 1
					if i > 0:
						s_lv[base + i - 1] = 1 # (el tramo que llega a un punto movido también cambió)
					moved = true
			if moved:
				(roads[rid] as Dictionary)["pts"] = pts

# ───────────────────────── consultas (puras: se pueden llamar desde cualquier hilo) ─────────────────────────
## La calle de la superficie más cercana a p (sin las bocas de túnel ni los estacionamientos): [punto del eje, rumbo unitario de la calle, distancia] o [] si no hay ninguna a menos de max_d.
## Sirve para «volver a la calle» cuando el auto quedó trabado (se recorren todos los tramos: no se usa en cada cuadro).
func nearest_street(p: Vector2, max_d: float) -> Array:
	var best := max_d
	var out: Array = []
	for rd in roads:
		var kind := str(rd["kind"])
		if kind == "bay" or kind == "tunnel":
			continue
		var pts: PackedVector3Array = rd["pts"]
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			var ab := b - a
			var l2 := ab.length_squared()
			if l2 < 1e-6:
				continue
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var q := a + ab * t
			var d := q.distance_to(p)
			if d < best:
				best = d
				out = [q, ab / sqrt(l2), d]
	return out

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
			out[4] = float(oa["y"]) if oa.has("y") else height(x, z)
			out[5] = orr
			out[6] = -2.0 - float(oi)
	return out

## Holgura al borde (calzada + banquina) de la ruta de campo más cercana (rural, atajo, panorámica, colina); negativa = afuera; -1e9 si no hay ninguna a la vista. A diferencia de probe(),
## sirve para saber a cuántos metros de la banquina se está (probe sólo es confiable adentro del corredor).
func verge_clearance(x: float, z: float) -> float:
	var best := -1e9
	var kx := int(floor(x / HC))
	var kz := int(floor(z / HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not _hash.has(k2):
				continue
			for si in (_hash[k2] as PackedInt32Array):
				var rd: Dictionary = roads[s_road[si]]
				var kind := str(rd["kind"])
				if kind != "rural" and kind != "shortcut" and kind != "scenic" and kind != "hill":
					continue
				var ni := s_next[si]
				var ax := s_x[si]
				var az := s_z[si]
				var ex := 0.0
				var ez := 0.0
				if ni >= 0:
					ex = s_x[ni] - ax
					ez = s_z[ni] - az
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				best = maxf(best, float(rd["hw"]) + float(rd["sw"]) - sqrt(ddx * ddx + ddz * ddz))
	return best

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
	(_occ[ok_key] as Array).append([cen.x, cen.y, yaw, w, d, 3.0 if extra.has("show") else 0.0]) # (vidriera: 3 m libres alrededor, sin fachadas delante)
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
				var mg := margin + (float(c[5]) if c.size() > 5 else 0.0)
				if absf(dx * sin(yw) + dz * cos(yw)) < float(c[3]) * 0.5 + mg and absf(dx * cos(yw) - dz * sin(yw)) < float(c[4]) * 0.5 + mg:
					return true
	return false

## Zonas abiertas donde no se construye (plazas y parques)
var open_areas: Array = [] # {pos: Vector2, r: float, name: String}
func _no_build(p: Vector2) -> bool:
	for oa in open_areas:
		if p.distance_to(oa["pos"]) < float(oa.get("nb", oa["r"])):
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
func _blocked_line(x: float, z: float, own: int, roads_only := false, body_only := false) -> bool:
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
					var tt := ((x - ax) * ex + (z - az) * ez) / l2
					t = clampf(tt, 0.0, 1.0)
					# sólo el cuerpo de la calle, sin la media luna que la rodea más allá de su punta (una calle que empieza o termina adentro de la vereda de otra no cruza su línea de edificación)
					if body_only and ((tt < 0.0 and s_prev[si] < 0) or (tt > 1.0 and s_next[ni] < 0)):
						continue
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var rd: Dictionary = roads[rid]
				var need := float(rd["hw"]) + float(rd["sw"]) + LINE_GAP
				if ddx * ddx + ddz * ddz < need * need:
					return true
	if roads_only:
		return false
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
		if kind == "rural" or kind == "shortcut" or kind == "scenic" or kind == "bay" or kind == "tunnel":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var hw := float(rd["hw"])
		var sw := float(rd["sw"])
		var off := hw + sw + LINE_GAP
		var n := pts.size()
		_cap_dead_ends(ri)
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
					_close_gaps(ri, pts, away, off, []) # el lado de adentro (la plaza): cerrado, salvo la Plaza y el Parque del Drift
					continue
			var blocked: Array = []
			var line: Array = []
			var gaps_f: Array = [] # [punto, espacio libre] de los huecos angostos (donde otra calle pasa muy cerca por detrás)
			for i in n:
				var lp := Vector2(pts[i].x, pts[i].z) + away[i] * off
				line.append(lp)
				var bl := _blocked_line(lp.x, lp.y, ri)
				if not bl and kind != "plaza":
					# dos calles que van casi juntas, se separan un poquito y se vuelven a unir no dejan lugar para edificios: no se arma ahí una losa comprimida
					var gd := _gap_behind(lp, away[i], ri)
					if gd > 0.0:
						bl = true
						if i % 5 == 0:
							gaps_f.append([lp + away[i] * gd * 0.5, away[i]])
				blocked.append(bl)
			for g in gaps_f: # en su lugar, una farola con un cantero de flores: se ve como una isla vial pensada
				var gp: Vector2 = g[0]
				_add_prop(0, gp.x, gp.y, g[1])
				_add_prop(7, gp.x + (g[1] as Vector2).x * 2.0, gp.y + (g[1] as Vector2).y * 2.0, g[1])
			# tramos libres, en parámetro continuo (índice + fracción), con los extremos exactos sobre el borde de la calle que cruza
			var runs: Array = []
			var cur_a := -1.0
			if not blocked[0]:
				cur_a = 0.0
			for i in range(n - 1):
				var b0: bool = blocked[i]
				var b1: bool = blocked[i + 1]
				if b0 and not b1:
					cur_a = float(i) + _edge_t(pts, away, off, i, true, ri, kind != "plaza")
				elif (not b0) and b1:
					runs.append([cur_a, float(i) + _edge_t(pts, away, off, i, false, ri, kind != "plaza")])
					cur_a = -1.0
			if cur_a >= 0.0:
				runs.append([cur_a, float(n - 1)])
			var covered: Array = []
			for r in runs:
				covered.append_array(_slabs_in_run(kind, pts, away, off, float(r[0]), float(r[1]), sdv))
			_close_gaps(ri, pts, away, off, covered)

## ¿El punto cae adentro de la huella de un lugar especial (sin el margen de la vidriera)?
func _point_in_special(x: float, z: float, margin := 0.3) -> bool:
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

## ¿Hay que cerrar con una pared este punto de la línea de edificación? No si es una calle que cruza (se pasa por ahí), un lugar especial (concesionario, taller: pared y entrada propias),
## una estación de servicio o una zona abierta del Drift. Sí en cualquier otro hueco: entre edificios, esquinas sin losa, manzanas angostas y la Plaza Aurora.
func _gap_needs_wall(q: Vector2, ri: int) -> bool:
	if _blocked_line(q.x, q.y, ri, true, true):
		return false
	if _point_in_special(q.x, q.y, 0.3):
		return false # (sólo adentro de la huella: los costados de un concesionario o un taller sí se cierran)
	for oa in open_areas:
		if q.distance_to(oa["pos"]) < float(oa.get("nb", oa["r"])):
			return not (oa.get("station", false) == true or oa.get("dark", false) == true or str(oa["name"]).contains("Drift"))
	return true

## Los tramos [desde, hasta] (parámetro de la línea) de un hueco donde hace falta pared: se mira cada ~2 m y los bordes se afinan por bisección
func _gap_runs(ri: int, pts: PackedVector3Array, away: PackedVector2Array, off: float, ta: float, tb: float) -> Array:
	var out: Array = []
	var steps := maxi(1, int(ceil((tb - ta) / 0.25)))
	var prev_t := ta
	var prev_need := _gap_needs_wall((_line_pt(pts, away, off, ta)[0] as Vector2), ri)
	var start := ta if prev_need else -1.0
	for k in range(1, steps + 1):
		var t := minf(ta + (tb - ta) * float(k) / float(steps), tb)
		var need := _gap_needs_wall((_line_pt(pts, away, off, t)[0] as Vector2), ri)
		if need != prev_need:
			var lo := prev_t
			var hi := t
			for it in 6:
				var mid := (lo + hi) * 0.5
				if _gap_needs_wall((_line_pt(pts, away, off, mid)[0] as Vector2), ri) == prev_need:
					lo = mid
				else:
					hi = mid
			var edge := (lo + hi) * 0.5
			if prev_need:
				out.append([start, edge])
				start = -1.0
			else:
				start = edge
		prev_t = t
		prev_need = need
	if prev_need and start >= 0.0:
		out.append([start, tb])
	return out

## Una pared a lo ancho del final de una calle sin salida (los callejones que entran a una manzana): antes la pared del corredor la cerraba y ahora el auto seguía de largo hacia el interior
func _cap_dead_ends(ri: int) -> void:
	var rd: Dictionary = roads[ri]
	if not (str(rd["kind"]) in DENSE_KINDS) or str(rd["name"]).contains("Drift"):
		return
	var pts: PackedVector3Array = rd["pts"]
	var n := pts.size()
	if n < 3:
		return
	var off := float(rd["hw"]) + float(rd["sw"]) + LINE_GAP
	for e in 2:
		var pe := Vector2(pts[0].x, pts[0].z) if e == 0 else Vector2(pts[n - 1].x, pts[n - 1].z)
		var pi := Vector2(pts[1].x, pts[1].z) if e == 0 else Vector2(pts[n - 2].x, pts[n - 2].z)
		if pe.distance_to(Vector2(pts[0].x, pts[0].z) if e == 1 else Vector2(pts[n - 1].x, pts[n - 1].z)) < 6.0:
			continue # una calle que cierra sobre sí misma (anillo)
		var dir := (pe - pi).normalized()
		if _blocked_line(pe.x, pe.y, ri, true, true):
			continue # termina adentro del corredor de otra calle: es un cruce
		var nrm := Vector2(-dir.y, dir.x)
		var c0 := pe + dir * LINE_GAP
		var a := c0 - nrm * off
		var b := c0 + nrm * off
		_gap_quads.append_array(PackedFloat32Array([a.x, a.y, b.x, b.y, b.x + dir.x * GAP_WALL_T, b.y + dir.y * GAP_WALL_T, a.x + dir.x * GAP_WALL_T, a.y + dir.y * GAP_WALL_T]))
		gap_wall_len += 2.0 * off

## Los playones de las gasolineras (varios círculos que se pisan, pegados a la calle): se entra desde la calle y se sale por ahí; el resto del borde del playón da al interior de la manzana y se
## cierra con una pared que no se dibuja
func _close_station_lots() -> void:
	for st in stations:
		var circles: Array = st["circles"]
		var R := float(st["r"])
		for ci in circles.size():
			var cc: Vector2 = circles[ci]
			var steps := maxi(12, int(ceil(TAU * R / 2.0)))
			var prev := cc + Vector2(R, 0.0)
			var prev_ok := _lot_edge_needs_wall(prev, circles, R)
			for k in range(1, steps + 1):
				var ang := TAU * float(k) / float(steps)
				var cur := cc + Vector2(cos(ang), sin(ang)) * R
				var cur_ok := _lot_edge_needs_wall(cur, circles, R)
				if prev_ok and cur_ok:
					var nm := ((prev + cur) * 0.5 - cc).normalized()
					_gap_quads.append_array(PackedFloat32Array([prev.x, prev.y, cur.x, cur.y, cur.x + nm.x * GAP_WALL_T, cur.y + nm.y * GAP_WALL_T, prev.x + nm.x * GAP_WALL_T, prev.y + nm.y * GAP_WALL_T]))
					gap_wall_len += prev.distance_to(cur)
				prev = cur
				prev_ok = cur_ok

## ¿Este punto del borde de un playón necesita pared? No si queda adentro de otro círculo del mismo playón ni adentro del corredor de una calle (por ahí se entra)
func _lot_edge_needs_wall(q: Vector2, circles: Array, R: float) -> bool:
	for oc in circles:
		if q.distance_to(oc) < R - 0.4:
			return false
	var pr := probe(q.x, q.y)
	if float(pr[6]) >= 0.0 and float(pr[0]) > -0.5:
		return false
	return true

## Cierra los huecos de la línea de edificación de una calle de la ciudad (lo que las losas `covered` no cubren)
func _close_gaps(ri: int, pts: PackedVector3Array, away: PackedVector2Array, off: float, covered: Array) -> void:
	if not (str((roads[ri] as Dictionary)["kind"]) in DENSE_KINDS):
		return
	if str((roads[ri] as Dictionary)["name"]).contains("Drift"):
		return # el Parque del Drift se maneja por adentro
	covered.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cur := 0.0
	var gaps: Array = []
	for c in covered:
		if float(c[0]) > cur + 0.02:
			gaps.append([cur, float(c[0])])
		cur = maxf(cur, float(c[1]))
	if cur < float(pts.size() - 1) - 0.02:
		gaps.append([cur, float(pts.size() - 1)])
	for g in gaps:
		for r in _gap_runs(ri, pts, away, off, float(g[0]), float(g[1])):
			var u0: float = r[0]
			var u1: float = r[1]
			var steps := maxi(1, int(ceil((u1 - u0) / 0.5)))
			var prev: Array = _line_pt(pts, away, off, u0)
			for k in range(1, steps + 1):
				var cu: Array = _line_pt(pts, away, off, u0 + (u1 - u0) * float(k) / float(steps))
				var a: Vector2 = prev[0]
				var b: Vector2 = cu[0]
				if a.distance_squared_to(b) > 0.0004:
					var na: Vector2 = prev[2]
					var nb: Vector2 = cu[2]
					_gap_quads.append_array(PackedFloat32Array([a.x, a.y, b.x, b.y, b.x + nb.x * GAP_WALL_T, b.y + nb.y * GAP_WALL_T, a.x + na.x * GAP_WALL_T, a.y + na.y * GAP_WALL_T]))
					gap_wall_len += a.distance_to(b)
				prev = cu

## Fondo libre de una losa: hasta dónde se puede ir hacia atrás desde cada punto del frente sin pisar el corredor de ninguna calle
func _free_depth(pts: PackedVector3Array, away: PackedVector2Array, depth: float) -> float:
	var free := depth
	for i in pts.size():
		var d := 1.0
		while d <= free + 0.01:
			var q := Vector2(pts[i].x, pts[i].z) + away[i] * d
			if probe(q.x, q.y)[0] > 0.0:
				free = d - 1.0
				break
			d += 1.0
	# y entre punto y punto (las losas largas en curva)
	for i in pts.size() - 1:
		var mid := (Vector2(pts[i].x, pts[i].z) + Vector2(pts[i + 1].x, pts[i + 1].z)) * 0.5
		var am := (away[i] + away[i + 1]).normalized()
		var d2 := 1.0
		while d2 <= free + 0.01:
			var q2 := mid + am * d2
			if probe(q2.x, q2.y)[0] > 0.0:
				free = d2 - 1.0
				break
			d2 += 1.0
	return free

## Si detrás de la línea de edificación (a menos de ~18 m) pasa el corredor de otra calle: la distancia hasta ahí; 0 si hay lugar de sobra para un edificio
func _gap_behind(p: Vector2, dir: Vector2, own: int) -> float:
	for d in [9.0, 18.0]:
		var q: Vector2 = p + dir * float(d)
		if _blocked_line(q.x, q.y, own, true):
			return float(d)
	return 0.0

## Parámetro (0..1) dentro del tramo i→i+1 donde la línea de edificación entra (to_free = true: pasa de bloqueada a libre) o sale de una calle que cruza
func _edge_t(pts: PackedVector3Array, away: PackedVector2Array, off: float, i: int, to_free: bool, own: int, gap_on := true) -> float:
	var lo := 0.0
	var hi := 1.0
	for it in 10:
		var mid := (lo + hi) * 0.5
		var lp: Array = _line_pt(pts, away, off, float(i) + mid)
		var bl := _blocked_line((lp[0] as Vector2).x, (lp[0] as Vector2).y, own)
		if not bl and gap_on:
			bl = _gap_behind(lp[0], lp[2], own) > 0.0 # (igual que en _place_facades: los huecos angostos también cortan la línea)
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

func _slabs_in_run(kind: String, pts: PackedVector3Array, away: PackedVector2Array, off: float, ta: float, tb: float, sdv: float) -> Array:
	if tb - ta < 0.05:
		return []
	var cur := ta
	var run_slabs: Array = []
	var last_h := 0.0
	var covered: Array = []
	while cur < tb - 0.001:
		var seg_a := cur # (de dónde a dónde, en parámetro de la línea, cubre esta losa: _close_gaps cierra lo que no cubre ninguna)
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
			"roof": ROOFS[_rng.randi() % ROOFS.size()], "seed": _rng.randf(), "depth": float(st["depth"]), "house": house, "hp": 0.0, "hn": 0.0, "zone": zone, "ta": seg_a, "tb": t}
		if skip:
			run_slabs.append(null)
			continue
		run_slabs.append(slab)
	# ninguna losa se mete en una calle (pedido del dueño, 14/10/2026: había edificios encima de calles y de las entradas de las estaciones):
	# por detrás de la línea de edificación puede pasar otra calle (curvas, entradas): la losa se achica hasta ahí, y si queda muy flaca no se hace
	for i in run_slabs.size():
		var sl = run_slabs[i]
		if sl == null:
			continue
		var free := _free_depth(sl["pts"], sl["away"], float(sl["depth"]))
		if free < 4.0:
			run_slabs[i] = null
		elif free < float(sl["depth"]):
			sl["depth"] = free
	# alturas y fondos de los vecinos (para cerrar el costado de la losa que asoma: más alta, más honda o sin vecino)
	for i in run_slabs.size():
		var sl = run_slabs[i]
		if sl == null:
			continue
		if i > 0 and run_slabs[i - 1] != null:
			sl["hp"] = float(run_slabs[i - 1]["h"])
			sl["dp"] = float(run_slabs[i - 1]["depth"])
		if i + 1 < run_slabs.size() and run_slabs[i + 1] != null:
			sl["hn"] = float(run_slabs[i + 1]["h"])
			sl["dn"] = float(run_slabs[i + 1]["depth"])
		var p0: Vector3 = sl["pts"][0]
		var key := chunk_of(p0.x, p0.z)
		var arr: Array = slabs.get(key, [])
		arr.append(sl)
		slabs[key] = arr
		slab_count += 1
		covered.append([float(sl["ta"]), float(sl["tb"])])
	return covered

# ───────────────────────── gasolineras y peajes ─────────────────────────
## Las gasolineras ocupan el lugar de un edificio: un playón abierto (varios círculos que se pisan, así se maneja por adentro) pegado a la calle, con techo sobre las islas de surtidores,
## carriles con 3 a 6 puntos de carga (círculo verde), un kiosco al fondo y un poste de precios. Hay tres tamaños: la grande de carga rápida en la avenida principal, dos medianas en
## los barrios y una chica que sale de la ciudad, sobre el camino de la Ruta 20. Marco local de cada una: x = a lo largo de la calle, z = hacia el fondo del lote (el frente da a la calle).
const STATION_SPECS := [
	["gas_central", "Carga Rápida Central", "Avenida 3", 235.0, 1.0, Color(0.95, 0.72, 0.10), "big", true],
	["gas_norte", "Gasolinera Norte", "Avenida 7", 520.0, -1.0, Color(0.88, 0.20, 0.15), "mid", false],
	["gas_oeste", "Gasolinera Oeste", "Avenida 6", 560.0, 1.0, Color(0.20, 0.68, 0.36), "mid", false],
	["gas_ruta", "Gasolinera Ruta 20", "Avenida 1", 930.0, -1.0, Color(0.16, 0.52, 0.86), "small", false],
	["gas_sierra", "Gasolinera Pie de Sierra", "Ruta Panorámica 70", 900.0, -1.0, Color(0.92, 0.45, 0.12), "small", false],
	["gas_mirador", "Gasolinera Mirador", "Ruta Panorámica 70", 4400.0, -1.0, Color(0.55, 0.30, 0.78), "small", false],
]
# R: radio de cada círculo del playón · cu: posición (x) de cada círculo · pumps/pillars/blocks/bays: [x, z] locales · canopy: [ancho, fondo] · kiosk: [ancho, fondo, z]
const STATION_KINDS := {
	"big": {"R": 22.0, "cu": [-22.0, 0.0, 22.0], "canopy": [40.0, 26.0], "kiosk": [16.0, 4.5, 18.5],
		"pumps": [[-8.0, -4.5], [8.0, -4.5], [-8.0, 4.5], [8.0, 4.5]], "pillars": [[-16.0, -4.5], [16.0, -4.5], [-16.0, 4.5], [16.0, 4.5], [-28.0, -14.0]],
		"bays": [[-8.0, -8.0], [8.0, -8.0], [-8.0, 0.0], [8.0, 0.0], [-8.0, 8.0], [8.0, 8.0]], "blocks": [[-5.5, 18.5], [0.0, 18.5], [5.5, 18.5]], "isle": [24.0, 4.5]},
	"mid": {"R": 19.0, "cu": [-9.0, 9.0], "canopy": [26.0, 15.0], "kiosk": [14.0, 4.0, 13.0],
		"pumps": [[-5.0, 0.0], [5.0, 0.0]], "pillars": [[-10.5, 0.0], [10.5, 0.0], [-18.0, -11.0]],
		"bays": [[-6.0, -4.4], [6.0, -4.4], [-6.0, 4.4], [6.0, 4.4]], "blocks": [[-4.0, 13.0], [4.0, 13.0]], "isle": [18.0, 0.0]},
	"small": {"R": 16.0, "cu": [-6.0, 6.0], "canopy": [18.0, 12.0], "kiosk": [10.0, 3.6, 11.0],
		"pumps": [[-4.0, 0.0], [4.0, 0.0]], "pillars": [[-7.5, 0.0], [7.5, 0.0], [-14.0, -8.5]],
		"bays": [[-5.0, -4.4], [5.0, -4.4], [0.0, 4.4]], "blocks": [[-3.0, 11.0], [3.0, 11.0]], "isle": [12.0, 0.0]},
}

# adorno por tamaño: [x, z] locales de árboles, canteros de flores y arbustos (adentro del playón, lejos de los carriles)
const STATION_DECOR := {
	"big": {"trees": [[-27.0, 13.0], [27.0, 13.0], [-34.0, -4.0], [34.0, -4.0]], "flowers": [[-13.0, 18.0], [13.0, 18.0], [-30.0, -12.0], [30.0, -12.0]], "bushes": [[-19.0, 15.0], [19.0, 15.0], [-25.0, 6.0], [25.0, 6.0]]},
	"mid": {"trees": [[-17.0, 9.0], [17.0, 9.0]], "flowers": [[-10.0, 13.5], [10.0, 13.5], [-19.0, -4.0]], "bushes": [[-14.0, 12.0], [14.0, 12.0]]},
	"small": {"trees": [[-12.0, 8.0], [12.0, 8.0]], "flowers": [[-7.0, 11.5], [7.0, 11.5]], "bushes": [[-10.0, 10.0], [10.0, 10.0]]},
}

## ¿El playón de una gasolinera cabe ahí? No toca el asfalto de ninguna calle, ni un lugar especial, ni una zona abierta, ni otra gasolinera.
func _lot_ok(circles: Array, r: float) -> bool:
	for cc in circles:
		var q: Vector2 = cc
		var c := int(ceil((r + 9.0) / HC))
		var kx := int(floor(q.x / HC))
		var kz := int(floor(q.y / HC))
		for dx in range(-c, c + 1):
			for dz in range(-c, c + 1):
				var k := Vector2i(kx + dx, kz + dz)
				if not _hash.has(k):
					continue
				for si in (_hash[k] as PackedInt32Array):
					var hw := float(roads[s_road[si]]["hw"])
					if Vector2(s_x[si], s_z[si]).distance_to(q) < r + hw + 0.4:
						return false
		for p in pois:
			var half := Vector2(p["size"]).length() * 0.5
			if q.distance_to(p["pos"]) < r + half + 3.0:
				return false
		for oa in open_areas:
			if q.distance_to(oa["pos"]) < r + float(oa["r"]) + 2.0:
				return false
	return true

func _place_stations() -> void:
	stations.clear()
	for sp in STATION_SPECS:
		var ri := road_named(str(sp[2]))
		if ri < 0:
			continue
		var kd: Dictionary = STATION_KINDS[str(sp[6])]
		var R := float(kd["R"])
		var rd: Dictionary = roads[ri]
		var pts: PackedVector3Array = rd["pts"]
		var cum: PackedFloat32Array = rd["cum"]
		var ov := minf(3.0, float(rd["sw"]) - 0.1)
		var found := false
		var tn := Vector2.ZERO
		var nrm := Vector2.ZERO
		var lx := Vector2.ZERO
		var center := Vector2.ZERO
		var foot := Vector2.ZERO
		var circles: Array = []
		# se busca un lugar libre cerca del pedido: primero del lado elegido, después del otro, corriendo de a 12 m
		for step_i in 60:
			for sd in [1.0, -1.0]:
				var shift := float(((step_i + 1) / 2) * 12) * (1.0 if step_i % 2 == 0 else -1.0)
				var side: float = float(sp[4]) * sd
				var bi := 0
				for i in pts.size():
					if cum[i] <= float(sp[3]) + shift:
						bi = i
				var a := pts[bi]
				var b := pts[mini(bi + 1, pts.size() - 1)]
				var tn2 := Vector2(b.x - a.x, b.z - a.z)
				if tn2.length() < 0.1:
					continue
				tn2 = tn2.normalized()
				var nrm2 := Vector2(-tn2.y, tn2.x) * side
				var lx2 := Vector2(nrm2.y, -nrm2.x) # el eje x local (ver CityWorld._station)
				var c2 := Vector2(a.x, a.z) + nrm2 * (float(rd["hw"]) + float(rd["sw"]) + R - ov)
				var cl: Array = []
				for u in kd["cu"]:
					cl.append(c2 + lx2 * float(u))
				if _lot_ok(cl, R):
					found = true
					tn = tn2
					nrm = nrm2
					lx = lx2
					center = c2
					foot = Vector2(a.x, a.z)
					circles = cl
					break
			if found:
				break
		if not found:
			push_warning("gasolinera sin lugar: " + str(sp[0]))
			continue
		var wpos := func(u: float, v: float) -> Vector2: return center + lx * u + nrm * v
		var pumps: Array = []
		for pp in kd["pumps"]:
			pumps.append(wpos.call(float(pp[0]), float(pp[1])))
		var bays: Array = []
		for bp in kd["bays"]:
			bays.append(wpos.call(float(bp[0]), float(bp[1])))
		var pillars: Array = []
		for pl in kd["pillars"]:
			pillars.append(wpos.call(float(pl[0]), float(pl[1])))
		var blocks: Array = []
		for bl in kd["blocks"]:
			blocks.append(wpos.call(float(bl[0]), float(bl[1])))
		var yaw := atan2(tn.x, tn.y)
		var rural := str(rd["kind"]) == "rural" or float(rd["sw"]) < 3.0
		var st := {"id": str(sp[0]), "name": str(sp[1]), "center": center, "yaw": yaw, "dir": nrm, "tn": tn, "lx": lx, "color": sp[5], "kind": str(sp[6]), "fast": bool(sp[7]), "rural": rural,
			"fuel_points": bays, "pumps": pumps, "pillars": pillars, "blocks": blocks, "circles": circles, "r": R, "front": foot + nrm * (float(rd["hw"]) * 0.5)}
		stations.append(st)
		for cc in circles:
			open_areas.append({"pos": cc, "r": R, "name": str(sp[1]), "paving": true, "nb": R + 3.0, "station": true})
		pois.append({"id": str(sp[0]), "kind": "fuel", "name": str(sp[1]), "pos": center, "yaw": yaw, "size": Vector2(2, 2), "color": sp[5], "y": height(center.x, center.y), "road": ri,
			"front": st["front"], "shop": "", "door": center, "dir": nrm, "road_yaw": yaw})
		# la pared de atrás: un arco de losas alrededor de cada círculo, salvo donde pasa la calle o donde el playón sigue en el círculo vecino (en la ruta no hay pared: se ve el campo)
		if rural:
			continue
		var steps := 20
		for cc in circles:
			var q: Vector2 = cc
			var prev_sl = null # el tramo anterior del arco (para no cerrar costados entre tramos pegados)
			for k in steps:
				var a0 := TAU * float(k) / float(steps)
				var a1 := TAU * float(k + 1) / float(steps)
				var am := (a0 + a1) * 0.5
				var mp := q + Vector2(cos(am), sin(am)) * (R + 1.5)
				var pr := probe(mp.x, mp.y)
				if pr[6] >= 0.0 and pr[0] > -0.4:
					prev_sl = null
					continue # ahí pasa la calle (el frente del lote)
				var inside_other := false
				for c2 in circles:
					if (c2 as Vector2) != q and mp.distance_to(c2) < R + 0.6:
						inside_other = true
				if inside_other:
					prev_sl = null
					continue
				var p0 := q + Vector2(cos(a0), sin(a0)) * (R + 1.5)
				var p1 := q + Vector2(cos(a1), sin(a1)) * (R + 1.5)
				var sl := {"pts": PackedVector3Array([Vector3(p0.x, height(p0.x, p0.y), p0.y), Vector3(p1.x, height(p1.x, p1.y), p1.y)]),
					"away": PackedVector2Array([Vector2(cos(a0), sin(a0)), Vector2(cos(a1), sin(a1))]), "h": 9.6, "wall": WALLS[(k * 3 + int(sp[3])) % WALLS.size()], "roof": ROOFS[k % ROOFS.size()],
					"seed": _rng.randf(), "depth": 6.0, "house": false, "hp": 0.0, "hn": 0.0, "zone": 1}
				var fd := _free_depth(sl["pts"], sl["away"], 6.0) # (que no tape la entrada ni la calle de atrás)
				if fd < 2.0:
					prev_sl = null
					continue
				sl["depth"] = fd
				if prev_sl != null:
					prev_sl["hn"] = 9.6
					prev_sl["dn"] = fd
					sl["hp"] = 9.6
					sl["dp"] = float(prev_sl["depth"])
				prev_sl = sl
				var key := chunk_of(p0.x, p0.y)
				var arr: Array = slabs.get(key, [])
				arr.append(sl)
				slabs[key] = arr
				slab_count += 1

## Peajes: un retén sobre cada ruta rural, justo al salir de la ciudad (antes de la ruta de alta velocidad). Dos carriles con barrera, una isla con la cabina en el medio y un pórtico.
## Se frena en un carril, se paga y la barrera se abre; la barrera cerrada es sólida (CityToll).
const TOLL_S := 95.0 # metros desde el comienzo de la ruta
const TOLL_PRICE := 30
var tolls: Array = [] # {id, name, pos, tn, nrm, hw, road, price}

func _place_tolls() -> void:
	tolls.clear()
	for rn in [20, 40, 60, 80]:
		var ri := road_named("Ruta %d" % rn)
		if ri < 0:
			continue
		var rd: Dictionary = roads[ri]
		var pts: PackedVector3Array = rd["pts"]
		var cum: PackedFloat32Array = rd["cum"]
		var bi := 0
		for i in pts.size():
			if cum[i] <= TOLL_S:
				bi = i
		var a := pts[bi]
		var b := pts[mini(bi + 1, pts.size() - 1)]
		var tn := Vector2(b.x - a.x, b.z - a.z).normalized()
		var pos := Vector2(a.x, a.z)
		var t := {"id": "peaje_%d" % rn, "name": "Peaje Ruta %d" % rn, "pos": pos, "tn": tn, "nrm": Vector2(-tn.y, tn.x), "hw": float(rd["hw"]), "road": ri, "price": TOLL_PRICE}
		tolls.append(t)
		pois.append({"id": str(t["id"]), "kind": "toll", "name": str(t["name"]), "pos": pos, "yaw": atan2(tn.x, tn.y), "size": Vector2(2, 2), "color": Color(0.9, 0.3, 0.2), "y": height(pos.x, pos.y), "road": ri,
			"front": pos, "shop": "", "door": pos, "dir": Vector2(-tn.y, tn.x), "road_yaw": atan2(tn.x, tn.y)})

## Estacionamiento Central: está sobre una ruta, a la salida de la ciudad, y se entra manejando: de la ruta sale un camino corto que entra por una abertura de la pared de la planta baja
## (sin círculos verdes ni fundidos). Son tres salas redondas en fila, paralelas a la ruta: la planta baja a la altura de la calle, la planta alta 4,4 m arriba y el subsuelo 4,4 m abajo,
## unidas por dos rampas. El lugar se busca por las rutas, del lado y a la distancia donde entre todo sin pisar otra calle ni otro lugar.
func _place_garage() -> void:
	garage = {}
	var dx := GARAGE_RG + GARAGE_RU + GARAGE_RAMP
	for rname in ["Ruta 40", "Ruta 60", "Ruta 20", "Ruta 80"]:
		var ri := road_named(rname)
		if ri < 0:
			continue
		var rd: Dictionary = roads[ri]
		var pts: PackedVector3Array = rd["pts"]
		var cum: PackedFloat32Array = rd["cum"]
		for s_try in range(140, 300, 20): # cerca de la ciudad: ahí el terreno todavía es casi llano
			for sd in [1.0, -1.0]:
				var bi := 0
				for i in pts.size():
					if cum[i] <= float(s_try):
						bi = i
				var a := pts[bi]
				var b := pts[mini(bi + 1, pts.size() - 1)]
				var tn := Vector2(b.x - a.x, b.z - a.z)
				if tn.length() < 0.1:
					continue
				tn = tn.normalized()
				var nrm := Vector2(-tn.y, tn.x) * float(sd)
				var p0 := Vector2(a.x, a.z)
				var c0 := p0 + nrm * (float(rd["hw"]) + float(rd["sw"]) + GARAGE_RG + 2.5)
				var cu := c0 + tn * dx
				var cb := c0 - tn * dx
				var ok := _lot_ok([c0], GARAGE_RG) and _lot_ok([cu], GARAGE_RU) and _lot_ok([cb], GARAGE_RU)
				if ok:
					ok = _lot_ok([c0 + tn * (dx * 0.5)], 8.0) and _lot_ok([c0 - tn * (dx * 0.5)], 8.0)
				if not ok:
					continue
				_build_garage(ri, a.y, p0, tn, nrm, c0, cu, cb)
				return
	push_warning("estacionamiento sin lugar")
	# (no debería pasar) el jugador aparece sobre la Avenida 5 y la prueba lo avisa
	var r5 := road_named("Avenida 5")
	if r5 >= 0:
		var p5: Vector3 = (roads[r5]["pts"] as PackedVector3Array)[12]
		spawns.append([p5.x, p5.z, 0.0])
		spawn_names.append("Estacionamiento Central")

## Los lugares con techo (para la lluvia: Weather.set_covers): las tres salas del estacionamiento, las rampas y los túneles (círculos a lo largo del eje) y el techo
## de cada gasolinera. Cada uno: [x, z, y del techo, y del piso, ux, uz, medio ancho, medio fondo (< 0 = círculo)].
func rain_covers() -> Array:
	var out: Array = []
	for h in halls:
		var c: Vector2 = h["pos"]
		out.append([c.x, c.y, float(h["y"]) + float(h["h"]), float(h["y"]) - 1.0, 1.0, 0.0, float(h["r"]) + 0.5, -1.0])
	for rd in roads:
		if str(rd["kind"]) != "tunnel":
			continue
		# rectángulos de hasta 16 m a lo largo del eje (pocos: el shader mira sólo los 16 techos más cercanos)
		var pts: PackedVector3Array = rd["pts"]
		var hz := float(rd["hw"]) + 1.0
		var i0 := 0
		while i0 < pts.size() - 1:
			var i1 := i0 + 1
			while i1 < pts.size() - 1 and Vector2(pts[i1 + 1].x - pts[i0].x, pts[i1 + 1].z - pts[i0].z).length() <= 16.0:
				i1 += 1
			var p0 := Vector2(pts[i0].x, pts[i0].z)
			var p1 := Vector2(pts[i1].x, pts[i1].z)
			var ln := maxf(p0.distance_to(p1), 0.1)
			var u := (p1 - p0) / ln
			var c := (p0 + p1) * 0.5
			out.append([c.x, c.y, maxf(pts[i0].y, pts[i1].y) + 6.5, minf(pts[i0].y, pts[i1].y) - 1.5, u.x, u.y, ln * 0.5 + hz * 0.5, hz])
			i0 = i1
	for st in stations:
		var kd: Dictionary = STATION_KINDS[str(st["kind"])]
		var c: Vector2 = st["center"]
		var nr: Vector2 = (st["dir"] as Vector2).normalized()
		var y := height(c.x, c.y)
		out.append([c.x, c.y, y + 4.95, y - 1.0, nr.y, -nr.x, float(kd["canopy"][0]) * 0.5, float(kd["canopy"][1]) * 0.5])
	return out

func _garage_road(rname: String, hw: float, kind: String, plan: PackedVector3Array) -> void:
	var cum := PackedFloat32Array()
	var acc := 0.0
	for i in plan.size():
		if i > 0:
			acc += Vector2(plan[i].x - plan[i - 1].x, plan[i].z - plan[i - 1].z).length()
		cum.append(acc)
	var nj := PackedByteArray()
	nj.resize(plan.size())
	roads.append({"id": roads.size(), "name": rname, "num": 0, "kind": kind, "hw": hw, "sw": 0.0, "pts": plan, "cum": cum, "nj": nj})
	_index_road(roads.size() - 1)

## Aplana la ruta ri alrededor de c (a la altura y, de r0 a r1 metros se funde con la altura de siempre): el carril de entrada del estacionamiento es plano y, si la ruta tiene pendiente, la altura de una
## y de la otra se cruzaba con un escalón de 15 a 30 cm en medio de la calzada (la «rampa invisible» que hacía saltar al auto al salir del estacionamiento)
func _flatten_road(ri: int, c: Vector2, y: float, r0: float, r1: float) -> void:
	var pts: PackedVector3Array = (roads[ri] as Dictionary)["pts"]
	var base := s_road.find(ri)
	if base < 0:
		return
	for i in pts.size():
		var d := Vector2(pts[i].x - c.x, pts[i].z - c.y).length()
		if d >= r1:
			continue
		var w := 1.0 - smoothstep(r0, r1, d)
		var q := pts[i]
		q.y = lerpf(q.y, y, w)
		pts[i] = q
		s_y[base + i] = q.y
	(roads[ri] as Dictionary)["pts"] = pts

func _build_garage(ri: int, fy: float, p0: Vector2, tn: Vector2, nrm: Vector2, c0: Vector2, cu: Vector2, cb: Vector2) -> void:
	_flatten_road(ri, p0, fy, 22.0, 60.0)
	var cs: Array = [c0, cu, cb]
	var ys: Array = [fy, fy + GARAGE_DY, fy - GARAGE_DY]
	var rs: Array = [GARAGE_RG, GARAGE_RU, GARAGE_RU]
	var names: Array = ["Estacionamiento Central", "Estacionamiento Central · Planta alta", "Estacionamiento Central · Subsuelo"]
	var a_road := atan2(-nrm.y, -nrm.x) # ángulos en el plano (x, z): hacia la ruta, hacia la sala alta y hacia el subsuelo
	var a_up := atan2(tn.y, tn.x)
	var a_dn := atan2(-tn.y, -tn.x)
	var gaps_g: Array = [[a_road, asin(5.6 / GARAGE_RG)], [a_up, asin(RAMP_HW / GARAGE_RG)], [a_dn, asin(RAMP_HW / GARAGE_RG)]]
	var gaps_u: Array = [[a_dn, asin(RAMP_HW / GARAGE_RU)]]
	var gaps_b: Array = [[a_up, asin(RAMP_HW / GARAGE_RU)]]
	var gps: Array = [gaps_g, gaps_u, gaps_b]
	for i in 3:
		halls.append({"pos": cs[i], "r": float(rs[i]), "h": 6.2, "y": float(ys[i]), "gaps": gps[i]})
		open_areas.append({"pos": cs[i], "r": float(rs[i]) - 0.6, "name": str(names[i]), "paving": true, "dark": true, "y": float(ys[i]), "nb": float(rs[i]) + 4.0})
	# el camino de entrada: del eje de la ruta al centro de la planta baja
	var lane := PackedVector3Array()
	var dist := p0.distance_to(c0)
	var n := int(ceil(dist / 3.0))
	for k in n + 1:
		var q := p0 + nrm * (dist * float(k) / float(n))
		lane.append(Vector3(q.x, fy, q.y))
	_garage_road("Entrada Estacionamiento Central", 5.5, "bay", lane)
	# las rampas: de adentro de la planta baja a adentro de la sala de arriba / de abajo (curva suave, pendiente de alrededor del 12 %)
	for side_i in 2:
		var sg := 1.0 if side_i == 0 else -1.0
		var tgt: Vector2 = cu if side_i == 0 else cb
		var x0 := c0 + tn * (sg * (GARAGE_RG - 2.0))
		var x1 := tgt - tn * (sg * (GARAGE_RU - 2.0))
		var plan := PackedVector3Array()
		var nn := 14
		for k in nn + 1:
			var t := float(k) / float(nn)
			var q := x0.lerp(x1, t)
			var py := fy + sg * GARAGE_DY * clampf((t - 0.1) / 0.8, 0.0, 1.0)
			plan.append(Vector3(q.x, py, q.y))
		_garage_road("Rampa · Planta alta" if side_i == 0 else "Rampa · Subsuelo", RAMP_HW, "tunnel", plan)
	var hw_r := float((roads[ri] as Dictionary)["hw"])
	var front := p0 + nrm * (hw_r * 0.5)
	garage = {"road": ri, "p": p0, "nrm": nrm, "tn": tn, "c": cs, "y": ys, "r": rs}
	# dónde aparece el jugador: en el centro de cada sala, mirando hacia la salida (la planta baja mira a la ruta; las otras dos, a la rampa)
	spawns.append([c0.x, c0.y, atan2(-nrm.x, -nrm.y)])
	spawn_names.append(names[0])
	spawns.append([cu.x, cu.y, atan2(-tn.x, -tn.y)])
	spawn_names.append(names[1])
	spawns.append([cb.x, cb.y, atan2(tn.x, tn.y)])
	spawn_names.append(names[2])
	pois.append({"id": "estacionamiento", "kind": "parking", "name": "Estacionamiento Central", "pos": c0, "yaw": atan2(tn.x, tn.y), "size": Vector2(2, 2), "color": Color(0.28, 0.52, 0.88), "y": fy, "road": ri,
		"front": front, "shop": "", "door": c0, "dir": nrm, "road_yaw": atan2(tn.x, tn.y)})

# ───────────────────────── objetos de la calle ─────────────────────────
var _lot_props := false # se están poniendo los objetos de una gasolinera (los demás no pueden caer dentro de un playón ni de un peaje)

## ¿Cae dentro de un playón de gasolinera, de un peaje o del Estacionamiento Central? (ahí no van objetos sueltos ni árboles de adorno)
func lot_blocked(x: float, z: float) -> bool:
	for st in stations:
		for cc in st["circles"]:
			if Vector2(x, z).distance_to(cc) < float(st["r"]) + 1.0:
				return true
	for tl in tolls:
		if Vector2(x, z).distance_to(tl["pos"]) < 16.0:
			return true
	if not garage.is_empty():
		# el frente del Estacionamiento Central queda despejado hasta la ruta (y del otro lado, enfrente de la salida): sin alambrados, árboles ni flores
		# delante de la explanada (el dueño veía «una valla enfrente de la entrada», 14/10/2026)
		for gi in 3:
			if Vector2(x, z).distance_to(garage["c"][gi]) < float(garage["r"][gi]) + 30.0:
				return true
		if Vector2(x, z).distance_to(garage["p"]) < 32.0:
			return true
	return false

func _add_prop(t: int, x: float, z: float, to_road: Vector2, y_over := NAN) -> void:
	# nunca sobre el asfalto de ninguna calle
	var pr := probe(x, z)
	if pr[6] >= 0.0 and float(pr[1]) <= float(pr[5]) + 0.2:
		return
	if t == 13 or t == 18:
		# el alambrado es un tramo de 6 m: ni los alambres pueden cruzar una calle (cruzaba la entrada del Estacionamiento Central, reporte del dueño 14/10/2026)
		for f in [-3.4, -1.7, 1.7, 3.4]:
			var qx: float = x + to_road.x * float(f)
			var qz: float = z + to_road.y * float(f)
			var pq := probe(qx, qz)
			if pq[6] >= 0.0 and float(pq[1]) <= float(pq[5]):
				return
	if not _lot_props and lot_blocked(x, z):
		return
	var id := prop_type.size()
	prop_type.append(t)
	prop_x.append(x)
	prop_z.append(z)
	var py := height(x, z)
	if pr[0] >= 0.0:
		py = float(pr[4]) + (0.16 if pr[6] >= 0.0 else 0.0) # sobre la vereda (el cordón sube 16 cm); en una plaza abierta, a ras del suelo
	if not is_nan(y_over):
		py = y_over
	prop_y.append(py)
	prop_yaw.append(atan2(to_road.x, to_road.y) if (t == 13 or t >= 14 or not (t == 1 or t >= 7)) else _rng.randf() * TAU)
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
		if kind == "rural" or kind == "shortcut" or kind == "scenic" or kind == "bay" or kind == "tunnel":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var nj: PackedByteArray = rd["nj"]
		var hw := float(rd["hw"])
		var sw := float(rd["sw"])
		var lamp_gap: float = {"plaza": 22.0, "alley": 26.0, "minor": 46.0, "coast": 30.0, "hill": 60.0}.get(kind, 40.0)
		var tree_gap := 56.0 # pocos árboles de calle (y lindos): no una fila continua
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
			if acc_t >= tree_gap and not near_j and sw >= 2.0:
				# árboles solo donde hay naturaleza (la colina y la plaza); en las calles de la ciudad, nada: salvo alguna maceta con flores en el centro, que es la zona más cuidada
				if kind in ["hill", "plaza"]:
					acc_t = 0.0
					if _rng.randf() < 0.75:
						var st := flip_t
						flip_t = -flip_t
						_add_prop(1, p.x + nrm.x * st * off, p.y + nrm.y * st * off, -nrm * st)
				elif kind in ["major", "ring", "minor"] and zone_of(p.x, p.y) == 0:
					acc_t = -tree_gap # una maceta cada ~110 m
					var st2 := flip_t
					flip_t = -flip_t
					_add_prop(7, p.x + nrm.x * st2 * off, p.y + nrm.y * st2 * off, -nrm * st2)
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
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_add_prop(1, cos(a) * 30.0, sin(a) * 30.0, Vector2(0, 1))
	for i in 16: # canteros de flores alrededor del monumento y bajo los árboles
		var a := TAU * float(i) / 16.0
		_add_prop(7, cos(a) * 14.0, sin(a) * 14.0, Vector2(0, 1))
		if i % 2 == 0:
			_add_prop(8, cos(a + 0.2) * 22.0, sin(a + 0.2) * 22.0, Vector2(0, 1))
			_add_prop(9, cos(a + 0.1) * 36.0, sin(a + 0.1) * 36.0, Vector2(0, 1))
	# reja baja alrededor de la plaza (15/10/2026: la gente y los chicos están adentro, los autos afuera), con cuatro entradas frente a las avenidas de 45°, 135°, 225° y 315°
	var fr := 38.4
	var nseg := int(floor(TAU * fr / 6.0))
	for i in nseg:
		var a0 := TAU * (float(i) - 0.5) / float(nseg)
		var a1 := TAU * (float(i) + 0.5) / float(nseg)
		if absf(wrapf(a0 + (a1 - a0) * 0.5, 0.0, PI * 0.5) - PI * 0.25) < 0.05:
			continue # entrada
		var q0 := Vector2(cos(a0), sin(a0)) * fr
		var q1 := Vector2(cos(a1), sin(a1)) * fr
		_add_prop(18, q0.x, q0.y, (q1 - q0).normalized())
	# gasolineras: surtidores, columnas del techo, poste de precios y bloques que cierran el kiosco (nada de esto se rompe)
	_lot_props = true
	for st in stations:
		var nr: Vector2 = st["dir"]
		for pp in st["pumps"]:
			_add_prop(11, (pp as Vector2).x, (pp as Vector2).y, -nr)
		for cl in st["pillars"]:
			_add_prop(5, (cl as Vector2).x, (cl as Vector2).y, nr)
		for bl in st["blocks"]:
			_add_prop(12, (bl as Vector2).x, (bl as Vector2).y, nr)
		# adorno de papel: árboles atrás, canteros con flores y arbustos junto al kiosco y al frente (los árboles se rompen; lo demás es decoración)
		var sdec: Dictionary = STATION_DECOR[str(st["kind"])]
		var c1: Vector2 = st["center"]
		var lx1: Vector2 = st["lx"]
		for tp in sdec["trees"]:
			var q1: Vector2 = c1 + lx1 * float(tp[0]) + nr * float(tp[1])
			_add_prop(1, q1.x, q1.y, nr)
		for fp1 in sdec["flowers"]:
			var q2: Vector2 = c1 + lx1 * float(fp1[0]) + nr * float(fp1[1])
			_add_prop(7, q2.x, q2.y, nr)
		for bp in sdec["bushes"]:
			var q3: Vector2 = c1 + lx1 * float(bp[0]) + nr * float(bp[1])
			_add_prop(8, q3.x, q3.y, nr)
		if bool(st["rural"]):
			# el fondo del lote en la ruta: una tirada de árboles detrás del playón
			var c0: Vector2 = st["center"]
			for k in 14:
				var ang := TAU * float(k) / 14.0
				var qq := c0 + Vector2(cos(ang), sin(ang)) * (float(st["r"]) + 7.0)
				if (qq - c0).dot(nr) > 0.0:
					_add_prop(10, qq.x, qq.y, nr)
	_lot_props = false
	# Estacionamiento Central: pilares en cada sala (lejos de las rampas, de la entrada y del lugar donde aparece el auto)
	if not garage.is_empty():
		_lot_props = true
		for li in 3:
			var gc: Vector2 = garage["c"][li]
			var gr: float = garage["r"][li]
			var np := 8 if li == 0 else 6
			for i in np:
				var a := (22.5 + 45.0 * float(i)) * PI / 180.0 if li == 0 else (15.0 + 60.0 * float(i)) * PI / 180.0
				var q := gc + Vector2(cos(a), sin(a)) * (gr * 0.68)
				if absf(wrapf(a - atan2(-(garage["nrm"] as Vector2).y, -(garage["nrm"] as Vector2).x), -PI, PI)) < 0.5 or absf(wrapf(a - atan2((garage["tn"] as Vector2).y, (garage["tn"] as Vector2).x), -PI, PI)) < 0.5 or absf(wrapf(a - atan2(-(garage["tn"] as Vector2).y, -(garage["tn"] as Vector2).x), -PI, PI)) < 0.5:
					continue
				_add_prop(5, q.x, q.y, Vector2(0, 1))
		_lot_props = false
	# el estacionamiento queda vacío: los únicos autos son los de los jugadores
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
				var before := prop_type.size()
				_add_prop(2, jp.x + (ta.x * along + na.x * offs) * sg, jp.y + (ta.y * along + na.y * offs) * sg, -na * sg)
				if prop_type.size() > before:
					prop_signal[before] = [int(rids[k]), jp] # este semáforo regula a la calle ra (ver world/traffic_signals.gd)
			# las calles chicas que desembocan en una calle grande tienen su cartel de PARE (mirando al tránsito que llega)
			if str(ra["kind"]) in ["minor", "alley"] and str(rb["kind"]) in ["major", "ring", "coast"]:
				var along_s := along + 5.0
				for sg2 in [1.0, -1.0]:
					_add_prop(14, jp.x + (ta.x * along_s + na.x * offs) * sg2, jp.y + (ta.y * along_s + na.y * offs) * sg2, ta * sg2)

## Guardarrailes donde el camino corre al borde de un barranco (el terreno cae más de CLIFF_DROP m a pocos metros del asfalto): caminos de la colina, atajos, rutas y la costanera.
## Cada tramo de 4 m es un objeto sólido (dos postes y la baranda), a ras de la calle y justo al borde de la banquina.
const CLIFF_DROP := 1.3
const GUARD_STEP := 4.0
func _place_guardrails() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		var kind := str(rd["kind"])
		if not (kind in ["hill", "shortcut", "rural", "coast", "scenic"]):
			continue
		var pts: PackedVector3Array = rd["pts"]
		var nj: PackedByteArray = rd["nj"]
		var base := float(rd["hw"]) + float(rd["sw"]) + 0.4
		var acc := GUARD_STEP
		for i in range(1, pts.size() - 1):
			var tn := Vector2(pts[i + 1].x - pts[i - 1].x, pts[i + 1].z - pts[i - 1].z)
			if tn.length() < 0.1:
				continue
			tn = tn.normalized()
			var nrm := Vector2(-tn.y, tn.x)
			var p := Vector2(pts[i].x, pts[i].z)
			var step := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
			acc += step
			if acc < GUARD_STEP or (nj.size() > i and nj[i] != 0):
				continue
			var placed := false
			for sg in [-1.0, 1.0]:
				var q := p + nrm * float(sg) * base
				var far := p + nrm * float(sg) * (base + 6.0)
				var drop := float(pts[i].y) - height(far.x, far.y)
				if drop > CLIFF_DROP:
					_add_prop(17, q.x, q.y, tn, float(pts[i].y))
					placed = true
			if placed:
				acc = 0.0
		# (la Ruta Panorámica ya no termina en bloques de hormigón: sigue por la región hasta la circunvalación)

## Bordes de las rutas rurales y de los atajos: una tirada de árboles del pack (varias especies, dos filas), con pasto, flores y algún arbusto abajo. No chocan: el auto no sale del camino.
func _place_roadside() -> void:
	for ri in roads.size():
		var rd: Dictionary = roads[ri]
		var kind := str(rd["kind"])
		if kind != "rural" and kind != "shortcut" and kind != "scenic":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var base := float(rd["hw"]) + float(rd["sw"])
		var acc_t := _rng.randf() * 28.0
		var acc_u := _rng.randf() * 60.0
		var acc_g := _rng.randf() * 11.0
		var acc_b := _rng.randf() * 40.0
		var acc_f := 0.0
		var acc_s := _rng.randf() * 80.0
		for i in range(1, pts.size() - 1):
			var tn := Vector2(pts[i + 1].x - pts[i - 1].x, pts[i + 1].z - pts[i - 1].z)
			if tn.length() < 0.1:
				continue
			tn = tn.normalized()
			var nrm := Vector2(-tn.y, tn.x)
			var p := Vector2(pts[i].x, pts[i].z)
			var step := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
			acc_t += step
			acc_u += step
			acc_g += step
			acc_b += step
			acc_f += step
			acc_s += step
			if acc_s >= 110.0 and i >= 3 and i < pts.size() - 3:
				# cartel de curva donde el camino dobla, y de vez en cuando uno de velocidad máxima (un par: uno para cada sentido)
				var t_a := Vector2(pts[i].x - pts[i - 3].x, pts[i].z - pts[i - 3].z)
				var t_b := Vector2(pts[i + 3].x - pts[i].x, pts[i + 3].z - pts[i].z)
				var bend := absf(wrapf(atan2(t_b.x, t_b.y) - atan2(t_a.x, t_a.y), -PI, PI))
				if bend > 0.16 or acc_s >= 330.0:
					acc_s = 0.0
					var kind_s := 15 if bend > 0.16 else 16
					for sd3 in [-1.0, 1.0]:
						var os := base + 2.2
						_add_prop(kind_s, p.x + nrm.x * float(sd3) * os, p.y + nrm.y * float(sd3) * os, tn * float(sd3))
			for sd in [-1.0, 1.0]:
				var sg: float = sd
				if acc_f >= 6.0:
					var fo := base + 0.5 # el alambrado corre justo al borde de la banquina
					_add_prop(13, p.x + nrm.x * sg * fo, p.y + nrm.y * sg * fo, tn)
				if acc_t >= 28.0:
					var o := base + 3.5 + _rng.randf() * 2.0
					_add_prop(10, p.x + nrm.x * sg * o, p.y + nrm.y * sg * o, nrm)
				if acc_u >= 60.0:
					var o2 := base + 9.5 + _rng.randf() * 3.0
					_add_prop(10, p.x + nrm.x * sg * o2, p.y + nrm.y * sg * o2, nrm)
				if acc_g >= 11.0:
					var o3 := base + 1.0 + _rng.randf() * 2.2
					_add_prop(9 if _rng.randf() < 0.5 else 7, p.x + nrm.x * sg * o3, p.y + nrm.y * sg * o3, nrm)
				if acc_b >= 40.0:
					var o4 := base + 2.0 + _rng.randf() * 1.5
					_add_prop(8, p.x + nrm.x * sg * o4, p.y + nrm.y * sg * o4, nrm)
			if acc_f >= 6.0:
				acc_f = 0.0
			if acc_t >= 28.0:
				acc_t = 0.0
			if acc_u >= 60.0:
				acc_u = 0.0
			if acc_g >= 11.0:
				acc_g = 0.0
			if acc_b >= 40.0:
				acc_b = 0.0

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

## Concesionarios de especialidad (rally y 4x4, clásicos, motorsport): mismo formato que POI_SPECS. Se arman DESPUÉS de las estaciones y del
## estacionamiento para no correr los números de las calles que ya existían; tienen vidriera con autos de verdad (city_world: _showroom).
const DEALER_SPECS := [
	["conc_rally", "dealer", "Rally & 4x4 del Puerto", "Avenida 5", 420.0, 1.0, 34.0, 22.0, 9.6, Color(0.85, 0.42, 0.12), "dealer_rally"],
	["conc_clasicos", "dealer", "Clásicos de Colección", "Avenida 3", 430.0, -1.0, 34.0, 22.0, 9.6, Color(0.62, 0.12, 0.14), "dealer_classic"],
	["conc_motorsport", "dealer", "Dream Motorsport", "Avenida 1", 430.0, 1.0, 34.0, 22.0, 9.6, Color(0.16, 0.17, 0.20), "dealer_sport"],
]

func _place_pois() -> void:
	pois.clear()
	for sp in POI_SPECS:
		_place_poi(sp)

func _place_dealers() -> void:
	for sp in DEALER_SPECS:
		_place_poi(sp)

func _place_poi(sp: Array) -> void:
	var ri := road_named(str(sp[3]))
	if ri < 0:
		return
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
		var ex := {"poi": str(sp[0]), "side": -side}
		if str(sp[1]) == "dealer":
			ex["show"] = str(sp[10]) # vidriera: la planta baja del frente es de vidrio (city_world: _showroom)
			ex["fn"] = -nrm # normal del frente (hacia la calle)
		_add_building(cen, float(sp[6]), float(sp[7]), float(sp[8]), yaw, sp[9], sp[9].darkened(0.3), zone_of(cen.x, cen.y), false, ri, ex)
