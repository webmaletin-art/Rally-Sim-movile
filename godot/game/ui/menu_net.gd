extends RefCounted
## Pantalla de la RED DE RUTAS del menú: caminos largos para circular libre o jugar a la persecución. Se elige el modo, la ventaja que hay que abrir para ganar,
## el nivel del rival y la estación donde se aparece. `m` es el menú (menu.gd).

const Kit := preload("res://game/ui/ui_kit.gd")
const NetSession := preload("res://game/net/net_session.gd")

var m # menu.gd
var _stations: Array = []

const MODES := ["free", "flee", "chase"]
const MODE_NAMES := {"free": "SOLO ANDAR", "flee": "ME PERSIGUEN", "chase": "YO PERSIGO"}
const MODE_HELP := {
	"free": "Sin rivales: recorrés las rutas a tu ritmo. Las estaciones de servicio son tu punto de salida y de regreso.",
	"flee": "Un rival sale detrás tuyo y te persigue por las rutas. Si le abrís la ventaja, ganás; si te alcanza y te pasa, los roles se invierten.",
	"chase": "Un rival sale adelante y tenés que alcanzarlo. Si te abre la ventaja, se te escapa; si lo pasás, ahora te persigue él.",
}
const SKILLS := [0.78, 0.86, 0.93, 1.0]
const SKILL_NAMES := ["TRANQUILO", "NORMAL", "RÁPIDO", "EXPERTO"]

func _opts() -> Dictionary:
	var o: Variant = m.profile.d.get("netOpts", null)
	if not (o is Dictionary):
		o = {"mode": "free", "gap": 150, "skill": 0.86, "station": 0}
		m.profile.d["netOpts"] = o
	return o

func _load_stations() -> void:
	if not _stations.is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/networks/red_1.json"))
	if d is Dictionary:
		for s in (d as Dictionary).get("stations", []):
			_stations.append(str(s["name"]))

func screen() -> void:
	_load_stations()
	var o := _opts()
	m.set_title(tr("RUTAS"))
	var mode := str(o["mode"])
	m.body.add_child(Kit.wrap(tr("Una red de rutas de más de 1.600 km: asfalto, tierra y barro, con rotondas y estaciones de servicio. Empezás en una estación."), 15, Kit.MUTED, 300))
	m.body.add_child(m.menu_button("▶ " + tr("JUGAR"), tr(MODE_NAMES[mode]), func() -> void:
		m.sfx.play("click")
		_play(), true))
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	g.add_child(Kit.selector(tr("MODO"), MODES, mode, func(v) -> String: return tr(MODE_NAMES[str(v)]), func(v) -> void:
		o["mode"] = str(v)
		m.profile.save()
		m.go("rutas", null, false), m.sfx))
	g.add_child(Kit.selector(tr("ESTACIÓN DE SALIDA"), range(_stations.size()), clampi(int(o["station"]), 0, maxi(0, _stations.size() - 1)), func(v) -> String: return str(_stations[int(v)]) if int(v) < _stations.size() else "-", func(v) -> void:
		o["station"] = int(v)
		m.profile.save(), m.sfx))
	if mode != "free":
		g.add_child(Kit.selector(tr("VENTAJA PARA GANAR"), NetSession.LIMITS, float(o["gap"]), func(v) -> String: return "%d m" % int(v), func(v) -> void:
			o["gap"] = int(v)
			m.profile.save(), m.sfx))
		g.add_child(Kit.selector(tr("RIVAL"), SKILLS, float(o["skill"]), func(v) -> String: return tr(SKILL_NAMES[SKILLS.find(v)]) if SKILLS.has(v) else "-", func(v) -> void:
			o["skill"] = float(v)
			m.profile.save(), m.sfx))
	m.body.add_child(Kit.wrap(tr(MODE_HELP[mode]), 15, Kit.TEXT, 300))
	if mode != "free":
		m.body.add_child(Kit.wrap(tr("La ventaja es la distancia en línea recta entre los dos autos: quien la abre primero gana. Podés volver a salir de la estación más cercana con el botón ↺ ESTACIÓN."), 14, Kit.MUTED, 300))

func _play() -> void:
	var o := _opts()
	var pid: String = m.profile.current_id()
	m.profile.select(pid)
	var mode := str(o["mode"])
	var cfg := {"type": "net", "track": "rutas", "netMode": mode, "station": int(o["station"]), "chaseGap": float(o["gap"]), "skill": float(o["skill"]),
		"ai": 0 if mode == "free" else 1, "rule": "" if mode == "free" else "chase", "sky": "day", "car": pid, "state": m.profile.car(), "seed": randi() % 1000, "back": "home", "quick": true}
	m.launch(cfg)
