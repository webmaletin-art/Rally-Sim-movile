extends Node3D
## Habitáculo de rally para las cámaras interiores. Se dibuja solo con la cámara adentro (casco / atrás de las butacas):
## desde afuera los vidrios son polarizados y no se ve a nadie.
## Está armado con formas simples pero cerradas (piso, tablero macizo, cortafuegos, puertas, techo, jaula) y pintado con
## un oscurecido falso hacia abajo (oclusión) para que no se vea plano. Todo lo fijo se junta en una malla por material.
##  · Tablero bajo y negro con puntadas, cúpula del instrumental sobre el volante con la pantalla digital y las luces de cambio
##  · Volante chico de fondo plano con la marca naranja arriba, cubo de carbono con botones de colores y perillas
##  · Consola central con la palanca secuencial, el freno de mano, el extintor y el panel de llaves
##  · Butacas de competición con apoyacabezas, jaula con tubos acolchados, redes en las ventanas, pedales de metal
##  · Piloto y copiloto con esqueleto: manos al volante por cinemática inversa, fuerzas G, el copiloto lee la hoja de notas
## Coordenadas: marco de la carrocería (+z adelante, +x izquierda, y desde el piso). El nodo va en y = -comHeight + rideOffset.

const RigPilot := preload("res://game/car/rig_pilot.gd")
const CrewMotion := preload("res://game/car/crew_motion.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const Gaze := preload("res://game/car/gaze.gd")

const CABIN := {
	"pickup": {"eyeY": 1.40, "eyeZ": 0.30, "cowlZ": 1.22, "halfW": 0.80, "roofY": 1.70},
	"t1plus": {"eyeY": 1.19, "eyeZ": -0.20, "cowlZ": 0.78, "halfW": 0.82, "roofY": 1.44},
	"truck": {"eyeY": 1.55, "eyeZ": 1.72, "cowlZ": 2.55, "halfW": 0.98, "roofY": 1.98},
	"genesis": {"eyeY": 1.08, "eyeZ": -0.12, "cowlZ": 0.98, "halfW": 0.74, "roofY": 1.33},
}
const WHEEL_R := 0.17 # radio del aro (el mismo de la versión anterior)

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
var pedal_thr: Node3D
var pedal_brk: Node3D
var notes: Node3D
var wipers: Array = []
var drops_mat: ShaderMaterial # gotas de lluvia sobre el parabrisas (las barre el limpiaparabrisas)
var drops_mesh: MeshInstance3D
var rain_wet := 0.0
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
var rear_dist := 1.08 # cámara de atrás de las butacas: metros detrás de los ojos del piloto
var ob_dist := 0.17 # cámara del casco: metros hacia atrás de la cabeza
var rear_fov := 92.0 # ángulo horizontal de las cámaras interiores (menos = más zoom)
var ob_fov := 96.0
var disp_off := 0.30 # cuánto se corre la pantalla del tablero desde delante del piloto hacia el centro del tablero (hacia su derecha)
var dome: Node3D
var gaze_p: RefCounted
var gaze_c: RefCounted
var read_w := 0.0 # cuánto está leyendo la hoja el copiloto (0 mira al frente … 1 mira la hoja)
var _body_col := Color(0.10, 0.31, 0.88)
var _acc := Color(1.0, 0.42, 0.03)
# medidas de la cabina (se calculan en _build)
var hw := 0.9
var eY := 1.19
var eZ := -0.2
var cz := 0.78
var rY := 1.5
var dz0 := 0.2
var fw := 0.83
var cowl_y := 0.9

func _init(p_type: String, p_paint := Color(0.10, 0.31, 0.88), p_accent := Color(1.0, 0.42, 0.03)) -> void:
	C = (CABIN.get(p_type, CABIN["t1plus"]) as Dictionary).duplicate()
	_body_col = p_paint
	_acc = p_accent
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_build()
	crew = Node3D.new()
	crew.name = "Crew"
	add_child(crew)
	for i in 2:
		rig.append(RigPilot.new(crew, 1.76, true))
	rig_ok = rig[0].ok and rig[1].ok
	mo = [CrewMotion.new(34.0, 8.0, 90.0, 5.0, 1.35), CrewMotion.new(36.0, 8.0, 92.0, 5.0, 1.3)]
	_build_notes()

# ───────────────────────── materiales y texturas ─────────────────────────
func _m(key: String, col: Color, rough := 0.8, metal := 0.0, tex: Texture2D = null, uv := Vector3.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv
	_mats[key] = m
	return m

func _grain_tex(base: int, spread: int, stitch: bool) -> ImageTexture:
	# grano fino (256 px, con mipmaps): de cerca no se ven cuadraditos; las costuras del tablero van cada 16 px
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in N:
		for x in N:
			var low := 0.5 + 0.5 * sin(float(x) * 0.11 + sin(float(y) * 0.07) * 2.0) * sin(float(y) * 0.13 + float(x) * 0.03)
			var v := (float(base) + float(spread) * (0.45 * low + 0.55 * rng.randf())) / 255.0
			img.set_pixel(x, y, Color(v, v, v + 0.008))
	if stitch:
		for x in range(0, N, 16):
			for k in 5:
				var c := Color(0.30, 0.30, 0.32)
				img.set_pixel(clampi(x + k, 0, N - 1), 26, c)
				img.set_pixel(clampi(x + k, 0, N - 1), 37, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _carbon_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var on := (((x / 4) + (y / 4)) % 2) == 1
			img.set_pixel(x, y, Color(0.09, 0.095, 0.105) if on else Color(0.16, 0.165, 0.18))
	return ImageTexture.create_from_image(img)

func _rubber_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var d := absf(fposmod(float(x + y), 16.0) - 8.0) + absf(fposmod(float(x - y), 16.0) - 8.0)
			var v := 0.05 + 0.03 * clampf(1.0 - d / 8.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v + 0.004))
	return ImageTexture.create_from_image(img)

## Reflejo falso de los espejos: cielo arriba, horizonte, camino oscuro abajo y una franja de pasto (no refleja el juego de verdad)
func _mirror_tex() -> ImageTexture:
	var H := 64
	var img := Image.create(8, H, false, Image.FORMAT_RGB8)
	for y in H:
		var t := float(y) / float(H - 1)
		var c: Color
		if t < 0.46:
			c = Color(0.62, 0.78, 0.93).lerp(Color(0.80, 0.88, 0.96), t / 0.46)
		elif t < 0.56:
			c = Color(0.22, 0.34, 0.20)
		else:
			c = Color(0.20, 0.21, 0.23).lerp(Color(0.09, 0.09, 0.10), (t - 0.56) / 0.44)
		for x in 8:
			img.set_pixel(x, y, c * 0.92)
	return ImageTexture.create_from_image(img)

func _net_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 32:
		for k in 2:
			img.set_pixel(i, k, Color(0.02, 0.02, 0.03, 0.55))
			img.set_pixel(k, i, Color(0.02, 0.02, 0.03, 0.55))
	return ImageTexture.create_from_image(img)

func _paper_tex() -> ImageTexture:
	var img := Image.create(64, 80, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.94, 0.90))
	for y in range(10, 80, 8):
		for x in range(4, 62):
			img.set_pixel(x, y, Color(0.66, 0.74, 0.82))
	for y in 80:
		img.set_pixel(1, y, Color(0.76, 0.12, 0.14))
		img.set_pixel(2, y, Color(0.76, 0.12, 0.14))
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

func _plane(w: float, l: float, pos: Vector3, mat_key: String, rot := Basis.IDENTITY) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, l)
	_add_mesh(pm, Transform3D(rot, pos), mat_key)

static func _align_y(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length() < 1e-6:
		return Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis.normalized(), Vector3.UP.angle_to(d))

func _bar(a: Vector3, b: Vector3, r: float, mat_key: String) -> void:
	var d := b - a
	_cyl(r, r, d.length(), a + d * 0.5, mat_key, _align_y(d), 12)

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

