extends Node3D
## Dibujo del auto: carrocería y ruedas del GLB del Volt (los mismos modelos de la versión HTML), siguiendo a la física.
## Estructura igual a VehicleVisual de js/main.js: el grupo está en el centro de masa; la carrocería baja hasta el piso;
## cada rueda cuelga de su punto de suspensión y gira con la velocidad angular real de la física.

const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarParts := preload("res://game/car/car_parts.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")
const VOLT_WHEEL_R := 0.40 # radio de la rueda con la que se modeló el GLB

var V: VehicleParams
var body: Node3D
var wheels: Array = [] # {steer, spin, front, angle}
var lo := false
var shell: Node3D
var tire_mat: StandardMaterial3D
var parts: CarParts # ruedas, frenos y suspensión por código (autos con carrocería propia); null = Volt
var meta: Dictionary = {} # medidas del GLB propio (models/cars/<id>.json)
var vt := ""
var mods: Dictionary = {} # piezas modulares instaladas (state["mods"]): se ponen ANTES de setup()
var mod_nodes: Array = []
var _own_mats: Array = [] # [{mi, surface, out, inn}] materiales de la carrocería propia (de afuera y de adentro)
var blob: MeshInstance3D # sombrita suave en el piso (no hace falta una sombra de verdad)
static var _blob_mat: StandardMaterial3D

const FINISH := {"gloss": [0.45, 0.35], "metal": [0.9, 0.24], "matte": [0.08, 0.88], "chrome": [1.0, 0.07]} # metálico, rugosidad

func setup(p_params: VehicleParams, p_lo: bool, paint: Color, rim: Color, finish := "gloss") -> void:
	V = p_params
	lo = p_lo
	vt = str(V.visualType)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.position.y = -V.comHeight + V.rideOffset
	var suffix := "_lo" if lo else ""
	if has_own_model(vt):
		_setup_own(paint, rim, finish)
		return
	var body_scene: PackedScene = load("res://game/models/volt_body%s.glb" % suffix)
	shell = body_scene.instantiate()
	body.add_child(shell)
	# la carrocería del Volt se ajusta a la distancia entre ejes y a la trocha de cada auto (si no, las ruedas quedan corridas del chasis)
	var wb_ref := 2.9
	var wf_ref := 0.48
	var sz := V.wheelBase / wb_ref
	var sx := V.trackF / 2.02
	var c_ref := wb_ref * (1.0 - 2.0 * wf_ref) * 0.5 # centro entre ejes del Volt (adelante − atrás)/2
	var c_car := V.wheelBase * (1.0 - 2.0 * V.weightFront) * 0.5
	shell.scale = Vector3(sx, sqrt(sx * sz), sz)
	shell.position.z = c_car - c_ref * sz
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			if nm == "glass":
				# vidrio polarizado: desde afuera no se ve la tripulación (ni se dibuja); además no hace falta transparencia
				m.albedo_color = Color(0.035, 0.045, 0.06)
				m.metallic = 0.6
				m.roughness = 0.1
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, m)
			else:
				# carrocería: el sombreador de pintura (los colores de vértice del modelo vienen azules: se usa solo su brillo)
				mi.set_surface_override_material(s, _paint_material(0, paint, Color(1.0, 0.5, 0.1), finish))
	_make_blob()
	# ruedas
	var wheel_scene: PackedScene = load("res://game/models/volt_wheel%s.glb" % suffix)
	var R := V.wheelRadius
	var a := V.wheelBase * (1.0 - V.weightFront)
	var b := V.wheelBase * V.weightFront
	var defs := [[V.trackF / 2.0, a, true], [-V.trackF / 2.0, a, true], [V.trackR / 2.0, -b, false], [-V.trackR / 2.0, -b, false]]
	tire_mat = StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.08, 0.085, 0.09)
	tire_mat.roughness = 0.93
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.18, 0.2, 0.22)
	rim_mat.metallic = 0.85
	rim_mat.roughness = 0.28
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = rim
	ring_mat.metallic = 0.35
	ring_mat.roughness = 0.3
	for d in defs:
		var steer := Node3D.new()
		steer.position = Vector3(d[0], R, d[1])
		body.add_child(steer)
		var spin := Node3D.new()
		steer.add_child(spin)
		var w: Node3D = wheel_scene.instantiate()
		var k := R / VOLT_WHEEL_R
		w.scale = Vector3(-k if d[0] < 0.0 else k, k, k)
		spin.add_child(w)
		for mi in _mesh_instances(w):
			var mesh2: Mesh = mi.mesh
			for s in mesh2.get_surface_count():
				var mt := mesh2.surface_get_material(s)
				var n2 := mt.resource_name if mt else ""
				mi.set_surface_override_material(s, tire_mat if n2 == "tire" else (ring_mat if n2 == "ring" else rim_mat))
		wheels.append({"steer": steer, "spin": spin, "front": d[2], "angle": 0.0})

