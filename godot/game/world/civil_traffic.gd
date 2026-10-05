extends "res://game/world/world_life_system.gd"
## Tránsito civil CINEMÁTICO y determinista (Etapa 9). Los autos NO usan la física del juego: cada uno sigue los carriles del grafo de tránsito (traffic_graph.gd) con un modelo
## de velocidad sencillo (crucero por tipo de calle, frenar ante el semáforo en rojo —estado puro de la hora del mundo, traffic_signals.gd— y ante el auto de adelante).
## - Reconstrucción: un sector que pasa a estar cerca del jugador se llena con autos que salen de WORLD_SEED + sector + número de auto + «bloque» de 60 s del mundo: se parte del
##   estado inicial del bloque y se avanza (a pasos fijos de 0,5 s) hasta ahora. Dos teléfonos con la misma semilla y hora reconstruyen los mismos autos en los mismos lugares.
##   Después cada auto sigue andando de forma continua (no vuelve a saltar): la diferencia entre teléfonos sólo puede acumularse con el tiempo, nunca se ve un salto.
## - Costo: un MultiMesh (una llamada de dibujo) y unos pocos cálculos por auto. Tope por perfil: LOW 10–12 · MEDIUM 20–24 · HIGH 30–36 (reglas en world_life.json).
##   Los autos lejanos (sector simplificado) se calculan a menos frecuencia. Con World Life en OFF no queda ninguno.
## - Cada auto es un círculo-doble de choque sólido para el jugador (CityTrack.set_dynamic_circles). La reacción al golpe (física temporal) es la Etapa 11.

const WorldSeed := preload("res://game/world/world_seed.gd")
const CityProps := preload("res://game/city/city_props.gd")
const TrafficSignals := preload("res://game/world/traffic_signals.gd")
const TrafficRoutine := preload("res://game/world/traffic_routine.gd")

const BLOCK := 60.0 # segundos del mundo por bloque de reconstrucción
const FF_STEP := 0.5 # paso fijo de la reconstrucción
const CAR_LEN := 4.6
const MIN_GAP := 2.5
const STOP_BEFORE := 8.0 # frena a esta distancia del final del carril si hay semáforo (no tapa el cruce)
const DECEL := 3.8
const ACCEL := 2.4
const SPAWN_SAFE := 95.0 # los autos que se agregan «de a uno» nacen al menos a esta distancia del jugador
const KIND_SPEED := {"plaza": 7.0, "ring": 9.5, "minor": 9.0, "major": 13.5, "coast": 12.0, "rural": 17.0, "shortcut": 13.0, "hill": 9.0}
const DENSITY_M := 240.0 # un auto cada tanto de carril (en el centro)

class Veh:
	extends RefCounted
	var id := 0
	var home := Vector2i.ZERO
	var lane := 0
	var d := 0.0
	var v := 0.0
	var next := -1 # carril al que sigue (elegido al entrar al carril actual)
	var conn := -1.0 # >= 0: recorriendo el empalme entre dos carriles (metros)
	var clen := 0.0
	var hop := 0
	var cruise := 9.0
	var color := Color.WHITE
	var variant := 0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var acc := 0.0 # tiempo acumulado (autos lejanos: se calculan por tandas)

var layout: RefCounted
var graph: RefCounted
var signals: RefCounted
var track: RefCounted
var root: Node3D
var vehicles: Array = [] # Veh
var _filled: Dictionary = {} # Vector2i → true (sectores ya llenados)
var _seq: Dictionary = {} # Vector2i → cantidad de autos «de repuesto» ya nacidos
var _len_cache: Dictionary = {}
var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _mesh: ArrayMesh
var _cap := 24 # tope del perfil
var _topup_t := 0.0
var _next_id := 0
var _t_now := 0.0 # hora del mundo del cálculo en curso (para las rutinas)

func _init() -> void:
	system_id = "traffic"
	update_hz = 20.0

func attach(p_layout: RefCounted, p_track: RefCounted, p_root: Node3D) -> void:
	layout = p_layout
	graph = p_layout.traffic()
	signals = p_layout.traffic_signals()
	track = p_track
	root = p_root

func enable() -> void:
	pass