## Perfil (z, y) extruido a lo ancho entre x0 y x1
func _extrude(profile: PackedVector2Array, x0: float, x1: float, uv_scale := 3.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tri := Geometry2D.triangulate_polygon(profile)
	for face in [0, 1]:
		var x := x0 if face == 0 else x1
		for k in range(0, tri.size(), 3):
			var ids := [tri[k], tri[k + 1], tri[k + 2]]
			if face == 1:
				ids = [tri[k], tri[k + 2], tri[k + 1]]
			for id in ids:
				st.set_uv(Vector2(profile[id].x, profile[id].y) * uv_scale)
				st.add_vertex(Vector3(x, profile[id].y, profile[id].x))
	var n := profile.size()
	var wdt := x1 - x0
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		var a := Vector3(x0, p0.y, p0.x)
		var b := Vector3(x0, p1.y, p1.x)
		var c := Vector3(x1, p1.y, p1.x)
		var d := Vector3(x1, p0.y, p0.x)
		var ua := Vector2(0.0, 0.0)
		var ub := Vector2(0.0, p0.distance_to(p1) * uv_scale)
		var uc := Vector2(wdt * uv_scale, p0.distance_to(p1) * uv_scale)
		var ud := Vector2(wdt * uv_scale, 0.0)
		for pair in [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]:
			st.set_uv(pair[1])
			st.add_vertex(pair[0])
	st.generate_normals()
	return st.commit()

func _label(text: String, pos: Vector3, basis: Basis, size: float, col: Color, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = size / 48.0
	l.modulate = col
	l.double_sided = true
	l.shaded = false
	l.transform = Transform3D(basis, pos)
	(parent if parent != null else interior).add_child(l)
	return l

# ───────────────────────── construcción ─────────────────────────
func _build() -> void:
	hw = float(C["halfW"]) * 1.12 # habitáculo 12 % más ancho que el real: menos ventanilla a los costados
	eY = C["eyeY"]
	eZ = C["eyeZ"]
	cz = C["cowlZ"]
	rY = float(C["roofY"]) + 0.12 # techo 12 cm más alto que el real (más inmersivo: se ve el horizonte)
	floor_y = eY - 1.05
	eye = Vector3(xD, eY, eZ)
	dz0 = eZ + 0.52 # cara del tablero que mira al piloto (el volante queda adelante de ella, sin atravesarla)
	fw = cz + 0.05 # cortafuegos
	cowl_y = eY - 0.30
	# materiales
	_m("dash", Color(0.62, 0.62, 0.66), 0.95, 0.0, _grain_tex(20, 14, true), Vector3(1, 1, 1))
	_m("trim", Color(0.11, 0.115, 0.125), 0.75)
	_m("carbon", Color(1, 1, 1), 0.35, 0.3, _carbon_tex(), Vector3(2, 2, 1))
	_m("roof", Color(0.16, 0.165, 0.175), 1.0)
	_m("floor", Color(1, 1, 1), 0.95, 0.0, _rubber_tex(), Vector3(6, 6, 1))
	_m("cage", Color(0.30, 0.31, 0.34), 0.4, 0.7)
	_m("pad", Color(0.95, 0.36, 0.06), 0.85)
	_m("seat", Color(0.07, 0.07, 0.08), 0.9)
	_m("seat_acc", Color(0.62, 0.08, 0.1), 0.85)
	_m("metal", Color(0.72, 0.74, 0.78), 0.3, 0.9)
	_m("red", Color(0.80, 0.09, 0.11), 0.4)
	_m("door", Color(0.10, 0.105, 0.115), 0.85, 0.0, _grain_tex(22, 12, false), Vector3(3, 3, 1))
	_m("head", Color(0.55, 0.56, 0.58), 1.0)
	_m("paint", _body_col, 0.3, 0.45)
	_m("acc", _acc, 0.7)
	var glass := _m("glass", Color(0.68, 0.76, 0.83, 0.10), 0.04, 0.9)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mir := _m("mirror", Color(1, 1, 1), 0.1, 0.0, _mirror_tex())
	mir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_b_floor_and_walls()
	_b_dash()
	_b_console()
	_b_seats()
	_b_cage()
	_b_doors_roof()
	_b_glass_hood()
	_b_wheel()
	_b_pedals()
	_finish_batches()

func _b_floor_and_walls() -> void:
	var z0 := eZ - 1.50
	_plane(2.0 * hw, fw - z0, Vector3(0, floor_y, (fw + z0) / 2.0), "floor")
	# túnel de transmisión a lo largo y cortafuegos
	_box(Vector3(2.0 * hw, cowl_y - floor_y + 0.02, 0.03), Vector3(0, (cowl_y + floor_y) / 2.0, fw), "trim")
	# panel trasero (detrás de las butacas): sube hasta la altura de la ventanilla
	_box(Vector3(2.0 * hw, 1.0 - floor_y, 0.04), Vector3(0, (1.0 + floor_y) / 2.0, z0), "door")

## curva cuadrática entre a y b con control c (n tramos)
func _bez(a: Vector2, c: Vector2, b: Vector2, n := 5) -> Array:
	var out := []
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out

func _b_dash() -> void:
	# tablero macizo con la cara y la tapa redondeadas, cortafuegos y piso; debajo queda el hueco de las piernas
	var pts: Array = [Vector2(dz0, eY - 0.80), Vector2(dz0, eY - 0.52)]
	pts.append_array(_bez(Vector2(dz0, eY - 0.52), Vector2(dz0 - 0.005, eY - 0.34), Vector2(dz0 + 0.07, eY - 0.315), 5))
	pts.append_array(_bez(Vector2(dz0 + 0.07, eY - 0.315), Vector2(dz0 + 0.20, eY - 0.29), Vector2(cz - 0.14, cowl_y - 0.02), 5))
	pts.append_array(_bez(Vector2(cz - 0.14, cowl_y - 0.02), Vector2(cz - 0.06, cowl_y + 0.035), Vector2(fw, cowl_y + 0.012), 4))
	pts.append_array([Vector2(fw, floor_y), Vector2(fw - 0.10, floor_y), Vector2(fw - 0.30, eY - 0.80)])
	_add_mesh(_extrude(PackedVector2Array(pts), -hw, hw), Transform3D.IDENTITY, "dash")
	# pantallita de marchas y velocidad (como la de la versión HTML): chica, sobre el tablero cerca del centro, girada hacia el piloto
	dome = Node3D.new()
	interior.add_child(dome)
	var tilt := Node3D.new() # la cara del visor se inclina hacia arriba para mirar al piloto
	tilt.rotation.x = 0.58
	dome.add_child(tilt)
	var pod := BoxMesh.new()
	pod.size = Vector3(0.196, 0.087, 0.05)
	_mesh_node(pod, _mats["trim"], Vector3.ZERO, Basis.IDENTITY, tilt)
	var stalk := BoxMesh.new()
	stalk.size = Vector3(0.05, 0.05, 0.05)
	_mesh_node(stalk, _mats["trim"], Vector3(0, -0.05, 0.0), Basis.IDENTITY, dome)
	_build_display(Vector3(0, 0, -0.0258), Vector3(0, 0, -1), tilt)
	set_disp_off(disp_off)
	# panel central de llaves (inclinado hacia el piloto) y salidas de aire
	var pc := Vector3(-0.02, eY - 0.42, dz0 - 0.005)
	_box(Vector3(0.34, 0.15, 0.02), pc, "trim", _face(pc, pc + Vector3(0, 0.15, -1)))
	for i in 8:
		var sx := pc.x - 0.135 + float(i % 4) * 0.09
		var sy := pc.y + 0.035 - float(i / 4) * 0.07
		_box(Vector3(0.026, 0.038, 0.02), Vector3(sx, sy, pc.z - 0.014), "red" if i < 2 else ("metal" if i < 5 else "acc"), _face(pc, pc + Vector3(0, 0.15, -1)))
	for sd in [1.0, -1.0]:
		var vp := Vector3(sd * 0.55 + (0.0 if sd > 0 else 0.0), eY - 0.50, dz0 - 0.005)
		_box(Vector3(0.20, 0.05, 0.02), vp, "trim")
		for k in 4:
			_box(Vector3(0.17, 0.004, 0.022), vp + Vector3(0, -0.015 + k * 0.01, -0.004), "metal")
	# tira del parasol con el nombre (sobre el parabrisas)
	# instrumento del copiloto (hoja de ruta): caja con pantallita
	var rc := Vector3(-0.42, eY - 0.30, dz0 + 0.10)
	_box(Vector3(0.20, 0.10, 0.10), rc, "trim", _face(rc, rc + Vector3(0.15, 0.2, -1)))
	_label("DREAM", Vector3(-0.66, eY - 0.29, dz0 + 0.095), Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -0.5), 0.028, Color(0.9, 0.9, 0.92, 0.9))

func _b_console() -> void:
	var prof := PackedVector2Array([Vector2(eZ - 0.62, floor_y), Vector2(eZ - 0.62, 0.50), Vector2(eZ - 0.40, 0.60), Vector2(dz0 + 0.02, 0.62), Vector2(dz0 + 0.20, 0.54), Vector2(dz0 + 0.30, floor_y)])
	_add_mesh(_extrude(prof, -0.15, 0.15, 3.0), Transform3D.IDENTITY, "carbon")
	# palanca secuencial (adelante) y freno de mano (atrás): están a la derecha del piloto, sobre la consola
	gear_lever = Node3D.new()
	gear_lever.position = Vector3(0.02, 0.62, eZ + 0.35)
	interior.add_child(gear_lever)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.016
	cm.height = 0.34
	cm.radial_segments = 8
	_mesh_node(cm, _m("metal", Color.WHITE), Vector3(0, 0.17, 0), Basis.IDENTITY, gear_lever)
	var sm := SphereMesh.new()
	sm.radius = 0.028
	sm.height = 0.056
	sm.radial_segments = 10
	sm.rings = 6
	_mesh_node(sm, _m("trim", Color.WHITE), Vector3(0, 0.35, 0), Basis.IDENTITY, gear_lever)
	var boot := CylinderMesh.new()
	boot.top_radius = 0.035
	boot.bottom_radius = 0.06
	boot.height = 0.06
	boot.radial_segments = 10
	_mesh_node(boot, _m("trim", Color.WHITE), Vector3(0, 0.03, 0), Basis.IDENTITY, gear_lever)
	hb_lever = Node3D.new()
	hb_lever.position = Vector3(0.02, 0.62, eZ + 0.17)
	interior.add_child(hb_lever)
	var hb := CylinderMesh.new()
	hb.top_radius = 0.013
	hb.bottom_radius = 0.017
	hb.height = 0.30
	hb.radial_segments = 8
	_mesh_node(hb, _m("red", Color.WHITE), Vector3(0, 0.15, 0), Basis.IDENTITY, hb_lever)
	var hg := CylinderMesh.new()
	hg.top_radius = 0.022
	hg.bottom_radius = 0.022
	hg.height = 0.08
	hg.radial_segments = 10
	_mesh_node(hg, _m("trim", Color.WHITE), Vector3(0, 0.32, 0), Basis.IDENTITY, hb_lever)
	# extintor entre las butacas
	_cyl(0.045, 0.045, 0.30, Vector3(0.0, 0.62 + 0.15, eZ - 0.45), "red", Basis.IDENTITY, 12)
	_cyl(0.02, 0.02, 0.05, Vector3(0.0, 0.62 + 0.325, eZ - 0.45), "metal", Basis.IDENTITY, 8)

## contorno redondeado (x, y) de un rectángulo w×h con las esquinas de arriba muy redondas
func _round_rect(w: float, h: float, rt: float, rb: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw2 := w / 2.0
	for i in range(0, 9): # esquina inferior derecha
		var a := -PI / 2.0 + PI / 2.0 * float(i) / 8.0
		pts.append(Vector2(hw2 - rb + cos(a) * rb, rb + sin(a) * rb))
	for i in range(0, 9): # esquina superior derecha
		var a := PI / 2.0 * float(i) / 8.0
		pts.append(Vector2(hw2 - rt + cos(a) * rt, h - rt + sin(a) * rt))
	for i in range(0, 9): # esquina superior izquierda
		var a := PI / 2.0 + PI / 2.0 * float(i) / 8.0
		pts.append(Vector2(-hw2 + rt + cos(a) * rt, h - rt + sin(a) * rt))
	for i in range(0, 9): # esquina inferior izquierda
		var a := PI + PI / 2.0 * float(i) / 8.0
		pts.append(Vector2(-hw2 + rb + cos(a) * rb, rb + sin(a) * rb))
	return pts

## contorno (x, y) extruido en z entre z0 y z1
func _extrude_z(profile: PackedVector2Array, z0: float, z1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tri := Geometry2D.triangulate_polygon(profile)
	for face in [0, 1]:
		var z := z0 if face == 0 else z1
		for k in range(0, tri.size(), 3):
			var ids := [tri[k], tri[k + 1], tri[k + 2]]
			if face == 1:
				ids = [tri[k], tri[k + 2], tri[k + 1]]
			for id in ids:
				st.set_uv(profile[id] * 3.0)
				st.add_vertex(Vector3(profile[id].x, profile[id].y, z))
	var n := profile.size()
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		for v in [Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z0), Vector3(p1.x, p1.y, z1), Vector3(p0.x, p0.y, z0), Vector3(p1.x, p1.y, z1), Vector3(p0.x, p0.y, z1)]:
			st.set_smooth_group(0) # el borde redondeado se ve suave
			st.set_uv(Vector2(v.x, v.y) * 3.0)
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _capsule(r: float, h: float, pos: Vector3, mat_key: String, rot := Basis.IDENTITY) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 4
	_add_mesh(cm, Transform3D(rot, pos), mat_key)

func _b_seats() -> void:
	var lean := Basis(Vector3.RIGHT, -0.20)
	for sd in [1.0, -1.0]:
		var sx: float = sd * xD
		# cáscara del respaldo con la parte de arriba redondeada (inclinada hacia atrás)
		var shell := _extrude_z(_round_rect(0.40, 0.56, 0.16, 0.03), -0.030, 0.030)
		_add_mesh(shell, Transform3D(lean, Vector3(sx, 0.40, eZ - 0.47)), "seat")
		var pad := _extrude_z(_round_rect(0.30, 0.44, 0.12, 0.02), 0.030, 0.045)
		_add_mesh(pad, Transform3D(lean, Vector3(sx, 0.44, eZ - 0.47)), "seat_acc")
		# laterales acolchados (cilindros redondeados) del torso y de los muslos
		for side in [-1.0, 1.0]:
			_capsule(0.032, 0.36, Vector3(sx + side * 0.205, 0.60, eZ - 0.42), "seat", lean)
			_capsule(0.028, 0.34, Vector3(sx + side * 0.205, 0.385, eZ - 0.12), "seat", Basis(Vector3.RIGHT, PI / 2.0))
		# base: perfil con el borde delantero levantado
		var base_prof := PackedVector2Array([Vector2(eZ - 0.36, 0.31), Vector2(eZ + 0.08, 0.31), Vector2(eZ + 0.11, 0.35), Vector2(eZ + 0.09, 0.385), Vector2(eZ - 0.05, 0.365), Vector2(eZ - 0.36, 0.375)])
		_add_mesh(_extrude(base_prof, sx - 0.19, sx + 0.19, 3.0), Transform3D.IDENTITY, "seat")
		_add_mesh(_extrude(PackedVector2Array([Vector2(eZ - 0.30, 0.372), Vector2(eZ + 0.06, 0.362), Vector2(eZ + 0.065, 0.375), Vector2(eZ - 0.30, 0.386)]), sx - 0.05, sx + 0.05, 3.0), Transform3D.IDENTITY, "seat_acc")
		# apoyacabezas redondo con dos orejas
		_capsule(0.042, 0.20, Vector3(sx, 0.99, eZ - 0.56), "seat", Basis(Vector3.FORWARD, PI / 2.0) * Basis(Vector3.RIGHT, -0.10))
		for side in [-1.0, 1.0]:
			_capsule(0.030, 0.12, Vector3(sx + side * 0.115, 0.985, eZ - 0.51), "seat", lean * Basis(Vector3.UP, -side * 0.3))
		_box(Vector3(0.14, 0.018, 0.004), Vector3(sx, 0.995, eZ - 0.598), "seat_acc", Basis(Vector3.RIGHT, -0.10))
		# cinturones: tiras a los costados y hebilla
		for side in [-1.0, 1.0]:
			_box(Vector3(0.045, 0.010, 0.30), Vector3(sx + side * 0.13, 0.392, eZ - 0.14), "seat_acc")
		_box(Vector3(0.06, 0.025, 0.045), Vector3(sx, 0.395, eZ + 0.03), "metal")

func _b_cage() -> void:
	var r := 0.024
	var ih := hw - 0.07
	var top := rY - 0.07
	var zm := eZ - 0.80 # arco principal detrás de las butacas
	var za := eZ + 0.40 # arco delantero (parantes del parabrisas)
	var zb := cz - 0.30 # pie del arco delantero
	for s in [1.0, -1.0]:
		var x: float = s * ih
		_bar(Vector3(x, floor_y, zm), Vector3(x, top, zm), r, "cage")
		_bar(Vector3(x, top, zm), Vector3(x * 0.95, top, za), r, "cage") # larguero de techo
		_bar(Vector3(x, 0.60, zb), Vector3(x * 0.95, top, za), r, "cage") # diagonal del parante
		_bar(Vector3(x, 0.78, zb), Vector3(x, 0.66, zm), r, "cage") # barras de puerta
		_bar(Vector3(x, 0.52, zb), Vector3(x, 0.40, zm), r, "cage")
		_bar(Vector3(x, 0.78, zb), Vector3(x, 0.40, zm), r * 0.85, "cage") # cruz
		# acolchado naranja donde pega la cabeza
		var dpar := (Vector3(x * 0.95, top, za) - Vector3(x, 0.60, zb)).normalized()
		_bar(Vector3(x * 0.95, top, za) - dpar * 0.40, Vector3(x * 0.95, top, za), r * 1.7, "pad")
		_bar(Vector3(x, top, za - 0.55), Vector3(x * 0.99, top, za - 0.10), r * 1.7, "pad")
		_bar(Vector3(x, top - 0.02, zm + 0.5), Vector3(x, top, zm + 0.05), r * 1.7, "pad")
	_bar(Vector3(-ih, top, zm), Vector3(ih, top, zm), r, "cage")
	_bar(Vector3(-ih * 0.95, top, za), Vector3(ih * 0.95, top, za), r, "cage")
	_bar(Vector3(-ih, top, (za + zm) / 2.0), Vector3(ih, top, (za + zm) / 2.0), r, "cage")
	_bar(Vector3(-ih, 0.62, zm), Vector3(ih, 0.62, zm), r, "cage")
	# nudos esféricos en las uniones (sin estos las barras se ven cortadas en cuadrado) y refuerzos
	for sd in [1.0, -1.0]:
		var xx: float = sd * ih
		for jp in [Vector3(xx, top, zm), Vector3(xx * 0.95, top, za), Vector3(xx, 0.60, zb), Vector3(xx, 0.78, zb), Vector3(xx, 0.66, zm), Vector3(xx, 0.62, zm)]:
			var sm := SphereMesh.new()
			sm.radius = r * 1.25
			sm.height = r * 2.5
			sm.radial_segments = 10
			sm.rings = 6
			_add_mesh(sm, Transform3D(Basis.IDENTITY, jp), "cage")
		# cartela triangular en el codo del arco principal
		_bar(Vector3(xx, top - 0.30, zm), Vector3(xx, top, zm + 0.30), r * 0.8, "cage")

func _b_doors_roof() -> void:
	var z_back := eZ - 1.50
	var z_front := cz - 0.12
	for sd in [1.0, -1.0]:
		var x: float = sd * (hw - 0.015)
		var dl := z_front - z_back
		var zc := (z_front + z_back) / 2.0
		_box(Vector3(0.03, 0.97 - floor_y, dl), Vector3(x, (0.97 + floor_y) / 2.0, zc), "door")
		_box(Vector3(0.07, 0.04, dl), Vector3(x - sd * 0.02, 0.98, zc), "trim") # borde de la ventanilla
		_box(Vector3(0.09, 0.07, 0.55), Vector3(x - sd * 0.04, 0.72, eZ - 0.05), "trim") # apoyabrazos
		_box(Vector3(0.03, 0.16, 0.06), Vector3(x - sd * 0.03, 0.88, eZ + 0.18), "red") # tira para cerrar la puerta
		_box(Vector3(0.04, 0.14, 0.34), Vector3(x - sd * 0.03, 0.50, eZ + 0.10), "trim") # bolsillo
		_cyl(0.07, 0.07, 0.03, Vector3(x - sd * 0.03, 0.42, eZ + 0.55), "trim", Basis(Vector3.FORWARD, PI / 2.0), 14) # parlante
		# red de la ventanilla
		var nm := _m("net", Color(1, 1, 1, 1), 1.0, 0.0, _net_tex(), Vector3(26, 14, 1))
		nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var q := _quad_mesh(Vector3(x, 1.0, eZ - 0.55), Vector3(x, 1.0, eZ + 0.42), Vector3(x, rY - 0.12, eZ - 0.55), Vector3(x, rY - 0.12, eZ + 0.42))
		_mesh_node(q, nm, Vector3.ZERO)
		# el triángulo delantero de la ventana (entre el parante del parabrisas y el borde de la puerta) también lleva red
		var tri := _quad_mesh(Vector3(x, 1.0, eZ + 0.42), Vector3(x, 1.0, z_front), Vector3(x, rY - 0.12, eZ + 0.46), Vector3(x, rY - 0.12, eZ + 0.46))
		_mesh_node(tri, nm, Vector3.ZERO)
		_bar(Vector3(x, 1.0, eZ + 0.42), Vector3(x, 1.0, z_front), 0.012, "trim") # marco del triángulo
		_bar(Vector3(x, 1.0, z_front), Vector3(x, rY - 0.12, eZ + 0.46), 0.012, "trim")
	# techo: revestimiento oscuro con escotilla de emergencia y luz de mapa
	var roof_len := eZ + 0.5 - (eZ - 1.50)
	_plane(2.0 * hw, roof_len, Vector3(0, rY + 0.01, (eZ + 0.5 + eZ - 1.50) / 2.0), "roof", Basis(Vector3.RIGHT, PI))
	_box(Vector3(0.50, 0.012, 0.42), Vector3(0.0, rY - 0.003, eZ - 0.30), "trim")
	_box(Vector3(0.10, 0.02, 0.06), Vector3(0.0, rY - 0.015, eZ + 0.10), "metal")
	# travesaño del parabrisas
	_box(Vector3(2.0 * hw, 0.07, 0.10), Vector3(0, rY - 0.03, eZ + 0.45), "trim")

func _b_glass_hood() -> void:
	var wBL := Vector3(hw * 0.97, cowl_y, cz - 0.02)
	var wBR := Vector3(-hw * 0.97, cowl_y, cz - 0.02)
	var wTL := Vector3(hw * 0.9, rY - 0.03, eZ + 0.46)
	var wTR := Vector3(-hw * 0.9, rY - 0.03, eZ + 0.46)
	_mesh_node(_quad_mesh(wBL, wBR, wTL, wTR), _mats["glass"], Vector3.ZERO)
	# borde negro del parabrisas (serigrafía) y tira del parasol con el nombre
	var frit := StandardMaterial3D.new()
	frit.albedo_color = Color(0.02, 0.02, 0.025, 0.95)
	frit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frit.cull_mode = BaseMaterial3D.CULL_DISABLED
	frit.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# franja superior (parasol)
	_mesh_node(_quad_mesh(wBL.lerp(wTL, 0.87), wBR.lerp(wTR, 0.87), wTL, wTR), frit, Vector3.ZERO)
	# laterales y base
	_mesh_node(_quad_mesh(wBL, wBL.lerp(wBR, 0.045), wTL, wTL.lerp(wTR, 0.045)), frit, Vector3.ZERO)
	_mesh_node(_quad_mesh(wBR.lerp(wBL, 0.045), wBR, wTR.lerp(wTL, 0.045), wTR), frit, Vector3.ZERO)
	_mesh_node(_quad_mesh(wBL, wBR, wBL.lerp(wTL, 0.06), wBR.lerp(wTR, 0.06)), frit, Vector3.ZERO)
	var strip_c: Vector3 = ((wBL.lerp(wTL, 0.935) + wBR.lerp(wTR, 0.935)) * 0.5)
	var nrm := ((wBL - wTL).cross(wBR - wTL)).normalized()
	if nrm.z > 0.0:
		nrm = -nrm
	_label("DREAM  RACING  TEAM", strip_c + Vector3(0, 0, -0.01), _face(strip_c, eye), 0.026, Color(1, 1, 1, 0.95))
	# parantes A finos
	_box_between(wBL + Vector3(0.03, 0, 0), wTL + Vector3(0.03, 0, 0), 0.06, 0.08, "trim")
	_box_between(wBR + Vector3(-0.03, 0, 0), wTR + Vector3(-0.03, 0, 0), 0.06, 0.08, "trim")
	_wu = (wBR - wBL).normalized() * -1.0
	_wv = (wBL.lerp(wBR, 0.5) - wTL.lerp(wTR, 0.5)).normalized() * -1.0
	# capó visto desde adentro: ancho y largo, casi plano (apenas abombado), con las dos franjas
	var hood_mat := StandardMaterial3D.new()
	hood_mat.albedo_texture = _hood_tex()
	hood_mat.metallic = 0.45
	hood_mat.roughness = 0.3
	var hL := 1.9
	var hood_pos := Vector3(0, cowl_y - 0.035, cz + hL / 2.0 - 0.04)
	_mesh_node(_hood_mesh(2.0 * hw * 1.22, hL, hw), hood_mat, hood_pos)
	# detalles del capó: toma de aire central, cuatro pasadores y bisagras (desde adentro se ve un capó de verdad)
	var scoop := BoxMesh.new()
	scoop.size = Vector3(0.30, 0.05, 0.36)
	var sc_u := 0.34
	var sc_y := -0.11 * sc_u * sc_u - 0.02 * sc_u
	_mesh_node(scoop, hood_mat, hood_pos + Vector3(0, sc_y + 0.025, (sc_u - 0.5) * hL), Basis(Vector3.RIGHT, 0.1))
	var inlet := _m("inlet", Color(0.01, 0.01, 0.012), 0.9)
	var iq := QuadMesh.new()
	iq.size = Vector2(0.26, 0.035)
	_mesh_node(iq, inlet, hood_pos + Vector3(0, sc_y + 0.02, (sc_u - 0.5) * hL + 0.182), Basis(Vector3.UP, PI))
	for px2 in [0.56, -0.56]:
		for pu in [0.2, 0.62]:
			var py2: float = -0.025 * (px2 * px2) / (hw * hw) - 0.11 * pu * pu - 0.02 * pu
			var pin := CylinderMesh.new()
			pin.top_radius = 0.016
			pin.bottom_radius = 0.016
			pin.height = 0.025
			pin.radial_segments = 10
			_mesh_node(pin, _mats["metal"], hood_pos + Vector3(px2, py2 + 0.012, (pu - 0.5) * hL))
			var loop := TorusMesh.new()
			loop.inner_radius = 0.012
			loop.outer_radius = 0.017
			loop.rings = 10
			loop.ring_segments = 6
			_mesh_node(loop, _mats["metal"], hood_pos + Vector3(px2, py2 + 0.03, (pu - 0.5) * hL), Basis(Vector3.RIGHT, PI / 2.0))
	# limpiaparabrisas (estacionados sobre la base del parabrisas; se mueven con la lluvia)
	for px in [0.30, -0.34]:
		var piv := Vector3(px, cowl_y + 0.012, cz + 0.02)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.016, 0.55, 0.010)
		var blade := _mesh_node(bm, _mats["trim"], piv)
		wipers.append({"piv": piv, "blade": blade, "len": 0.55})
	_build_drops(wBL, wBR, wTL, wTR)
	# espejo interior
	var my := minf(rY - 0.16, eY + 0.16)
	var mpos := Vector3(0.02, my, eZ + 0.44)
	var aim := Vector3(xD * 0.5, eY + 0.02, eZ - 0.36)
	var nn := (aim - mpos).normalized()
	var fp := mpos - nn * 0.02
	_box(Vector3(0.22, 0.07, 0.025), fp, "trim", _face(fp, aim))
	var qm := QuadMesh.new()
	qm.size = Vector2(0.20, 0.055)
	_mesh_node(qm, _mats["mirror"], mpos, _face(mpos, aim))
	_cyl(0.007, 0.007, maxf(0.04, rY - my - 0.02), Vector3(0.02, (rY + my) / 2.0, eZ + 0.45), "trim", Basis.IDENTITY, 6)
	# espejos laterales
	for sd in [1.0, -1.0]:
		var sp := Vector3(sd * (hw + 0.21), eY - 0.1, cz - 0.02)
		var hp := sp + (eye - sp).normalized() * -0.04
		var cap := CapsuleMesh.new()
		cap.radius = 0.06
		cap.height = 0.26
		cap.radial_segments = 14
		cap.rings = 4
		var cap_basis := _face(hp, eye) * Basis(Vector3.FORWARD, PI / 2.0) * Basis(Vector3.RIGHT, 0.0)
		_mesh_node(cap, _mats["paint"], hp, cap_basis * Basis.from_scale(Vector3(1.0, 1.0, 0.55)))
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.21, 0.12)
		_mesh_node(q2, _mats["mirror"], sp, _face(sp, eye))
		_box(Vector3(0.16, 0.03, 0.05), Vector3(sd * (hw + 0.09), eY - 0.17, cz - 0.03), "paint")

