## Guardarrailes en barrancos (Etapa 12): hay donde el camino cae al costado, ninguno sobre el asfalto ni en un cruce, y son sólidos. Sin red.
## Uso: godot --headless --path godot --script res://tests/guardrail_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const CityProps := preload("res://game/city/city_props.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var c := CityLayout.new()
	c.build()
	var n := 0
	var on_asphalt := 0
	var floating := 0
	var by_kind := {}
	for id in c.prop_type.size():
		if int(c.prop_type[id]) != CityProps.GUARD:
			continue
		n += 1
		var x: float = c.prop_x[id]
		var z: float = c.prop_z[id]
		var pr := c.probe(x, z)
		if pr[6] >= 0.0 and float(pr[1]) <= float(pr[5]) + 0.2:
			on_asphalt += 1
		else:
			var ry := float(pr[4])
			if pr[6] >= 0.0 and absf(float(c.prop_y[id]) - ry) > 3.0:
				floating += 1
				if floating < 4:
					print('     flota: ', Vector2(x, z), ' y ', c.prop_y[id], ' eje ', ry, ' calle ', c.roads[int(pr[6])]['name'])
		var k := str(c.roads[int(pr[6])]["kind"]) if pr[6] >= 0.0 else "?"
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	print("     guardarrailes: ", n, " ", by_kind)
	check(n > 20, "hay guardarrailes en el camino de la colina (%d)" % n)
	check(on_asphalt == 0, "ninguno sobre el asfalto")
	check(floating == 0, "todos a la altura de su calle")
	check(CityProps.RADIUS.size() > CityProps.GUARD and CityProps.RADIUS[CityProps.GUARD] > 1.0, "son sólidos (radio %.2f)" % CityProps.RADIUS[CityProps.GUARD])
	# no se rompen: sólo los tipos < 4 se rompen
	check(CityProps.GUARD >= 4, "no se rompen con el choque")
	print("GUARDRAIL_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
