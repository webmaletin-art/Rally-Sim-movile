extends Node
## Cliente del modo online (Supabase). Habla con la API REST de Supabase por HTTPS. El modo online REQUIERE una cuenta con correo (el resto del juego anda sin conexión
## y sin cuenta): con la cuenta se mandan las mejores marcas y se traen los rankings. Solo usa la clave PÚBLICA (anon); la seguridad está en la base (supabase/migrations: RLS y funciones).
##
## La dirección y la clave pública se escriben en game/online/online_config.json al compilar (workflows, a partir de los secretos
## SUPABASE_URL y SUPABASE_ANON_KEY). Sin eso, o con «Rankings online» apagado en Opciones, no se conecta a nada.
## Todas las llamadas son «await» y devuelven {ok, code, data, error}.

const CONFIG_PATH := "res://game/online/online_config.json"
const Release := preload("res://game/data/release.gd")
const ClassRecords := preload("res://game/online/class_records.gd")
const SESSION_PATH := "user://online.json"

var url := ""
var anon_key := ""
var profile: RefCounted # para el nombre y la opción «Rankings online»
var token := ""
var refresh_token := ""
var uid := ""
var expires_at := 0 # segundos unix
var email := "" # correo de la cuenta ("" = sin cuenta: el modo online no anda)
var last_error := ""

func _ready() -> void:
	load_config()
	_load_session()

## Lee la dirección y la clave pública. Devuelve true si hay datos
func load_config() -> bool:
	url = ""
	anon_key = ""
	if FileAccess.file_exists(CONFIG_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if d is Dictionary:
			url = origin_of(str((d as Dictionary).get("url", "")))
			anon_key = str((d as Dictionary).get("anon_key", "")).strip_edges()
	return configured()

## Sólo «https://proyecto.supabase.co»: si al cargar el secreto se pegó la dirección con un camino (por ejemplo «/rest/v1/»), el servidor contesta «Invalid path specified in request URL»
static func origin_of(u: String) -> String:
	u = u.strip_edges()
	var i := u.find("://")
	if i < 0:
		return u.rstrip("/")
	var j := u.find("/", i + 3)
	return u if j < 0 else u.substr(0, j)

func configured() -> bool:
	return (url.begins_with("https://") or url.begins_with("http://127.0.0.1")) and anon_key.length() > 20 # http solo para el servidor de prueba local

## ¿Se puede usar? (hay configuración, el jugador tiene cuenta y aceptó participar en los rankings)
func enabled() -> bool:
	return configured() and is_account() and profile != null and profile.setting("onlineScores") == true

# ───────────────────────── armado de pedidos (puro, sin red: se prueba aparte) ─────────────────────────
static func headers(key: String, bearer: String) -> PackedStringArray:
	return PackedStringArray(["apikey: " + key, "Authorization: Bearer " + (bearer if bearer != "" else key), "Content-Type: application/json", "Accept: application/json"])

## Carga para submit_score (la función de la base valida todo de nuevo)
static func score_payload(track: String, board: String, value: float, car: String, laps: int, build: String, name: String) -> Dictionary:
	return {"p_track": track, "p_board": board, "p_value": snappedf(value, 0.001), "p_car": car, "p_laps": laps, "p_build": build, "p_name": name}

## Qué tabla corresponde al resultado de una carrera (o "" si no entra a ningún ranking)
static func board_for(result_type: String, cfg: Dictionary) -> String:
	if cfg.get("testCar", false) == true or cfg.get("practice", false) == true or cfg.get("labbed", false) == true or str(cfg.get("type", "")) == "net":
		return "" # (la Red de rutas no tiene ranking)
	if result_type == "drift":
		return "drift" if cfg.get("duel", false) != true else ""
	if cfg.get("drag", false) == true:
		return "drag"
	if result_type == "timetrial":
		return "timetrial"
	if result_type == "race":
		return "race"
	return ""

static func parse_session(d: Dictionary) -> Dictionary:
	var user: Dictionary = d.get("user", {}) if d.get("user", {}) is Dictionary else {}
	return {"token": str(d.get("access_token", "")), "refresh": str(d.get("refresh_token", "")), "uid": str(user.get("id", "")),
		"email": str(user.get("email", "")), "expires_at": int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600)) - 60}

