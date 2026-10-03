extends RefCounted
## Junta piezas de papel del pack (árboles, flores, arbustos, pasto: godot/game/models/paper) dentro de una sola malla: cada pieza se copia con su posición, giro y escala
## (la transformación de todos los puntos de una pieza se hace de una vez, sin recorrerlos uno por uno).

const PaperKit := preload("res://game/fx/paper_kit.gd")

static var _src: Dictionary = {} # id -> [PackedVector3Array, PackedColorArray, altura]

static func _piece(id: String) -> Array:
	if _src.has(id):
		return _src[id]
	var m := PaperKit.mesh(id)
	if m == null or m.get_surface_count() == 0:
		_src[id] = []
		return []
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var h := float(PaperKit.info(id).get("h", 1.0))
	_src[id] = [v, c, h]
	return _src[id]

## Pone la pieza id en (pos), girada yaw, con una altura final de height metros (0 = tamaño original)
static func add(id: String, pos: Vector3, yaw: float, height: float, v: PackedVector3Array, c: PackedColorArray, base_xf := Transform3D.IDENTITY, tint := 1.0) -> void:
	var s := _piece(id)
	if s.is_empty():
		return
	var k := 1.0 if height <= 0.0 else height / maxf(float(s[2]), 0.05)
	var xf := base_xf * Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(k, k, k)), pos)
	v.append_array(xf * (s[0] as PackedVector3Array))
	var cols: PackedColorArray = s[1]
	if tint != 1.0:
		var out := PackedColorArray()
		out.resize(cols.size())
		for i in cols.size():
			out[i] = Color(minf(cols[i].r * tint, 1.0), minf(cols[i].g * tint, 1.0), minf(cols[i].b * tint, 1.0), 1.0)
		cols = out
	c.append_array(cols)
