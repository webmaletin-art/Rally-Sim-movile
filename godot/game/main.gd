extends Node3D
## Prueba de fuego de la versión Godot: circuito, autos con la física verificada (la misma de la versión HTML),
## el Volt con su modelo real, pilotos, bosque y controles táctiles. El contador de arriba a la izquierda
## muestra FPS, milisegundos y objetos dibujados; los botones de la derecha cambian la carga
## (autos, árboles, pilotos, sombras) para medir hasta dónde llega el teléfono.

const CircuitTrack := preload("res://game/track/circuit_track.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const RingDriver := preload("res://game/ai/ring_driver.gd")
const Pilot := preload("res://game/car/pilot.gd")
const Hud := preload("res://game/ui/hud.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")

var track: CircuitTrack
var cars: Array = []
var vehicles: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var hud: Control
var trees_node: Node3D
var cam_yaw := 0.0
var cam_ready := false
var phys_us := 0
var phys_frames := 0
var shown_phys_ms := 0.0
var stat_timer := 0.0
var frame_count := 0
var shot_path := ""
var shot_frames := 0
var bench := false
var fps_sum := 0.0
var fps_n := 0
var cars_n := 4
var trees_n := 3000
var pilots_on := true
var hi_model := true
var cam_mode := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a == "--bench":
			bench = true
		elif a.begins_with("--cam="):
			cam_mode = a.substr(6)
		elif a.begins_with("--cars="):
			cars_n = int(a.substr(7))
		elif a.begins_with("--trees="):
			trees_n = int(a.substr(8))
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	track = CircuitTrack.new()
	_build_world()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.option_changed.connect(_on_option)
	_rebuild_trees()
	_rebuild_cars()

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.83, 0.92)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.93)
	env.fog_density = 0.0016
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 2500.0
	add_child(cam)
	cam.make_current()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.21, 0.35, 0.15)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	var road := MeshInstance3D.new()
	road.mesh = track.build_road_mesh()
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.9
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = rm
	add_child(road)

func _rebuild_trees() -> void:
	if trees_node != null:
		trees_node.queue_free()
	trees_node = Node3D.new()
	add_child(trees_node)
	if trees_n <= 0:
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.24
	trunk.height = 2.4
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.7
	crown.height = 4.6
	crown.radial_segments = 8
	crown.rings = 1
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.30, 0.20, 0.12)
	tm.roughness = 1.0
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.10, 0.32, 0.12)
	cm.roughness = 1.0
	trunk.material = tm
	crown.material = cm
	var mm_t := MultiMesh.new()
	mm_t.transform_format = MultiMesh.TRANSFORM_3D
	mm_t.mesh = trunk
	mm_t.instance_count = trees_n
	var mm_c := MultiMesh.new()
	mm_c.transform_format = MultiMesh.TRANSFORM_3D
	mm_c.mesh = crown
	mm_c.instance_count = trees_n
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in trees_n:
		var th := rng.randf() * TAU
		var off := rng.randf_range(11.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector2 = track.center(th)
		var t: Vector2 = track.tangent(th)
		var p := c + Vector2(-t.y, t.x) * off
		var sc := rng.randf_range(0.8, 1.7)
		mm_t.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(p.x, 1.2 * sc, p.y)))
		mm_c.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(p.x, 4.4 * sc, p.y)))
	var a := MultiMeshInstance3D.new()
	a.multimesh = mm_t
	var b := MultiMeshInstance3D.new()
	b.multimesh = mm_c
	trees_node.add_child(a)
	trees_node.add_child(b)

func _rebuild_cars() -> void:
	for c in cars:
		c.visual.queue_free()
	cars.clear()
	var d: Dictionary = vehicles["t1plus"].duplicate()
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var paints := [Color(0.10, 0.31, 0.88), Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.1), Color(0.15, 0.7, 0.35), Color(0.9, 0.9, 0.92), Color(0.6, 0.2, 0.8), Color(0.95, 0.45, 0.1), Color(0.1, 0.75, 0.8)]
	for i in cars_n:
		var lo := (i > 0) or not hi_model
		var car := Car.new(track, VehicleParams.from_dict(d), i == 0, lo, paints[i % paints.size()], Color(1.0, 0.42, 0.03))
		if i > 0:
			car.driver = RingDriver.new(track, 20.0 + float((i * 7) % 9), (float((i * 5) % 7) - 3.0) * 0.9)
		var sp: Array = track.start_pose(i)
		car.place(sp[0], sp[1], sp[2])
		add_child(car.visual)
		if pilots_on:
			Pilot.create(car.visual.body, 0.37, 0.49, -0.31, lo)
			Pilot.create(car.visual.body, -0.37, 0.49, -0.31, lo)
		cars.append(car)
	cam_ready = false

