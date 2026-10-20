## Las cuadras de Dream City se calculan en un hilo y salen iguales que armadas de golpe ([B] 20/10/2026).
## Reporte del dueño: «al ir en rutas hacia otros pueblos el juego hace tirones y baja mucho el FPS, necesito fluidez». Cada cuadra se armaba entera en el cuadro en que entraba en el radio
## (12 a 60 ms en la PC, 3 a 6 veces más en un teléfono). Ahora CityWorld calcula la cuadra en un hilo (_chunk_data: sólo cuentas) y el cuadro principal sólo sube las mallas (_assemble_a/_b) en
## pasos cortos. Esta prueba comprueba que:
##  · lo que calcula el hilo es IGUAL a lo que calcula el hilo principal (sopas de triángulos, objetos, árboles) en cuadras de todo tipo: centro, avenidas, ruta, borde con la región, vidriera;
##  · seguir la posición de la cámara arma todas las cuadras de alrededor sin trabarse y deja las colas vacías (objetos, locales y autos de las vidrieras);
##  · cada llamada de update_around es corta (el trabajo pesado no pasa por el hilo principal);
##  · warm() con una cuadra en camino termina todo de una vez, sin trabarse;
##  · el piso de la física se puede consultar mientras el hilo arma cuadras (no se cae ni da distinto);
##  · al alejarse se borran las cuadras y no quedan cosas pendientes.
## Uso: tools/test/run_test.sh city_stream_test 120
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Una cuenta corta de todo lo que sale de la cuadra (si dos corridas dan lo mismo, esto da lo mismo)
func _sig(d: Dictionary) -> String:
	var out := []
	for nm in ["terr", "rd", "mk", "tn", "bl"]:
		var s = d[nm]
		var sv := Vector3.ZERO
		for v in s.v:
			sv += v
		var sc := 0.0
		for c in s.c:
			sc += c.r + c.g * 2.0 + c.b * 3.0 + c.a * 5.0
		var sn := Vector3.ZERO
		for n in s.n:
			sn += n
		out.append("%s:%d:%.3f,%.3f,%.3f:%.3f:%.3f,%.3f,%.3f" % [nm, s.v.size(), sv.x, sv.y, sv.z, sc, sn.x, sn.y, sn.z])
	var pd: Dictionary = d["props"]
	if pd.is_empty():
		out.append("props:0")
	else:
		var arr: Array = pd["arr"]
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ps := Vector3.ZERO
		for v in pv:
			ps += v
		out.append("props:%d:%.3f,%.3f,%.3f:g%d:s%d" % [pv.size(), ps.x, ps.y, ps.z, (pd["gv"] as PackedVector3Array).size(), (pd["sv"] as PackedVector3Array).size()])
	var tr: Array = d["trees"]
	var ts := 0.0
	for it in tr:
		ts += float(it[0]) + float(it[1]) * 2.0 + float(it[2]) * 3.0 + float(it[3]) * 7.0 + float(it[4]) * 11.0
	out.append("trees:%d:%.3f" % [tr.size(), ts])
	out.append("pois:%d" % (d["pois"] as Array).size())
	return "|".join(out)

