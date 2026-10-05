extends RefCounted
## Ciclo de día de Dream City: amanecer, mañana, mediodía, tarde, atardecer y noche. Un día entero dura 16 minutos de juego. Todo es barato: unos pocos valores (cielo, luz del sol/luna,
## ambiente, niebla) que se recalculan 8 veces por segundo, sin luces dinámicas ni sombras nuevas. De noche se prenden las ventanas (en el shader de las fachadas), las lámparas de la calle
## (mallas aditivas con charcos de luz) y los faros del auto (un haz plano aditivo sobre el piso).

const DAY_SECONDS := 960.0
const START_HOUR := 9.0

# hora · cielo arriba · cielo horizonte · piso · color de luz · energía de luz · color ambiente · energía ambiente · niebla · elevación (°) · giro (°) · noche (0..1)
const KEYS := [
	[0.0, Color(0.03, 0.04, 0.12), Color(0.10, 0.14, 0.30), Color(0.04, 0.05, 0.10), Color(0.55, 0.66, 1.0), 0.30, Color(0.34, 0.40, 0.66), 0.62, Color(0.07, 0.09, 0.20), 48.0, 205.0, 1.0],
	[5.0, Color(0.05, 0.07, 0.19), Color(0.16, 0.20, 0.38), Color(0.05, 0.06, 0.11), Color(0.55, 0.66, 1.0), 0.32, Color(0.36, 0.42, 0.68), 0.64, Color(0.12, 0.14, 0.28), 40.0, 215.0, 1.0],
	[6.1, Color(0.26, 0.36, 0.64), Color(0.98, 0.62, 0.44), Color(0.40, 0.30, 0.30), Color(1.0, 0.66, 0.42), 0.85, Color(0.70, 0.62, 0.68), 0.74, Color(0.94, 0.68, 0.56), 7.0, 98.0, 0.50],
	[7.6, Color(0.34, 0.56, 0.88), Color(0.95, 0.86, 0.78), Color(0.62, 0.62, 0.58), Color(1.0, 0.90, 0.72), 1.20, Color(0.76, 0.82, 0.92), 0.88, Color(0.88, 0.86, 0.86), 26.0, 80.0, 0.0],
	[12.5, Color(0.40, 0.62, 0.90), Color(0.86, 0.90, 0.95), Color(0.70, 0.74, 0.74), Color(1.0, 0.97, 0.90), 1.35, Color(0.76, 0.82, 0.92), 0.95, Color(0.82, 0.87, 0.92), 62.0, 20.0, 0.0],
	[17.0, Color(0.38, 0.56, 0.86), Color(0.95, 0.88, 0.78), Color(0.66, 0.66, 0.62), Color(1.0, 0.90, 0.72), 1.25, Color(0.78, 0.78, 0.86), 0.90, Color(0.90, 0.88, 0.84), 34.0, -60.0, 0.0],
	[19.0, Color(0.28, 0.30, 0.58), Color(1.0, 0.56, 0.32), Color(0.36, 0.26, 0.26), Color(1.0, 0.52, 0.28), 1.0, Color(0.72, 0.58, 0.64), 0.74, Color(0.95, 0.62, 0.48), 6.0, -98.0, 0.30],
	[20.2, Color(0.11, 0.13, 0.32), Color(0.52, 0.34, 0.46), Color(0.14, 0.12, 0.18), Color(0.80, 0.50, 0.50), 0.45, Color(0.46, 0.44, 0.64), 0.64, Color(0.34, 0.28, 0.42), 1.0, -110.0, 0.80],
	[21.4, Color(0.03, 0.04, 0.12), Color(0.10, 0.14, 0.30), Color(0.04, 0.05, 0.10), Color(0.55, 0.66, 1.0), 0.30, Color(0.34, 0.40, 0.66), 0.62, Color(0.07, 0.09, 0.20), 48.0, 205.0, 1.0],
	[24.0, Color(0.03, 0.04, 0.12), Color(0.10, 0.14, 0.30), Color(0.04, 0.05, 0.10), Color(0.55, 0.66, 1.0), 0.30, Color(0.34, 0.40, 0.66), 0.62, Color(0.07, 0.09, 0.20), 48.0, 205.0, 1.0],
]

