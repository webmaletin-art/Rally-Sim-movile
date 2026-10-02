extends RefCounted
## Papercraft: carga las piezas .pap (godot/game/models/paper, hechas por tools/paper/paperize.py) y arma los materiales de papel.
## Cada pieza es una malla de pocos triángulos con un color liso por cara; el shader (paper.gdshader) hace el resto.

const DIR := "res://game/models/paper/"
const SHADER := preload("res://game/fx/paper.gdshader")

static var _meshes: Dictionary = {}
static var _grain: Texture2D
static var _mats: Dictionary = {}
static var _catalog: Array = []

static func catalog() -> Array:
	if _catalog.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalog.json"))
		_catalog = d if d is Array else []
	return _catalog

static func info(id: String) -> Dictionary:
	for c in catalog():
		if str(c["id"]) == id:
			return c
	return {}

static func grain() -> Texture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.045
		n.fractal_octaves = 3
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.noise = n
		_grain = t
	return _grain

## Material de papel. detail: textura impresa opcional (asfalto, tierra…) y cuánto se nota
static func material(detail: Texture2D = null, detail_amt := 0.0, detail_scale := 0.18, edge_amt := 0.55) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f" % [detail.resource_path if detail != null else "", detail_amt, detail_scale, edge_amt]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("grain", grain())
	if detail != null:
		m.set_shader_parameter("detail", detail)
		m.set_shader_parameter("detail_amt", detail_amt)
		m.set_shader_parameter("detail_scale", detail_scale)
	m.set_shader_parameter("edge_amt", edge_amt)
	_mats[key] = m
	return m

## Agrega a una malla una superficie de caras de color liso (verts: 3 puntos por cara · cols: un color por vértice, igual en los tres)
static func add_surface(m: ArrayMesh, verts: PackedVector3Array, cols: PackedColorArray, mat: Material = null) -> void:
	var n := verts.size()
	if n == 0:
		return
	var uv2 := PackedVector2Array()
	uv2.resize(n)
	var nrm := PackedVector3Array()
	nrm.resize(n)
	for i in range(0, n, 3):
		uv2[i] = Vector2(1, 0)
		uv2[i + 1] = Vector2(0, 1)
		uv2[i + 2] = Vector2(0, 0)
		var fn := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).normalized()
		nrm[i] = fn
		nrm[i + 1] = fn
		nrm[i + 2] = fn
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat if mat != null else material())

static func mesh_from_triangles(verts: PackedVector3Array, cols: PackedColorArray, mat: Material = null) -> ArrayMesh:
	var m := ArrayMesh.new()
	add_surface(m, verts, cols, mat)
	return m

## Pieza del pack en papel (se guarda en memoria: cada una se arma una sola vez)
static func mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var f := FileAccess.open(DIR + id + ".pap", FileAccess.READ)
	if f == null:
		return null
	f.get_buffer(4)
	var nv := int(f.get_32())
	var pos := f.get_buffer(nv * 12).to_float32_array()
	var rgba := f.get_buffer(nv * 4)
	f.close()
	var verts := PackedVector3Array()
	verts.resize(nv)
	var cols := PackedColorArray()
	cols.resize(nv)
	for i in nv:
		verts[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		cols[i] = Color8(rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2], 255)
	var m := mesh_from_triangles(verts, cols)
	_meshes[id] = m
	return m