func disable() -> void:
	vehicles.clear()
	_filled.clear()
	_seq.clear()
	_len_cache.clear()
	if is_instance_valid(_mmi):
		_mmi.queue_free()
	_mmi = null
	_mm = null
	if track != null and track.has_method("set_dynamic_circles"):
		track.set_dynamic_circles(PackedFloat32Array())

func rebuild() -> void:
	disable()
	on_sector_changed()

func seed_v() -> int:
	return wl.state.system_seed("traffic")

func now() -> float:
	return wl.clock.now()

## Hora (0–24) y fin de semana para un instante t del mundo
func _hour_of(t: float) -> float:
	return fposmod(t / float(wl.clock.day_seconds), 1.0) * 24.0

func _weekend_of(t: float) -> bool:
	return TrafficRoutine.is_weekend(int(floor(t / float(wl.clock.day_seconds))))

func routine_density(t: float) -> float:
	return TrafficRoutine.density(_hour_of(t), _weekend_of(t))

# ───────────────────────── reglas de movimiento (puras) ─────────────────────────
func _lane_cruise(li: int) -> float:
	return float(KIND_SPEED.get(str(graph.lanes[li]["kind"]), 9.0))

func _choose_next(v: Veh) -> void:
	var nx: Array = graph.lanes[v.lane]["next"]
	if nx.is_empty():
		v.next = -1
		return
	if nx.size() == 1:
		v.next = int(nx[0])
		return
	# rutina: a la mañana se prefiere ir hacia el centro, a la tarde salir (peso por cuánto apunta el carril hacia/desde el centro)
	var bias := TrafficRoutine.inward_bias(_hour_of(_t_now), _weekend_of(_t_now))
	var ws: Array = []
	var tot := 0.0
	for li in nx:
		var h: Vector2 = graph.lane_at(int(li), 0.0)["tan"]
		var p: Vector3 = graph.lane_at(int(li), 0.0)["pos"]
		var to_c := Vector2(-p.x, -p.z).normalized()
		var w := clampf(1.0 + bias * 0.9 * h.dot(to_c), 0.15, 2.0)
		ws.append(w)
		tot += w
	var pick := WorldSeed.unit(seed_v(), v.id, v.hop, 77) * tot
	v.next = int(nx[nx.size() - 1])
	for i in nx.size():
		if pick <= float(ws[i]):
			v.next = int(nx[i])
			break
		pick -= float(ws[i])

## (velocidad objetivo, tope duro de velocidad): el tope hace que el auto SIEMPRE pueda frenar antes del semáforo en rojo o del auto de adelante
func _target_speed(v: Veh, t: float, gap_ahead: float, v_ahead: float) -> Vector2:
	var vt := _lane_cruise(v.lane) * v.cruise / 9.0 * TrafficRoutine.speed_factor(_hour_of(t)) # crucero de la calle × carácter del conductor × hora del día
	var vcap := 1e9
	if v.conn >= 0.0:
		return Vector2(minf(vt, 6.5), 1e9) # en el cruce, más despacio (las curvas)
	var remaining := float(graph.lanes[v.lane]["len"]) - v.d
	# semáforo al final del carril
	if signals.is_signalized(int(graph.lanes[v.lane]["b"])) and remaining > 1.0:
		var st: int = signals.lane_state(v.lane, t)
		if st != TrafficSignals.GO:
			var stop_at := minf(STOP_BEFORE, float(graph.lanes[v.lane]["len"]) * 0.4) # en tramos cortos el punto de frenado se acerca
			var dist := remaining - stop_at
			var can_stop := v.v * v.v / (2.0 * DECEL) <= maxf(dist, 0.0) + 0.8
			if st == TrafficSignals.RED or can_stop:
				if dist >= -0.5:
					vcap = sqrt(2.0 * DECEL * maxf(dist, 0.0))
				else:
					vcap = sqrt(2.0 * DECEL * 1.6 * maxf(remaining - 1.0, 0.0)) # ya pasó la marca: frena lo que pueda antes de la línea
				vt = minf(vt, vcap)
	# auto de adelante
	if gap_ahead < 1e8:
		var room := maxf(gap_ahead - MIN_GAP, 0.0)
		var lc := v_ahead + sqrt(2.0 * DECEL * room)
		vcap = minf(vcap, lc)
		vt = minf(vt, lc)
	return Vector2(vt, vcap)

