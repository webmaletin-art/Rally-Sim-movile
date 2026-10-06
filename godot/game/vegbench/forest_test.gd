extends Node3D
## ImpostorForestTest — MAPA DE PRUEBA de vegetación y edificios (aislado: no toca pistas, física, vehículos ni menús del juego).
## Una pista corta de rally para conducir y comparar: árboles en 3D ORIGINAL · 8 VISTAS PNG · CROSS 2 PLANOS (1000 a 20 000) y una calle de ciudad con tres sistemas de edificios.
## Se maneja con los controles táctiles del juego; arriba a la izquierda se ven los FPS.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const Controls := preload("res://game/ui/controls.gd")
const Car := preload("res://game/car/car.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VegTrack := preload("res://game/vegbench/veg_track.gd")
const VegScatter := preload("res://game/vegbench/veg_scatter.gd")
const VegBuildings := preload("res://game/vegbench/veg_buildings.gd")
const TreeModels := preload("res://game/vegbench/tree_models.gd")
const TreeImpostor8View := preload("res://game/vegbench/tree_impostor_8view.gd")
const TreeCross2Planes := preload("res://game/vegbench/tree_cross.gd")

signal exit_requested

const PaperKit := preload("res://game/fx/paper_kit.gd")

const CAM_NAMES := ["PERSECUCIÓN", "LEJANA", "ALTA", "CAPÓ", "PARAGOLPES"]
const RIVAL_CARS := ["hatch", "suv", "muscle", "buggy"]
const SYSTEMS := ["3D ORIGINAL", ".PAP ACTUAL", "8 VISTAS PNG", "CROSS 2 PLANOS"]
const RESULTS_FILE := "user://vegbench_results.json"
const QUICK_COUNTS := [1000, 2000, 3000, 5000, 7500, 10000, 15000, 20000]
const B_COUNTS := [100, 200, 400, 800, 1000]
const CELL := 250.0 # los árboles van en bloques de 250 m (un MultiMesh por bloque y especie: el motor oculta los que no se ven)

var system := 2
var count := 1000
var b_system := 0 # edificios: 0 sin · 1 drift/aventura · 2 dream city · 3 papel
var b_count := 200
var auto_drive := false
var cam_mode := 0 # 0 persecución · 1 lejana · 2 alta · 3 capó · 4 paragolpes
var cam_yaw := 0.0 # giro de la cámara con el dedo (cámara libre alrededor del auto)
var cam_pitch := 0.0
var cam_zoom := 1.0
var rivals_n := 0
var rivals: Array = [] # autos de la IA
var menu_btn: Button
var panel_open := true

var track
var track_root: Node3D
var veg_root: Node3D
var bld_root: Node3D
var scatter
var buildings
var car
var cam: Camera3D
var controls: Control
var layer: CanvasLayer
var stats_l: Label
var panel_box: Control

var _state := "loading" # loading → terrain → scatter → run
var _terrain_rows: Array = []
var _terrain_r := 0
var _terrain_next := 0
var _sim_t := 0.0
var _acc := 0.0
var _species_ids: Array = []
var _fps_min := 1e9
var _fps_sum := 0.0
var _fps_n := 0
var _fps_t := 0.0
# argumentos de prueba en PC (sólo capturas): --vb_sys=0|1|2 --vb_count=N --vb_bsys=0..3 --vb_bcount=N --vb_auto --vb_shot=ruta.png --vb_frames=N --vb_nopanel
var _shot_path := ""
var _shot_frames := 200
var _frame_n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vb_sys="):
			system = clampi(int(a.substr(9)), 0, 3)
		elif a.begins_with("--vb_count="):
			count = int(a.substr(11))
		elif a.begins_with("--vb_bsys="):
			b_system = clampi(int(a.substr(10)), 0, 3)
		elif a.begins_with("--vb_bcount="):
			b_count = int(a.substr(12))
		elif a == "--vb_auto":
			auto_drive = true
		elif a.begins_with("--vb_shot="):
			_shot_path = a.substr(10)
		elif a.begins_with("--vb_frames="):
			_shot_frames = int(a.substr(12))
		elif a == "--vb_nopanel":
			panel_open = false
		elif a.begins_with("--vb_cam="):
			cam_mode = clampi(int(a.substr(9)), 0, 4)
		elif a.begins_with("--vb_rivals="):
			rivals_n = clampi(int(a.substr(12)), 0, 4)
	for t in TreeModels.TREES:
		_species_ids.append(str(t["id"]))
	layer = CanvasLayer.new()
	add_child(layer)
	stats_l = Kit.label("Cargando…", 20, Kit.TEXT)
	var sp := Kit.panel(8, Color(0.03, 0.04, 0.06, 0.78))
	sp.position = Vector2(10, 8)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(stats_l)
	layer.add_child(sp)
	_build_world()

# ───────────────────────── mundo ─────────────────────────
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.32, 0.5, 0.78)
	psm.sky_horizon_color = Color(0.7, 0.8, 0.9)
	psm.ground_horizon_color = Color(0.62, 0.72, 0.8)
	psm.ground_bottom_color = Color(0.3, 0.4, 0.3)
	sky.sky_material = psm
	env.sky = sky
	TreeModels.set_ambient(env)
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_density = 0.0006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	TreeModels.add_sun(self)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.3
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	track = VegTrack.create()
	# la caja del terreno se amplía para cubrir también los árboles lejanos (hasta ~800 m del camino)
	track.min_xz -= Vector2(700, 700)
	track.max_xz += Vector2(700, 700)
	track_root = Node3D.new()
	add_child(track_root)
	var road := MeshInstance3D.new()
	road.mesh = track.build_road_mesh()
	track_root.add_child(road)
	var sh := MeshInstance3D.new()
	sh.mesh = track.build_shoulder_mesh()
	track_root.add_child(sh)
	var dims: Dictionary = track.terrain_dims(34.0)
	_terrain_r = int(dims["R"])
	_terrain_rows.resize(_terrain_r + 1)
	# el auto (una pickup de serie)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var st: Dictionary = Profile.new_car_state("pickup")
	var d: Dictionary = CarBuild.build_params(vehicles["pickup"], st, {"abs": true, "tc": 50.0, "stab": 40.0})
	car = Car.new(track.make_view(), VehicleParams.from_dict(d), true, false, Color(0.75, 0.1, 0.1), Color(0.8, 0.8, 0.85))
	var sp: Array = track.start_pose(0, 0)
	car.place(sp[0], sp[1], sp[2])
	track_root.add_child(car.visual)
	# controles táctiles del juego (volante y pedales); el botón de pausa abre/cierra el panel
	controls = Controls.new()
	layer.add_child(controls)
	controls.show_shot = false
	controls.pause_pressed.connect(func() -> void: _set_panel(not panel_open))
	controls.camera_pressed.connect(_next_cam)
	controls.cam_drag.connect(func(rel: Vector2) -> void:
		cam_yaw -= rel.x * 0.006
		cam_pitch = clampf(cam_pitch + rel.y * 0.004, -0.5, 0.9))
	controls.cam_zoom.connect(func(f: float) -> void: cam_zoom = clampf(cam_zoom / f, 0.5, 2.5))
	# botón siempre a la vista para volver a abrir el menú cuando está oculto
	menu_btn = Kit.button("☰ MENÚ", func() -> void: _set_panel(true), true, 16, Vector2(110, 44))
	menu_btn.position = Vector2(10, 100)
	menu_btn.visible = not panel_open
	layer.add_child(menu_btn)
	scatter = VegScatter.new()
	scatter.setup(track, _species_ids.size())
	buildings = VegBuildings.new()
	buildings.setup(track)
	_build_panel()

