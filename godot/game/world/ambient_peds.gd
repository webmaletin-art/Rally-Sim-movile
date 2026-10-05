extends "res://game/world/world_life_system.gd"
## Peatones ambientales 2.5D (Etapa 21): figuras de papel (tarjetas que miran a la cámara) que caminan por las veredas de las calles de la ciudad.
## DETERMINISTAS y sin estado: cada tramo de vereda (SLOT m) tiene a lo sumo un peatón que va y viene entre dos puntos; si existe, su color, velocidad y fase salen de WORLD_SEED + calle + tramo,
## y dónde está en este instante es una función PURA de la hora del mundo (ida y vuelta). Todos los jugadores ven a la misma gente en el mismo lugar.
## Cuántos hay depende de la hora (poca gente de madrugada, más a la mañana, al mediodía y a la tarde) y del clima (con lluvia casi nadie, y los que hay llevan paraguas).
## Un solo MultiMesh (una llamada de dibujo) con tope por perfil (max_pedestrians) sólo de los sectores activos. El auto del jugador los asusta (se hacen atrás) y, si los toca, quedan
## acostados un rato (dibujito de papel, sin violencia) y se levantan. Eso es sólo local: no se comparte ni se guarda.

const WorldSeed := preload("res://game/world/world_seed.gd")
const WorldWeather := preload("res://game/world/world_weather.gd")
const TrafficRoutine := preload("res://game/world/traffic_routine.gd")
const SHADER := preload("res://game/fx/city_peds.gdshader")

const SLOT := 26.0 # largo de un tramo de vereda (m)
const MARGIN := 9.0 # distancia al cruce
const WALK_KINDS := ["minor", "ring", "major", "coast"]
const MIN_SW := 2.0
const FILL := 0.55 # fracción de tramos con peatón a la hora de más gente
const SHOW_R := 120.0 # más lejos que esto no se dibuja
const H := 1.75 # alto de la figura (m)
const W := 0.9

var layout: RefCounted
var graph: RefCounted
var track: RefCounted
var root: Node3D
var player_vel := Vector2.ZERO # la pone race.gd (para asustarlos y atropellos suaves)
var night := 0.0 # la pone race.gd (de noche se ven más oscuros)
var weather_on := true # opción «Clima del mundo» (race.gd): apagada, no se ahuyentan con la lluvia
var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _mat: ShaderMaterial
var _slot_cache: Dictionary = {} # Vector2i → [peatones del sector]
var _chosen: Array = [] # peatones que se dibujan ahora (ya filtrados por tope y distancia)
var _pool: Array = [] # todos los de los sectores activos
var _cap := 32
var _fade: Dictionary = {} # key → 0..1 (aparecen/desaparecen creciendo)
var _hit: Dictionary = {} # key → segundos que le quedan tirado
var _scare: Dictionary = {} # key → 0..1 cuánto se hizo atrás
var _hour_i := -1
var _present_now: Dictionary = {}

func _init() -> void:
	system_id = "peds"
	update_hz = 20.0

func attach(p_layout: RefCounted, p_track: RefCounted, p_root: Node3D) -> void:
	layout = p_layout
	graph = p_layout.traffic()
	track = p_track
	root = p_root

func enable() -> void:
	if root != null and not is_instance_valid(root):
		root = null

func disable() -> void:
	if _mmi != null and is_instance_valid(_mmi):
		_mmi.queue_free()
	_mmi = null
	_mm = null
	_slot_cache.clear()
	_pool.clear()
	_chosen.clear()
	_fade.clear()

func rebuild() -> void:
	disable()
	on_sector_changed()

func seed_v() -> int:
	return wl.state.system_seed("peds")

# ───────────────────────── lógica pura ─────────────────────────
## Cuánta gente hay en la calle (0..1.2): de día, con picos a la mañana, al mediodía y a la tarde; la lluvia la ahuyenta
static func density(hour: float, weekend: bool, rain: float) -> float:
	var h := fposmod(hour, 24.0)
	var day := smoothstep(5.5, 8.5, h) * smoothstep(23.5, 20.0, h)
	var bump := 0.0
	for c in [[8.3, 1.6, 0.35], [13.0, 2.0, 0.30], [18.4, 2.0, 0.45]]:
		bump += float(c[2]) * clampf(1.0 - absf(h - float(c[0])) / float(c[1]), 0.0, 1.0)
	var d := 0.12 + 0.55 * day + (0.5 if not weekend else 0.35) * bump
	if weekend:
		d += 0.25 * clampf(1.0 - absf(h - 16.0) / 4.0, 0.0, 1.0) * day
	return clampf(d * (1.0 - 0.85 * clampf(rain, 0.0, 1.0)), 0.0, 1.2)

