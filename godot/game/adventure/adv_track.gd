extends "res://game/track/route_track.gd"
## Pista de una etapa del modo aventura: el tramo de la Ruta de los Sueños entre dos estaciones de servicio (más un poco antes
## y después), centrado en el origen. Es una ruta abierta con ancho, superficie y ambiente que cambian por tramo:
##   · camino: medio ancho (hwa) + ensanche a la derecha para entrar a estaciones y talleres (laya)
##   · banquina (shl) y después el terreno según el ambiente: vereda de la ciudad, cuneta y campo, bosque con el camino
##     hundido, montaña (paredón de un lado y precipicio del otro), terrazas de la cantera, bancos de nieve…
##   · túneles, puente sobre el río y paso bajo nivel cambian el terreno de los costados
## Los cambios de ambiente se mezclan de a poco (pesos suavizados por muestra) para que no haya escalones.

const AdvRoute := preload("res://game/adventure/adv_route.gd")

const NB := 7 # ambientes
const SHOULDER_B := [0.0, 1.4, 1.5, 1.0, 1.2, 1.5, 1.0] # banquina por ambiente (la ciudad tiene cordón y vereda)
const WALL_B := [2.6, 3.4, 0.55, 0.45, 0.9, 0.7, 0.45] # dónde está el límite (desde el borde de la banquina)
const GRIP_SURF := {0: 1.0, 1: 0.566, 6: 0.44} # agarre relativo para la IA

var stage := 0
var g0 := 0 # índice global de la muestra 0
var origin := Vector3.ZERO
var hwa := PackedFloat32Array()
var laya := PackedFloat32Array()
var shl := PackedFloat32Array()
var surfa := PackedByteArray()
var biomea := PackedByteArray()
var flaga := PackedInt32Array()
var cropa := PackedByteArray()
var towna := PackedByteArray()
var msidea := PackedFloat32Array() # +1 montaña a la derecha · −1 a la izquierda (suavizado)
var bw: Array = [] # pesos de cada ambiente por muestra
var w_bridge := PackedFloat32Array()
var w_tunnel := PackedFloat32Array()
var w_under := PackedFloat32Array()
var w_lay := PackedFloat32Array()
var under_top := PackedFloat32Array() # altura de la calle de arriba en el paso bajo nivel
var clear_l := PackedFloat32Array() # hasta dónde se puede dibujar terreno de cada lado sin pisar otra parte del camino
var clear_r := PackedFloat32Array()
var curv := PackedFloat32Array()
var events: Array = []
var i_start := 0 # surtidores de la estación de largada
var i_end := 0 # surtidores de la estación de llegada
var stage_len := 0.0

var variant := -1 # −1 camino principal · k = toma el ramal de la bifurcación k
var forks: Array = [] # bifurcaciones de la etapa {fork, split, join, m} (índices del camino principal)
var split := -1 # en una variante con ramal: dónde se separa y dónde se une (índices de esta variante)
var join := -1
var other # vista de la otra variante (para pasar de un camino al otro en la bifurcación)
var allow_switch := false # solo la vista del auto del jugador (y su cámara) cambian de camino
var zone := Vector2i(-1, -1) # muestras donde se revisa si el auto está en el otro camino
var mside_raw := PackedByteArray()

func _init(p_stage := -1, p_variant := -1) -> void:
	if p_stage < 0:
		return
	stage = p_stage
	variant = p_variant
	open = true
	center_line = true
	mode = "asphalt"
	half_width = 4.0
	shoulder = 1.4
	route_id = "adv%d_%d" % [p_stage, p_variant]
	_build_stage()

func _copy_view(v: Object) -> void:
	v.stage = stage
	v.g0 = g0
	v.origin = origin
	v.hwa = hwa
	v.laya = laya
	v.shl = shl
	v.surfa = surfa
	v.biomea = biomea
	v.flaga = flaga
	v.cropa = cropa
	v.towna = towna
	v.msidea = msidea
	v.bw = bw
	v.w_bridge = w_bridge
	v.w_tunnel = w_tunnel
	v.w_under = w_under
	v.w_lay = w_lay
	v.under_top = under_top
	v.clear_l = clear_l
	v.clear_r = clear_r
	v.curv = curv
	v.events = events
	v.i_start = i_start
	v.i_end = i_end
	v.stage_len = stage_len
	v.center_line = center_line
	v.variant = variant
	v.forks = forks
	v.split = split
	v.join = join
	v.zone = zone

