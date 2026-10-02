extends Node3D
## El mundo de papel de Paper Race: camino (asfalto y tierra con sus marcas), banquina y campo en caras de papel, y una selva densa hecha
## con TODO el pack de vegetación (árboles, palmeras, bambú, arbustos, flores, pastos, rocas y piezas de calle) en MultiMesh por tramos.
## Todo es fijo: nada se mueve con el viento. Los tramos lejanos se ocultan solos (visibility_range) y la niebla tapa el borde.

const PaperKit := preload("res://game/fx/paper_kit.gd")
const TEX := "res://game/models/paper/tex/"
const CH := 48 # filas (de ~4 m) por tramo de dibujo

const TREES := ["sc_acacia", "sc_cypress", "sc_pine", "tree_birch", "tree_black_tupelo", "tree_christmas_tree", "tree_lombardy_poplar", "tree_quaking_aspen",
	"tree_sassafras", "tree_tree", "tree_weeping_willow", "pino", "abedul", "alamo", "arbol_hoja_ancha", "arbol_seco"]
const PALMS := ["sc_coconut_tree", "sc_palm_tree", "tree_palm_tree", "palmera"]
const MID := ["arbusto", "sc_bamboo", "bush_plant", "bush_plant_3", "bush_decorative_plant", "bush_plant_box", "bush_indoor_plant", "tree_fan_palm_tree"]
const LOW := ["bush_plant_2", "bush_spider_plant", "bush_little_plant", "bush_decorative_plant_2"]
const GRASS := ["pasto"]
const FLOWERS := ["bush_flowers", "bush_flower_box", "sc_hydrangea", "sc_lavender_bush", "flor_roja", "flor_amarilla", "flor_violeta", "flor_blanca", "flor_naranja"]
const ROCKS := ["rock_rock", "rock_rock_2", "rock_rock_3", "roca"]

const C_ASPH := Color(0.55, 0.56, 0.61)
const C_DIRT := Color(0.64, 0.45, 0.27)
const C_SHOULDER := Color(0.76, 0.67, 0.52)
const C_GRASS := [Color(0.40, 0.66, 0.28), Color(0.33, 0.58, 0.24), Color(0.46, 0.70, 0.30), Color(0.29, 0.52, 0.22)]
const C_DEEP := Color(0.17, 0.34, 0.15)

class Acc:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color) -> void:
		v.append_array(PackedVector3Array([a, b, cc, b, d, cc]))
		for k in 6:
			c.append(col)

var track
var view
var rng := RandomNumberGenerator.new()
var density := 1.0
var inst_total := 0
var _inst: Dictionary = {} # "tramo|id" → Array[Transform3D]
var _decor: Dictionary = {}

func setup(p_track, p_density := 1.0) -> void:
	track = p_track
	view = track.make_view(false)
	density = p_density
	rng.seed = 90210
	var rows := int(ceil(float(track.n) / 2.0))
	var chunks := int(ceil(float(rows) / float(CH)))
	for ch in chunks:
		_build_ground(ch * CH * 2, mini(track.n, (ch + 1) * CH * 2))
		_build_road(ch * CH * 2, mini(track.n, (ch + 1) * CH * 2))
	_plant()
	_decor_pieces()
	_commit_instances()

func _jit(c: Color, a: float) -> Color:
	var k := 1.0 + (rng.randf() - 0.5) * a
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))

func _mat_asphalt() -> ShaderMaterial:
	return PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.28)

func _mat_dirt() -> ShaderMaterial:
	return PaperKit.material(load(TEX + "dirt.png") as Texture2D, 0.26, 0.2, 0.3)

func _mat_grass() -> ShaderMaterial:
	return PaperKit.material(load(TEX + "grass.png") as Texture2D, 0.38, 0.16, 0.4)

