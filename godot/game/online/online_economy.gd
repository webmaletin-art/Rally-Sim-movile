extends RefCounted
## Cliente de la economía online. El dinero y los autos online viven en el SERVIDOR (supabase/migrations/20261007010000_online_economy.sql): acá sólo se piden acciones
## y se guarda el resultado que devuelve. Nada de esto toca el perfil offline (el progreso offline y el online están separados).
## Cada auto online es una INSTANCIA con su id (uuid): mejoras, gomas, pintura y piezas son de esa instancia.

var online: Node
var credits := 0
var vehicles: Array = [] # lo que devuelve online_state: [{instance, vehicle, upg, tires, tiresOwned, tireWear, paint, partsOwned, mods, km, status}]
var ready := false
var last_error := ""
var nick := "Piloto"
var anchor := Vector2.ZERO # dónde estaba el jugador al entrar a un local (el servidor comprueba que esté en el local para cobrar un trabajo)
var has_anchor := false

func _init(p_online: Node) -> void:
	online = p_online

## Pide el estado completo (billetera y autos). Devuelve false si no hubo conexión.
func sync(p_nick: String) -> bool:
	nick = p_nick
	var r: Dictionary = await online.call_fn("online_state", {"p_name": nick})
	if not r["ok"] or not (r["data"] is Dictionary):
		last_error = str(r["error"])
		return false
	var d: Dictionary = r["data"]
	credits = int(d.get("credits", 0))
	vehicles = d.get("vehicles", []) as Array
	ready = true
	return true

## Regalo diario del servidor (una vez cada 20 horas). Devuelve {ok, gift, text}
func daily() -> Dictionary:
	var r: Dictionary = await online.call_fn("online_daily", {})
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not r["ok"]:
		return {"ok": false, "text": "No se pudo cobrar. Probá de nuevo."}
	if not bool(d.get("ok", false)):
		return {"ok": false, "text": str(d.get("reason", "ya cobraste el regalo de hoy"))}
	credits = int(d.get("credits", credits))
	return {"ok": true, "gift": int(d.get("gift", 0)), "text": ""}

## Avisa dónde está el jugador (la posición de la puerta del local) para que el servidor acepte el trabajo de taller.
func beat_at_shop() -> void:
	if not has_anchor:
		return
	await online.call_fn("presence_beat", {"p_x": anchor.x, "p_z": anchor.y, "p_speed": 0.0, "p_car": "", "p_name": nick, "p_instance": null})

## Llama a una acción del servidor. Devuelve {ok, text, data}; si vino un auto o un saldo, los guarda.
func act(fn: String, args: Dictionary, at_shop := true) -> Dictionary:
	if at_shop:
		await beat_at_shop()
	var r: Dictionary = await online.call_fn(fn, args)
	if not r["ok"]:
		last_error = str(r["error"])
		return {"ok": false, "text": last_error, "data": {}}
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if d.has("ok") and not bool(d["ok"]):
		return {"ok": false, "text": str(d.get("reason", "no se pudo")), "data": d}
	if d.has("credits"):
		credits = int(d["credits"])
	if d.get("vehicle") is Dictionary:
		put(d["vehicle"])
	return {"ok": true, "text": "", "data": d}

## Guarda (o reemplaza) un auto con lo que mandó el servidor
func put(v: Dictionary) -> void:
	for i in vehicles.size():
		if str((vehicles[i] as Dictionary).get("instance", "")) == str(v.get("instance", "")):
			vehicles[i] = v
			return
	vehicles.append(v)

func find(instance: String) -> Dictionary:
	for v in vehicles:
		if str((v as Dictionary).get("instance", "")) == instance:
			return v
	return {}

func report_drive(instance: String, km: float, seconds: float, stress: float) -> void:
	if instance == "" or km < 0.05:
		return
	var r: Dictionary = await act("online_report_drive", {"p_instance": instance, "p_km": km, "p_seconds": seconds, "p_stress": stress}, false)
	if not bool(r["ok"]):
		last_error = str(r["text"])
