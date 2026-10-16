extends RefCounted
## Récords por CLASE (auditoría del ciclo de juego, fase 3 «competencia justa», 16/10/2026). Reglas puras (sin red): las usa game/online/online.gd y las prueba
## tests/class_records_test.gd. Servidor: supabase/migrations/20261023000000_class_records.sql.
##  · meta(): lo que acompaña a cada marca: PI con mejoras y gomas, clase (D…X), nivel de ayudas (arcade / intermedio / simulador / personalizado / aventura),
##    gomas y un resumen corto de las mejoras. La clase la vuelve a calcular el servidor con el PI.
##  · Cola sin conexión: si no hay red (o el servidor está ocupado) la marca queda guardada en el perfil (d.recQueue) y se manda después; por pista, tabla y
##    clase se guarda sólo la mejor; tope QUEUE_MAX (se va la más vieja). Una marca que el servidor rechaza por imposible no se reintenta.

const CarBuild := preload("res://game/data/car_build.gd")

const QUEUE_MAX := 30
const SIMS := ["arcade", "mid", "pro", "custom", "adv"]
const HIGHER := ["drift", "fugitive"] # tablas donde más es mejor
## código corto de cada mejora para el resumen («E3 T2 S1»)
const UPG_CODE := {"engine": "E", "turbo": "T", "weight": "W", "brakes": "B", "suspension": "S", "gearbox": "G", "diff": "D", "aero": "A", "nitro": "N", "stance": "P"}

static func cls_of(pi: int) -> String:
	if pi >= 800:
		return "X"
	if pi >= 700:
		return "S"
	if pi >= 600:
		return "A"
	if pi >= 500:
		return "B"
	if pi >= 400:
		return "C"
	return "D"

static func upg_summary(state: Dictionary) -> String:
	var u: Variant = state.get("upg", {})
	if not (u is Dictionary):
		return ""
	var parts: Array = []
	for k in UPG_CODE:
		var lv := int((u as Dictionary).get(k, 0))
		if lv > 0:
			parts.append("%s%d" % [UPG_CODE[k], lv])
	return " ".join(parts).left(40)

## vehicle = parámetros del auto (Race.vehicles[id] / Menu.vehicles[id]); state = perfil del auto (mejoras, gomas, reglajes)
static func meta(vehicle: Dictionary, state: Dictionary, sim: String) -> Dictionary:
	var pi := 100
	if not vehicle.is_empty():
		pi = int(CarBuild.perf_of(CarBuild.build_params(vehicle, state))["pi"])
	pi = clampi(pi, 100, 999)
	return {"pi": pi, "cls": cls_of(pi), "sim": sim if SIMS.has(sim) else "", "tires": str(state.get("tires", "street")).left(16), "upg": upg_summary(state)}

static func better(board: String, a: float, b: float) -> bool:
	return a > b if HIGHER.has(board) else a < b

static func queue_key(e: Dictionary) -> String:
	return "%s|%s|%s" % [str(e.get("board", "")), str(e.get("track", "")), str(e.get("cls", ""))]

## Guarda una marca para mandarla cuando haya conexión (d = profile.d). Devuelve true si quedó en la cola.
static func enqueue(d: Dictionary, e: Dictionary) -> bool:
	if not (d.get("recQueue") is Array):
		d["recQueue"] = []
	var q: Array = d["recQueue"]
	var k := queue_key(e)
	for i in q.size():
		if queue_key(q[i]) == k:
			if better(str(e["board"]), float(e["value"]), float(q[i]["value"])):
				q[i] = e
				return true
			return false
	q.append(e)
	while q.size() > QUEUE_MAX:
		q.pop_front()
	return true

## Qué hacer con una marca según la respuesta del servidor: "done" (guardada o rechazada para siempre), "retry" (sin red, ocupado), "legacy" (el servidor
## todavía no tiene la migración: se manda a la tabla vieja)
static func outcome(res: Dictionary) -> String:
	if bool(res.get("ok", false)):
		return "done"
	var code := int(res.get("code", 0))
	var data: Variant = res.get("data")
	var pg := str((data as Dictionary).get("code", "")) if data is Dictionary else ""
	if code == 404 or pg == "PGRST202":
		return "legacy"
	if code == 0 or code == 429 or code >= 500:
		return "retry"
	return "done" # 4xx: imposible, tabla inválida, sin cuenta… no se insiste

## El texto del puesto para mostrar al terminar: «Clase B · 3.º de 41»
static func rank_text(data: Dictionary) -> String:
	var rk := int(data.get("rank", 0))
	if rk <= 0:
		return ""
	var of := int(data.get("of", 0))
	var c := str(data.get("cls", ""))
	return ("Clase %s · " % c if c != "" else "") + ("%d.º de %d" % [rk, of] if of > 0 else "%d.º" % rk)
