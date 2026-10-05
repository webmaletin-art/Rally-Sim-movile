## Prueba del cliente online contra un servidor de mentira que imita Supabase (tools/online/mock_supabase.py): cuenta, renovación,
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
	check(not on.enabled() and not await on.sign_in(), "sin cuenta el modo online no anda (no entra como anónimo)")
	var made: Dictionary = await on.create_account("ana@correo.com", "clave-larga-1")
	check(made["ok"] and on.is_account() and on.enabled() and on.uid != "" and on.token != "", "con la cuenta creada y participación activada queda habilitado")
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
	await _account_tests(on)
	OS.kill(pid)
	OS.kill(pid2)
	quit(1 if fail else 0)

var pid2 := -1

## Cuenta con correo: se le suma al usuario anónimo (mismas marcas), inicio de sesión desde otro «teléfono», errores y cierre de sesión
func _account_tests(on: Node) -> void:
	check(Online.origin_of("https://abc.supabase.co/rest/v1/") == "https://abc.supabase.co" and Online.origin_of(" https://abc.supabase.co/ ") == "https://abc.supabase.co" and Online.origin_of("http://127.0.0.1:8000") == "http://127.0.0.1:8000", "la dirección de Supabase se deja sin camino (evita «Invalid path specified in request URL»)")
	check(Online.valid_email("ana@correo.com") and not Online.valid_email("ana@correo") and not Online.valid_email("ana correo@x.com") and not Online.valid_email("@x.com"), "valida los correos")
	check(Online.valid_password("12345678") and not Online.valid_password("1234567"), "la contraseña pide 8 caracteres")
	check("ya tiene una cuenta" in Online.friendly_error("User already registered") and "incorrectos" in Online.friendly_error("Invalid login credentials"), "traduce los errores del servidor")
	var anon_uid: String = on.uid # (el usuario de la cuenta creada arriba)
	check(on.is_account(), "arranca con la cuenta creada")
	var bad: Dictionary = await on.create_account("ana@correo", "12345678")
	check(not bad["ok"], "no crea una cuenta con un correo inválido")
	var short: Dictionary = await on.create_account("ana@correo.com", "123")
	check(not short["ok"], "no crea una cuenta con una contraseña corta")
	check(on.email == "ana@correo.com", "la cuenta guarda el correo en minúsculas")
	var dup: Dictionary = await on.create_account("ana@correo.com", "otra-clave-1")
	check(not dup["ok"], "no deja repetir un correo (%s)" % str(dup["text"]))
	# (el intento fallido borró la sesión: se vuelve a entrar)
	var relog: Dictionary = await on.login("ana@correo.com", "clave-larga-1")
	check(relog["ok"] and on.uid == anon_uid, "vuelve a entrar con la misma cuenta")
	# otro teléfono: sesión limpia + inicio de sesión
	on.logout()
	check(not on.is_account() and on.token == "" and on.refresh_token == "" and not FileAccess.file_exists(Online.SESSION_PATH), "cerrar sesión borra todo lo guardado")
	var wrong: Dictionary = await on.login("ana@correo.com", "mala")
	check(not wrong["ok"] and "incorrectos" in str(wrong["text"]), "contraseña equivocada: %s" % str(wrong["text"]))
	var li: Dictionary = await on.login("ana@correo.com", "clave-larga-1")
	check(li["ok"] and on.is_account() and on.uid == anon_uid, "inicia sesión y vuelve a ser el mismo usuario")
	var lb: Dictionary = await on.leaderboard("dream", "race", 10)
	check(lb["ok"] and lb["data"][0]["is_me"] == true, "con la cuenta sigue viendo sus marcas")
	var rc: Dictionary = await on.recover("ana@correo.com")
	check(rc["ok"], "pide cambiar la contraseña")
	# borrar la cuenta: se van la cuenta y las marcas; el correo se puede volver a usar y la sesión vieja ya no sirve
	var del_uid: String = on.uid
	var del: Dictionary = await on.delete_account()
	check(del["ok"] and not on.is_account() and on.token == "" and on.uid == "", "borra la cuenta y cierra la sesión")
	var gone: Dictionary = await on.login("ana@correo.com", "clave-larga-1")
	check(not gone["ok"], "después de borrarla ya no se puede entrar (%s)" % str(gone["text"]))
	check(not await on.sign_in() and not on.is_account(), "sin cuenta no hay sesión (no vuelve a entrar como anónimo)")
	var c2: Dictionary = await on.create_account("ana@correo.com", "clave-larga-1")
	check(c2["ok"] and on.uid != del_uid, "el mismo correo se puede volver a usar, como usuario nuevo (%s)" % str(c2["text"]))
	var lb2: Dictionary = await on.leaderboard("dream", "race", 10)
	check(lb2["ok"] and (lb2["data"] as Array).is_empty(), "sus marcas ya no están en el ranking")
	# después de reiniciar el juego la cuenta sigue
	var again := Online.new()
	again.profile = on.profile
	root.add_child(again)
	await process_frame
	check(again.is_account() and again.email == "ana@correo.com", "al reabrir el juego sigue con la cuenta")
	again.url = "http://127.0.0.1:54330"
	again.anon_key = KEY
	# cuenta nueva sin usuario anónimo previo (registro al primer inicio)
	again.logout()
	var fresh: Dictionary = await again.create_account("beto@correo.com", "clave-larga-2")
	check(fresh["ok"] and again.is_account() and again.uid != "" and again.uid != anon_uid, "crea una cuenta nueva desde cero (%s)" % str(fresh["text"]))
	# servidor que pide confirmar el correo
	pid2 = OS.create_process("python3", [ProjectSettings.globalize_path("res://").path_join("../tools/online/mock_supabase.py"), "54331", "--confirm"])
	OS.delay_msec(900)
	var cf := Online.new()
	cf.profile = on.profile
	root.add_child(cf)
	await process_frame
	cf.url = "http://127.0.0.1:54331"
	cf.anon_key = KEY
	cf.logout()
	var cc: Dictionary = await cf.create_account("carla@correo.com", "clave-larga-3")
	check(cc["ok"] and cc["confirm"] == true and not cf.is_account() and "confirmar" in str(cc["text"]), "pide confirmar el correo y todavía no queda como cuenta (%s)" % str(cc["text"]))
