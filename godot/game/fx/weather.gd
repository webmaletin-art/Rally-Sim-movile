extends Node3D
## Clima y cielo. Los 5 cielos de la versión web (día, nublado, lluvia, atardecer, ocaso) con sus colores, niebla y luz,
## y en lluvia real: gotas en 3D alrededor de la cámara (rayitas que caen con el viento), salpicaduras en el piso,
## calle mojada (más oscura y brillante), rocío de agua detrás de los autos y menos agarre.

const TEX_DIR := "res://game/fx/tex/"

## fog = [cerca, lejos] en metros (niebla lineal, como en la versión web); hemi = [color de arriba, color del piso, intensidad]
const PRESETS := {
	"dia": {"bg": "#9ec0d2", "zen": "#4a86c8", "fog": [180.0, 900.0], "hemi": ["#d9e9ff", "#4b4132", 1.1], "sun": ["#fff0d2", 1.6], "pos": [120.0, 160.0, 80.0], "exp": 1.05, "wet": 0.0},
	"atardecer": {"bg": "#e9a576", "zen": "#34457a", "fog": [140.0, 760.0], "hemi": ["#ffd2b0", "#3d2c26", 0.95], "sun": ["#ffb070", 1.75], "pos": [-220.0, 55.0, 140.0], "exp": 1.0, "wet": 0.0},
	"nublado": {"bg": "#9aa4ad", "zen": "#7b8792", "fog": [90.0, 560.0], "hemi": ["#d2d9e0", "#4b4a44", 1.25], "sun": ["#e8ecf0", 0.55], "pos": [60.0, 200.0, 40.0], "exp": 1.08, "wet": 0.0},
	"lluvia": {"bg": "#6d7780", "zen": "#4d5760", "fog": [55.0, 340.0], "hemi": ["#aab4be", "#34332f", 1.0], "sun": ["#c8d0d8", 0.35], "pos": [40.0, 200.0, 60.0], "exp": 1.0, "wet": 1.0},
	"ocaso": {"bg": "#5b6a8f", "zen": "#141b36", "fog": [110.0, 620.0], "hemi": ["#9fb0d8", "#2a2530", 0.8], "sun": ["#ff9a6a", 1.0], "pos": [-160.0, 30.0, -180.0], "exp": 1.15, "wet": 0.0},
}
const ORDER := ["dia", "nublado", "lluvia", "atardecer", "ocaso"]

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var cam: Camera3D
var track: RefCounted
var fx: Node3D
var current := "dia"
var wet := 0.0 # mojado actual (se acerca al objetivo de a poco)
var wet_target := 0.0
var q := 1.0 # cantidad de gotas (0.5 baja · 1 media · 1.5 alta)

var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _road_col := Color(1, 1, 1)
var _ground_col := Color(1, 1, 1)

func setup(p_env: Environment, p_sun: DirectionalLight3D, p_cam: Camera3D, p_track: RefCounted, p_fx: Node3D, p_road: StandardMaterial3D, p_ground: StandardMaterial3D) -> void:
	env = p_env
	sun = p_sun
	cam = p_cam
	track = p_track
	fx = p_fx
	road_mat = p_road
	ground_mat = p_ground
	_road_col = road_mat.albedo_color
	_ground_col = ground_mat.albedo_color
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.0
	_build_rain()
	apply("dia", true)

func set_sky_enabled(on: bool) -> void:
	env.background_mode = Environment.BG_SKY if on else Environment.BG_COLOR
	env.background_color = Color(PRESETS[current]["bg"])

func _rain_tex(name: String) -> Texture2D:
	return load(TEX_DIR + name)

