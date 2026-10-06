extends RefCounted
## Bosque del horizonte de Dream City: dos anillos de imágenes (72 segmentos cada uno, 144 triángulos en total) que acompañan a la cámara. Cada uno es una tira de bosque de 2048 x 64 píxeles hecha con las siluetas
## de las mismas imágenes de árboles (tools/vegworld/make_horizon.py): copas de distinta altura, claros, hileras de álamos y manchones de pinos. Se repiten 3 y 4 veces por vuelta con tiras DISTINTAS y a
## distinto radio, así no se nota la repetición, y el borde de arriba es irregular: no se ve un muro. Reemplazan a miles de árboles individuales a esa distancia.

const SHADER := preload("res://game/city/shaders/horizon_trees.gdshader")
const DIR := "res://game/city/trees/"
const BASE_Y := -6.5
## radio (m) · alto (m) · repeticiones por vuelta · tira · giro inicial (vueltas)
const RINGS := [[395.0, 26.0, 4, "horizon_a", 0.0], [335.0, 21.0, 3, "horizon_b", 0.37]]
static var _mats: Array[ShaderMaterial] = []
static var _tone := Vector3.ONE

## Los anillos (nodos MeshInstance3D); el que los pone los mueve con la cámara
static func build() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_mats.clear()
	var n := 72
	for ri in RINGS.size():
		var rg: Array = RINGS[ri]
		var r := float(rg[0])
		var hh := float(rg[1])
		var rep := int(rg[2])
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		for i in n + 1:
			var a := TAU * float(i) / float(n)
			var x := cos(a) * r
			var z := sin(a) * r
			var u := float(rg[4]) + float(i) / float(n) * float(rep)
			verts.append(Vector3(x, BASE_Y, z))
			uvs.append(Vector2(u, 1.0))
			verts.append(Vector3(x, BASE_Y + hh, z))
			uvs.append(Vector2(u, 0.0))
		for i in n:
			var b := i * 2
			idx.append_array([b, b + 1, b + 3, b, b + 3, b + 2])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("strip", load(DIR + str(rg[3]) + ".png"))
		mat.set_shader_parameter("base_y", BASE_Y)
		mat.set_shader_parameter("tone", _tone)
		m.surface_set_material(0, mat)
		_mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.name = "bosque_lejano_%d" % ri
		mi.mesh = m
		mi.extra_cull_margin = 4000.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
	return out

static func set_night(n: float) -> void:
	_tone = Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.20, 0.24, 0.40), clampf(n, 0.0, 1.0))
	for m in _mats:
		m.set_shader_parameter("tone", _tone)
