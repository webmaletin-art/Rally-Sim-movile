extends RefCounted
## Rutinas del tránsito (Etapa 10): cómo cambia la vida de la calle con la hora del mundo. Son funciones PURAS de la hora (0–24) y del día del mundo, así que todos ven lo mismo.
##  - densidad: poco de madrugada, pico a la mañana (7–9:30) y a la tarde (17–20), calmo al mediodía; los fines de semana (los días 5 y 6 de cada 7) el pico es más suave y la noche más viva
##  - sentido: a la mañana la gente va hacia el centro y a la tarde sale (las rutas se inclinan hacia ese lado en cada cruce)
##  - velocidad: en la hora pico se anda más despacio y de noche más rápido
##  - estacionados: de día (trabajo) hay menos autos en el cordón, de noche (casas) más

static func is_weekend(day_index: int) -> bool:
	var d := posmod(day_index, 7)
	return d == 5 or d == 6

static func _bump(h: float, c: float, w: float) -> float:
	var d := absf(h - c)
	return clampf(1.0 - d / w, 0.0, 1.0)

## Multiplicador de la cantidad de autos en marcha (1.0 = normal)
static func density(hour: float, weekend := false) -> float:
	var h := fposmod(hour, 24.0)
	var base := 0.28
	var day := smoothstep(5.0, 8.0, h) * smoothstep(23.5, 20.5, h) # de día hay más gente
	base += 0.55 * day
	var peak := 0.30 if weekend else 0.65
	base += peak * (_bump(h, 8.3, 1.9) + _bump(h, 18.5, 2.2))
	if weekend:
		base += 0.25 * _bump(h, 14.0, 4.0) + 0.2 * _bump(h, 22.0, 2.5) # paseos y salidas
	return clampf(base, 0.2, 1.6)

## -1 (salen del centro) … +1 (van hacia el centro)
static func inward_bias(hour: float, weekend := false) -> float:
	var h := fposmod(hour, 24.0)
	var amp := 0.5 if weekend else 1.0
	return amp * (_bump(h, 8.3, 2.2) - _bump(h, 18.5, 2.4))

## Factor de la velocidad de crucero
static func speed_factor(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var rush := maxf(_bump(h, 8.3, 1.6), _bump(h, 18.5, 1.8))
	var night := smoothstep(22.0, 24.0, h) + smoothstep(5.0, 3.0, h)
	return 1.0 - 0.18 * rush + 0.12 * clampf(night, 0.0, 1.0)

## Fracción de los lugares de estacionamiento ocupados (multiplica el 36 % base)
static func parked_factor(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var away := smoothstep(7.0, 9.0, h) * smoothstep(19.0, 17.0, h) # de 9 a 17 la gente está en el trabajo
	return lerpf(1.35, 0.6, away)
