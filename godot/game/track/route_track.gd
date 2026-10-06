extends "res://game/physics/track_base.gd"
## Pistas por curva de la versión HTML (clase Track de js/main.js): una ruta cerrada que pasa por unos puntos de control
## (Catmull-Rom, 1100 muestras a igual distancia), con altura, badenes, corona del camino, banquina, zanja y pasto.
## La física pide altura y superficie con ground_info(); cada auto usa su propia "vista" (make_view) porque la búsqueda del
## tramo más cercano guarda el último resultado y los autos corren en hilos distintos.
## godot/tests/track_test.gd compara con el código real de la versión HTML (tools/godot/track_reference.mjs).

const N_SAMPLES := 1100
const STRIP_EXT := 90.0 # Travesía X: hasta qué distancia del camino llega la franja con la altura exacta (banquina + build_far_strip)
const BUMP_AMP := [0.005, 0.03, 0.035, 0.045, 0.05, 0.03] # por superficie: asfalto, tierra, banquina, pasto, afuera, barro

var hills := 0.0 # subidas y bajadas suaves del recorrido (0 = las de la versión HTML; 1 = las de las carreras de Dream Racing)
var center_line := false # línea amarilla del medio (solo para el modo aventura)
var n_samples := N_SAMPLES # muestras del camino (las rutas muy largas piden más)
var flat := false # sin ondulación del asfalto (la picada)
var open := false # ruta abierta (modo aventura): la última muestra no se une con la primera
var road_surf := PackedByteArray() # superficie del camino por muestra (0 asfalto · 1 tierra); vacío = la del modo de la pista
var surf_mu := PackedFloat32Array() # agarre relativo de cada muestra para la IA (vacío = igual en toda la pista)
var wall_l := PackedFloat32Array() # límite lateral por muestra (modo aventura; vacío = el del auto)
var wall_r := PackedFloat32Array()
var route_id := ""
var mode := "asphalt" # "asphalt" | "dirt"
var half_width := 5.0
var shoulder := 2.0
var dips: Array = []
var water: Array = [] # lagos/vados: [{"i0","i1","y","half"}] índices de muestra, altura del agua y semiancho (la ruta Travesía X)
var sections: Array = [] # tramos con nombre [{"i0","i1","name","label","cap"}] (para el cartel y el ritmo del convoy de la Travesía)
var ledges: Array = [] # escalones de roca: [{"from","to","rise","step","len"}] fracciones del recorrido (la Travesía X)
var caves: Array = [] # cuevas (túnel de roca sobre el camino, sólo visual): [{"i0","i1"}]
var ctrl: PackedVector3Array = PackedVector3Array()
var samples: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var laterals: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat64Array = PackedFloat64Array()
var cy: PackedFloat64Array = PackedFloat64Array() # altura del centro del camino en cada muestra (con la corona)
var length := 0.0
var n := 0
var min_xz := Vector2.ZERO
var max_xz := Vector2.ZERO

# resultado de la última búsqueda (por vista)
var hint := -1
var trust := false
var r_dist := 0.0
var r_idx := 0
var r_t := 0.0
var r_y := 0.0
var r_lat := 0.0
var _bd := 0.0
var _bi := 0
var _bt := 0.0

static var _routes: Dictionary
var views: Array = [] # vistas creadas (para propagar el agarre)
var prof_cache := {} # perfiles de velocidad de la IA (se comparten con las vistas)

## route: nombre en routes.json; reverse: sentido inverso. p_mode: "asphalt" o "dirt"
func _init(p_route := "", p_mode := "asphalt", reverse := false, p_hills := 0.0) -> void:
	if p_route == "":
		return
	hills = p_hills
	if _routes.is_empty():
		_routes = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["routes"]
	var r: Dictionary = _routes[p_route]
	route_id = p_route
	mode = p_mode
	half_width = float(r["halfWidth"])
	shoulder = float(r["shoulder"])
	dips = r.get("dips", [])
	ledges = r.get("ledges", [])
	flat = r.get("flat", false) == true
	n_samples = int(r.get("samples", N_SAMPLES))
	var pts: Array = r["points"]
	if reverse:
		var tail: Array = pts.slice(1)
		tail.reverse()
		pts = [pts[0]] + tail
	for p in pts:
		ctrl.append(Vector3(p[0], p[1], p[2]))
	_build()
	if r.has("surf") or r.has("water") or r.has("sections") or r.has("caves"):
		_apply_zones(r, reverse)

func center_xz() -> Vector2:
	return (min_xz + max_xz) * 0.5

## Otra vista de la misma pista (comparte los datos, tiene su propia búsqueda)
## register = false para vistas temporales de otros hilos (el terreno): no se anotan en la lista compartida (agregarla desde varios hilos
## a la vez corrompía la memoria y cerraba el juego) ni reciben los cambios de agarre.
func make_view(register := true) -> Object:
	var v = (get_script() as GDScript).new()
	v.route_id = route_id
	v.mode = mode
	v.half_width = half_width
	v.shoulder = shoulder
	v.dips = dips
	v.ctrl = ctrl
	v.samples = samples
	v.tangents = tangents
	v.laterals = laterals
	v.cum = cum
	v.cy = cy
	v.length = length
	v.n = n
	v.min_xz = min_xz
	v.max_xz = max_xz
	v.grip_mul = grip_mul
	v.prof_cache = prof_cache
	v.open = open
	v.surf_mu = surf_mu
	v.road_surf = road_surf
	v.water = water
	v.sections = sections
	v.wall_l = wall_l
	v.wall_r = wall_r
	_copy_view(v)
	if register:
		views.append(v)
	return v