# ───────────────────────── red ─────────────────────────
func request(method: int, path: String, body: Variant = null, bearer := "") -> Dictionary:
	if not configured():
		return {"ok": false, "code": 0, "data": null, "error": "sin configurar"}
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(url + path, headers(anon_key, bearer), method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "no se pudo mandar el pedido (%d)" % err}
	var res: Array = await http.request_completed
	http.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	var ok := int(res[0]) == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	var msg := ""
	if not ok:
		msg = str((data as Dictionary).get("message", (data as Dictionary).get("msg", (data as Dictionary).get("error_description", "")))) if data is Dictionary else ""
		if msg == "":
			msg = "sin conexión" if int(res[0]) != HTTPRequest.RESULT_SUCCESS else "error %d" % code
		last_error = msg
	return {"ok": ok, "code": code, "data": data, "error": msg}

## Reusa la sesión de la cuenta y la renueva si venció. Sin cuenta (sin sesión guardada) no entra: el modo online necesita iniciar sesión o crear la cuenta.
func sign_in() -> bool:
	var now := int(Time.get_unix_time_from_system())
	if token != "" and expires_at > now:
		return true
	if refresh_token != "":
		var r := await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})
		if r["ok"] and r["data"] is Dictionary:
			_set_session(parse_session(r["data"] as Dictionary))
			return token != ""
		var code := int(r.get("code", 0))
		if code >= 400 and code < 500 and code != 429:
			# el servidor dijo que esa sesión ya no sirve (se cambió la contraseña, se cerró la sesión en otro teléfono, la cuenta se borró): hay que volver a iniciar sesión
			_clear_session()
			last_error = "sesión vencida"
		return false
	last_error = "sin sesión"
	return false

func _set_session(s: Dictionary) -> void:
	token = str(s["token"])
	refresh_token = str(s["refresh"])
	uid = str(s["uid"])
	expires_at = int(s["expires_at"])
	email = str(s.get("email", ""))
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"refresh": refresh_token, "uid": uid, "email": email}))

func _load_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
		if d is Dictionary:
			refresh_token = str((d as Dictionary).get("refresh", ""))
			uid = str((d as Dictionary).get("uid", ""))
			email = str((d as Dictionary).get("email", ""))
	if email == "" and refresh_token != "":
		# una sesión anónima de una versión anterior: ya no sirve (el modo online pide cuenta)
		refresh_token = ""
		uid = ""
		if FileAccess.file_exists(SESSION_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

## Llama a una función de la base (RPC) con sesión
func call_fn(fn: String, args: Dictionary, need_session := true) -> Dictionary:
	if need_session and not await sign_in():
		return {"ok": false, "code": 0, "data": null, "error": last_error if last_error != "" else "sin sesión"}
	return await request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, token if need_session else "")

## Llama a una función de borde de Supabase (supabase/functions/<nombre>, por ejemplo «verify-purchase»: verifica el recibo de Google Play y acredita la compra) con la sesión de la cuenta
func call_edge(fn: String, args: Dictionary) -> Dictionary:
	if not await sign_in():
		return {"ok": false, "code": 0, "data": null, "error": last_error if last_error != "" else "sin sesión"}
	return await request(HTTPClient.METHOD_POST, "/functions/v1/" + fn, args, token)

# ───────────────────────── cuenta con correo ─────────────────────────
## Para jugar online hace falta una cuenta con correo y contraseña; en otro teléfono se vuelve a entrar con «iniciar sesión». El progreso del juego (autos, créditos) sigue guardado en el teléfono.
static func valid_email(e: String) -> bool:
	var parts := e.strip_edges().split("@")
	return parts.size() == 2 and parts[0].length() > 0 and parts[1].length() >= 3 and "." in parts[1] and not parts[1].begins_with(".") and not parts[1].ends_with(".") and not " " in e

static func valid_password(p: String) -> bool:
	return p.length() >= 8