## ¿Este tramo tiene peatón a esa hora? (los de menos gente son un subconjunto de los de más gente)
static func present(key: int, dens: float) -> bool:
	return float(key & 0xFFFF) / 65536.0 < FILL * dens

## Posición a lo largo del tramo (0..1) en el instante t: ida y vuelta con rapidez v (m/s) sobre un tramo de largo len
static func along(phase: float, v: float, len_: float, t: float) -> float:
	var u := fposmod(phase + v * t / maxf(len_, 1.0), 2.0)
	return u if u <= 1.0 else 2.0 - u

## Si va hacia el final del tramo (+1) o hacia el principio (−1)
static func heading(phase: float, v: float, len_: float, t: float) -> float:
	var u := fposmod(phase + v * t / maxf(len_, 1.0), 2.0)
	return 1.0 if u <= 1.0 else -1.0

## Todos los tramos con peatón de un sector (los mismos siempre): [{a: Vector3, b: Vector3, key, phase, v, hue, var}]
func slots_in_sector(cell: Vector2i) -> Array:
	var out: Array = []
	var sd := seed_v()
	var cs: float = graph.CELL
	for li in graph.lanes_in_cell(cell):
		var L: Dictionary = graph.lanes[li]
		var rd: Dictionary = layout.roads[int(L["road"])]
		if not WALK_KINDS.has(str(L["kind"])) or float(rd["sw"]) < MIN_SW:
			continue
		var len_: float = float(L["len"])
		var i := 0
		var d := MARGIN
		while d + SLOT <= len_ - MARGIN:
			var key := WorldSeed.hash_ints(sd, int(L["road"]), roundi(float(L["s0"]) * 2.0) * 2 + (0 if int(L["dir"]) == 1 else 1), i, 77)
			i += 1
			var d0 := d
			d += SLOT
			var ca: Dictionary = graph.lane_at(int(li), d0)
			var cb: Dictionary = graph.lane_at(int(li), d0 + SLOT * 0.9)
			var pa: Vector3 = ca["pos"]
			var pb: Vector3 = cb["pos"]
			var ta: Vector2 = ca["tan"]
			var tb: Vector2 = cb["tan"]
			var push := float(L["hw"]) + float(rd["sw"]) * 0.55 - float(L["off"]) # del centro del carril a la mitad de la vereda (a la derecha del sentido de la marcha)
			var a := Vector3(pa.x - ta.y * push, pa.y + 0.16, pa.z + ta.x * push)
			var b := Vector3(pb.x - tb.y * push, pb.y + 0.16, pb.z + tb.x * push)
			if Vector2i(int(floor(a.x / cs)), int(floor(a.z / cs))) != cell:
				continue
			var k2 := WorldSeed.mix32(key)
			out.append({"a": a, "b": b, "len": a.distance_to(b), "key": key, "phase": float((k2 >> 3) & 0xFFFF) / 32768.0, "v": 0.9 + float((k2 >> 18) & 0xFF) / 255.0 * 0.8,
				"hue": float((k2 >> 8) & 0xFFF) / 4096.0, "var": (k2 >> 20) % 8})
	return out

func logical_hash() -> int:
	var h := 29
	var secs: Array = []
	for s in wl.sectors.active:
		secs.append(s)
	secs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var dens := _density_now()
	for s in secs:
		for p in slots_in_sector(s):
			if present(int(p["key"]), dens):
				h = WorldSeed.combine(h, int(p["key"]))
	return h

func _density_now() -> float:
	var t: float = wl.clock.now()
	var hour := fposmod(t / float(wl.clock.day_seconds), 1.0) * 24.0
	var wk := TrafficRoutine.is_weekend(int(floor(t / float(wl.clock.day_seconds))))
	var rn: float = float(WorldWeather.at(int(wl.state.world_seed), t)["rain"]) if weather_on else 0.0
	return density(hour, wk, rn)

# ───────────────────────── instancias ─────────────────────────
func on_sector_changed() -> void:
	if root == null or not is_instance_valid(root) or wl == null or not wl.state.enabled:
		return
	_cap = int(wl.state.rules.get("max_pedestrians", 32))
	_pool.clear()
	for s in wl.sectors.active:
		var list: Array = _slot_cache.get(s, [])
		if not _slot_cache.has(s):
			list = slots_in_sector(s)
			_slot_cache[s] = list
		_pool.append_array(list)
	if _slot_cache.size() > 120:
		_slot_cache.clear()
	_ensure_mm()

