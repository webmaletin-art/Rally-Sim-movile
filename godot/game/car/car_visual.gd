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
var shell_in: Node3D # carrocería liviana (~6 mil triángulos) que se dibuja con la cámara adentro del auto: sin retazos del interior del modelo y mucho más rápida
var _paint_args: Array = []
var clear_glass := false # opción «Ver pilotos desde afuera»: vidrios translúcidos (el auto del jugador)
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
	_paint_args = [pattern, paint, accent, finish, accent2]
	if shell_in != null:
		_paint_inside_shell()
	var textured: bool = bool(meta.get("textured", false)) # todos los autos llevan su textura: el color y los detalles reemplazan los canales de color de la textura (pattern 11 = textura original)
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			if textured:
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
					var orig := pattern == ORIGINAL_TEXTURE
					var pair: Array = []
					for inside in [false, true]:
						var sm := _own_paint(0 if orig else pattern, paint, accent, finish, accent2, inside, clear_glass and not inside)
						_set_tex(sm, (mat as BaseMaterial3D).albedo_texture, 2.0 if orig else 1.0)
						pair.append(sm)
					mi.set_surface_override_material(s, pair[0])
					_own_mats.append({"mi": mi, "s": s, "out": pair[0], "in": pair[1]})
				continue
			if nm == "glass":
				mi.set_surface_override_material(s, _glass_material())
				continue
			var mo := _own_paint(pattern, paint, accent, finish, accent2, false, clear_glass)
			var mi2 := _own_paint(pattern, paint, accent, finish, accent2, true)
			mi.set_surface_override_material(s, mo)
			_own_mats.append({"mi": mi, "s": s, "out": mo, "in": mi2})

## Vidrios translúcidos (para ver a los pilotos desde las cámaras de afuera): rearma la pintura con el sombreador transparente
func set_clear_glass(on: bool) -> void:
	if clear_glass == on or _paint_args.is_empty():
		clear_glass = on
		return
	clear_glass = on
	var a := _paint_args
	_apply_own_mats(int(a[0]), a[1], a[2], str(a[3]), a[4])

## Con la cámara adentro del auto: se esconden las ruedas y la suspensión y la carrocería se dibuja solo por fuera
func set_inside(v: bool) -> void:
	if parts == null:
		body.visible = not v
		return
	body.visible = true
	# desde adentro se ve el capó de la carrocería COMPLETA (la de afuera, con los materiales de adentro). Antes se usaba la reducida (_lo, la de los rivales):
	# desde la cabina el capó se veía deforme y por sus agujeros se veía la calle (reporte del dueño con el Bisonte, 14/10/2026). CAB_LO_SHELL=1 vuelve a la de antes.
	if v and shell_in == null and not lo and not _paint_args.is_empty() and OS.has_environment("CAB_LO_SHELL"):
		_make_inside_shell()
	var use_in := v and shell_in != null
	for c in body.get_children():
		if c == shell:
			c.visible = not use_in
		elif c == shell_in:
			c.visible = use_in
		else:
			c.visible = not v
	for e in _own_mats:
		(e["mi"] as MeshInstance3D).set_surface_override_material(int(e["s"]), e["in"] if v else e["out"])

## Carrocería liviana para la vista interior (se arma la primera vez que se entra al auto)
func _make_inside_shell() -> void:
	var f := "res://game/models/cars/%s_lo.glb" % vt
	if not ResourceLoader.exists(f):
		return
	shell_in = (load(f) as PackedScene).instantiate()
	shell_in.visible = false
	body.add_child(shell_in)
	_paint_inside_shell()

func _paint_inside_shell() -> void:
	var a := _paint_args
	for mi in _mesh_instances(shell_in):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				var orig: bool = int(a[0]) == ORIGINAL_TEXTURE
				var sm := _own_paint(0 if orig else int(a[0]), a[1], a[2], str(a[3]), a[4], true)
				_set_tex(sm, (mat as BaseMaterial3D).albedo_texture, 2.0 if orig else 1.0)
				mi.set_surface_override_material(s, sm)

