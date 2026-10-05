extends "res://game/data/profile.gd"
## Perfil del MODO ONLINE: mismo interfaz que el perfil offline (así el garaje y los talleres funcionan igual), pero los autos y los créditos son un ESPEJO de lo que dice el servidor.
## Cada cambio que hace la interfaz se aplica enseguida en pantalla y, al guardar, se compara con lo último que confirmó el servidor y se mandan las acciones que corresponden
## (comprar mejora, gomas, pieza, pintura, auto). El servidor valida todo (dueño, local, catálogo, compatibilidad, saldo); si rechaza algo, el espejo vuelve a lo que dice el servidor.
## El progreso offline no se toca: ajustes, nombre y estadísticas se comparten (son del jugador), pero autos, créditos, nafta, fama y posición del mundo online son aparte (base.d["online"]).
## Un auto por modelo en el garaje de la pantalla (si por el mercado llegaran dos del mismo modelo, se ve el primero).

signal sync_failed(text: String)

const SERVER_PAINT_KEYS := ["body", "accent", "rim", "tire", "spring", "caliper", "finish", "livery", "disc"]
const OWN_KEYS := ["lastPos", "tod", "worldTime", "worldSeed", "fuel", "toll_pass", "worldRep", "act"]

var base: RefCounted # el perfil offline (ajustes, nombre, dónde se guarda en disco)
var eco: RefCounted # online_economy.gd
var shop := "" # local de Dream City desde el que se está operando (lo pone app.gd al abrir el taller); vacío = en la calle
var _inst: Dictionary = {} # id de modelo → instancia (uuid)
var _busy := false

func _init(p_base: RefCounted = null, p_eco: RefCounted = null) -> void:
	base = p_base
	eco = p_eco
	if base == null:
		return
	var sub: Dictionary = _sub()
	d = (base.d as Dictionary).duplicate(false)
	for k in OWN_KEYS:
		if sub.has(k):
			d[k] = sub[k]
		else:
			d.erase(k)
	d["worldRep"] = sub.get("worldRep", {"pts": 0.0, "visited": {}})
	d["act"] = sub.get("act", {})
	d["fuel"] = float(sub.get("fuel", 1.0))
	d["toll_pass"] = int(sub.get("toll_pass", 0))
	rebuild()

func _sub() -> Dictionary:
	var b: Dictionary = base.d
	if not (b.get("online") is Dictionary):
		b["online"] = {"cur": "", "tune": {}}
	return b["online"]

## Vuelve a armar el espejo con lo último que mandó el servidor
func rebuild() -> void:
	var cars: Dictionary = CarBuild.catalog()["cars"]
	var keep := str(d.get("current", ""))
	var sub: Dictionary = _sub()
	var tunes: Dictionary = sub.get("tune", {})
	var owned: Dictionary = {}
	_inst = {}
	for item in eco.vehicles:
		var v: Dictionary = item
		var id := str(v.get("vehicle", ""))
		if str(v.get("status", "garage")) != "garage" or owned.has(id) or not cars.has(id):
			continue
		var st: Dictionary = new_car_state(id)
		st["upg"] = (v.get("upg", {}) as Dictionary).duplicate(true)
		st["tires"] = str(v.get("tires", "street"))
		st["tiresOwned"] = (v.get("tiresOwned", ["street"]) as Array).duplicate()
		st["tireWear"] = (v.get("tireWear", {}) as Dictionary).duplicate(true)
		var pt: Dictionary = st["paint"]
		var sp: Dictionary = v.get("paint", {})
		for k in sp:
			pt[k] = sp[k]
		st["partsOwned"] = (v.get("partsOwned", []) as Array).duplicate()
		st["mods"] = (v.get("mods", {}) as Dictionary).duplicate(true)
		st["km"] = float(v.get("km", 0.0))
		st["instance"] = str(v.get("instance", ""))
		st["tune"] = (tunes.get(str(v.get("instance", "")), {}) as Dictionary).duplicate(true)
		owned[id] = st
		_inst[id] = str(v.get("instance", ""))
	d["owned"] = owned
	d["credits"] = eco.credits
	if owned.has(keep):
		d["current"] = keep
	elif owned.has(str(sub.get("cur", ""))):
		d["current"] = str(sub["cur"])
	else:
		d["current"] = str(owned.keys()[0]) if owned.size() > 0 else ""

func instance_of(id: String) -> String:
	return str(_inst.get(id, ""))

