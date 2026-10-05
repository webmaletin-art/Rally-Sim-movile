extends RefCounted
## Semáforos funcionales de Dream City (Etapa 7). El estado de cada semáforo es una FUNCIÓN PURA del tiempo del mundo (WorldClock.now()): no hay temporizadores ni estado que
## sincronizar, así que todos los jugadores (y el servidor) ven el mismo color a la vez, y para tener el estado de un cruce alcanza con una cuenta.
## Cada cruce con semáforos reparte sus calles en dos grupos (0 y 1) que alternan: verde → amarillo → todo rojo → verde del otro grupo. Cada cruce tiene su propio desfase
## (derivado de su posición y de la semilla del mundo) para que no cambien todos a la vez.
##   ciclo CYCLE s: grupo 0 verde [0, GREEN), amarillo [GREEN, GREEN+YELLOW), rojo el resto; el grupo 1 hace lo mismo medio ciclo después.
## La luz que se ve en los postes es un shader (fx/city_signal.gdshader) que calcula lo MISMO con la hora del mundo: cambiar de color no cuesta nada por cuadro.

const RED := 0
const AMBER := 1
const GO := 2
const CYCLE := 40.0
const GREEN := 16.0
const YELLOW := 3.0
const NODE_RADIUS := 30.0 # un semáforo pertenece al cruce más cercano dentro de esto

var graph: RefCounted # TrafficGraph
var by_node: Dictionary = {} # id de nodo → {offset: float, groups: {id de calle: 0|1}}
var head_info: Dictionary = {} # id de prop (semáforo) → Vector2(desfase, grupo)

func build(p_graph: RefCounted, layout: RefCounted) -> void:
	graph = p_graph
	by_node.clear()
	head_info.clear()
	var roads_at: Dictionary = {} # nodo → {id de calle: true}
	var head_node: Dictionary = {} # id de prop → nodo
	var ids: Array = layout.prop_signal.keys()
	ids.sort()
	for id in ids:
		var info: Array = layout.prop_signal[id]
		var jp: Vector2 = info[1]
		var n: int = graph.node_near(jp, NODE_RADIUS)
		if n < 0:
			continue
		head_node[id] = n
		if not roads_at.has(n):
			roads_at[n] = {}
		(roads_at[n] as Dictionary)[int(info[0])] = true
	for n in roads_at:
		var rl: Array = (roads_at[n] as Dictionary).keys()
		rl.sort()
		var groups := {}
		for i in rl.size():
			groups[int(rl[i])] = i % 2
		by_node[n] = {"offset": _offset_for(graph.nodes[n]["pos"], int(layout.seed_v)), "groups": groups}
	for id in ids:
		if not head_node.has(id):
			continue
		var n2: int = head_node[id]
		var g: int = int(by_node[n2]["groups"].get(int(layout.prop_signal[id][0]), 0))
		head_info[id] = Vector2(float(by_node[n2]["offset"]), float(g))

static func _offset_for(pos: Vector2, seed_v: int) -> float:
	var k: int = (roundi(pos.x / 8.0) * 73856093) ^ (roundi(pos.y / 8.0) * 19349663) ^ seed_v
	k = ((k ^ (k >> 13)) * 1274126177) & 0x7fffffff
	k = (k ^ (k >> 16)) & 0xffff
	return float(k) / 65536.0 * CYCLE

## Estado de un grupo de un cruce en el instante t del mundo
static func state_at(offset: float, group: int, t: float) -> int:
	var ph := fposmod(t + offset + float(group) * CYCLE * 0.5, CYCLE)
	if ph < GREEN:
		return GO
	if ph < GREEN + YELLOW:
		return AMBER
	return RED

func is_signalized(node: int) -> bool:
	return by_node.has(node)

## Estado del semáforo que ve un auto que va por el carril lane al llegar al cruce del final del carril (GO si ese cruce no tiene semáforos)
func lane_state(lane: int, t: float) -> int:
	var L: Dictionary = graph.lanes[lane]
	var n: int = int(L["b"])
	if not by_node.has(n):
		return GO
	var e: Dictionary = by_node[n]
	return state_at(float(e["offset"]), int((e["groups"] as Dictionary).get(int(L["road"]), 1)), t)

## Segundos que faltan para que cambie el estado del carril (para decidir si frenar o pasar)
func time_to_change(lane: int, t: float) -> float:
	var L: Dictionary = graph.lanes[lane]
	var n: int = int(L["b"])
	if not by_node.has(n):
		return 1e9
	var e: Dictionary = by_node[n]
	var g: int = int((e["groups"] as Dictionary).get(int(L["road"]), 1))
	var ph := fposmod(t + float(e["offset"]) + float(g) * CYCLE * 0.5, CYCLE)
	if ph < GREEN:
		return GREEN - ph
	if ph < GREEN + YELLOW:
		return GREEN + YELLOW - ph
	return CYCLE - ph

func count() -> int:
	return by_node.size()