func _on_option(key: String, value) -> void:
	match key:
		"cars":
			cars_n = int(value)
			_rebuild_cars()
		"trees":
			trees_n = int(value)
			_rebuild_trees()
		"pilots":
			pilots_on = int(value) == 1
			_rebuild_cars()
		"shadows":
			sun.shadow_enabled = int(value) == 1
		"hi":
			hi_model = int(value) == 1
			_rebuild_cars()

func _physics_process(dt: float) -> void:
	if cars.is_empty():
		return
	var pl: Car = cars[0]
	pl.in_throttle = hud.throttle
	pl.in_brake = hud.brake
	pl.in_steer = hud.steer
	pl.in_handbrake = hud.handbrake
	var t0 := Time.get_ticks_usec()
	for c in cars:
		c.step(dt)
	phys_us += Time.get_ticks_usec() - t0
	phys_frames += 1

func _process(dt: float) -> void:
	if cars.is_empty():
		return
	for c in cars:
		c.update_visual(dt)
	var p: VehiclePhysics = cars[0].phys
	# cámara de seguimiento
	var target_yaw: float = p.yaw
	if not cam_ready:
		cam_yaw = target_yaw
		cam_ready = true
	cam_yaw = lerp_angle(cam_yaw, target_yaw, 1.0 - exp(-dt * 4.0))
	var fwd := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var pos := Vector3(p.px, p.py, p.pz)
	var want := pos - fwd * 7.5 + Vector3.UP * 2.7
	cam.position = want if cam.position.distance_to(want) > 30.0 else cam.position.lerp(want, 1.0 - exp(-dt * 9.0))
	cam.look_at(pos + fwd * 3.0 + Vector3.UP * 0.9)
	if cam_mode == "side":
		var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
		cam.position = pos + right * 5.0 + Vector3.UP * 0.6 + fwd * 1.0
		cam.look_at(pos + Vector3.UP * 0.1)
	elif cam_mode == "front":
		cam.position = pos + fwd * 6.0 + Vector3.UP * 1.6 + Vector3(cos(p.yaw), 0, -sin(p.yaw)) * 2.5
		cam.look_at(pos + Vector3.UP * 0.5)
	elif cam_mode == "top":
		cam.position = pos + Vector3.UP * 9.0 - fwd * 0.5
		cam.look_at(pos)
	# HUD
	hud.speed_kmh = absf(p.vLong) * 3.6
	hud.gear_text = "R" if p.gear < 0 else ("N" if p.gear == 0 else str(p.gear))
	stat_timer += dt
	frame_count += 1
	if stat_timer >= 0.5:
		var fps := Engine.get_frames_per_second()
		if phys_frames > 0:
			shown_phys_ms = float(phys_us) / 1000.0 / float(phys_frames)
		# la física corre a 120 Hz: ms por paso × pasos por cuadro
		var steps_per_frame := float(phys_frames) / maxf(1.0, float(frame_count))
		hud.stats_text = "FPS %d · cuadro %.1f ms · física %.2f ms/paso (%.1f pasos/cuadro)\nAutos %d · pilotos %s · árboles %d · sombras %s\nLlamadas %d · objetos %d · triángulos %dk" % [
			fps, dt * 1000.0, shown_phys_ms, steps_per_frame, cars_n, "sí" if pilots_on else "no", trees_n, "sí" if sun.shadow_enabled else "no",
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
		phys_us = 0
		phys_frames = 0
		frame_count = 0
		stat_timer = 0.0
		if bench and Engine.get_frames_drawn() > 60:
			fps_sum += fps
			fps_n += 1
	if shot_frames > 0 and Engine.get_frames_drawn() >= shot_frames:
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		if bench and fps_n > 0:
			print("BENCH fps medio %.1f · %s" % [fps_sum / fps_n, hud.stats_text.replace("\n", " | ")])
		get_tree().quit()
