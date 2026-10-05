extends RefCounted
## Cámaras del juego (portadas de CameraRig, js/main.js): 4 de seguimiento, cámara libre, capó, paragolpes y las dos
## interiores (casco del piloto y atrás de las butacas, con el habitáculo y la tripulación).

const CarSnapshot := preload("res://game/car/car_snapshot.gd")

const CAMERAS := [
	{"name": "Onboard (casco)", "mode": "onboard", "fov": 70.0},
	{"name": "Media", "mode": "chase", "dist": 7.5, "height": 2.2, "look": 3.6, "lookH": 0.75, "fov": 58.0},
	{"name": "Cerca/Alta", "mode": "chase", "dist": 4.8, "height": 2.9, "look": 3.0, "lookH": 0.6, "fov": 64.0},
	{"name": "Lejos/Baja", "mode": "chase", "dist": 11.0, "height": 1.2, "look": 4.5, "lookH": 1.0, "fov": 54.0},
	{"name": "Aérea", "mode": "chase", "dist": 15.0, "height": 6.0, "look": 2.0, "lookH": 0.2, "fov": 50.0},
	{"name": "Cámara libre", "mode": "custom", "fov": 60.0},
	{"name": "Interior (atrás del piloto)", "mode": "rearcabin", "fov": 68.0},
	{"name": "Capó", "mode": "hood", "fov": 66.0},
	{"name": "Paragolpes", "mode": "bumper", "fov": 70.0},
]

var cam: Camera3D
var track: RefCounted
var visual: Node3D # el auto (CarVisual)
var cockpit: Node3D # habitáculo (o null)
var mount := {} # {hood: {y, z, ly}, bumper: {…}}
var ground_off := 0.0 # y del piso dentro del auto (−comHeight + rideOffset)
var index := 1
var ready := false
var yaw := 0.0
var bank := 0.0
var dist := 7.5
var shake := 0.0
var pos := Vector3.ZERO
var time := 0.0
var aspect := 2.0

## Ajustes del jugador por cámara (índice → {dist, height, side, fov}) en metros / grados; se cambian desde la pausa → CÁMARA
var adj := {}

func adj_of(k: String) -> float:
	var d: Variant = adj.get(str(index))
	return float((d as Dictionary).get(k, 0.0)) if d is Dictionary else 0.0

func set_adj(k: String, v: float) -> void:
	var d: Dictionary = adj.get(str(index), {})
	d[k] = v
	adj[str(index)] = d

## Rotar la cámara libre arrastrando el dedo y acercarla/alejarla con dos dedos
func drag(rel: Vector2) -> void:
	if mode() != "custom":
		return
	custom_yaw_off -= rel.x * 0.009
	custom_elev = clampf(custom_elev + rel.y * 0.006, -0.15, 1.35)

func zoom(f: float) -> void:
	if mode() != "custom":
		return
	custom_dist = clampf(custom_dist / f, 2.5, 40.0)

# cámara libre
var custom_yaw_off := 0.0
var custom_elev := 0.28
var custom_dist := 7.5
var custom_pan_f := 0.0
var custom_pan_r := 0.0
var custom_pan_u := 0.0
var custom_tgt_y := 0.6

func _init(p_cam: Camera3D, p_track: RefCounted) -> void:
	cam = p_cam
	track = p_track

func mode() -> String:
	return CAMERAS[index]["mode"]

func is_inside() -> bool:
	var m := mode()
	return m == "onboard" or m == "rearcabin"

func cam_name() -> String:
	return CAMERAS[index]["name"]

func set_preset(i: int) -> void:
	index = i
	ready = false
	yaw = 0.0
	bank = 0.0
	if CAMERAS[i].has("dist"):
		dist = CAMERAS[i]["dist"]

func next(d := 1) -> void:
	set_preset((index + d + CAMERAS.size()) % CAMERAS.size())

func _ground(x: float, z: float) -> float:
	return (track.ground_info(x, z) as Vector2).x

var _clear := 1.0 # 1 = la cámara está a su distancia normal · menos: se acercó porque había un edificio en el medio

