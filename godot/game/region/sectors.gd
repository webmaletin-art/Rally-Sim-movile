extends RefCounted
## Sectores del mundo abierto (docs/REGION.md → «Sectores habilitados»): qué partes de la región se pueden manejar hoy. Los datos están en game/data/sectors.json
## y se puede volver a abrir todo poniendo open_all = true (reversible, sin regenerar la región). Lo que no está abierto se ve en el mapa pero no se aparece ahí
## y las rutas que entran tienen barreras de obra físicas (city/city_sectors.gd). Consultas puras y estáticas (las usan la policía, las carreras, el menú y el mapa).

const FILE := "res://game/data/sectors.json"

static var _loaded := false
static var _open_all := true
static var _circles: Array = [] # [Vector2 centro, radio]
static var _polys: Array = [] # PackedVector2Array
static var _names: Array = [] # nombre por sector abierto (mismo orden: círculos y después polígonos)
static var pending_name := "Sector en obra"

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (d is Dictionary):
		return
	_open_all = bool(d.get("open_all", false))
	pending_name = str(d.get("pending_name", pending_name))
	for s in d.get("sectors", []):
		if not bool(s.get("open", false)):
			continue
		if s.has("circle"):
			var c: Array = s["circle"]
			_circles.append([Vector2(float(c[0]), float(c[1])), float(c[2])])
		elif s.has("poly"):
			var pv := PackedVector2Array()
			for q in s["poly"]:
				pv.append(Vector2(float(q[0]), float(q[1])))
			_polys.append(pv)

## ¿Todo abierto? (sin sectores en obra)
static func all_open() -> bool:
	_load()
	return _open_all

static func is_open(p: Vector2) -> bool:
	_load()
	if _open_all:
		return true
	if p.x > 70000.0:
		return true # el «bolsillo» de los túneles y estacionamientos
	for c in _circles:
		if p.distance_squared_to(c[0]) < float(c[1]) * float(c[1]):
			return true
	for pv in _polys:
		if Geometry2D.is_point_in_polygon(p, pv):
			return true
	return false

## Polígonos y círculos abiertos (para dibujar el mapa)
static func open_shapes() -> Dictionary:
	_load()
	return {"circles": _circles, "polys": _polys}

## Sólo para pruebas: volver a leer el archivo
static func reload() -> void:
	_loaded = false
	_circles.clear()
	_polys.clear()
	_load()

## Sólo para pruebas: forzar todo abierto / con sectores en obra (asignar _open_all desde otro script después de reload() no siempre se aplica)
static func force_open_all(v: bool) -> void:
	_load()
	_open_all = v
