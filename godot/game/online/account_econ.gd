extends Node
## Economía de la CUENTA: los créditos, los autos y las compras viven en el servidor (Supabase) y el juego los trae de ahí; lo que diga profile.json no vale. Ver docs/CUENTA_Y_ECONOMIA.md.
##
## Cómo anda:
##  · El perfil (profile.gd) le anota a este nodo cada premio, gasto y compra como un EVENTO (`log_event`). Los eventos esperan en `profile.d["acct"]["pending"]` (se guardan con el perfil: si se
##    cierra el juego o no hay conexión no se pierden) y se mandan al servidor en tandas (`account_apply`).
##  · El servidor valida todo contra su catálogo y sus topes (precio de cada auto y pieza, saldo, premios por hora y por día, autos premium sólo con la compra) y devuelve el estado de verdad:
##    créditos, autos con sus mejoras/gomas/piezas y compras. Ese estado MANDA: `reconcile` lo vuelca sobre el perfil (lo que el servidor no reconoce desaparece) y le suma los eventos que todavía
##    no se mandaron, así el saldo que se ve en pantalla sigue siendo inmediato.
##  · Sin conexión se juega igual (hasta ACCOUNT_GRACE_DAYS días desde la última confirmación del servidor); al volver la conexión se mandan los eventos que quedaron esperando.
##  · Un sello (HMAC) del estado confirmado detecta si se editó profile.json a mano: con el sello roto hay que conectarse y el servidor pisa lo editado. (Es un freno, no una pared: la defensa
##    de verdad es que el servidor es el dueño de los créditos y los autos.)

const Release := preload("res://game/data/release.gd")
const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const PartCatalog := preload("res://game/car/part_catalog.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")
const Tr := preload("res://game/i18n/tr.gd")

signal changed # cambió el estado de la sincronización o la cola
signal corrected(text: String) # el servidor corrigió algo de lo que se veía (compra rechazada, premio recortado…)
signal login_needed # la sesión ya no sirve: hay que volver a iniciar sesión
signal _done(res: Dictionary) # terminó la sincronización en curso (para los que esperan su resultado)

const BATCH := 40 # eventos por tanda (el servidor acepta hasta 60)
const FLUSH_DELAY := 6.0 # segundos desde el primer evento nuevo hasta mandarlo
const MIN_GAP := 12.0 # segundos mínimos entre dos tandas (el servidor deja 600 por hora)
const BACKOFF := [5.0, 15.0, 60.0, 300.0]

var profile: RefCounted
var online: Node
var status := "off" # off · ok · syncing · offline · login · server_old · slow · error
var server_missing := false # el servidor no tiene las funciones de la cuenta (falta aplicar la migración): en las compilaciones de prueba se juega con lo local; en la de Play no se entra
var last_error := ""
var last_rejects: Array = [] # [{t, reason}] de la última tanda (para ver qué rechazó el servidor)
var _busy := false
var _again := false
var _fail := 0
var _timer: Timer
var _last_run := 0.0

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: sync())
	add_child(_timer)

## Se llama al arrancar (app.gd): el perfil queda conectado a este nodo
func attach(p: RefCounted, o: Node) -> void:
	profile = p
	online = o
	p.acct = self

## ¿La cuenta del servidor maneja la economía de este perfil? (con el modo desarrollador o sin Supabase configurado es todo local)
func is_active() -> bool:
	return profile != null and Release.account_mode(profile, online) and not (server_missing and not Release.store())

func _ac() -> Dictionary:
	var d: Dictionary = profile.d
	if not (d.get("acct") is Dictionary):
		d["acct"] = Profile.default_profile()["acct"]
	var ac: Dictionary = d["acct"]
	if not (ac.get("pending") is Array):
		ac["pending"] = []
	return ac

func pending_count() -> int:
	return (_ac()["pending"] as Array).size() if profile != null else 0

## Anota un evento para el servidor. `delta` es lo que cambia el saldo en pantalla mientras no lo confirme (premio +, gasto −)
func log_event(e: Dictionary, delta: int) -> void:
	if not is_active():
		return
	var ac := _ac()
	ac["n"] = int(ac.get("n", 0)) + 1
	e["id"] = "%s%d_%d_%d" % [str(ac.get("uid", "")).left(6), int(Time.get_unix_time_from_system()), int(ac["n"]), randi() % 10000]
	e["d"] = delta
	(ac["pending"] as Array).append(e)
	changed.emit()
	_schedule(FLUSH_DELAY)