## ¿Tiene carrocería propia (GLB en models/cars) además de las ruedas por código?
static func has_own_model(id: String) -> bool:
	return id != "" and ResourceLoader.exists("res://game/models/cars/%s.glb" % id)

static func load_meta(id: String) -> Dictionary:
	var f := "res://game/models/cars/%s.json" % id
	if not FileAccess.file_exists(f):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	return d if d is Dictionary else {}

func _setup_own(paint: Color, rim: Color, finish: String) -> void:
	meta = load_meta(vt)
	var suffix := "_lo" if lo else ""
	var scene: PackedScene = load("res://game/models/cars/%s%s.glb" % [vt, suffix])
	shell = scene.instantiate()
	body.add_child(shell)
	_apply_own_mats(0, paint, Color(1.0, 0.5, 0.1), finish, Color(0.95, 0.95, 0.93))
	_make_blob()
	parts = CarParts.new()
	var safe := VehicleCustomization.sanitize(mods, vt, V, meta) if not mods.is_empty() else {}
	parts.build(body, V, meta, lo, rim, VehicleCustomization.wheel_override(vt, V, meta, safe))
	mod_nodes = VehicleCustomization.attach(body, vt, V, meta, safe, lo)
	VehicleCustomization.tint(mod_nodes, paint)
	parts.set_colors({"rim": rim.to_html(false)})
	wheels = parts.wheels
	tire_mat = parts.mats["tire"]

## Pone la pintura (afuera: doble cara · adentro: solo caras de frente, así con la cámara interior se ve el capó real y no el techo)
func _apply_own_mats(pattern: int, paint: Color, accent: Color, finish: String, accent2: Color) -> void:
	_own_mats.clear()
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			if nm == "glass":
				mi.set_surface_override_material(s, _glass_material())
				continue
			var mo := _own_paint(pattern, paint, accent, finish, accent2, false)
			var mi2 := _own_paint(pattern, paint, accent, finish, accent2, true)
			mi.set_surface_override_material(s, mo)
			_own_mats.append({"mi": mi, "s": s, "out": mo, "in": mi2})

## Con la cámara adentro del auto: se esconden las ruedas y la suspensión y la carrocería se dibuja solo por fuera
func set_inside(v: bool) -> void:
	if parts == null:
		body.visible = not v
		return
	body.visible = true
	for c in body.get_children():
		c.visible = (c == shell) or not v
	for e in _own_mats:
		(e["mi"] as MeshInstance3D).set_surface_override_material(int(e["s"]), e["in"] if v else e["out"])

## Material de pintura de una carrocería propia: oscurecido de vértice tal cual y vidrios dibujados por el sombreador
func _own_paint(pattern: int, paint: Color, accent: Color, finish: String, accent2: Color, inside := false) -> ShaderMaterial:
	var sm := _paint_material(pattern, paint, accent, finish, accent2, inside)
	sm.set_shader_parameter("vk", 1.0)
	var g: Variant = meta.get("glass")
	if g is Dictionary:
		var gd: Dictionary = g
		sm.set_shader_parameter("glass_on", 1.0)
		var ws: Array = gd["ws"]
		var rg: Array = gd["rg"]
		var cab := float(gd["cab_hw"])
		sm.set_shader_parameter("ws", Vector4(ws[0][0], ws[0][1], ws[1][0], ws[1][1]))
		sm.set_shader_parameter("rg", Vector4(rg[0][0], rg[0][1], rg[1][0], rg[1][1]))
		sm.set_shader_parameter("ws_w", Vector2(cab * float(gd.get("ws_w0", 1.22)), cab * float(gd.get("ws_w1", 0.92))))
		sm.set_shader_parameter("rg_w", Vector2(cab * float(gd.get("rg_w0", 0.9)), cab * float(gd.get("rg_w1", 1.1))))
		var pl: Array = gd["poly"]
		sm.set_shader_parameter("sp0", Vector4(pl[0][0], pl[0][1], pl[1][0], pl[1][1]))
		sm.set_shader_parameter("sp1", Vector4(pl[2][0], pl[2][1], pl[3][0], pl[3][1]))
		sm.set_shader_parameter("cab_hw", cab)
		if inside:
			sm.set_shader_parameter("clip", Vector2(float(ws[0][0]) + 0.03, cab * 1.05))
	return sm