## Las pistas derivadas copian acá sus datos extra a la vista nueva
func _copy_view(_v: Object) -> void:
	pass

## Agarre global de la pista (lluvia): se copia a todas las vistas
func set_grip(g: float) -> void:
	grip_mul = g
	for v in views:
		if is_instance_valid(v): # al cerrar el juego algunas vistas ya fueron liberadas
			v.grip_mul = g

# ───────────────────────── construcción de la ruta ─────────────────────────
static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, w: float) -> Vector3:
	# Catmull-Rom uniforme con tensión 0,5 (igual que CatmullRomCurve3 de three.js)
	var t1 := (p2 - p0) * 0.5
	var t2 := (p3 - p1) * 0.5
	var c2 := p1 * -3.0 + p2 * 3.0 - t1 * 2.0 - t2
	var c3 := p1 * 2.0 - p2 * 2.0 + t1 + t2
	return p1 + t1 * w + c2 * w * w + c3 * w * w * w

func _curve_point(t: float) -> Vector3:
	var l := ctrl.size()
	var p := float(l) * t
	var ip := int(floor(p))
	var w := p - float(ip)
	return _cr(ctrl[posmod(ip - 1, l)], ctrl[posmod(ip, l)], ctrl[posmod(ip + 1, l)], ctrl[posmod(ip + 2, l)], w)

func _build() -> void:
	# tabla de longitudes para repartir las muestras a igual distancia (como getSpacedPoints)
	var div := maxi(3000, ctrl.size() * 4) # las rutas largas (Travesía X) piden una tabla más fina
	var lens := PackedFloat64Array()
	lens.resize(div + 1)
	var prev := _curve_point(0.0)
	for i in range(1, div + 1):
		var c := _curve_point(float(i) / float(div))
		lens[i] = lens[i - 1] + prev.distance_to(c)
		prev = c
	var total := lens[div]
	samples.resize(n_samples)
	for i in n_samples:
		var target := total * float(i) / float(n_samples)
		var lo := 0
		var hi := div
		while lo < hi:
			var mid := (lo + hi) / 2
			if lens[mid] < target:
				lo = mid + 1
			else:
				hi = mid
		var b := lo if lens[lo] == target else lo - 1
		b = clampi(b, 0, div - 1)
		var seg := lens[b + 1] - lens[b]
		var u := (target - lens[b]) / seg if seg > 0.0 else 0.0
		samples[i] = _curve_point((float(b) + u) / float(div))
	n = n_samples
	# altura: interpolación de los puntos de control + ondulación, suavizada con media móvil circular
	var y := PackedFloat64Array()
	y.resize(n)
	var lc := ctrl.size()
	for i in n:
		var t := float(i) / float(n)
		var ii := int(floor(t * lc)) % lc
		var u2 := fposmod(t * lc, 1.0)
		var a := ctrl[ii].y
		var b2 := ctrl[(ii + 1) % lc].y
		y[i] = a + (b2 - a) * u2 + (0.0 if flat else 0.20 * sin(t * PI * 6.0) + 0.10 * sin(t * PI * 15.0))
		if hills > 0.0:
			# frecuencias enteras: el recorrido cerrado empalma sin escalón
			y[i] += hills * (7.0 * sin(t * TAU * 2.0 + 0.7) + 3.5 * sin(t * TAU * 5.0 + 2.0) + 1.2 * sin(t * TAU * 11.0 + 0.3))
	for W in [6, 6, 4]:
		var o := PackedFloat64Array()
		o.resize(n)
		for i in n:
			var s := 0.0
			for j in range(-W, W + 1):
				s += y[posmod(i + j, n)]
			o[i] = s / float(2 * W + 1)
		y = o
	for i in n:
		samples[i].y = y[i]
	if not dips.is_empty():
		_apply_dips()
	if not ledges.is_empty():
		_apply_ledges()
	tangents.resize(n)
	laterals.resize(n)
	for i in n:
		var tg := (samples[(i + 1) % n] - samples[(i + n - 1) % n]).normalized()
		tangents[i] = tg
		laterals[i] = tg.cross(Vector3.UP).normalized()
	cum.resize(n + 1)
	for i in range(1, n + 1):
		cum[i] = cum[i - 1] + samples[i - 1].distance_to(samples[i % n])
	length = cum[n]
	cy.resize(n)
	for i in n:
		cy[i] = samples[i].y + _road_offset(i)
	min_xz = Vector2(1e9, 1e9)
	max_xz = Vector2(-1e9, -1e9)
	for p in ctrl:
		min_xz = Vector2(minf(min_xz.x, p.x), minf(min_xz.y, p.z))
		max_xz = Vector2(maxf(max_xz.x, p.x), maxf(max_xz.y, p.z))
	min_xz -= Vector2(180, 180)
	max_xz += Vector2(180, 180)

