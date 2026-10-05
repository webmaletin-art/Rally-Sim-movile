extends RefCounted
## TreeImpostor8View: el árbol falso de 8 vistas. UN cuadro (2 triángulos) + UNA textura de 8 capas (las 8 PNG) + selección automática de la vista según el ángulo de la cámara
## (shaders/impostor8.gdshader). La malla y el material se arman una sola vez por tipo de árbol y los comparten todas las instancias (MultiMesh).

const TreeModels := preload("res://game/vegbench/tree_models.gd")
const SHADER := preload("res://game/vegbench/shaders/impostor8.gdshader")
static var _cache: Dictionary = {}

## {mesh, material, tex_bytes}: la malla es un cuadro del tamaño del cuadro de las imágenes (S m), con la base del árbol a y = 0
static func build(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var meta := TreeModels.frame_meta(id)
	var s := float(meta["S"])
	var h := float(meta["h"])
	var images: Array[Image] = []
	for ang in TreeModels.VIEW_ANGLES:
		var im: Image = (load(TreeModels.view_path(id, int(ang))) as Texture2D).get_image()
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
	var cy := h * 0.5 # el cuadro está centrado a media altura del árbol
	var verts := PackedVector3Array([Vector3(-s * 0.5, cy - s * 0.5, 0), Vector3(s * 0.5, cy - s * 0.5, 0), Vector3(s * 0.5, cy + s * 0.5, 0), Vector3(-s * 0.5, cy + s * 0.5, 0)])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.custom_aabb = AABB(Vector3(-s * 0.5, cy - s * 0.5, -s * 0.5), Vector3(s, s, s)) # el cuadro gira alrededor del tronco
	m.surface_set_material(0, mat)
	var r := images[0].get_width()
	var res := {"mesh": m, "material": mat, "tex_bytes": 8 * r * r * 4 * 4 / 3, "tris": 2}
	_cache[id] = res
	return res
