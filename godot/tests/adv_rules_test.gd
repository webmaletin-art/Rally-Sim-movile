## Reglas de la aventura para publicar ([B] 20/10/2026): 5 etapas libres, daño bajo y cada etapa con el auto reparado.
## Pedido del dueño: «hacé más bajo el daño de ruedas en la aventura y que cada vez que reinicio una carrera o una etapa se reinicie el daño; dejá libres 5 etapas».
## Uso: tools/test/run_test.sh adv_rules_test 30
extends SceneTree

const Release := preload("res://game/data/release.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	# 1. etapas libres
	_check(Release.ADVENTURE_STAGES == 5, "etapas libres de la aventura: %d" % Release.ADVENTURE_STAGES)
	_check(Release.adventure_limit(null) == 5, "sin compra el límite es 5 etapas (%d)" % Release.adventure_limit(null))
	# 2. un auto sin daño no pierde nada
	var st := AdvData.default_state()
	var z := AdvData.damage_mul(st)
	_check(absf(float(z["power"]) - 1.0) < 1e-6 and absf(float(z["grip"]) - 1.0) < 1e-6 and absf(float(z["pull"])) < 1e-6, "el auto reparado no tiene ninguna pérdida")
	# 3. el daño máximo de cada parte pega mucho menos que antes (potencia −30 %, agarre −12 %, volante 0,14)
	st["damage"] = {"motor": 1.0, "dir": 1.0, "susp": 1.0}
	var m := AdvData.damage_mul(st)
	_check(float(m["power"]) >= 0.8 - 1e-6, "motor al máximo: potencia ×%.2f (antes ×0,70)" % float(m["power"]))
	_check(float(m["grip"]) >= 0.94 - 1e-6, "suspensión al máximo: agarre ×%.2f (antes ×0,88)" % float(m["grip"]))
	_check(absf(float(m["pull"])) <= 0.05 + 1e-6, "dirección al máximo: el volante tira %.2f (antes 0,14)" % absf(float(m["pull"])))
	# 4. un golpe fuerte (20 m/s contra el guardarraíl) suma poco daño: hacen falta muchos para llegar a algo notable
	var k := (20.0 - 2.5) * AdvData.HIT_K
	_check(k < 0.15, "un golpe a 72 km/h suma %.3f de daño (antes %.3f)" % [k, (20.0 - 2.5) * 0.018])
	_check(int(ceil(0.5 / (k * 0.6))) >= 7, "hacen falta %d golpes fuertes contra la pared para dejar la dirección a la mitad" % int(ceil(0.5 / (k * 0.6))))
	# 5. cada etapa arranca reparada
	var zd := AdvData.zero_damage()
	_check(float(zd["motor"]) == 0.0 and float(zd["dir"]) == 0.0 and float(zd["susp"]) == 0.0, "zero_damage deja las tres partes en cero")
	quit(1 if fail else 0)
