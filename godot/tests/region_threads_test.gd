## Cierre de golpe del mundo abierto (SIGSEGV, «estado 11», 14/10/2026): los hilos que arman el terreno de la región (region_world._build → _road_caps → _fillets
## → RegionData.edge_cum) llenaban a demanda la tabla compartida _cum mientras el hilo principal (GPS, policía, carreras) también la usaba: dos hilos
## escribiendo el mismo Dictionary rompen la memoria. Ahora las distancias se calculan todas al cargar y en el juego sólo se leen.
## Esta prueba: (1) la tabla está completa apenas carga la región; (2) 4 hilos arman cuadrados de terreno mientras el hilo principal consulta calles al azar,
## como en el juego, y nada se rompe ni cambia la tabla.
## Uso: godot --headless --path godot --script res://tests/region_threads_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const RegionWorld := preload("res://game/region/region_world.gd")

var fail := false
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	var tr := CityTrack.new()
	var rg = tr.region
	_check(rg != null and rg._cum.size() == rg.edges.size(), "las distancias de las %d calles se calculan al cargar (%d)" % [rg.edges.size() if rg != null else 0, rg._cum.size() if rg != null else 0])
	var wn: Node3D = tr.build_world() # (el mundo de la ciudad y el de la región, como en el juego)
	var rw = wn.get_node("region")
	# cuadrados con cruces de 3 o más calles (los que pasan por _fillets), alrededor de varios pueblos
	var keys: Array = []
	for n in rg.nodes:
		if (rg.node_edges[int(n[0])] as PackedInt32Array).size() >= 3:
			keys.append(Vector2i(int(floor(float(n[1]) / RegionWorld.CHUNK)), int(floor(float(n[2]) / RegionWorld.CHUNK))))
		if keys.size() >= 24:
			break
	var before: int = rg._cum.size()
	var tasks: Array = []
	var t0 := Time.get_ticks_msec()
	for i in keys.size():
		tasks.append(WorkerThreadPool.add_task(func() -> void: rw._build(keys[i], i % 2)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var calls := 0
	while true:
		var all_done := true
		for t in tasks:
			if not WorkerThreadPool.is_task_completed(t):
				all_done = false
		# el hilo principal, mientras tanto: lo que hacen el GPS, la policía y las carreras
		for k in 200:
			var ei: int = rng.randi() % rg.edges.size()
			var cum: PackedFloat32Array = rg.edge_cum(ei)
			rg.point_at(ei, cum[cum.size() - 1] * rng.randf())
			calls += 1
		if all_done:
			break
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_check(true, "%d cuadrados armados en 4 hilos con %d consultas del hilo principal a la vez, sin cierre (%d ms)" % [keys.size(), calls, Time.get_ticks_msec() - t0])
	_check(rg._cum.size() == before, "durante el juego nadie escribe la tabla compartida (%d → %d)" % [before, rg._cum.size()])
	wn.free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
