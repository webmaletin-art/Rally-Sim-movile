## Prueba del cliente online contra un servidor de mentira que imita Supabase (tools/online/mock_supabase.py): sesión anónima, renovación,
## envío de marcas, ranking y errores. Sin internet. Uso: godot --headless --path godot --script res://tests/online_test.gd
extends SceneTree

const Online := preload("res://game/online/online.gd")
const KEY := "test-anon-key-0123456789abcdef"
var fail := false
var pid := -1

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Stub extends RefCounted:
	var d := {"name": "Ana", "settings": {"onlineScores": true, "dev": false}}
	func setting(k: String):
		return d["settings"].get(k)

func _init() -> void:
	# lógica pura
	check(Online.board_for("race", {}) == "race" and Online.board_for("timetrial", {}) == "timetrial", "carrera y contrarreloj van a su tabla")
	check(Online.board_for("race", {"drag": true}) == "drag", "la picada va a la tabla de picadas")
	check(Online.board_for("drift", {}) == "drift" and Online.board_for("drift", {"duel": true}) == "", "drift libre sí; el duelo contra el bot no")
	check(Online.board_for("race", {"testCar": true}) == "" and Online.board_for("race", {"practice": true}) == "", "las pruebas de autos y las prácticas no cuentan")
	check(Online.board_for("parking", {}) == "", "los eventos sin ranking no se mandan")
	var h := Online.headers("K", "")
	check(h[0] == "apikey: K" and h[1] == "Authorization: Bearer K", "sin sesión se manda la clave pública")
	check(Online.headers("K", "T")[1] == "Authorization: Bearer T", "con sesión se manda el token")
	check(Online.score_payload("dream", "race", 241.23456, "gt", 1, "r1", "Ana")["p_value"] == 241.235, "el tiempo se redondea al milésimo")
	var s := Online.parse_session({"access_token": "a", "refresh_token": "r", "expires_in": 3600, "user": {"id": "u1"}})
	check(s["token"] == "a" and s["refresh"] == "r" and s["uid"] == "u1" and int(s["expires_at"]) > int(Time.get_unix_time_from_system()), "se lee la sesión")
	# contra el servidor de mentira
	var out: Array = []
	pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://").path_join("../tools/online/mock_supabase.py"), "54330"])
	OS.delay_msec(900)
	var on := Online.new()
	on.profile = Stub.new()
	root.add_child(on)
	await process_frame
	check(not on.configured() and not on.enabled(), "sin configuración no se conecta a nada")
	on.url = "http://127.0.0.1:54330"
	on.anon_key = "clave-mala-clave-mala-clave"
	var bad: Dictionary = await on.request(HTTPClient.METHOD_POST, "/auth/v1/signup", {})
	check(not bad["ok"] and bad["code"] == 401 and str(bad["error"]) != "", "una clave equivocada da error claro (%s)" % str(bad["error"]))
	on.anon_key = KEY
	check(on.enabled(), "con configuración y participación activada queda habilitado")
	check(await on.sign_in() and on.uid != "" and on.token != "", "entra con un usuario anónimo")
	var first_uid := on.uid
	on.expires_at = 0 # token vencido: se renueva con el refresh token y es el mismo usuario
	check(await on.sign_in() and on.uid == first_uid, "renueva la sesión sin cambiar de usuario")
	var r1: Dictionary = await on.submit_score("dream", "race", 250.5, "gt", 1, "r1")
	check(r1["ok"] and r1["data"]["saved"] == true, "manda una marca")
	var r2: Dictionary = await on.submit_score("dream", "race", 260.0, "gt", 1, "r1")
	check(r2["ok"] and r2["data"]["saved"] == false and r2["data"]["best"] == 250.5, "una marca peor no reemplaza a la mejor")
	var r3: Dictionary = await on.submit_score("dream", "race", 10.0, "gt", 1, "r1")
	check(not r3["ok"] and "imposible" in str(r3["error"]), "un tiempo imposible lo rechaza el servidor (%s)" % str(r3["error"]))
	var lb: Dictionary = await on.leaderboard("dream", "race", 10)
	check(lb["ok"] and (lb["data"] as Array).size() == 1 and lb["data"][0]["name"] == "Ana" and lb["data"][0]["is_me"] == true, "el ranking trae la marca con el nombre")
	var pg: Dictionary = await on.ping()
	check(pg["ok"] and "Conectado" in str(pg["text"]), "la prueba de conexión dice que anda: %s" % str(pg["text"]))
	on.profile.d["settings"]["onlineScores"] = false
	var off: Dictionary = await on.submit_score("dream", "race", 200.0, "gt", 1, "r1")
	check(not off["ok"] and off["error"] == "apagado", "con «Rankings online» apagado no manda nada")
	OS.kill(pid)
	quit(1 if fail else 0)
