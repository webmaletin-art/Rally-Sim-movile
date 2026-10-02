extends RefCounted
## Prueba de rendimiento completa («PRUEBA DE RENDIMIENTO» del menú de inicio). Arma la lista de pasos (cada paso es una
## configuración medida unos segundos), calcula las estadísticas de cada uno y escribe el informe de texto para copiar y pegar.
##
## Orden de cada pista: 1) BASE sin ningún filtro de cámara (cantidad de autos, resolución, sombras, hilos, pilotos, árboles) ·
## 2) CÁMARAS (lejos, cerca, casco, atrás…) · 3) COMPONENTES apagados a propósito para medir cuánto cuesta cada uno ·
## 4) CON FILTROS: la configuración del jugador, el lente y cada efecto de cámara solo y en combinaciones.
## Todos los pasos de 2 a 4 usan la misma base (4 autos, 50 %), así que la diferencia contra «BASE» es el costo de eso.

const Lens := preload("res://game/fx/lens.gd")

const STEP_S_REAL := 5.5 # segundos por paso (el primer 1,5 s se descarta: carga de shaders y de autos)
const WARM_S_REAL := 1.5
## Para probar la prueba en la compu se acorta con la variable de entorno PB_FAST
static func step_s() -> float:
	return 1.6 if OS.has_environment("PB_FAST") else STEP_S_REAL

static func warm_s() -> float:
	return 0.5 if OS.has_environment("PB_FAST") else WARM_S_REAL

const CAMS := [[1, "Media (tercera persona)"], [2, "Cerca/Alta"], [3, "Lejos/Baja"], [0, "Onboard (casco)"], [6, "Onboard (desde atrás)"], [7, "Capó"]]
const COMPONENTS := [["e", "sin humo/polvo/marcas"], ["c", "sin cielo"], ["n", "sin niebla"], ["h", "sin controles en pantalla"], ["m", "sin dibujar el mundo 3D (solo interfaz)"], ["a", "sin sonido"]]
const FX_SINGLE := [14, 23, 24, 25, 26, 27, 28, 13, 15, 3, 9, 22]
const FX_COMBOS := [["🎬 Realista (oclusión + cromática + ojo de pez)", [23, 24, 14]], ["🎞 Cine (tonos + granulado + destello)", [25, 28, 27]], ["⚠ Pesado (boceto + oclusión + profundidad de campo)", [15, 23, 26]]]

static func step(track: String, grp: String, name: String, o := {}) -> Dictionary:
	var s := {"track": track, "grp": grp, "name": name, "cars": 4, "trees": 3000, "pilots": true, "shadows": false, "threads": true, "res": 0.5, "cam": 1,
		"lens_on": false, "lens_level": 0, "fx": [0, 0, 0], "flags": "", "ref": false, "user_lens": false}
	for k in o:
		s[k] = o[k]
	return s

## mode: "quick" (≈3 min) o "full" (≈8 min). user_*: el lente y los efectos que tiene puestos el jugador.
static func plan(mode: String) -> Array:
	var full := mode == "full"
	var out: Array = []
	out.append_array(_track_steps("lake", "Circuito del Lago (asfalto)", full, 8, true))
	if full:
		out.append(step("forest", "BOSQUE", "4 autos · 50 %", {"ref": true}))
		out.append(step("forest", "BOSQUE", "8 autos · 50 %", {"cars": 8}))
		out.append(step("forest", "BOSQUE", "4 autos · muchos árboles (8000)", {"trees": 8000}))
		out.append(step("forest", "BOSQUE", "Onboard (casco)", {"cam": 0}))
		out.append(step("forest", "BOSQUE", "Con tu lente y efectos", {"lens_on": true, "user_lens": true}))
	out.append_array(_track_steps("drift", "Drift Plaza (ciudad, conos con física)", full, 6, false))
	# la base otra vez al final: si bajó, el teléfono se calentó y se está frenando solo
	out.append(step("lake", "FINAL", "BASE otra vez (para ver si el teléfono se calentó)", {"ref": true}))
	return out

