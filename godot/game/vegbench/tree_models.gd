extends RefCounted
## BENCHMARK DE VEGETACIÓN (aislado del juego): los árboles pesados elegidos y cómo se cargan sus modelos 3D originales (GLB del pack, sin tocar).
## El mismo código arma el árbol 3D original de la prueba y el que dibuja las imágenes PNG (tools/vegbench/render_views.gd): así los tres sistemas parten del mismo árbol.

const DIR := "res://game/vegbench/"
## id de la prueba · GLB original · altura que se le da (m) · resolución de las imágenes (px) · nombre para mostrar
const TREES := [
	{"id": "tree_a", "src": "sc_pine", "h": 10.0, "res": 512, "name": "Pino SC (11 554 tri)"},
	{"id": "tree_b", "src": "sc_bamboo", "h": 6.5, "res": 512, "name": "Bambú SC (5 913 tri)"},
	{"id": "tree_c", "src": "tree_tree", "h": 10.0, "res": 256, "name": "Árbol hoja ancha (2 992 tri)"},
	{"id": "tree_d", "src": "tree_birch", "h": 8.0, "res": 256, "name": "Abedul (2 826 tri)"},
	{"id": "tree_e", "src": "tree_weeping_willow", "h": 8.0, "res": 256, "name": "Sauce llorón (2 784 tri)"},
]
const VIEW_ANGLES := [0, 45, 90, 135, 180, 225, 270, 315]
static var _cache: Dictionary = {}

static func info(id: String) -> Dictionary:
	for t in TREES:
		if str(t["id"]) == id:
			return t
	return {}

static func tex_path(id: String, kind: String, name: String) -> String:
	return "%stex/%s/%s/%s.png" % [DIR, id, kind, name]

static func view_path(id: String, angle: int) -> String:
	return tex_path(id, "8views", "%s_%d" % [id, angle])

static func cross_path(id: String, which: String) -> String:
	return tex_path(id, "cross", "%s_%s" % [id, which])

## Medidas del cuadro de las imágenes (S = lado del cuadro en metros, h = alto del árbol, r = radio máximo) guardadas por la herramienta de render
static func frame_meta(id: String) -> Dictionary:
	var f := "%stex/%s/meta.json" % [DIR, id]
	if FileAccess.file_exists(f):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Dictionary:
			return d
	return {}

## ¿Están las imágenes generadas de este árbol?
static func has_images(id: String) -> bool:
	return ResourceLoader.exists(view_path(id, 0)) and ResourceLoader.exists(cross_path(id, "front")) and ResourceLoader.exists(cross_path(id, "side"))

## El árbol 3D original en UNA malla (varias superficies): escalada para que mida h, con el tronco en el origen y la base en y = 0. {mesh, h, radius, tris}
static func original(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var t := info(id)
	var ps: PackedScene = load("%smodels/%s.glb" % [DIR, str(t["src"])])
	var root: Node = ps.instantiate()
	var parts: Array = []
	_collect(root, Transform3D.IDENTITY, parts)
	# caja y escala
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for p in parts:
		var mi: MeshInstance3D = p[0]
		var bb: AABB = (p[1] as Transform3D) * mi.mesh.get_aabb()
		lo = lo.min(bb.position)
		hi = hi.max(bb.position + bb.size)
	var k := float(t["h"]) / maxf(0.01, hi.y - lo.y)
	var out := ArrayMesh.new()
	var radius := 0.0
	var tris := 0
	for p in parts:
		var mi: MeshInstance3D = p[0]
		var xf: Transform3D = p[1]
		var m: Mesh = mi.mesh
		var sizes: Array = []
		for s in m.get_surface_count():
			sizes.append((m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		var big := 0
		for s in sizes.size():
			if sizes[s] > sizes[big]:
				big = s
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nv := PackedVector3Array()
			nv.resize(v.size())
			for i in v.size():
				var q := xf * v[i]
				q = Vector3((q.x) * k, (q.y - lo.y) * k, (q.z) * k)
				nv[i] = q
				radius = maxf(radius, sqrt(q.x * q.x + q.z * q.z))
			arr[Mesh.ARRAY_VERTEX] = nv
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var rn := PackedVector3Array()
				rn.resize(nn.size())
				for i in nn.size():
					rn[i] = (xf.basis * nn[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = rn
			arr[Mesh.ARRAY_TANGENT] = null
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += (idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else nv.size() / 3
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, _fixed_material(mi.get_active_material(s), s == big))
	root.free()
	var res := {"mesh": out, "h": float(t["h"]), "radius": radius, "tris": tris}
	_cache[id] = res
	return res

## El pack trae hojas como tarjetas sin material (saldrían blancas): se les da verde y marrón; todo se ve de los dos lados
static func _fixed_material(cur: Material, is_leaf: bool) -> Material:
	var nm: StandardMaterial3D
	if cur is StandardMaterial3D:
		nm = (cur as StandardMaterial3D).duplicate()
		if nm.albedo_color.is_equal_approx(Color(1, 1, 1)) and nm.albedo_texture == null:
			nm.albedo_color = Color(0.22, 0.42, 0.12) if is_leaf else Color(0.35, 0.26, 0.17)
	else:
		nm = StandardMaterial3D.new()
		nm.albedo_color = Color(0.22, 0.42, 0.12) if is_leaf else Color(0.35, 0.26, 0.17)
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	nm.roughness = 0.95
	return nm

static func _collect(n: Node, parent_xf: Transform3D, acc: Array) -> void:
	var xf := parent_xf
	if n is Node3D:
		xf = parent_xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append([n, xf])
	for c in n.get_children():
		_collect(c, xf, acc)

## Luz de la prueba (igual para las imágenes y para la escena: así el 3D original y los impostores se ven con la misma luz)
static func set_ambient(env: Environment) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.55

static func add_sun(parent: Node) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 0.9
	parent.add_child(sun)
	return sun