func _build_rain() -> void:
	# gotas: rayitas verticales que caen rápido, con un poco de viento
	_rain = GPUParticles3D.new()
	_rain.amount = int(1400.0 * q)
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emitting = false
	_rain.fixed_fps = 0
	_rain.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain.visibility_aabb = AABB(Vector3(-40, -25, -40), Vector3(80, 50, 80))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.75)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _rain_tex("rain_streak.png")
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	quad.material = m
	_rain.draw_pass_1 = quad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.2, 24)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.color = Color(0.78, 0.84, 0.92, 0.42)
	_rain.process_material = pm
	add_child(_rain)
	# salpicaduras: anillitos que se abren en el piso
	_splash = GPUParticles3D.new()
	_splash.amount = int(260.0 * q)
	_splash.lifetime = 0.32
	_splash.local_coords = false
	_splash.emitting = false
	_splash.fixed_fps = 0
	_splash.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	_splash.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 6, 80))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sq := QuadMesh.new()
	sq.size = Vector2(0.5, 0.5)
	sq.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _rain_tex("splash.png")
	sm.vertex_color_use_as_albedo = true
	sm.disable_receive_shadows = true
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 30.0
	sm.distance_fade_max_distance = 12.0
	sq.material = sm
	_splash.draw_pass_1 = sq
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(26, 0.02, 26)
	sp.direction = Vector3.UP
	sp.spread = 0.0
	sp.initial_velocity_min = 0.0
	sp.initial_velocity_max = 0.0
	sp.gravity = Vector3.ZERO
	sp.scale_min = 0.5
	sp.scale_max = 1.0
	sp.scale_curve = _curve([[0.0, 0.25], [0.6, 0.85], [1.0, 1.0]])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	sp.color_ramp = gt
	_splash.process_material = sp
	add_child(_splash)

func _curve(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p in pts:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

func set_quality(level: String) -> void:
	q = 0.5 if level == "baja" else (1.5 if level == "alta" else 1.0)
	_rain.amount = int(1400.0 * q)
	_splash.amount = int(260.0 * q)

## Cambia el cielo. instant = sin transición (al arrancar)
func apply(name: String, instant := false) -> void:
	if not PRESETS.has(name):
		return
	current = name
	var P: Dictionary = PRESETS[name]
	var bg := Color(P["bg"])
	var zen := Color(P["zen"])
	sky_mat.sky_top_color = zen
	sky_mat.sky_horizon_color = bg
	sky_mat.sky_curve = 0.22
	sky_mat.ground_horizon_color = bg
	sky_mat.ground_bottom_color = bg.darkened(0.35)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.15
	env.fog_light_color = bg
	env.fog_depth_begin = float(P["fog"][0])
	env.fog_depth_end = float(P["fog"][1])
	var h: Array = P["hemi"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(h[0]).lerp(Color(h[1]), 0.25)
	env.ambient_light_energy = float(h[2]) * 0.72
	# el brillo va en las luces: con exposición distinta de 1 el teléfono tendría que dibujar en un buffer más pesado
	var ex := float(P["exp"])
	env.ambient_light_energy *= ex
	sun.light_color = Color(P["sun"][0])
	sun.light_energy = float(P["sun"][1]) * 0.8 * ex
	var sp: Array = P["pos"]
	var dir := -Vector3(sp[0], sp[1], sp[2]).normalized()
	sun.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3.ZERO)
	wet_target = float(P["wet"])
	if instant:
		wet = wet_target
	_apply_wet()

func _apply_wet() -> void:
	# calle y pasto mojados: más oscuros y brillantes; agarre menor (0,86 como en la versión web)
	road_mat.albedo_color = _road_col.lerp(_road_col * 0.62, wet)
	road_mat.roughness = lerpf(0.9, 0.28, wet)
	road_mat.metallic_specular = lerpf(0.5, 0.9, wet)
	ground_mat.albedo_color = _ground_col.lerp(_ground_col * 0.78, wet)
	ground_mat.roughness = lerpf(1.0, 0.7, wet)
	track.grip_mul = lerpf(1.0, 0.86, wet)
	if fx != null:
		fx.wetness = wet
	var raining := wet_target > 0.5
	_rain.emitting = raining
	_splash.emitting = raining

func _process(dt: float) -> void:
	if not is_equal_approx(wet, wet_target):
		wet = move_toward(wet, wet_target, dt * 0.12) # se moja/seca de a poco
		_apply_wet()
	# la lluvia acompaña a la cámara
	if cam != null:
		_rain.global_position = cam.global_position + Vector3(0, 13.0, 0)
		_splash.global_position = Vector3(cam.global_position.x, 0.06, cam.global_position.z)
