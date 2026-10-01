extends Node3D
## Efectos de los autos con partículas por GPU (mucho más que las bocanadas de la versión web):
##  · HUMO de neumáticos: bocanadas volumétricas de 16 formas, rotan, se estiran y se disuelven, arrastradas por turbulencia.
##  · POLVO: nubes grandes y lentas que quedan flotando atrás del auto (una estela) y se abren con la velocidad.
##  · PIEDRITAS y BARRO: terrones oscuros que salen despedidos con gravedad.
##  · ROCÍO DE AGUA: en calle mojada cada rueda levanta una neblina blanca según la velocidad.
##  · MARCAS: tiras en el asfalto (goma) y huellas en tierra.
## Cada rueda del auto del jugador tiene sus emisores (según el patinaje y la superficie); los rivales cercanos llevan uno por eje.
## Todo se reparte en pocos emisores con un tope según la calidad; los que no tienen partículas vivas se apagan.

const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const TEX_DIR := "res://game/fx/tex/"

const MARKS := 500

var intensity := 1.0 # 0 sin partículas … 1 todas (opción «Partículas» 0–10)
var qk := 1.0 # 0.5 baja · 1.0 media · 1.5 alta (cantidad de partículas)
var track: RefCounted
var wetness := 0.0 # 0 seco … 1 lluvia fuerte
var wind := Vector3(0.6, 0.0, 0.2)

var _tex_smoke: Texture2D
var _tex_chunk: Texture2D
var _marks: MultiMesh
var _mk := 0
var _cars := {} # índice de auto → {smoke:[4], dust:[4], spray:[4], debris:[2], last:[4], acc:[4]}
var _mat_cache := {}

func setup(p_track: RefCounted) -> void:
	track = p_track
	_tex_smoke = load(TEX_DIR + "smoke_atlas.png")
	_tex_chunk = load(TEX_DIR + "chunk.png")
	# marcas de frenada: tiras pegadas al piso
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var mm2 := StandardMaterial3D.new()
	mm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm2.vertex_color_use_as_albedo = true
	mm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = mm2
	_marks = MultiMesh.new()
	_marks.transform_format = MultiMesh.TRANSFORM_3D
	_marks.use_colors = true
	_marks.mesh = plane
	_marks.instance_count = MARKS
	_clear_marks()
	var inst2 := MultiMeshInstance3D.new()
	inst2.multimesh = _marks
	inst2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst2.extra_cull_margin = 4000.0
	add_child(inst2)

func _clear_marks() -> void:
	var hide := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -999, 0))
	for i in MARKS:
		_marks.set_instance_transform(i, hide)
	_mk = 0

func set_quality(level: String) -> void:
	qk = 0.5 if level == "baja" else (1.5 if level == "alta" else 1.0)

func reset() -> void:
	for k in _cars:
		for kind in ["smoke", "dust", "spray", "debris"]:
			for e in _cars[k][kind]:
				(e as GPUParticles3D).emitting = false
				(e as GPUParticles3D).restart()
	_clear_marks()
	for k in _cars:
		_cars[k]["last"] = [null, null, null, null]

# ───────────────────────── construcción de emisores ─────────────────────────
## kind: parámetros del emisor. Devuelve un GPUParticles3D listo (apagado, en el espacio del mundo)
func _emitter(amount: int, life: float, tex: Texture2D, atlas: bool, blend_add := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(4, int(float(amount) * qk))
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.randomness = 1.0
	p.fixed_fps = 0
	p.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	p.visibility_aabb = AABB(Vector3(-120, -10, -120), Vector3(240, 60, 240))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if blend_add else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA # se desvanece pegada a la cámara: no tapa la pantalla
	m.distance_fade_min_distance = 1.0
	m.distance_fade_max_distance = 4.0
	if atlas:
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 4
		m.particles_anim_loop = false
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)
	return p