## Avanza un auto dt segundos. gap_ahead / v_ahead: distancia libre al auto de adelante (1e9 si no hay) y su velocidad.
func _advance(v: Veh, dt: float, t: float, gap_ahead: float, v_ahead: float) -> bool:
	var tv := _target_speed(v, t, gap_ahead, v_ahead)
	var a := clampf((tv.x - v.v) / 0.7, -DECEL * 1.6, ACCEL)
	v.v = minf(maxf(v.v + a * dt, 0.0), tv.y)
	if v.conn >= 0.0:
		v.conn += v.v * dt
		if v.conn >= v.clen:
			v.d = v.conn - v.clen
			v.lane = v.next
			v.conn = -1.0
			v.hop += 1
			_choose_next(v)
			if v.next < 0:
				return false
	else:
		v.d += v.v * dt
		var len_: float = float(graph.lanes[v.lane]["len"])
		if v.d >= len_:
			if v.next < 0:
				return false # carril sin salida (no debería pasar)
			var p0: Vector3 = graph.lane_at(v.lane, len_)["pos"]
			var p2: Vector3 = graph.lane_at(v.next, 0.0)["pos"]
			v.conn = v.d - len_
			v.clen = maxf(Vector2(p0.x - p2.x, p0.z - p2.z).length() * 1.05, 1.0)
			v.d = len_
			if v.conn >= v.clen:
				v.d = v.conn - v.clen
				v.lane = v.next
				v.conn = -1.0
				v.hop += 1
				_choose_next(v)
	return true

## Posición y rumbo del auto (en el carril o recorriendo el empalme con una curva suave)
func _place(v: Veh) -> void:
	if v.conn < 0.0:
		var c: Dictionary = graph.lane_at(v.lane, v.d)
		v.pos = c["pos"]
		v.yaw = c["yaw"]
		var c2: Dictionary = graph.lane_at(v.lane, v.d + 2.0)
		var dy := float((c2["pos"] as Vector3).y) - v.pos.y
		var dd := maxf(Vector2((c2["pos"] as Vector3).x - v.pos.x, (c2["pos"] as Vector3).z - v.pos.z).length(), 0.1)
		v.pitch = -atan2(dy, dd)
		return
	var la: Dictionary = graph.lane_at(v.lane, float(graph.lanes[v.lane]["len"]))
	var lb: Dictionary = graph.lane_at(v.next, 0.0)
	var u := clampf(v.conn / v.clen, 0.0, 1.0)
	var p0: Vector3 = la["pos"]
	var p1: Vector3 = lb["pos"]
	var m0: Vector2 = (la["tan"] as Vector2) * v.clen
	var m1: Vector2 = (lb["tan"] as Vector2) * v.clen
	var u2 := u * u
	var u3 := u2 * u
	var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
	var h10 := u3 - 2.0 * u2 + u
	var h01 := -2.0 * u3 + 3.0 * u2
	var h11 := u3 - u2
	var x := h00 * p0.x + h10 * m0.x + h01 * p1.x + h11 * m1.x
	var z := h00 * p0.z + h10 * m0.y + h01 * p1.z + h11 * m1.y
	var dx := (6.0 * u2 - 6.0 * u) * p0.x + (3.0 * u2 - 4.0 * u + 1.0) * m0.x + (-6.0 * u2 + 6.0 * u) * p1.x + (3.0 * u2 - 2.0 * u) * m1.x
	var dz := (6.0 * u2 - 6.0 * u) * p0.z + (3.0 * u2 - 4.0 * u + 1.0) * m0.y + (-6.0 * u2 + 6.0 * u) * p1.z + (3.0 * u2 - 2.0 * u) * m1.y
	v.pos = Vector3(x, lerpf(p0.y, p1.y, u), z)
	v.yaw = atan2(dx, dz)
	v.pitch = 0.0

