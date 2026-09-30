extends Node3D
## Habitáculo para las cámaras interiores (portado de js/cockpit.js): tablero, parantes, parabrisas, capó visto desde adentro,
## jaula, butacas, volante que gira, palanca y freno de mano que se mueven, display digital, y el piloto y el copiloto con
## esqueleto (manos al volante por cinemática inversa, fuerzas G).
## Solo se dibuja cuando la cámara está adentro (onboard / atrás de las butacas): desde afuera los vidrios son oscuros
## y no se ve a nadie. Todo lo fijo se junta en pocas mallas (una por material) para gastar pocas llamadas de dibujo.
## Coordenadas: marco de la carrocería (+z adelante, +x izquierda, y desde el piso). El nodo va en y = -comHeight + rideOffset.

const RigPilot := preload("res://game/car/rig_pilot.gd")
const CrewMotion := preload("res://game/car/crew_motion.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

const CABIN := {
	"pickup": {"eyeY": 1.40, "eyeZ": 0.30, "cowlZ": 1.22, "halfW": 0.80, "roofY": 1.70},
	"t1plus": {"eyeY": 1.19, "eyeZ": -0.20, "cowlZ": 0.78, "halfW": 0.82, "roofY": 1.44},
	"truck": {"eyeY": 1.55, "eyeZ": 1.72, "cowlZ": 2.55, "halfW": 0.98, "roofY": 1.98},
	"genesis": {"eyeY": 1.08, "eyeZ": -0.12, "cowlZ": 0.98, "halfW": 0.74, "roofY": 1.33},
}

var C: Dictionary
var xD := 0.37
var floor_y := 0.0
var eye := Vector3.ZERO
var wheel_c := Vector3.ZERO
var interior: Node3D # todo lo fijo (visible solo con cámara interior)
var crew: Node3D # piloto y copiloto
var rig: Array = [] # [piloto, copiloto]
var mo: Array = [] # movimiento de cada uno (CrewMotion)
var wheel_group: Node3D
var rim: Node3D
var gear_lever: Node3D
var hb_lever: Node3D
var wipers: Array = []
var disp_vp: SubViewport
var disp_ctl: DisplayPanel
var _disp_t := 0.0
var _mats := {}
var _batch := {}
var _wu := Vector3.RIGHT
var _wv := Vector3.UP
var gear_kick := 0.0
var wipe_t := 0.0
var raining := false
var units := "kmh"
var look_yaw := 0.0
var rig_ok := false

func _init(p_type: String, p_paint := Color(0.10, 0.31, 0.88), p_accent := Color(1.0, 0.42, 0.03)) -> void:
	C = (CABIN.get(p_type, CABIN["t1plus"]) as Dictionary).duplicate()
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_build(p_paint, p_accent)
	crew = Node3D.new()
	crew.name = "Crew"
	add_child(crew)
	for i in 2:
		var r := RigPilot.new(crew, 1.76, true)
		rig.append(r)
	rig_ok = rig[0].ok and rig[1].ok
	mo = [CrewMotion.new(), CrewMotion.new(40.0, 8.5, 95.0, 5.2, 1.0)]

# ───────────────────────── materiales ─────────────────────────
func _mat(key: String, col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

func _noise_tex(base: int, spread: int, w := 64) -> ImageTexture:
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in w:
		for x in w:
			var v := float(base + rng.randi() % spread) / 255.0
			img.set_pixel(x, y, Color(v, v, v + 0.01))
	return ImageTexture.create_from_image(img)

func _carbon_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var on := (((x / 4) + (y / 4)) % 2) == 1
			img.set_pixel(x, y, Color(0.11, 0.115, 0.125) if on else Color(0.165, 0.17, 0.185))
	return ImageTexture.create_from_image(img)

# ───────────────────────── mallas unidas por material ─────────────────────────
func _add_mesh(mesh: Mesh, xf: Transform3D, mat_key: String) -> void:
	if not _batch.has(mat_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batch[mat_key] = st
	(_batch[mat_key] as SurfaceTool).append_from(mesh, 0, xf)

func _box(size: Vector3, pos: Vector3, mat_key: String, rot := Basis.IDENTITY) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_add_mesh(bm, Transform3D(rot, pos), mat_key)

func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat_key: String, rot := Basis.IDENTITY, seg := 8) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	_add_mesh(cm, Transform3D(rot, pos), mat_key)

static func _align_y(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length() < 1e-6:
		return Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(d))

func _bar(a: Vector3, b: Vector3, r: float, mat_key: String) -> void:
	var d := b - a
	_cyl(r, r, d.length(), a + d * 0.5, mat_key, _align_y(d), 6)

func _box_between(a: Vector3, b: Vector3, w: float, t: float, mat_key: String) -> void:
	var d := b - a
	_box(Vector3(w, d.length(), t), a + d * 0.5, mat_key, _align_y(d))

## Rotación para que +z del objeto mire hacia "target" desde "pos"
static func _face(pos: Vector3, target: Vector3) -> Basis:
	return Basis.looking_at((target - pos).normalized(), Vector3.UP, true)

func _quad_mesh(a: Vector3, b: Vector3, c: Vector3, d: Vector3, v0 := 0.0, v1 := 1.0) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c, d])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, v0), Vector2(1, v0), Vector2(0, v1), Vector2(1, v1)])
	var n := (b - a).cross(c - a).normalized()
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n, n])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3, basis := Basis.IDENTITY, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else interior).add_child(mi)
	return mi

