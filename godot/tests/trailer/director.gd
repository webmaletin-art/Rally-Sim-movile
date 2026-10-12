## Director del tráiler: arma una escena del juego (mundo/ruta, sala de exhibición o pantalla del menú), mueve la cámara a donde pide la lista de tomas
## y guarda cada foto en Full HD. No va en el juego (la carpeta tests/ no se exporta); lo usa tools/trailer/ (ver docs/TRAILER.md).
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1920x1080 --script res://tests/trailer/director.gd -- --job=/ruta/trabajo.json
##
## Trabajo (JSON):
##  mode    "world" (una carrera/ruta/ciudad con el motor real) | "studio" (la sala de exhibición del garaje)
##  out     carpeta de salida · quality  "jpg" (por defecto) o "png"
##  settings  ajustes del perfil que se pisan (calidad, árboles, sombras…)
##  cfg     configuración de la carrera (como la arma el menú) · car, paint  → el auto del jugador
##  shots   lista de tomas: {name, cam, fov, sim, tp, pilots, env, wait, hide_car}
##    cam  {"orbit": {a, r, h, lh}}  cámara a ángulo `a` (0 = adelante del auto mirándolo, 180 = atrás), radio r, altura h y punto mirado a lh de altura
##         {"rel": [der, alto, adel], "look": [der, alto, adel]}  relativa al auto
##         {"abs": [x, y, z], "look": [x, y, z]}  absoluta
##         "roll" (grados) inclina el horizonte
##    sim  segundos que corre la simulación antes de la toma (el jugador maneja solo)
##    tp   {"frac": 0..1, "lat": m}  pone al jugador en esa fracción de la ruta
##    pilots [{clip, t, at: [der, adel], face: "car"|"cam"|grados, h}]  pilotos de pie con un gesto de Mixamo
##    orbit con "n": una vuelta de n cuadros (a0 → a1) en una sola toma (cuadro a cuadro)
extends SceneTree

const Profile := preload("res://game/data/profile.gd")
const RACE_SCENE := preload("res://game/race.tscn")
const Showroom := preload("res://game/ui/showroom.gd")
const RigPilot := preload("res://game/car/rig_pilot.gd")
const MixamoClips := preload("res://game/car/mixamo_clips.gd")
const RouteTrack := preload("res://game/track/route_track.gd")

class Hook:
	extends Node
	var d
	func _process(_dt: float) -> void:
		d.apply_goal()

var job: Dictionary = {}
var out_dir := ""
var mode := "world"
var fmt := "jpg"
var profile: RefCounted
var race: Node
var room: Node3D
var track
var cam: Camera3D
var goal: Dictionary = {} # {pos, look, fov, roll}
var crew: Array = [] # [{node, rig, pl, spec}]
var loaded := false
var hook: Node
var vehicles: Dictionary = {}
var count := 0
var t_start := 0