func _holder(m: ArrayMesh, vis_end: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = vis_end
	add_child(mi)
	return mi

# ───────────────────────── camino ─────────────────────────
func _build_road(i0: int, i1: int) -> void:
	var asph := Acc.new()
	var dirt := Acc.new()
	var marks := Acc.new()
	var hw: float = track.half_width
	for i in range(i0, i1):
		var j: int = (i + 1) % track.n
		var p: Vector3 = track.samples[i]
		var q: Vector3 = track.samples[j]
		var la: Vector3 = track.laterals[i]
		var lb: Vector3 = track.laterals[j]
		var ya: float = track.cy[i] + 0.015
		var yb: float = track.cy[j] + 0.015
		var is_dirt: bool = int(track.road_surf[i]) == 1
		var a := Vector3(p.x - la.x * hw, ya, p.z - la.z * hw)
		var b := Vector3(p.x + la.x * hw, ya, p.z + la.z * hw)
		var c := Vector3(q.x - lb.x * hw, yb, q.z - lb.z * hw)
		var d := Vector3(q.x + lb.x * hw, yb, q.z + lb.z * hw)
		if is_dirt:
			dirt.quad(a, b, c, d, _jit(C_DIRT, 0.16))
			# huellas de las ruedas: dos tiras más oscuras
			for sg in [-1.0, 1.0]:
				var o0: float = sg * 1.0
				var o1: float = sg * 1.55
				marks.quad(_at(p, la, o0, ya + 0.012), _at(p, la, o1, ya + 0.012), _at(q, lb, o0, yb + 0.012), _at(q, lb, o1, yb + 0.012), _jit(C_DIRT.darkened(0.26), 0.1))
		else:
			asph.quad(a, b, c, d, _jit(C_ASPH, 0.1))
			# bordes blancos y línea del medio amarilla cortada
			for sg in [-1.0, 1.0]:
				var o0: float = sg * (hw - 0.45)
				var o1: float = sg * (hw - 0.28)
				marks.quad(_at(p, la, o0, ya + 0.012), _at(p, la, o1, ya + 0.012), _at(q, lb, o0, yb + 0.012), _at(q, lb, o1, yb + 0.012), Color(0.96, 0.95, 0.9))
			if i % 4 < 2:
				marks.quad(_at(p, la, -0.08, ya + 0.012), _at(p, la, 0.08, ya + 0.012), _at(q, lb, -0.08, yb + 0.012), _at(q, lb, 0.08, yb + 0.012), Color(0.97, 0.80, 0.25))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, asph.v, asph.c, _mat_asphalt())
	PaperKit.add_surface(m, dirt.v, dirt.c, _mat_dirt())
	PaperKit.add_surface(m, marks.v, marks.c, PaperKit.material(null, 0.0, 0.2, 0.0))
	_holder(m, 330.0)

func _at(p: Vector3, lat: Vector3, off: float, y: float) -> Vector3:
	return Vector3(p.x + lat.x * off, y, p.z + lat.z * off)

# ───────────────────────── banquina y campo ─────────────────────────
func _build_ground(i0: int, i1: int) -> void:
	var gr := Acc.new()
	var sh := Acc.new()
	var hw: float = track.half_width
	var sho: float = track.shoulder
	var bands: Array[float] = [hw, hw + sho * 0.5, hw + sho, hw + sho + 0.9, hw + sho + 3.0, hw + sho + 7.0, hw + sho + 13.0, hw + sho + 22.0, hw + sho + 34.0, hw + sho + 48.0, hw + sho + 58.0]
	for i in range(i0, i1, 2):
		var j: int = mini(i + 2, i1 + 1) % track.n
		for side in [-1.0, 1.0]:
			var pa: Array[Vector3] = _band_row(i, side, bands)
			var pb: Array[Vector3] = _band_row(j, side, bands)
			for k in bands.size() - 1:
				var col: Color
				var target: Acc = gr
				if k < 2:
					col = _jit(C_SHOULDER, 0.14)
					target = sh
				elif k == 2:
					col = _jit(C_DIRT.darkened(0.25), 0.2)
					target = sh
				elif k >= 9:
					col = _jit(C_DEEP, 0.2)
				else:
					col = _jit(C_GRASS[rng.randi() % 4].lerp(C_DEEP, float(k) / 14.0), 0.18)
					if rng.randf() < 0.07:
						col = _jit(C_DIRT, 0.25) # claros de tierra
				target.quad(pa[k], pa[k + 1], pb[k], pb[k + 1], col)
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, sh.v, sh.c, _mat_dirt())
	PaperKit.add_surface(m, gr.v, gr.c, _mat_grass())
	_holder(m, 330.0)

func _band_row(i: int, side: float, bands: Array[float]) -> Array[Vector3]:
	var p: Vector3 = track.samples[i % track.n]
	var lat: Vector3 = track.laterals[i % track.n]
	var out: Array[Vector3] = []
	for k in bands.size():
		var x: float = p.x + lat.x * side * bands[k]
		var z: float = p.z + lat.z * side * bands[k]
		var y: float = view.ground_smooth(x, z)
		if k == bands.size() - 1:
			y -= 6.0 # faldón: no se ve el borde del mundo
		out.append(Vector3(x, y, z))
	return out

# ───────────────────────── selva ─────────────────────────
func _pick(pool: Array) -> String:
	var tot := 0.0
	for id in pool:
		tot += maxf(0.05, float(PaperKit.info(str(id)).get("weight", 1.0)))
	var r := rng.randf() * tot
	for id in pool:
		r -= maxf(0.05, float(PaperKit.info(str(id)).get("weight", 1.0)))
		if r <= 0.0:
			return str(id)
	return str(pool[0])

