extends RefCounted
## Árboles falsos del mundo abierto (Dream City): imágenes en vez de geometría. Cada especie son 8 vistas (cada 45°) dibujadas de su árbol de papel (tools/vegworld) y todas juntas viven en UNA textura de capas.
##  · cerca (cuadras a menos de ~190 m): «8 VISTAS» — un cuadro que mira a la cámara y elige la vista que corresponde (2 triángulos por árbol);
##  · media distancia (hasta donde se arma el mundo): «CRUZ» — dos cuadros cruzados con las vistas de 0° y 90° de la MISMA textura (4 triángulos): no cuesta memoria extra;
##  · más allá: el horizonte (horizon_trees.gd).
## Todos los árboles de una cuadra se juntan en un MultiMesh por nivel (una llamada de dibujo cada uno) y comparten malla, material y textura con todo el mundo.
## Reemplazan a los árboles de papel con volumen (de ~100 a más de 400 triángulos cada uno) y a los recortes cruzados de la ruta.

const SHADER_BILL := preload("res://game/city/shaders/tree_bill.gdshader")
const SHADER_CROSS := preload("res://game/city/shaders/tree_cross.gdshader")
const NEAR_END := 190.0 # hasta acá (distancia al centro de los árboles de la cuadra) se usan las 8 vistas
const FAR_END := 520.0
const DIR := "res://game/city/trees/"
const PALM_FIRST := 7 # desde esta especie: palmeras (sólo cerca del mar)
## id · pieza de papel de la que sale (godot/game/models/paper) · altura (m) · resolución de cada vista (px) · tipo
const SPECIES := [
	{"id": "pino", "src": "pino", "h": 12.0, "res": 192, "kind": "conifer"},
	{"id": "cipres", "src": "sc_cypress", "h": 10.0, "res": 192, "kind": "column"},
	{"id": "alamo", "src": "alamo", "h": 13.0, "res": 192, "kind": "column"},
	{"id": "hoja_ancha", "src": "arbol_hoja_ancha", "h": 11.0, "res": 192, "kind": "round"},
	{"id": "roble", "src": "tree_tree", "h": 10.0, "res": 192, "kind": "round"},
	{"id": "abedul", "src": "abedul", "h": 9.0, "res": 192, "kind": "round"},
	{"id": "sasafras", "src": "tree_sassafras", "h": 11.0, "res": 192, "kind": "round"},
	{"id": "palmera", "src": "palmera", "h": 10.0, "res": 192, "kind": "palm"},
	{"id": "coco", "src": "sc_coconut_tree", "h": 10.0, "res": 192, "kind": "palm"},
]

static var _tex: Texture2DArray
static var _meta: Dictionary = {}
static var _mat_b: ShaderMaterial
static var _mat_c: ShaderMaterial
static var _mesh_b: ArrayMesh
static var _mesh_c: ArrayMesh
static var _tone := Vector3.ONE