func _initialize() -> void:
	t_start = Time.get_ticks_msec()
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--job="):
			path = a.substr(6)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path != "" else null
	if not (parsed is Dictionary):
		push_error("director: falta --job=trabajo.json")
		quit(2)
		return
	job = parsed
	out_dir = str(job.get("out", "/tmp/trailer/out"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	mode = str(job.get("mode", "world"))
	fmt = str(job.get("format", "jpg"))
	_run()

func _run() -> void:
	profile = Profile.new()
	var st: Dictionary = profile.d["settings"]
	# calidad de «foto»: todo al máximo (la computadora de pruebas no corre a 60 cuadros, no importa)
	for k in {"gfxMode": "manual", "quality": "high", "res": 1.0, "frameRes": 0, "trees": 6000, "shadowsQ": true, "textures": "high", "particles": 10, "capBtn": false, "showFps": false, "diagBtn": false, "worldLife": true, "worldWeather": true, "lang": "es", "hud": "full"}:
		st[k] = {"gfxMode": "manual", "quality": "high", "res": 1.0, "frameRes": 0, "trees": 6000, "shadowsQ": true, "textures": "high", "particles": 10, "capBtn": false, "showFps": false, "diagBtn": false, "worldLife": true, "worldWeather": true, "lang": "es", "hud": "full"}[k]
	for k in (job.get("settings", {}) as Dictionary):
		st[k] = job["settings"][k]
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	root.msaa_3d = Viewport.MSAA_4X
	hook = Hook.new()
	hook.d = self
	hook.process_priority = 100000
	root.add_child(hook)
	if mode == "studio":
		await _start_studio()
	else:
		await _start_world()
	print("director: escena lista en %.1f s" % [float(Time.get_ticks_msec() - t_start) / 1000.0])
	for s in (job.get("shots", []) as Array):
		await _shot(s as Dictionary)
	print("director: %d fotos en %.1f s" % [count, float(Time.get_ticks_msec() - t_start) / 1000.0])
	quit(0)

# ───────────────────────── arranque de las escenas ─────────────────────────
func _car_state(id: String) -> Dictionary:
	var state: Dictionary = Profile.new_car_state(id)
	var pt: Dictionary = job.get("paint", {})
	for k in pt:
		(state["paint"] as Dictionary)[k] = pt[k]
	for k in (job.get("state", {}) as Dictionary):
		state[k] = job["state"][k]
	return state

func _start_world() -> void:
	for k in (job.get("env", {}) as Dictionary): # variables de entorno de prueba del juego (DR_POS = x,z,grados · DR_SPAWN = lugar de aparición)
		OS.set_environment(str(k), str(job["env"][k]))
	var cfg: Dictionary = (job.get("cfg", {}) as Dictionary).duplicate(true)
	var car_id := str(job.get("car", cfg.get("car", "hatch")))
	cfg["car"] = car_id
	cfg["state"] = _car_state(car_id)
	for k in ["quick", "sim", "maxPI", "back", "seed"]:
		if not cfg.has(k):
			cfg[k] = {"quick": true, "sim": "mid", "maxPI": 999, "back": "home", "seed": 7}[k]
	race = RACE_SCENE.instantiate()
	race.cfg = cfg
	race.profile = profile
	race.auto_player = bool(job.get("auto", false)) # el jugador maneja solo (hay que decirlo antes de armar los autos)
	if job.has("view_at"):
		race.view_at = float(job["view_at"])
	race.loaded.connect(func() -> void: loaded = true)
	root.add_child(race)
	while not loaded:
		await process_frame
	for i in 6:
		await process_frame
	track = race.track
	cam = race.cam
	# fuera el HUD y los controles (la capa 5 del juego)
	for ch in race.get_children():
		if ch is CanvasLayer and (ch as CanvasLayer).layer >= 1:
			(ch as CanvasLayer).visible = bool(job.get("hud", false))
	race.world.msaa_3d = Viewport.MSAA_4X
	race.world.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if race.sun != null and bool(job.get("shadows", true)):
		race.sun.shadow_enabled = true
		race.sun.directional_shadow_max_distance = float(job.get("shadow_dist", 90.0))
		race.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		race.sun.shadow_opacity = 0.62
	if race.session != null:
		race.session.cd = 0.0 # sin cuenta regresiva

func _start_studio() -> void:
	room = Showroom.new()
	room.dist_scale = 1.0
	root.add_child(room)
	await process_frame
	var car_id := str(job.get("car", "hatch"))
	room.set_car(car_id, _car_state(car_id), vehicles)
	room.set_process(false) # la cámara y los pilotos los maneja el director
	for c in room.crew: # los pilotos de la sala (con su propio guion) se esconden: los pone el director
		(c["node"] as Node3D).visible = false
	if room.clip != null:
		room.clip.visible = false
	room.set_process_unhandled_input(false)
	cam = room.cam
	_studio_lights(str(job.get("lights", "default")))
	for i in 4:
		await process_frame

## Luces de la sala: [0] clave (sol), [1] contorno desde atrás, [2] relleno. «dramatic»: contorno naranja fuerte y relleno azul (los autos se despegan del fondo)
func _studio_lights(preset: String) -> void:
	var ls: Array = []
	for ch in room.get_children():
		if ch is DirectionalLight3D:
			ls.append(ch)
	if ls.size() < 3 or preset == "default":
		return
	match preset:
		"dramatic":
			ls[0].light_energy = 1.25
			ls[0].light_color = Color(1.0, 0.94, 0.84)
			ls[0].rotation_degrees = Vector3(-36, -48, 0)
			ls[1].light_energy = 2.1
			ls[1].light_color = Color(1.0, 0.56, 0.22)
			ls[1].rotation_degrees = Vector3(-14, 200, 0)
			ls[2].light_energy = 0.8
			ls[2].light_color = Color(0.40, 0.58, 1.0)
			ls[2].rotation_degrees = Vector3(-12, 118, 0)
		"cold":
			ls[0].light_energy = 1.1
			ls[0].light_color = Color(0.85, 0.92, 1.0)
			ls[1].light_energy = 1.8
			ls[1].light_color = Color(0.30, 0.65, 1.0)
			ls[2].light_energy = 0.7
			ls[2].light_color = Color(1.0, 0.6, 0.35)

# ───────────────────────── cámara y pilotos ─────────────────────────
func player_xf() -> Dictionary:
	if mode == "studio":
		return {"pos": Vector3.ZERO, "yaw": 0.0}
	var sn = race.cars[0].snap
	return {"pos": Vector3(sn.px, sn.py, sn.pz), "yaw": float(sn.yaw)}

func _local(pxf: Dictionary, v: Array) -> Vector3:
	# v = [derecha, alto, adelante] en el marco del auto
	var yaw: float = pxf["yaw"]
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return (pxf["pos"] as Vector3) + right * float(v[0]) + Vector3.UP * float(v[1]) + fwd * float(v[2])

func _cam_goal(s: Dictionary, a_override = null) -> Dictionary:
	var c: Dictionary = s.get("cam", {})
	var pxf := player_xf()
	var g := {"fov": float(s.get("fov", c.get("fov", 45.0))), "roll": float(c.get("roll", 0.0)), "near": float(s.get("near", c.get("near", 0.12)))}
	if c.has("orbit"):
		var o: Dictionary = c["orbit"]
		var a := deg_to_rad(float(a_override if a_override != null else o.get("a", 30.0)))
		var r := float(o.get("r", 6.0))
		g["pos"] = _local(pxf, [sin(a) * r + float(o.get("dx", 0.0)), float(o.get("h", 1.2)), cos(a) * r + float(o.get("dz", 0.0))])
		g["look"] = _local(pxf, [float(o.get("lx", 0.0)), float(o.get("lh", 0.7)), float(o.get("lz", 0.0))])
	elif c.has("rel"):
		g["pos"] = _local(pxf, c["rel"])
		g["look"] = _local(pxf, c.get("look", [0.0, 0.7, 0.0]))
	elif c.has("abs"):
		var p: Array = c["abs"]
		g["pos"] = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var l: Array = c.get("look", [0, 0, 0])
		g["look"] = Vector3(float(l[0]), float(l[1]), float(l[2]))
	else:
		g["pos"] = _local(pxf, [4.0, 1.3, 5.0])
		g["look"] = _local(pxf, [0.0, 0.7, 0.0])
	return g

func apply_goal() -> void:
	if goal.is_empty() or cam == null or not is_instance_valid(cam):
		return
	var pos: Vector3 = goal["pos"]
	var look: Vector3 = goal["look"]
	if pos.distance_to(look) < 0.01:
		return
	var up := Vector3.UP
	if absf(float(goal.get("roll", 0.0))) > 0.01:
		up = Vector3.UP.rotated((look - pos).normalized(), deg_to_rad(float(goal["roll"])))
	cam.global_transform = Transform3D(Basis.looking_at(look - pos, up), pos)
	cam.fov = float(goal["fov"])
	cam.near = float(goal.get("near", 0.12))
	cam.far = maxf(cam.far, 2500.0)
	for c in crew:
		_pose_crew(c)

func _clear_crew() -> void:
	for c in crew:
		if is_instance_valid(c["node"]):
			(c["node"] as Node).queue_free()
	crew.clear()

func _set_crew(specs: Array) -> void:
	_clear_crew()
	var pxf := player_xf()
	var parent: Node = room if mode == "studio" else race.world
	for sp in specs:
		var d: Dictionary = sp
		var node := Node3D.new()
		parent.add_child(node)
		var rig := RigPilot.new(node, float(d.get("h", 1.76)), false)
		var pl: Variant = null
		if rig.ok and MixamoClips.available():
			pl = MixamoClips.Player.new(rig.skel, rig.B)
			(pl as MixamoClips.Player).strip = true
			(pl as MixamoClips.Player).play(MixamoClips.clip(str(d.get("clip", "Standing_Idle"))))
		var at: Array = d.get("at", [2.4, 0.0])
		var wp := _local(pxf, [float(at[0]), 0.0, float(at[1])])
		if mode != "studio" and track != null:
			wp.y = track.ground_y(wp.x, wp.z)
		node.position = wp
		var face: Variant = d.get("face", "car")
		var yaw := 0.0
		if face is String and face == "car":
			var pp: Vector3 = pxf["pos"]
			yaw = atan2(pp.x - wp.x, pp.z - wp.z)
		elif face is String and face == "cam":
			yaw = atan2((goal["pos"] as Vector3).x - wp.x, (goal["pos"] as Vector3).z - wp.z) if not goal.is_empty() else 0.0
		elif face is float or face is int:
			yaw = deg_to_rad(float(face)) + float(pxf["yaw"])
		node.rotation.y = yaw
		crew.append({"node": node, "rig": rig, "pl": pl, "spec": d, "face": face})

func _pose_crew(c: Dictionary) -> void:
	var pl: Variant = c["pl"]
	if pl == null:
		return
	var p: MixamoClips.Player = pl
	var sp: Dictionary = c["spec"]
	if str(c["face"]) == "cam" and not goal.is_empty():
		var wp: Vector3 = (c["node"] as Node3D).position
		(c["node"] as Node3D).rotation.y = atan2((goal["pos"] as Vector3).x - wp.x, (goal["pos"] as Vector3).z - wp.z)
	p.t = float(sp.get("t", 0.0))
	p.blend = 1.0
	p.apply_clip()

# ───────────────────────── tomas ─────────────────────────
func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _teleport(tp: Dictionary) -> void:
	if mode != "world" or not (track is RouteTrack):
		return
	var n: int = track.n
	var i := int(floor(float(tp.get("frac", 0.0)) * float(n))) % n
	var lat := float(tp.get("lat", 0.0))
	var sm: Vector3 = track.samples[i]
	var l: Vector3 = track.laterals[i]
	var t: Vector3 = track.tangents[i]
	var car = race.cars[0]
	car.place(sm.x + l.x * lat, sm.z + l.z * lat, atan2(t.x, t.z) + deg_to_rad(float(tp.get("yaw", 0.0))))
	car.restart_history(race.sim_t)
	# los rivales detrás/adelante, en fila
	var rivals: Array = tp.get("rivals", [])
	for k in range(1, race.cars.size()):
		var gap := float(rivals[k - 1]) if k - 1 < rivals.size() else 12.0 * float(k)
		var j := i
		var acc := 0.0
		while absf(acc) < absf(gap) and j >= 0:
			var j2 := posmod(j + (1 if gap > 0.0 else -1), n)
			acc += track.samples[j].distance_to(track.samples[j2])
			j = j2
		var s2: Vector3 = track.samples[j]
		var l2: Vector3 = track.laterals[j]
		var t2: Vector3 = track.tangents[j]
		var side := (1.8 if k % 2 == 0 else -1.8)
		race.cars[k].place(s2.x + l2.x * side, s2.z + l2.z * side, atan2(t2.x, t2.z))
		race.cars[k].restart_history(race.sim_t)

func _apply_env(e: Dictionary) -> void:
	if mode != "world" or race == null:
		return
	if e.has("sun_rot") and race.sun != null:
		var r: Array = e["sun_rot"]
		race.sun.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
	if e.has("sun_energy") and race.sun != null:
		race.sun.light_energy = float(e["sun_energy"])
	if e.has("sun_color") and race.sun != null:
		race.sun.light_color = Color(str(e["sun_color"]))
	if e.has("fog_density") and race.env != null:
		race.env.fog_density = float(e["fog_density"])
	if e.has("fog_color") and race.env != null:
		race.env.fog_light_color = Color(str(e["fog_color"]))
	if e.has("ambient") and race.env != null:
		race.env.ambient_light_energy = float(e["ambient"])

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var base := out_dir.path_join(name)
	if fmt == "png":
		img.save_png(base + ".png")
	else:
		img.save_jpg(base + ".jpg", 0.96)
	count += 1

func _shot(s: Dictionary) -> void:
	var name := str(s.get("name", "foto_%04d" % count))
	if s.has("tp"):
		_teleport(s["tp"])
	if s.has("env"):
		_apply_env(s["env"])
	if s.has("pilots"):
		goal = _cam_goal(s) # (para los que miran a la cámara)
		_set_crew(s["pilots"])
	elif s.has("clear_pilots") or (not s.has("keep_pilots") and not crew.is_empty()):
		_clear_crew()
	if race != null:
		race.sim_hold = false
	var sim := float(s.get("sim", 0.0))
	if sim > 0.0 and mode == "world":
		# la simulación corre sin dibujar (mucho más rápido); sólo se dibujan los últimos cuadros (polvo y humo)
		var t_end: float = float(race.sim_t) + sim
		var warm := float(s.get("warm", 0.0))
		var guard := 0
		RenderingServer.render_loop_enabled = false
		while float(race.sim_t) < t_end - warm and guard < 100000:
			guard += 1
			await process_frame
		RenderingServer.render_loop_enabled = true
		while float(race.sim_t) < t_end and guard < 100000:
			guard += 1
			await process_frame
	var cam_spec: Dictionary = s.get("cam", {})
	var orbit: Dictionary = cam_spec.get("orbit", {})
	if orbit.has("n"):
		var n := int(orbit["n"])
		var a0 := float(orbit.get("a0", 0.0))
		var a1 := float(orbit.get("a1", 360.0))
		for i in n:
			var a := lerpf(a0, a1, float(i) / float(n))
			goal = _cam_goal(s, a)
			await _frames(int(s.get("wait", 2)))
			await _save("%s_%03d" % [name, i])
		return
	goal = _cam_goal(s)
	await _frames(int(s.get("wait", 4)))
	await _save(name)
