extends RefCounted
## Clima del mundo (Etapa 17): una función PURA de WORLD_SEED + tiempo del mundo (el mismo reloj que el ciclo de día y noche y los semáforos). El tiempo se divide en bloques de 5 minutos;
## cada bloque tiene un estado (despejado, nublado, lluvia, tormenta, niebla) sacado de la semilla, y entre un bloque y el siguiente se mezcla durante 40 s. Todos los jugadores ven el mismo
## cielo a la misma hora, sin sincronizar nada más que el reloj. Devuelve componentes continuos: nubes, lluvia, niebla y mojado (la calle sigue mojada un rato después de llover).

const WorldSeed := preload("res://game/world/world_seed.gd")

const BLOCK := 300.0 # s del mundo por bloque
const BLEND := 40.0 # s de mezcla entre bloques
const KINDS := ["clear", "cloudy", "rain", "storm", "fog"]
# componentes de cada estado: nubes, lluvia, niebla
const COMP := {"clear": [0.05, 0.0, 0.0], "cloudy": [0.7, 0.0, 0.12], "rain": [0.9, 0.7, 0.3], "storm": [1.0, 1.0, 0.45], "fog": [0.55, 0.0, 0.85]}
const WEIGHTS := {"clear": 52, "cloudy": 22, "rain": 14, "storm": 4, "fog": 8}

## Estado del bloque n (determinista). Evita dos tormentas seguidas y que arranque lloviendo fuerte el primer bloque del día.
static func block_kind(world_seed: int, n: int) -> String:
	var total := 0
	for k in KINDS:
		total += int(WEIGHTS[k])
	var u := WorldSeed.unit(world_seed, 9001, n) * float(total)
	var kind := "clear"
	var acc := 0.0
	for k in KINDS:
		acc += float(WEIGHTS[k])
		if u < acc:
			kind = k
			break
	if kind == "storm" and n > 0 and block_kind_raw(world_seed, n - 1) == "storm":
		kind = "rain"
	return kind

static func block_kind_raw(world_seed: int, n: int) -> String:
	var total := 0
	for k in KINDS:
		total += int(WEIGHTS[k])
	var u := WorldSeed.unit(world_seed, 9001, n) * float(total)
	var acc := 0.0
	for k in KINDS:
		acc += float(WEIGHTS[k])
		if u < acc:
			return k
	return "clear"

## Nubes, lluvia y niebla en el instante t (continuo: se mezcla entre bloques)
static func _comp(world_seed: int, t: float) -> Array:
	var n := int(floor(t / BLOCK))
	var into := t - float(n) * BLOCK
	var cur := block_kind(world_seed, n)
	var c: Array = COMP[cur]
	var cloud := float(c[0])
	var rain := float(c[1])
	var fog := float(c[2])
	if into < BLEND * 0.5:
		# la primera mitad del tramo de mezcla viene del bloque anterior
		var prev: Array = COMP[block_kind(world_seed, n - 1)]
		var w := smoothstep(0.0, 1.0, 0.5 + into / BLEND)
		cloud = lerpf(float(prev[0]), cloud, w)
		rain = lerpf(float(prev[1]), rain, w)
		fog = lerpf(float(prev[2]), fog, w)
	elif into > BLOCK - BLEND * 0.5:
		var nxt: Array = COMP[block_kind(world_seed, n + 1)]
		var w2 := smoothstep(0.0, 1.0, (into - (BLOCK - BLEND * 0.5)) / BLEND)
		cloud = lerpf(cloud, float(nxt[0]), w2)
		rain = lerpf(rain, float(nxt[1]), w2)
		fog = lerpf(fog, float(nxt[2]), w2)
	return [cloud, rain, fog]

## Clima en el instante t del mundo: {cloud, rain, fog, wet, kind}
static func at(world_seed: int, t: float) -> Dictionary:
	var c := _comp(world_seed, t)
	var rain := float(c[1])
	# mojado: llueve ahora, o llovió hace poco (la calle seca de a poco: 100, 200 y 300 s después)
	var wet := rain
	var k := 0.85
	for lag in [100.0, 200.0, 300.0]:
		wet = maxf(wet, float(_comp(world_seed, t - float(lag))[1]) * k)
		k -= 0.2
	return {"cloud": float(c[0]), "rain": rain, "fog": float(c[2]), "wet": clampf(wet, 0.0, 1.0), "kind": block_kind(world_seed, int(floor(t / BLOCK)))}

## Qué porcentaje del tiempo llueve (para comprobar que el clima no es un diluvio ni un desierto)
static func rain_fraction(world_seed: int, blocks: int) -> float:
	var r := 0
	for n in blocks:
		var k := block_kind(world_seed, n)
		if k == "rain" or k == "storm":
			r += 1
	return float(r) / float(maxi(blocks, 1))