static func _glass_material() -> StandardMaterial3D:
	# vidrio polarizado: desde afuera no se ve la tripulación (ni se dibuja); además no hace falta transparencia
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.035, 0.045, 0.06)
	m.metallic = 0.6
	m.roughness = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Colores de piezas desde el perfil: {tire, rim, spring, caliper, disc}
func set_parts(pp: Dictionary) -> void:
	if parts != null:
		parts.set_colors(pp)

## Rotulados: dibujos de pintura calculados sobre la carrocería (no hace falta textura): franjas, banda lateral, la «onda»
## de Dream Racing, bicolor y el rally con el círculo del número en las puertas. 0 = liso.
const LIVERIES := ["Liso", "Franjas", "Banda lateral", "Onda Dream", "Bicolor", "Rally"]
const LIVERY_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 paint : source_color = vec3(0.1, 0.3, 0.9);
uniform vec3 accent : source_color = vec3(1.0, 0.5, 0.1);
uniform vec3 accent2 : source_color = vec3(0.95, 0.95, 0.93);
uniform int pattern = 0;
uniform float metal = 0.45;
uniform float rough = 0.35;
uniform float vk = 8.77;
uniform float glass_on = 0.0;
uniform vec4 ws = vec4(0.0); // parabrisas: base (z, y) y borde superior (z, y) sobre el eje central
uniform vec2 ws_w = vec2(0.5, 0.4); // semiancho en la base y arriba
uniform vec4 rg = vec4(0.0); // luneta: borde superior y base
uniform vec2 rg_w = vec2(0.4, 0.5);
uniform vec4 sp0 = vec4(0.0); // ventanillas laterales: polígono (z, y) de 4 puntos
uniform vec4 sp1 = vec4(0.0);
uniform vec2 clip = vec2(-1000.0, 0.0); // vista interior: no se dibuja la carrocería dentro de la cabina (z menor que clip.x y |x| menor que clip.y)
uniform float cab_hw = 0.6;
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// vidrio plano inclinado (parabrisas o luneta): trapecio con esquinas redondeadas sobre la recta (z, y) de seg
float glass_strip(vec3 p, vec3 n, vec4 seg, vec2 w) {
	vec2 a = seg.xy;
	vec2 d = seg.zw - a;
	float L = max(length(d), 0.001);
	vec2 u = d / L;
	vec2 nn = vec2(-u.y, u.x);
	if (nn.y < 0.0) nn = -nn;
	vec2 q = p.zy - a;
	float t = dot(q, u);
	float dist = dot(q, nn);
	float hw = mix(w.x, w.y, clamp(t / L, 0.0, 1.0));
	float sd = rbox(vec2(p.x, t - L * 0.5), vec2(hw, L * 0.5), 0.10);
	float plane = 1.0 - smoothstep(0.05, 0.08, abs(dist));
	float align = smoothstep(0.78, 0.92, dot(n, vec3(0.0, nn.y, nn.x)));
	return (1.0 - smoothstep(-0.006, 0.004, sd)) * plane * align;
}
// ventanillas de los costados: polígono convexo con esquinas redondeadas (máximo suave de las distancias a los lados)
float glass_side(vec3 p, vec3 n) {
	vec2 v0 = sp0.xy; vec2 v1 = sp0.zw; vec2 v2 = sp1.xy; vec2 v3 = sp1.zw;
	vec2 c = (v0 + v1 + v2 + v3) * 0.25;
	float acc = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 a = i == 0 ? v0 : (i == 1 ? v1 : (i == 2 ? v2 : v3));
		vec2 b = i == 0 ? v1 : (i == 1 ? v2 : (i == 2 ? v3 : v0));
		vec2 e = b - a;
		vec2 nn = normalize(vec2(-e.y, e.x));
		if (dot(nn, a - c) < 0.0) nn = -nn;
		acc += exp((dot(p.zy - a, nn) + 0.035) * 30.0);
	}
	float d = log(acc) / 30.0;
	float lat = smoothstep(0.35, 0.6, abs(n.x)) * smoothstep(0.55 * cab_hw, 0.7 * cab_hw, abs(p.x));
	return (1.0 - smoothstep(-0.004, 0.004, d)) * lat;
}
float band(float v, float a, float b) {
	float w = max(fwidth(v), 0.002) * 1.2;
	return smoothstep(a - w, a + w, v) * (1.0 - smoothstep(b - w, b + w, v));
}
void fragment() {
	if (lp.z < clip.x && abs(lp.x) < clip.y) {
		discard;
	}
	vec3 c = paint;
	float side = smoothstep(0.35, 0.55, abs(ln.x));
	float top = smoothstep(0.25, 0.5, ln.y);
	float ax = abs(lp.x);
	if (pattern == 1) {
		float m = (band(ax, 0.10, 0.30) * top) + band(ax, 0.10, 0.30) * smoothstep(0.3, 0.6, abs(ln.z)) * step(0.5, lp.y);
		c = mix(c, accent, clamp(m, 0.0, 1.0));
		c = mix(c, accent2, band(ax, 0.32, 0.36) * top);
	} else if (pattern == 2) {
		float y0 = 0.52 + (lp.z - 0.2) * 0.06;
		c = mix(c, accent, band(lp.y, y0, y0 + 0.17) * side);
		c = mix(c, accent2, band(lp.y, y0 + 0.21, y0 + 0.25) * side);
	} else if (pattern == 3) {
		float wave = 0.62 + 0.18 * sin(lp.z * 1.5 + 0.6);
		c = mix(c, accent, band(lp.y, wave - 0.09, wave + 0.04) * side);
		c = mix(c, accent2, band(lp.y, wave + 0.07, wave + 0.10) * side);
		c = mix(c, accent, band(ax, 0.0, 0.05) * top * step(0.4, lp.z));
	} else if (pattern == 4) {
		float k = lp.z * 0.9 - lp.y * 0.7;
		c = mix(c, accent, smoothstep(0.05, 0.12, k));
		c = mix(c, accent2, band(k, -0.03, 0.03));
	} else if (pattern == 5) {
		vec2 d = vec2(lp.z - 0.15, lp.y - 0.78);
		float r = length(d);
		float disc = (1.0 - smoothstep(0.30, 0.31, r)) * side;
		float ring = band(r, 0.30, 0.36) * side;
		c = mix(c, accent2, disc);
		c = mix(c, accent, ring);
		c = mix(c, accent, band(ax, 0.0, 0.22) * top * step(0.0, lp.z));
	}
	// el modelo trae la pintura original (azul) en los colores de vértice: se usa solo cuánto brilla cada parte
	float k = clamp(dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)) * vk, 0.0, 1.0);
	// pedazos de la piel con la cara al revés se ven desde afuera: se pintan casi igual que el resto
	vec3 base = c * k * (FRONT_FACING ? 1.0 : 0.9);
	float gm = 0.0;
	if (glass_on > 0.5) {
		gm = max(max(glass_strip(lp, ln, ws, ws_w), glass_strip(lp, ln, rg, rg_w)), glass_side(lp, ln));
	}
	ALBEDO = mix(base, vec3(0.012, 0.016, 0.022), gm);
	METALLIC = mix(metal, 0.85, gm);
	ROUGHNESS = mix(rough, 0.06, gm);
}
"""
static var _livery_shader: Shader

## Color de las gomas (negro de fábrica)
func set_tire_color(c: Color) -> void:
	if tire_mat != null:
		tire_mat.albedo_color = c

static var _livery_shader_in: Shader

static func _paint_material(pattern: int, paint: Color, accent: Color, finish: String, accent2 := Color(0.95, 0.95, 0.93), inside := false) -> ShaderMaterial:
	if _livery_shader == null:
		_livery_shader = Shader.new()
		_livery_shader.code = LIVERY_SHADER
		_livery_shader_in = Shader.new()
		_livery_shader_in.code = LIVERY_SHADER.replace("render_mode cull_disabled;", "render_mode cull_back;")
	var fin: Array = FINISH.get(finish, FINISH["gloss"])
	var sm := ShaderMaterial.new()
	sm.shader = _livery_shader_in if inside else _livery_shader
	sm.set_shader_parameter("paint", paint)
	sm.set_shader_parameter("accent", accent)
	sm.set_shader_parameter("accent2", accent2)
	sm.set_shader_parameter("pattern", pattern)
	sm.set_shader_parameter("metal", float(fin[0]))
	sm.set_shader_parameter("rough", float(fin[1]))
	return sm

## Cambia la pintura de la carrocería por la del rotulado elegido (pattern 0 = lisa)
func set_livery(pattern: int, paint: Color, accent: Color, finish := "gloss", accent2 := Color(0.95, 0.95, 0.93)) -> void:
	if shell == null:
		return
	if parts != null:
		_apply_own_mats(pattern, paint, accent, finish, accent2)
		VehicleCustomization.tint(mod_nodes, paint)
		return
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for sidx in mesh.get_surface_count():
			var mat := mesh.surface_get_material(sidx)
			if mat != null and mat.resource_name == "glass":
				continue
			mi.set_surface_override_material(sidx, _paint_material(pattern, paint, accent, finish, accent2))

func _make_blob() -> void:
	if _blob_mat == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_SQUARE
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = gt
		_blob_mat.disable_receive_shadows = true
	blob = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(V.trackF + 1.3, V.wheelBase + 2.4)
	q.material = _blob_mat
	blob.mesh = q
	blob.top_level = true
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

## Puntos de las cámaras de capó y paragolpes, medidos sobre la carrocería real (rayos sobre sus triángulos), en el marco del auto
func compute_mounts(cowl_z: float, eye_y: float) -> Dictionary:
	var ground := -V.comHeight + V.rideOffset
	var tris := PackedVector3Array()
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mi in _mesh_instances(shell):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != self:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for v in (mi.mesh as Mesh).get_faces():
			var w := xf * v
			tris.append(w)
			mn = mn.min(w)
			mx = mx.max(w)
	var hy := NAN
	for dz in [0.3, 0.5, 0.7, 0.15]:
		var z := minf(cowl_z + dz, mx.z - 0.2)
		var best := -1e9
		for k in range(0, tris.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(0, mx.y + 1.0, z), Vector3.DOWN, tris[k], tris[k + 1], tris[k + 2])
			if hit != null:
				best = maxf(best, (hit as Vector3).y)
		if best > -1e8:
			hy = best
			break
	if is_nan(hy):
		hy = ground + eye_y - 0.35
	return {"hood": {"y": maxf(hy + 0.36, ground + eye_y - 0.25), "z": cowl_z + 0.02, "ly": -0.22}, "bumper": {"y": ground + 0.46, "z": mx.z + 0.06, "ly": -0.1}}

func _mesh_instances(root: Node) -> Array:
	var out := []
	var stack := [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

## Sincroniza con el estado de la física
func sync_from(p: CarSnapshot, dt: float) -> void:
	position = Vector3(p.px, p.py, p.pz)
	basis = Basis.from_euler(Vector3(p.pitch, p.yaw, p.roll), EULER_ORDER_YXZ)
	blob.global_position = Vector3(p.px, p.py - V.comHeight + 0.05, p.pz)
	blob.global_rotation = Vector3(0.0, p.yaw, 0.0)
	var base := V.comHeight + V.hardpointY - V.rideOffset
	if parts != null:
		parts.sync(p, base, dt)
		return
	for i in 4:
		var w: Dictionary = wheels[i]
		var steer: Node3D = w["steer"]
		steer.position.y = base - p.wheel_s[i]
		if w["front"]:
			steer.rotation.y = p.steerAngle
		w["angle"] += p.wheel_omega[i] * dt
		(w["spin"] as Node3D).rotation.x = w["angle"]
