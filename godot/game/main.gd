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
const DebugPanel := preload("res://game/ui/debug_panel.gd")
const Controls := preload("res://game/ui/controls.gd")
const Effects := preload("res://game/fx/effects.gd")
const Weather := preload("res://game/fx/weather.gd")
const Lens := preload("res://game/fx/lens.gd")
const Cockpit := preload("res://game/car/cockpit.gd")
const CarAudio := preload("res://game/audio/car_audio.gd")
const CameraRig := preload("res://game/car/camera_rig.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")

var track: CircuitTrack
var cars: Array = []
var vehicles: Dictionary
var cam: Camera3D
var sun: DirectionalLight3D
var hud: Control # panel de pruebas
var controls: Control # controles de manejo
var trees_node: Node3D
var fx: Node3D # humo, polvo y marcas
var weather: Node3D
var env: Environment
var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var weather_name := "dia"
var force_steer := 0.0
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
var threaded := true
var manual_gearbox := false
var nitro_test := false
var world: SubViewport # el mundo 3D se dibuja acá, a menor resolución que la pantalla (el HUD queda nítido)
var view_rect: TextureRect
var res_scale := 0.5
var bench_i := -1 # índice de la prueba automática en curso (-1 = apagada)
var bench_t := 0.0
var _bench_samples: Array = []
var report_body: Array = [] # líneas detalladas por configuración
var bench_results: Array = []
var no_body := false
var force_gas := false
var force_hb := false
var dirt_test := false
var autobench := false
var acc := 0.0
var step_n := 0
var fx_on := true
var res_auto := true # la resolución del mundo 3D se ajusta sola según los cuadros por segundo
var script_ms := 0.0
var cockpit: Node3D
var audio: Node
var pl_events: Array = []
var pl_impact := 0.0
var audio_on := true
var audiorec_path := ""
var audiorec: AudioEffectRecord
var cam_rig: RefCounted
var was_inside := false
var was_onboard := false
var cam_index := 1
var lens_auto := true # el filtro se apaga solo si el teléfono no llega
var lens: Node # filtro de cámara (Lente Rally)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--audiorec="):
			audiorec_path = a.substr(11)
		elif a == "--autobench":
			autobench = true
		elif a.begins_with("--steer="):
			force_steer = float(a.substr(8))
		elif a.begins_with("--weather="):
			weather_name = a.substr(10)
		elif a == "--dirt":
			dirt_test = true
		elif a == "--hb":
			force_hb = true
		elif a == "--gas":
			force_gas = true
		elif a == "--nobody":
			no_body = true
		elif a == "--bench":
			bench = true
		elif a.begins_with("--cam="):
			cam_mode = a.substr(6)
			cam_index = {"onboard": 0, "cabin": 0, "chase": 1, "near": 2, "far": 3, "aerial": 4, "rear": 6, "hood": 7, "bumper": 8}.get(cam_mode, 1)
		elif a.begins_with("--cars="):
			cars_n = int(a.substr(7))
		elif a.begins_with("--trees="):
			trees_n = int(a.substr(8))
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	track = CircuitTrack.new()
	if dirt_test:
		track.outside_surf = 1.0
	_setup_viewport()
	_build_world()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	controls = Controls.new()
	layer.add_child(controls)
	hud = DebugPanel.new()
	layer.add_child(hud)
	hud.option_changed.connect(_on_option)
	hud.bench_pressed.connect(_bench_start)
	hud.copy_pressed.connect(_copy_report)
	controls.camera_pressed.connect(_next_camera)
	fx = Effects.new()
	world.add_child(fx)
	fx.setup(track)
	fx.set_quality("media")
	weather = Weather.new()
	world.add_child(weather)
	weather.setup(env, sun, cam, track, fx, road_mat, ground_mat)
	weather.apply(weather_name, true)
	audio = CarAudio.new()
	add_child(audio)
	if audiorec_path != "":
		audiorec = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, audiorec)
		audiorec.set_recording_active(true)
	audio.rain(weather_name == "lluvia")
	_rebuild_trees()
	_rebuild_cars()
	if autobench:
		_bench_start()