## ¿Hasta dónde llega la cámara sin meterse en un edificio? (la pista lo sabe: hoy solo Dream City; en las demás siempre 1). Se acerca de golpe y vuelve despacio, sin tirones.
func _clearance(dt: float, p: CarSnapshot, tx: float, tz: float) -> float:
	var t := 1.0
	if track != null and track.has_method("camera_clear"):
		t = clampf(float(track.call("camera_clear", Vector2(p.px, p.pz), Vector2(tx, tz))), 0.22, 1.0)
	if t < _clear:
		_clear = t
	else:
		_clear += (t - _clear) * (1.0 - exp(-dt * 1.4))
	return _clear

## p: estado del auto interpolado (CarSnapshot). rough: 0..1 rugosidad del camino. Devuelve true si la cámara está adentro.
func update(dt: float, p: CarSnapshot, rough_surface: bool) -> void:
	time += dt
	var c: Dictionary = CAMERAS[index]
	var m: String = c["mode"]
	var rough := 1.0 if rough_surface else 0.0
	if (m == "hood" or m == "bumper") and not mount.is_empty():
		_mounted(p, c, rough)
		return
	if (m == "onboard" or m == "rearcabin") and cockpit != null:
		_inside(p, m, rough)
		return
	if cam.near != 0.15:
		cam.near = 0.15
	if m == "custom":
		_custom(dt, p, c)
	elif m in ["chase"]:
		_chase(dt, p, c)
	else:
		_chase(dt, p, CAMERAS[1])

func _chase(dt: float, p: CarSnapshot, c: Dictionary) -> void:
	var spd := sqrt(p.vx * p.vx + p.vz * p.vz)
	var heading := p.yaw
	if spd > 5.0:
		var vh := atan2(p.vx, p.vz)
		var d := wrapf(vh - p.yaw, -PI, PI)
		if p.vLong < 0.0:
			d = 0.0
		heading = p.yaw + d * 0.5
	if not ready:
		yaw = heading
	var dy := wrapf(heading - yaw, -PI, PI)
	yaw += dy * (1.0 - exp(-dt * 2.3))
	var fx := sin(yaw)
	var fz := cos(yaw)
	var target_d: float = float(c["dist"]) + adj_of("dist") + clampf(spd * 0.018, 0.0, 1.1) - clampf(p.aLong * 0.07, -0.4, 0.7)
	dist += (target_d - dist) * (1.0 - exp(-dt * 3.0))
	var ix := p.px - fx * dist
	var iz := p.pz - fz * dist
	var iy: float = p.py + float(c["height"]) + adj_of("height")
	var rx := cos(yaw)
	var rz := -sin(yaw)
	ix += rx * adj_of("side")
	iz += rz * adj_of("side")
	var cl := _clearance(dt, p, ix, iz)
	if cl < 0.999:
		ix = p.px + (ix - p.px) * cl # con un edificio en el medio la cámara se acerca y mira desde más arriba
		iz = p.pz + (iz - p.pz) * cl
		iy += (1.0 - cl) * 3.2
	var gy := _ground(ix, iz) + 0.7
	if iy < gy:
		iy = gy
	if not ready:
		pos = Vector3(ix, iy, iz)
		ready = true
	var k := 1.0 - exp(-dt * 9.0)
	var kh := 1.0 - exp(-dt * 5.0)
	pos.x += (ix - pos.x) * k
	pos.z += (iz - pos.z) * k
	pos.y += (iy - pos.y) * kh
	var look := Vector3(p.px + fx * float(c["look"]), p.py + float(c["lookH"]), p.pz + fz * float(c["look"]))
	var rough := 2.2 if _loose(p) else 1.0
	shake += dt * 37.0
	var sa := minf(1.0, spd / 40.0) * 0.012 * rough
	cam.position = Vector3(pos.x, pos.y + sin(shake) * sa, pos.z)
	cam.look_at(look)
	var bt := clampf(-p.aLat * 0.010, -0.07, 0.07)
	bank += (bt - bank) * (1.0 - exp(-dt * 3.0))
	cam.rotate_object_local(Vector3.BACK, bank)
	cam.fov = float(c["fov"]) + adj_of("fov") + minf(spd / 45.0, 1.0) * 8.0