## z de la base del parabrisas (donde empieza el capó): si el parabrisas medido sobre el perfil sale casi vertical se usa el polígono del vidrio
func cowl_z() -> float:
	var g: Variant = meta.get("glass")
	if g is Dictionary:
		var gd: Dictionary = g
		var ws: Array = gd["ws"]
		if absf(float(ws[0][0]) - float(ws[1][0])) < 0.35:
			return float((gd["poly"] as Array)[0][0])
		return float(ws[0][0])
	return float(meta.get("cowl_z", 0.45)) # buggy (sin vidrios)

## Material de pintura de una carrocería propia: oscurecido de vértice tal cual y vidrios dibujados por el sombreador
func _own_paint(pattern: int, paint: Color, accent: Color, finish: String, accent2: Color, inside := false, clear := false) -> ShaderMaterial:
	var sm := _paint_material(pattern, paint, accent, finish, accent2, inside, clear)
	sm.set_shader_parameter("vk", 1.0)
	if (pattern >= 7 and pattern <= 10) or pattern in [13, 14, 19]:
		_set_decal(sm, pattern)
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
		sm.set_shader_parameter("clip", Vector2(cowl_z() + 0.03, 1000.0)) # vista interior: no se dibuja NADA de la carrocería detrás del capó (techo, puertas, columnas, volante del modelo); eso lo arma el habitáculo propio
	return sm

static func _glass_material() -> StandardMaterial3D:
	# vidrio polarizado: desde afuera no se ve la tripulación (ni se dibuja); además no hace falta transparencia
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.065, 0.09)
	m.metallic = 0.6
	m.roughness = 0.1
	m.emission_enabled = true # un reflejo de cielo suave: el vidrio no queda como un agujero negro
	m.emission = Color(0.12, 0.17, 0.24)
	m.emission_energy_multiplier = 0.8
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Textura propia del auto: canales de color (meta.tex: a / b = [tipo, …], va / vb = brillo de referencia) y modo 1 = recolorear · 2 = original
func _set_tex(sm: ShaderMaterial, tex: Texture2D, mode: float) -> void:
	var t: Dictionary = meta.get("tex", {})
	var ca: Array = t.get("a", [0.0, 0.615, 0.09, 0.35])
	var cb: Array = t.get("b", [-1.0, 0.0, 0.09, 0.35])
	sm.set_shader_parameter("use_tex", mode)
	sm.set_shader_parameter("albedo_tex", tex)
	sm.set_shader_parameter("ch_a", Vector4(float(ca[0]), float(ca[1]), float(ca[2]), float(ca[3])))
	sm.set_shader_parameter("ch_b", Vector4(float(cb[0]), float(cb[1]), float(cb[2]), float(cb[3])))
	sm.set_shader_parameter("ch_v", Vector2(float(t.get("va", 0.7)), float(t.get("vb", 0.7))))

## Letras del rotulado en las puertas: la fila del atlas (según el patrón) y el rectángulo sobre la puerta, medido con los pasos de rueda y la línea de cintura del GLB
func _set_decal(sm: ShaderMaterial, pattern: int) -> void:
	if pattern == 13: # número de competición (atlas propio)
		if _nums == null:
			_nums = load(NUM_TEX)
			_num_rows = JSON.parse_string(FileAccess.get_file_as_string(NUM_JSON))
		sm.set_shader_parameter("decal_tex", _nums)
		var nr := float((_num_rows.get("rows", {}) as Dictionary).get(race_number, 5))
		var nt := float(_num_rows.get("total", 1))
		sm.set_shader_parameter("decal_v", Vector2((nr + 0.04) / nt, (nr + 0.96) / nt))
	elif pattern >= 7 and pattern <= 10:
		var rows: Dictionary = _decal_rows.get("rows", {})
		var key := str(meta.get("id", "")) if pattern == 10 else ("dream" if pattern == 7 else ("sr" if pattern == 8 else "sport"))
		var total := float(_decal_rows.get("total", 1))
		var r := float(rows.get(key, 0))
		sm.set_shader_parameter("decal_v", Vector2((r + 0.04) / total, (r + 0.96) / total))
	var ar: Array = meta.get("arches", [])
	var lift := float(meta.get("lift", 0.1))
	var zc := 0.0
	var gap := 1.6
	if ar.size() >= 2:
		var za := float((ar[0] as Dictionary)["z"])
		var zb := float((ar[1] as Dictionary)["z"])
		zc = (za + zb) * 0.5
		gap = absf(za - zb)
	var belt := lift + 0.45 * (float(meta.get("H", 1.2)) - lift)
	var g: Variant = meta.get("glass")
	if g is Dictionary:
		var pl: Array = (g as Dictionary)["poly"]
		belt = minf(float(pl[0][1]), float(pl[3][1]))
	var hz := minf(gap * 0.30, 1.0)
	sm.set_shader_parameter("decal_rect", Vector4(zc, lift + (belt - lift) * 0.5, hz, hz / 8.0))