func _ensure_mm() -> void:
	if _cap <= 0:
		if _mmi != null:
			_mmi.visible = false
		return
	if _mmi != null and is_instance_valid(_mmi) and _mm.instance_count == _cap:
		return
	if _mmi != null and is_instance_valid(_mmi):
		_mmi.queue_free()
	var q := QuadMesh.new()
	q.size = Vector2(W, H)
	q.center_offset = Vector3(0, H * 0.5, 0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = _cap
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.extra_cull_margin = 60.0
	root.add_child(_mmi)

func update(dt: float) -> void:
	if _mm == null or _cap <= 0 or wl == null or not wl.state.enabled:
		return
	var t: float = wl.clock.now()
	var dens := _density_now()
	var pl: Vector2 = wl.sectors.player
	var spd := player_vel.length()
	var rain: float = float(WorldWeather.at(int(wl.state.world_seed), t)["rain"]) if weather_on else 0.0
	_mat.set_shader_parameter("light", lerpf(1.0, 0.4, clampf(night, 0.0, 1.0)))
	_mat.set_shader_parameter("rainy", rain)
	# los que están presentes y cerca (los más cercanos primero, con tope)
	var cand: Array = []
	var pl3 := Vector3(pl.x, 0.0, pl.y)
	for p in _pool:
		if not present(int(p["key"]), dens):
			continue
		var u := along(float(p["phase"]), float(p["v"]), float(p["len"]), t)
		var pos: Vector3 = (p["a"] as Vector3).lerp(p["b"] as Vector3, u)
		var dd := Vector2(pos.x - pl.x, pos.z - pl.y).length()
		if dd < SHOW_R:
			cand.append([dd, p, pos, u])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var n := mini(cand.size(), _cap)
	var seen: Dictionary = {}
	for i in n:
		var e: Array = cand[i]
		var p: Dictionary = e[1]
		var key := int(p["key"])
		seen[key] = true
		var pos: Vector3 = e[2]
		var dd: float = e[0]
		# aparecer / desaparecer creciendo
		var fade := minf(1.0, float(_fade.get(key, 0.0)) + dt * 2.5)
		_fade[key] = fade
		# el auto del jugador: se hacen atrás y, si lo toca, quedan acostados un rato
		var hit_t := float(_hit.get(key, 0.0))
		var sc := float(_scare.get(key, 0.0))
		if hit_t > 0.0:
			hit_t -= dt
			_hit[key] = hit_t
		elif spd > 2.0 and dd < 9.0:
			sc = minf(1.0, sc + dt * 2.0)
			if dd < 1.5 and spd > 4.0:
				_hit[key] = 5.0
				hit_t = 5.0
		else:
			sc = maxf(0.0, sc - dt * 0.8)
		_scare[key] = sc
		if sc > 0.0:
			var away := Vector2(pos.x - pl.x, pos.z - pl.y)
			if away.length() > 0.1:
				var aw := away.normalized() * 0.9 * sc
				pos.x += aw.x
				pos.z += aw.y
		var hd := heading(float(p["phase"]), float(p["v"]), float(p["len"]), t)
		var dir: Vector3 = ((p["b"] as Vector3) - (p["a"] as Vector3)) * hd
		var hs := 0.93 + float((int(p["key"]) >> 9) & 15) / 15.0 * 0.14
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis.from_scale(Vector3(1.0, hs, 1.0)), pos) # el eje Z del instante es el rumbo: el shader decide hacia qué lado de la pantalla mira
		_mm.set_instance_transform(i, xf)
		var col := Color.from_hsv(float(p["hue"]), 0.55, 0.85)
		col.a = (float(int(p["var"])) + 0.5) / 8.0
		_mm.set_instance_color(i, col)
		var walk_ph := fposmod(float(p["phase"]) * 3.0 + t * float(p["v"]) * 0.9, 1.0)
		_mm.set_instance_custom_data(i, Color(walk_ph if hit_t <= 0.0 else 0.0, 0.0, 1.0 if hit_t > 0.0 else 0.0, fade))
	_mm.visible_instance_count = n
	if _fade.size() > 400:
		for k in _fade.keys():
			if not seen.has(k):
				_fade.erase(k)
				_hit.erase(k)
				_scare.erase(k)

func stats() -> Dictionary:
	return {"pool": _pool.size(), "shown": _mm.visible_instance_count if _mm != null else 0}