## En celulares de gama media dibujar a la resolución nativa (2400x1080) es lo que más pesa: el mundo 3D se dibuja en un
## SubViewport a una fracción de la pantalla y se estira; el HUD se dibuja aparte, a resolución completa.
func _setup_viewport() -> void:
	var l0 := CanvasLayer.new()
	l0.layer = 0
	add_child(l0)
	world = SubViewport.new()
	world.msaa_3d = Viewport.MSAA_DISABLED
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	view_rect = TextureRect.new()
	view_rect.texture = world.get_texture()
	view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l0.add_child(view_rect)
	lens = Lens.new()
	add_child(lens)
	lens.attach(view_rect)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	world.size = Vector2i(maxi(320, int(win.x * res_scale)), maxi(180, int(win.y * res_scale)))
	view_rect.position = Vector2.ZERO
	view_rect.size = get_viewport().get_visible_rect().size

func _build_world() -> void:
	env = Environment.new()
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
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_opacity = 0.42 # sombra clara y suave, no negra
	sun.shadow_blur = 2.5
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 1200.0
	world.add_child(cam)
	cam.make_current()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.21, 0.35, 0.15)
	gm.roughness = 1.0
	ground.material_override = gm
	ground_mat = gm
	world.add_child(ground)
	var road := MeshInstance3D.new()
	road.mesh = track.build_road_mesh()
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.9
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = rm
	road_mat = rm
	world.add_child(road)

## Bosque con tres capas de detalle según la distancia (zonas de 200 m; cada capa se dibuja solo dentro de su rango):
##   cerca  (0–190 m)     tronco + copa, con forma
##   media  (170–520 m)   un solo cono chato por árbol (barato) — con la niebla parece bosque
##   lejos  (500–950 m)   una cuarta parte de los árboles, más grandes: una "cortina" que se nota que hay bosque
## Al acercarte, las capas se cambian solas. Antes se dibujaba todo el campo.
const CHUNK := 200.0

