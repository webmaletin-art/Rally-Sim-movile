extends "res://game/physics/track_base.gd"
## La pista de la Red de rutas: un mundo plano con caminos (NetData). El piso de cada punto sale de la calle más cercana: la calzada (asfalto, tierra, ripio, barro o arena según la calle),
## la banquina (2 m), el pasto y, lejos de todo, «afuera». No tiene paredes: se puede salir al campo (agarra poco). Las consultas son puras (la física corre en hilos).

const NetData := preload("res://game/net/net_data.gd")

const SURF_OF_ROAD := [0, 1, 1, 5, 1] # superficie de la física de cada tipo de calle: asfalto, tierra, ripio→tierra, barro, arena→tierra
const BUMP := [0.004, 0.03, 0.035, 0.05, 0.03, 0.03] # ondulación por superficie de la física (asfalto, tierra, banquina, pasto, afuera, barro)

var net
var mode := "asphalt"
var n := 1
var samples: Array = [Vector3.ZERO]
var length := 1.0e9
var map_bounds := Rect2()
var map_lines: Array = []
var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var title := "RED DE RUTAS"
var theme := "net"
var world_node: Node3D
var spawn_i := 0

func _init(net_id := "red_1") -> void:
	net = NetData.load_net(net_id)
	if net == null:
		push_error("no se pudo cargar la red %s" % net_id)
		return
	title = "RED DE RUTAS"
	map_bounds = net.bbox
	road_mat = StandardMaterial3D.new()
	ground_mat = StandardMaterial3D.new()

func ground_info(x: float, z: float) -> Vector2:
	var pr: Array = net.probe(x, z, 34.0)
	if pr.is_empty():
		return Vector2(_bump(x, z, 4), 4.0)
	var m: float = float(pr[0]) - float(pr[1])
	var s := 4
	if m <= 0.0:
		s = SURF_OF_ROAD[int(pr[2])]
	elif m <= 2.2:
		s = 2
	elif m <= 30.0:
		s = 3
	return Vector2(_bump(x, z, s), float(s))

func _bump(x: float, z: float, s: int) -> float:
	var a: float = BUMP[s]
	return a * (sin(x * 0.71 + z * 1.27) + sin(x * 1.93 - z * 0.83)) * 0.5

func ground_smooth(x: float, z: float) -> float:
	return 0.0

## Pose para aparecer en la estación i (cada una tiene un playón al costado del camino): el auto queda de frente al camino, paralelo a él
func start_pose(slot: int) -> Array:
	var st: Dictionary = net.stations[spawn_i % net.stations.size()]
	var pos: Vector2 = st["pos"]
	var yaw: float = st["yaw"]
	var side := Vector2(cos(yaw), -sin(yaw)) # a la derecha del rumbo
	var q := pos + side * 5.0 * float(slot) - Vector2(sin(yaw), cos(yaw)) * 6.0 * float(slot)
	return [q.x, q.y, yaw]

## Pose en la estación st (para volver a aparecer): playón y rumbo del camino
func station_pose(st_i: int, slot := 0) -> Array:
	var sp := spawn_i
	spawn_i = st_i
	var r := start_pose(slot)
	spawn_i = sp
	return r

func build_world() -> Node3D:
	var NetWorld = load("res://game/net/net_world.gd")
	world_node = NetWorld.new()
	world_node.setup(self)
	return world_node
