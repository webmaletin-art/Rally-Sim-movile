extends RefCounted
## CROSS 2 PLANOS: dos cuadros verticales cruzados a 90° (4 triángulos) con 2 PNG (frente y costado). Sin geometría del árbol original: 2 cuadros + 2 imágenes + material con recorte.

const TreeModels := preload("res://game/vegbench/tree_models.gd")
const SHADER := preload("res://game/vegbench/shaders/cross2.gdshader")
static var _cache: Dictionary = {}

static func build(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var meta := TreeModels.frame_meta(id)
	var s := float(meta["S"])
	var h := float(meta["h"])
	var images: Array[Image] = []
	for which in ["front", "side"]:
		var im: Image = (load(TreeModels.cross_path(id, which)) as Texture2D).get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		im.generate_mipmaps()
		images.append(im)
	var arr_tex := Texture2DArray.new()
	arr_tex.create_from_images(images)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("views", arr_tex)
	var cy := h * 0.5
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in 2:
		# plano 0: a lo largo de X (se ve de frente); plano 1: a lo largo de Z (se ve de costado)
		var dx := Vector3(s * 0.5, 0, 0) if p == 0 else Vector3(0, 0, s * 0.5)
		var b := verts.size()
		verts.append_array([-dx + Vector3(0, cy - s * 0.5, 0), dx + Vector3(0, cy - s * 0.5, 0), dx + Vector3(0, cy + s * 0.5, 0), -dx + Vector3(0, cy + s * 0.5, 0)])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		for k in 4:
			cols.append(Color(float(p), 0, 0, 1))
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, mat)
	var r := images[0].get_width()
	var res := {"mesh": m, "material": mat, "tex_bytes": 2 * r * r * 4 * 4 / 3, "tris": 4}
	_cache[id] = res
	return res