func _terrain_step(budget_rows: int) -> void:
	var done := 0
	while _terrain_next <= _terrain_r and done < budget_rows:
		_terrain_rows[_terrain_next] = track.terrain_row(_terrain_next, _terrain_r)
		_terrain_next += 1
		done += 1
	if _terrain_next > _terrain_r:
		var mi := MeshInstance3D.new()
		mi.mesh = track.build_terrain_mesh(_terrain_rows, _terrain_r)
		track_root.add_child(mi)
		_terrain_rows.clear()
		_state = "scatter"

# ───────────────────────── árboles ─────────────────────────
func _mesh_of(sid: String) -> Mesh:
	if system == 0:
		return TreeModels.original(sid)["mesh"]
	if system == 1:
		return PaperKit.mesh(str(TreeModels.info(sid)["src"])) # el papercraft actual del mismo árbol (geometría de pocos triángulos con color liso por cara)
	if system == 2:
		return TreeImpostor8View.build(sid)["mesh"]
	return TreeCross2Planes.build(sid)["mesh"]

func _rebuild_veg() -> void:
	if veg_root != null:
		veg_root.queue_free()
	veg_root = Node3D.new()
	add_child(veg_root)
	var items: Array = scatter.items
	var n := mini(count, items.size())
	var groups: Dictionary = {}
	for i in n:
		var it: Array = items[i]
		var key := Vector3i(floori(float(it[0]) / CELL), floori(float(it[2]) / CELL), int(it[5]))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(it)
	for key in groups:
		veg_root.add_child(_chunk(_mesh_of(_species_ids[int(key.z)]), groups[key]))
	_reset_fps()

