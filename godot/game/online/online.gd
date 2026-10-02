extends Node
## Cliente del modo online (Supabase). Habla con la API REST de Supabase por HTTPS: entra sin cuenta con un usuario anónimo, manda
## las mejores marcas y trae los rankings. Solo usa la clave PÚBLICA (anon); la seguridad está en la base (supabase/migrations: RLS y funciones).
##
## La dirección y la clave pública se escriben en game/online/online_config.json al compilar (workflows, a partir de los secretos
## SUPABASE_URL y SUPABASE_ANON_KEY). Sin eso, o con «Rankings online» apagado en Opciones, no se conecta a nada.
## Todas las llamadas son «await» y devuelven {ok, code, data, error}.

const CONFIG_PATH := "res://game/online/online_config.json"
const SESSION_PATH := "user://online.json"

var url := ""
var anon_key := ""
var profile: RefCounted # para el nombre y la opción «Rankings online»
var token := ""
var refresh_token := ""
var uid := ""
var expires_at := 0 # segundos unix
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
			url = str((d as Dictionary).get("url", "")).strip_edges().rstrip("/")
			anon_key = str((d as Dictionary).get("anon_key", "")).strip_edges()
	return configured()

func configured() -> bool:
	return (url.begins_with("https://") or url.begins_with("http://127.0.0.1")) and anon_key.length() > 20 # http solo para el servidor de prueba local

## ¿Se puede usar? (hay configuración y el jugador aceptó participar en los rankings)
func enabled() -> bool:
	return configured() and profile != null and profile.setting("onlineScores") == true

# ───────────────────────── armado de pedidos (puro, sin red: se prueba aparte) ─────────────────────────
static func headers(key: String, bearer: String) -> PackedStringArray:
	return PackedStringArray(["apikey: " + key, "Authorization: Bearer " + (bearer if bearer != "" else key), "Content-Type: application/json", "Accept: application/json"])

## Carga para submit_score (la función de la base valida todo de nuevo)
static func score_payload(track: String, board: String, value: float, car: String, laps: int, build: String, name: String) -> Dictionary:
	return {"p_track": track, "p_board": board, "p_value": snappedf(value, 0.001), "p_car": car, "p_laps": laps, "p_build": build, "p_name": name}

## Qué tabla corresponde al resultado de una carrera (o "" si no entra a ningún ranking)
static func board_for(result_type: String, cfg: Dictionary) -> String:
	if cfg.get("testCar", false) == true or cfg.get("practice", false) == true or cfg.get("labbed", false) == true:
		return ""
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
		"expires_at": int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600)) - 60}

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

## Entra sin cuenta (usuario anónimo). Reusa la sesión guardada y la renueva si venció.
func sign_in() -> bool:
	var now := int(Time.get_unix_time_from_system())
	if token != "" and expires_at > now:
		return true
	if refresh_token != "":
		var r := await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})
		if r["ok"] and r["data"] is Dictionary:
			_set_session(parse_session(r["data"] as Dictionary))
			return token != ""
	var a := await request(HTTPClient.METHOD_POST, "/auth/v1/signup", {})
	if a["ok"] and a["data"] is Dictionary:
		_set_session(parse_session(a["data"] as Dictionary))
		return token != ""
	return false

func _set_session(s: Dictionary) -> void:
	token = str(s["token"])
	refresh_token = str(s["refresh"])
	uid = str(s["uid"])
	expires_at = int(s["expires_at"])
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"refresh": refresh_token, "uid": uid}))

func _load_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
		if d is Dictionary:
			refresh_token = str((d as Dictionary).get("refresh", ""))
			uid = str((d as Dictionary).get("uid", ""))

## Llama a una función de la base (RPC) con sesión
func call_fn(fn: String, args: Dictionary, need_session := true) -> Dictionary:
	if need_session and not await sign_in():
		return {"ok": false, "code": 0, "data": null, "error": last_error if last_error != "" else "sin sesión"}
	return await request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, token if need_session else "")

# ───────────────────────── lo que usa el juego ─────────────────────────
## Manda una marca (si el jugador participa en los rankings). No molesta: se llama sin esperar el resultado.
func submit_score(track: String, board: String, value: float, car: String, laps: int, build: String) -> Dictionary:
	if not enabled() or board == "":
		return {"ok": false, "code": 0, "data": null, "error": "apagado"}
	var nm := str(profile.d.get("name", "Piloto"))
	return await call_fn("submit_score", score_payload(track, board, value, car, laps, build, nm))

func leaderboard(track: String, board: String, limit := 50) -> Dictionary:
	return await call_fn("get_leaderboard", {"p_track": track, "p_board": board, "p_limit": limit}, await sign_in())

## Prueba de conexión (para el modo desarrollador): entra, pide un ranking y cuenta las filas
func ping() -> Dictionary:
	if not configured():
		return {"ok": false, "text": "Falta configurar la dirección y la clave de Supabase (secretos del repositorio)."}
	var ok := await sign_in()
	if not ok:
		return {"ok": false, "text": "No pude entrar (%s)." % (last_error if last_error != "" else "sin respuesta")}
	var r := await call_fn("get_leaderboard", {"p_track": "dream", "p_board": "race", "p_limit": 5})
	if not r["ok"]:
		return {"ok": false, "text": "Entré, pero falló el ranking: %s. ¿Se aplicaron las migraciones?" % str(r["error"])}
	return {"ok": true, "text": "✔ Conectado a Supabase (usuario %s…, %d filas en el ranking de prueba)." % [uid.left(6), (r["data"] as Array).size() if r["data"] is Array else 0]}