static func _track_steps(t: String, label: String, full: bool, max_cars: int, trees: bool) -> Array:
	var g := label
	var o: Array = []
	# 1) base, sin filtros de cámara
	if full:
		o.append(step(t, g + " · BASE sin filtros", "1 auto · resolución 100 %", {"cars": 1, "res": 1.0}))
		o.append(step(t, g + " · BASE sin filtros", "1 auto · 50 %", {"cars": 1}))
	o.append(step(t, g + " · BASE sin filtros", "4 autos · 50 %  (BASE de comparación)", {"ref": true}))
	o.append(step(t, g + " · BASE sin filtros", "%d autos · 50 %%" % max_cars, {"cars": max_cars}))
	if full:
		o.append(step(t, g + " · BASE sin filtros", "4 autos · 75 %", {"res": 0.75}))
		o.append(step(t, g + " · BASE sin filtros", "4 autos · 35 %", {"res": 0.35}))
	o.append(step(t, g + " · BASE sin filtros", "4 autos + sombras", {"shadows": true}))
	if full:
		o.append(step(t, g + " · BASE sin filtros", "%d autos + sombras" % max_cars, {"cars": max_cars, "shadows": true}))
	o.append(step(t, g + " · BASE sin filtros", "4 autos · sin hilos de física", {"threads": false}))
	if full:
		if trees:
			o.append(step(t, g + " · BASE sin filtros", "4 autos · 8000 árboles", {"trees": 8000}))
			o.append(step(t, g + " · BASE sin filtros", "4 autos · sin árboles", {"trees": 0}))
	# 2) cámaras
	for c in CAMS:
		if not full and not (int(c[0]) in [0, 6, 3]):
			continue
		o.append(step(t, g + " · CÁMARAS", str(c[1]), {"cam": int(c[0])}))
	# 3) componentes apagados
	for c in COMPONENTS:
		if not full and not (str(c[0]) in ["e", "h", "m"]):
			continue
		o.append(step(t, g + " · COMPONENTES APAGADOS", str(c[1]), {"flags": str(c[0])}))
	# 4) con filtros
	var G := g + " · CON FILTROS"
	o.append(step(t, G, "TU configuración de lente y efectos", {"lens_on": true, "user_lens": true}))
	for lv in [1, 2]:
		o.append(step(t, G, "Lente Rally nivel %d" % lv, {"lens_on": true, "lens_level": lv}))
	for id in FX_SINGLE:
		if not full and not (id in [14, 23, 26]):
			continue
		o.append(step(t, G, "Efecto: %s" % str(Lens.FX_NAMES[id]), {"lens_on": true, "fx": [id, 0, 0]}))
	for cb in FX_COMBOS:
		if not full and str(cb[0]).begins_with("🎞"):
			continue
		o.append(step(t, G, str(cb[0]), {"lens_on": true, "fx": cb[1], "lens_level": 1}))
	return o

static func total_seconds(plan_list: Array) -> float:
	return float(plan_list.size()) * STEP_S_REAL

# ───────────────────────── estadísticas ─────────────────────────
## samples: [dt, ms de espera de física, llamadas, triángulos, ms de código, objetos]
static func summarize(samples: Array) -> Dictionary:
	var n := samples.size()
	if n == 0:
		return {}
	var dts: Array = []
	var sdt := 0.0
	var sph := 0.0
	var sdc := 0.0
	var stri := 0.0
	var sscr := 0.0
	var sob := 0.0
	var scpu := 0.0
	var sgpu := 0.0
	for s in samples:
		dts.append(float(s[0]))
		sdt += float(s[0])
		sph += float(s[1])
		sdc += float(s[2])
		stri += float(s[3])
		sscr += float(s[4])
		sob += float(s[5])
		scpu += float(s[6]) if s.size() > 6 else 0.0
		sgpu += float(s[7]) if s.size() > 7 else 0.0
	dts.sort()
	var slow20 := 0
	var slow33 := 0
	for d in dts:
		if float(d) > 0.0205:
			slow20 += 1
		if float(d) > 0.0334:
			slow33 += 1
	return {"n": n, "fps": float(n) / sdt, "ms": sdt / float(n) * 1000.0, "p50": float(dts[n / 2]) * 1000.0, "p95": float(dts[int(n * 0.95)]) * 1000.0,
		"p99": float(dts[mini(n - 1, int(n * 0.99))]) * 1000.0, "worst": float(dts[n - 1]) * 1000.0, "s20": 100.0 * float(slow20) / float(n), "s33": slow33,
		"phys": sph / float(n), "script": sscr / float(n), "draws": sdc / float(n), "tris": stri / float(n), "objs": sob / float(n), "rcpu": scpu / float(n), "rgpu": sgpu / float(n)}