const SWAP_FIELDS := ["samples", "tangents", "laterals", "cum", "cy", "length", "n", "hwa", "laya", "shl", "surfa", "biomea", "flaga", "cropa",
	"towna", "msidea", "bw", "w_bridge", "w_tunnel", "w_under", "w_lay", "under_top", "clear_l", "clear_r", "curv", "events", "i_end", "variant",
	"split", "join", "zone", "surf_mu", "wall_l", "wall_r", "prof_cache", "hint", "min_xz", "max_xz", "route_id"]

## Vista que puede cambiar de camino en las bifurcaciones (la del jugador): o es la vista de la otra variante
func link_other(o) -> void:
	other = o
	allow_switch = true

## Búsqueda del tramo más cercano; en la zona de una bifurcación también mira el otro camino y, si el auto está más
## cerca de ese, la vista pasa a ser la de ese camino (todos los datos cambian juntos).
func nearest(x: float, z: float) -> void:
	super.nearest(x, z)
	if not allow_switch or other == null or r_idx < zone.x or r_idx > zone.y:
		return
	other.nearest(x, z)
	var mine := absf(r_lat) - float(hwa[r_idx])
	var theirs: float = absf(float(other.r_lat)) - float(other.hwa[other.r_idx])
	if theirs < mine - 0.3:
		# solo si el auto ya está dentro de los límites del otro camino (si no, el cambio lo empujaría contra un muro)
		var oi: int = other.r_idx
		var ol: float = float(other.r_lat)
		if ol <= float(other.wall_r[oi]) and ol >= -float(other.wall_l[oi]):
			_swap()

func _swap() -> void:
	for f in SWAP_FIELDS:
		var a = get(f)
		set(f, other.get(f))
		other.set(f, a)
	for f in ["r_dist", "r_idx", "r_t", "r_y", "r_lat"]:
		set(f, other.get(f))
	hint = r_idx

