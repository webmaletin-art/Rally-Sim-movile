extends RefCounted
## Taller de prueba de la pausa (pruebas de autos de la tienda, Carrera rápida y drift): todos los ajustes del auto en barras,
## sin piezas ni plata y sin guardar nada. Cada cambio se aplica al soltar la barra (race.gd rearma el auto).
## st: estado del auto de la prueba (con "lab": {"all": true, …}) · defs: valores de fábrica de los ajustes (CarBuild.default_tune)

const Kit := preload("res://game/ui/ui_kit.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Tr := preload("res://game/i18n/tr.gd")

## Ajustes extra que no están en el taller normal (se guardan en st["lab"]); todos en %
const EXTRA := {
	"power": {"n": "Potencia del motor", "min": 40, "max": 300, "step": 5, "def": 100, "u": "%", "info": "Multiplica la potencia en todo el rango de vueltas."},
	"mass": {"n": "Peso del auto", "min": 50, "max": 160, "step": 2, "def": 100, "u": "%", "info": "Masa total: menos peso acelera, frena y dobla mejor."},
	"drag": {"n": "Resistencia al aire", "min": 40, "max": 250, "step": 5, "def": 100, "u": "%", "info": "Más resistencia = menos velocidad final."},
	"grip": {"n": "Agarre de las gomas (todo)", "min": 40, "max": 180, "step": 2, "def": 100, "u": "%", "info": "Multiplica el agarre de las cuatro gomas en todas las superficies."},
	"travel": {"n": "Recorrido de suspensión", "min": 40, "max": 220, "step": 5, "def": 100, "u": "%", "info": "Cuánto sube y baja cada rueda antes de topar."},
}

## [título de la solapa, [claves en orden]]
const TABS := [
	["MOTOR", ["power", "mass", "drag"]],
	["AGARRE", ["tires", "grip", "gripF", "gripR", "pressF", "pressR", "camberF", "camberR", "toeF", "toeR"]],
	["SUSPENSIÓN", ["height", "springF", "springR", "bump", "rebound", "arbF", "arbR", "travel"]],
	["FRENOS", ["bias", "bpress", "steer"]],
	["TRANSMISIÓN", ["split", "lsd", "final"]],
	["AERO", ["aeroF", "aeroR", "stanceCamber"]],
]

static func _items() -> Dictionary:
	var out := {}
	for g in CarBuild.catalog()["tune"]:
		for it in g["items"]:
			out[str(it["k"])] = it
	for k in EXTRA:
		var e: Dictionary = (EXTRA[k] as Dictionary).duplicate()
		e["k"] = k
		e["extra"] = true
		out[k] = e
	return out

static func default_for(k: String, it: Dictionary, defs: Dictionary) -> float:
	if it.has("extra"):
		return float(it["def"])
	return float(defs.get(k, it["def"]))

static func value_of(st: Dictionary, k: String, it: Dictionary, defs: Dictionary) -> float:
	if it.has("extra"):
		return float((st["lab"] as Dictionary).get(k, it["def"]))
	return float((st.get("tune", {}) as Dictionary).get(k, defs.get(k, it["def"])))

static func _num(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 0.001 else "%.2f" % v

## Arma la página en body. on_change: Callable() → se aplicó un valor (race.gd rearma el auto) · on_page: Callable() → hay que rearmar la página
## (cambió la solapa o un valor que cambia otros) · tab: [índice] (se guarda entre aperturas) · on_reset: Callable() → volver al auto de fábrica
static func build(body: VBoxContainer, st: Dictionary, defs: Dictionary, tab: Array, on_change: Callable, on_page: Callable, on_reset: Callable, sfx: Node = null) -> void:
	var items := _items()
	var cur := clampi(int(tab[0]), 0, TABS.size() - 1)
	var labels: Array = []
	for t in TABS:
		labels.append(str(t[0]))
	var r1 := Kit.tabs(labels.slice(0, 3), cur, func(i: int) -> void:
		tab[0] = i
		on_page.call(), 16, 44.0)
	body.add_child(r1)
	var r2 := Kit.tabs(labels.slice(3), cur - 3, func(i: int) -> void:
		tab[0] = i + 3
		on_page.call(), 16, 44.0)
	body.add_child(r2)
	var info := Kit.wrap("", 13, Kit.MUTED, 200)
	info.max_lines_visible = 3
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for k in TABS[cur][1]:
		if k == "tires":
			_tires_row(body, st, on_change, sfx)
			continue
		var it: Dictionary = items[k]
		var v0 := value_of(st, k, it, defs)
		var row := Kit.hbox(8)
		body.add_child(row)
		var nl := Kit.label(str(it["n"]), 15, Kit.TEXT)
		nl.custom_minimum_size.x = 168
		nl.clip_text = true
		row.add_child(nl)
		var sl := HSlider.new()
		sl.min_value = float(it["min"])
		sl.max_value = float(it["max"])
		sl.step = float(it["step"]) if it.has("step") else 1.0
		sl.value = v0
		sl.custom_minimum_size = Vector2(0, 38)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sl)
		var unit := str(it.get("u", ""))
		var vl := Kit.label("%s %s" % [_num(v0), unit], 15, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = 76
		row.add_child(vl)
		var txt := Tr.t(str(it.get("info", "")))
		var extra: bool = it.has("extra")
		var key: String = k
		sl.value_changed.connect(func(nv: float) -> void:
			if extra:
				(st["lab"] as Dictionary)[key] = nv
			else:
				if not st.has("tune"):
					st["tune"] = {}
				(st["tune"] as Dictionary)[key] = nv
			vl.text = "%s %s" % [_num(nv), unit]
			info.text = txt)
		sl.drag_ended.connect(func(_c: bool) -> void: on_change.call())
	body.add_child(info)
	# atajos de ajuste (los mismos del taller) y volver al auto de fábrica
	var prow := Kit.hbox(6)
	body.add_child(prow)
	var cat := CarBuild.catalog()
	for pk in ["asfalto", "tierra", "drift", "salto"]:
		var pkey: String = pk
		var pb := Kit.button(str(cat["preset_n"][pkey]), func() -> void:
			if sfx != null:
				sfx.play("click")
			var tu := {}
			for k2 in cat["presets"][pkey]:
				tu[k2] = float(cat["presets"][pkey][k2])
			st["tune"] = tu
			on_change.call()
			on_page.call(), false, 15, Vector2(0, 42))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(pb)
	var rb := Kit.button("↺ AUTO DE FÁBRICA", func() -> void:
		if sfx != null:
			sfx.play("click")
		on_reset.call(), false, 17, Vector2(0, 48))
	body.add_child(rb)
	body.add_child(Kit.wrap("Los cambios no se guardan ni cuestan nada: son solo para probar. Se aplican al soltar la barra.", 12, Kit.MUTED, 200))

static func _tires_row(body: VBoxContainer, st: Dictionary, on_change: Callable, sfx: Node) -> void:
	var tires: Array = CarBuild.catalog()["tires"]
	var ids: Array = []
	for t in tires:
		ids.append(str(t["id"]))
	var fmt := func(v) -> String:
		for t in tires:
			if str(t["id"]) == str(v):
				return "%s %s" % [t["icon"], Tr.t(str(t["n"]))]
		return str(v)
	var pick := func(v) -> void:
		st["tires"] = str(v)
		on_change.call()
	body.add_child(Kit.selector(Tr.t("Gomas"), ids, str(st.get("tires", "street")), fmt, pick, sfx, 60.0))
