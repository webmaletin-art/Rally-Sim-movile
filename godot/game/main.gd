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
var threaded := true
var world: SubViewport # el mundo 3D se dibuja acá, a menor resolución que la pantalla (el HUD queda nítido)
var view_rect: TextureRect
var res_scale := 0.5
var bench_i := -1 # índice de la prueba automática en curso (-1 = apagada)
var bench_t := 0.0
var _bench_samples: Array = []
var report_body: Array = [] # líneas detalladas por configuración
var bench_results: Array = []
var no_body := false
var autobench := false
var acc := 0.0
var step_n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a == "--autobench":
			autobench = true
		elif a == "--nobody":
			no_body = true
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
	_setup_viewport()
	_build_world()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.option_changed.connect(_on_option)
	hud.bench_pressed.connect(_bench_start)
	hud.copy_pressed.connect(_copy_report)
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
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	world.size = Vector2i(maxi(320, int(win.x * res_scale)), maxi(180, int(win.y * res_scale)))
	view_rect.position = Vector2.ZERO
	view_rect.size = get_viewport().get_visible_rect().size

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
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
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
	world.add_child(ground)
	var road := MeshInstance3D.new()
	road.mesh = track.build_road_mesh()
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.roughness = 0.9
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = rm
	world.add_child(road)

## Árboles: dos MultiMesh por zona de 300 m (troncos y copas). Cada zona se dibuja solo si está a la vista y a menos de
## 450 m: en un bosque grande el celular no paga por lo que no se ve.
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
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.30, 0.20, 0.12)
	tm.roughness = 1.0
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.10, 0.32, 0.12)
	cm.roughness = 1.0
	trunk.material = tm
	crown.material = cm
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var cells := {}
	for i in trees_n:
		var th := rng.randf() * TAU
		var off := rng.randf_range(11.0, 260.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var c: Vector2 = track.center(th)
		var t: Vector2 = track.tangent(th)
		var p := c + Vector2(-t.y, t.x) * off
		var key := Vector2i(floori(p.x / 300.0), floori(p.y / 300.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append([p.x, p.y, rng.randf_range(0.8, 1.7)])
	for key in cells:
		var list: Array = cells[key]
		var mm_t := MultiMesh.new()
		mm_t.transform_format = MultiMesh.TRANSFORM_3D
		mm_t.mesh = trunk
		mm_t.instance_count = list.size()
		var mm_c := MultiMesh.new()
		mm_c.transform_format = MultiMesh.TRANSFORM_3D
		mm_c.mesh = crown
		mm_c.instance_count = list.size()
		for i in list.size():
			var e: Array = list[i]
			var sc: float = e[2]
			mm_t.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(e[0], 1.2 * sc, e[1])))
			mm_c.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(e[0], 4.4 * sc, e[1])))
		for mm in [mm_t, mm_c]:
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.visibility_range_end = 450.0
			trees_node.add_child(inst)

func _rebuild_cars() -> void:
	_finish_physics()
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
		world.add_child(car.visual)
		if no_body:
			car.visual.body.get_child(0).visible = false
		if pilots_on:
			Pilot.create(car.visual.body, 0.37, 0.49, -0.31, lo)
			Pilot.create(car.visual.body, -0.37, 0.49, -0.31, lo)
		cars.append(car)
	cam_ready = false

## Prueba automática: recorre varias cargas (cada una 6 s, descartando el primer segundo y medio) y muestra la tabla.
## [autos, árboles, pilotos, sombras, hilos, resolución]
const BENCH_CFGS := [
	[1, 0, 0, 0, 1, 1.0], [1, 0, 0, 0, 1, 0.5], [1, 3000, 1, 0, 1, 0.5], [4, 3000, 1, 0, 1, 0.5],
	[8, 3000, 1, 0, 1, 0.5], [8, 8000, 1, 0, 1, 0.5], [8, 3000, 0, 0, 1, 0.5], [8, 3000, 1, 0, 0, 0.5], [4, 3000, 1, 1, 1, 0.5]]

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
	_on_resize()
	if new_trees != trees_n or trees_node == null:
		trees_n = new_trees
		_rebuild_trees()
	_rebuild_cars()
	# el jugador también maneja solo, así la escena está siempre en movimiento
	if not cars.is_empty():
		cars[0].driver = RingDriver.new(track, 26.0, 0.0)
	bench_t = 0.0