func _build_stage() -> void:
	var R = AdvRoute.get_route()
	var D: Dictionary = R.variant_data(stage, variant)
	g0 = int(D["g0"])
	n = int(D["n"])
	i_start = int(D["i_start"])
	i_end = int(D["i_end"])
	forks = D["forks"]
	split = int(D.get("split", -1))
	join = int(D.get("join", -1))
	if variant >= 0:
		zone = Vector2i(split - 24, join + 24)
	else:
		for fk in forks:
			if int(fk["fork"]) == 0 or zone.x < 0:
				zone = Vector2i(int(fk["split"]) - 24, int(fk["join"]) + 24)
	stage_len = R.stage_length(stage)
	origin = D["origin"]
	samples.resize(n)
	hwa = D["hw"]
	laya = D["lay"]
	surfa = D["surf"]
	biomea = D["biome"]
	flaga = D["flags"]
	cropa = D["crop"]
	towna = D["town"]
	curv = D["k"]
	mside_raw = D["mside"]
	shl.resize(n)
	surf_mu.resize(n)
	var X: PackedFloat64Array = D["x"]
	var Y: PackedFloat64Array = D["y"]
	var Z: PackedFloat64Array = D["z"]
	for i in n:
		samples[i] = Vector3(X[i] - origin.x, Y[i] - origin.y, Z[i] - origin.z)
		surf_mu[i] = float(GRIP_SURF.get(int(surfa[i]), 0.35))
	events = D["events"]
	# pesos suavizados de cada ambiente y de las obras especiales (±40 m)
	bw.clear()
	for b in NB:
		var a := PackedFloat32Array()
		a.resize(n)
		for i in n:
			a[i] = 1.0 if int(biomea[i]) == b else 0.0
		bw.append(_smooth(a, 16))
	w_bridge = _smooth(_flag_arr(AdvRoute.F_BRIDGE), 10)
	w_tunnel = _smooth(_flag_arr(AdvRoute.F_TUNNEL), 14)
	w_under = _smooth(_flag_arr(AdvRoute.F_UNDER), 3)
	w_lay = _smooth(_flag_arr(AdvRoute.F_STATION | AdvRoute.F_WORKSHOP), 8)
	var ms := PackedFloat32Array()
	ms.resize(n)
	for i in n:
		ms[i] = 1.0 if int(mside_raw[i]) == 1 else -1.0
	msidea = _smooth(ms, 20)
	for i in n:
		var s := 0.0
		for b in NB:
			s += float(bw[b][i]) * float(SHOULDER_B[b])
		shl[i] = lerpf(s, 0.6, maxf(w_bridge[i], maxf(w_tunnel[i], w_under[i])))
	# direcciones, distancias y altura del centro
	tangents.resize(n)
	laterals.resize(n)
	for i in n:
		var tg := (samples[mini(i + 1, n - 1)] - samples[maxi(i - 1, 0)]).normalized()
		tangents[i] = tg
		laterals[i] = tg.cross(Vector3.UP).normalized()
	cum.resize(n + 1)
	for i in range(1, n):
		cum[i] = cum[i - 1] + samples[i - 1].distance_to(samples[i])
	cum[n] = cum[n - 1] + 2.5
	length = cum[n - 1]
	cy.resize(n)
	for i in n:
		cy[i] = samples[i].y + 0.06
	# paso bajo nivel: la calle de arriba queda a la altura de la entrada
	under_top.resize(n)
	var top := 0.0
	for i in n:
		if (int(flaga[i]) & AdvRoute.F_UNDER) != 0:
			if i == 0 or (int(flaga[i - 1]) & AdvRoute.F_UNDER) == 0:
				top = cy[i]
			under_top[i] = top
		else:
			under_top[i] = cy[i]
	# límites laterales (el centro del auto no pasa de acá)
	wall_l.resize(n)
	wall_r.resize(n)
	for i in n:
		var wb := 0.0
		for b in NB:
			wb += float(bw[b][i]) * float(WALL_B[b])
		var sp := maxf(w_bridge[i], maxf(w_tunnel[i], w_under[i]))
		wb = lerpf(wb, 0.25 if w_tunnel[i] < 0.5 else 0.6, sp)
		var base: float = hwa[i] + shl[i] + wb - 1.0
		wall_l[i] = base
		wall_r[i] = base + laya[i]
	_bounds()
	_clearance()