static func _line(r: Dictionary) -> String:
	var st: Dictionary = r["stats"]
	if st.is_empty():
		return "%s → (sin datos)" % str(r["name"])
	return "%-52s → %3d FPS · %5.1f ms · p95 %5.1f · p99 %5.1f · peor %5.1f · >20ms %4.1f%% · tirones(>33ms) %3d · fís %4.1f · código %4.1f · render CPU %4.1f / GPU %4.1f · %3d llam · %3dk tri" % [
		str(r["name"]), int(round(float(st["fps"]))), float(st["ms"]), float(st["p95"]), float(st["p99"]), float(st["worst"]), float(st["s20"]), int(st["s33"]),
		float(st["phys"]), float(st["script"]), float(st["rcpu"]), float(st["rgpu"]), int(st["draws"]), int(float(st["tris"]) / 1000.0)]

## El informe completo. header: líneas del teléfono/juego. results: [{track, grp, name, ref, stats, vmem, tmem}]
static func report(header: Array, results: Array, extra: Array) -> String:
	var out: Array = []
	out.append_array(header)
	out.append_array(extra)
	out.append("")
	# resumen por pista: base + costo de cada cosa
	var tracks: Array = []
	for r in results:
		if not tracks.has(str(r["track"])):
			tracks.append(str(r["track"]))
	out.append("════════ RESUMEN ════════")
	for t in tracks:
		var ref := {}
		for r in results:
			if str(r["track"]) == t and bool(r["ref"]) and not str(r["grp"]) == "FINAL":
				ref = r
				break
		if ref.is_empty():
			continue
		var rs: Dictionary = ref["stats"]
		if rs.is_empty():
			continue
		out.append("")
		out.append("▶ %s — BASE (4 autos, 50 %%, sin filtros): %d FPS · %.1f ms por cuadro · p95 %.1f ms · tirones %d" % [_track_name(results, t), int(round(float(rs["fps"]))), float(rs["ms"]), float(rs["p95"]), int(rs["s33"])])
		var costs: Array = []
		for r in results:
			if str(r["track"]) != t or r == ref or r["stats"].is_empty() or str(r["grp"]) == "FINAL":
				continue
			var g := str(r["grp"])
			if g.contains("COMPONENTES") or g.contains("CON FILTROS") or g.contains("CÁMARAS"):
				costs.append([float(r["stats"]["ms"]) - float(rs["ms"]), g.split(" · ")[-1] + ": " + str(r["name"])])
		costs.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
		out.append("  Lo que MÁS cuesta (ms por cuadro de más respecto de la base; negativo = ahorra):")
		for i in mini(costs.size(), 12):
			out.append("   %+6.1f ms  %s" % [float(costs[i][0]), str(costs[i][1])])
		var worst_fx := ""
		for c in costs:
			if str(c[1]).begins_with("CON FILTROS") and float(c[0]) > 3.0:
				worst_fx += "%s (+%.1f) · " % [str(c[1]).replace("CON FILTROS: ", ""), float(c[0])]
		if worst_fx != "":
			out.append("  Filtros que pasan los 3 ms: " + worst_fx.trim_suffix(" · "))
	# calor
	var first := {}
	var last := {}
	for r in results:
		if str(r["grp"]) == "FINAL":
			last = r
		elif bool(r["ref"]) and str(r["track"]) == "lake" and first.is_empty():
			first = r
	if not first.is_empty() and not last.is_empty() and not first["stats"].is_empty() and not last["stats"].is_empty():
		var f0 := float(first["stats"]["fps"])
		var f1 := float(last["stats"]["fps"])
		out.append("")
		out.append("▶ Calentamiento: la base al principio %d FPS y al final %d FPS (%s)" % [int(round(f0)), int(round(f1)), "el teléfono se calentó y se frena solo" if f1 < f0 * 0.88 else "estable, sin frenarse por calor"])
	out.append("")
	out.append("════════ DETALLE DE CADA PASO ════════")
	out.append("(render CPU/GPU = ms que tarda el motor en preparar/dibujar el mundo 3D según el propio motor; 0.0 = este teléfono no lo mide · FPS = cuadros por segundo promedio · p95/p99 = tiempo de cuadro del 95/99 % de los cuadros · fís = ms que el hilo principal espera a la física · código = ms de script por cuadro · llam = llamadas de dibujo · tri = triángulos)")
	var cur := ""
	for r in results:
		var gk := str(r["grp"])
		if gk != cur:
			cur = gk
			out.append("")
			out.append("— " + gk + " —")
		out.append(_line(r))
	out.append("")
	out.append("Memoria de video al final: %d MB · texturas: %d MB" % [int(results[-1].get("vmem", 0)), int(results[-1].get("tmem", 0))])
	out.append("=== FIN DEL INFORME ===")
	return "\n".join(out)

static func _track_name(results: Array, t: String) -> String:
	for r in results:
		if str(r["track"]) == t:
			return str(r["grp"]).split(" · ")[0]
	return t