func _rebuild_trees() -> void:
	if trees_node != null:
		trees_node.queue_free()
	trees_node = Node3D.new()
	world.add_child(trees_node)
	if trees_n <= 0:
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.24
	trunk.height = 2.4
	trunk.radial_segments = 5
	trunk.rings = 1
	trunk.cap_top = false
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.7
	crown.height = 4.6
	crown.radial_segments = 6
	crown.rings = 1
	crown.cap_top = false
	var low := CylinderMesh.new()
	low.top_radius = 0.0
	low.bottom_radius = 1.8
	low.height = 6.4
	low.radial_segments = 4
	low.rings = 1
	low.cap_top = false
	low.cap_bottom = false
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.30, 0.20, 0.12)
	tm.roughness = 1.0
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.10, 0.32, 0.12)
	cm.roughness = 1.0
	trunk.material = tm
	crown.material = cm
	low.material = cm
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var cells := {}
	for i in trees_n:
		var th := rng.randf() * TAU
		var off := rng.randf_range(11.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector2 = track.center(th)
		var t: Vector2 = track.tangent(th)
		var p := c + Vector2(-t.y, t.x) * off
		var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
		if not cells.has(key):
			cells[key] = []
		cells[key].append([p.x, p.y, rng.randf_range(0.8, 1.7)])
	for key in cells:
		var list: Array = cells[key]
		var center := Vector3((float(key.x) + 0.5) * CHUNK, 0.0, (float(key.y) + 0.5) * CHUNK)
		# cerca: tronco y copa
		var mm_t := _multimesh(trunk, list, center, 1.2, 1.0, 1)
		var mm_c := _multimesh(crown, list, center, 4.4, 1.0, 1)
		_add_tree_layer(mm_t, center, 0.0, 190.0)
		_add_tree_layer(mm_c, center, 0.0, 190.0)
		# media: un cono por árbol
		_add_tree_layer(_multimesh(low, list, center, 3.2, 1.0, 1), center, 170.0, 520.0)
		# lejos: uno de cada cuatro, más grande
		if list.size() >= 4:
			_add_tree_layer(_multimesh(low, list, center, 3.2, 1.7, 4), center, 500.0, 950.0)

## MultiMesh con los árboles de una zona (posiciones relativas al centro de la zona); cada "step"-ésimo árbol
func _multimesh(mesh: Mesh, list: Array, center: Vector3, y_off: float, size_k: float, step: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var n := int(ceil(float(list.size()) / float(step)))
	mm.instance_count = n
	for j in n:
		var e: Array = list[j * step]
		var sc: float = float(e[2]) * size_k
		mm.set_instance_transform(j, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(float(e[0]) - center.x, y_off * sc, float(e[1]) - center.z)))
	return mm

func _add_tree_layer(mm: MultiMesh, center: Vector3, r_begin: float, r_end: float) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.position = center # la distancia de visibilidad se mide hasta el origen del nodo: va en el centro de la zona
	inst.visibility_range_begin = r_begin
	inst.visibility_range_end = r_end
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # las sombras son solo de los autos
	trees_node.add_child(inst)

func _rebuild_cars() -> void:
	_finish_physics()
	if fx != null:
		fx.reset()
	for c in cars:
		c.visual.queue_free()
	cars.clear()
	var d: Dictionary = vehicles["t1plus"].duplicate()
	if nitro_test:
		d["nitroCap"] = 8.0
		d["nitroBoost"] = 0.35
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
		car.restart_history(sim_t)
		world.add_child(car.visual)
		if no_body:
			car.visual.body.get_child(0).visible = false
		# los vidrios son oscuros: la tripulación y el habitáculo solo se dibujan con las cámaras interiores del jugador
		if i == 0:
			var Vp: VehicleParams = car.phys.V
			cockpit = Cockpit.new(str(d.get("visualType", "t1plus")), paints[0], Color(1.0, 0.42, 0.03))
			cockpit.position = Vector3(0, -Vp.comHeight + Vp.rideOffset, 0)
			car.visual.add_child(cockpit)
			cockpit.set_engine(Vp.maxRpm, Vp.shiftUpRpm, Vp.nitroCap)
			cockpit.set_inside(false, false)
			cam_rig = CameraRig.new(cam, track)
			cam_rig.visual = car.visual
			cam_rig.cockpit = cockpit
			cam_rig.ground_off = -Vp.comHeight + Vp.rideOffset
			cam_rig.mount = car.visual.compute_mounts(float(cockpit.C["cowlZ"]), float(cockpit.C["eyeY"]))
			cam_rig.set_preset(cam_index)
			was_inside = false
			_load_cabin_cfg()
		cars.append(car)
		if i <= 3 and fx != null:
			fx.prepare(i)
	if not cars.is_empty():
		cars[0].phys.manual = manual_gearbox
		controls.manual = manual_gearbox
		controls.has_nitro = cars[0].phys.V.nitroCap > 0.0
	cam_ready = false

## Prueba automática: recorre varias cargas (cada una 6 s, descartando el primer segundo y medio) y muestra la tabla.
## [autos, árboles, pilotos, sombras, hilos, resolución]
## El 7º dato son cosas que se APAGAN para medir cuánto cuestan: e = efectos, c = cielo, n = niebla, h = controles/HUD, m = mundo 3D,
## f = filtro de cámara, a = sonido.
const BENCH_CFGS := [
	[1, 0, 0, 0, 1, 1.0, ""], [1, 0, 0, 0, 1, 0.5, ""], [1, 3000, 1, 0, 1, 0.5, ""], [4, 3000, 1, 0, 1, 0.5, ""],
	[8, 3000, 1, 0, 1, 0.5, ""], [8, 8000, 1, 0, 1, 0.5, ""], [8, 3000, 0, 0, 1, 0.5, ""], [8, 3000, 1, 0, 0, 0.5, ""], [4, 3000, 1, 1, 1, 0.5, ""],
	[1, 3000, 0, 0, 1, 0.5, ""], [1, 3000, 0, 0, 1, 0.5, "e"], [1, 3000, 0, 0, 1, 0.5, "c"], [1, 3000, 0, 0, 1, 0.5, "n"],
	[1, 3000, 0, 0, 1, 0.5, "f"], [1, 3000, 0, 0, 1, 0.5, "h"], [1, 3000, 0, 0, 1, 0.5, "m"], [1, 3000, 0, 0, 1, 0.5, "a"], [1, 3000, 0, 0, 1, 0.5, "ecnfa"]]

func _bench_start() -> void:
	DisplayServer.screen_set_keep_on(true) # que no se apague la pantalla durante la prueba
	bench_i = -1
	bench_results.clear()
	report_body.clear()
	_bench_next()

func _bench_next() -> void:
	bench_i += 1
	if bench_i >= BENCH_CFGS.size():
		bench_i = -1
		var lines := ["RESULTADOS (mandame una captura de esto)", "autos · árboles · pilotos · sombras · hilos · resolución  →  FPS · ms/cuadro · física ms · llamadas · triángulos"]
		for r in bench_results:
			lines.append(r)
		lines.append("LISTO. El informe ya quedó copiado (pegalo en el chat). INFORME lo vuelve a copiar.")
		hud.result_text = "\n".join(lines)
		hud.stats_text = ""
		hud.banner = ""
		_copy_report() # queda copiado solo: ya se puede pegar en el chat
		if autobench:
			await get_tree().create_timer(0.5).timeout
			if shot_path != "":
				get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
		return
	var c: Array = BENCH_CFGS[bench_i]
	var new_trees: int = c[1]
	cars_n = c[0]
	pilots_on = c[2] == 1
	sun.shadow_enabled = c[3] == 1
	threaded = c[4] == 1
	res_scale = c[5]
	res_auto = false
	_apply_diag(str(c[6]))
	_on_resize()
	if new_trees != trees_n or trees_node == null:
		trees_n = new_trees
		_rebuild_trees()
	_rebuild_cars()
	# el jugador también maneja solo, así la escena está siempre en movimiento
	if not cars.is_empty():
		cars[0].driver = RingDriver.new(track, 26.0, 0.0)
	bench_t = 0.0

## Apaga a propósito partes del juego para medir cuánto cuesta cada una (ver BENCH_CFGS)
func _apply_diag(flags: String) -> void:
	fx_on = not flags.contains("e")
	if not fx_on:
		fx.reset()
	weather.set_sky_enabled(not flags.contains("c"))
	env.fog_enabled = not flags.contains("n")
	controls.visible = not flags.contains("h")
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED if flags.contains("m") else SubViewport.UPDATE_ALWAYS
	lens.enabled = not flags.contains("f")
	audio_on = not flags.contains("a")
	audio.set_active(audio_on)

func _bench_tick(dt: float) -> void:
	bench_t += dt
	var left := int(ceil(float(BENCH_CFGS.size() - bench_i) * 7.5 - bench_t))
	hud.banner = "PRUEBA %d/%d · faltan %d s · NO TOQUES LA PANTALLA" % [bench_i + 1, BENCH_CFGS.size(), maxi(left, 0)]
	if bench_t > 1.5 and bench_t < 6.0:
		if bench_i >= 0:
			_bench_samples.append([dt, shown_phys_ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), script_ms])
	if bench_t >= 6.0:
		var dts: Array = []
		for smp in _bench_samples:
			dts.append(smp[0])
		dts.sort()
		var n := _bench_samples.size()
		var sdt := 0.0
		var sph := 0.0
		var sdc := 0.0
		var stri := 0.0
		var sscr := 0.0
		for s in _bench_samples:
			sdt += s[0]
			sph += s[1]
			sdc += s[2]
			stri += s[3]
			sscr += s[4]
		var c: Array = BENCH_CFGS[bench_i]
		if n > 0:
			bench_results.append("%2d autos · %5d árb · pil %s · som %s · hilos %s · res %3d%%%s  →  %3d FPS · %5.1f ms · fis %4.1f · código %4.1f ms · %4d llam · %dk tri" % [
				c[0], c[1], "sí" if c[2] == 1 else "no", "sí" if c[3] == 1 else "no", "sí" if c[4] == 1 else "no", int(c[5] * 100.0),
				(" · SIN " + str(c[6])) if str(c[6]) != "" else "",
				int(round(float(n) / sdt)), sdt / n * 1000.0, sph / n, sscr / n, int(sdc / n), int(stri / n / 1000.0)])
			var slow := 0
			var slow20 := 0
			for d in dts:
				if d > 0.0334:
					slow += 1
				if d > 0.0205:
					slow20 += 1
			report_body.append("  #%d: cuadros %d · p50 %.1f ms · p95 %.1f ms · p99 %.1f ms · peor %.1f ms · cuadros >20 ms (bajan de 50 FPS) %.1f%% · cuadros >33 ms (tirones) %d (%.1f%%) · memoria de video %d MB · texturas %d MB" % [
				bench_i + 1, n, float(dts[n / 2]) * 1000.0, float(dts[int(n * 0.95)]) * 1000.0, float(dts[mini(n - 1, int(n * 0.99))]) * 1000.0, float(dts[n - 1]) * 1000.0, 100.0 * slow20 / n, slow, 100.0 * slow / n,
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0)])
		_bench_samples.clear()
		_bench_next()

