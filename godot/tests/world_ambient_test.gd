## Audio ambiente del mundo (Etapa 20): las decisiones (qué motores suenan, Doppler, ruido de ciudad, truenos iguales para todos) sin necesitar audio.
## Uso: godot --headless --path godot --script res://tests/world_ambient_test.gd
extends SceneTree

const WA := preload("res://game/audio/world_ambient.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

class FV:
	extends RefCounted
	var pos := Vector3.ZERO
	var crashed := false

func _initialize() -> void:
	var list: Array = []
	for i in 6:
		var v := FV.new()
		v.pos = Vector3(10.0 * float(i + 1), 0, 0)
		list.append(v)
	(list[0] as FV).crashed = true
	var pick: Array = WA.pick_nearest(list, Vector3.ZERO, 60.0, 3)
	check(pick.size() == 3 and pick[0] == list[1] and not pick.has(list[0]), "suenan los 3 más cercanos y un auto chocado no suena")
	check(WA.pick_nearest(list, Vector3.ZERO, 25.0, 4).size() == 1, "fuera del radio no suena nadie (sólo el de 20 m)")
	# histéresis: el que ya suena se conserva un poco más lejos
	var far := FV.new()
	far.pos = Vector3(70, 0, 0)
	check(WA.pick_nearest([far], Vector3.ZERO, 60.0, 2, []).is_empty() and WA.pick_nearest([far], Vector3.ZERO, 60.0, 2, [far]).size() == 1, "un auto que ya sonaba se conserva hasta 75 m (no parpadea en el borde)")
	check(WA.doppler(30.0) > 1.0 and WA.doppler(-30.0) < 1.0 and is_equal_approx(WA.doppler(0.0), 1.0), "Doppler: se acerca → más agudo, se aleja → más grave")
	check(WA.doppler(500.0) <= 1.25 and WA.doppler(-500.0) >= 0.8, "el Doppler está acotado")
	check(WA.engine_pitch(20.0) > WA.engine_pitch(0.0) and WA.engine_pitch(0.0) > 0.2, "el motor sube de tono con la velocidad")
	check(WA.bed_level(10.0, 0.0, 0.0) > WA.bed_level(10.0, 1.0, 0.0), "de noche el ruido de ciudad baja")
	check(WA.bed_level(0.0, 0.0, 0.0) == 0.0 and WA.bed_level(2.0, 0.0, 0.0) < WA.bed_level(9.0, 0.0, 0.0), "más autos cerca → más ruido de ciudad; sin autos, silencio")
	check(WA.bed_level(10.0, 0.0, 40.0) < WA.bed_level(10.0, 0.0, 0.0), "a alta velocidad el viento tapa el ruido de ciudad")
	# truenos iguales para todos
	var a: Array = WA.thunder_events(12345, 0.0, 900.0)
	var b: Array = WA.thunder_events(12345, 0.0, 900.0)
	check(a.size() > 20 and a.size() < 90 and JSON.stringify(a) == JSON.stringify(b), "los truenos salen de la semilla y la hora: dos jugadores oyen los mismos (%d en 15 min)" % a.size())
	check(JSON.stringify(WA.thunder_events(999, 0.0, 900.0)) != JSON.stringify(a), "otro mundo, otros truenos")
	var split: Array = WA.thunder_events(12345, 0.0, 450.0) + WA.thunder_events(12345, 450.0, 900.0)
	check(split.size() == a.size(), "pedirlos en tramos da lo mismo que de una vez")
	print("WORLD_AMBIENT_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)
