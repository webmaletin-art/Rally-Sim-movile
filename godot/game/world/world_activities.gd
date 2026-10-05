extends RefCounted
## Actividades del mundo abierto de Dream City (Etapa 15): reglas PURAS (sin nodos ni estado): dónde están, cómo se puntúan y cuánto pagan. Todo sale del mapa y de la semilla del
## mundo, así que es igual para todos. El estado (récords, cobros) vive en el perfil (offline) y lo maneja city/city_activities.gd.
##  · RADARES: líneas de control de velocidad en avenidas y rutas; pasar rápido paga (una vez por radar por día del mundo) y se guarda el récord.
##  · CONTRARRELOJ PANORÁMICA: la Ruta Panorámica 70 de punta a punta; medallas de bronce/plata/oro por tiempo.
##  · ENCARGOS: llevar algo de un lugar a otro de la ciudad antes de un límite de tiempo; los ofrece el mundo (semilla + día + número de encargo).

const WorldSeed := preload("res://game/world/world_seed.gd")

const TRAP_SPECS := [["Avenida 1", 450.0], ["Avenida 3", 520.0], ["Avenida 5", 470.0], ["Avenida 7", 620.0], ["Ruta 20", 1500.0], ["Ruta 60", 1400.0], ["Ruta Panorámica 70", 1700.0], ["Ruta Panorámica 70", 3500.0]]
const TRAP_TIERS := [[240.0, 1000], [200.0, 600], [160.0, 300], [120.0, 150]] # km/h → créditos
const TRIAL_ROAD := "Ruta Panorámica 70"
const TRIAL_START_S := 40.0
const TRIAL_END_BACK := 60.0 # la llegada está a esta distancia del final de la ruta
const TRIAL_PAR := {"gold": 235.0, "silver": 275.0, "bronze": 330.0} # segundos (4,5 km)
const TRIAL_PAY := {1: 400, 2: 900, 3: 1800}
const DELIVERY_KINDS := ["fuel", "shop", "parking", "toll", "drift"]
const DELIVERY_RADIUS := 6.0

## Punto y rumbo de una calle a s metros de su inicio: {pos: Vector2, dir: Vector2, y, hw, sw}; vacío si no existe la calle
static func road_point(layout: RefCounted, road_name: String, s: float) -> Dictionary:
	var ri: int = layout.road_named(road_name)
	if ri < 0:
		return {}
	var rd: Dictionary = layout.roads[ri]
	var cum: PackedFloat32Array = rd["cum"]
	var pts: PackedVector3Array = rd["pts"]
	var ss := clampf(s, 0.0, float(cum[cum.size() - 1]))
	var i := 0
	while i < cum.size() - 2 and float(cum[i + 1]) < ss:
		i += 1
	var t := clampf((ss - float(cum[i])) / maxf(float(cum[i + 1]) - float(cum[i]), 0.001), 0.0, 1.0)
	var a := pts[i]
	var b := pts[i + 1]
	var p := a.lerp(b, t)
	var d := Vector2(b.x - a.x, b.z - a.z).normalized()
	return {"pos": Vector2(p.x, p.z), "dir": d, "y": p.y, "hw": float(rd["hw"]), "sw": float(rd["sw"]), "road": ri, "len": float(cum[cum.size() - 1])}

static func traps(layout: RefCounted) -> Array:
	var out: Array = []
	for i in TRAP_SPECS.size():
		var sp: Array = TRAP_SPECS[i]
		var rp := road_point(layout, str(sp[0]), float(sp[1]))
		if rp.is_empty():
			continue
		out.append({"id": "radar_%d" % i, "name": "Radar · %s" % str(sp[0]), "pos": rp["pos"], "dir": rp["dir"], "half": float(rp["hw"]) + float(rp["sw"]), "y": rp["y"], "road": rp["road"]})
	return out

## Créditos por pasar a kmh por un radar
static func trap_reward(kmh: float) -> int:
	for t in TRAP_TIERS:
		if kmh >= float(t[0]):
			return int(t[1])
	return 0