## Texturas, materiales y mallas: se arman una sola vez y las comparten todas las cuadras
static func _ensure() -> void:
	if _tex != null:
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "trees.json"))
	_meta = d if d is Dictionary else {}
	var images: Array[Image] = []
	var res := 0
	for sp in SPECIES:
		res = maxi(res, int(sp["res"]))
	for sp in SPECIES:
		for ang in [0, 45, 90, 135, 180, 225, 270, 315]:
			var im: Image = (load("%s%s_%d.png" % [DIR, str(sp["id"]), ang]) as Texture2D).get_image()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			if im.get_width() != res:
				im.resize(res, res, Image.INTERPOLATE_BILINEAR)
			im.generate_mipmaps()
			images.append(im)
	_tex = Texture2DArray.new()
	_tex.create_from_images(images)
	_mat_b = ShaderMaterial.new()
	_mat_b.shader = SHADER_BILL
	_mat_b.set_shader_parameter("views", _tex)
	_mat_c = ShaderMaterial.new()
	_mat_c.shader = SHADER_CROSS
	_mat_c.set_shader_parameter("views", _tex)
	_mat_b.set_shader_parameter("tone", _tone)
	_mat_c.set_shader_parameter("tone", _tone)
	var big := AABB(Vector3(-0.75, -0.75, -0.75), Vector3(1.5, 1.5, 1.5)) # el cuadro gira alrededor del tronco: la caja de recorte es un cubo
	var q := PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = q
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_mesh_b = ArrayMesh.new()
	_mesh_b.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	_mesh_b.custom_aabb = big
	_mesh_b.surface_set_material(0, _mat_b)
	var v2 := PackedVector3Array()
	v2.append_array(q)
	for p in q:
		v2.append(Vector3(0, p.y, p.x)) # plano 1: a lo largo de Z
	var uv2 := PackedVector2Array()
	for i in 4:
		uv2.append(Vector2(0, 0))
	for i in 4:
		uv2.append(Vector2(1, 0))
	var uvs := PackedVector2Array()
	uvs.append_array(uv)
	uvs.append_array(uv)
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = v2
	a2[Mesh.ARRAY_TEX_UV] = uvs
	a2[Mesh.ARRAY_TEX_UV2] = uv2
	a2[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	_mesh_c = ArrayMesh.new()
	_mesh_c.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	_mesh_c.custom_aabb = big
	_mesh_c.surface_set_material(0, _mat_c)

## Altura de la especie (m)
static func height_of(sp: int) -> float:
	return float(SPECIES[sp]["h"])

## Memoria de textura (bytes, con mipmaps) que ocupa el conjunto: para las estadísticas
static func tex_bytes() -> int:
	var t := 0
	for sp in SPECIES:
		var r := int(sp["res"])
		t += 8 * r * r * 4 * 4 / 3
	return t

static func _h01(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)

## Qué especie va en (x, z): el monte tiene «manchones» de 45 m con una especie preferida (como un monte real) y un tercio de los árboles salen distintos. r = número al azar del árbol (0…1).
## coast: cerca del mar entran las palmeras.
static func pick(x: float, z: float, r: float, coast := false) -> int:
	if coast and r < 0.45:
		return PALM_FIRST + int(r * 1000.0) % (SPECIES.size() - PALM_FIRST)
	var cell := _h01(floorf(x / 45.0), floorf(z / 45.0))
	var groves := [3, 4, 0, 5, 1, 6, 4, 3, 2, 0, 3, 5] # hoja ancha y roble los más comunes, después pino, abedules, ciprés y álamo
	var pref: int = groves[int(cell * 12.0) % 12]
	var rr := fposmod(r * 7.31, 1.0)
	if rr < 0.62:
		return pref
	var mix := [3, 4, 0, 5, 6, 1, 2, 0, 3, 4]
	return mix[int(fposmod(r * 91.7, 1.0) * float(mix.size())) % mix.size()]

## Lo mismo para un bioma (la Travesía X): «conifer» (pinos y cipreses: la sierra), «round» (hojas anchas: valles y arroyos) o «mixed». Los manchones de 45 m prefieren una especie de la lista.
static func pick_biome(x: float, z: float, r: float, biome: String) -> int:
	var list: Array
	match biome:
		"conifer":
			list = [0, 0, 0, 1, 0, 2, 0, 5]
		"round":
			list = [3, 4, 5, 6, 3, 4, 2, 6]
		_:
			list = [3, 0, 4, 0, 5, 6, 1, 3, 2, 4]
	var cell := _h01(floorf(x / 45.0), floorf(z / 45.0))
	var pref: int = list[int(cell * float(list.size())) % list.size()]
	if fposmod(r * 7.31, 1.0) < 0.62:
		return pref
	return list[int(fposmod(r * 91.7, 1.0) * float(list.size())) % list.size()]

## Un árbol para build(): base en (x, y, z) · especie · escala (0,7…1,3) · giro · tinte (verde más claro u oscuro)
static func item(x: float, y: float, z: float, sp: int, k: float, yaw: float, seed_v: float) -> Array:
	var b := 0.84 + 0.26 * fposmod(seed_v * 17.3, 1.0)
	var hs := (fposmod(seed_v * 5.7, 1.0) - 0.5) * 0.18 # corrimiento hacia amarillo o hacia azul
	return [x, y, z, sp, k, yaw, Color(b * (1.0 + hs), b, b * (1.0 - hs))]

## Nodo con los árboles de la lista (null si está vacía): un MultiMesh de 8 vistas para lo cercano y uno de cruces para lo lejano. vk = alcance de la vista (0,6…1).
static func build(items: Array, vk: float) -> Node3D:
	if items.is_empty():
		return null
	_ensure()
	var root := Node3D.new()
	root.name = "trees"
	var near := _mmi(items, _mesh_b, false)
	near.name = "arboles_8v"
	near.visibility_range_end = NEAR_END * vk
	near.visibility_range_end_margin = 20.0
	var far := _mmi(items, _mesh_c, true)
	far.name = "arboles_cruz"
	far.visibility_range_begin = NEAR_END * vk
	far.visibility_range_begin_margin = 20.0
	far.visibility_range_end = FAR_END * vk
	root.add_child(near)
	root.add_child(far)
	return root

static func _mmi(items: Array, mesh: Mesh, use_yaw: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	var i := 0
	for it in items:
		var sp: int = it[3]
		var info: Dictionary = _meta[str(SPECIES[sp]["id"])]
		var k: float = it[4]
		var s := float(info["S"]) * k
		var b := Basis(Vector3.UP, float(it[5]) if use_yaw else 0.0).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(it[0], float(it[1]) + float(info["h"]) * k * 0.5, it[2])))
		var t: Color = it[6]
		mm.set_instance_custom_data(i, Color(float(sp * 8), t.r, t.g, t.b))
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## Luz del momento del día: las imágenes traen la luz de día pintada; de noche se oscurecen (n = 0 día … 1 noche, igual que CityWorld.set_night)
static func set_night(n: float) -> void:
	_tone = Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.20, 0.24, 0.40), clampf(n, 0.0, 1.0))
	if _mat_b != null:
		_mat_b.set_shader_parameter("tone", _tone)
		_mat_c.set_shader_parameter("tone", _tone)
