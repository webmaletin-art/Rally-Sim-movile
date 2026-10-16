## Reglas de premio de las carreras del mapa (fase 4, game/city/city_events.gd → pay_mult): perder a propósito ya no paga más que ganar.
## Corta (≈ 1 s). Uso: tools/test/run_test.sh progression_rules_test 30
extends SceneTree

const CityEvents := preload("res://game/city/city_events.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var E = CityEvents
	_check(is_equal_approx(E.pay_mult(true, true, 1), 1.0) and is_equal_approx(E.pay_mult(true, true, 4), 1.0), "la primera victoria paga entera (aunque haya perdido antes)")
	_check(is_equal_approx(E.pay_mult(true, false, 5), E.REPEAT_K), "una victoria repetida paga el 35 %")
	_check(is_equal_approx(E.pay_mult(false, true, 1), 1.0), "el primer intento perdido paga su puesto entero (2.º 45 %, plata 60 %): no castiga al que aprende")
	_check(is_equal_approx(E.pay_mult(false, true, 2), E.LOSE_K), "desde el segundo intento, perder paga × %.2f" % E.LOSE_K)
	var second: float = E.PLACE_K[1] * E.LOSE_K
	var silver: float = E.MEDAL_K[1] * E.LOSE_K
	_check(second < E.REPEAT_K and silver < E.REPEAT_K, "salir 2.º (%.0f %%) o sacar plata (%.0f %%) repetido paga MENOS que ganar repetido (%.0f %%)" % [second * 100.0, silver * 100.0, E.REPEAT_K * 100.0])
	_check(E.PLACE_K[1] > E.PLACE_K[2] and E.MEDAL_K[1] > E.MEDAL_K[2], "el orden de los puestos y medallas se mantiene (2.º > 3.º, plata > bronce)")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