func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(s[0])
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _curve(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p in pts:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

func _make_smoke() -> GPUParticles3D:
	var p := _emitter(70, 2.6, _tex_smoke, true)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, 0.55, 0) # el humo caliente sube despacio
	pm.damping_min = 1.2
	pm.damping_max = 2.4
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -35.0
	pm.angular_velocity_max = 35.0
	pm.scale_min = 0.55
	pm.scale_max = 1.0
	pm.scale_curve = _curve([[0.0, 0.25], [0.25, 0.7], [1.0, 1.0]]) # nace chico y se abre
	pm.color_ramp = _ramp([[0.0, Color(0.96, 0.96, 0.98, 0.0)], [0.06, Color(0.96, 0.96, 0.98, 0.95)], [0.5, Color(0.88, 0.89, 0.92, 0.6)], [1.0, Color(0.82, 0.84, 0.88, 0.0)]])
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 1.8
	pm.turbulence_noise_speed = Vector3(0.3, 0.1, 0.2)
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.18
	p.process_material = pm
	# el tamaño real lo da la escala del cuadro
	(p.draw_pass_1 as QuadMesh).size = Vector2(2.4, 2.4)
	return p

func _make_dust() -> GPUParticles3D:
	var p := _emitter(130, 3.6, _tex_smoke, true)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.45
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, 0.12, 0)
	pm.damping_min = 0.9
	pm.damping_max = 1.8
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -18.0
	pm.angular_velocity_max = 18.0
	pm.scale_min = 1.0
	pm.scale_max = 1.8
	pm.scale_curve = _curve([[0.0, 0.45], [0.25, 0.8], [1.0, 1.3]])
	pm.color = Color(0.62, 0.52, 0.38) # el color real lo pone el emisor según la superficie
	pm.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.07, Color(1, 1, 1, 0.95)], [0.45, Color(1, 1, 1, 0.7)], [1.0, Color(1, 1, 1, 0.0)]])
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 1.4
	pm.turbulence_noise_speed = Vector3(0.2, 0.05, 0.15)
	pm.turbulence_influence_min = 0.04
	pm.turbulence_influence_max = 0.14
	p.process_material = pm
	(p.draw_pass_1 as QuadMesh).size = Vector2(3.2, 3.2)
	return p

func _make_spray() -> GPUParticles3D:
	var p := _emitter(60, 1.5, _tex_smoke, true)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -0.3, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.scale_curve = _curve([[0.0, 0.3], [0.3, 0.8], [1.0, 1.0]])
	pm.color_ramp = _ramp([[0.0, Color(0.9, 0.94, 1.0, 0.0)], [0.1, Color(0.9, 0.94, 1.0, 0.6)], [1.0, Color(0.85, 0.9, 0.96, 0.0)]])
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	p.process_material = pm
	(p.draw_pass_1 as QuadMesh).size = Vector2(1.8, 1.8)
	return p

func _make_debris() -> GPUParticles3D:
	var p := _emitter(40, 1.0, _tex_chunk, false)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.damping_min = 0.0
	pm.damping_max = 0.6
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(0.22, 0.17, 0.12)
	pm.color_ramp = _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.85, Color(1, 1, 1, 1.0)], [1.0, Color(1, 1, 1, 0.0)]])
	p.process_material = pm
	(p.draw_pass_1 as QuadMesh).size = Vector2(0.075, 0.075)
	(p.draw_pass_1.material as StandardMaterial3D).distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	return p

## Crea los emisores de un auto antes de que hagan falta y los "calienta" unos cuadros (invisibles) para que el teléfono
## compile los shaders ahora y no en el primer derrape.
func prepare(key: int) -> void:
	_ensure_car(key)

func tick(cam_pos: Vector3) -> void:
	for k in _cars:
		var car: Dictionary = _cars[k]
		if car["warm"] > 0:
			car["warm"] -= 1
			for kind in ["smoke", "dust", "spray", "debris"]:
				for e in car[kind]:
					(e as GPUParticles3D).global_position = cam_pos
					(e as GPUParticles3D).emitting = car["warm"] > 0

