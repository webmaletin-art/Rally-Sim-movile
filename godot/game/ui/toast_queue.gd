extends RefCounted
## Cola de avisos del HUD (auditoría del ciclo de juego, 16/10/2026): antes cada aviso pisaba al anterior al instante y muchos no se llegaban a leer
## (policía + evento + premio en el mismo segundo). Ahora esperan su turno con prioridad, sin carteles gigantes ni pilas largas.
## Prioridad: «down» (policía, peligro) 3 > «up» (premio, logro) 2 > informativo 1. Un aviso nuevo de MÁS prioridad corta al que se está mostrando sólo si
## ese ya se vio un rato (MIN_SHOW); el cortado no vuelve. Iguales seguidos no se repiten. Con avisos esperando, cada uno dura SHOW_BUSY; si no, SHOW.

const SHOW := 2.2
const SHOW_BUSY := 1.7
const MIN_SHOW := 0.7
const MAX_WAIT := 4

var cur: Dictionary = {} # {text, kind, prio, t (tiempo mostrado), dur}
var waiting: Array = []

static func prio_of(kind: String) -> int:
	return 3 if kind == "down" else (2 if kind == "up" else 1)

## Devuelve true si hay que mostrarlo ya (el que llama lo pone en pantalla con show_now())
func push(text: String, kind := "") -> bool:
	if text == "":
		return false
	if not cur.is_empty() and str(cur["text"]) == text:
		cur["t"] = minf(float(cur["t"]), MIN_SHOW) # el mismo aviso otra vez: se queda un rato más
		return false
	for w in waiting:
		if str(w["text"]) == text:
			return false
	var e := {"text": text, "kind": kind, "prio": prio_of(kind), "t": 0.0, "dur": SHOW}
	if cur.is_empty():
		cur = e
		return true
	if int(e["prio"]) > int(cur["prio"]) and float(cur["t"]) >= MIN_SHOW:
		cur = e
		return true
	waiting.append(e)
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) > int(b["prio"]))
	while waiting.size() > MAX_WAIT:
		waiting.pop_back() # el de menos prioridad (y más nuevo entre iguales) se descarta
	return false

## Avanza el tiempo. Devuelve el aviso que hay que mostrar ahora ({} = ninguno nuevo; cur vacío = no mostrar nada)
func step(dt: float) -> Dictionary:
	if cur.is_empty():
		return {}
	cur["t"] = float(cur["t"]) + dt
	var dur := SHOW_BUSY if not waiting.is_empty() else SHOW
	if float(cur["t"]) < dur:
		return {}
	cur = {}
	if waiting.is_empty():
		return {}
	cur = waiting.pop_front()
	return cur

## Lo que queda por mostrar del aviso actual (para el desvanecido)
func remaining() -> float:
	if cur.is_empty():
		return 0.0
	return maxf(0.0, (SHOW_BUSY if not waiting.is_empty() else SHOW) - float(cur["t"]))

func clear() -> void:
	cur = {}
	waiting.clear()