func _schedule(delay: float) -> void:
	if _timer == null or not is_inside_tree():
		return
	var wait := maxf(delay, MIN_GAP - (Time.get_ticks_msec() / 1000.0 - _last_run))
	if _timer.is_stopped() or _timer.time_left > wait:
		_timer.start(wait)

## Manda ya lo que haya esperando (al volver al menú, al entrar a un taller, al pasar la app a segundo plano)
func flush_soon() -> void:
	if is_active() and pending_count() > 0 and online != null and online.is_account():
		_schedule(0.2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		flush_soon()

# ───────────────────────── sello de integridad ─────────────────────────
static func _key() -> PackedByteArray:
	return "·".join(["dr", "K7", "acct", "seal", "v1", "9f2c"]).to_utf8_buffer()

## Resumen del estado que importa (créditos, autos con sus compras, compras de la tienda, cola) para firmarlo
static func _digest_text(d: Dictionary) -> String:
	var ac: Dictionary = d.get("acct", {})
	var parts: PackedStringArray = []
	parts.append(str(ac.get("uid", "")))
	parts.append(str(int(d.get("credits", 0))))
	parts.append(str(int(ac.get("synced", 0))))
	parts.append(str(int(ac.get("seq", 0))))
	var owned: Dictionary = d.get("owned", {})
	var ids: Array = owned.keys()
	ids.sort()
	for id in ids:
		var st: Dictionary = owned[id]
		var ow: Array = (st.get("owned", {}) as Dictionary).keys()
		ow.sort()
		var tw: Array = (st.get("tiresOwned", []) as Array).duplicate()
		tw.sort()
		var po: Array = (st.get("partsOwned", []) as Array).duplicate()
		po.sort()
		parts.append("%s=%s;%s;%s" % [str(id), ",".join(PackedStringArray(ow)), ",".join(PackedStringArray(tw)), ",".join(PackedStringArray(po))])
	var iap: Array = (d.get("iap", {}) as Dictionary).keys()
	iap.sort()
	parts.append(",".join(PackedStringArray(iap)))
	for e in (ac.get("pending", []) as Array):
		parts.append(str((e as Dictionary).get("id", "")))
	return "|".join(parts)

static func seal_of(d: Dictionary) -> String:
	var c := Crypto.new()
	return c.hmac_digest(HashingContext.HASH_SHA256, _key(), _digest_text(d).to_utf8_buffer()).hex_encode()

## Se llama al guardar el perfil: firma el estado actual
func stamp() -> void:
	if profile == null or not is_active():
		return
	var ac := _ac()
	ac["seal"] = seal_of(profile.d)

## ¿Se tocó el archivo del perfil a mano? (el sello no coincide con lo que hay)
func tampered() -> bool:
	if profile == null:
		return false
	var ac := _ac()
	var seal := str(ac.get("seal", ""))
	if seal == "":
		return false # todavía no se firmó nunca (perfil de antes de la cuenta): se verifica por «nunca sincronizó»
	return seal != seal_of(profile.d)

# ───────────────────────── puerta de entrada ─────────────────────────
## "" = se puede jugar · "login" = hay que iniciar sesión · "sync" = hay que conectarse a confirmar la cuenta (cuenta nueva en este teléfono, archivo tocado o demasiados días sin conexión)
func gate_state() -> String:
	if not is_active():
		return ""
	if online == null or not online.is_account():
		return "login"
	var ac := _ac()
	var synced := int(ac.get("synced", 0))
	if str(ac.get("uid", "")) != str(online.uid) or synced <= 0 or tampered():
		return "sync"
	if int(Time.get_unix_time_from_system()) - synced > Release.ACCOUNT_GRACE_DAYS * 86400:
		return "sync"
	return ""

## Después de iniciar sesión o crear la cuenta: si es otra cuenta distinta de la que había en este teléfono se borra lo local (créditos, autos, compras) y se trae todo del servidor
func on_login() -> Dictionary:
	if not is_active():
		return {"ok": true, "text": ""}
	var ac := _ac()
	if str(ac.get("uid", "")) != str(online.uid):
		wipe_economy(profile.d, str(online.uid))
	return await sync()

## Al cerrar la sesión o borrar la cuenta: lo local de la economía se borra (el próximo que entre trae lo suyo)
func on_logout() -> void:
	if profile == null:
		return
	wipe_economy(profile.d, "")
	status = "off"
	profile.save()
	changed.emit()

static func wipe_economy(d: Dictionary, uid: String) -> void:
	d["credits"] = 0
	d["owned"] = {}
	d["current"] = ""
	d["iap"] = {}
	d["iapTokens"] = []
	d["daily"] = {"day": "", "streak": 0}
	d["acct"] = {"uid": uid, "synced": 0, "seq": 0, "pending": [], "n": 0, "seal": ""}

# ───────────────────────── sincronización ─────────────────────────
func status_text() -> String:
	var n := pending_count()
	match status:
		"ok":
			return Tr.t("☁ Cuenta sincronizada") if n == 0 else Tr.t("☁ Sincronizando (%d)") % n
		"syncing":
			return Tr.t("☁ Sincronizando…")
		"offline":
			return Tr.t("☁ Sin conexión (%d cambios esperando)") % n
		"login":
			return Tr.t("☁ Hay que iniciar sesión de nuevo")
		"server_old":
			return Tr.t("☁ El servidor todavía no está actualizado")
		"slow":
			return Tr.t("☁ Muchos cambios seguidos, se mandan en un rato")
		"error":
			return Tr.t("☁ No se pudo sincronizar")
	return ""

func _set_status(s: String) -> void:
	if status != s:
		status = s
		changed.emit()

## Manda lo que esté esperando y trae el estado de la cuenta. Devuelve {ok, text} (text: la clave en español del error, para traducir)
func sync() -> Dictionary:
	if not is_active():
		return {"ok": true, "text": ""}
	if online == null or not online.is_account():
		_set_status("login")
		return {"ok": false, "text": "Hay que iniciar sesión."}
	if _busy:
		_again = true
		return await _done # ya hay una en curso: se espera a que termine y se devuelve su resultado
	_busy = true
	_set_status("syncing")
	var res := {"ok": true, "text": ""}
	var rounds := 0
	var rejected := 0
	last_rejects = []
	while rounds < 12:
		rounds += 1
		_again = false
		var ac := _ac()
		var pend: Array = ac["pending"]
		var batch: Array = []
		var sent: Dictionary = {}
		for i in mini(pend.size(), BATCH):
			var e: Dictionary = (pend[i] as Dictionary).duplicate()
			e.erase("d")
			batch.append(e)
			sent[str(e["id"])] = true
		var r: Dictionary
		if batch.is_empty():
			r = await online.call_fn("account_state", {})
		else:
			r = await online.call_fn("account_apply", {"p_events": batch})
		_last_run = Time.get_ticks_msec() / 1000.0
		if not r["ok"]:
			res = _on_error(r)
			break
		var st: Dictionary = r["data"] if r["data"] is Dictionary else {}
		if not st.has("credits"):
			res = {"ok": false, "text": "El servidor contestó algo que no entendí."}
			_set_status("error")
			break
		_fail = 0
		# los eventos que se mandaron ya no esperan (aunque el servidor haya rechazado alguno: el estado que vuelve es la verdad)
		var keep: Array = []
		for e2 in (ac["pending"] as Array):
			if not sent.has(str((e2 as Dictionary).get("id", ""))):
				keep.append(e2)
		ac["pending"] = keep
		for rs in (st.get("results", []) as Array):
			if rs is Dictionary and not bool((rs as Dictionary).get("ok", true)):
				rejected += 1
				last_rejects.append(rs)
		var rep := reconcile(profile.d, st, keep)
		ac["synced"] = int(Time.get_unix_time_from_system())
		ac["seq"] = int(st.get("seq", 0))
		ac["uid"] = str(online.uid)
		if st.get("cars", {}) is Dictionary and (st["cars"] as Dictionary).is_empty() and not _has_pending(keep, "give_car") and not _has_pending(keep, "buy_car"):
			_bootstrap_starter() # cuenta nueva: se pide el auto de partida
		profile.save()
		if int(rep["fixed"]) > 0 or (rep["removed"] as Array).size() > 0:
			rejected += 1
		if (ac["pending"] as Array).is_empty() and not _again:
			break
	_busy = false
	if res["ok"]:
		_set_status("ok")
		if rejected > 0:
			corrected.emit(Tr.t("Se ajustó tu cuenta con el servidor"))
		if pending_count() > 0:
			_schedule(FLUSH_DELAY)
	changed.emit()
	_done.emit(res)
	return res

static func _has_pending(pend: Array, t: String) -> bool:
	for e in pend:
		if str((e as Dictionary).get("t", "")) == t:
			return true
	return false

func _bootstrap_starter() -> void:
	var cat: Dictionary = CarBuild.catalog()
	for id in cat["order"]:
		if bool((cat["cars"][id] as Dictionary).get("starter", false)):
			profile.give(str(id), "starter")
			if str(profile.d.get("current", "")) == "":
				profile.d["current"] = str(id)
			return

func _on_error(r: Dictionary) -> Dictionary:
	var code := int(r.get("code", 0))
	var err := str(r.get("error", ""))
	last_error = err
	var low := err.to_lower()
	if code == 401 or code == 403 or "jwt" in low or "sesión" in low or "hace falta una cuenta" in low:
		_set_status("login")
		login_needed.emit()
		return {"ok": false, "text": "Hay que iniciar sesión de nuevo."}
	if code == 0 or low == "sin conexión" or low == "sin configurar":
		_set_status("offline")
		_retry()
		return {"ok": false, "text": "Sin conexión a internet."}
	if code == 404 or "could not find the function" in low or "not found" in low:
		_set_status("server_old")
		if not Release.store():
			server_missing = true # (compilación de prueba) se sigue con el progreso local hasta que se aplique la migración «account_economy»
			corrected.emit(Tr.t("El servidor todavía no tiene la cuenta: se juega con el progreso de este teléfono"))
		return {"ok": false, "text": "El servidor todavía no está actualizado. Probá más tarde."}
	if "demasiadas acciones" in low or code == 429 or code == 503:
		_set_status("slow")
		_retry()
		return {"ok": false, "text": "Muchos cambios seguidos. Probá en un rato."}
	_set_status("error")
	_retry()
	return {"ok": false, "text": "No se pudo sincronizar con el servidor.", "detail": err.left(90)}

func _retry() -> void:
	if pending_count() == 0 or _timer == null or not is_inside_tree():
		return
	var delay: float = BACKOFF[mini(_fail, BACKOFF.size() - 1)]
	_fail += 1
	_timer.start(delay)

## Compra de la tienda (Google Play): el servidor verifica el recibo con Google y acredita (créditos o desbloqueo). Devuelve {ok, text}. Mientras no esté verificada la compra no se consume ni se
## reconoce en Google (si falla se reintenta al abrir el juego).
func verify_purchase(product_id: String, token: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "text": "La cuenta no está activa."}
	if online == null or not online.is_account():
		return {"ok": false, "text": "Hay que iniciar sesión."}
	var r: Dictionary = await online.call_edge("verify-purchase", {"product_id": product_id, "purchase_token": token})
	if not r["ok"]:
		var rr := _on_error(r)
		return rr
	var data: Dictionary = r["data"] if r["data"] is Dictionary else {}
	var st: Dictionary = data.get("state", {}) if data.get("state", {}) is Dictionary else {}
	if not bool(data.get("ok", false)) or not st.has("credits"):
		return {"ok": false, "text": "No se pudo verificar la compra.", "detail": str(data.get("error", ""))}
	var ac := _ac()
	reconcile(profile.d, st, ac["pending"])
	ac["synced"] = int(Time.get_unix_time_from_system())
	ac["seq"] = int(st.get("seq", 0))
	profile.save()
	_set_status("ok")
	return {"ok": true, "text": ""}

# ───────────────────────── el estado del servidor manda ─────────────────────────
## Vuelca el estado de verdad del servidor sobre los datos del perfil `d`, más los eventos `pending` que todavía no se mandaron (para que lo que se ve en pantalla siga al instante).
## Devuelve {removed: autos que se sacaron, added: autos que aparecieron, fixed: piezas/mejoras que se corrigieron, credits_before, credits_after}.
static func reconcile(d: Dictionary, state: Dictionary, pending: Array) -> Dictionary:
	var rep := {"removed": [], "added": [], "fixed": 0, "credits_before": int(d.get("credits", 0)), "credits_after": 0}
	var cars_srv: Dictionary = state.get("cars", {}) if state.get("cars", {}) is Dictionary else {}
	var catalog: Dictionary = CarBuild.catalog()["cars"]
	var p_cars := {}
	var p_upg := {}
	var p_tires := {}
	var p_parts := {}
	var delta := 0
	var p_daily := false
	for ev in pending:
		var e: Dictionary = ev
		delta += int(e.get("d", 0))
		var car := str(e.get("car", ""))
		match str(e.get("t", "")):
			"buy_car", "give_car":
				p_cars[car] = true
			"buy_upgrade":
				_push(p_upg, car, "%s:%d" % [str(e.get("cat", "")), int(e.get("level", 0))])
			"buy_tires":
				_push(p_tires, car, str(e.get("tire", "")))
			"buy_part":
				_push(p_parts, car, str(e.get("part", "")))
			"daily":
				p_daily = true
	# créditos
	d["credits"] = maxi(0, int(state.get("credits", 0)) + delta)
	rep["credits_after"] = int(d["credits"])
	# autos
	if not (d.get("owned") is Dictionary):
		d["owned"] = {}
	var owned: Dictionary = d["owned"]
	for id in owned.keys():
		if not cars_srv.has(id) and not p_cars.has(id):
			owned.erase(id)
			(rep["removed"] as Array).append(str(id))
	for id in cars_srv:
		if not catalog.has(id):
			continue # el servidor tiene un auto que esta versión del juego no conoce
		var cs: Dictionary = cars_srv[id]
		if not owned.has(id):
			owned[id] = Profile.new_car_state(str(id))
			(rep["added"] as Array).append(str(id))
		var st: Dictionary = owned[id]
		# autos alquilados (premios de eventos): el servidor los borra al vencer
		if cs.has("until"):
			st["until"] = int(cs["until"])
		else:
			st.erase("until")
		# mejoras compradas
		var ow := {}
		for k in (cs.get("owned", []) as Array):
			ow[str(k)] = 1
		for k in (p_upg.get(id, []) as Array):
			ow[str(k)] = 1
		st["owned"] = ow
		var upg: Dictionary = st.get("upg", {})
		for cat in upg.keys():
			var lvl := int(upg[cat])
			if lvl > 0 and not ow.has("%s:%d" % [str(cat), lvl]) and _upgrade_cost(str(cat), lvl) != 0:
				upg[cat] = 0 # el nivel puesto no está comprado (o no existe)
				rep["fixed"] = int(rep["fixed"]) + 1
		st["upg"] = upg
		# gomas
		var tires: Array = ["street"]
		for t in (cs.get("tires", []) as Array):
			if not tires.has(str(t)):
				tires.append(str(t))
		for t in (p_tires.get(id, []) as Array):
			if not tires.has(str(t)):
				tires.append(str(t))
		for t in (st.get("tiresOwned", []) as Array):
			if not tires.has(str(t)) and int(CarBuild.tire(str(t)).get("cost", 1)) <= 0:
				tires.append(str(t)) # las gratis son de todos
		st["tiresOwned"] = tires
		if not tires.has(str(st.get("tires", "street"))):
			st["tires"] = "street"
			rep["fixed"] = int(rep["fixed"]) + 1
		# piezas
		var parts: Array = []
		for pn in (cs.get("parts", []) as Array):
			if not parts.has(str(pn)):
				parts.append(str(pn))
		for pn in (p_parts.get(id, []) as Array):
			if not parts.has(str(pn)):
				parts.append(str(pn))
		st["partsOwned"] = parts
		var mods: Dictionary = st.get("mods", {})
		for cat in mods.keys():
			var pid := str((mods[cat] as Dictionary).get("id", ""))
			if pid != "" and not parts.has(pid) and int(PartCatalog.part(pid).get("price", 1)) > 0:
				VehicleCustomization.remove(st, str(cat))
				rep["fixed"] = int(rep["fixed"]) + 1
	# el auto elegido tiene que ser tuyo
	if str(d.get("current", "")) == "" or not owned.has(str(d.get("current", ""))):
		d["current"] = str(owned.keys()[0]) if owned.size() > 0 else ""
	# compras de la tienda: sólo las que dice el servidor
	var iap := {}
	for k in (state.get("iap", {}) as Dictionary):
		iap[str(k)] = true
	d["iap"] = iap
	# regalo diario
	if not p_daily:
		d["daily"] = {"day": str(state.get("daily", "")), "streak": int(state.get("streak", 0))}
	return rep

static func _push(dict: Dictionary, key: String, value: String) -> void:
	if not dict.has(key):
		dict[key] = []
	(dict[key] as Array).append(value)

## Costo de un nivel de mejora; 0 = gratis (es de todos); -1 = no existe esa mejora o ese nivel
static func _upgrade_cost(cat: String, level: int) -> int:
	var u := CarBuild.upgrade(cat)
	if u.is_empty() or level < 0 or level >= (u["levels"] as Array).size():
		return -1
	return int(u["levels"][level].get("cost", 0))