## Zonas de la ruta (fracciones del recorrido en routes.json): superficie por tramo (tierra/barro), agarre para la IA, lagos y tramos con nombre.
## En el sentido inverso las fracciones se espejan.
func _apply_zones(r: Dictionary, reverse: bool) -> void:
	var fr := func(u: float) -> int:
		return clampi(int(floor((1.0 - u if reverse else u) * float(n))), 0, n - 1)
	var base_code := 0 if mode == "asphalt" else 1
	var surf_list: Array = r.get("surf", [])
	if not surf_list.is_empty():
		road_surf.resize(n)
		road_surf.fill(base_code)
		surf_mu.resize(n)
		surf_mu.fill(1.0 if base_code == 0 else 0.6)
		for z in surf_list:
			var a: int = fr.call(float(z["from"]))
			var b: int = fr.call(float(z["to"]))
			var i0 := mini(a, b)
			var i1 := maxi(a, b)
			for i in range(i0, i1 + 1):
				road_surf[i] = int(z["s"])
				surf_mu[i] = (1.0 if base_code == 0 else 0.6) * float(z.get("mu", 1.0))
		# transición suave del agarre de la IA (frena antes de entrar y no acelera de golpe al salir)
		var sm := surf_mu.duplicate()
		for i in n:
			var acc := 0.0
			for j in range(-6, 7):
				acc += sm[posmod(i + j, n)]
			surf_mu[i] = acc / 13.0
	for wz in r.get("water", []):
		var a2: int = fr.call(float(wz["from"]))
		var b2: int = fr.call(float(wz["to"]))
		var j0 := mini(a2, b2)
		var j1 := maxi(a2, b2)
		var low := 1e9
		for i in range(j0, j1 + 1):
			low = minf(low, cy[i])
		water.append({"i0": j0, "i1": j1, "y": low + float(wz.get("above", 0.5)), "half": float(wz.get("half", 40.0))})
	for sc in r.get("sections", []):
		var a3: int = fr.call(float(sc["from"]))
		var b3: int = fr.call(float(sc["to"]))
		sections.append({"i0": mini(a3, b3), "i1": maxi(a3, b3), "name": str(sc["name"]), "label": str(sc.get("label", "")), "cap": float(sc.get("cap", 12.0))})
	for cv in r.get("caves", []):
		var a4: int = fr.call(float(cv["from"]))
		var b4: int = fr.call(float(cv["to"]))
		caves.append({"i0": mini(a4, b4), "i1": maxi(a4, b4)})

func _apply_dips() -> void:
	var c := PackedFloat64Array()
	c.resize(n)
	for i in range(1, n):
		c[i] = c[i - 1] + samples[i].distance_to(samples[i - 1])
	for d in dips:
		var i0 := int(floor(float(d["from"]) * n))
		var i1 := int(floor(float(d["to"]) * n))
		var s0 := c[i0]
		var s1 := c[i1]
		for i in range(i0, i1 + 1):
			var u := (c[i] - s0) / maxf(1.0, s1 - s0)
			var win := minf(1.0, minf(u * 6.0, (1.0 - u) * 6.0))
			samples[i].y += -float(d["amp"]) * win * 0.5 * (1.0 - cos(2.0 * PI * (c[i] - s0) / float(d["wave"])))