## Informe completo: datos del teléfono + versión del juego + tabla de la prueba. Se copia al portapapeles y se guarda en un archivo.
func _build_report() -> String:
	var v := "completo (todo adentro)"
	if FileAccess.file_exists("user://content_version.txt"):
		v = FileAccess.get_file_as_string("user://content_version.txt").strip_edges()
	var mem := OS.get_memory_info()
	var out: Array = []
	out.append("=== INFORME GSKORP RALLY (Godot) ===")
	out.append("Fecha: " + Time.get_datetime_string_from_system())
	out.append("Juego: versión %s" % v)
	out.append("Motor: Godot %s · renderizador %s" % [Engine.get_version_info()["string"], str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))])
	var ver := OS.get_version()
	if ver == "" and OS.has_method("get_version_alias"):
		ver = str(OS.call("get_version_alias"))
	out.append("Teléfono: %s · %s %s" % [OS.get_model_name(), OS.get_name(), ver])
	var cpu := OS.get_processor_name()
	if cpu.strip_edges() == "":
		cpu = _proc_value("/proc/cpuinfo", ["Hardware", "model name", "Processor"])
	var freqs: Array = []
	for i in OS.get_processor_count():
		var f := "/sys/devices/system/cpu/cpu%d/cpufreq/cpuinfo_max_freq" % i
		if FileAccess.file_exists(f):
			freqs.append(str(int(FileAccess.get_file_as_string(f).strip_edges().to_int() / 1000)))
	out.append("Procesador: %s · %d núcleos%s" % [cpu if cpu != "" else "(no informa)", OS.get_processor_count(), (" · MHz máx.: " + ", ".join(freqs)) if freqs.size() > 0 else ""])
	var mem_total := int(float(mem.get("physical", 0)) / 1048576.0)
	var mem_free := int(float(mem.get("available", mem.get("free", 0))) / 1048576.0)
	if mem_total <= 0:
		mem_total = int(_proc_value("/proc/meminfo", ["MemTotal"]).to_int() / 1024)
		mem_free = int(_proc_value("/proc/meminfo", ["MemAvailable"]).to_int() / 1024)
	out.append("Memoria: %d MB en total · %d MB libres" % [mem_total, mem_free])
	out.append("GPU: %s · %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	var hz := DisplayServer.screen_get_refresh_rate()
	out.append("Dibujado del mundo 3D a %d%% de la pantalla" % int(res_scale * 100.0))
	out.append("Pantalla: %dx%d · %s Hz" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y, ("%.0f" % hz) if is_finite(hz) and hz > 0.0 else "?"])
	out.append("")
	if bench_results.is_empty():
		out.append("(No se corrió la prueba automática. Estado actual:)")
		out.append(hud.stats_text.replace("\n", " | "))
	else:
		out.append("PRUEBA AUTOMÁTICA (cada configuración 6 s, sin contar el primer segundo y medio)")
		out.append("autos · árboles · pilotos · sombras · hilos · resolución  →  FPS · ms/cuadro · física ms · código ms · llamadas · triángulos")
		for r in bench_results:
			out.append(r)
		out.append("")
		out.append("(SIN e=efectos c=cielo n=niebla f=filtro de cámara h=controles m=mundo 3D: se apaga a propósito para medir cuánto cuesta; código = tiempo del script por cuadro)")
		out.append("(fís = milisegundos por cuadro que el hilo principal pierde esperando a la física; con hilos debería ser ~0)")
		out.append("DETALLE (p50/p95/p99 = tiempo de cuadro del 50%, 95% y 99% de los cuadros; cuadros lentos = tirones)")
		for r in report_body:
			out.append(r)
	return "\n".join(out)