## Traduce los mensajes de Supabase Auth a algo que entienda el jugador
static func friendly_error(msg: String) -> String:
	var m := msg.to_lower()
	if "already registered" in m or "already been registered" in m:
		return "Ese correo ya tiene una cuenta. Probá con «Iniciar sesión»."
	if "invalid login" in m:
		return "Correo o contraseña incorrectos."
	if "not confirmed" in m:
		return "Falta confirmar el correo: abrí el mensaje que te mandamos y tocá el enlace."
	if "rate limit" in m or "too many" in m or ("after" in m and "seconds" in m):
		return "Hiciste muchos intentos seguidos. Esperá unos minutos y probá de nuevo."
	if "password" in m and ("least" in m or "weak" in m or "short" in m):
		return "La contraseña es muy corta o débil (mínimo 8 caracteres)."
	if "valid email" in m or "invalid email" in m or "unable to validate email" in m:
		return "Ese correo no parece válido."
	if "anonymous" in m and "disabled" in m:
		return "El servidor no permite entrar sin cuenta todavía."
	if "signup" in m and ("disabled" in m or "not allowed" in m) or "provider" in m and "disabled" in m:
		return "El servidor todavía no acepta cuentas con correo."
	if "not authorized" in m or "error sending" in m or "smtp" in m:
		return "El servidor todavía no puede mandar el correo de confirmación."
	if msg == "sin conexión":
		return "Sin conexión a internet."
	return GENERIC_ERROR

const GENERIC_ERROR := "No se pudo completar. Probá de nuevo en un rato."

## Resultado de un error: el texto amable y, si no se supo explicar, el mensaje del servidor (corto) para poder averiguar qué pasó
static func error_result(raw: String, extra := {}) -> Dictionary:
	var out: Dictionary = {"ok": false, "text": friendly_error(raw)}
	if out["text"] == GENERIC_ERROR:
		out["detail"] = raw.substr(0, 90)
	out.merge(extra)
	return out

func is_account() -> bool:
	return email != ""

## Crea la cuenta (usuario nuevo con correo y contraseña). Devuelve {ok, text, confirm}.
## confirm = true si el servidor pide confirmar el correo antes de usarla. «text» es la clave en español para traducir (con «arg» si lleva %s).
func create_account(mail: String, pw: String) -> Dictionary:
	mail = mail.strip_edges().to_lower()
	if not configured():
		return {"ok": false, "text": "Esta versión no tiene el modo online configurado.", "confirm": false}
	if not valid_email(mail):
		return {"ok": false, "text": "Ese correo no parece válido.", "confirm": false}
	if not valid_password(pw):
		return {"ok": false, "text": "La contraseña tiene que tener al menos 8 caracteres.", "confirm": false}
	_clear_session() # (si quedara una sesión vieja, no se mezcla con la cuenta nueva)
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": mail, "password": pw})
	if r["ok"] and r["data"] is Dictionary and str((r["data"] as Dictionary).get("access_token", "")) != "":
		_set_session(parse_session(r["data"] as Dictionary))
	if not r["ok"]:
		return error_result(str(r["error"]), {"confirm": false})
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	var user: Dictionary = d.get("user", d) if d.get("user", d) is Dictionary else {}
	var confirmed := str(user.get("email", "")) == mail and (user.get("email_confirmed_at") != null or user.get("confirmed_at") != null)
	if confirmed:
		email = mail
		_set_session({"token": token, "refresh": refresh_token, "uid": uid, "email": mail, "expires_at": expires_at})
		return {"ok": true, "text": "¡Cuenta creada! Ya podés entrar con este correo desde cualquier teléfono.", "confirm": false}
	return {"ok": true, "text": "Te mandamos un mensaje a %s. Tocá el enlace para confirmar la cuenta y después volvé al juego.", "arg": mail, "confirm": true}