## Escalones de roca (Travesía X): el camino sube en peldaños de `rise` m cada `step` m (con una rampa de `len` m) hasta la mitad de la zona y baja igual: hay que subirlos con suspensión y acelerador
func _apply_ledges() -> void:
	var c := PackedFloat64Array()
	c.resize(n)
	for i in range(1, n):
		c[i] = c[i - 1] + samples[i].distance_to(samples[i - 1])
	for lg in ledges:
		var i0 := int(floor(float(lg["from"]) * n))
		var i1 := int(floor(float(lg["to"]) * n))
		var s0 := c[i0]
		var step := float(lg["step"])
		var ramp := float(lg["len"])
		var rise := float(lg["rise"])
		var nst := maxi(2, int((c[i1] - s0) / step))
		for i in range(i0, i1 + 1):
			var s := c[i] - s0
			var k := mini(int(floor(s / step)), nst - 1)
			var local := s - float(k) * step
			var f := clampf((local - (step - ramp)) / ramp, 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			var lv0 := float(mini(k, nst - k))
			var lv1 := float(mini(k + 1, nst - k - 1))
			samples[i].y += rise * (lv0 + (lv1 - lv0) * f)

func _road_offset(i: int) -> float:
	if flat:
		return 0.0
	var t := float(i) / float(n)
	if route_id == "travesia":
		return 0.06 + 0.10 * sin(t * PI * 5.0) + 0.04 * sin(t * PI * 13.0) # sin los bultos de las otras rutas: ahí caerían en otro tramo
	return 0.06 + 0.10 * sin(t * PI * 5.0) + 0.04 * sin(t * PI * 13.0) - 0.25 * exp(-pow((t - 0.43) / 0.045, 2.0)) + 0.18 * exp(-pow((t - 0.73) / 0.06, 2.0))

# ───────────────────────── búsqueda del tramo más cercano ─────────────────────────
func _seg_d(x: float, z: float, i: int) -> float:
	var a := samples[i]
	var b := samples[(i + 1) % n]
	var abx := b.x - a.x
	var abz := b.z - a.z
	var den := abx * abx + abz * abz
	var t := clampf(((x - a.x) * abx + (z - a.z) * abz) / den, 0.0, 1.0) if den > 0.0 else 0.0
	var dx := x - (a.x + abx * t)
	var dz := z - (a.z + abz * t)
	return dx * dx + dz * dz

func _scan(x: float, z: float, i0: int, cnt: int) -> void:
	for k in cnt:
		var i := posmod(i0 + k, n)
		if open and i == n - 1:
			continue
		var a := samples[i]
		var b := samples[(i + 1) % n]
		var abx := b.x - a.x
		var abz := b.z - a.z
		var den := abx * abx + abz * abz
		var t := clampf(((x - a.x) * abx + (z - a.z) * abz) / den, 0.0, 1.0) if den > 0.0 else 0.0
		var dx := x - (a.x + abx * t)
		var dz := z - (a.z + abz * t)
		var d := dx * dx + dz * dz
		if d < _bd:
			_bd = d
			_bi = i
			_bt = t

## Deja en r_* el tramo más cercano a (x, z). Desde "hint" camina cuesta abajo (mucho más rápido que revisar todo).
func nearest(x: float, z: float) -> void:
	var Wd := 35
	_bd = INF
	_bi = 0
	_bt = 0.0
	if hint >= 0:
		var h := hint
		var i := h
		var d := _seg_d(x, z, i)
		for st in [1, -1]:
			var k := 0
			while k < Wd:
				k += 1
				var j := posmod(i + st, n)
				if open and (j == n - 1 or absi(j - i) > 1):
					break
				var dj := _seg_d(x, z, j)
				if dj < d:
					i = j
					d = dj
				else:
					break
			if i != h:
				break
		_scan(x, z, i - 4, 9)
		# lejos del camino puede haber varios mínimos: ahí se revisa una ventana completa
		if _bd > 225.0 or trust:
			_bd = INF
			_scan(x, z, h - Wd, 2 * Wd + 1)
		var off := _bi - h
		if off > n / 2:
			off -= n
		if off < -n / 2:
			off += n
		if absi(off) >= Wd - 1 or (_bd > 900.0 and not trust):
			_bd = INF
			_scan(x, z, 0, n)
	else:
		_scan(x, z, 0, n)
	hint = _bi
	var a := samples[_bi]
	var b := samples[(_bi + 1) % n]
	r_idx = _bi
	r_t = _bt
	r_y = lerpf(cy[_bi], cy[(_bi + 1) % n], _bt)
	var lat := laterals[_bi]
	r_lat = (x - (a.x + (b.x - a.x) * _bt)) * lat.x + (z - (a.z + (b.z - a.z) * _bt)) * lat.z
	r_dist = sqrt(_bd)

## Hondonada del lago (Travesía X): el terreno de los costados baja alrededor del vado para que el agua se vea como un lago y el camino lo cruce
func _basin(idx: int, d: float) -> float:
	var depth := 0.0
	for w in water:
		var i0: int = int(w["i0"])
		var i1: int = int(w["i1"])
		if idx < i0 - 40 or idx > i1 + 40:
			continue
		var along := clampf(minf(float(idx - i0 + 40), float(i1 + 40 - idx)) / 40.0, 0.0, 1.0)
		along = along * along * (3.0 - 2.0 * along)
		var half: float = float(w["half"])
		var u := clampf((half - d) / (half * 0.7), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var bank := clampf((d - (half_width + shoulder)) / 22.0, 0.0, 1.0) # la orilla baja de a poco desde la banquina (antes era un escalón de 1,7 m al borde del camino)
		bank = bank * bank * (3.0 - 2.0 * bank)
		depth = maxf(depth, 1.7 * along * u * bank)
	return depth

func _terrain_base(x: float, z: float, road_y: float) -> float:
	return road_y - 0.25 + 0.7 * sin(x * 0.020 + z * 0.018) + 0.35 * sin(x * 0.045 - z * 0.038 + 1.3) + 0.18 * sin(x * 0.11 + z * 0.09 + 2.7)

## Terreno fuera de la banquina: el camino va hundido, como en una trinchera suave. Del borde de la banquina sube de forma
## progresiva (pendiente suave que se acentúa y se aplana) hasta ~0,9 m por encima del camino, y ahí sigue con las ondulaciones del campo.
func _outside_y(d: float, se: float, x: float, z: float, road_y: float) -> float:
	var dd := maxf(0.0, d - se)
	var t := minf(dd / 16.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t)
	var u := _terrain_base(x, z, road_y) - (road_y - 0.25) # ondulación del campo (±1,2 m)
	var hi := road_y + 0.9 + u * 0.7
	return lerpf(road_y - 0.05, hi, s)

func _micro_bump(x: float, z: float, surf: int) -> float:
	var a: float = BUMP_AMP[surf]
	var nn := sin(x * 0.71 + z * 0.53) * sin(x * 0.29 - z * 0.83 + 1.3) * 0.6 + sin(x * 1.9 + z * 1.3 + 0.7) * 0.15 + sin(x * 0.17 + z * 0.13 + 2.1) * 0.25
	return a * (0.5 + 0.5 * nn)

func _surf_of(d: float, idx := -1) -> int:
	var se := half_width + shoulder
	if d <= half_width:
		if idx >= 0 and road_surf.size() == n:
			return int(road_surf[idx])
		return 0 if mode == "asphalt" else 1
	if d <= se:
		return 2
	return 3 if d < 12.0 else 4

## Altura y superficie (0 asfalto · 1 tierra · 2 banquina · 3 pasto · 4 afuera · 5 barro) en un punto
func ground_info(x: float, z: float) -> Vector2:
	nearest(x, z)
	var d := absf(r_lat)
	var edge := half_width
	var se := edge + shoulder
	var y: float
	if d <= edge:
		y = r_y + (1.0 - pow(minf(d / edge, 1.0), 2.0)) * 0.03
	else:
		if d <= se:
			var t := (d - edge) / shoulder
			y = r_y - 0.05 * t # la banquina baja apenas hacia la cuneta
		else:
			y = _outside_y(d, se, x, z, r_y)
			if not water.is_empty():
				y -= _basin(r_idx, d)
	var surf := _surf_of(d, r_idx)
	return Vector2(y + _micro_bump(x, z, surf), float(surf))

## Altura del terreno sin la ondulación fina (para dibujar)
func ground_smooth(x: float, z: float) -> float:
	nearest(x, z)
	var d := absf(r_lat)
	var edge := half_width
	var se := edge + shoulder
	if d <= edge:
		return r_y + (1.0 - pow(minf(d / edge, 1.0), 2.0)) * 0.03
	if d <= se:
		var t := (d - edge) / shoulder
		return r_y - 0.05 * t
	if not water.is_empty():
		return _outside_y(d, se, x, z, r_y) - _basin(r_idx, d)
	return _outside_y(d, se, x, z, r_y)

# ───────────────────────── largada y progreso ─────────────────────────
## Pose de largada en el lugar "slot" de la parrilla (0 = adelante a la derecha): x, z, yaw
func start_pose(slot: int, from_idx := 0) -> Array:
	var back := 6.0 + float(slot / 2) * 9.0
	var i := from_idx
	var acc := 0.0
	while acc < back:
		var j := posmod(i - 1, n)
		acc += samples[i].distance_to(samples[j])
		i = j
	var side := -1.0 if slot % 2 == 0 else 1.0
	var s := samples[i]
	var l := laterals[i]
	var t := tangents[i]
	return [s.x + l.x * side * 2.0, s.z + l.z * side * 2.0, atan2(t.x, t.z), i]

## Fracciones [desde, hasta] de la ruta cuyas muestras caen en x0 y x1 sobre la recta de salida (z = 0); para pistas con un tramo recto (picada)
func seg_between_x(x0: float, x1: float) -> Array:
	var out: Array = []
	for xv in [x0, x1]:
		var bi := 0
		var bd := 1e18
		for i in n:
			var d := absf(samples[i].x - xv) + absf(samples[i].z) * 2.0
			if d < bd:
				bd = d
				bi = i
		out.append(float(bi) / float(n))
	return out

## distancia recorrida sobre la ruta (m) del punto más cercano, para posiciones y vueltas
func arc_pos(x: float, z: float) -> float:
	nearest(x, z)
	return cum[r_idx] + r_t * (cum[r_idx + 1] - cum[r_idx])

# ───────────────────────── dibujo ─────────────────────────
func _asphalt_tex() -> ImageTexture:
	var img := Image.create(128, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var base := Color(0.20, 0.205, 0.22) if mode == "asphalt" else Color(0.36, 0.29, 0.22)
	for y in 256:
		for x in 128:
			var q := (rng.randf() - 0.5) * 0.07
			img.set_pixel(x, y, Color(base.r + q, base.g + q, base.b + q))
	if mode == "asphalt":
		for y in 256:
			for x in range(8, 14):
				img.set_pixel(x, y, Color(0.92, 0.92, 0.88))
			for x in range(114, 120):
				img.set_pixel(x, y, Color(0.92, 0.92, 0.88))
		if center_line:
			for y in range(0, 128):
				for x in range(62, 67):
					img.set_pixel(x, y, Color(0.96, 0.80, 0.27))
	else:
		for y in 256:
			for xs in [38, 90]:
				var ox := int(sin(float(y) * 0.05) * 3.0)
				for x in range(xs - 9 + ox, xs + 9 + ox):
					var c := img.get_pixel(clampi(x, 0, 127), y)
					img.set_pixel(clampi(x, 0, 127), y, c.darkened(0.16))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Camino: una cinta de dos vértices por muestra
func build_road_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray() # el barro se ve más oscuro y húmedo (si la ruta tiene superficies por tramo)
	for i in n:
		var p := samples[i]
		var lat := laterals[i]
		var y := cy[i] + 0.015
		verts.append(Vector3(p.x - lat.x * half_width, y, p.z - lat.z * half_width))
		verts.append(Vector3(p.x + lat.x * half_width, y, p.z + lat.z * half_width))
		uvs.append(Vector2(0, float(i) * 0.22))
		uvs.append(Vector2(1, float(i) * 0.22))
		if road_surf.size() == n:
			var sc := Color(1, 1, 1) if int(road_surf[i]) == 0 else (Color(0.62, 0.50, 0.40) if int(road_surf[i]) == 5 else Color(1.0, 0.97, 0.92))
			cols.append(sc)
			cols.append(sc)
	for i in n:
		var j := (i + 1) % n
		var a := i * 2
		var b := i * 2 + 1
		var c := j * 2
		var d := j * 2 + 1
		idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	if not cols.is_empty():
		arr[Mesh.ARRAY_COLOR] = cols
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _asphalt_tex()
	mat.vertex_color_use_as_albedo = not cols.is_empty()
	mat.roughness = 0.9
	mat.uv1_scale = Vector3(1, 1, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m

## Banquina y franja exterior: copia lo que pisa la física (ground_smooth) y se abre en pasto
func build_shoulder_mesh() -> ArrayMesh:
	return _strip_mesh([0.0, 1.0, 1.6, 3.2, 6.0, 10.0, 16.0, 23.0, 26.0], 26.0, 1, false)

## Franja de cerca de la Travesía X (de 26 m a STRIP_EXT m del camino) con la altura exacta de la física, una fila cada 3 muestras: el terreno de fondo es una grilla muy gruesa (la ruta mide más de 40 km) y no
## puede dibujar bien lo que está a la vista del camino. Empalma con la banquina (mismo color y la misma caída de 24 cm).
func build_far_strip() -> ArrayMesh:
	return _strip_mesh([26.0, 34.0, 46.0, 60.0, 76.0, STRIP_EXT], STRIP_EXT, 3, true)

## fr: distancias (m) al borde del camino de cada columna · step: cada cuántas muestras hay una fila · flat_sink: la franja de afuera queda 24 cm bajo el suelo (como el final de la banquina)
## Las filas son independientes: se calculan en hilos (en la Travesía X son más de 11 000 filas y en un solo hilo tardaba más de un minuto). strip_begin() las lanza y strip_finish() arma la malla;
## strip_progress() dice cuánto va (0…1) para la barra de carga.
func _strip_mesh(fr: Array, ext: float, step: int, flat_sink: bool) -> ArrayMesh:
	return strip_finish(strip_begin(fr, ext, step, flat_sink))

func strip_begin(fr: Array, ext: float, step: int, flat_sink: bool) -> Dictionary:
	var rows := range(0, n, step)
	var chunks := 32
	var h := {"fr": fr, "ext": ext, "step": step, "flat": flat_sink, "rows": rows, "per": ceili(float(rows.size()) / float(chunks)), "chunks": chunks, "res": []}
	(h["res"] as Array).resize(chunks)
	h["task"] = WorkerThreadPool.add_group_task(_strip_job.bind(h), chunks, -1, true, "franja")
	return h

func _strip_job(ci: int, h: Dictionary) -> void:
	(h["res"] as Array)[ci] = _strip_rows(h, ci)

func strip_progress(h: Dictionary) -> float:
	var done := 0
	for r in (h["res"] as Array):
		if r != null:
			done += 1
	return float(done) / float(h["chunks"])

func strip_done(h: Dictionary) -> bool:
	return WorkerThreadPool.is_group_task_completed(int(h["task"]))

func _strip_rows(h: Dictionary, ci: int) -> Array:
	var fr: Array = h["fr"]
	var ext: float = h["ext"]
	var flat_sink: bool = h["flat"]
	var rows: Array = h["rows"]
	var rw := fr.size()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var c_sh := Color(0.48, 0.42, 0.34)
	var c_gr := Color(0.28, 0.40, 0.24)
	var view = make_view(false)
	view.hint = -1
	view.trust = true # busca sólo en una ventana alrededor de la fila (sin recorrer toda la ruta por cada punto)
	var r0: int = ci * int(h["per"])
	var r1: int = mini(r0 + int(h["per"]), rows.size())
	for ri in range(r0, r1):
		var i: int = rows[ri]
		var p := samples[i]
		var lat := laterals[i]
		var yc := cy[i]
		for s in [-1.0, 1.0]:
			for k in rw:
				var f: float = fr[k]
				var x: float
				var z: float
				var yy: float
				if f == 0.0:
					x = p.x + lat.x * s * half_width
					z = p.z + lat.z * s * half_width
					yy = yc + 0.01
				elif f == 1.0:
					x = p.x + lat.x * s * (half_width + shoulder)
					z = p.z + lat.z * s * (half_width + shoulder)
					view.hint = i
					yy = view.ground_smooth(x, z) + 0.03
				else:
					var o := half_width + shoulder + (f - 1.0)
					if route_id == "travesia":
						o = minf(o, inner_limit(i, s))
					x = p.x + lat.x * s * o
					z = p.z + lat.z * s * o
					var e := 1.0 if flat_sink else (f - 1.0) / (ext - 1.0)
					view.hint = i
					yy = view.ground_smooth(x, z) + 0.02 - 0.24 * e * e
				verts.append(Vector3(x, yy, z))
				cols.append(c_sh if f <= 1.0 else c_sh.lerp(c_gr, minf(1.0, (f - 1.0) / 3.5)))
	return [verts, cols]

func strip_finish(h: Dictionary) -> ArrayMesh:
	WorkerThreadPool.wait_for_group_task_completion(int(h["task"]))
	var fr: Array = h["fr"]
	var rw := fr.size()
	var rows: Array = h["rows"]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for r in (h["res"] as Array):
		verts.append_array(r[0])
		cols.append_array(r[1])
	var idx := PackedInt32Array()
	for ri in rows.size():
		var ni := (ri + 1) % rows.size()
		for side in 2:
			for k in rw - 1:
				var a := ri * rw * 2 + side * rw + k
				var b := a + 1
				var c := ni * rw * 2 + side * rw + k
				var d := c + 1
				# orienta cada triángulo hacia arriba (en curvas cerradas la franja se pliega)
				for tri in [[a, b, c], [b, d, c]]:
					var va: Vector3 = verts[tri[0]]
					var vb: Vector3 = verts[tri[1]]
					var vc: Vector3 = verts[tri[2]]
					if (vb - va).cross(vc - va).y < 0.0:
						idx.append_array([tri[0], tri[2], tri[1]])
					else:
						idx.append_array(tri)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var uvs2 := PackedVector2Array()
	for v in verts:
		uvs2.append(Vector2(v.x, v.z) * 0.22)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	var out := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = grass_texture()
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	out.surface_set_material(0, mat)
	return out

## Terreno alrededor: grilla con la altura de la física (hundida bajo el camino para que no asome nada)
func terrain_dims(cell_min := 14.0) -> Dictionary:
	var ext := max_xz - min_xz
	var r := int(clampf(ceil(maxf(ext.x, ext.y) / cell_min), 60.0, 220.0))
	return {"R": r, "cell": maxf(ext.x, ext.y) / float(r)}

## Una fila de la grilla (para repartir en hilos): devuelve posiciones y colores
func terrain_row(iz: int, r: int) -> Array:
	var view = make_view(false)
	view.trust = true
	var span := maxf(max_xz.x - min_xz.x, max_xz.y - min_xz.y)
	var z := min_xz.y + span * float(iz) / float(r)
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var coarse := PackedInt32Array()
	for i in range(0, n, maxi(6, n / 600)):
		coarse.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + iz
	var sr := half_width + (span / float(r)) * 1.45
	if route_id == "travesia":
		sr = STRIP_EXT + (span / float(r)) * 0.9 # la franja de cerca (build_far_strip) tapa hasta STRIP_EXT m: la grilla se hunde sólo debajo de ella
	for ix in r + 1:
		var x := min_xz.x + span * float(ix) / float(r)
		var bi := 0
		var bd := 1e18
		for i in coarse:
			var dx := samples[i].x - x
			var dz := samples[i].z - z
			var dd := dx * dx + dz * dz
			if dd < bd:
				bd = dd
				bi = i
		view.hint = bi
		var y0: float = view.ground_smooth(x, z) - 0.25
		var d: float = absf(view.r_lat)
		pos.append(Vector3(x, y0 - ((0.35 if route_id == "travesia" else 0.6) if d < sr else 0.0), z))
		var cc := Color(0.45, 0.38, 0.30) if d < half_width + shoulder else Color(0.29, 0.40, 0.24)
		var q := (rng.randf() - 0.5) * 0.08
		col.append(Color(cc.r + q, cc.g + q, cc.b + q * 0.5))
	return [pos, col]

func build_terrain_mesh(rows: Array, r: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for row in rows:
		verts.append_array(row[0])
		cols.append_array(row[1])
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.z) * 0.22)
	var idx := PackedInt32Array()
	for iz in r:
		for ix in r:
			var a := iz * (r + 1) + ix
			var b := a + 1
			var c := a + r + 1
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	var out := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = grass_texture()
	mat.roughness = 1.0
	out.surface_set_material(0, mat)
	return out

## Línea de largada con dos postes y el cartel
func build_start_gate(gi := 0, text := "DREAM RACING", color := Color(1, 1, 1)) -> Node3D:
	var g := Node3D.new()
	var p := samples[gi]
	var l := laterals[gi]
	var tg := tangents[gi]
	var w := half_width + shoulder * 0.6
	var yaw := atan2(tg.x, tg.z)
	# línea a cuadros pegada al camino
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 64:
			img.set_pixel(x, y, Color(0.96, 0.96, 0.96) if ((x / 4) + (y / 4)) % 2 == 0 else Color(0.08, 0.08, 0.08))
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = ImageTexture.create_from_image(img)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var lp := PlaneMesh.new()
	lp.size = Vector2(half_width * 2.0, 1.2)
	var line := MeshInstance3D.new()
	line.mesh = lp
	line.material_override = lm
	line.position = Vector3(p.x, cy[gi] + 0.04, p.z)
	line.rotation.y = yaw
	g.add_child(line)
	# postes y cartel
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.13, 0.14, 0.17)
	pm.metallic = 0.6
	pm.roughness = 0.4
	for sd in [-1.0, 1.0]:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 5.2, 0.35)
		var post := MeshInstance3D.new()
		post.mesh = bm
		post.material_override = pm
		post.position = Vector3(p.x + l.x * w * sd, cy[gi] + 2.6, p.z + l.z * w * sd)
		g.add_child(post)
	var ban := Label3D.new()
	ban.text = text
	ban.font_size = 96
	ban.pixel_size = 0.012
	ban.modulate = color
	ban.outline_size = 24
	ban.outline_modulate = Color(0.05, 0.07, 0.1)
	ban.double_sided = true
	ban.shaded = false
	ban.position = Vector3(p.x, cy[gi] + 4.7, p.z)
	ban.rotation.y = yaw + PI
	g.add_child(ban)
	return g


## Guardarraíl a los dos lados del camino (sobre el borde de la banquina): postes en un MultiMesh y dos cintas de chapa acanalada.
## rail_off: distancia al centro del camino. wood: valla de madera (tierra) en vez de chapa galvanizada.
func build_guardrail(rail_off: float, wood := false) -> Node3D:
	var g := Node3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 0.95, 0.14) if not wood else Vector3(0.2, 1.1, 0.2)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.47, 0.5) if not wood else Color(0.33, 0.22, 0.13)
	pm.roughness = 0.6
	pm.metallic = 0.5 if not wood else 0.0
	post_mesh.material = pm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	mm.instance_count = n * 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# perfil de la chapa (distancia hacia afuera, altura): acanalado en W; cada lado es una cinta continua
	var prof: Array = [[0.0, 0.40], [0.035, 0.46], [0.0, 0.53], [0.05, 0.62], [0.0, 0.71], [0.035, 0.78], [0.0, 0.84]]
	if wood:
		prof = [[0.0, 0.50], [0.0, 0.66], [0.0, 0.80], [0.0, 0.96]]
	var base_col := Color(0.78, 0.8, 0.83) if not wood else Color(0.42, 0.29, 0.18)
	var k := 0
	for sd in [-1.0, 1.0]:
		var v0 := verts.size()
		var np: int = prof.size()
		for i in n:
			var p: Vector3 = samples[i]
			var l: Vector3 = laterals[i]
			var y0: float = cy[i] - 0.06
			var ox: float = p.x + l.x * sd * rail_off
			var oz: float = p.z + l.z * sd * rail_off
			# poste (un poco más afuera que la chapa)
			var t: Vector3 = tangents[i]
			var b := Basis(Vector3.UP, atan2(t.x, t.z))
			mm.set_instance_transform(k, Transform3D(b, Vector3(ox + l.x * sd * 0.12, y0 + post_mesh.size.y * 0.5, oz + l.z * sd * 0.12)))
			k += 1
			for q in np:
				var off: float = prof[q][0]
				verts.append(Vector3(ox + l.x * sd * off, y0 + float(prof[q][1]), oz + l.z * sd * off))
				norms.append(Vector3(-l.x * sd, 0.0, -l.z * sd))
				cols.append(base_col * (0.92 + 0.12 * float(q % 2)))
		for i in n:
			var j := (i + 1) % n
			for q in range(np - 1):
				var a := v0 + i * np + q
				var b2 := v0 + i * np + q + 1
				var c := v0 + j * np + q
				var d := v0 + j * np + q + 1
				idx.append_array([a, b2, c, b2, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.45
	rm.metallic = 0.55 if not wood else 0.0
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, rm)
	var rail := MeshInstance3D.new()
	rail.mesh = am
	rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(rail)
	var posts := MultiMeshInstance3D.new()
	posts.multimesh = mm
	posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(posts)
	return g


## Textura de pasto: ruido de varias escalas y briznas cortas (256 px con mipmaps); se tiñe con el color de cada vértice
static var _grass_cache: ImageTexture
static func grass_texture() -> ImageTexture:
	if _grass_cache != null:
		return _grass_cache
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in N:
		for x in N:
			var fx := float(x) / float(N) * TAU
			var fy := float(y) / float(N) * TAU
			# ruido periódico (las frecuencias son enteras: la textura repite sin costura)
			var low := 0.5 + 0.25 * sin(fx * 2.0 + sin(fy * 3.0)) + 0.25 * sin(fy * 3.0 + sin(fx * 2.0) * 1.5)
			var mid := 0.5 + 0.5 * sin(fx * 9.0 + fy * 5.0) * sin(fy * 8.0 - fx * 3.0)
			var v := 0.78 + 0.16 * low + 0.07 * mid + 0.07 * rng.randf()
			img.set_pixel(x, y, Color(v * 0.97, v, v * 0.93))
	# brizna: trazo corto casi vertical, más claro o más oscuro
	for k in 2600:
		var bx := rng.randi() % N
		var by := rng.randi() % N
		var ln := 3 + rng.randi() % 6
		var lean := rng.randf_range(-0.5, 0.5)
		var shade := 0.72 if rng.randf() < 0.5 else 1.14
		for j in ln:
			var px := posmod(bx + int(lean * float(j)), N)
			var py := (by - j + N) % N
			var c := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(clampf(c.r * shade, 0.0, 1.0), clampf(c.g * shade, 0.0, 1.0), clampf(c.b * shade, 0.0, 1.0)))
	img.generate_mipmaps()
	_grass_cache = ImageTexture.create_from_image(img)
	return _grass_cache