var race
var hour := START_HOUR
var night := 0.0 # 0 = de día · 1 = de noche (lo que usan las ventanas y las lámparas)
var sun_e := 1.3 # energía de la luz de afuera (race.gd la baja bajo tierra)
var amb_e := 0.9
var fog_col := Color(0.82, 0.87, 0.92)
var _sky: ProceduralSkyMaterial
var _acc := 0.0
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _frozen := false
var _follow_world := true # la hora sale del reloj del mundo (WorldClock): en el online es la misma para todos; con la hora forzada de una prueba, no

func setup(p_race, p_sky: ProceduralSkyMaterial) -> void:
	race = p_race
	_sky = p_sky
	_sky.sun_angle_max = 9.0 # el sol (o la luna) es un disco con poco resplandor: el valor por defecto lava todo el cielo en el atardecer
	_sky.sun_curve = 0.35
	hour = fposmod(float(race.profile.d.get("tod", START_HOUR)), 24.0)
	var forced = race.cfg.get("tod")
	if forced != null:
		_follow_world = false
		hour = fposmod(float(forced), 24.0)
		_frozen = bool(race.cfg.get("tod_frozen", false))
	race.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR # (el ambiente sale de acá: el cielo no regenera reflejos)
	race.env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_build_beam()
	_apply()

## Nombre de la franja del día (para el cartel del reloj)
func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - float(h)) * 60.0)
	var icon := "🌙" if (hour < 5.8 or hour >= 20.0) else ("🌅" if (hour < 7.5 or hour >= 18.0) else "☀")
	return "%s %02d:%02d" % [icon, h, m]

func save() -> void:
	race.profile.d["tod"] = hour

func update(dt: float) -> void:
	if not _frozen:
		if _follow_world and race.world_life != null:
			hour = race.world_life.clock.hour()
		else:
			hour = fposmod(hour + dt * 24.0 / DAY_SECONDS, 24.0)
	_acc += dt
	if _acc >= 0.125:
		_acc = 0.0
		_apply()
	_update_beam()