# ───────────────────────── reconstrucción ─────────────────────────
func _sector_lanes(cell: Vector2i) -> Array:
	if _len_cache.has(cell):
		return _len_cache[cell]
	var out: Array = []
	for li in graph.lanes_in_cell(cell):
		var L: Dictionary = graph.lanes[li]
		if not KIND_SPEED.has(str(L["kind"])):
			continue
		var m: Vector3 = graph.lane_at(int(li), float(L["len"]) * 0.5)["pos"]
		if Vector2i(int(floor(m.x / graph.CELL)), int(floor(m.z / graph.CELL))) == cell:
			out.append([int(li), float(L["len"])])
	_len_cache[cell] = out
	return out

func sector_target(cell: Vector2i) -> int:
	var total := 0.0
	for e in _sector_lanes(cell):
		total += float(e[1])
	var c: Vector2 = wl.sectors.sector_center(cell)
	var zone: int = layout.zone_of(c.x, c.y)
	var dens := DENSITY_M * (1.0 if zone <= 1 else 1.8)
	return clampi(int(round(total / dens * routine_density(_t_now))), 0, 6)

## El auto número i (de «semilla de aparición» key) de un sector, en el estado del comienzo del bloque
func _make(cell: Vector2i, key: int, t: float) -> Veh:
	var lanes_here := _sector_lanes(cell)
	if lanes_here.is_empty():
		return null
	var total := 0.0
	for e in lanes_here:
		total += float(e[1])
	var sd := seed_v()
	var pick := WorldSeed.unit(sd, cell.x, cell.y, key, 1) * total
	var li: int = int(lanes_here[0][0])
	var d0 := 0.0
	var acc := 0.0
	for e in lanes_here:
		if pick <= acc + float(e[1]):
			li = int(e[0])
			d0 = pick - acc
			break
		acc += float(e[1])
	var v := Veh.new()
	v.id = WorldSeed.hash_ints(sd, cell.x, cell.y, key, 2) & 0x3FFFFFFF
	v.home = cell
	v.lane = li
	v.d = clampf(d0, 0.0, float(graph.lanes[li]["len"]) - 1.0)
	v.cruise = 9.0 * (0.85 + 0.25 * WorldSeed.unit(sd, v.id, 3))
	v.v = _lane_cruise(li) * 0.7
	v.variant = WorldSeed.range_i(sd, 0, 2, v.id, 4)
	var ci := WorldSeed.range_i(sd, 0, 9, v.id, 5)
	if ci < 3:
		v.color = [Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.13), Color(0.55, 0.57, 0.6)][ci]
	else:
		var h := WorldSeed.unit(sd, v.id, 6)
		v.color = Color.from_hsv(h, 0.55 + 0.25 * WorldSeed.unit(sd, v.id, 7), 0.6 + 0.3 * WorldSeed.unit(sd, v.id, 8))
	_choose_next(v)
	# avanza desde el comienzo del bloque hasta ahora (sin autos de adelante: sólo semáforos)
	var t0: float = floorf(t / BLOCK) * BLOCK
	var tt: float = t0
	_t_now = t0
	while tt < t - 0.001:
		_t_now = tt
		var step: float = minf(FF_STEP, t - tt)
		if not _advance(v, step, tt, 1e9, 0.0):
			return null
		tt += step
	_place(v)
	return v

## Autos que le tocan a un sector en el instante t (sin instanciar nada): sirve para comprobar el determinismo
func reconstruct_sector(cell: Vector2i, t: float) -> Array:
	var out: Array = []
	for i in sector_target(cell):
		var v := _make(cell, i, t)
		if v != null:
			out.append(v)
	return out

func logical_hash() -> int:
	var h := 29
	var secs: Array = []
	for s in wl.sectors.active:
		secs.append(s)
	secs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var t := now()
	for s in secs:
		for v in reconstruct_sector(s, t):
			h = WorldSeed.combine(h, v.id)
			h = WorldSeed.combine(h, v.lane)
			h = WorldSeed.combine(h, roundi(v.d * 10.0))
	return h