## Entra con una cuenta existente
func login(mail: String, pw: String) -> Dictionary:
	mail = mail.strip_edges().to_lower()
	if not configured():
		return {"ok": false, "text": "Esta versión no tiene el modo online configurado."}
	if not valid_email(mail) or pw == "":
		return {"ok": false, "text": "Escribí tu correo y tu contraseña."}
	var r := await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": pw})
	if not r["ok"] or not (r["data"] is Dictionary):
		return error_result(str(r["error"]))
	var s := parse_session(r["data"] as Dictionary)
	if s["token"] == "":
		return {"ok": false, "text": "Correo o contraseña incorrectos."}
	if s["email"] == "":
		s["email"] = mail
	_set_session(s)
	return {"ok": true, "text": "¡Listo! Entraste como %s.", "arg": mail}

## Manda el mensaje para elegir una contraseña nueva
func recover(mail: String) -> Dictionary:
	mail = mail.strip_edges().to_lower()
	if not valid_email(mail):
		return {"ok": false, "text": "Escribí tu correo."}
	var r := await request(HTTPClient.METHOD_POST, "/auth/v1/recover", {"email": mail})
	if not r["ok"]:
		return error_result(str(r["error"]))
	return {"ok": true, "text": "Si ese correo tiene cuenta, te mandamos un mensaje para elegir una contraseña nueva."}

## Borra la cuenta, las marcas y todo lo que haya en el servidor (Google Play lo exige para las apps con cuentas) y cierra la sesión
func delete_account() -> Dictionary:
	if not await sign_in():
		return {"ok": false, "text": friendly_error(last_error)}
	var r := await call_fn("delete_my_account", {})
	if not r["ok"]:
		return {"ok": false, "text": friendly_error(str(r["error"]))}
	logout()
	return {"ok": true, "text": "Listo: se borraron tu cuenta y tus marcas."}

## Cierra la sesión de este teléfono (para el modo online hay que volver a iniciar sesión)
func logout() -> void:
	if token != "":
		request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, token) # no hace falta esperar la respuesta
	_clear_session()

func _clear_session() -> void:
	token = ""
	refresh_token = ""
	uid = ""
	email = ""
	expires_at = 0
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

# ───────────────────────── lo que usa el juego ─────────────────────────
## Manda una marca (si el jugador participa en los rankings). No molesta: se llama sin esperar el resultado.
func submit_score(track: String, board: String, value: float, car: String, laps: int, build: String) -> Dictionary:
	if not enabled() or board == "":
		return {"ok": false, "code": 0, "data": null, "error": "apagado"}
	var nm := str(profile.d.get("name", "Piloto"))
	return await call_fn("submit_score", score_payload(track, board, value, car, laps, build, nm))

func leaderboard(track: String, board: String, limit := 50) -> Dictionary:
	if not is_account():
		return {"ok": false, "code": 0, "data": null, "error": "sin sesión"} # los rankings también piden cuenta
	return await call_fn("get_leaderboard", {"p_track": track, "p_board": board, "p_limit": limit})

## Banderas del servidor (tabla app_flags): hoy sólo «pvp» = el mundo online en tiempo real habilitado. Sin conexión queda como estaba (apagado).
func fetch_flags() -> Dictionary:
	if not configured():
		return {}
	var r := await call_fn("app_flags", {}, false)
	if r["ok"] and r["data"] is Dictionary:
		Release.pvp_remote = bool((r["data"] as Dictionary).get("pvp", false))
		return r["data"]
	return {}

## Récord del mundo abierto: board «owev» (id del evento, segundos) o «fugitive» (id «fugitivo», racha). Devuelve {saved, best, rank, top: {name, value}}
func submit_record(board: String, id: String, value: float, car: String) -> Dictionary:
	if not is_account():
		return {"ok": false, "code": 0, "data": null, "error": "sin sesión"}
	return await call_fn("submit_record", {"p_board": board, "p_id": id, "p_value": snappedf(value, 0.01), "p_car": car, "p_name": str(profile.d.get("name", "Piloto")) if profile != null else "Piloto"})

## Marca por CLASE (fase 3, 16/10/2026): e = {board, track, value, car, pi, cls, sim, tires, upg, laps, build}. Devuelve {ok, data: {saved, best, rank, of, cls, top}}.
## Sin conexión (o con el servidor ocupado) la marca queda en la cola del perfil y se manda después (flush_records). Si el servidor todavía no tiene la migración
## 20261023000000_class_records.sql, va a la tabla vieja (sin clase) como siempre.
func submit_class(e: Dictionary) -> Dictionary:
	if not enabled():
		return {"ok": false, "code": 0, "data": null, "error": "apagado"}
	e["uid"] = uid
	var r := await _send_class(e)
	if ClassRecords.outcome(r) == "retry" and profile != null:
		ClassRecords.enqueue(profile.d, e)
		profile.save()
		r["queued"] = true
	return r