## Lo que hay que mandar al servidor para que lo confirmado coincida con lo que se ve (una acción por vez; vacío si ya coincide)
func _next_op() -> Dictionary:
	var owned: Dictionary = d["owned"]
	for key in owned:
		var id := str(key)
		var st: Dictionary = owned[id]
		if not _inst.has(id):
			return {"fn": "online_buy_vehicle", "args": {"p_vehicle": id, "p_shop": "dealer"}, "id": id}
		var inst := str(_inst[id])
		var sv: Dictionary = eco.find(inst)
		if sv.is_empty():
			continue
		var upg: Dictionary = st.get("upg", {})
		var supg: Dictionary = sv.get("upg", {})
		for cat in upg:
			var want := int(upg[cat])
			var have := int(supg.get(cat, 0))
			if want > have:
				return {"fn": "online_buy_upgrade", "args": {"p_instance": inst, "p_category": str(cat), "p_level": have + 1, "p_shop": shop}, "id": id}
		var tires := str(st.get("tires", "street"))
		if tires != str(sv.get("tires", "street")):
			return {"fn": "online_buy_tires", "args": {"p_instance": inst, "p_tire": tires, "p_shop": shop}, "id": id}
		var tw: Dictionary = st.get("tireWear", {})
		var stw: Dictionary = sv.get("tireWear", {})
		if float(tw.get(tires, 0.0)) <= 0.0 and float(stw.get(tires, 0.0)) > 0.0:
			return {"fn": "online_replace_tires", "args": {"p_instance": inst, "p_shop": shop}, "id": id}
		var mods: Dictionary = st.get("mods", {})
		var smods: Dictionary = sv.get("mods", {})
		for cat in mods:
			var pid := str((mods[cat] as Dictionary).get("id", ""))
			var spid := str((smods.get(cat, {}) as Dictionary).get("id", ""))
			if pid != "" and pid != spid:
				return {"fn": "online_buy_part", "args": {"p_instance": inst, "p_part": pid, "p_shop": shop}, "id": id}
		for cat in smods:
			if not mods.has(cat):
				return {"fn": "online_remove_part", "args": {"p_instance": inst, "p_category": str(cat), "p_shop": shop}, "id": id}
		var paint: Dictionary = st.get("paint", {})
		var spaint: Dictionary = sv.get("paint", {})
		var diff: Dictionary = {}
		for k in SERVER_PAINT_KEYS:
			if paint.has(k) and str(paint[k]).to_lower() != str(spaint.get(k, "")).to_lower():
				diff[k] = int(paint[k]) if k == "livery" else str(paint[k])
		if not diff.is_empty():
			return {"fn": "online_set_paint", "args": {"p_instance": inst, "p_paint": diff, "p_shop": shop}, "id": id}
	return {}

## Se llama tras cada cambio de la interfaz: guarda lo local (ajustes, ajuste fino) y manda al servidor lo que cambió
func save() -> void:
	flush()
	if eco == null or not eco.ready:
		return
	if _busy:
		return # la tanda en curso vuelve a mirar al terminar
	if _next_op().is_empty():
		d["credits"] = eco.credits # lo que sólo se cambió localmente (ajuste fino) no cobra online
		return
	_run()

func _run() -> void:
	_busy = true
	var failed := ""
	var guard := 0
	while guard < 40:
		guard += 1
		var op: Dictionary = _next_op()
		if op.is_empty():
			break
		var r: Dictionary = await eco.act(str(op["fn"]), op["args"] as Dictionary)
		if not bool(r["ok"]):
			failed = str(r["text"])
			break
		if str(op["fn"]) == "online_buy_vehicle":
			var nv: Variant = (r["data"] as Dictionary).get("vehicle")
			if nv is Dictionary:
				_inst[str(op["id"])] = str((nv as Dictionary).get("instance", ""))
	if failed != "":
		await eco.sync(str(eco.nick)) # lo que el servidor rechazó no pasó: se vuelve a pedir el saldo y los autos reales
	_busy = false
	rebuild()
	if failed != "":
		sync_failed.emit(failed)
	flush()
	changed.emit()

## Guarda en el perfil offline (en su propio rincón «online») lo que es de este modo, y escribe el disco
func flush() -> void:
	if base == null:
		return
	var sub: Dictionary = _sub()
	for k in OWN_KEYS:
		if d.has(k):
			sub[k] = d[k]
	sub["cur"] = str(d.get("current", ""))
	var tunes: Dictionary = sub.get("tune", {})
	var owned: Dictionary = d["owned"]
	for id in owned:
		var st: Dictionary = owned[id]
		var inst := str(st.get("instance", ""))
		if inst != "":
			tunes[inst] = (st.get("tune", {}) as Dictionary).duplicate(true)
	sub["tune"] = tunes
	base.d["online"] = sub
	base.save()

# ───────────────────────── reglas propias del online ─────────────────────────
## En un local el cobro es un espejo (el servidor cobra de verdad); en la calle (nafta, peajes) todavía no se cobra online
func spend(n: int) -> bool:
	if shop == "":
		return true
	if credits < n:
		return false
	d["credits"] = credits - n
	return true

## Los premios online los paga el servidor cuando valide los resultados (todavía no hay): acá no se crea dinero
func earn(_n: float) -> void:
	pass

func daily_check() -> Dictionary:
	return {}

func add_xp(_n: float) -> Array:
	return []

func upgrade_level(id: String, cat: String) -> int:
	return int(((d["owned"][id] as Dictionary).get("upg", {}) as Dictionary).get(cat, 0))

## Las mejoras se compran de a un nivel y no se bajan (el servidor no guarda niveles sueltos)
func buy_upgrade(id: String, cat: String, level: int) -> bool:
	if not owns(id) or level != upgrade_level(id, cat) + 1:
		return false
	return super.buy_upgrade(id, cat, level)

func part_owned(id: String, cat: String, level: int) -> bool:
	return owns(id) and level <= upgrade_level(id, cat)

func sell_value(_id: String) -> int:
	return 0