func _ensure_car(key: int) -> Dictionary:
	if _cars.has(key):
		return _cars[key]
	var d := {"smoke": [], "dust": [], "spray": [], "debris": [], "last": [null, null, null, null], "acc": [0.0, 0.0, 0.0, 0.0], "idle": 0.0, "warm": 4}
	for i in 4:
		d["smoke"].append(_make_smoke())
		d["dust"].append(_make_dust())
		d["spray"].append(_make_spray())
	for i in 2:
		d["debris"].append(_make_debris())
	_cars[key] = d
	return d

# ───────────────────────── emisión por rueda ─────────────────────────
## Reglas: patinaje (longitudinal + lateral) y superficie por rueda. Se llama una vez por cuadro por auto.
## detail 1.0 = jugador (todas las ruedas); rivales cercanos 0.5 (las mismas reglas, menos cantidad)
func emit_from(key: int, s: CarSnapshot, dt: float, tire_w: float, detail := 1.0) -> void:
	var car := _ensure_car(key)
	if car["warm"] > 0:
		return
	var base_detail := detail
	detail *= intensity
	var fwd := Vector3(sin(s.yaw), 0.0, cos(s.yaw))
	var left := Vector3(cos(s.yaw), 0.0, -sin(s.yaw))
	var any := false
	var debris_rate := 0.0
	var debris_pos := Vector3.ZERO
	var last: Array = car["last"]
	for i in 4:
		var o := i * 8
		var f := s.wheel_fx
		var smoke: GPUParticles3D = car["smoke"][i]
		var dust: GPUParticles3D = car["dust"][i]
		var spray: GPUParticles3D = car["spray"][i]
		if f[o] < 0.5: # rueda en el aire
			smoke.emitting = false
			dust.emitting = false
			spray.emitting = false
			last[i] = null
			continue
		var surf := int(f[o + 1])
		var vl := f[o + 2]
		var kappa := f[o + 3]
		var alp := f[o + 4]
		var pos := Vector3(f[o + 5], f[o + 7] + 0.06, f[o + 6])
		var is_left := (i % 2) == 0
		var side := 1.0 if is_left else -1.0
		var sp := absf(vl)
		var sl := maxf(0.0, absf(kappa) - 0.06) + maxf(0.0, absf(alp) - 0.09)
		var loose := surf != 0
		# HUMO de goma: solo en asfalto y patinando
		var smoke_amt := 0.0
		if not loose and sl > 0.14:
			smoke_amt = clampf((sl - 0.14) * 3.2, 0.0, 1.0) * minf(1.0, sp / 3.0 + 0.3)
		_set_emitter(smoke, pos, smoke_amt * detail, -fwd * (0.4 + sp * 0.03) + left * side * 0.35 + Vector3.UP * 0.4, 0.8 + sp * 0.06)
		# POLVO: superficies sueltas, según la velocidad y el patinaje
		var dust_amt := 0.0
		if loose:
			dust_amt = clampf(sp * 0.045 + sl * 1.6, 0.0, 1.0) * _dust_k(surf)
			var col := _dust_color(surf)
			((dust.process_material as ParticleProcessMaterial)).color = col
		_set_emitter(dust, pos, dust_amt * detail, -fwd * (0.55 + sp * 0.02) + left * side * 0.5 + Vector3.UP * 0.9, 1.0 + sp * 0.08)
		# ROCÍO en calle mojada
		var spray_amt := 0.0
		if not loose and wetness > 0.05:
			spray_amt = clampf((sp - 6.0) * 0.03, 0.0, 1.0) * wetness
		_set_emitter(spray, pos, spray_amt * detail, -fwd * 0.6 + Vector3.UP * 0.5, 1.2 + sp * 0.05)
		# piedritas/barro: acumula de las ruedas traseras
		if loose and i >= 2:
			debris_rate += clampf(sp * 0.03 + sl * 1.2, 0.0, 1.0)
			debris_pos = pos
		any = any or smoke_amt > 0.0 or dust_amt > 0.0 or spray_amt > 0.0
		# marcas
		var mark := (not loose) and sl > 0.22
		var mark_dirt := loose and sp > 4.0 and sl > 0.25
		if (mark or mark_dirt) and last[i] != null:
			var L: Vector3 = last[i]
			var dx := pos.x - L.x
			var dz := pos.z - L.z
			var dd := sqrt(dx * dx + dz * dz)
			if dd > 0.35 and dd < 3.0:
				var y1 := _ground(pos.x, pos.z)
				var b := Basis.from_euler(Vector3(-atan2(y1 - L.y, dd), atan2(dx, dz), 0.0), EULER_ORDER_YXZ)
				b = b * Basis.from_scale(Vector3(tire_w * (0.9 if mark else 1.1), 1.0, sqrt(dd * dd + (y1 - L.y) * (y1 - L.y))))
				_marks.set_instance_transform(_mk, Transform3D(b, Vector3((pos.x + L.x) * 0.5, (y1 + L.y) * 0.5 + 0.06, (pos.z + L.z) * 0.5)))
				_marks.set_instance_color(_mk, Color(0.03, 0.03, 0.03, 0.55) if mark else Color(0.16, 0.12, 0.08, 0.26))
				_mk = (_mk + 1) % MARKS
				last[i] = Vector3(pos.x, y1, pos.z)
			elif dd >= 3.0:
				last[i] = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
		elif mark or mark_dirt:
			last[i] = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
		else:
			last[i] = null
	# piedritas: dos emisores por auto (atrás)
	var d0: GPUParticles3D = car["debris"][0]
	var d1: GPUParticles3D = car["debris"][1]
	if debris_rate > 0.0 and base_detail >= 1.0 and intensity >= 0.4:
		var dir := -fwd * 0.9 + Vector3.UP * 0.8
		for e in [d0, d1]:
			var pm := (e as GPUParticles3D).process_material as ParticleProcessMaterial
			pm.direction = dir.normalized()
			(e as GPUParticles3D).global_position = debris_pos
			(e as GPUParticles3D).amount_ratio = clampf(debris_rate * 0.5, 0.05, 1.0)
			(e as GPUParticles3D).emitting = true
	else:
		d0.emitting = false
		d1.emitting = false