func _send_class(e: Dictionary) -> Dictionary:
	var board := str(e.get("board", ""))
	var nm := str(profile.d.get("name", "Piloto")) if profile != null else "Piloto"
	var r := await call_fn("submit_class_record", {"p_board": board, "p_track": str(e.get("track", "")), "p_value": snappedf(float(e.get("value", 0.0)), 0.001),
		"p_car": str(e.get("car", "")), "p_pi": int(e.get("pi", 100)), "p_sim": str(e.get("sim", "")), "p_tires": str(e.get("tires", "")), "p_upg": str(e.get("upg", "")),
		"p_laps": int(e.get("laps", 1)), "p_build": str(e.get("build", "")), "p_name": nm, "p_late": bool(e.get("late", false))})
	if ClassRecords.outcome(r) != "legacy":
		return r
	var v := float(e.get("value", 0.0))
	var car := str(e.get("car", ""))
	if board == "owev":
		r = await submit_record("owev", str(e.get("track", "")), v, car)
	elif board == "fugitive":
		r = await submit_record("fugitive", "fugitivo", v, car)
	else:
		r = await call_fn("submit_score", score_payload(str(e.get("track", "")), board, v, car, int(e.get("laps", 1)), str(e.get("build", "")), nm))
	r["legacy"] = true
	return r

var _flushing := false
## Manda las marcas que quedaron sin conexión (de esta cuenta). Devuelve cuántas salieron.
func flush_records() -> int:
	if _flushing or profile == null or not enabled() or not (profile.d.get("recQueue") is Array) or (profile.d["recQueue"] as Array).is_empty():
		return 0
	_flushing = true
	var q: Array = (profile.d["recQueue"] as Array).duplicate()
	var keep: Array = []
	var sent := 0
	var stop := false
	for e in q:
		if stop or str((e as Dictionary).get("uid", "")) != uid:
			if str((e as Dictionary).get("uid", "")) == uid:
				keep.append(e) # (las de otra cuenta se descartan)
			continue
		(e as Dictionary)["late"] = true # (en la tabla: «enviada después»)
		var r := await _send_class(e)
		if ClassRecords.outcome(r) == "retry":
			keep.append(e)
			stop = true # sin red: el resto espera a la próxima
		else:
			sent += 1
	profile.d["recQueue"] = keep
	profile.save()
	_flushing = false
	return sent

func class_board(track: String, board: String, cls := "", limit := 50) -> Dictionary:
	if not is_account():
		return {"ok": false, "code": 0, "data": null, "error": "sin sesión"}
	return await call_fn("get_class_leaderboard", {"p_track": track, "p_board": board, "p_cls": cls, "p_limit": limit})

## Prueba de conexión (para el modo desarrollador): entra, pide un ranking y cuenta las filas
func ping() -> Dictionary:
	if not configured():
		return {"ok": false, "text": "Falta configurar la dirección y la clave de Supabase (secretos del repositorio)."}
	if not is_account():
		return {"ok": false, "text": "Para probar la conexión iniciá sesión con tu cuenta."}
	var ok := await sign_in()
	if not ok:
		return {"ok": false, "text": "No pude entrar (%s)." % (last_error if last_error != "" else "sin respuesta")}
	var r := await call_fn("get_leaderboard", {"p_track": "dream", "p_board": "race", "p_limit": 5})
	if not r["ok"]:
		return {"ok": false, "text": "Entré, pero falló el ranking: %s. ¿Se aplicaron las migraciones?" % str(r["error"])}
	return {"ok": true, "text": "✔ Conectado a Supabase (usuario %s…, %d filas en el ranking de prueba)." % [uid.left(6), (r["data"] as Array).size() if r["data"] is Array else 0]}