func _flag_arr(f: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = 1.0 if (int(flaga[i]) & f) != 0 else 0.0
	return a

static func _smooth(a: PackedFloat32Array, W: int) -> PackedFloat32Array:
	var nn := a.size()
	var o := PackedFloat32Array()
	o.resize(nn)
	# media móvil con suma acumulada (bordes recortados)
	var pre := PackedFloat64Array()
	pre.resize(nn + 1)
	for i in nn:
		pre[i + 1] = pre[i] + a[i]
	for i in nn:
		var lo := maxi(0, i - W)
		var hi := mini(nn, i + W + 1)
		o[i] = float((pre[hi] - pre[lo]) / float(hi - lo))
	return o

func _bounds() -> void:
	min_xz = Vector2(1e9, 1e9)
	max_xz = Vector2(-1e9, -1e9)
	for p in samples:
		min_xz = Vector2(minf(min_xz.x, p.x), minf(min_xz.y, p.z))
		max_xz = Vector2(maxf(max_xz.x, p.x), maxf(max_xz.y, p.z))
	min_xz -= Vector2(200, 200)
	max_xz += Vector2(200, 200)

## Hasta dónde se dibuja el terreno de cada lado: no más allá de la mitad del camino hasta otra parte lejana del recorrido
## (curvas en U, caminos paralelos) ni más allá del centro de la curva por dentro (ahí la franja se doblaría sobre sí misma).
const STRIP_MAX := 150.0
func _clearance() -> void:
	clear_l.resize(n)
	clear_r.resize(n)
	clear_l.fill(STRIP_MAX)
	clear_r.fill(STRIP_MAX)
	# por dentro de las curvas
	for i in n:
		var kmax := 0.0
		var ksg := 0.0
		for j in range(maxi(0, i - 10), mini(n, i + 11)):
			if absf(curv[j]) > kmax:
				kmax = absf(curv[j])
				ksg = signf(curv[j])
		if kmax > 1e-4:
			var r := 0.92 / kmax
			# curva a la izquierda (+): el centro queda a la izquierda
			if ksg > 0.0:
				clear_l[i] = minf(clear_l[i], r)
			else:
				clear_r[i] = minf(clear_r[i], r)
	# otras partes del camino cerca
	var cell := 80.0
	var grid := {}
	for i in range(0, n, 2):
		var key := Vector2i(floori(samples[i].x / cell), floori(samples[i].z / cell))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		(grid[key] as PackedInt32Array).append(i)
	for i in range(0, n, 3):
		var p := samples[i]
		var l := laterals[i]
		var key := Vector2i(floori(p.x / cell), floori(p.z / cell))
		var cl := STRIP_MAX
		var cr := STRIP_MAX
		for gx in range(key.x - 2, key.x + 3):
			for gz in range(key.y - 2, key.y + 3):
				if not grid.has(Vector2i(gx, gz)):
					continue
				for j in (grid[Vector2i(gx, gz)] as PackedInt32Array):
					if absi(j - i) < 50:
						continue
					var dx: float = samples[j].x - p.x
					var dz: float = samples[j].z - p.z
					var D := sqrt(dx * dx + dz * dz)
					if D > 2.0 * STRIP_MAX + 20.0:
						continue
					var c := (dx * l.x + dz * l.z) / maxf(D, 0.01) # coseno con la lateral (+ = derecha)
					if absf(c) < 0.25:
						continue
					var reach := D / (2.0 * absf(c))
					if c > 0.0:
						cr = minf(cr, reach)
					else:
						cl = minf(cl, reach)
		for j in range(i, mini(n, i + 3)):
			clear_l[j] = minf(clear_l[j], cl)
			clear_r[j] = minf(clear_r[j], cr)
	# que no salte de golpe: mínimo en una ventana de ±4 muestras
	var ol := clear_l.duplicate()
	var orr := clear_r.duplicate()
	for i in n:
		for j in range(maxi(0, i - 4), mini(n, i + 5)):
			clear_l[i] = minf(clear_l[i], ol[j])
			clear_r[i] = minf(clear_r[i], orr[j])

# ───────────────────────── terreno ─────────────────────────
## Ruido suave del campo (el mismo para todas las partes de la franja: donde se superponen coinciden)
static func field_noise(x: float, z: float) -> float:
	return 0.55 * sin(x * 0.021 + z * 0.017) + 0.3 * sin(x * 0.047 - z * 0.039 + 1.3) + 0.15 * sin(x * 0.11 + z * 0.093 + 2.7)

## Forma del terreno de un ambiente a e metros pasando la banquina, del lado side (+1 derecha). Devuelve la altura sobre el camino.
func _profile(b: int, e: float, side: float, ms: float, x: float, z: float) -> float:
	match b:
		0: # ciudad: vereda alta (cordón de 15 cm) y terreno parejo
			var cu := clampf(e / 0.22, 0.0, 1.0)
			return 0.16 * cu + (0.0 if e < 30.0 else field_noise(x, z) * 0.25 * minf(1.0, (e - 30.0) / 30.0))
		1: # campo: cuneta y después los lotes, con ondulaciones suaves
			var ditch := -0.55 * sin(PI * clampf(e / 4.0, 0.0, 1.0))
			var t := clampf((e - 4.0) / 8.0, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return ditch + t * (0.25 + field_noise(x, z) * 1.1)
		2: # bosque: el camino va hundido; sube de a poco a ~0,9 m y sigue ondulado
			var t := minf(e / 16.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return t * (0.85 + field_noise(x, z) * 0.9)
		3, 6: # montaña: paredón del lado de la montaña, precipicio del otro
			var up := side * ms # > 0: lado de la montaña
			var wall_k := clampf(up * 0.5 + 0.5, 0.0, 1.0)
			var cliff := 0.0
			if e > 0.4:
				var q := e - 0.4
				cliff = minf(q * 2.4, 34.0) + maxf(0.0, q - 14.0) * 0.55 + field_noise(x, z) * 2.0 * minf(1.0, q / 6.0)
			var drop := -minf(maxf(0.0, e - 0.8) * 0.85, 75.0) + field_noise(x, z) * 1.5 * minf(1.0, e / 20.0)
			return lerpf(drop, cliff, wall_k)
		4: # cantera: terrazas de piedra (escalones de 5,5 m cada 11 m)
			var q := maxf(0.0, e - 0.6)
			var lvl := floorf(q / 11.0)
			var f := clampf((q - lvl * 11.0 - 7.5) / 3.5, 0.0, 1.0)
			return (lvl + f) * 5.5 + (0.4 * field_noise(x, z) if q > 2.0 else 0.0)
		5: # nieve: bancos de nieve del quitanieves y después lomas blancas
			var bank := 0.95 * sin(PI * 0.5 * clampf(e / 2.5, 0.0, 1.0))
			var t := clampf((e - 2.5) / 14.0, 0.0, 1.0)
			return bank + t * (0.6 + field_noise(x, z) * 1.6)
	return 0.0

## Altura del terreno a e metros pasando la banquina en la muestra i (fracción t hacia la siguiente)
func side_height(i: int, t: float, e: float, side: float, x: float, z: float) -> float:
	var j := mini(i + 1, n - 1)
	var ry: float = lerpf(cy[i], cy[j], t)
	var ms: float = lerpf(msidea[i], msidea[j], t)
	var y := 0.0
	var ws := 0.0
	for b in NB:
		var w: float = lerpf(bw[b][i], bw[b][j], t)
		if w < 0.002:
			continue
		y += w * _profile(b, e, side, ms, x, z)
		ws += w
	if ws > 0.0:
		y /= ws
	# obras especiales
	var wb: float = lerpf(w_bridge[i], w_bridge[j], t)
	if wb > 0.002:
		# el río: barranca que baja hasta el agua
		var q := clampf((e - 0.5) / 22.0, 0.0, 1.0)
		var rv := -14.0 * q * q * (3.0 - 2.0 * q) * wb
		y = lerpf(y, rv, minf(1.0, wb * 1.4))
	var wt: float = lerpf(w_tunnel[i], w_tunnel[j], t)
	if wt > 0.002:
		var q := maxf(0.0, e - 0.3)
		var mt := minf(q * 3.0, 38.0) + maxf(0.0, q - 13.0) * 0.4 + field_noise(x, z) * 2.0 * minf(1.0, q / 5.0)
		y = lerpf(y, mt, wt)
	var wu: float = lerpf(w_under[i], w_under[j], t)
	if wu > 0.002:
		var top: float = lerpf(under_top[i], under_top[j], t) - ry
		var q := clampf(e / 0.3, 0.0, 1.0)
		y = lerpf(y, maxf(0.16, top + 0.16) * q, wu)
	var wl: float = lerpf(w_lay[i], w_lay[j], t)
	if wl > 0.002 and side > 0.0:
		# alrededor de la estación y del taller: playón parejo
		var flat := 0.04 if e < 26.0 else lerpf(0.04, y, clampf((e - 26.0) / 14.0, 0.0, 1.0))
		y = lerpf(y, flat, wl)
	return ry + y

## Superficie pasando la banquina
func side_surf(i: int, e: float, side: float) -> int:
	var b := int(biomea[i])
	if (int(flaga[i]) & (AdvRoute.F_STATION | AdvRoute.F_WORKSHOP)) != 0 and side > 0.0:
		return 0
	match b:
		0: return 0 if e < 3.0 else 3
		4: return 1
		5, 6: return 6
		3:
			return 4 if side * float(msidea[i]) > 0.0 else 3
	return 3 if e < 12.0 else 4

## Altura y superficie (0 asfalto · 1 tierra · 2 banquina · 3 pasto · 4 afuera · 5 barro · 6 nieve) en un punto
func ground_info(x: float, z: float) -> Vector2:
	nearest(x, z)
	var i := r_idx
	var j := mini(i + 1, n - 1)
	var t := r_t
	var lat := r_lat
	var hw: float = lerpf(hwa[i], hwa[j], t)
	var er: float = hw + lerpf(laya[i], laya[j], t)
	if lat >= -hw and lat <= er:
		var y := r_y
		var su := int(surfa[i])
		if lat <= hw:
			y += (1.0 - pow(minf(absf(lat) / hw, 1.0), 2.0)) * 0.03
		elif su != 0:
			su = 0 # el playón de la estación es de hormigón
		return Vector2(y + _micro_bump(x, z, su if su < 6 else 1), float(su))
	var side := 1.0 if lat > 0.0 else -1.0
	var dd := (lat - er) if lat > 0.0 else (-lat - hw)
	var sh: float = lerpf(shl[i], shl[j], t)
	if dd <= sh:
		var city := float(bw[0][i])
		var yy := r_y - 0.05 * dd / maxf(sh, 0.1)
		return Vector2(yy + _micro_bump(x, z, 2), 2.0 if city < 0.5 else 0.0)
	var e := dd - sh
	var s2 := side_surf(i, e, side)
	return Vector2(side_height(i, t, e, side, x, z) + _micro_bump(x, z, mini(s2, 5)), float(s2))

func ground_smooth(x: float, z: float) -> float:
	nearest(x, z)
	var i := r_idx
	var j := mini(i + 1, n - 1)
	var t := r_t
	var lat := r_lat
	var hw: float = lerpf(hwa[i], hwa[j], t)
	var er: float = hw + lerpf(laya[i], laya[j], t)
	if lat >= -hw and lat <= er:
		if lat <= hw:
			return r_y + (1.0 - pow(minf(absf(lat) / hw, 1.0), 2.0)) * 0.03
		return r_y
	var side := 1.0 if lat > 0.0 else -1.0
	var dd := (lat - er) if lat > 0.0 else (-lat - hw)
	var sh: float = lerpf(shl[i], shl[j], t)
	if dd <= sh:
		return r_y - 0.05 * dd / maxf(sh, 0.1)
	return side_height(i, t, dd - sh, side, x, z)

## Pose sobre el camino: muestra i, a lat metros del centro (+ derecha), mirando hacia adelante. Devuelve [x, z, yaw]
func pose_at(i: int, lat: float) -> Array:
	i = clampi(i, 0, n - 2)
	var p := samples[i]
	var l := laterals[i]
	var tg := tangents[i]
	return [p.x + l.x * lat, p.z + l.z * lat, atan2(tg.x, tg.z)]

## Índice de la muestra a s metros (distancia acumulada)
func idx_at(s: float) -> int:
	var lo := 0
	var hi := n - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if cum[mid] < s:
			lo = mid + 1
		else:
			hi = mid
	return lo

## ¿La muestra está dentro de un túnel?
func in_tunnel(i: int) -> bool:
	return (int(flaga[clampi(i, 0, n - 1)]) & AdvRoute.F_TUNNEL) != 0

## Bifurcación: el terreno de cada camino no puede tapar al otro. Recorta lo que se dibuja de cada lado usando las muestras
## del otro camino que ya se separaron (las que siguen pegadas al camino propio no cuentan).
func cross_clear(o) -> void:
	if zone.x < 0:
		return
	var a := maxi(0, zone.x)
	var b := mini(n - 1, zone.y)
	var oa := maxi(0, int(o.zone.x))
	var ob := mini(int(o.n) - 1, int(o.zone.y))
	for i in range(a, b + 1):
		var p := samples[i]
		var l := laterals[i]
		var cl: float = clear_l[i]
		var cr: float = clear_r[i]
		for j in range(oa, ob + 1, 2):
			var q: Vector3 = o.samples[j]
			var dx := q.x - p.x
			var dz := q.z - p.z
			var D := sqrt(dx * dx + dz * dz)
			if D > 2.0 * STRIP_MAX + 20.0:
				continue
			var near: float = float(hwa[i]) + float(o.hwa[j]) + 3.0
			# la muestra del otro camino todavía está sobre este camino (cerca de donde se separan)
			var along := absf(dx * tangents[i].x + dz * tangents[i].z)
			var c := (dx * l.x + dz * l.z) / maxf(D, 0.01)
			var lat_o := absf(dx * l.x + dz * l.z)
			if lat_o < near and along < 30.0:
				continue
			if absf(c) < 0.25:
				continue
			var reach := maxf(float(hwa[i]) + float(shl[i]) + 0.5, D / (2.0 * absf(c)))
			if c > 0.0:
				cr = minf(cr, reach)
			else:
				cl = minf(cl, reach)
		clear_l[i] = cl
		clear_r[i] = cr