func _lerp_key(h: float) -> Array:
	var i := 0
	while i < KEYS.size() - 2 and h >= float(KEYS[i + 1][0]):
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t := clampf((h - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var out := []
	for k in a.size():
		if a[k] is Color:
			out.append((a[k] as Color).lerp(b[k], t))
		else:
			out.append(lerpf(float(a[k]), float(b[k]), t))
	return out

func _apply() -> void:
	var k := _lerp_key(hour)
	_sky.sky_top_color = k[1]
	_sky.sky_horizon_color = k[2]
	_sky.ground_horizon_color = (k[2] as Color).lerp(k[3], 0.4)
	_sky.ground_bottom_color = k[3]
	race.sun.light_color = k[4]
	sun_e = float(k[5])
	race.env.ambient_light_color = k[6]
	amb_e = float(k[7])
	fog_col = k[8]
	race.sun.rotation_degrees = Vector3(-float(k[9]), float(k[10]), 0.0)
	night = float(k[11])
	var hud = race.race_hud.city_hud if race.race_hud != null else null
	if hud != null and hud.clock_l != null:
		hud.clock_l.text = clock_text()
	if race.track != null and race.track.world_node != null:
		race.track.world_node.set_night(night)
	if _beam != null:
		_beam.visible = night > 0.08
		_beam_mat.albedo_color = Color(1.0, 0.95, 0.78, clampf(night * 0.55, 0.0, 0.55))

# ───────────── faros: un haz plano aditivo sobre el piso, delante del auto ─────────────
func _build_beam() -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	# dos conos de luz por faro, uno dentro del otro: el de afuera es ancho y suave (se apaga hacia el borde y hacia el fondo) y el de adentro, más angosto, concentra la luz;
	# más un charco de luz delante del paragolpes. Todo es un solo mesh aditivo plano (sin luces dinámicas, sin sombras).
	for side_v in [-0.7, 0.7]:
		var side: float = side_v
		for layer in 2:
			var w0 := 0.40 if layer == 0 else 0.22 # medio ancho cerca del faro
			var w1 := 3.6 if layer == 0 else 1.5 # medio ancho a 28 m
			var zf := 28.0 if layer == 0 else 20.0
			var ow := side * (2.2 if layer == 0 else 1.5) # el haz se abre un poco hacia afuera
			var a_n := 0.55 if layer == 0 else 0.85
			var near_a := Vector3(side - w0, 0.0, 2.2)
			var near_b := Vector3(side + w0, 0.0, 2.2)
			var mid_a := Vector3(side + ow * 0.35 - (w0 + (w1 - w0) * 0.4), 0.0, zf * 0.42)
			var mid_b := Vector3(side + ow * 0.35 + (w0 + (w1 - w0) * 0.4), 0.0, zf * 0.42)
			var far_a := Vector3(side + ow - w1, 0.0, zf)
			var far_b := Vector3(side + ow + w1, 0.0, zf)
			var cn := Color(1, 0.96, 0.82, a_n * 0.5 if layer == 0 else a_n)
			var cm := Color(1, 0.96, 0.82, a_n * 0.36)
			var cf := Color(1, 0.96, 0.82, 0.0)
			# bordes de afuera transparentes: el haz se difumina hacia los costados
			var cn_e := Color(1, 0.96, 0.82, 0.0)
			var cm_e := Color(1, 0.96, 0.82, 0.0)
			v.append_array(PackedVector3Array([near_a, near_b, (mid_a + mid_b) * 0.5, near_a, (mid_a + mid_b) * 0.5, mid_a, near_b, mid_b, (mid_a + mid_b) * 0.5,
				mid_a, (mid_a + mid_b) * 0.5, (far_a + far_b) * 0.5, mid_a, (far_a + far_b) * 0.5, far_a, mid_b, far_b, (far_a + far_b) * 0.5,
				(mid_a + mid_b) * 0.5, mid_b, (far_a + far_b) * 0.5]))
			c.append_array(PackedColorArray([cn, cn, cm, cn_e, cm, cm_e, cn_e, cm_e, cm,
				cm_e, cm, cf, cm_e, cf, cf, cm_e, cf, cf,
				cm, cm_e, cf]))
	# charco delante del auto (la luz que cae sobre el piso justo adelante de los faros)
	for k in 12:
		var a0 := TAU * float(k) / 12.0
		var a1 := TAU * float(k + 1) / 12.0
		v.append(Vector3(0.0, 0.0, 4.5))
		v.append(Vector3(cos(a0) * 3.4, 0.0, 4.5 + sin(a0) * 3.0))
		v.append(Vector3(cos(a1) * 3.4, 0.0, 4.5 + sin(a1) * 3.0))
		c.append(Color(1, 0.95, 0.8, 0.30))
		c.append(Color(1, 0.95, 0.8, 0.0))
		c.append(Color(1, 0.95, 0.8, 0.0))
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.vertex_color_use_as_albedo = true
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_beam_mat.albedo_color = Color(1, 1, 1, 0)
	m.surface_set_material(0, _beam_mat)
	_beam = MeshInstance3D.new()
	_beam.mesh = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	_beam.top_level = true
	race.world.add_child(_beam)

func _update_beam() -> void:
	if _beam == null or not _beam.visible or race.cars.is_empty():
		return
	var vis: Node3D = race.cars[0].visual
	if vis == null:
		return
	var gy: float = (vis.get("blob") as Node3D).global_position.y + 0.05
	_beam.global_transform = Transform3D(Basis(Vector3.UP, vis.basis.get_euler(EULER_ORDER_YXZ).y), Vector3(vis.position.x, gy, vis.position.z))
