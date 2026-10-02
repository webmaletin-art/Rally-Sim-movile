extends RefCounted
## Reglas de la picada: qué tan bien se acertó el momento de cada cambio de marcha (caja manual).

const LO := 0.93 # ventana del cambio perfecto, en proporción de las vueltas de cambio del auto (shiftUpRpm)
const HI := 1.04

enum Q { EARLY, PERFECT, LATE }

static func quality(rpm: float, shift_up_rpm: float) -> int:
	var r := rpm / shift_up_rpm
	if r < LO:
		return Q.EARLY
	return Q.PERFECT if r <= HI else Q.LATE

## Cuánto dura el cambio respecto al normal: perfecto = el doble de rápido, tarde (rebote contra el limitador) = casi el doble de lento
static func shift_scale(q: int) -> float:
	return 0.5 if q == Q.PERFECT else (1.8 if q == Q.LATE else 1.0)