const DROPS_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float wet = 0.0;
uniform float tm = 0.0;
uniform vec2 gsize = vec2(1.6, 0.6);
uniform vec2 piv_a = vec2(0.5, 0.0);
uniform vec2 piv_b = vec2(1.1, 0.0);
uniform vec2 wu2 = vec2(1.0, 0.0);
uniform vec2 wv2 = vec2(0.0, 1.0);
uniform float phase = 0.0;
uniform float wipe_on = 0.0;
uniform float blade_len = 0.58;
uniform float sweep = 1.65;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// segundos desde que la escobilla pasó por este punto (99 = nunca la barre)
float since_wipe(vec2 pm, vec2 piv) {
	vec2 d = pm - piv;
	vec2 l = vec2(dot(d, wu2), dot(d, wv2));
	float a = atan(l.y, l.x);
	float r = length(l);
	if (a < 0.0 || a > sweep || r > blade_len) return 99.0;
	float p1 = acos(clamp(1.0 - 2.0 * a / sweep, -1.0, 1.0)) / 6.2831853;
	float p2 = 1.0 - p1;
	return min(fract(phase - p1), fract(phase - p2)) * 1.4;
}

void fragment() {
	vec2 pm = UV * gsize;
	float age = 99.0;
	if (wipe_on > 0.5) age = min(since_wipe(pm, piv_a), since_wipe(pm, piv_b));
	// después de pasar la escobilla el vidrio queda limpio y las gotas vuelven de a poco
	float v = smoothstep(0.15, 1.6, age) * wet;
	float cell_s = 0.026;
	vec2 g = pm / cell_s;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float h = h21(id);
	vec2 c = vec2(0.25 + 0.5 * h21(id + 7.3), 0.25 + 0.5 * h21(id + 3.1));
	float rad = 0.12 + 0.20 * h21(id + 1.7);
	float dist = length(f - c);
	float on = step(h, v * 0.85); // más gotas cuanto más mojado
	float drop = smoothstep(rad, rad * 0.55, dist) * on;
	float hi = smoothstep(rad * 0.8, 0.0, length(f - c + vec2(0.05, -0.05) * rad * 3.0)) * on;
	// llovizna fina (niebla de gotas chicas) que le saca nitidez a la vista
	float mist = 0.10 * v * (0.6 + 0.4 * h21(floor(pm * 140.0)));
	vec3 col = mix(vec3(0.46, 0.53, 0.60), vec3(0.85, 0.92, 1.0), hi);
	ALBEDO = col;
	ALPHA = clamp(drop * 0.50 + mist, 0.0, 0.85);
}
"""

func _build_drops(wBL: Vector3, wBR: Vector3, wTL: Vector3, wTR: Vector3) -> void:
	var ex := (wBR - wBL).normalized()
	var ey := (wTL - wBL).normalized()
	var nrm := ex.cross(ey).normalized()
	if nrm.dot(eye - wBL) < 0.0:
		nrm = -nrm
	var sh := Shader.new()
	sh.code = DROPS_SHADER
	drops_mat = ShaderMaterial.new()
	drops_mat.shader = sh
	drops_mat.render_priority = 2
	var piv_a: Vector3 = wipers[0]["piv"]
	var piv_b: Vector3 = wipers[1]["piv"]
	drops_mat.set_shader_parameter("gsize", Vector2((wBR - wBL).length(), (wTL - wBL).length()))
	drops_mat.set_shader_parameter("piv_a", Vector2((piv_a - wBL).dot(ex), (piv_a - wBL).dot(ey)))
	drops_mat.set_shader_parameter("piv_b", Vector2((piv_b - wBL).dot(ex), (piv_b - wBL).dot(ey)))
	drops_mat.set_shader_parameter("wu2", Vector2(_wu.dot(ex), _wu.dot(ey)))
	drops_mat.set_shader_parameter("wv2", Vector2(_wv.dot(ex), _wv.dot(ey)))
	var off := nrm * 0.004
	drops_mesh = _mesh_node(_quad_mesh(wBL + off, wBR + off, wTL + off, wTR + off), drops_mat, Vector3.ZERO)
	drops_mesh.visible = false

func _hood_tex() -> ImageTexture:
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	img.fill(_body_col)
	var dark := _body_col.darkened(0.55)
	# dos franjas de color con borde suave
	for y in N:
		for x in N:
			var fx := float(x) / float(N)
			var d1 := minf(absf(fx - 0.40), absf(fx - 0.60))
			if fx > 0.37 and fx < 0.43 or fx > 0.57 and fx < 0.63:
				var edge := smoothstep(0.0, 0.006, 0.03 - absf(fx - (0.40 if fx < 0.5 else 0.60)))
				img.set_pixel(x, y, _body_col.lerp(_acc, edge))
	# líneas de panel (juntas) y rejilla de salida de aire
	var seam := _body_col.darkened(0.45)
	for y in N:
		for k in 2:
			img.set_pixel(clampi(int(N * 0.06) + k, 0, N - 1), y, seam)
			img.set_pixel(clampi(int(N * 0.94) + k, 0, N - 1), y, seam)
	for x in N:
		for k in 2:
			img.set_pixel(x, clampi(int(N * 0.62) + k, 0, N - 1), seam)
	for r in 7: # persianas
		var yy := int(N * 0.12) + r * 9
		for x in range(int(N * 0.44), int(N * 0.56)):
			for k in 4:
				img.set_pixel(x, yy + k, dark)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _hood_mesh(w: float, l: float, hwid: float) -> ArrayMesh:
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
			var y := -0.025 * (x * x) / (hwid * hwid) - 0.11 * u * u - 0.02 * u
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

# ───────────────────────── volante ─────────────────────────
func _b_wheel() -> void:
	wheel_c = Vector3(xD, eY - 0.31, eZ + 0.31)
	wheel_group = Node3D.new()
	wheel_group.position = wheel_c
	wheel_group.basis = _face(wheel_c, eye + Vector3(0, -0.12, 0))
	interior.add_child(wheel_group)
	# columna
	var col := CylinderMesh.new()
	col.top_radius = 0.035
	col.bottom_radius = 0.045
	col.height = 0.16
	col.radial_segments = 12
	_mesh_node(col, _mats["trim"], Vector3(0, -0.02, -0.09), Basis(Vector3.RIGHT, PI / 2.0), wheel_group)
	rim = Node3D.new()
	wheel_group.add_child(rim)
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.65
	_mesh_node(_rim_mesh(), rm, Vector3.ZERO, Basis.IDENTITY, rim)
	# cubo de carbono con botones de colores, perillas y una pantallita
	var hub := BoxMesh.new()
	hub.size = Vector3(0.17, 0.095, 0.026)
	var cm := _mats["carbon"] as StandardMaterial3D
	_mesh_node(hub, cm, Vector3(0, 0.0, 0.004), Basis.IDENTITY, rim)
	for sx in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(0.09, 0.06, 0.022)
		_mesh_node(wing, cm, Vector3(sx * 0.125, 0.0, 0.0), Basis.IDENTITY, rim)
	var btn := CylinderMesh.new()
	btn.top_radius = 0.0075
	btn.bottom_radius = 0.0075
	btn.height = 0.01
	btn.radial_segments = 8
	var cols := [Color(0.9, 0.1, 0.1), Color(0.1, 0.8, 0.25), Color(1, 0.8, 0.1), Color(0.15, 0.5, 1.0), Color(1, 0.4, 0.05), Color(0.9, 0.9, 0.9), Color(0.9, 0.15, 0.6), Color(0.1, 0.8, 0.8)]
	for i in 8:
		var bm := StandardMaterial3D.new()
		bm.albedo_color = cols[i]
		bm.emission_enabled = true
		bm.emission = cols[i]
		bm.emission_energy_multiplier = 0.35
		var bx := (float(i % 4) - 1.5) * 0.029
		var by := 0.019 - float(i / 4) * 0.035
		_mesh_node(btn, bm, Vector3(bx, by, 0.0175), Basis(Vector3.RIGHT, PI / 2.0), rim)
	for sx in [-1.0, 1.0]:
		var kn := CylinderMesh.new()
		kn.top_radius = 0.012
		kn.bottom_radius = 0.014
		kn.height = 0.014
		kn.radial_segments = 10
		_mesh_node(kn, _mats["metal"], Vector3(sx * 0.118, 0.0, 0.020), Basis(Vector3.RIGHT, PI / 2.0), rim)

	_build_cluster()

## Tablero de instrumentos detrás del volante: tacómetro analógico con aguja y barra de luces de cambio (se encienden con las vueltas)
var cluster_vp: SubViewport
var cluster_face: ClusterFace
var cluster_needle: Node3D
var cluster_leds: Array = []
func _build_cluster() -> void:
	var cl := Node3D.new()
	cl.position = Vector3(0.0, 0.085, -0.085) # sobre el cubo, un poco más atrás que el aro: se ve a través del volante
	cl.rotation.x = 0.1
	wheel_group.add_child(cl)
	var box := BoxMesh.new()
	box.size = Vector3(0.19, 0.085, 0.045)
	_mesh_node(box, _mats["trim"], Vector3.ZERO, Basis.IDENTITY, cl)
	var hoodm := BoxMesh.new()
	hoodm.size = Vector3(0.20, 0.012, 0.06) # visera del instrumental
	_mesh_node(hoodm, _mats["trim"], Vector3(0, 0.046, 0.012), Basis(Vector3.RIGHT, -0.25), cl)
	cluster_vp = SubViewport.new()
	cluster_vp.size = Vector2i(384, 160)
	cluster_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(cluster_vp)
	cluster_face = ClusterFace.new()
	cluster_face.size = Vector2(384, 160)
	cluster_vp.add_child(cluster_face)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.178, 0.0742)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_texture = cluster_vp.get_texture()
	_mesh_node(qm, fm, Vector3(0, -0.002, 0.0232), Basis.IDENTITY, cl)
	# aguja (pivote en el centro del tacómetro: a la derecha de la cara)
	cluster_needle = Node3D.new()
	cluster_needle.position = Vector3(0.037, -0.004, 0.0245)
	cl.add_child(cluster_needle)
	var nb := BoxMesh.new()
	nb.size = Vector3(0.0026, 0.030, 0.001)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(1.0, 0.35, 0.05)
	nm.emission_enabled = true
	nm.emission = Color(1.0, 0.35, 0.05)
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_node(nb, nm, Vector3(0, 0.014, 0), Basis.IDENTITY, cluster_needle)
	var hubm := CylinderMesh.new()
	hubm.top_radius = 0.004
	hubm.bottom_radius = 0.004
	hubm.height = 0.002
	hubm.radial_segments = 10
	_mesh_node(hubm, _mats["metal"], Vector3(0, 0, 0.0005), Basis(Vector3.RIGHT, PI / 2.0), cluster_needle)
	# luces de cambio (9) en el borde de arriba
	var cols := [Color(0.1, 1.0, 0.3), Color(0.1, 1.0, 0.3), Color(0.1, 1.0, 0.3), Color(1.0, 0.85, 0.1), Color(1.0, 0.85, 0.1), Color(1.0, 0.85, 0.1), Color(1.0, 0.15, 0.1), Color(1.0, 0.15, 0.1), Color(1.0, 0.15, 0.1)]
	for i in 9:
		var lm := BoxMesh.new()
		lm.size = Vector3(0.012, 0.006, 0.003)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = (cols[i] as Color).darkened(0.8)
		_mesh_node(lm, mat, Vector3((float(i) - 4.0) * 0.0165, 0.0425, 0.024), Basis.IDENTITY, cl)
		cluster_leds.append({"mat": mat, "col": cols[i]})

## Cara del tacómetro (se dibuja una sola vez en un SubViewport): arco con números cada mil vueltas, zona roja y rótulos
class ClusterFace extends Control:
	var max_rpm := 8000.0
	var up_frac := 0.85

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.03), true)
		var c := Vector2(size.x * 0.715, size.y * 0.55)
		var r := 66.0
		draw_arc(c, r + 5.0, deg_to_rad(-230.0), deg_to_rad(50.0), 64, Color(0.2, 0.22, 0.26), 2.0, true)
		var thousands := int(max_rpm / 1000.0)
		for i in range(0, thousands * 2 + 1):
			var f := float(i) / float(thousands * 2)
			var ang := deg_to_rad(-130.0 + 260.0 * f - 90.0)
			var major := i % 2 == 0
			var col := Color(0.9, 0.92, 0.95) if f < up_frac else Color(1.0, 0.25, 0.2)
			var p0 := c + Vector2(cos(ang), sin(ang)) * (r - (14.0 if major else 8.0))
			var p1 := c + Vector2(cos(ang), sin(ang)) * r
			draw_line(p0, p1, col, 3.0 if major else 1.5, true)
			if major:
				var tp := c + Vector2(cos(ang), sin(ang)) * (r - 28.0)
				draw_string(font, tp + Vector2(-6, 7), str(i / 2), HORIZONTAL_ALIGNMENT_CENTER, 14, 20, col)
		draw_arc(c, r - 3.0, deg_to_rad(-130.0 + 260.0 * up_frac - 90.0), deg_to_rad(130.0 - 90.0), 24, Color(1.0, 0.2, 0.15, 0.9), 5.0, true)
		draw_string(font, c + Vector2(-26, 46), "RPM x1000", HORIZONTAL_ALIGNMENT_CENTER, 52, 11, Color(0.6, 0.65, 0.72))
		# franja izquierda: indicadores
		draw_string(font, Vector2(14, 34), "DREAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.48, 0.1))
		draw_string(font, Vector2(14, 58), "RACING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.75, 0.82))
		draw_rect(Rect2(14, 84, 100, 3), Color(0.25, 0.28, 0.32), true)
		for k in 4:
			draw_circle(Vector2(26.0 + float(k) * 26.0, 112.0), 6.0, [Color(0.1, 0.5, 0.2), Color(0.6, 0.45, 0.05), Color(0.5, 0.1, 0.1), Color(0.1, 0.3, 0.55)][k])

## Aro circular y grueso: tubo que recorre un círculo; la marca naranja de las 12 va pintada
func _rim_mesh() -> ArrayMesh:
	var n := 96
	var seg := 14
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var nrms := PackedVector3Array()
	var flat := -1e9 # aro completamente circular
	var path: Array = []
	for i in n:
		var th := TAU * float(i) / float(n)
		var p := Vector2(cos(th), sin(th)) * WHEEL_R
		p.y = maxf(p.y, flat)
		path.append(p)
	for i in n:
		var p: Vector2 = path[i]
		var q: Vector2 = path[(i + 1) % n]
		var pr: Vector2 = path[(i + n - 1) % n]
		var tan2 := (q - pr).normalized()
		var out2 := Vector2(tan2.y, -tan2.x) # hacia afuera del aro
		var th := atan2(p.y, p.x)
		var grip := 0.024 + 0.003 * absf(cos(th)) # grueso, un poco más en las manos (3 y 9)
		var mark := 1.0 if (absf(wrapf(th - PI / 2.0, -PI, PI)) < 0.11 and p.y > 0.0) else 0.0
		for j in seg:
			var a := TAU * float(j) / float(seg)
			var off_out := cos(a) * grip
			var off_z := sin(a) * grip
			var v := Vector3(p.x + out2.x * off_out, p.y + out2.y * off_out, off_z)
			verts.append(v)
			nrms.append(Vector3(out2.x * cos(a), out2.y * cos(a), sin(a)).normalized())
			cols.append(Color(1.0, 0.42, 0.04) if mark > 0.5 else (Color(0.05, 0.05, 0.055) if absf(cos(th)) < 0.55 else Color(0.03, 0.03, 0.035)))
	for i in n:
		var i2 := (i + 1) % n
		for j in seg:
			var j2 := (j + 1) % seg
			var a := i * seg + j
			var b := i2 * seg + j
			var c := i2 * seg + j2
			var d := i * seg + j2
			idx.append_array([a, b, c, a, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _b_pedals() -> void:
	pedal_thr = Node3D.new()
	pedal_thr.position = Vector3(xD - 0.11, floor_y + 0.06, eZ + 0.70)
	interior.add_child(pedal_thr)
	var tb := BoxMesh.new()
	tb.size = Vector3(0.055, 0.15, 0.012)
	_mesh_node(tb, _mats["metal"], Vector3(0, 0.07, 0), Basis.IDENTITY, pedal_thr)
	pedal_brk = Node3D.new()
	pedal_brk.position = Vector3(xD - 0.01, floor_y + 0.06, eZ + 0.72)
	interior.add_child(pedal_brk)
	var bb := BoxMesh.new()
	bb.size = Vector3(0.10, 0.13, 0.012)
	_mesh_node(bb, _mats["metal"], Vector3(0, 0.065, 0), Basis.IDENTITY, pedal_brk)
	pedal_thr.rotation.x = 0.55
	pedal_brk.rotation.x = 0.55
	_box(Vector3(0.18, 0.12, 0.012), Vector3(xD + 0.17, floor_y + 0.07, eZ + 0.60), "metal", Basis(Vector3.RIGHT, 0.75))

## reparte las mallas fijas: una por material, con un oscurecido falso hacia abajo y hacia los costados
func _finish_batches() -> void:
	for k in _batch:
		if OS.get_environment("CAB_SKIP") == k:
			continue
		var st: SurfaceTool = _batch[k]
		var m: ArrayMesh = st.commit()
		var arr := m.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(vs.size())
		for i in vs.size():
			var v := vs[i]
			var ao := lerpf(0.42, 1.0, smoothstep(floor_y - 0.05, floor_y + 0.85, v.y))
			ao *= 1.0 - 0.22 * smoothstep(hw * 0.62, hw, absf(v.x))
			ao *= 1.0 - 0.18 * smoothstep(fw - 0.5, fw, v.z) * (1.0 - smoothstep(0.85, 1.15, v.y))
			cols[i] = Color(ao, ao, ao, 1.0)
		arr[Mesh.ARRAY_COLOR] = cols
		var m2 := ArrayMesh.new()
		m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m2
		mi.material_override = _mats[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		interior.add_child(mi)
	_batch.clear()

# ───────────────────────── pantalla del tablero ─────────────────────────
func _build_display(pos: Vector3, normal: Vector3, parent: Node3D) -> void:
	disp_vp = SubViewport.new()
	disp_vp.size = Vector2i(256, 112)
	disp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	disp_vp.transparent_bg = false
	add_child(disp_vp)
	disp_ctl = DisplayPanel.new()
	disp_ctl.size = Vector2(256, 112)
	disp_vp.add_child(disp_ctl)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.176, 0.077)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = disp_vp.get_texture()
	_mesh_node(qm, m, pos, Basis.looking_at(normal, Vector3.UP, true), parent)

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


# ───────────────────────── hoja de notas del copiloto ─────────────────────────
func _build_notes() -> void:
	notes = Node3D.new()
	crew.add_child(notes)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.20, 0.25)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _paper_tex()
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_node(qm, m, Vector3.ZERO, Basis.IDENTITY, notes)
	var lines := ["L4  >  100", "R3  <  60", "cresta  ¡ojo!", "R5 corta", "recta 300"]
	for i in lines.size():
		_label(lines[i], Vector3(-0.085, 0.09 - float(i) * 0.045, 0.002), Basis.IDENTITY, 0.014, Color(0.10, 0.16, 0.55), notes).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

# ───────────────────────── cuadro por cuadro ─────────────────────────
## Piloto y copiloto (con cámaras exteriores no se llama: no se dibujan)
func update_crew(dt: float, p: CarSnapshot, in_handbrake: bool, time: float, rough: float) -> void:
	if gaze_p == null:
		gaze_p = Gaze.new("pilot", int(Time.get_ticks_usec()) & 0xffff)
		gaze_c = Gaze.new("copilot", (int(Time.get_ticks_usec()) >> 3) & 0xffff)
	gaze_p.update(dt)
	gaze_c.update(dt)
	if not rig_ok:
		return
	var m0: CrewMotion = mo[0]
	var m1: CrewMotion = mo[1]
	for m in mo:
		m.step_forces(dt, p)
		m.step_gear(dt, p.gear)
		m.step_limbs(dt, p)
		m.t_look += dt
	# camino de tierra: los cuerpos vibran un poco más
	var loose := 0.0
	for i in 4:
		if p.wheel_fx[i * 8] > 0.5 and int(p.wheel_fx[i * 8 + 1]) != 0:
			loose = 1.0
	var sp := minf(1.0, absf(p.vLong) / 30.0)
	var jit := (0.0016 + 0.004 * loose) * sp
	var jy := sin(time * 43.0) * 0.6 + sin(time * 27.0 + 1.1) * 0.4
	var jx := sin(time * 37.0 + 0.4) * 0.6 + sin(time * 21.0) * 0.4
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
	var gr := WHEEL_R
	for i in 2:
		var ph: float = m0.phi[i]
		var gp := wheel_c + wX * (cos(ph) * gr) + wY * (sin(ph) * gr) + n * float(m0.lift[i])
		var rr := (gp - wheel_c).normalized()
		hands.append({"side": "Right" if i == 0 else "Left", "wrist": gp + n * 0.075 + rr * 0.05, "fdir": (rr * -0.15 + n * -0.85).normalized(), "back": (rr * 0.9 + n * 0.25).normalized(), "pole": Vector3(0.55, -0.55, -0.30)})
	# cambio de marcha: la mano derecha va a la palanca, tira (sube) o empuja (baja) y vuelve
	var sw := CrewMotion.shift_w(m0.shift_t)
	var hr: Dictionary = hands[0]
	if sw > 0.0:
		var knob: Vector3 = gear_lever.transform * Vector3(0, 0.35, 0)
		knob.z += -0.05 if m0.shift_up else 0.05
		hr["wrist"] = (hr["wrist"] as Vector3).lerp(knob + Vector3(0.05, 0.075, -0.075), sw)
		hr["fdir"] = (hr["fdir"] as Vector3).lerp(Vector3(-0.2, -0.75, 0.6).normalized(), sw).normalized()
		hr["back"] = (hr["back"] as Vector3).lerp(Vector3(-0.5, 0.8, -0.2).normalized(), sw).normalized()
		hr["pole"] = (hr["pole"] as Vector3).lerp(Vector3(0.45, -0.25, -0.6), sw)
	# freno de mano: la derecha agarra la palanca y tira
	var hw2: float = m0.hbW * (1.0 - sw)
	if hw2 > 0.01:
		var grip: Vector3 = hb_lever.transform * Vector3(0, 0.32, 0) + Vector3(0.05, 0.06, -0.05)
		hr["wrist"] = (hr["wrist"] as Vector3).lerp(grip, hw2)
		hr["fdir"] = (hr["fdir"] as Vector3).lerp(Vector3(-0.1, -0.6, 0.8).normalized(), hw2).normalized()
		hr["back"] = (hr["back"] as Vector3).lerp(Vector3(-0.9, 0.3, 0).normalized(), hw2).normalized()
		hr["pole"] = (hr["pole"] as Vector3).lerp(Vector3(0.35, -0.2, -0.8), hw2)
	var b: Vector3 = m0.body
	var h: Vector3 = m0.head
	var fy := floor_y
	var look := clampf(p.steerAngle * 0.45 + p.yawRate * 0.06, -0.35, 0.35) * (1.0 - maxf(sw, hw2) * 0.3)
	look_yaw = look
	# miradas con vida: casi nada cuando el volante está girando fuerte (el piloto mira la curva)
	var gk := 1.0 - clampf(absf(look) * 3.5, 0.0, 1.0)
	var g_yaw: float = gaze_p.yaw_out() * gk
	var g_pit: float = gaze_p.pitch_out() * gk
	# el piloto mira el mundo: la cabeza compensa un poco la inclinación del cuerpo (mantiene el horizonte)
	var brake_nod := clampf(-p.aLong * 0.004, -0.02, 0.05)
	rig[0].pose({"hips": Vector3(xD + b.x * 0.4 + jx * jit * 0.3, eY - 0.70 + b.y * 0.3 + jy * jit * 0.5 + 0.003 * sin(time * 1.6), eZ - 0.11 + b.z * 0.3), "head": Vector3(xD + h.x, eY - 0.07 + h.y + brake_nod, eZ - 0.09 + h.z),
		"roll": h.x * 1.2 - b.x * 0.5, "look": look + g_yaw, "look_y": -0.1 - brake_nod * 4.0 + g_pit, "hands": hands, "grip": 1.2 + 0.45 * maxf(sw, hw2),
		"feet": [{"side": "Left", "pos": Vector3(xD + 0.13, fy + 0.13, eZ + 0.60)}, {"side": "Right", "pos": m0.right_foot(xD, fy, eZ)}]})
	# pedales
	pedal_thr.rotation.x = 0.55 + (0.0 if m0.onBrake > 0.5 else m0.press * 0.30)
	pedal_brk.rotation.x = 0.55 + (m0.press * 0.30 if m0.onBrake > 0.5 else 0.0)
	# copiloto: lee la hoja (sostiene el borde con la izquierda), levanta la vista al frente cada tanto, se ataja al frenar fuerte
	var c1: CrewMotion = m1
	var cb: Vector3 = c1.body
	var ch: Vector3 = c1.head
	var want_read := 1.0 if (gaze_c.is_reading() and c1.brace < 0.2) else 0.0
	read_w += (want_read - read_w) * (1.0 - exp(-dt * (5.0 if want_read > 0.5 else 3.0)))
	var sheet := Vector3(-xD + cb.x * 0.9 + 0.03, eY - 0.50 + cb.y + 0.03 * read_w, eZ + 0.12 + cb.z + 0.03 * read_w)
	var x := sheet.x
	var by := sheet.y - 0.05
	var bz := sheet.z + 0.03
	# la hoja: inclinada hacia los ojos del copiloto, la agita la vibración
	notes.position = sheet + Vector3(jx * jit * 0.5, jy * jit * 0.4, 0.0)
	notes.basis = Basis(Vector3.RIGHT, -0.85 + cb.z * 1.5 + 0.10 * read_w)
	var co_h: Array = c1.co_hands(x, by, bz, xD, C)
	# izquierda del copiloto = borde izquierdo de la hoja (lado +x); derecha = sigue las líneas
	co_h[0]["pole"] = Vector3(0.5, -0.6, -0.3)
	co_h[1]["pole"] = Vector3(0.5, -0.6, -0.3)
	var ck := CrewMotion.co_look(c1.t_look)
	var look_c: float = -0.05 + (ck + float(gaze_c.yaw_out())) * (1.0 - read_w) * 0.8
	rig[1].pose({"hips": Vector3(-xD + cb.x * 0.4, eY - 0.70 + cb.y * 0.3 + jy * jit * 0.4, eZ - 0.13 + cb.z * 0.3), "head": Vector3(-xD + ch.x * 0.9, eY - 0.09 + ch.y - 0.045 * read_w, eZ - 0.07 + ch.z + 0.05 * read_w),
		"roll": ch.x * 1.1, "look": look_c, "look_y": -0.10 - 0.95 * read_w + float(gaze_c.pitch_out()) * (1.0 - read_w), "grip": 0.8, "hands": co_h,
		"feet": [{"side": "Left", "pos": Vector3(-xD + 0.13, fy + 0.12, eZ + 0.55)}, {"side": "Right", "pos": Vector3(-xD - 0.13, fy + 0.12, eZ + 0.55)}]})

func update_cabin(dt: float, p: CarSnapshot, in_handbrake: bool, time: float) -> void:
	hb_lever.rotation.x = -0.32 if in_handbrake else 0.0
	var m0: CrewMotion = mo[0]
	gear_kick = maxf(0.0, gear_kick - dt * 6.0)
	if m0.shift_t > 0.14 and m0.shift_t < 0.2:
		gear_kick = 1.0
	gear_lever.rotation.x = (-1.0 if m0.shift_up else 1.0) * gear_kick * 0.25
	# limpiaparabrisas: estacionados abajo; con lluvia barren
	if raining:
		wipe_t += dt
	var ph := fmod(wipe_t, 1.4) / 1.4 if raining else 0.0
	var th := (0.5 - 0.5 * cos(ph * TAU)) * 1.65
	for w in wipers:
		var dir := _wu * cos(th) + _wv * sin(th)
		var piv: Vector3 = w["piv"]
		var end := piv + dir * float(w["len"])
		var d := end - piv
		(w["blade"] as Node3D).position = piv + d * 0.5
		(w["blade"] as Node3D).basis = _align_y(d)
	# lluvia sobre el parabrisas: se moja de a poco; con el limpiaparabrisas andando se despeja al pasar la escobilla
	if drops_mat != null:
		rain_wet = move_toward(rain_wet, 1.0 if raining else 0.0, dt * (0.18 if raining else 0.5))
		drops_mesh.visible = rain_wet > 0.01
		if drops_mesh.visible:
			drops_mat.set_shader_parameter("wet", rain_wet)
			drops_mat.set_shader_parameter("phase", ph)
			drops_mat.set_shader_parameter("wipe_on", 1.0 if raining else 0.0)
	# tacómetro de atrás del volante: aguja y luces de cambio
	if cluster_needle != null:
		var fr := clampf(p.rpm / _max_rpm, 0.0, 1.0)
		cluster_needle.rotation.z = lerp_angle(cluster_needle.rotation.z, deg_to_rad(130.0 - 260.0 * fr), clampf(dt * 22.0, 0.0, 1.0))
		var flash := p.rpm / _max_rpm >= _up_frac and int(time * 14.0) % 2 == 0
		for i in cluster_leds.size():
			var on := fr > 0.58 + float(i) * (_up_frac - 0.58) / 9.0
			var cc: Color = cluster_leds[i]["col"]
			(cluster_leds[i]["mat"] as StandardMaterial3D).albedo_color = cc if (on and (fr < _up_frac or flash)) else cc.darkened(0.82)
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
	if cluster_face != null:
		cluster_face.max_rpm = max_rpm
		cluster_face.up_frac = _up_frac
		cluster_face.queue_redraw()
		cluster_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_nitro_cap = nitro_cap

## Posición y mirada de la cámara interior, en el marco del habitáculo. mode: "onboard" | "rearcabin"
## Devuelve {pos, look, roll, hfov}
func camera_local(mode: String, p: CarSnapshot, time: float, rough: float) -> Dictionary:
	var vib := (0.0025 + 0.006 * rough) * (0.3 + minf(1.0, absf(p.vLong) / 30.0))
	var nx := sin(time * 37.1) * 0.6 + sin(time * 23.7) * 0.4
	var ny := sin(time * 41.3) * 0.5 + sin(time * 29.9) * 0.5
	var H: Vector3 = (mo[0] as CrewMotion).cam
	var pos: Vector3
	var look: Vector3
	var roll := 0.0
	if mode == "onboard":
		# un poco más atrás y arriba que la cabeza: se ven los antebrazos y más tablero; mira apenas hacia la ventanilla del piloto
		pos = Vector3(xD + H.x + nx * vib, eY + 0.075 + H.y + ny * vib, eZ - ob_dist + H.z)
		var yl := clampf(p.steerAngle * 0.45 + p.yawRate * 0.06, -0.35, 0.35) + 0.075
		look = pos + Vector3(sin(yl), -0.17, cos(yl))
		roll = -H.x * 0.9
	else:
		# atrás de las butacas, más lejos: se ven los respaldos, las cabezas y el tablero
		pos = Vector3(0.02 + nx * vib * 0.5, eY + minf(0.14, (float(C["roofY"]) - eY) * 0.55) + ny * vib * 0.5, eZ - rear_dist)
		look = Vector3(0.06, eY - 0.32, eZ + 2.4)
	if OS.has_environment("CAB_POS"): # depuración: cámara libre dentro de la cabina  CAB_POS=x,y,z CAB_LOOK=x,y,z
		var a := OS.get_environment("CAB_POS").split_floats(",")
		var b := OS.get_environment("CAB_LOOK").split_floats(",")
		pos = Vector3(a[0], a[1], a[2])
		look = Vector3(b[0], b[1], b[2])
	return {"pos": pos, "look": look, "roll": roll, "hfov": ob_fov if mode == "onboard" else rear_fov}

func set_disp_off(v: float) -> void:
	disp_off = v
	if dome != null:
		var top_y := eY - 0.31 + 0.075
		dome.position = Vector3(xD - v, top_y, dz0 + 0.17)
		# mira hacia el piloto (la cara del visor apunta a -z local)
		dome.rotation = Vector3(0, atan2(-(xD - dome.position.x), -(eZ - dome.position.z)), 0)

func set_inside(v: bool, driver_head_visible: bool) -> void:
	interior.visible = v
	crew.visible = v and not OS.has_environment("CAB_NOCREW")
	if rig_ok:
		rig[0].hide_head(v and not driver_head_visible)
