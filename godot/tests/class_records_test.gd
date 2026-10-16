## Récords por clase (fase 3, game/online/class_records.gd + online.gd): la marca lleva PI/clase/ayudas/gomas/mejoras; sin red queda en la cola (la mejor por
## pista, tabla y clase) y sale después; sin la migración del servidor va a la tabla vieja; un rechazo por imposible no se reintenta; el texto del puesto.
## Sin red de verdad: el «servidor» es un doble que contesta lo que la prueba le pide.
## Uso: godot --headless --path godot --script res://tests/class_records_test.gd
extends SceneTree

const ClassRecords := preload("res://game/online/class_records.gd")
const Profile := preload("res://game/data/profile.gd")
const MenuScript := preload("res://game/ui/menu.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## doble del servidor: mismas funciones que online.gd, sin red
func _fake_online() -> Node:
	var g := GDScript.new()
	g.source_code = """extends "res://game/online/online.gd"
var replies: Array = []
var calls: Array = []
func enabled() -> bool:
	return true
func call_fn(fn: String, args: Dictionary, _need := true) -> Dictionary:
	calls.append([fn, args])
	await get_tree().process_frame
	if replies.is_empty():
		return {"ok": true, "code": 200, "data": {"saved": true, "rank": 1, "of": 1, "cls": "C"}, "error": ""}
	return replies.pop_front()
"""
	g.reload()
	var o: Node = g.new()
	root.add_child(o)
	return o

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var veh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	# 1) lo que acompaña a la marca
	var st := Profile.new_car_state("hatch")
	var m0 := ClassRecords.meta(veh["hatch"], st, "arcade")
	_check(int(m0["pi"]) >= 100 and str(m0["cls"]) == ClassRecords.cls_of(int(m0["pi"])) and str(m0["sim"]) == "arcade" and str(m0["tires"]) == "street",
		"R2 Turbo de serie: PI %d, clase %s, arcade, gomas de calle" % [int(m0["pi"]), str(m0["cls"])])
	st["upg"] = {"engine": 3, "turbo": 2, "suspension": 1}
	st["tires"] = "sport"
	var m1 := ClassRecords.meta(veh["hatch"], st, "pro")
	_check(int(m1["pi"]) > int(m0["pi"]) and str(m1["upg"]) == "E3 T2 S1" and str(m1["tires"]) == "sport", "con mejoras sube el PI (%d → %d) y viaja el resumen «%s»" % [int(m0["pi"]), int(m1["pi"]), str(m1["upg"])])
	_check(str(ClassRecords.meta(veh["hatch"], st, "trampa")["sim"]) == "", "un nivel de ayudas desconocido no se manda")
	var mg := ClassRecords.meta(veh["genesis"], Profile.new_car_state("genesis"), "mid")
	_check(["S", "X"].has(str(mg["cls"])), "el Bisonte XR cae en S/X (%s, PI %d): no compite con el R2" % [str(mg["cls"]), int(mg["pi"])])
	_check(ClassRecords.cls_of(399) == "D" and ClassRecords.cls_of(400) == "C" and ClassRecords.cls_of(800) == "X", "cortes de clase iguales al catálogo y al servidor")
	# 2) cola sin conexión
	var d := {}
	ClassRecords.enqueue(d, {"board": "race", "track": "lake", "cls": "C", "value": 120.0})
	_check(not ClassRecords.enqueue(d, {"board": "race", "track": "lake", "cls": "C", "value": 125.0}), "un tiempo peor de la misma pista y clase no entra a la cola")
	ClassRecords.enqueue(d, {"board": "race", "track": "lake", "cls": "C", "value": 118.0})
	ClassRecords.enqueue(d, {"board": "race", "track": "lake", "cls": "B", "value": 110.0})
	ClassRecords.enqueue(d, {"board": "drift", "track": "drift", "cls": "C", "value": 9000.0})
	_check(not ClassRecords.enqueue(d, {"board": "drift", "track": "drift", "cls": "C", "value": 8000.0}), "en drift (más es mejor) un puntaje menor tampoco")
	_check((d["recQueue"] as Array).size() == 3 and float(d["recQueue"][0]["value"]) == 118.0, "queda la mejor por pista/tabla/clase (3 en la cola)")
	for i in 40:
		ClassRecords.enqueue(d, {"board": "owev", "track": "ev%d" % i, "cls": "C", "value": 60.0})
	_check((d["recQueue"] as Array).size() == ClassRecords.QUEUE_MAX, "la cola tiene tope (%d)" % ClassRecords.QUEUE_MAX)
	# 3) qué hacer con cada respuesta
	_check(ClassRecords.outcome({"ok": false, "code": 0}) == "retry" and ClassRecords.outcome({"ok": false, "code": 503}) == "retry", "sin red o servidor ocupado: se reintenta")
	_check(ClassRecords.outcome({"ok": false, "code": 404, "data": {"code": "PGRST202"}}) == "legacy", "sin la migración: a la tabla vieja")
	_check(ClassRecords.outcome({"ok": false, "code": 400, "data": {"message": "tiempo imposible"}}) == "done", "un tiempo imposible no se reintenta")
	# 4) el «servidor»: sin red → cola; vuelve la red → sale; sin migración → tabla vieja
	var had_file := FileAccess.file_exists(Profile.PATH) # (la cola se guarda con el perfil: no pisar el del que corre la prueba)
	var keep := FileAccess.get_file_as_string(Profile.PATH) if had_file else ""
	var p := Profile.new()
	p.d = Profile.default_profile()
	var on := _fake_online()
	on.profile = p
	on.uid = "u1"
	on.email = "a@b.cd"
	on.replies = [{"ok": false, "code": 0, "data": null, "error": "sin conexión"}]
	var e := ClassRecords.meta(veh["hatch"], Profile.new_car_state("hatch"), "mid")
	e.merge({"board": "race", "track": "lake", "value": 131.2, "car": "hatch", "laps": 2, "build": "t"})
	var r: Dictionary = await on.submit_class(e)
	_check(bool(r.get("queued", false)) and (p.d.get("recQueue", []) as Array).size() == 1, "sin red: la marca queda guardada en el perfil")
	_check(str(on.calls[0][0]) == "submit_class_record" and int(on.calls[0][1]["p_pi"]) == int(e["pi"]) and str(on.calls[0][1]["p_sim"]) == "mid", "se manda con PI y nivel de ayudas")
	on.calls.clear()
	var n: int = await on.flush_records()
	_check(n == 1 and (p.d["recQueue"] as Array).is_empty(), "al volver la red sale sola y la cola queda vacía")
	_check(bool(on.calls[0][1]["p_late"]), "y sale marcada «enviada después» (se distingue de una al momento)")
	p.d["recQueue"] = [{"board": "race", "track": "lake", "cls": "C", "value": 100.0, "uid": "otra"}]
	n = await on.flush_records()
	_check(n == 0 and (p.d["recQueue"] as Array).is_empty() and on.calls.size() == 1, "las marcas de otra cuenta no se mandan con esta")
	on.calls.clear()
	on.replies = [{"ok": false, "code": 404, "data": {"code": "PGRST202"}, "error": "no existe"}, {"ok": true, "code": 200, "data": {"saved": true, "best": 131.2, "rank": 4}, "error": ""}]
	r = await on.submit_class(e)
	_check(bool(r.get("legacy", false)) and str(on.calls[1][0]) == "submit_score" and int(r["data"]["rank"]) == 4, "servidor sin la migración: va a submit_score como antes")
	on.calls.clear()
	on.replies = [{"ok": false, "code": 404, "data": {"code": "PGRST202"}, "error": ""}, {"ok": true, "code": 200, "data": {"saved": true, "rank": 1}, "error": ""}]
	var eo := e.duplicate()
	eo["board"] = "owev"
	eo["track"] = "ev7"
	r = await on.submit_class(eo)
	_check(str(on.calls[1][0]) == "submit_record" and str(on.calls[1][1]["p_id"]) == "ev7", "y una carrera del mapa, a submit_record")
	if had_file:
		var fk := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		fk.store_string(keep)
		fk.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.PATH))
	# 5) el texto al terminar la carrera
	var t1 := MenuScript.world_text({"cls": "B", "pi": 523, "rank": 3, "of": 41, "saved": true})
	_check(t1.contains("Clase B") and t1.contains("PI 523") and t1.contains("3.º de 41"), "resultado: «%s»" % t1)
	_check(MenuScript.world_text({"cls": "C", "pi": 420, "rank": 1, "of": 7, "saved": true}).contains("RÉCORD DE LA CLASE"), "primero de la clase: récord")
	_check(MenuScript.world_text({"cls": "C", "queued": true}).contains("Sin conexión"), "sin red lo dice y promete mandarla")
	_check(MenuScript.world_text({"wait": true}) == "" and MenuScript.world_text({"fail": true}) == "", "mientras espera o si falló no muestra nada raro")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