func _chunk(mesh: Mesh, list: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	var buf := PackedFloat32Array()
	buf.resize(list.size() * 12)
	var o := 0
	for e in list:
		var s := float(e[3])
		var yaw := float(e[4]) if system != 2 else 0.0 # el impostor de 8 vistas no gira: la luz está pintada en las imágenes
		var c := cos(yaw) * s
		var sn := sin(yaw) * s
		# Transform3D por filas: [bx.x by.x bz.x ox | bx.y by.y bz.y oy | bx.z by.z bz.z oz]
		buf[o] = c; buf[o + 1] = 0.0; buf[o + 2] = sn; buf[o + 3] = float(e[0])
		buf[o + 4] = 0.0; buf[o + 5] = s; buf[o + 6] = 0.0; buf[o + 7] = float(e[1])
		buf[o + 8] = -sn; buf[o + 9] = 0.0; buf[o + 10] = c; buf[o + 11] = float(e[2])
		o += 12
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _rebuild_buildings() -> void:
	if bld_root != null:
		bld_root.queue_free()
	bld_root = buildings.build(b_system, b_count)
	add_child(bld_root)
	_reset_fps()

# ───────────────────────── FPS ─────────────────────────
func _reset_fps() -> void:
	_fps_min = 1e9
	_fps_sum = 0.0
	_fps_n = 0
	_fps_t = 1.5 # un momento para que se asienten los FPS tras armar

func _fps_avg() -> float:
	return float(_fps_n) / maxf(_fps_sum, 0.001)

func _stats_text() -> String:
	var s := "%d FPS" % int(Engine.get_frames_per_second())
	if _fps_min < 1e8:
		s += "  (prom %d · mín %d)" % [int(_fps_avg()), int(_fps_min)]
	s += "\nÁRBOLES: %s · %d\n" % [SYSTEMS[system], mini(count, scatter.items.size())]
	s += "EDIFICIOS: %s" % VegBuildings.SYSTEMS[b_system]
	if b_system > 0:
		s += " · %d" % mini(b_count, buildings.spots.size())
	return s

# ───────────────────────── interfaz ─────────────────────────
func _set_panel(on: bool) -> void:
	panel_open = on
	if panel_box != null:
		panel_box.visible = on
	if menu_btn != null:
		menu_btn.visible = not on

func _row_btn(row: Container, text: String, cb: Callable, accent: bool, size := 15, h := 46.0) -> void:
	var b := Kit.button(text, cb, accent, size, Vector2(0, h))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)