func _bench_tick(dt: float) -> void:
	bench_t += dt
	var left := int(ceil(float(BENCH_CFGS.size() - bench_i) * 7.5 - bench_t))
	hud.banner = "PRUEBA %d/%d · faltan %d s · NO TOQUES LA PANTALLA" % [bench_i + 1, BENCH_CFGS.size(), maxi(left, 0)]
	if bench_t > 1.5 and bench_t < 6.0:
		if bench_i >= 0:
			_bench_samples.append([dt, shown_phys_ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
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
		for s in _bench_samples:
			sdt += s[0]
			sph += s[1]
			sdc += s[2]
			stri += s[3]
		var c: Array = BENCH_CFGS[bench_i]
		if n > 0:
			bench_results.append("%2d autos · %5d árb · pil %s · som %s · hilos %s · res %3d%%  →  %3d FPS · %5.1f ms · fis %4.1f · %4d llam · %dk tri" % [
				c[0], c[1], "sí" if c[2] == 1 else "no", "sí" if c[3] == 1 else "no", "sí" if c[4] == 1 else "no", int(c[5] * 100.0),
				int(round(float(n) / sdt)), sdt / n * 1000.0, sph / n, int(sdc / n), int(stri / n / 1000.0)])
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
		out.append("autos · árboles · pilotos · sombras · hilos · resolución  →  FPS · ms/cuadro · física ms · llamadas · triángulos")
		for r in bench_results:
			out.append(r)
		out.append("")
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
		"threads":
			threaded = int(value) == 1
		"res":
			res_scale = float(value)
			_on_resize()

## Física a 120 Hz con paso fijo propio, UN CUADRO ADELANTADA y en otros núcleos:
##  · al empezar el cuadro se espera (casi nunca) a que terminen los pasos del cuadro anterior y se toma una foto de cada auto;
##  · enseguida se lanza la física del cuadro que viene (una tarea por auto) y el hilo principal sigue con el dibujado.
## El dibujado y la cámara usan solo la foto. Costo: un cuadro (16 ms) más de retardo al girar el volante.
var phys_task := -1
var phys_wait_us := 0

func _finish_physics() -> void:
	if phys_task != -1:
		var t0 := Time.get_ticks_usec()
		WorkerThreadPool.wait_for_group_task_completion(phys_task)
		phys_wait_us += Time.get_ticks_usec() - t0
		phys_task = -1
		for c in cars:
			c.capture()

func _step_physics(dt: float) -> void:
	_finish_physics()
	var h := 1.0 / 120.0
	acc = minf(acc + dt, 0.05)
	step_n = int(acc / h)
	acc -= float(step_n) * h
	if step_n <= 0 or cars.is_empty():
		return
	var pl: Car = cars[0]
	pl.in_throttle = hud.throttle
	pl.in_brake = hud.brake
	pl.in_steer = hud.steer
	pl.in_handbrake = hud.handbrake
	phys_frames += 1
	if threaded:
		phys_task = WorkerThreadPool.add_group_task(_step_car, cars.size(), -1, true, "fisica")
	else:
		var t0 := Time.get_ticks_usec()
		for i in cars.size():
			_step_car(i)
		phys_us += Time.get_ticks_usec() - t0
		for c in cars:
			c.capture()

func _step_car(i: int) -> void:
	var c: Car = cars[i]
	for k in step_n:
		c.step(1.0 / 120.0)

func _process(dt: float) -> void:
	_step_physics(dt)
	if bench_i >= 0:
		_bench_tick(dt)
	if cars.is_empty():
		return
	for c in cars:
		c.update_visual(dt)
	var p = cars[0].snap
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
	elif cam_mode == "cabin":
		cam.position = pos + Vector3.UP * 2.3 - fwd * 2.2 + Vector3(cos(p.yaw), 0, -sin(p.yaw)) * 1.2
		cam.look_at(pos + Vector3.UP * 0.1 + fwd * 0.2)
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
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		if bench and fps_n > 0:
			print("BENCH fps medio %.1f · %s" % [fps_sum / fps_n, hud.stats_text.replace("\n", " | ")])
		get_tree().quit()
