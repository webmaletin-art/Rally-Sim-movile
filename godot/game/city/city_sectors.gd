extends RefCounted
## Barreras de obra donde una ruta de la región entra a un sector cerrado (region/sectors.gd, game/data/sectors.json). No es una pared invisible: es una fila de
## barreras rojas y blancas de verdad, de banquina a banquina (lo que mide el corredor de la ruta), con su cartel «CAMINO CERRADO». Cada barrera choca
## (círculos sólidos en la pista: track.add_prop, no se rompen) y el dibujo sólo existe cerca de la cámara.
## Para abrir todo: sectors.json → open_all = true (no hace falta tocar nada más).

const Sectors := preload("res://game/region/sectors.gd")
const RegionData := preload("res://game/region/region_data.gd")
const Tr := preload("res://game/i18n/tr.gd")

const PROP_BASE := 970000
const NEAR := 700.0
const BACK := 28.0 # la barrera queda tantos metros adentro del lado abierto
const STEP := 1.7 # separación de los círculos sólidos
const R := 1.0

var race
var track
var region
var gates: Array = [] # {p: Vector2, dir: Vector2 (hacia el sector cerrado), w: float (medio ancho a cubrir), y: float}
var _nodes := {} # índice → Node3D
var _t := 0.0
var _mat_r: StandardMaterial3D
var _mat_w: StandardMaterial3D

func setup(p_race) -> void:
	race = p_race
	track = race.track
	region = track.get("region")
	if region == null or Sectors.all_open():
		return
	gates = find_gates(region)
	var id := PROP_BASE
	for g in gates:
		var lat := Vector2(g["dir"].y, -g["dir"].x)
		var w: float = g["w"]
		var k := -w
		while k <= w + 0.01:
			var q: Vector2 = g["p"] + lat * k
			track.add_prop(id, q.x, q.y, R)
			id += 1
			k += STEP

## Dónde cada ruta cruza de un sector abierto a uno cerrado (puro: lo usan también las pruebas)
static func find_gates(rg) -> Array:
	var out: Array = []
	for ei in rg.edges.size():
		var n: int = rg.edge_n(ei)
		if n < 3:
			continue
		var prev_open := Sectors.is_open(rg.edge_point(ei, 0))
		for i in range(1, n):
			var o := Sectors.is_open(rg.edge_point(ei, i))
			if o != prev_open:
				# índice del último punto abierto y sentido hacia el cerrado
				var step := -1 if o else 1 # si ahora es abierto, el cerrado quedó atrás
				var j := i if o else i - 1
				var acc := 0.0
				while acc < BACK and j - step >= 0 and j - step < n:
					acc += rg.edge_point(ei, j).distance_to(rg.edge_point(ei, j - step))
					j -= step
				var p: Vector2 = rg.edge_point(ei, j)
				var q: Vector2 = rg.edge_point(ei, clampi(j + step, 0, n - 1))
				var dv := (q - p).normalized() if q != p else Vector2(0, 1)
				var w: float = float(rg.e_hw[ei]) + RegionData.SHOULDER + float(rg.wall_of(ei)) + 0.6
				out.append({"p": p, "dir": dv, "w": w, "ei": ei})
			prev_open = o
	return out

func update(dt: float) -> void:
	if gates.is_empty() or race.cars.is_empty():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	var ph = race.cars[0].phys
	var p := Vector2(ph.px, ph.pz)
	for i in gates.size():
		var near := (gates[i]["p"] as Vector2).distance_to(p) < NEAR
		if near and not _nodes.has(i):
			_nodes[i] = _build(gates[i])
		elif not near and _nodes.has(i):
			if is_instance_valid(_nodes[i]):
				(_nodes[i] as Node).queue_free()
			_nodes.erase(i)

func _build(g: Dictionary) -> Node3D:
	if _mat_r == null:
		_mat_r = StandardMaterial3D.new()
		_mat_r.albedo_color = Color(0.85, 0.12, 0.1)
		_mat_w = StandardMaterial3D.new()
		_mat_w.albedo_color = Color(0.95, 0.95, 0.93)
	var root := Node3D.new()
	var p: Vector2 = g["p"]
	var dir: Vector2 = g["dir"]
	var lat := Vector2(dir.y, -dir.x)
	var w: float = g["w"]
	var yaw := atan2(dir.x, dir.y)
	# barreras tipo New Jersey de 2 m (rojas y blancas intercaladas): una sola llamada de dibujo por color
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.85, 0.55)
	var cnt := int(ceil(w * 2.0 / 2.0)) + 1
	var mi_r := MultiMeshInstance3D.new()
	var mi_w := MultiMeshInstance3D.new()
	var mr := MultiMesh.new()
	var mw := MultiMesh.new()
	for m2 in [mr, mw]:
		m2.transform_format = MultiMesh.TRANSFORM_3D
		m2.mesh = bm
		m2.instance_count = (cnt + 1) / 2
	var ir := 0
	var iw := 0
	for k in cnt:
		var off := -w + 2.0 * float(k)
		var q := p + lat * off
		var y := float(track.ground_y(q.x, q.y)) + 0.42
		var xf := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), Vector3(q.x, y, q.y))
		if k % 2 == 0 and ir < mr.instance_count:
			mr.set_instance_transform(ir, xf)
			ir += 1
		elif iw < mw.instance_count:
			mw.set_instance_transform(iw, xf)
			iw += 1
	mr.visible_instance_count = ir
	mw.visible_instance_count = iw
	mi_r.multimesh = mr
	mi_r.material_override = _mat_r
	mi_w.multimesh = mw
	mi_w.material_override = _mat_w
	root.add_child(mi_r)
	root.add_child(mi_w)
	var sy := float(track.ground_y(p.x, p.y))
	var lb := Label3D.new()
	lb.text = "⛔ " + Tr.t("CAMINO CERRADO") + "\n" + Tr.t(Sectors.pending_name) + " · " + Tr.t("Próximamente")
	lb.font_size = 64
	lb.pixel_size = 0.012
	lb.outline_size = 14
	lb.modulate = Color(1.0, 0.85, 0.3)
	lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lb.position = Vector3(p.x, sy + 3.2, p.y)
	root.add_child(lb)
	if track.world_node != null:
		track.world_node.add_child(root)
	return root