# ───────────────────────── vida ─────────────────────────
func on_sector_changed() -> void:
	if wl == null or not wl.state.enabled or root == null or not is_instance_valid(root):
		return
	_cap = int(wl.state.rules.get("max_active_vehicles", 24))
	_ensure_render()
	var near: Dictionary = {}
	for s in wl.sectors.active:
		near[s] = true
	for s in wl.sectors.simplified:
		near[s] = true
	# sectores que se alejaron: se sueltan sus «llenados» (al volver se reconstruyen)
	for k in _filled.keys():
		if not near.has(k):
			_filled.erase(k)
			_seq.erase(k)
	# llena los nuevos, del más cercano al más lejano, respetando el tope
	var order: Array = near.keys()
	var pl: Vector2 = wl.sectors.player
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return wl.sectors.sector_center(a).distance_squared_to(pl) < wl.sectors.sector_center(b).distance_squared_to(pl))
	var t := now()
	for s in order:
		if _filled.has(s):
			continue
		_filled[s] = true
		for v in reconstruct_sector(s, t):
			if vehicles.size() >= cap_now(t):
				break
			if _spot_free(v):
				vehicles.append(v)
	_refresh_all()

func _ensure_render() -> void:
	if _mm != null:
		return
	_mesh = _build_mesh()
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = _mesh
	_mm.instance_count = 48 # tope máximo (HIGH 36 + margen); se muestran sólo los que existen
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "CivilTraffic"
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.extra_cull_margin = 400.0
	root.add_child(_mmi)

func _build_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var xf := Transform3D.IDENTITY
	CityProps.box(v, c, xf, Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), Color(1, 1, 1))
	CityProps.box(v, c, xf, Vector3(0, 1.1, -0.2), Vector3(1.55, 0.5, 2.3), Color(0.18, 0.24, 0.32))
	CityProps.box(v, c, xf, Vector3(0, 1.38, -0.2), Vector3(1.5, 0.08, 2.1), Color(0.85, 0.85, 0.85))
	for wx in [-0.92, 0.92]:
		for wz in [-1.4, 1.4]:
			CityProps.box(v, c, xf, Vector3(float(wx), 0.32, float(wz)), Vector3(0.22, 0.64, 0.64), Color(0.10, 0.10, 0.12))
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.2
	m.surface_set_material(0, mat)
	return m

func update(dt: float) -> void:
	if wl == null or not wl.state.enabled or _mm == null:
		return
	var t := now()
	_t_now = t
	var pl: Vector2 = wl.sectors.player
	var r_act: float = wl.sectors.r_active
	var r_drop: float = wl.sectors.r_simplified * 1.2
	# autos por carril, ordenados por distancia, para el de adelante
	var occ: Dictionary = {}
	for v in vehicles:
		if v.conn < 0.0:
			if not occ.has(v.lane):
				occ[v.lane] = []
			(occ[v.lane] as Array).append(v)
	for k in occ:
		(occ[k] as Array).sort_custom(func(a: Veh, b: Veh) -> bool: return a.d < b.d)
	var dead: Array = []
	for v in vehicles:
		var far := Vector2(v.pos.x, v.pos.z).distance_to(pl) > r_act
		v.acc += dt
		if far and v.acc < 0.25:
			continue
		var step: float = v.acc
		v.acc = 0.0
		var ga := 1e9
		var va := 0.0
		if v.conn >= 0.0 and v.next >= 0:
			# recorriendo el cruce: el de adelante es el que va primero hacia el mismo carril (o el último del carril de destino)
			var rem: float = v.clen - v.conn
			for o3 in vehicles:
				if o3 != v and o3.conn >= 0.0 and o3.next == v.next:
					var rem3: float = o3.clen - o3.conn
					if rem3 < rem and rem - rem3 - CAR_LEN < ga:
						ga = rem - rem3 - CAR_LEN
						va = o3.v
			if occ.has(v.next):
				var f: Veh = (occ[v.next] as Array)[0]
				if rem + f.d - CAR_LEN < ga:
					ga = rem + f.d - CAR_LEN
					va = f.v
		if v.conn < 0.0:
			var here: Array = occ.get(v.lane, [])
			for o in here:
				if o != v and o.d > v.d:
					ga = o.d - v.d - CAR_LEN
					va = o.v
					break
			if ga >= 1e8 and v.next >= 0 and occ.has(v.next):
				var o2: Veh = (occ[v.next] as Array)[0]
				ga = (float(graph.lanes[v.lane]["len"]) - v.d) + o2.d - CAR_LEN
				va = o2.v
		if not _advance(v, step, t, ga, va):
			dead.append(v)
			continue
		_place(v)
		if Vector2(v.pos.x, v.pos.z).distance_to(pl) > r_drop:
			dead.append(v)
	for v in dead:
		vehicles.erase(v)
	# repuestos: los sectores cercanos que quedaron con pocos autos reciben uno nuevo lejos de la vista del jugador
	_topup_t -= dt
	if _topup_t <= 0.0:
		_topup_t = 1.0
		_top_up(t, pl)
	_refresh_all()