## Matas de pasto y flores pegadas al camino: cuadrados cruzados con transparencia, repartidos en un MultiMesh (se ven hasta ~90 m)
func build_tufts(count: int, from_off: float, seed_v: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for b in 14:
		var bx := 6.0 + float(b) * 3.6 + rng.randf() * 2.0
		var hgt := rng.randf_range(0.45, 0.95) * float(N - 2)
		var lean := rng.randf_range(-0.35, 0.35)
		var col := Color(0.18 + rng.randf() * 0.12, 0.42 + rng.randf() * 0.2, 0.12 + rng.randf() * 0.08, 1.0)
		for j in int(hgt):
			var w := 1.0 + (1.0 - float(j) / hgt) * 2.2
			var px := bx + lean * float(j) * 0.5
			for dx in range(-int(w), int(w) + 1):
				var xx := clampi(int(px) + dx, 0, N - 1)
				var yy := N - 1 - j
				img.set_pixel(xx, yy, col.lightened(float(j) / hgt * 0.25))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	var quad_a := QuadMesh.new()
	quad_a.size = Vector2(1.1, 0.7)
	quad_a.center_offset = Vector3(0, 0.35, 0)
	quad_a.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad_a
	mm.instance_count = count * 2 # cada mata son dos cuadrados cruzados
	var view = make_view()
	view.hint = -1
	var k := 0
	for q in count:
		var si := rng.randi() % n
		var p: Vector3 = samples[si]
		var l: Vector3 = laterals[si]
		var off := from_off + rng.randf() * rng.randf() * 18.0
		var sg := 1.0 if rng.randf() < 0.5 else -1.0
		var x: float = p.x + l.x * sg * off
		var z: float = p.z + l.z * sg * off
		view.hint = si
		var y: float = view.ground_smooth(x, z) - 0.02
		var sc := rng.randf_range(0.7, 1.5)
		var yaw := rng.randf() * PI
		var tint := Color(0.85 + rng.randf() * 0.3, 0.9 + rng.randf() * 0.2, 0.8 + rng.randf() * 0.2)
		for cr in 2:
			var b := Basis(Vector3.UP, yaw + float(cr) * PI * 0.5).scaled(Vector3(sc, sc, sc))
			mm.set_instance_transform(k, Transform3D(b, Vector3(x, y, z)))
			mm.set_instance_color(k, tint)
			k += 1
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 95.0
	return inst