## ¿El segmento a→b (el auto en un cuadro) cruza la línea del radar? Devuelve el sentido (+1 / −1 respecto de su rumbo) o 0
static func crossed(trap: Dictionary, a: Vector2, b: Vector2) -> int:
	var d: Vector2 = trap["dir"]
	var c: Vector2 = trap["pos"]
	var sa := (a - c).dot(d)
	var sb := (b - c).dot(d)
	if sa * sb > 0.0 or is_equal_approx(sa, sb):
		return 0
	var t := sa / (sa - sb)
	var q := a.lerp(b, t)
	var lat := absf((q - c).dot(Vector2(-d.y, d.x)))
	if lat > float(trap["half"]) + 1.0:
		return 0
	return 1 if sb > sa else -1

static func trial(layout: RefCounted) -> Dictionary:
	var a := road_point(layout, TRIAL_ROAD, TRIAL_START_S)
	if a.is_empty():
		return {}
	var total: float = a["len"]
	var b := road_point(layout, TRIAL_ROAD, total - TRIAL_END_BACK)
	return {"road": a["road"], "start": a["pos"], "start_dir": a["dir"], "finish": b["pos"], "finish_dir": b["dir"], "half": float(a["hw"]) + float(a["sw"]), "length": total - TRIAL_END_BACK - TRIAL_START_S}

## Medalla por tiempo: 3 oro · 2 plata · 1 bronce · 0 nada
static func medal(t: float) -> int:
	if t <= float(TRIAL_PAR["gold"]):
		return 3
	if t <= float(TRIAL_PAR["silver"]):
		return 2
	if t <= float(TRIAL_PAR["bronze"]):
		return 1
	return 0

## Premio de una vuelta: sólo si mejora la medalla (se cobra la diferencia) o es la primera vez
static func trial_reward(new_medal: int, old_medal: int) -> int:
	var pay := 0
	for m in range(old_medal + 1, new_medal + 1):
		pay += int(TRIAL_PAY.get(m, 0))
	return pay

## Lugares donde se puede recoger o entregar un encargo (los de la ciudad con una calle de frente), en orden estable
static func delivery_sites(layout: RefCounted) -> Array:
	var out: Array = []
	for p in layout.pois:
		if DELIVERY_KINDS.has(str(p["kind"])) and p.has("front"):
			out.append({"name": str(p["name"]), "pos": p["front"] as Vector2, "id": str(p["id"])})
	return out

## El encargo número seq del día del mundo day: {from, to (índices en delivery_sites), dist, deadline (s), pay}
static func delivery_offer(world_seed: int, day: int, seq: int, sites: Array) -> Dictionary:
	if sites.size() < 2:
		return {}
	var n := sites.size()
	var a := WorldSeed.range_i(world_seed, 0, n - 1, 5151, day, seq)
	var best := -1
	var tries := 0
	while tries < 12:
		var b := WorldSeed.range_i(world_seed, 0, n - 1, 5152 + tries, day, seq)
		var d := (sites[a]["pos"] as Vector2).distance_to(sites[b]["pos"])
		if b != a and d > 350.0 and d < 1800.0:
			best = b
			break
		tries += 1
	if best < 0:
		best = (a + 1) % n
	var dist := (sites[a]["pos"] as Vector2).distance_to(sites[best]["pos"])
	return {"from": a, "to": best, "dist": dist, "deadline": dist * 1.45 / 11.0 + 45.0, "pay": 150 + int(dist * 0.35)}

## Pago de un encargo entregado en `elapsed` segundos: rápido (< 70 % del límite) +30 %; en tiempo, completo; hasta 1,5× el límite, la mitad; después, nada
static func delivery_pay(offer: Dictionary, elapsed: float) -> int:
	var dl := float(offer["deadline"])
	var pay := int(offer["pay"])
	if elapsed <= dl * 0.7:
		return int(round(float(pay) * 1.3))
	if elapsed <= dl:
		return pay
	if elapsed <= dl * 1.5:
		return int(round(float(pay) * 0.5))
	return 0
