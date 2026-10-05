## Clima del mundo (Etapa 17): determinista, continuo, con lluvia razonable y mojado que seca de a poco. Sin red.
## Uso: godot --headless --path godot --script res://tests/world_weather_test.gd
extends SceneTree

const WW := preload("res://game/world/world_weather.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var a := WW.at(4242, 12345.0)
	var b := WW.at(4242, 12345.0)
	check(a == b, "mismo mundo y misma hora: el mismo cielo (%s)" % str(a["kind"]))
	# otra semilla da otro clima en algún momento
	var differs := false
	for n in 60:
		if WW.block_kind(4242, n) != WW.block_kind(99, n):
			differs = true
	check(differs, "otra semilla de mundo tiene otro clima")
	# fracciones razonables en 400 bloques (≈ 33 horas del mundo)
	var counts := {}
	for n in 400:
		var k := WW.block_kind(7, n)
		counts[k] = int(counts.get(k, 0)) + 1
	print("     reparto: ", counts)
	var rf := WW.rain_fraction(7, 400)
	check(rf > 0.08 and rf < 0.35, "llueve el %.0f %% del tiempo" % (rf * 100.0))
	check(int(counts.get("clear", 0)) > 120, "casi la mitad del tiempo está despejado")
	# continuidad: nada salta entre cuadros (paso de 0,5 s)
	var worst := 0.0
	var prev := WW.at(7, 0.0)
	var t := 0.5
	while t < 6000.0:
		var cur := WW.at(7, t)
		for k in ["cloud", "rain", "fog", "wet"]:
			worst = maxf(worst, absf(float(cur[k]) - float(prev[k])))
		prev = cur
		t += 0.5
	check(worst < 0.06, "el clima cambia sin saltos (mayor cambio en 0,5 s: %.3f)" % worst)
	# rangos
	var ok_range := true
	for i in 2000:
		var w := WW.at(31, float(i) * 7.3)
		for k in ["cloud", "rain", "fog", "wet"]:
			if float(w[k]) < -0.001 or float(w[k]) > 1.001:
				ok_range = false
	check(ok_range, "los componentes siempre quedan entre 0 y 1")
	# después de llover sigue mojado un rato y seca de a poco
	var found := false
	for n in range(1, 400):
		if WW.block_kind(7, n) in ["rain", "storm"] and WW.block_kind(7, n + 1) in ["clear", "cloudy", "fog"]:
			var t_end := float(n + 1) * WW.BLOCK
			var w1 := WW.at(7, t_end + 50.0)
			var w2 := WW.at(7, t_end + 250.0)
			found = float(w1["rain"]) < 0.05 and float(w1["wet"]) > float(w2["wet"]) and float(w1["wet"]) > 0.2
			break
	check(found, "terminada la lluvia la calle sigue mojada y seca de a poco")
	print("WORLD_WEATHER_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