func _put(chunk: int, id: String, x: float, z: float, s: float) -> void:
	var y: float = view.ground_smooth(x, z)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - 0.03, z))
	var key := "%d|%s" % [chunk, id]
	if not _inst.has(key):
		_inst[key] = []
	(_inst[key] as Array).append(xf)
	inst_total += 1

func _plant() -> void:
	var edge: float = track.half_width + track.shoulder + 0.5
	# [tasa por fila y lado, distancia mínima, máxima, piezas, escala mín, escala máx]
	var layers := [
		[2.4, -1.4, 9.0, GRASS, 1.5, 2.6], [1.9, -0.8, 10.0, FLOWERS, 1.7, 3.0], [1.1, 0.0, 8.0, LOW, 1.7, 2.8], [1.3, 1.0, 14.0, MID, 1.0, 1.7],
		[0.4, 0.0, 12.0, ROCKS, 0.8, 2.2], [1.0, 2.2, 14.0, TREES + PALMS, 0.7, 1.2], [1.3, 10.0, 42.0, TREES, 1.0, 1.7], [0.5, 4.0, 22.0, PALMS, 0.9, 1.3],
	]
	for i in range(0, track.n, 2):
		var ch: int = i / (CH * 2)
		var p: Vector3 = track.samples[i]
		var lat: Vector3 = track.laterals[i]
		for side in [-1.0, 1.0]:
			for L in layers:
				var cnt := int(float(L[0]) * density + rng.randf())
				for k in cnt:
					var d: float = edge + rng.randf_range(float(L[1]), float(L[2]))
					var along: float = rng.randf_range(-2.1, 2.1)
					var tg: Vector3 = track.tangents[i]
					var x: float = p.x + lat.x * side * d + tg.x * along
					var z: float = p.z + lat.z * side * d + tg.z * along
					view.ground_smooth(x, z)
					if absf(view.r_lat) < edge - 0.2:
						continue # cayó sobre el camino (curva cerrada)
					var pool: Array = L[3]
					_put(ch, _pick(pool), x, z, rng.randf_range(float(L[4]), float(L[5])))

func _decor_pieces() -> void:
	var edge: float = track.half_width + track.shoulder + 0.2
	# sendas peatonales sobre el asfalto
	for t in [0.07, 0.50]:
		var i := int(t * float(track.n))
		var tg: Vector3 = track.tangents[i]
		var p: Vector3 = track.samples[i]
		var yaw := atan2(-tg.z, tg.x)
		var mi := MeshInstance3D.new()
		mi.mesh = PaperKit.mesh("sc_pedestrian_crossing")
		var sc := Vector3(1.0, 1.0, track.half_width * 2.0 * 0.9 / 7.5)
		mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(sc), Vector3(p.x, track.cy[i] + 0.03, p.z))
		mi.visibility_range_end = 300.0
		add_child(mi)
	# postes separadores y cordón de la recta de largada, banquinas de piedra en el pueblo, y un arenero con estacionamiento
	for i in range(0, 40, 3):
		for side in [-1.0, 1.0]:
			var p: Vector3 = track.samples[i]
			var lat: Vector3 = track.laterals[i]
			_decor_at("sc_traffic_lane_separator", p, lat, side * (edge + 0.2), 1.0, track.tangents[i])
	for i in range(int(0.86 * float(track.n)), int(0.98 * float(track.n)), 6):
		for side in [-1.0, 1.0]:
			_decor_at("sidewalk_concrete_sidewalk", track.samples[i], track.laterals[i], side * (edge - 0.5), 1.0, track.tangents[i])
	var k := int(0.30 * float(track.n))
	_decor_at("sc_sandpit", track.samples[k], track.laterals[k], edge + 5.0, 2.2, track.tangents[k])
	_decor_at("sc_parking_slot", track.samples[k + 6], track.laterals[k + 6], edge + 4.5, 1.0, track.tangents[k + 6])
	_decor_at("sidewalk_bump", track.samples[k + 12], track.laterals[k + 12], edge + 3.0, 2.0, track.tangents[k + 12])

func _decor_at(id: String, p: Vector3, lat: Vector3, off: float, s: float, tg: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = PaperKit.mesh(id)
	var x: float = p.x + lat.x * off
	var z: float = p.z + lat.z * off
	var y: float = view.ground_smooth(x, z)
	mi.transform = Transform3D(Basis(Vector3.UP, atan2(-tg.z, tg.x)).scaled(Vector3.ONE * s), Vector3(x, y, z))
	mi.visibility_range_end = 260.0
	add_child(mi)

func _commit_instances() -> void:
	for key in _inst:
		var parts := str(key).split("|")
		var id: String = parts[1]
		var arr: Array = _inst[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PaperKit.mesh(id)
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 250.0 if PaperKit.info(id).get("cat", "") in ["pasto", "flor", "planta"] else 330.0
		add_child(mmi)
	_inst.clear()