func _loose(p: CarSnapshot) -> bool:
	for i in 4:
		var o := i * 8
		if p.wheel_fx[o] > 0.5 and int(p.wheel_fx[o + 1]) != 0:
			return true
	return false

func _custom(dt: float, p: CarSnapshot, c: Dictionary) -> void:
	var ang := p.yaw + PI + custom_yaw_off
	var cos_e := cos(custom_elev)
	var sin_e := sin(custom_elev)
	var cd := maxf(1.5, custom_dist + adj_of("dist"))
	var ox := sin(ang) * cd * cos_e
	var oz := cos(ang) * cd * cos_e
	var oy := cd * sin_e
	var cy := cos(p.yaw)
	var sy := sin(p.yaw)
	var pan_x := cy * custom_pan_r + sy * custom_pan_f
	var pan_z := -sy * custom_pan_r + cy * custom_pan_f
	var tx := p.px + ox + pan_x
	var tz := p.pz + oz + pan_z
	var ty := p.py + oy + custom_pan_u + adj_of("height")
	var clc := _clearance(dt, p, tx, tz)
	if clc < 0.999:
		tx = p.px + (tx - p.px) * clc
		tz = p.pz + (tz - p.pz) * clc
		ty += (1.0 - clc) * 3.2
	var gy := _ground(tx, tz) + 0.25
	if ty < gy:
		ty = gy
	var target := Vector3(tx, ty, tz)
	if not ready:
		pos = target
		ready = true
	pos = pos.lerp(target, 1.0 - exp(-dt * 14.0))
	cam.position = pos
	cam.look_at(Vector3(p.px, p.py + custom_tgt_y, p.pz))
	cam.fov = float(c["fov"]) + adj_of("fov")

## capó / paragolpes: rígidas, con la vibración del camino
func _mounted(p: CarSnapshot, c: Dictionary, rough: float) -> void:
	var m: Dictionary = mount[c["mode"]]
	var vib := (0.006 if c["mode"] == "bumper" else 0.003) * (0.4 + rough * 1.6) * minf(1.0, absf(p.vLong) / 20.0)
	var ax := adj_of("side")
	var ay := adj_of("height")
	var az := -adj_of("dist") # «distancia» positiva = más atrás
	var lp := Vector3(sin(time * 39.7) * vib + ax, float(m["y"]) + sin(time * 47.3) * vib + ay, float(m["z"]) + az)
	var ll := Vector3(ax, float(m["y"]) + ay + float(m["ly"]), float(m["z"]) + az + 12.0)
	var t := visual.global_transform
	var wp := t * lp # los puntos de montaje ya vienen en el marco del auto
	var wl := t * ll
	cam.position = wp
	cam.look_at(wl, t.basis.y)
	var spd := sqrt(p.vx * p.vx + p.vz * p.vz)
	cam.fov = float(c["fov"]) + adj_of("fov") + minf(spd / 50.0, 1.0) * 5.0
	cam.near = 0.08

func _inside(p: CarSnapshot, m: String, rough: float) -> void:
	var d: Dictionary = cockpit.camera_local(m, p, time, rough)
	var t := visual.global_transform
	var base := Vector3(0, ground_off, 0)
	var off := Vector3(adj_of("side"), adj_of("height"), -adj_of("dist"))
	var wp := t * (base + (d["pos"] as Vector3) + off)
	var wl := t * (base + (d["look"] as Vector3) + off)
	var up := t.basis.y
	if d["roll"] != 0.0:
		up = up.rotated((wl - wp).normalized(), float(d["roll"]))
	cam.position = wp
	cam.look_at(wl, up)
	# ángulo HORIZONTAL fijo como en los simuladores (con el vertical se veía todo el habitáculo en un celular)
	var hf := float(d["hfov"]) * PI / 360.0
	cam.fov = clampf(2.0 * atan(tan(hf) / aspect) * 180.0 / PI, 46.0, 74.0) + adj_of("fov")
	cam.near = 0.04
