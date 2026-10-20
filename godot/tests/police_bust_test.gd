## La barra de arresto de la policía depende de la velocidad ([B] 20/10/2026): a velocidad alta no hay arresto, despacio o quieto sube rápido, en el medio sube lento sólo si te encierran.
## Reporte del dueño: «voy en persecución y me arrestan igual; a velocidades altas no deberían arrestarme; si me frenan o me quedo quieto, sube la barra».
## Uso: tools/test/run_test.sh police_bust_test 20
extends SceneTree

const CityPolice := preload("res://game/city/city_police.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var B = CityPolice
	# 1. a velocidad alta, ni un patrullero encima te arresta (antes llenaba la barra en 6 s a cualquier velocidad)
	for kmh in [70.0, 100.0, 150.0, 220.0]:
		for d in [0.5, 3.0, 4.0, 8.0, 20.0]:
			if B.bust_rate(kmh, d) > 0.0:
				_check(false, "a %d km/h con un patrullero a %.1f m la barra sube (%.3f)" % [kmh, d, B.bust_rate(kmh, d)])
	_check(B.bust_rate(150.0, 2.0) < 0.0, "a 150 km/h con un patrullero encima la barra baja")
	# 2. casi quieto o muy despacio con uno cerca: te arrestan rápido (1,6 s)
	_check(absf(1.0 / B.bust_rate(0.0, 10.0) - B.BUST_T) < 0.01, "quieto con un patrullero a 10 m: arresto en %.1f s" % (1.0 / B.bust_rate(0.0, 10.0)))
	_check(absf(1.0 / B.bust_rate(20.0, 6.0) - B.BUST_T) < 0.01, "a 20 km/h con uno a 6 m: arresto en %.1f s" % (1.0 / B.bust_rate(20.0, 6.0)))
	_check(B.bust_rate(3.0, 13.0) > 0.0, "quieto con un patrullero a 13 m: ya sube (te rodean)")
	_check(B.bust_rate(3.0, 30.0) < 0.0, "quieto pero con los patrulleros lejos: baja")
	# 3. entre 25 y 70 km/h sólo sube si te encierran (pegado), y más lento cuanto más rápido vas
	_check(B.bust_rate(40.0, 7.0) < 0.0, "a 40 km/h con uno a 7 m (no pegado): baja")
	var r40: float = B.bust_rate(40.0, 3.0)
	var r60: float = B.bust_rate(60.0, 3.0)
	var r26: float = B.bust_rate(26.0, 3.0)
	_check(r40 > 0.0 and r60 > 0.0 and r60 < r40 and r40 < r26, "pegado: sube más lento cuanto más rápido (26 km/h %.3f · 40 km/h %.3f · 60 km/h %.3f por s)" % [r26, r40, r60])
	_check(1.0 / r26 >= 5.0, "pegado a 26 km/h tarda %.1f s en arrestarte (no 1,6 s)" % (1.0 / r26))
	# 4. sin patrulleros (distancia enorme) siempre baja
	for kmh in [0.0, 30.0, 90.0]:
		_check(B.bust_rate(kmh, 1.0e9) < 0.0, "sin patrulleros cerca a %d km/h la barra baja" % int(kmh))
	quit(1 if fail else 0)