## Lee un valor de /proc (Android lo deja leer): busca la primera línea "clave: valor"
func _proc_value(path: String, keys: Array) -> String:
	if not FileAccess.file_exists(path):
		return ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		for k in keys:
			if line.begins_with(k):
				var parts := line.split(":", true, 1)
				if parts.size() == 2:
					return parts[1].strip_edges()
	return ""

func _copy_report() -> void:
	var txt := _build_report()
	DisplayServer.clipboard_set(txt)
	var f := FileAccess.open("user://informe_gskorp.txt", FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	hud.show_toast("Informe copiado ✔  Pegalo en el chat")
	print(txt)

## Humo/polvo/marcas: el propio siempre; los rivales solo si están cerca y a la vista (y a menor ritmo). Los rivales muy
## lejanos ni se dibujan.
func _update_fx(dt: float) -> void:
	if not fx_on:
		return
	var cp := cam.position
	fx.tick(cp)
	for i in cars.size():
		var c: Car = cars[i]
		var pos := Vector3(c.snap.px, c.snap.py, c.snap.pz)
		var d := pos.distance_to(cp)
		if i > 0:
			c.visual.visible = d < 380.0
		if i == 0:
			fx.emit_from(0, c.snap, dt, 0.325)
		elif i <= 3 and d < 60.0 and cam.is_position_in_frustum(pos):
			fx.emit_from(i, c.snap, dt, 0.325, 0.5)

func _next_camera() -> void:
	if cam_rig == null:
		return
	cam_rig.next()
	hud.show_toast("🎥 " + cam_rig.cam_name())

func _load_cabin_cfg() -> void:
	if cockpit == null:
		return
	var cf := ConfigFile.new()
	if cf.load("user://cabina.cfg") == OK:
		cockpit.rear_dist = float(cf.get_value("cam", "rear", cockpit.rear_dist))
		cockpit.ob_dist = float(cf.get_value("cam", "ob", cockpit.ob_dist))
		cockpit.rear_fov = float(cf.get_value("cam", "rear_fov", cockpit.rear_fov))
		cockpit.ob_fov = float(cf.get_value("cam", "ob_fov", cockpit.ob_fov))
		cockpit.set_disp_off(float(cf.get_value("cam", "disp", cockpit.disp_off)))
	hud.sliders["cam_rear"]["val"] = cockpit.rear_dist
	hud.sliders["cam_rear_fov"]["val"] = cockpit.rear_fov
	hud.sliders["cam_ob"]["val"] = cockpit.ob_dist
	hud.sliders["cam_ob_fov"]["val"] = cockpit.ob_fov
	hud.sliders["disp_x"]["val"] = cockpit.disp_off

func _save_cabin_cfg() -> void:
	var cf := ConfigFile.new()
	cf.set_value("cam", "rear", cockpit.rear_dist)
	cf.set_value("cam", "ob", cockpit.ob_dist)
	cf.set_value("cam", "rear_fov", cockpit.rear_fov)
	cf.set_value("cam", "ob_fov", cockpit.ob_fov)
	cf.set_value("cam", "disp", cockpit.disp_off)
	cf.save("user://cabina.cfg")

func _on_option(key: String, value) -> void:
	match key:
		"cam_rear":
			cockpit.rear_dist = float(value)
			_save_cabin_cfg()
		"cam_ob":
			cockpit.ob_dist = float(value)
			_save_cabin_cfg()
		"cam_rear_fov":
			cockpit.rear_fov = float(value)
			_save_cabin_cfg()
		"cam_ob_fov":
			cockpit.ob_fov = float(value)
			_save_cabin_cfg()
		"disp_x":
			cockpit.set_disp_off(float(value))
			_save_cabin_cfg()
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
		"threads":
			threaded = int(value) == 1
		"res":
			res_auto = float(value) == 0.0
			if not res_auto:
				res_scale = float(value)
				_on_resize()
		"lens":
			lens.level = int(value)
			lens_auto = false
		"steer":
			controls.steer_mode = "wheel" if str(value) == "volante" else "slider"
		"gearbox":
			manual_gearbox = str(value) == "manual"
			if not cars.is_empty():
				cars[0].phys.manual = manual_gearbox
			controls.manual = manual_gearbox
		"gyro":
			controls.gyro_on = int(value) == 1
			controls.recalibrate_gyro()
		"nitro":
			nitro_test = int(value) == 1
			_rebuild_cars()
		"weather":
			weather.apply(str(value))
			audio.rain(str(value) == "lluvia")
		"recal":
			controls.recalibrate_gyro()
			hud.show_toast("Acelerómetro calibrado: sostené el teléfono como para jugar")

## Física a 120 Hz con paso fijo propio, UN CUADRO ADELANTADA y en otros núcleos:
##  · al empezar el cuadro se espera (casi nunca) a que terminen los pasos del cuadro anterior y se toma una foto de cada auto;
##  · enseguida se lanza la física del cuadro que viene (una tarea por auto) y el hilo principal sigue con el dibujado.
## El dibujado y la cámara usan solo la foto. Costo: un cuadro (16 ms) más de retardo al girar el volante.
var phys_task := -1
var sim_t := 0.0 # hora de la simulación (múltiplo de 1/120 s)
var batch_t0 := 0.0
var render_t := 0.0
var smooth_dt := 0.016
var phys_wait_us := 0

func _finish_physics() -> void:
	if phys_task != -1:
		var t0 := Time.get_ticks_usec()
		WorkerThreadPool.wait_for_group_task_completion(phys_task)
		phys_wait_us += Time.get_ticks_usec() - t0
		phys_task = -1

func _step_physics(dt: float) -> void:
	_finish_physics()
	# eventos de la física (cambios, limitador, aterrizajes, golpes): se toman ahora, con los hilos parados
	for i in cars.size():
		var sn = cars[i].snap
		if i == 0:
			pl_events = sn.take_events()
			pl_impact = maxf(pl_impact, sn.take_impact())
		else:
			sn.pending_events.clear()
			sn.pending_impact = 0.0
	var h := 1.0 / 120.0
	smooth_dt = lerpf(smooth_dt, minf(dt, 0.1), 0.02)
	acc = minf(acc + dt, 0.05)
	step_n = int(acc / h)
	acc -= float(step_n) * h
	batch_t0 = sim_t
	sim_t += float(step_n) * h
	# hora que se dibuja: atrasada lo justo para que los estados que rodean esa hora ya estén calculados
	render_t = sim_t + acc - (smooth_dt * 1.3 + h)
	if step_n <= 0 or cars.is_empty():
		return
	var pl: Car = cars[0]
	pl.in_throttle = controls.gas
	pl.in_brake = controls.brake
	pl.in_steer = controls.steer
	pl.in_handbrake = controls.handbrake
	pl.in_nitro = controls.nitro
	if controls.shift != 0:
		pl.in_shift = controls.shift
	phys_frames += 1
	if threaded:
		phys_task = WorkerThreadPool.add_group_task(_step_car, cars.size(), -1, true, "fisica")
	else:
		var t0 := Time.get_ticks_usec()
		for i in cars.size():
			_step_car(i)
		phys_us += Time.get_ticks_usec() - t0

func _step_car(i: int) -> void:
	var c: Car = cars[i]
	for k in step_n:
		c.step_and_record(1.0 / 120.0, batch_t0 + float(k + 1) / 120.0)

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame(dt)
	script_ms = lerpf(script_ms, float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	if res_auto:
		_auto_res(dt)

## Resolución automática del mundo 3D: baja si el teléfono no llega y sube de a poco si le sobra
var _ar_t := 0.0
var _ar_sum := 0.0
var _ar_n := 0
var _ar_cool := 0.0
var _ar_cap := 0.8
func _auto_res(dt: float) -> void:
	if bench_i >= 0 or dt > 0.25:
		return
	_ar_t += dt
	_ar_sum += dt
	_ar_n += 1
	_ar_cool -= dt
	if _ar_t < 1.5:
		return
	var avg := _ar_sum / float(_ar_n)
	_ar_t = 0.0
	_ar_sum = 0.0
	_ar_n = 0
	var target := 1.0 / maxf(DisplayServer.screen_get_refresh_rate(), 30.0) if is_finite(DisplayServer.screen_get_refresh_rate()) else 0.0167
	target = clampf(target, 0.0083, 0.0167)
	if avg > target * 1.25 and res_scale <= 0.45 and lens.level > 0 and lens_auto:
		lens.level = 0 # ni bajando la resolución llega: el filtro de cámara es lo primero que se apaga
	elif avg > target * 1.25 and res_scale > 0.36:
		res_scale = maxf(0.35, res_scale - 0.05)
		_ar_cap = minf(_ar_cap, res_scale + 0.05) # ahí ya no llegaba: no vuelve a probar arriba enseguida
		_ar_cool = 20.0
		_on_resize()
	elif avg < target * 1.08 and res_scale < _ar_cap and _ar_cool <= 0.0:
		res_scale = minf(_ar_cap, res_scale + 0.05)
		_ar_cool = 6.0
		_on_resize()

func _frame(dt: float) -> void:
	controls.update_inputs(dt)
	if force_gas:
		controls.gas = 1.0
	if force_steer != 0.0:
		controls.steer = force_steer
	if force_hb:
		controls.handbrake = true
	_step_physics(dt)
	if bench_i >= 0:
		_bench_tick(dt)
	if cars.is_empty():
		return
	for c in cars:
		c.snap.sample(render_t)
		c.update_visual(dt)
	_update_fx(dt)
	var p = cars[0].snap
	# cámara (las de seguimiento, capó, paragolpes, libre y las dos interiores)
	var pos := Vector3(p.px, p.py, p.pz)
	var fwd := Vector3(sin(p.yaw), 0, cos(p.yaw))
	cam_rig.aspect = float(world.size.x) / float(maxi(1, world.size.y))
	cam_rig.update(dt, p, false)
	var inside: bool = cam_rig.is_inside() and cockpit != null
	var onboard: bool = cam_rig.mode() == "onboard"
	if inside != was_inside or onboard != was_onboard:
		was_inside = inside
		was_onboard = onboard
		cars[0].visual.body.visible = not inside
		controls.show_speed = not inside
		cockpit.set_inside(inside, not onboard)
	if inside:
		cockpit.update_crew(dt, p, controls.handbrake, cam_rig.time, 0.0)
		cockpit.update_cabin(dt, p, controls.handbrake, cam_rig.time)
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
	controls.speed_kmh = absf(p.vLong) * 3.6
	controls.gear_text = "R" if p.gear < 0 else ("N" if p.gear == 0 else str(p.gear))
	controls.rpm_frac = p.rpm / cars[0].phys.V.maxRpm
	lens.update(dt, controls.speed_kmh, 1.0 if controls.nitro else 0.0)
	if audio_on:
		audio.update(p, cars[0].phys.V, dt, pl_events, pl_impact)
		pl_events = []
		pl_impact = 0.0
		# el rival más cercano (a menos de 55 m) también suena
		var nd := -1.0
		var nrpm := 0.0
		for i in range(1, cars.size()):
			var d2 := Vector2(cars[i].snap.px - p.px, cars[i].snap.pz - p.pz).length()
			if d2 < 55.0 and (nd < 0.0 or d2 < nd):
				nd = d2
				nrpm = cars[i].snap.rpm
		audio.rival(nd, nrpm, cars[0].phys.V.firingOrder)
	stat_timer += dt
	frame_count += 1
	if stat_timer >= 0.5:
		var fps := Engine.get_frames_per_second()
		if phys_frames > 0:
			shown_phys_ms = float(phys_us + phys_wait_us) / 1000.0 / float(phys_frames)
		hud.stats_text = "FPS %d · cuadro %.1f ms · física %.2f ms/cuadro (%s)\nAutos %d · pilotos %s · árboles %d · sombras %s\nLlamadas %d · objetos %d · triángulos %dk" % [
			fps, dt * 1000.0, shown_phys_ms, "hilos" if threaded else "1 hilo", cars_n, "sí" if pilots_on else "no", trees_n, "sí" if sun.shadow_enabled else "no",
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
		phys_us = 0
		phys_wait_us = 0
		phys_frames = 0
		frame_count = 0
		stat_timer = 0.0
		if bench and Engine.get_frames_drawn() > 60:
			fps_sum += fps
			fps_n += 1
	if shot_frames > 0 and Engine.get_frames_drawn() >= shot_frames:
		if audiorec != null:
			audiorec.set_recording_active(false)
			audiorec.get_recording().save_to_wav(audiorec_path)
		print("VEL ", int(controls.speed_kmh), " km/h · marcha ", controls.gear_text, " · ", fx.debug_info())
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		if bench and fps_n > 0:
			print("BENCH fps medio %.1f · %s" % [fps_sum / fps_n, hud.stats_text.replace("\n", " | ")])
		get_tree().quit()