func _build_panel() -> void:
	if panel_box != null:
		panel_box.queue_free()
	var pc := Kit.panel(10, Color(0.04, 0.05, 0.08, 0.93))
	panel_box = pc
	pc.position = Vector2(10, 108)
	pc.size = Vector2(560, 458)
	pc.visible = panel_open
	layer.add_child(pc)
	var sc := TouchScroll.new()
	sc.custom_minimum_size = Vector2(540, 444)
	pc.add_child(sc)
	var v := Kit.vbox(8)
	v.custom_minimum_size = Vector2(530, 0)
	sc.add_child(v)
	v.add_child(Kit.label("MAPA DE PRUEBA — VEGETACIÓN Y EDIFICIOS", 19, Kit.ACCENT))
	v.add_child(Kit.label("Pista corta de rally (%.1f km). Manejás vos; el botón de pausa abre y cierra este panel." % (float(track.length) / 1000.0), 12, Kit.MUTED))
	# árboles
	v.add_child(Kit.label("SISTEMA DE VEGETACIÓN", 15, Kit.GOLD))
	var row := Kit.grid(2, 6, 6)
	v.add_child(row)
	for i in SYSTEMS.size():
		var idx := i
		_row_btn(row, str(SYSTEMS[i]), func() -> void:
			system = idx
			_apply_veg(), system == i, 15, 46.0)
	v.add_child(Kit.label("CANTIDAD DE ÁRBOLES: %d" % count, 17, Kit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var g := Kit.grid(4, 5, 5)
	v.add_child(g)
	for q in QUICK_COUNTS:
		var qq: int = q
		_row_btn(g, str(qq), func() -> void:
			count = qq
			_apply_veg(), count == qq)
	# edificios
	v.add_child(Kit.label("SISTEMA DE EDIFICIOS (calle de ciudad a lo largo de la pista)", 15, Kit.GOLD))
	var g2 := Kit.grid(2, 6, 6)
	v.add_child(g2)
	for i in VegBuildings.SYSTEMS.size():
		var bi := i
		_row_btn(g2, str(VegBuildings.SYSTEMS[i]), func() -> void:
			b_system = bi
			_apply_bld(), b_system == bi, 15, 46.0)
	v.add_child(Kit.label("CANTIDAD DE EDIFICIOS: %d" % b_count, 17, Kit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var g3 := Kit.grid(5, 5, 5)
	v.add_child(g3)
	for q in B_COUNTS:
		var qq2: int = q
		_row_btn(g3, str(qq2), func() -> void:
			b_count = qq2
			_apply_bld(), b_count == qq2)
	v.add_child(Kit.label("CÁMARA Y RIVALES", 15, Kit.GOLD))
	var rc := Kit.hbox(5)
	v.add_child(rc)
	_row_btn(rc, "CÁMARA: " + str(CAM_NAMES[cam_mode]), func() -> void:
		_next_cam()
		_build_panel(), false, 14, 46.0)
	_row_btn(rc, "RIVALES: %d" % rivals_n, func() -> void:
		rivals_n = (rivals_n + 1) % 5
		_set_rivals()
		_build_panel(), rivals_n > 0, 14, 46.0)
	v.add_child(Kit.label("Con el botón de cámara del juego (o arriba) cambiás de cámara; arrastrando un dedo la girás y con dos dedos hacés zoom.", 12, Kit.MUTED))
	_build_log_ui(v)
	# otros
	var r5 := Kit.hbox(5)
	v.add_child(r5)
	_row_btn(r5, "MANEJA LA IA: " + ("SÍ" if auto_drive else "NO"), func() -> void:
		_set_auto(not auto_drive)
		_build_panel(), auto_drive)
	_row_btn(r5, "REINICIAR AUTO", func() -> void:
		var sp: Array = track.start_pose(0, 0)
		car.place(sp[0], sp[1], sp[2]), false)
	var r7 := Kit.hbox(5)
	v.add_child(r7)
	_row_btn(r7, "OCULTAR PANEL", func() -> void: _set_panel(false), true)
	_row_btn(r7, "← SALIR", func() -> void: exit_requested.emit(), false)

## Cambió una opción de árboles: se arma otra vez el bosque (siempre el mismo reparto)
func _apply_veg() -> void:
	if _state != "run":
		return
	_state = "busy"
	await _ensure_scatter(count)
	_rebuild_veg()
	_state = "run"
	_build_panel()

func _apply_bld() -> void:
	if _state != "run":
		return
	_rebuild_buildings()
	_build_panel()

func _ensure_scatter(upto: int) -> void:
	while not scatter.generate(upto, 700):
		stats_l.text = "Repartiendo árboles… %d / %d" % [scatter.items.size(), upto]
		await get_tree().process_frame

func _next_cam() -> void:
	cam_mode = (cam_mode + 1) % CAM_NAMES.size()
	cam_yaw = 0.0
	cam_pitch = 0.0
	cam_zoom = 1.0

## Rivales de la IA (0 a 4): autos de baja con el mismo manejo de la carrera, arrancan atrás del jugador
func _set_rivals() -> void:
	for r in rivals:
		r.visual.queue_free()
	rivals.clear()
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var phys: Array = [car.phys]
	for i in rivals_n:
		var id: String = RIVAL_CARS[i % RIVAL_CARS.size()]
		var st: Dictionary = Profile.new_car_state(id)
		st["tires"] = "gravel"
		var d: Dictionary = CarBuild.build_params(vehicles[id], st, {"abs": true, "tc": 50.0, "stab": 40.0})
		var paints := [Color(0.1, 0.35, 0.85), Color(0.95, 0.75, 0.1), Color(0.15, 0.7, 0.35), Color(0.9, 0.9, 0.92)]
		var c := Car.new(track.make_view(), VehicleParams.from_dict(d), false, true, paints[i % paints.size()], Color(0.2, 0.2, 0.22))
		var sp: Array = track.start_pose(i + 1, 0)
		c.place(sp[0], sp[1], sp[2])
		c.driver = AIDriver.new(track.make_view(), c.phys, {"skill": 0.8 + 0.04 * float(i), "lane": (float(i % 3) - 1.0) * 1.5, "aggr": 0.4})
		track_root.add_child(c.visual)
		rivals.append(c)
		phys.append(c.phys)
	for c in rivals:
		c.driver.others = phys

func _set_auto(on: bool) -> void:
	auto_drive = on
	car.driver = AIDriver.new(track.make_view(), car.phys, {"skill": 0.85}) if on else null
	controls.visible = not on

# ───────────────────────── cuadro a cuadro ─────────────────────────
func _process(dt: float) -> void:
	if _state == "loading":
		_state = "terrain"
		return
	if _state == "terrain":
		stats_l.text = "Armando el terreno… %d / %d" % [_terrain_next, _terrain_r + 1]
		_terrain_step(3)
		return
	if _state == "scatter":
		_state = "busy"
		await _ensure_scatter(count)
		_rebuild_veg()
		_rebuild_buildings()
		_state = "run"
		if rivals_n > 0:
			_set_rivals()
		_build_panel()
		if auto_drive:
			_set_auto(true)
		return
	if _state == "busy":
		return
	_drive(dt)
	if _fps_t > 0.0:
		_fps_t -= dt
	else:
		_fps_min = minf(_fps_min, 1.0 / maxf(dt, 0.0001))
		_fps_sum += dt
		_fps_n += 1
	stats_l.text = _stats_text()
	_frame_n += 1
	if _shot_path != "" and _frame_n == _shot_frames:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("VB ", stats_l.text.replace("\n", " | "))
		get_tree().quit()

func _drive(dt: float) -> void:
	_acc = minf(_acc + dt, 0.05)
	var h := 1.0 / 120.0
	if not auto_drive:
		# teclado (PC) además de los controles táctiles
		var kg := 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
		var kb := 1.0 if (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
		var ks := (1.0 if (Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0) - (1.0 if (Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0)
		car.in_throttle = maxf(controls.gas, kg)
		car.in_brake = maxf(controls.brake, kb)
		car.in_steer = controls.steer if absf(controls.steer) > 0.01 else ks * 0.6
		car.in_handbrake = controls.handbrake
	while _acc >= h:
		_acc -= h
		_sim_t += h
		car.step_and_record(h, _sim_t)
		for r in rivals:
			r.step_and_record(h, _sim_t)
	car.snap.sample(_sim_t - h)
	car.update_visual(dt)
	for r in rivals:
		r.snap.sample(_sim_t - h)
		r.update_visual(dt)
	controls.speed_kmh = absf(car.snap.vLong) * 3.6
	car.visual.visible = cam_mode != 3 # con la cámara de capó no se ve el techo del propio auto
	# cámara (5 modos); con el dedo se gira alrededor del auto y con dos dedos se acerca o aleja
	var yaw: float = car.snap.yaw
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var tgt := Vector3(car.snap.px, car.snap.py, car.snap.pz)
	var back: float = [8.5, 16.0, 11.0, -0.4, -2.3][cam_mode] * (cam_zoom if cam_mode < 3 else 1.0)
	var up: float = [3.4, 6.0, 15.0, 1.25, 0.75][cam_mode]
	var ang := yaw + PI + cam_yaw if cam_mode < 3 else yaw + cam_yaw * 0.6
	var dir := Vector3(sin(ang), 0.0, cos(ang))
	var want: Vector3
	if cam_mode < 3:
		want = tgt + dir * back + Vector3(0, up + cam_pitch * 6.0, 0)
		cam.position = cam.position.lerp(want, clampf(dt * 5.0, 0.0, 1.0)) if cam.position.distance_to(want) < 40.0 else want
		cam.look_at(tgt + fwd * 5.0 + Vector3(0, 1.3, 0))
	else:
		want = tgt + fwd * (-back) + Vector3(0, up, 0)
		cam.position = want
		var look := Vector3(sin(ang), -0.04 - cam_pitch * 0.5, cos(ang))
		cam.look_at(want + look * 20.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB:
		_set_panel(not panel_open)

# ───────────────────────── registro de mis pruebas ─────────────────────────
# Lo que se ve en el teléfono se anota con un toque: el FPS (promedio y mínimo desde el último cambio) sale del contador, lo demás lo marcás vos. Queda guardado en el teléfono
# (user://vegbench_results.json) y se copia como texto para pegarlo en el chat y analizarlo. No mide nada solo ni corre pruebas.
const OPT_QUALITY := ["1/5 mala", "2/5", "3/5 normal", "4/5", "5/5 muy buena"]
const OPT_STUTTER := ["NO", "POCOS", "MUCHOS"]
const OPT_YESNO := ["NO", "SÍ"]
const OPT_FAKE := ["NO", "UN POCO", "MUCHO"]
const OPT_TRANSP := ["NO", "ALGO", "MUCHOS"]
const OPT_DIST := ["NO SE NOTA", "CERCA (<30 m)", "MEDIA (30–100 m)", "LEJOS (100 m+)"]
var _q := {"quality": 2, "stutter": 0, "tex": 0, "fake": 0, "transp": 0, "dist": 0}
var _log: Array = []
var _log_shown := false
var _log_msg := ""

func _load_log() -> void:
	if not _log.is_empty() or not FileAccess.file_exists(RESULTS_FILE):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESULTS_FILE))
	if d is Array:
		_log = d

func _save_log() -> void:
	var f := FileAccess.open(RESULTS_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_log))
		f.close()

func _cycle(key: String, opts: Array) -> void:
	_q[key] = (int(_q[key]) + 1) % opts.size()
	_build_panel()

func _build_log_ui(v: VBoxContainer) -> void:
	_load_log()
	v.add_child(Kit.label("REGISTRO DE MIS PRUEBAS", 15, Kit.GOLD))
	v.add_child(Kit.label("Probá una combinación, conducí un rato y marcá lo que ves (tocá cada botón para cambiar el valor). El FPS lo toma del contador.", 12, Kit.MUTED))
	var g := Kit.grid(2, 6, 6)
	v.add_child(g)
	_row_btn(g, "CALIDAD VISUAL: " + str(OPT_QUALITY[int(_q["quality"])]), func() -> void: _cycle("quality", OPT_QUALITY), false, 13, 44.0)
	_row_btn(g, "TIRONES: " + str(OPT_STUTTER[int(_q["stutter"])]), func() -> void: _cycle("stutter", OPT_STUTTER), false, 13, 44.0)
	_row_btn(g, "CAMBIOS DE TEXTURA VISIBLES: " + str(OPT_YESNO[int(_q["tex"])]), func() -> void: _cycle("tex", OPT_YESNO), false, 12, 44.0)
	_row_btn(g, "SE VE FALSO: " + str(OPT_FAKE[int(_q["fake"])]), func() -> void: _cycle("fake", OPT_FAKE), false, 13, 44.0)
	_row_btn(g, "PROBLEMAS DE TRANSPARENCIA: " + str(OPT_TRANSP[int(_q["transp"])]), func() -> void: _cycle("transp", OPT_TRANSP), false, 12, 44.0)
	_row_btn(g, "SE EMPIEZA A NOTAR: " + str(OPT_DIST[int(_q["dist"])]), func() -> void: _cycle("dist", OPT_DIST), false, 12, 44.0)
	var r := Kit.hbox(5)
	v.add_child(r)
	_row_btn(r, "ANOTAR ÁRBOLES", func() -> void: _log_add("ÁRBOLES"), true, 14, 48.0)
	_row_btn(r, "ANOTAR EDIFICIOS", func() -> void: _log_add("EDIFICIOS"), true, 14, 48.0)
	var r2 := Kit.hbox(5)
	v.add_child(r2)
	_row_btn(r2, "VER (%d)" % _log.size(), func() -> void:
		_log_shown = not _log_shown
		_build_panel(), _log_shown, 14, 44.0)
	_row_btn(r2, "COPIAR", func() -> void:
		DisplayServer.clipboard_set(_log_text())
		_log_msg = "Copiado: pegalo en el chat."
		_build_panel(), false, 14, 44.0)
	_row_btn(r2, "BORRAR", func() -> void:
		_log.clear()
		_save_log()
		_log_msg = "Registro borrado."
		_build_panel(), false, 14, 44.0)
	if _log_msg != "":
		v.add_child(Kit.label(_log_msg, 13, Kit.GREEN))
	if _log_shown:
		var l := Kit.label(_log_text(), 11, Kit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		v.add_child(l)

func _log_add(kind: String) -> void:
	if _fps_n < 30:
		_log_msg = "Esperá unos segundos conduciendo así se arma el promedio de FPS."
		_build_panel()
		return
	var e := {
		"tipo": kind, "arboles_sistema": SYSTEMS[system], "arboles": mini(count, scatter.items.size()),
		"edificios_sistema": VegBuildings.SYSTEMS[b_system], "edificios": mini(b_count, buildings.spots.size()) if b_system > 0 else 0,
		"fps_prom": snappedf(_fps_avg(), 0.1), "fps_min": snappedf(_fps_min, 0.1), "segundos": snappedf(_fps_sum, 0.1),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"triangulos": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"calidad": OPT_QUALITY[int(_q["quality"])], "tirones": OPT_STUTTER[int(_q["stutter"])], "cambios_textura": OPT_YESNO[int(_q["tex"])],
		"se_ve_falso": OPT_FAKE[int(_q["fake"])], "transparencia": OPT_TRANSP[int(_q["transp"])], "se_nota": OPT_DIST[int(_q["dist"])]}
	_log.append(e)
	_save_log()
	_log_msg = "Anotado (%d): %s · FPS %d (mín %d)." % [_log.size(), kind, int(e["fps_prom"]), int(e["fps_min"])]
	_build_panel()

func _log_text() -> String:
	var lines: Array = ["INFORME DE PRUEBAS · %s · GPU: %s · Godot %s" % [OS.get_model_name(), RenderingServer.get_video_adapter_name(), Engine.get_version_info()["string"]]]
	if _log.is_empty():
		lines.append("(todavía no anotaste nada)")
	var i := 0
	for e in _log:
		i += 1
		var ent: Dictionary = e
		var subject: String
		if str(ent["tipo"]) == "ÁRBOLES":
			subject = "ÁRBOLES %s ×%d (edificios: %s ×%d)" % [ent["arboles_sistema"], int(ent["arboles"]), ent["edificios_sistema"], int(ent["edificios"])]
		else:
			subject = "EDIFICIOS %s ×%d (árboles: %s ×%d)" % [ent["edificios_sistema"], int(ent["edificios"]), ent["arboles_sistema"], int(ent["arboles"])]
		lines.append("%d) %s · FPS prom %.0f · mín %.0f (%.0f s) · llamadas %d · triáng. %d · calidad %s · tirones %s · cambios de textura %s · falso %s · transparencia %s · se nota: %s" % [
			i, subject, float(ent["fps_prom"]), float(ent["fps_min"]), float(ent["segundos"]), int(ent["draw_calls"]), int(ent["triangulos"]), ent["calidad"], ent["tirones"],
			ent["cambios_textura"], ent["se_ve_falso"], ent["transparencia"], ent["se_nota"]])
	return "\n".join(lines)
