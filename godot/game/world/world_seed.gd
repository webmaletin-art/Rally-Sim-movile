extends RefCounted
## Números «al azar» DETERMINISTAS: la misma semilla y las mismas claves dan siempre el mismo resultado en cualquier teléfono (no depende de randi() ni del orden en que se pidan).
## Se usa para reconstruir la vida del mundo (tráfico, estacionados, semáforos, rutinas) a partir de WORLD_ID + WORLD_VERSION + WORLD_SEED + WORLD_TIME.
## Todo trabaja con enteros de 32 bits (las multiplicaciones caben en 64 bits sin desbordar).

const M := 0xFFFFFFFF

## Mezcla de 32 bits (tipo «hash32» de Thomas Wang, con constantes chicas para no desbordar)
static func mix32(x: int) -> int:
	x &= M
	x = (((x >> 16) ^ x) * 0x45d9f3b) & M
	x = (((x >> 16) ^ x) * 0x45d9f3b) & M
	x = (x >> 16) ^ x
	return x & M

static func combine(a: int, b: int) -> int:
	return mix32((a & M) ^ (mix32(b) + 0x9e3779b9 + ((a & M) << 6) + ((a & M) >> 2)))

## Hash de un texto (FNV-1a de 32 bits sobre los bytes UTF-8)
static func str_hash(s: String) -> int:
	var h := 0x811c9dc5
	for b in s.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & M
	return h

## Una semilla grande (hasta 2^53, como viene del servidor) se pliega a 32 bits sin perder las partes altas
static func fold(seed_v: int) -> int:
	return combine(seed_v & M, (seed_v >> 32) & M)

## Hash de una semilla con hasta cuatro claves enteras
static func hash_ints(seed_v: int, a := 0, b := 0, c := 0, d := 0) -> int:
	var h := fold(seed_v)
	h = combine(h, a)
	h = combine(h, b)
	h = combine(h, c)
	return combine(h, d)

## Número entre 0 y 1 (sin incluir 1)
static func unit(seed_v: int, a := 0, b := 0, c := 0, d := 0) -> float:
	return float(hash_ints(seed_v, a, b, c, d)) / 4294967296.0

## Entero entre lo y hi (inclusive)
static func range_i(seed_v: int, lo: int, hi: int, a := 0, b := 0, c := 0) -> int:
	return lo + int(floor(unit(seed_v, a, b, c) * float(hi - lo + 1)))

## Un RandomNumberGenerator de Godot sembrado con esas claves (para sistemas que necesitan una secuencia)
static func rng(seed_v: int, a := 0, b := 0, c := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash_ints(seed_v, a, b, c)
	return r
