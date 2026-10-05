extends RefCounted
## Progresión del mundo (Etapa 16): la FAMA en Dream City. Se gana descubriendo lugares, manejando, pasando radares, entregando encargos y ganando medallas de la contrarreloj, y sube de
## RANGO. Cada rango da ventajas concretas (nafta más barata, encargos mejor pagados, cambio de gomas más barato). Reglas puras: el estado (puntos y lugares descubiertos) vive en el perfil
## (offline: profile.d["worldRep"]); el online tendrá el suyo, separado, guardado por el servidor (ver docs/ECONOMIA_ONLINE.md).

const RANKS := [
	{"name": "Novato", "pts": 0},
	{"name": "Conductor", "pts": 60},
	{"name": "Piloto urbano", "pts": 180},
	{"name": "Veterano", "pts": 400},
	{"name": "Leyenda de Dream City", "pts": 800},
]
const RANK_BONUS := [0, 300, 600, 1200, 3000] # créditos de regalo al llegar a cada rango

## Puntos de fama por evento
const PTS := {"discover": 6.0, "km": 1.0, "trap": 4.0, "trap_tier": 3.0, "delivery": 12.0, "medal": 25.0}

static func rank_for(pts: float) -> int:
	var r := 0
	for i in RANKS.size():
		if pts >= float(RANKS[i]["pts"]):
			r = i
	return r

static func rank_name(rank: int) -> String:
	return str(RANKS[clampi(rank, 0, RANKS.size() - 1)]["name"])

## Puntos que faltan para el próximo rango (0 si ya es el último)
static func to_next(pts: float) -> float:
	var r := rank_for(pts)
	if r >= RANKS.size() - 1:
		return 0.0
	return float(RANKS[r + 1]["pts"]) - pts

## Ventajas por rango: multiplicadores (1 = sin cambio)
static func fuel_price_k(rank: int) -> float:
	return 1.0 - 0.04 * float(rank) # hasta −16 %

static func delivery_pay_k(rank: int) -> float:
	return 1.0 + 0.06 * float(rank) # hasta +24 %

static func tire_price_k(rank: int) -> float:
	return 1.0 - 0.05 * float(rank) # hasta −20 %

## Puntos de un radar según los km/h (más rápido, más fama)
static func trap_pts(reward: int) -> float:
	var tier := 0
	for lim in [150, 300, 600, 1000]:
		if reward >= lim:
			tier += 1
	return float(PTS["trap"]) + float(PTS["trap_tier"]) * float(maxi(tier - 1, 0))