# ───────────────────────── construcción ─────────────────────────
func _build(body_col: Color, acc: Color) -> void:
	var hw: float = C["halfW"] * 1.12 # habitáculo 12 % más ancho que el real: menos ventanilla a los costados
	var eY: float = C["eyeY"]
	var eZ: float = C["eyeZ"]
	var cz: float = C["cowlZ"]
	var rY: float = C["roofY"] + 0.12 # techo 12 cm más alto que el real (más inmersivo: se ve el horizonte)
	floor_y = eY - 1.05
	eye = Vector3(xD, eY, eZ)
	# materiales
	var suede := _mat("dash", Color(0.11, 0.115, 0.125), 0.95)
	suede.albedo_texture = _noise_tex(22, 16)
	suede.uv1_scale = Vector3(4, 2, 1)
	_mat("trim", Color(0.15, 0.155, 0.17), 0.75)
	var carbon := _mat("carbon", Color(1, 1, 1), 0.4, 0.3)
	carbon.albedo_texture = _carbon_tex()
	_mat("head", Color(0.55, 0.56, 0.58), 1.0)
	_mat("cage", Color(0.84, 0.85, 0.86), 0.45, 0.35)
	_mat("paint", body_col, 0.3, 0.45)
	_mat("seat", Color(0.09, 0.095, 0.105), 0.9)
	_mat("metal", Color(0.6, 0.63, 0.66), 0.35, 0.8)
	_mat("red", Color(0.77, 0.12, 0.14), 0.5)
	_mat("acc", acc, 0.7)
	_mat("floor", Color(0.15, 0.155, 0.17), 0.9)
	var glass := _mat("glass", Color(0.68, 0.76, 0.83, 0.10), 0.04, 0.9)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mir := _mat("mirror", Color(0.09, 0.115, 0.15), 0.1, 0.0)
	mir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# parabrisas
	var cowl_y := eY - 0.30
	var wBL := Vector3(hw * 0.97, cowl_y, cz - 0.02)
	var wBR := Vector3(-hw * 0.97, cowl_y, cz - 0.02)
	var wTL := Vector3(hw * 0.9, rY - 0.03, eZ + 0.46)
	var wTR := Vector3(-hw * 0.9, rY - 0.03, eZ + 0.46)
	var gl := _mesh_node(_quad_mesh(wBL, wBR, wTL, wTR), glass, Vector3.ZERO)
	gl.name = "Parabrisas"
	# banda del parasol
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color(0.07, 0.08, 0.10, 0.82)
	strip.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	strip.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip.cull_mode = BaseMaterial3D.CULL_DISABLED
	strip.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mesh_node(_quad_mesh(wBL.lerp(wTL, 0.88), wBR.lerp(wTR, 0.88), wTL, wTR), strip, Vector3.ZERO)
	_wu = (wBR - wBL).normalized() * -1.0
	_wv = (wBL.lerp(wBR, 0.5) - wTL.lerp(wTR, 0.5)).normalized() * -1.0
	# marco: parantes A, travesaño, cowl
	_box_between(wBL + Vector3(0.03, 0, 0), wTL + Vector3(0.03, 0, 0), 0.09, 0.13, "trim")
	_box_between(wBR + Vector3(-0.03, 0, 0), wTR + Vector3(-0.03, 0, 0), 0.09, 0.13, "trim")
	_box(Vector3(2.0 * hw, 0.09, 0.16), Vector3(0, rY - 0.02, eZ + 0.44), "trim")
	# techo
	var roof_len := maxf(0.6, 1.55)
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0 * hw, roof_len)
	_add_mesh(pm, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, rY + 0.01, (eZ + 0.5 + eZ - 1.05) / 2.0)), "head")
	# capó visto desde adentro: ancho y largo, casi plano (apenas abombado)
	var hood_tex := _hood_tex(body_col, acc)
	var hood_mat := StandardMaterial3D.new()
	hood_mat.albedo_texture = hood_tex
	hood_mat.metallic = 0.45
	hood_mat.roughness = 0.3
	var hL := 1.9
	_mesh_node(_hood_mesh(2.0 * hw * 1.22, hL, hw), hood_mat, Vector3(0, cowl_y - 0.035, cz + hL / 2.0 - 0.04))
	# limpiaparabrisas
	for px in [0.28, -0.32]:
		var piv := Vector3(px, cowl_y + 0.01, cz + 0.03)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.55, 0.012)
		var blade := _mesh_node(bm, _mat("trim", Color.BLACK), piv)
		blade.visible = false
		wipers.append({"piv": piv, "blade": blade, "len": 0.55})
	# tablero (perfil extruido a lo ancho)
	var dz0 := eZ + 0.40
	var prof := PackedVector2Array([Vector2(dz0, eY - 0.78), Vector2(dz0, eY - 0.44), Vector2(dz0 + 0.008, eY - 0.375), Vector2(dz0 + 0.04, eY - 0.34), Vector2(dz0 + 0.14, eY - 0.32), Vector2(cz - 0.02, cowl_y - 0.005), Vector2(cz - 0.02, eY - 0.78)])
	_add_mesh(_extrude(prof, 2.0 * hw), Transform3D(Basis.IDENTITY, Vector3(-hw, 0, 0)), "dash")
	_box(Vector3(0.34, 0.07, 0.16), Vector3(xD, eY - 0.27, eZ + 0.56), "dash")
	# display digital (al costado del volante, se lee entero)
	var dx := xD - 0.30
	var dy := eY - 0.2
	_box(Vector3(0.25, 0.118, 0.04), Vector3(dx, dy, eZ + 0.575), "dash", _face(Vector3(dx, dy, eZ + 0.575), eye))
	_build_display(Vector3(dx, dy, eZ + 0.55))
	# cronómetro y panel de interruptores (cajas simples)
	_box(Vector3(0.19, 0.085, 0.05), Vector3(xD - 0.36, eY - 0.36, eZ + 0.60), "trim")
	_box(Vector3(0.27, 0.135, 0.02), Vector3(-0.04, eY - 0.56, eZ + 0.44), "trim", _face(Vector3(-0.04, eY - 0.56, eZ + 0.44), eye + Vector3(0, -0.25, 0)))
	for i in 8:
		var sx := -0.04 - 0.1 + float(i % 4) * 0.065
		var sy := eY - 0.56 + 0.03 - float(i / 4) * 0.055
		_box(Vector3(0.018, 0.028, 0.02), Vector3(sx, sy, eZ + 0.435), "metal" if i > 2 else "red")
	# espejos (vidrio oscuro; el reflejo real es una opción aparte)
	var my := minf(rY - 0.14, eY + 0.18)
	var mpos := Vector3(0.02, my, eZ + 0.42)
	var aim := Vector3(xD * 0.5, eY + 0.06, eZ - 0.36)
	var nrm := (aim - mpos).normalized()
	var fp := mpos - nrm * 0.02
	_box(Vector3(0.29, 0.095, 0.03), fp, "trim", _face(fp, aim))
	var qm := QuadMesh.new()
	qm.size = Vector2(0.27, 0.08)
	_mesh_node(qm, mir, mpos, _face(mpos, aim))
	_cyl(0.008, 0.008, maxf(0.04, rY - my - 0.02), Vector3(0.02, (rY + my) / 2.0, eZ + 0.44), "trim", Basis.IDENTITY, 6)
	for sd in [1.0, -1.0]:
		var sp := Vector3(sd * (hw + 0.21), eY - 0.1, cz - 0.02)
		var hn := (eye - sp).normalized()
		var hp := sp + hn * -0.04
		_box(Vector3(0.25, 0.16, 0.07), hp, "paint", _face(hp, eye))
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.22, 0.13)
		_mesh_node(q2, mir, sp, _face(sp, eye))
		_box(Vector3(0.16, 0.03, 0.05), Vector3(sd * (hw + 0.09), eY - 0.17, cz - 0.03), "paint")
	# puertas y piso
	for sd in [1.0, -1.0]:
		var dl := cz - 0.1 - (eZ - 1.0)
		_box(Vector3(0.04, eY - 0.22 - floor_y, dl), Vector3(sd * hw, (eY - 0.22 + floor_y) / 2.0, (cz - 0.1 + eZ - 1.0) / 2.0), "carbon")
		_box(Vector3(0.1, 0.05, dl), Vector3(sd * (hw - 0.03), eY - 0.21, (cz - 0.1 + eZ - 1.0) / 2.0), "dash")
	var fl := PlaneMesh.new()
	fl.size = Vector2(2.0 * hw, 2.4)
	_add_mesh(fl, Transform3D(Basis.IDENTITY, Vector3(0, floor_y, eZ)), "floor")
	# jaula antivuelco
	var r := 0.021
	var ih := hw - 0.08
	var aL0 := Vector3(ih, eY - 0.62, cz - 0.25)
	var aL1 := Vector3(ih * 0.95, rY - 0.07, eZ + 0.40)
	var aR0 := Vector3(-ih, eY - 0.62, cz - 0.25)
	var aR1 := Vector3(-ih * 0.95, rY - 0.07, eZ + 0.40)
	var mL0 := Vector3(ih, floor_y, eZ - 0.85)
	var mL1 := Vector3(ih, rY - 0.07, eZ - 0.85)
	var mR0 := Vector3(-ih, floor_y, eZ - 0.85)
	var mR1 := Vector3(-ih, rY - 0.07, eZ - 0.85)
	var bars := [[aL0, aL1], [aR0, aR1], [aL1, aR1], [mL0, mL1], [mR0, mR1], [mL1, mR1], [aL1, mL1], [aR1, mR1],
		[mL1, Vector3(mR0.x, eY - 0.5, mR0.z)], [aL1, mR1], [aR1, mL1],
		[Vector3(ih, eY - 0.55, cz - 0.3), Vector3(ih, eY - 0.40, eZ - 0.85)], [Vector3(ih, eY - 0.88, cz - 0.3), Vector3(ih, eY - 0.55, eZ - 0.85)],
		[Vector3(-ih, eY - 0.55, cz - 0.3), Vector3(-ih, eY - 0.40, eZ - 0.85)], [Vector3(-ih, eY - 0.88, cz - 0.3), Vector3(-ih, eY - 0.55, eZ - 0.85)]]
	for bb in bars:
		_bar(bb[0], bb[1], r, "cage")
	# butacas
	for sd in [1.0, -1.0]:
		var sx: float = sd * xD
		_box(Vector3(0.5, 0.86, 0.09), Vector3(sx, eY - 0.55, eZ - 0.42), "seat", Basis(Vector3.RIGHT, -0.18))
		_box(Vector3(0.5, 0.09, 0.46), Vector3(sx, eY - 0.93, eZ - 0.10), "seat")
		for side in [-1.0, 1.0]:
			_box(Vector3(0.07, 0.38, 0.2), Vector3(sx + side * 0.25, eY - 0.72, eZ - 0.26), "seat")
	# palanca secuencial y freno de mano hidráulico (se mueven)
	gear_lever = Node3D.new()
	gear_lever.position = Vector3(xD - 0.33, eY - 0.78, eZ + 0.33)
	interior.add_child(gear_lever)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.016
	cm.height = 0.42
	cm.radial_segments = 8
	_mesh_node(cm, _mat("metal", Color.WHITE), Vector3(0, 0.21, 0), Basis.IDENTITY, gear_lever)
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 10
	sm.rings = 6
	_mesh_node(sm, _mat("dash", Color.WHITE), Vector3(0, 0.43, 0), Basis.IDENTITY, gear_lever)
	hb_lever = Node3D.new()
	hb_lever.position = Vector3(xD - 0.25, eY - 0.80, eZ + 0.17)
	interior.add_child(hb_lever)
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.014
	cm2.bottom_radius = 0.018
	cm2.height = 0.5
	cm2.radial_segments = 8
	_mesh_node(cm2, _mat("red", Color.WHITE), Vector3(0, 0.25, 0), Basis.IDENTITY, hb_lever)
	var cm3 := CylinderMesh.new()
	cm3.top_radius = 0.024
	cm3.bottom_radius = 0.024
	cm3.height = 0.09
	cm3.radial_segments = 10
	_mesh_node(cm3, _mat("dash", Color.WHITE), Vector3(0, 0.48, 0), Basis.IDENTITY, hb_lever)
	# volante
	wheel_c = Vector3(xD, eY - 0.31, eZ + 0.37)
	wheel_group = Node3D.new()
	wheel_group.position = wheel_c
	wheel_group.basis = _face(wheel_c, eye + Vector3(0, -0.12, 0))
	interior.add_child(wheel_group)
	var col := CylinderMesh.new()
	col.top_radius = 0.03
	col.bottom_radius = 0.03
	col.height = 0.08
	col.radial_segments = 10
	_mesh_node(col, _mat("trim", Color.WHITE), Vector3(0, 0, -0.05), Basis(Vector3.RIGHT, PI / 2.0), wheel_group)
	rim = Node3D.new()
	wheel_group.add_child(rim)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.149
	tor.outer_radius = 0.191
	tor.rings = 24
	tor.ring_segments = 8
	_mesh_node(tor, _mat("dash", Color.WHITE), Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2.0), rim)
	var mark := BoxMesh.new()
	mark.size = Vector3(0.05, 0.03, 0.03)
	_mesh_node(mark, _mat("acc", Color.WHITE), Vector3(0, 0.17, 0), Basis.IDENTITY, rim)
	for a in [0.0, PI, -PI / 2.0]:
		var sb := BoxMesh.new()
		sb.size = Vector3(0.16, 0.028, 0.012)
		_mesh_node(sb, _mat("carbon", Color.WHITE), Vector3(cos(a) * 0.085, sin(a) * 0.085, 0.006), Basis(Vector3.BACK, a), rim)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.05
	hub.bottom_radius = 0.055
	hub.height = 0.03
	hub.radial_segments = 16
	_mesh_node(hub, _mat("carbon", Color.WHITE), Vector3(0, 0, 0.012), Basis(Vector3.RIGHT, PI / 2.0), rim)
	# se juntan las piezas fijas
	for k in _batch:
		var st: SurfaceTool = _batch[k]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mats[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		interior.add_child(mi)
	_batch.clear()

func _hood_tex(body_col: Color, acc: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(body_col)
	for y in 64:
		for x in range(23, 28):
			img.set_pixel(x, y, acc)
		for x in range(36, 41):
			img.set_pixel(x, y, acc)
	for y in range(6, 28):
		for x in range(30, 34):
			img.set_pixel(x, y, body_col.darkened(0.5))
	return ImageTexture.create_from_image(img)

func _hood_mesh(w: float, l: float, hw: float) -> ArrayMesh:
	var nx := 8
	var nz := 6
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := (float(i) / nx - 0.5) * w
			var z := (float(j) / nz - 0.5) * l
			var u := z / l + 0.5
			var y := -0.025 * (x * x) / (hw * hw) - 0.11 * u * u - 0.02 * u
			verts.append(Vector3(x, y, z))
			uvs.append(Vector2(float(i) / nx, 1.0 - float(j) / nz))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	return st.commit()

## Perfil (z, y) extruido a lo ancho (eje x)
func _extrude(profile: PackedVector2Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(profile)
	for face in [0, 1]:
		var x := 0.0 if face == 0 else width
		for k in range(0, tri.size(), 3):
			var ids := [tri[k], tri[k + 1], tri[k + 2]]
			if face == 1:
				ids = [tri[k], tri[k + 2], tri[k + 1]]
			for id in ids:
				st.set_smooth_group(-1)
				st.set_uv(Vector2(profile[id].x, profile[id].y))
				st.add_vertex(Vector3(x, profile[id].y, profile[id].x))
	var n := profile.size()
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		var a := Vector3(0, p0.y, p0.x)
		var b := Vector3(0, p1.y, p1.x)
		var c := Vector3(width, p1.y, p1.x)
		var d := Vector3(width, p0.y, p0.x)
		for v in [a, b, c, a, c, d]:
			st.set_smooth_group(-1)
			st.set_uv(Vector2(v.x, v.y))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _build_display(pos: Vector3) -> void:
	disp_vp = SubViewport.new()
	disp_vp.size = Vector2i(256, 112)
	disp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	disp_vp.transparent_bg = false
	add_child(disp_vp)
	disp_ctl = DisplayPanel.new()
	disp_ctl.size = Vector2(256, 112)
	disp_vp.add_child(disp_ctl)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.226, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = disp_vp.get_texture()
	_mesh_node(qm, m, pos, _face(pos, eye))

## Pantalla del tablero (se dibuja en un SubViewport chiquito, 10 veces por segundo)
class DisplayPanel extends Control:
	var kmh := 0.0
	var gear_txt := "N"
	var rpm_frac := 0.0
	var up_frac := 0.85
	var nitro_frac := -1.0
	var blink := false
	var rpm_val := 0.0
	var mph := false

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 256, 112), Color(0.016, 0.02, 0.024))
		var over := rpm_frac > up_frac
		for i in 15:
			var th := up_frac * 0.6 + float(i) * (up_frac * 0.42 / 15.0)
			var on := rpm_frac > th
			var col := Color(0.09, 0.09, 0.105)
			if on:
				col = Color(0.14, 0.88, 0.35) if i < 5 else (Color(1, 0.8, 0.1) if i < 10 else Color(1, 0.18, 0.24))
			if over and blink:
				col = Color(0.23, 0.63, 1.0)
			draw_circle(Vector2(17.0 + float(i) * 15.75, 9.0), 6.0, col)
		var sp := int(round(kmh * (0.621 if mph else 1.0)))
		draw_string(f, Vector2(4, 75), str(sp), HORIZONTAL_ALIGNMENT_RIGHT, 152, 58, Color.WHITE)
		draw_string(f, Vector2(163, 75), "MPH" if mph else "KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.56, 0.7, 0.84))
		draw_rect(Rect2(199, 20, 50, 60), Color(1, 0.18, 0.24) if over else Color(0.07, 0.19, 0.29))
		draw_rect(Rect2(199, 20, 50, 60), Color(0.23, 0.63, 1.0), false, 2.0)
		draw_string(f, Vector2(199, 71), gear_txt, HORIZONTAL_ALIGNMENT_CENTER, 50, 50, Color.WHITE)
		draw_rect(Rect2(7, 88, 242, 13), Color(0.11, 0.13, 0.15))
		var bc := Color(1, 0.18, 0.24) if over else (Color(1, 0.8, 0.1) if rpm_frac > up_frac * 0.85 else Color(0.23, 0.63, 1.0))
		draw_rect(Rect2(7, 88, 242.0 * clampf(rpm_frac, 0, 1), 13), bc)
		draw_string(f, Vector2(10, 99), "%d rpm" % int(rpm_val), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.91, 0.95, 1.0))
		if nitro_frac >= 0.0:
			draw_rect(Rect2(7, 104, 242.0 * clampf(nitro_frac, 0, 1), 5), Color(0.22, 0.78, 1.0))

# ───────────────────────── cuadro por cuadro ─────────────────────────
## Piloto y copiloto (con cámaras exteriores no se llama: no se dibujan)
func update_crew(dt: float, p: CarSnapshot, in_handbrake: bool, time: float, rough: float) -> void:
	if not rig_ok:
		return
	var m0: CrewMotion = mo[0]
	var m1: CrewMotion = mo[1]
	for m in mo:
		m.step_forces(dt, p)
		m.step_gear(dt, p.gear)
		m.step_limbs(dt, p)
		m.t_look += dt
	# volante: ≈ 8:1 de relación visual
	m0.steer_vis += (p.steerAngle * 7.5 - m0.steer_vis) * (1.0 - exp(-dt * 25.0))
	rim.rotation.z = m0.steer_vis
	var busy_r := maxf(CrewMotion.shift_w(m0.shift_t), m0.hbW) > 0.45
	m0.step_grip(dt, m0.steer_vis, [busy_r, false]) # la mano derecha (índice 0) es la que va a la palanca / freno de mano
	# posición de las manos en el aro
	var n := (Basis(wheel_group.basis.get_rotation_quaternion()) * Vector3(0, 0, 1))
	var wX := Vector3.UP.cross(n).normalized()
	var wY := n.cross(wX)
	var hands := []
	for i in 2:
		var ph: float = m0.phi[i]
		var gp := wheel_c + wX * (cos(ph) * CrewMotion.GRIP_R) + wY * (sin(ph) * CrewMotion.GRIP_R) + n * float(m0.lift[i])
		var rr := (gp - wheel_c).normalized()
		hands.append({"side": "Right" if i == 0 else "Left", "wrist": gp + n * 0.07 + rr * 0.045, "fdir": (rr * -0.15 + n * -0.85).normalized(), "back": (rr * 0.9 + n * 0.25).normalized()})
	# cambio de marcha: la mano derecha va a la palanca, tira (sube) o empuja (baja) y vuelve
	var sw := CrewMotion.shift_w(m0.shift_t)
	var hr: Dictionary = hands[0]
	if sw > 0.0:
		var knob: Vector3 = gear_lever.transform * Vector3(0, 0.43, 0)
		knob.z += -0.05 if m0.shift_up else 0.05
		knob.y += 0.035
		hr["wrist"] = (hr["wrist"] as Vector3).lerp(knob + Vector3(0.035, 0.02, -0.05), sw)
		hr["fdir"] = (hr["fdir"] as Vector3).lerp(Vector3(-0.2, -0.75, 0.6).normalized(), sw).normalized()
		hr["back"] = (hr["back"] as Vector3).lerp(Vector3(-0.5, 0.8, -0.2).normalized(), sw).normalized()
	# freno de mano: la derecha agarra la palanca y tira
	var hw2: float = m0.hbW * (1.0 - sw)
	if hw2 > 0.01:
		var grip: Vector3 = hb_lever.transform * Vector3(0, 0.47, 0) + Vector3(0.03, 0, 0)
		hr["wrist"] = (hr["wrist"] as Vector3).lerp(grip, hw2)
		hr["fdir"] = (hr["fdir"] as Vector3).lerp(Vector3(-0.1, -0.6, 0.8).normalized(), hw2).normalized()
		hr["back"] = (hr["back"] as Vector3).lerp(Vector3(-0.9, 0.3, 0).normalized(), hw2).normalized()
		hr["pole"] = Vector3(0.6, -1, -0.25).lerp(Vector3(0.3, -0.55, -1), hw2)
	var b: Vector3 = m0.body
	var h: Vector3 = m0.head
	var eY: float = C["eyeY"]
	var eZ: float = C["eyeZ"]
	var fy := floor_y
	var look := clampf(p.steerAngle * 0.45 + p.yawRate * 0.06, -0.35, 0.35) * (1.0 - maxf(sw, hw2) * 0.3)
	look_yaw = look
	rig[0].pose({"hips": Vector3(xD + b.x * 0.4, eY - 0.70 + b.y * 0.3, eZ - 0.11 + b.z * 0.3), "head": Vector3(xD + h.x, eY - 0.07 + h.y, eZ - 0.09 + h.z),
		"roll": h.x * 1.2, "look": look, "hands": hands, "grip": 1.2,
		"feet": [{"side": "Left", "pos": Vector3(xD + 0.13, fy + 0.13, eZ + 0.60)}, {"side": "Right", "pos": m0.right_foot(xD, fy, eZ)}]})
	var c1: CrewMotion = m1
	var cb: Vector3 = c1.body
	var ch: Vector3 = c1.head
	var x := -xD + cb.x * 0.9
	var by := eY - 0.47 + cb.y
	var bz := eZ + 0.27 + cb.z
	rig[1].pose({"hips": Vector3(-xD + cb.x * 0.4, eY - 0.70 + cb.y * 0.3, eZ - 0.13 + cb.z * 0.3), "head": Vector3(-xD + ch.x * 0.9, eY - 0.09 + ch.y, eZ - 0.07 + ch.z),
		"roll": ch.x * 1.1, "look": -0.05 + CrewMotion.co_look(c1.t_look), "grip": 0.8, "hands": c1.co_hands(x, by, bz, xD, C),
		"feet": [{"side": "Left", "pos": Vector3(-xD + 0.13, fy + 0.12, eZ + 0.55)}, {"side": "Right", "pos": Vector3(-xD - 0.13, fy + 0.12, eZ + 0.55)}]})

func update_cabin(dt: float, p: CarSnapshot, in_handbrake: bool, time: float) -> void:
	hb_lever.rotation.x = -0.32 if in_handbrake else 0.0
	var m0: CrewMotion = mo[0]
	gear_kick = maxf(0.0, gear_kick - dt * 6.0)
	if m0.shift_t > 0.14 and m0.shift_t < 0.2:
		gear_kick = 1.0
	gear_lever.rotation.x = (-1.0 if m0.shift_up else 1.0) * gear_kick * 0.25
	# limpiaparabrisas
	if raining:
		wipe_t += dt
	var ph := fmod(wipe_t, 1.4) / 1.4 if raining else 0.0
	var th := (0.5 - 0.5 * cos(ph * TAU)) * 1.65
	for w in wipers:
		(w["blade"] as Node3D).visible = raining
		if raining:
			var dir := _wu * cos(th) + _wv * sin(th)
			var piv: Vector3 = w["piv"]
			var end := piv + dir * float(w["len"])
			var d := end - piv
			(w["blade"] as Node3D).position = piv + d * 0.5
			(w["blade"] as Node3D).basis = _align_y(d)
	# display
	_disp_t -= dt
	if _disp_t <= 0.0:
		_disp_t = 0.1
		var dp := disp_ctl
		dp.kmh = absf(p.vLong) * 3.6
		dp.gear_txt = "R" if p.gear < 0 else ("N" if p.gear == 0 else str(p.gear))
		dp.mph = units == "mph"
		dp.rpm_val = p.rpm
		dp.rpm_frac = p.rpm / _max_rpm
		dp.up_frac = _up_frac
		dp.nitro_frac = (p.nitro / _nitro_cap) if _nitro_cap > 0.0 else -1.0
		dp.blink = int(time * 12.0) % 2 == 0
		dp.queue_redraw()
		disp_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

var _max_rpm := 8000.0
var _up_frac := 0.85
var _nitro_cap := 0.0

func set_engine(max_rpm: float, shift_up_rpm: float, nitro_cap: float) -> void:
	_max_rpm = max_rpm
	_up_frac = shift_up_rpm / max_rpm
	_nitro_cap = nitro_cap

## Posición y mirada de la cámara interior, en el marco del habitáculo. mode: "onboard" | "rearcabin"
## Devuelve {pos, look, up_roll, hfov}
func camera_local(mode: String, p: CarSnapshot, time: float, rough: float) -> Dictionary:
	var eY: float = C["eyeY"]
	var eZ: float = C["eyeZ"]
	var vib := (0.0025 + 0.006 * rough) * (0.3 + minf(1.0, absf(p.vLong) / 30.0))
	var nx := sin(time * 37.1) * 0.6 + sin(time * 23.7) * 0.4
	var ny := sin(time * 41.3) * 0.5 + sin(time * 29.9) * 0.5
	var H: Vector3 = (mo[0] as CrewMotion).cam
	var pos: Vector3
	var look: Vector3
	var roll := 0.0
	if mode == "onboard":
		pos = Vector3(xD + H.x + nx * vib, eY + 0.05 + H.y + ny * vib, eZ - 0.04 + H.z)
		var yl := clampf(p.steerAngle * 0.45 + p.yawRate * 0.06, -0.35, 0.35)
		look = pos + Vector3(sin(yl), -0.2, cos(yl))
		roll = -H.x * 0.9
	else:
		pos = Vector3(0.02 + nx * vib * 0.5, eY + minf(0.13, (float(C["roofY"]) - eY) * 0.55) + ny * vib * 0.5, eZ - 0.72)
		look = Vector3(0.08, eY - 0.32, eZ + 2.4)
	return {"pos": pos, "look": look, "roll": roll, "hfov": 92.0 if mode == "onboard" else 102.0}

func set_inside(v: bool, driver_head_visible: bool) -> void:
	interior.visible = v
	crew.visible = v
	if rig_ok:
		rig[0].hide_head(v and not driver_head_visible)