## Tope de autos según la hora: de madrugada circulan muchos menos (nunca más que el tope del perfil)
func cap_now(t: float) -> int:
	return clampi(int(round(float(_cap) * clampf(routine_density(t) / 1.0, 0.3, 1.0))), 2, _cap)

func _top_up(t: float, pl: Vector2) -> void:
	var cn := cap_now(t)
	if vehicles.size() > cn + 1:
		# sobran autos para esta hora: se retira el más lejano que no esté a la vista
		var worst: Veh = null
		var wd := SPAWN_SAFE
		for v in vehicles:
			var dd := Vector2(v.pos.x, v.pos.z).distance_to(pl)
			if dd > wd:
				wd = dd
				worst = v
		if worst != null:
			vehicles.erase(worst)
		return
	if vehicles.size() >= cn:
		return
	var counts: Dictionary = {}
	for v in vehicles:
		var k := Vector2i(int(floor(v.pos.x / graph.CELL)), int(floor(v.pos.z / graph.CELL)))
		counts[k] = int(counts.get(k, 0)) + 1
	var spawned := 0
	for s in _filled.keys():
		var want := sector_target(s)
		if int(counts.get(s, 0)) >= maxi(want - 1, 1) or want == 0:
			continue
		var seq := int(_seq.get(s, 0))
		_seq[s] = seq + 1
		var v := _make(s, 1000 + seq, t)
		if v == null:
			continue
		if Vector2(v.pos.x, v.pos.z).distance_to(pl) < SPAWN_SAFE:
			continue
		if not _spot_free(v):
			continue
		vehicles.append(v)
		spawned += 1
		if spawned >= 2 or vehicles.size() >= cn:
			break

## ¿Hay lugar para un auto nuevo (ningún otro a menos de 9 m en el mismo carril)?
func _spot_free(nv: Veh) -> bool:
	for o in vehicles:
		if o.lane == nv.lane and o.conn < 0.0 and absf(o.d - nv.d) < 9.0:
			return false
		if o.conn >= 0.0 and Vector2(o.pos.x - nv.pos.x, o.pos.z - nv.pos.z).length() < 9.0:
			return false
	return true

func _refresh_all() -> void:
	if _mm == null:
		return
	var n := mini(vehicles.size(), _mm.instance_count)
	_mm.visible_instance_count = n
	var circles := PackedFloat32Array()
	for i in n:
		var v: Veh = vehicles[i]
		var sc := Vector3(1.0, 1.0, 1.0)
		match v.variant:
			1: sc = Vector3(1.0, 1.0, 0.9)
			2: sc = Vector3(1.1, 1.22, 1.12)
		var b := Basis(Vector3.UP, v.yaw) * Basis(Vector3.RIGHT, v.pitch) * Basis.from_scale(sc)
		_mm.set_instance_transform(i, Transform3D(b, v.pos))
		_mm.set_instance_color(i, v.color)
		var fwd := Vector2(sin(v.yaw), cos(v.yaw))
		for sg in [-1.0, 1.0]:
			circles.append(v.pos.x + fwd.x * float(sg) * 1.2 * sc.z)
			circles.append(v.pos.z + fwd.y * float(sg) * 1.2 * sc.z)
			circles.append(1.05)
	if track != null and track.has_method("set_dynamic_circles"):
		track.set_dynamic_circles(circles)

func stats() -> Dictionary:
	var spd := 0.0
	for v in vehicles:
		spd += v.v
	return {"cars": vehicles.size(), "cap": _cap, "sectors": _filled.size(), "avg_speed": spd / maxf(float(vehicles.size()), 1.0)}
