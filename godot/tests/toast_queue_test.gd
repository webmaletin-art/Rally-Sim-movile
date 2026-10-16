## Cola de avisos del HUD (game/ui/toast_queue.gd): ya no se pisan antes de leerlos, la policía tiene prioridad, iguales no se repiten.
## Uso: godot --headless --path godot --script res://tests/toast_queue_test.gd
extends SceneTree

const ToastQueue := preload("res://game/ui/toast_queue.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var q := ToastQueue.new()
	_check(q.push("📍 GPS: Plaza", ""), "el primer aviso se muestra enseguida")
	_check(not q.push("+ $500", "up"), "uno nuevo apenas después no lo pisa (espera)")
	_check(str(q.cur["text"]) == "📍 GPS: Plaza" and q.waiting.size() == 1, "sigue el primero en pantalla y el segundo espera")
	q.step(ToastQueue.SHOW_BUSY + 0.01)
	_check(str(q.cur.get("text", "")) == "+ $500", "al terminar el primero sale el que esperaba")
	q.step(ToastQueue.MIN_SHOW + 0.01)
	_check(q.push("🚨 ¡Te persiguen!", "down"), "la policía corta a un aviso menos importante que ya se vio un rato")
	_check(not q.push("🚨 ¡Te persiguen!", "down"), "el mismo aviso repetido no se encola")
	for i in 8:
		q.push("info %d" % i, "")
	_check(q.waiting.size() <= ToastQueue.MAX_WAIT, "la pila de espera tiene tope (%d)" % q.waiting.size())
	q.push("🏆 ¡Ganaste!", "up")
	_check(str(q.waiting[0]["text"]) == "🏆 ¡Ganaste!", "entre los que esperan, el premio va antes que la información")
	var shown := 0
	for i in 40:
		if not q.step(0.5).is_empty():
			shown += 1
	_check(q.cur.is_empty() and q.waiting.is_empty(), "con el tiempo se muestran todos y la pantalla queda limpia (%d más)" % shown)
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