func _set_emitter(e: GPUParticles3D, pos: Vector3, amount: float, dir: Vector3, vel: float) -> void:
	if amount <= 0.02:
		e.emitting = false
		return
	e.global_position = pos
	var pm := e.process_material as ParticleProcessMaterial
	pm.direction = dir.normalized()
	pm.initial_velocity_min = vel * 0.35
	pm.initial_velocity_max = vel
	pm.gravity.x = wind.x * 0.35 # el viento las arrastra
	pm.gravity.z = wind.z * 0.35
	e.amount_ratio = clampf(amount, 0.05, 1.0)
	e.emitting = true

## cuánto polvo levanta cada superficie
func _dust_k(surf: int) -> float:
	match surf:
		1: return 1.0
		2: return 0.8
		3: return 0.4
		5: return 0.3
	return 0.5

func _dust_color(surf: int) -> Color:
	match surf:
		1: return Color(0.66, 0.55, 0.40) # tierra
		2: return Color(0.58, 0.52, 0.42) # banquina
		3: return Color(0.50, 0.50, 0.36) # pasto seco
		5: return Color(0.30, 0.22, 0.15) # barro
	return Color(0.6, 0.55, 0.45)

func _ground(x: float, z: float) -> float:
	return track.ground_y(x, z) if track != null else 0.0

func debug_info() -> String:
	var out := []
	for k in _cars:
		var n := 0
		var parts := []
		for kind in ["smoke", "dust", "spray", "debris"]:
			var on := 0
			var ratio := 0.0
			for e in _cars[k][kind]:
				if (e as GPUParticles3D).emitting:
					on += 1
					ratio = maxf(ratio, (e as GPUParticles3D).amount_ratio)
			parts.append("%s %d (max %.2f)" % [kind, on, ratio])
		out.append("auto %d: %s" % [k, " · ".join(parts)])
	return " | ".join(out)