## Colores de piezas desde el perfil: {tire, rim, spring, caliper, disc}
func set_parts(pp: Dictionary) -> void:
	if parts != null:
		parts.set_colors(pp)

## Rotulados: dibujos de pintura calculados sobre la carrocería (no hace falta textura): franjas, banda lateral, la «onda»
## de Dream Racing, bicolor y el rally con el círculo del número en las puertas. 0 = liso.
const LIVERIES := ["Liso", "Franjas", "Banda lateral", "Onda Dream", "Bicolor", "Rally", "Camuflaje Multicam", "Dream Racing", "SRGamestudios", "Sport", "Nombre del auto", "Textura original",
	"Fibra de carbono", "Competición con número", "Dos tonos", "Neón nocturno", "Rally clásico", "Degradé", "Damero", "Llamas"]
const FREE_LIVERIES := 12 # del 12 en adelante son diseños que se compran (cosmetics.json); el selector libre muestra sólo los primeros
const NUM_TEX := "res://game/models/paint/numbers.png" # números de competición (patrón 13), en el contenido: no obliga a bajar de nuevo los autos
const NUM_JSON := "res://game/models/paint/numbers.json"
const ORIGINAL_TEXTURE := 11 # rotulado «textura original»: el auto con su textura de fábrica sin tocar
const CAMO_TEX := "res://game/models/cars/camo_multicam.png"
## rotulados con letras (patrones 7 a 10): una fila del atlas decals.png (tools/cars/gen_decals.py) proyectada sobre las puertas; 7 = DREAM RACING, 8 = SRGamestudios, 9 = SPORT, 10 = el nombre del auto
const DECAL_TEX := "res://game/models/cars/decals.png"
const DECAL_JSON := "res://game/models/cars/decals.json"
static var _camo: Texture2D
static var _decal: Texture2D
static var _decal_rows: Dictionary = {}
static var _nums: Texture2D
static var _num_rows: Dictionary = {}
var race_number := "77" # número de competición del patrón 13 (paint["number"])
const INSIDE_MARK := "	ROUGHNESS = mix(mix(0.55, rough, pm), 0.06, gm);\n"
const INSIDE_SMOOTH := """	vec3 up_v = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0))).xyz);
	NORMAL = normalize(mix(NORMAL, up_v, 0.85 * top * (1.0 - gm)));
	ROUGHNESS = max(ROUGHNESS, mix(0.55, ROUGHNESS, gm));
"""
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
uniform sampler2D camo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D decal_tex : source_color, filter_linear_mipmap;
uniform vec4 decal_rect = vec4(0.0, 0.6, 1.0, 0.125); // letras en las puertas: centro (z, y) y semiancho / semialto
uniform vec2 decal_v = vec2(0.0, 0.03); // franja del atlas (v) de la fila elegida
uniform float use_tex = 0.0; // autos con textura propia: 1 = los canales de color de la textura (pintura y detalles) pasan al color del taller; 2 = la textura original sin tocar
uniform sampler2D albedo_tex : filter_linear_mipmap;
// canal de color de la textura: x = tipo (-1 apagado · 0 tono: y = tono 0–1, z = ancho, w = saturación mínima · 1 neutro (blancos, plateados y grises): y = brillo desde, z = brillo hasta, w = saturación máxima)
uniform vec4 ch_a = vec4(0.0, 0.615, 0.09, 0.35);
uniform vec4 ch_b = vec4(0.0, 0.0, 0.09, 0.35);
uniform vec2 ch_v = vec2(0.7, 0.7); // brillo (V) de referencia de cada canal: el sombreado de la textura se conserva respecto de ese valor
varying vec3 lp;
varying vec3 ln;
varying vec2 tuv;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	tuv = UV;
}
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}
float hue_d(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}
float chmask(vec3 hsv, vec4 ch) {
	if (ch.x < -0.5) {
		return 0.0;
	}
	if (ch.x < 0.5) {
		float sm = smoothstep(ch.w, ch.w + 0.25, hsv.y) * smoothstep(0.05, 0.18, hsv.z);
		return sm * (1.0 - smoothstep(ch.z * 0.6, ch.z, hue_d(hsv.x, ch.y)));
	}
	return smoothstep(ch.y, ch.z, hsv.z) * (1.0 - smoothstep(ch.w, ch.w + 0.12, hsv.y));
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
	float tmall = 1.0;
	if (use_tex > 0.5) {
		vec3 raw = texture(albedo_tex, tuv).rgb; // valores de la imagen tal cual (sin pasar a lineal): el tono y la saturación se miden como se pintaron
		c = pow(raw, vec3(2.2));
		if (use_tex < 1.5) {
			vec3 hsv = rgb2hsv(raw);
			float ma = chmask(hsv, ch_a);
			float mb = chmask(hsv, ch_b);
			float vl = pow(hsv.z, 2.2);
			c = mix(c, paint * clamp(vl / pow(ch_v.x, 2.2), 0.0, 1.6), ma);
			c = mix(c, accent * clamp(vl / pow(ch_v.y, 2.2), 0.0, 1.6), mb * (1.0 - ma));
			tmall = max(ma, mb);
		} else {
			tmall = 0.6;
		}
	}
	float side = smoothstep(0.35, 0.55, abs(ln.x));
	float top = smoothstep(0.25, 0.5, ln.y);
	float ax = abs(lp.x);
	vec3 em = vec3(0.0); // brillo propio (neón)
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
	} else if (pattern >= 7 && pattern <= 10) { // letras en las puertas (se leen de adelante hacia atrás desde afuera, de los dos lados) + un detalle de franjas según el rotulado
		float sx = lp.x >= 0.0 ? 1.0 : -1.0;
		float du = 0.5 - sx * (lp.z - decal_rect.x) / (2.0 * decal_rect.z);
		float dv = 0.5 - (lp.y - decal_rect.y) / (2.0 * decal_rect.w);
		float inside = step(0.0, du) * step(du, 1.0) * step(0.0, dv) * step(dv, 1.0);
		float a = texture(decal_tex, vec2(du, mix(decal_v.x, decal_v.y, clamp(dv, 0.02, 0.98)))).a * inside * side;
		float ys = decal_rect.y - decal_rect.w;
		float zr = abs(lp.z - decal_rect.x);
		float line = band(lp.y, ys - 0.07, ys - 0.045) * side * (1.0 - smoothstep(decal_rect.z * 0.9, decal_rect.z * 1.0, zr));
		if (pattern == 7) { // doble franja en el capó y el techo
			c = mix(c, accent, band(ax, 0.07, 0.15) * top);
			c = mix(c, accent2, band(ax, 0.17, 0.19) * top);
			c = mix(c, accent2, line);
		} else if (pattern == 8) { // una franja central
			c = mix(c, accent, band(ax, 0.0, 0.10) * top);
			c = mix(c, accent2, line);
		} else if (pattern == 9) { // franja ancha
			c = mix(c, accent, band(ax, 0.0, 0.28) * top);
			c = mix(c, accent2, band(ax, 0.30, 0.33) * top);
		} else { // nombre: solo la línea
			c = mix(c, accent, line);
		}
		c = mix(c, accent, a);
	} else if (pattern == 12) { // fibra de carbono: capó, techo y zócalos con trama de carbono; el resto pintado, filete del color de detalles
		vec2 uvc = (abs(ln.y) > 0.55 ? lp.xz : (abs(ln.x) > 0.55 ? lp.zy : lp.xy)) * 22.0;
		float chk = mod(floor(uvc.x) + floor(uvc.y), 2.0);
		float fib = 0.5 + 0.5 * sin((chk > 0.5 ? uvc.x : uvc.y) * 6.2832 * 3.0);
		vec3 carbon = mix(vec3(0.018, 0.019, 0.022), vec3(0.085, 0.09, 0.1), 0.35 + 0.4 * fib * (0.6 + 0.4 * chk));
		float zone = max(top * smoothstep(-0.2, 0.2, lp.z), band(lp.y, -1.0, 0.40) * side);
		c = mix(c, carbon, clamp(zone, 0.0, 1.0));
		c = mix(c, accent, band(lp.y, 0.40, 0.43) * side);
	} else if (pattern == 13) { // competición: círculo blanco con el número en las puertas, franjas diagonales del color de detalles
		float sx = lp.x >= 0.0 ? 1.0 : -1.0;
		vec2 dc = vec2(lp.z - decal_rect.x, lp.y - decal_rect.y);
		float rr = length(dc);
		float rad = decal_rect.w * 1.75;
		float disc = (1.0 - smoothstep(rad - 0.01, rad, rr)) * side;
		c = mix(c, accent2, disc);
		float du = 0.5 - sx * dc.x / (2.0 * rad * 1.6);
		float dv = 0.5 - dc.y / (2.0 * rad * 0.82);
		float inside = step(0.0, du) * step(du, 1.0) * step(0.0, dv) * step(dv, 1.0);
		float a = texture(decal_tex, vec2(du, mix(decal_v.x, decal_v.y, clamp(dv, 0.02, 0.98)))).a * inside * disc;
		c = mix(c, vec3(0.02), a);
		float k2 = lp.z * 0.8 + lp.y * 1.4;
		float stripes = (band(fract(k2 * 0.9), 0.0, 0.18) + band(fract(k2 * 0.9), 0.30, 0.36)) * side * step(0.5, 1.0 - disc) * step(abs(dc.x), decal_rect.z * 2.2) * step(lp.z, decal_rect.x - rad);
		c = mix(c, accent, clamp(stripes, 0.0, 1.0));
		c = mix(c, accent, band(ax, 0.0, 0.08) * top);
	} else if (pattern == 14) { // dos tonos: abajo el color de detalles, filete fino en el medio
		float cut = decal_rect.y + 0.02;
		c = mix(c, accent, (1.0 - smoothstep(cut - 0.006, cut + 0.006, lp.y)) * (1.0 - top * 0.5));
		c = mix(c, accent2, band(lp.y, cut + 0.012, cut + 0.028) * side);
	} else if (pattern == 15) { // neón nocturno: base oscura, líneas de luz en los zócalos, el capó y los paragolpes (brillan de noche)
		float sill = band(lp.y, 0.28, 0.31) * side;
		float hood = band(ax, 0.36, 0.385) * top * step(0.2, lp.z);
		float chev = band(abs(lp.z - 1.2 + ax * 0.9), 0.0, 0.03) * top * step(0.6, lp.z);
		float neon = clamp(sill + hood + chev, 0.0, 1.0);
		c = mix(c, accent, neon);
		em = accent * neon * 1.8;
	} else if (pattern == 16) { // rally clásico: banda ancha cruzada en las puertas y el techo, dos filetes finos
		float k3 = lp.z * 0.55 - lp.y * 0.9;
		float sash = band(k3, -0.62, -0.36) * side;
		c = mix(c, accent, sash);
		c = mix(c, accent2, (band(k3, -0.70, -0.66) + band(k3, -0.32, -0.28)) * side);
		c = mix(c, accent, band(ax, 0.0, 0.16) * top);
		c = mix(c, accent2, band(ax, 0.18, 0.21) * top);
	} else if (pattern == 17) { // degradé: del color de pintura adelante al de detalles atrás
		float g = smoothstep(1.6, -1.8, lp.z);
		c = mix(c, accent, g);
	} else if (pattern == 18) { // damero: techo y parte de atrás a cuadros, franja a cuadros en los zócalos
		vec2 q2 = (abs(ln.y) > 0.55 ? lp.xz : lp.zy) * 5.0;
		float chk2 = mod(floor(q2.x) + floor(q2.y), 2.0);
		float zone2 = top * smoothstep(0.3, -0.2, lp.z) + band(lp.y, 0.26, 0.42) * side;
		c = mix(c, mix(accent, accent2, chk2), clamp(zone2, 0.0, 1.0));
	} else if (pattern == 19) { // llamas: lenguas de fuego que salen de la trompa por los costados y el capó
		float fz = lp.z + 0.25 * sin(lp.y * 18.0 + lp.x * 3.0) + 0.18 * sin(lp.y * 31.0);
		float fy = abs(lp.y - decal_rect.y) * 2.4;
		float edge = 1.3 - fy * 1.1;
		float fire = smoothstep(edge - 0.06, edge + 0.06, fz) * side + smoothstep(0.9, 1.2, lp.z + 0.3 * sin(ax * 22.0)) * top;
		float core = smoothstep(edge + 0.25, edge + 0.4, fz) * side;
		c = mix(c, accent, clamp(fire, 0.0, 1.0));
		c = mix(c, accent2, clamp(core, 0.0, 1.0));
	} else if (pattern == 6) { // camuflaje multicam: textura proyectada en tres ejes (la carrocería no necesita UV); el color de pintura la tiñe (blanco = camuflaje puro)
		vec3 w = pow(abs(ln), vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.001);
		vec3 t = texture(camo_tex, lp.zy * 0.35).rgb * w.x + texture(camo_tex, lp.xz * 0.35).rgb * w.y + texture(camo_tex, lp.xy * 0.35).rgb * w.z;
		c = t * 1.7 * paint;
	}
	// el modelo trae la pintura original (azul) en los colores de vértice: se usa solo cuánto brilla cada parte
	float k = clamp(dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)) * vk, 0.0, 1.0);
	// pedazos de la piel con la cara al revés se ven desde afuera: se pintan casi igual que el resto
	vec3 base = c * k * (FRONT_FACING ? 1.0 : 0.9);
	float gm = 0.0;
	if (glass_on > 0.5) {
		gm = max(max(glass_strip(lp, ln, ws, ws_w), glass_strip(lp, ln, rg, rg_w)), glass_side(lp, ln));
	}
	ALBEDO = mix(base, vec3(0.02, 0.03, 0.045), gm);
	EMISSION = em;
	float pm = use_tex > 0.5 ? tmall : 1.0; // con textura: solo la pintura brilla según el acabado; el carbono y los detalles oscuros son más mates
	METALLIC = mix(mix(0.25, metal, pm), 0.85, gm);
	ROUGHNESS = mix(mix(0.55, rough, pm), 0.06, gm);
	if (gm > 0.01) { // vidrio polarizado con un reflejo de cielo falso (sin esto se veía como un agujero negro): más claro de costado (fresnel) y hacia arriba
		vec3 V = normalize(VIEW);
		vec3 N = normalize(NORMAL);
		float fr = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.5);
		vec3 R = (INV_VIEW_MATRIX * vec4(reflect(-V, N), 0.0)).xyz;
		vec3 sky = mix(vec3(0.16, 0.22, 0.30), vec3(0.45, 0.62, 0.85), clamp(R.y * 0.8 + 0.3, 0.0, 1.0));
		EMISSION += sky * gm * (0.14 + 0.55 * fr);
	}
}
"""
static var _livery_shader: Shader

## Color de las gomas (negro de fábrica)
func set_tire_color(c: Color) -> void:
	if tire_mat != null:
		tire_mat.albedo_color = c

static var _livery_shader_in: Shader
static var _livery_shader_clear: Shader

static func _paint_material(pattern: int, paint: Color, accent: Color, finish: String, accent2 := Color(0.95, 0.95, 0.93), inside := false, clear := false) -> ShaderMaterial:
	if _livery_shader == null:
		_livery_shader = Shader.new()
		_livery_shader.code = LIVERY_SHADER
		_livery_shader_in = Shader.new()
		# vista interior: el capó se ve a un metro y las ondulaciones finas de la malla (modelos sin reducir) brillaban como chapa arrugada (dueño, 15/10/2026):
		# las caras de arriba toman la normal «vertical» del auto (casi sin ondas) y el brillo es más suave
		_livery_shader_in.code = LIVERY_SHADER.replace("render_mode cull_disabled;", "render_mode cull_back;").replace(INSIDE_MARK, INSIDE_MARK + INSIDE_SMOOTH)
		# vidrios translúcidos (la tripulación se ve desde afuera): sólo el vidrio lleva transparencia, el resto de la carrocería queda opaca
		_livery_shader_clear = Shader.new()
		_livery_shader_clear.code = LIVERY_SHADER.replace("render_mode cull_disabled;", "render_mode cull_disabled, blend_mix, depth_draw_always;").replace("ALBEDO = mix(base, vec3(0.02, 0.03, 0.045), gm);", "ALBEDO = mix(base, vec3(0.02, 0.03, 0.045), gm);\n\tALPHA = 1.0 - gm * 0.8;")
	var fin: Array = FINISH.get(finish, FINISH["gloss"])
	var sm := ShaderMaterial.new()
	sm.shader = _livery_shader_in if inside else (_livery_shader_clear if clear else _livery_shader)
	sm.set_shader_parameter("paint", paint)
	sm.set_shader_parameter("accent", accent)
	sm.set_shader_parameter("accent2", accent2)
	sm.set_shader_parameter("pattern", pattern)
	if pattern == 6:
		if _camo == null:
			_camo = load(CAMO_TEX)
		sm.set_shader_parameter("camo_tex", _camo)
	elif pattern >= 7 and pattern <= 10:
		if _decal == null:
			_decal = load(DECAL_TEX)
			_decal_rows = JSON.parse_string(FileAccess.get_file_as_string(DECAL_JSON))
		sm.set_shader_parameter("decal_tex", _decal)
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

## Inclinación visible de la rueda (radianes) por la caída: sólo lo que pasa de 2° (camber extremo del kit stance); los autos de serie no cambian
static func camber_tilt(cam_deg: float) -> float:
	return deg_to_rad(maxf(0.0, -cam_deg - 2.0))

## Sincroniza con el estado de la física
func sync_from(p: CarSnapshot, dt: float) -> void:
	position = Vector3(p.px, p.py, p.pz)
	basis = Basis.from_euler(Vector3(p.pitch, p.yaw, p.roll), EULER_ORDER_YXZ)
	blob.global_position = Vector3(p.px, p.py - V.comHeight + 0.05, p.pz)
	blob.global_rotation = Vector3(0.0, p.yaw, 0.0)
	var base := V.comHeight + V.hardpointY - V.rideOffset
	var tilt := Vector2(camber_tilt(V.camberF), camber_tilt(V.camberR))
	if parts != null:
		parts.camber_tilt = tilt
		parts.sync(p, base, dt)
		return
	for i in 4:
		var w: Dictionary = wheels[i]
		var steer: Node3D = w["steer"]
		steer.position.y = base - p.wheel_s[i]
		if w["front"]:
			steer.rotation.y = p.steerAngle
		steer.rotation.z = signf(steer.position.x) * (tilt.x if w["front"] else tilt.y)
		w["angle"] += p.wheel_omega[i] * dt
		(w["spin"] as Node3D).rotation.x = w["angle"]