func _init() -> void:
	var t_all := Time.get_ticks_msec()
	var track = CityTrack.new()
	var cw = track.build_world()
	root.add_child(cw)
	cw.set_process(false)
	cw._ensure_shared()
	cw._prime_display() # (como en el juego: warm() lo hace con la pantalla de carga)
	# ── 1. el hilo calcula lo mismo que el principal (mitad: primero el hilo, mitad: primero el principal)
	var keys: Array = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(-2, 3), Vector2i(3, 0), Vector2i(5, 0), Vector2i(7, 0), Vector2i(9, 0), Vector2i(0, -9), Vector2i(0, -11), Vector2i(12, 7),
		Vector2i(13, 7), Vector2i(-4, -4), Vector2i(2, 5), Vector2i(-6, 2), Vector2i(4, -3), Vector2i(0, 5)]
	# sumamos las cuadras con un local, con una estación y con un peaje (donde hay más cosas que armar)
	for b_key in cw.city.buildings.keys():
		var bl: Array = cw.city.buildings[b_key]
		for b in bl:
			if b.has("poi") and keys.size() < 24 and not keys.has(b_key) and b.has("show"):
				keys.append(b_key)
	for st in cw.city.stations:
		var sk: Vector2i = cw.city.chunk_of((st["center"] as Vector2).x, (st["center"] as Vector2).y)
		if not keys.has(sk) and keys.size() < 28:
			keys.append(sk)
	var same := 0
	var diff := 0
	var first_diff := ""
	var t_thread := 0.0
	var t_main := 0.0
	for i in keys.size():
		var k: Vector2i = keys[i]
		var d_th: Dictionary
		var d_mn: Dictionary
		var ta := Time.get_ticks_usec()
		if i % 2 == 0:
			cw._start_job(k)
			cw._take_job()
			var rq: Array = cw._ready_q.pop_back()
			cw._pending.erase(k)
			d_th = rq[1] if rq[1] != null else {}
			var tb := Time.get_ticks_usec()
			d_mn = cw._chunk_data_main(k)
			t_thread += float(tb - ta) / 1000.0
			t_main += float(Time.get_ticks_usec() - tb) / 1000.0
		else:
			var tc := Time.get_ticks_usec()
			d_mn = cw._chunk_data_main(k)
			var td := Time.get_ticks_usec()
			cw._start_job(k)
			cw._take_job()
			var rq2: Array = cw._ready_q.pop_back()
			cw._pending.erase(k)
			d_th = rq2[1] if rq2[1] != null else {}
			t_main += float(td - tc) / 1000.0
			t_thread += float(Time.get_ticks_usec() - td) / 1000.0
		if d_th.is_empty() or _sig(d_th) != _sig(d_mn):
			diff += 1
			if first_diff == "":
				first_diff = "%s\n  hilo:      %s\n  principal: %s" % [str(k), _sig(d_th) if not d_th.is_empty() else "(vacío)", _sig(d_mn)]
		else:
			same += 1
	_check(diff == 0 and same == keys.size(), "el hilo y el principal calculan lo mismo en %d cuadras (%d distintas) %s" % [keys.size(), diff, first_diff])
	_check(cw._job_id < 0 and cw._ready_q.is_empty() and cw._pending.is_empty(), "no quedó ningún trabajo colgado")
	# ── 2. seguir la cámara: se arma todo lo de alrededor, de a pasos cortos
	var p0 := Vector3(0.0, 0.0, 0.0)
	var ck: Vector2i = cw.city.chunk_of(p0.x, p0.z)
	var worst := 0.0
	var times: Array = []
	var calls := 0
	var t0 := Time.get_ticks_msec()
	var idle := 0
	while Time.get_ticks_msec() - t0 < 25000:
		var ta2 := Time.get_ticks_usec()
		cw.update_around(p0, 4, 2.5)
		var dt := float(Time.get_ticks_usec() - ta2) / 1000.0
		worst = maxf(worst, dt)
		times.append(dt)
		calls += 1
		var busy: bool = cw._job_id >= 0 or not cw._ready_q.is_empty() or not cw._pend_b.is_empty() or not cw._extras_q.is_empty() or not cw._wanted(p0, ck, 3).is_empty()
		if not busy:
			idle += 1
			if idle > 3:
				break
		else:
			idle = 0
			OS.delay_msec(3) # (cada cuadro de verdad dura ≥ 16 ms: el hilo avanza entre uno y otro)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	var want_n := 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var k2 := Vector2i(ck.x + dx, ck.y + dz)
			var qx := (float(k2.x) + 0.5) * 160.0
			var qz := (float(k2.y) + 0.5) * 160.0
			if qx * qx + qz * qz <= 3750.0 * 3750.0:
				want_n += 1
	_check(cw.chunks.size() == want_n, "se armaron las %d cuadras de alrededor (%d armadas, %.1f s, %d llamadas)" % [want_n, cw.chunks.size(), secs, calls])
	_check(cw._pend_b.is_empty() and cw._extras_q.is_empty() and cw._ready_q.is_empty() and cw._job_id < 0, "las colas de objetos, locales y vidrieras quedaron vacías")
	times.sort()
	var p90: float = times[int(times.size() * 0.9)]
	_check(p90 < 10.0 and worst < 100.0, "las llamadas de update_around son cortas: el 90 %% tarda menos de %.1f ms y la peor %.1f ms (antes una cuadra entera: 12 a 60 ms en la PC, con picos de 190)" % [p90, worst])
	var with_props := 0
	var with_trees := 0
	var with_shop := 0
	var cars_in_showroom := 0
	for k3 in cw.chunks:
		var rt: Node3D = cw.chunks[k3]
		if rt.get_node_or_null("props") != null:
			with_props += 1
		if rt.get_node_or_null("trees") != null:
			with_trees += 1
		for ch in rt.get_children():
			if str(ch.name).begins_with("shop_"):
				with_shop += 1
				var sr := ch.get_node_or_null("showroom")
				if sr != null:
					for g in sr.get_children():
						if g.has_meta("vp"):
							cars_in_showroom += 1
	_check(with_props > 10 and with_shop >= 3, "las cuadras subidas tienen objetos (%d), árboles (%d) y locales (%d, con %d autos de vidriera)" % [with_props, with_trees, with_shop, cars_in_showroom])
	_check(track.props.size() > 100, "los objetos de la calle chocan (cuadrículas con objetos registrados: %d)" % track.props.size())
	# ── 2b. la válvula de escape (threaded = false): armando todo en el hilo principal salen las mismas cuadras con los mismos triángulos
	var tris_th: int = int(cw.stats()["tris"])
	var n_th: int = cw.chunks.size()
	cw._unload_far(Vector2i(100000, 100000), 3) # (se sueltan todas: también se sacan sus objetos de la grilla de choques)
	cw.threaded = false
	var t_sync := Time.get_ticks_msec()
	while not cw._wanted(p0, ck, 3).is_empty() and Time.get_ticks_msec() - t_sync < 20000:
		cw.update_around(p0, 6, 1e9)
	_check(cw.chunks.size() == n_th and int(cw.stats()["tris"]) == tris_th, "sin hilos (threaded = false) salen las mismas %d cuadras y %d triángulos que con hilos (%d y %d)" % [cw.chunks.size(), int(cw.stats()["tris"]), n_th, tris_th])
	cw.threaded = true
	# ── 3. consultas del piso de la física mientras el hilo arma cuadras
	var p1 := Vector3(1500.0, 0.0, -400.0)
	var ck1: Vector2i = cw.city.chunk_of(p1.x, p1.z)
	var ref := []
	for i in 50:
		var q := Vector2(p1.x + float(i) * 11.0, p1.z - float(i) * 7.0)
		ref.append(track.ground_info(q.x, q.y))
		ref.append(track.push_world(q.x, q.y, 1.2))
	var mism := 0
	var t1 := Time.get_ticks_msec()
	var rounds := 0
	while Time.get_ticks_msec() - t1 < 12000:
		cw.update_around(p1, 4, 2.5)
		for i in 50:
			var q2 := Vector2(p1.x + float(i) * 11.0, p1.z - float(i) * 7.0)
			if track.ground_info(q2.x, q2.y) != ref[i * 2] or track.push_world(q2.x, q2.y, 1.2) != ref[i * 2 + 1]:
				mism += 1
		rounds += 1
		var busy2: bool = cw._job_id >= 0 or not cw._ready_q.is_empty() or not cw._pend_b.is_empty() or not cw._extras_q.is_empty() or not cw._wanted(p1, ck1, 3).is_empty()
		if not busy2:
			break
		OS.delay_msec(2)
	# (las cuadras nuevas pueden sumar objetos que chocan: se comparan sólo los puntos de la calzada, sin objetos al lado)
	_check(rounds > 3 and mism <= 4, "el piso y los choques se consultan mientras el hilo arma cuadras (%d vueltas, %d consultas distintas de 100 por vuelta)" % [rounds, mism])
	# ── 4. warm() con una cuadra en camino
	var far := Vector3(-1200.0, 0.0, 900.0)
	cw.update_around(far, 1, 2.5)
	var t2 := Time.get_ticks_msec()
	cw.warm(far)
	var ck4: Vector2i = cw.city.chunk_of(far.x, far.z)
	var ok4: bool = cw._job_id < 0 and cw._ready_q.is_empty() and cw._pend_b.is_empty() and cw._extras_q.is_empty() and cw._wanted(far, ck4, 3).is_empty()
	_check(ok4, "warm() termina todo de una vez, con un trabajo en camino (%.1f s)" % (float(Time.get_ticks_msec() - t2) / 1000.0))
	# ── 5. alejarse: se borran las cuadras de antes y no queda nada pendiente
	var gone := true
	for k5 in cw.chunks:
		if maxi(absi(k5.x - ck4.x), absi(k5.y - ck4.y)) > 4:
			gone = false
	_check(gone and cw._pending.is_empty(), "al alejarse se borran las cuadras de antes (%d armadas ahora, nada pendiente)" % cw.chunks.size())
	print("tiempo: cuentas en el hilo %.0f ms · en el principal %.0f ms (las mismas %d cuadras) · prueba entera %.1f s" % [t_thread, t_main, keys.size(), float(Time.get_ticks_msec() - t_all) / 1000.0])
	cw._exit_tree()
	quit(1 if fail else 0)
