extends RefCounted
## Ambiente del garaje del menú: una sala redonda de paredes de grafito con pilares, barras de luz blancas y naranjas, piso pulido y el logo DR.
## Liviano para el teléfono (que es lo que pesa: la pared cubre toda la pantalla): pocas mallas (MultiMesh para lo repetido), materiales SIN iluminación
## (un color liso ya oscurecido: cuesta casi nada por píxel), sin luces extra y sin sombras.

const ROOM_R := 14.0
const ROOM_H := 7.5

static func _mat(col: Color, _rough := 0.7, _metal := 0.0, _emissive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _multi(parent: Node3D, mesh: Mesh, xf: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)

## Barra de luz en la pared: centro a ángulo `ang` (rad) y altura `y`, largo `len` sobre la pared
static func _bar_xf(ang: float, y: float, len: float, r := ROOM_R - 0.25) -> Transform3D:
	var pos := Vector3(sin(ang) * r, y, cos(ang) * r)
	var b := Basis.looking_at(-Vector3(sin(ang), 0, cos(ang)), Vector3.UP) # mira al centro; el largo va a lo ancho (x local)
	b = b.scaled(Vector3(len, 1, 1))
	return Transform3D(b, pos)

static func _on(part: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="): # prueba de rendimiento: sólo estas partes (wall,floor,pillars,panels,bars,labels)
			return (a.substr(7).split(",") as PackedStringArray).has(part)
	return true

static func build(parent: Node3D) -> void:
	var room := Node3D.new()
	room.name = "GarageRoom"
	parent.add_child(room)
	# pared y techo (se ven desde adentro)
	var wall_m := _mat(Color(0.045, 0.052, 0.068))
	wall_m.cull_mode = BaseMaterial3D.CULL_FRONT
	var cyl := CylinderMesh.new()
	cyl.top_radius = ROOM_R
	cyl.bottom_radius = ROOM_R
	cyl.height = ROOM_H
	cyl.radial_segments = 40
	cyl.rings = 1
	cyl.material = wall_m
	var wall := MeshInstance3D.new()
	wall.mesh = cyl
	wall.position.y = ROOM_H * 0.5 - 0.05
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _on("wall"):
		room.add_child(wall)
	# piso pulido (más grande que la plataforma)
	var floor_m := _mat(Color(0.022, 0.025, 0.032))
	var fl := CylinderMesh.new()
	fl.top_radius = ROOM_R - 0.05
	fl.bottom_radius = ROOM_R - 0.05
	fl.height = 0.06
	fl.radial_segments = 40
	fl.rings = 1
	fl.material = floor_m
	var floor_i := MeshInstance3D.new()
	floor_i.mesh = fl
	floor_i.position.y = -0.1
	floor_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _on("floor"):
		room.add_child(floor_i)
	# pilares verticales
	var pil := BoxMesh.new()
	pil.size = Vector3(0.55, ROOM_H, 0.3)
	pil.material = _mat(Color(0.085, 0.092, 0.115))
	var xs: Array = []
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		var tf := Transform3D(Basis.looking_at(-Vector3(sin(a), 0, cos(a)), Vector3.UP), Vector3(sin(a) * (ROOM_R - 0.15), ROOM_H * 0.5 - 0.05, cos(a) * (ROOM_R - 0.15)))
		xs.append(tf)
	if _on("pillars"):
		_multi(room, pil, xs)
	# paneles entre pilares (un poco más claros, a media altura): dan textura industrial
	var pan := BoxMesh.new()
	pan.size = Vector3(1.9, 1.6, 0.12)
	pan.material = _mat(Color(0.062, 0.07, 0.09))
	var px: Array = []
	for i in n:
		var a2 := TAU * (float(i) + 0.5) / float(n)
		px.append(Transform3D(Basis.looking_at(-Vector3(sin(a2), 0, cos(a2)), Vector3.UP), Vector3(sin(a2) * (ROOM_R - 0.1), 1.4, cos(a2) * (ROOM_R - 0.1))))
		px.append(Transform3D(Basis.looking_at(-Vector3(sin(a2), 0, cos(a2)), Vector3.UP), Vector3(sin(a2) * (ROOM_R - 0.1), 3.4, cos(a2) * (ROOM_R - 0.1))))
	if _on("panels"):
		_multi(room, pan, px)
	# barras de luz: blancas arriba, naranjas más abajo (algunas), y un zócalo naranja tenue
	var bar := BoxMesh.new()
	bar.size = Vector3(1.0, 0.085, 0.06)
	bar.material = _mat(Color(1.0, 0.96, 0.9))
	var wx: Array = []
	for i in 9:
		var a3 := TAU * (float(i) + 0.25) / 9.0
		wx.append(_bar_xf(a3, 5.5, 4.2))
		wx.append(_bar_xf(a3 + 0.26, 6.25, 2.4))
	if _on("bars"):
		_multi(room, bar, wx)
	var bar_o := BoxMesh.new()
	bar_o.size = Vector3(1.0, 0.09, 0.06)
	bar_o.material = _mat(Color(1.0, 0.47, 0.09))
	var ox: Array = []
	for i in 9:
		var a4 := TAU * (float(i) + 0.75) / 9.0
		ox.append(_bar_xf(a4, 4.6, 3.4))
		ox.append(_bar_xf(a4 - 0.22, 0.28, 4.0))
	if _on("bars"):
		_multi(room, bar_o, ox)
	# logo DR en la pared del fondo (y en otras dos para cuando se gira la cámara)
	for k in (3 if _on("labels") else 0):
		var ang := PI + 0.62 + float(k) * TAU / 3.0 # el auto mira hacia el frente-izquierdo: el fondo está del lado opuesto de la cámara
		var lab := Label3D.new()
		lab.text = "DR"
		lab.font_size = 160
		lab.pixel_size = 0.0202
		lab.outline_size = 0
		lab.modulate = Color(0.52, 0.55, 0.62, 0.62)
		lab.shaded = false
		lab.double_sided = false
		lab.no_depth_test = false
		var r := ROOM_R - 0.45
		lab.position = Vector3(sin(ang) * r, 3.2, cos(ang) * r)
		lab.look_at_from_position(lab.position, Vector3(0, 3.2, 0), Vector3.UP)
		lab.rotate_object_local(Vector3.UP, PI) # Label3D mira hacia +z local
		room.add_child(lab)
		var sub := Label3D.new()
		sub.text = "DREAM RACING"
		sub.font_size = 48
		sub.pixel_size = 0.016
		sub.modulate = Color(1.0, 0.47, 0.09, 0.8)
		sub.shaded = false
		var r2 := ROOM_R - 0.45
		sub.position = Vector3(sin(ang) * r2, 2.15, cos(ang) * r2)
		sub.look_at_from_position(sub.position, Vector3(0, 2.15, 0), Vector3.UP)
		sub.rotate_object_local(Vector3.UP, PI)
		room.add_child(sub)
