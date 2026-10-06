extends RefCounted
## Puntos de aparición del menú de diagnóstico (RESPAWN / CAMBIAR UBICACIÓN): lugares equivalentes ya existentes de Dream City, con el auto apuntando en el sentido de la calle.
## No hay caminos de tierra: el equivalente es la banquina de tierra de una ruta del campo. «Muchos árboles» y «muchos edificios» son las cuadras de carga con más árboles y más fachadas.
## Se calcula una vez (recorre los datos de la ciudad) y queda guardado.

const CityProps := preload("res://game/city/city_props.gd")

static var _cache: Array = []
static var _for_city = null

static func spots(city) -> Array:
	if _for_city == city and not _cache.is_empty():
		return _cache
	_for_city = city
	_cache = []
	_add(city, "asphalt", "ASFALTO", "avenida a ~600 m del centro", _road_pt(city, "major", 600.0, 0.5))
	_add(city, "center", "CENTRO DEL PUEBLO", "la avenida principal, junto a la Plaza Aurora", _center_pt(city))
	_add(city, "rural", "ZONA RURAL", "la Ruta 20, en pleno campo", _road_pt(city, "rural", 500.0, 0.5))
	_add(city, "dirt", "CAMINO DE TIERRA", "banquina de tierra de la Ruta 20 (no hay caminos de tierra)", _road_pt(city, "rural", 900.0, 1.9))
	var tree_key := _best_chunk(city, true)
	_add(city, "trees", "ZONA DE MUCHOS ÁRBOLES", "la cuadra con más árboles (%d)" % int(tree_key[1]), _near_chunk(city, tree_key[0]))
	var bld_key := _best_chunk(city, false)
	_add(city, "buildings", "ZONA DE MUCHOS EDIFICIOS", "la cuadra con más fachadas (%d)" % int(bld_key[1]), _near_chunk(city, bld_key[0]))
	return _cache

static func _add(city, id: String, label: String, sub: String, pose: Array) -> void:
	if pose.is_empty():
		return
	_cache.append({"id": id, "label": label, "sub": sub, "x": float(pose[0]), "z": float(pose[1]), "yaw": float(pose[2])})

## Un punto de una calle: ri = índice de la calle, i = punto; lat = qué fracción del semiancho a la derecha del sentido de la calle (o metros si lat_m)
static func _pose_at(city, ri: int, i: int, lat_k: float, lat_m := false) -> Array:
	var rd: Dictionary = city.roads[ri]
	var pts: PackedVector3Array = rd["pts"]
	var j := mini(i + 1, pts.size() - 1)
	var k := i if j > i else maxi(i - 1, 0)
	var dx := pts[j].x - pts[k].x
	var dz := pts[j].z - pts[k].z
	var yaw := atan2(dx, dz)
	var off := lat_k if lat_m else lat_k * float(rd["hw"])
	var right := Vector2(cos(yaw), -sin(yaw))
	return [pts[i].x + right.x * off, pts[i].z + right.y * off, yaw]

## La primera calle de ese tipo, a `dist` metros de su inicio (o su final si es más corta)
static func _road_pt(city, kind: String, dist: float, lat: float) -> Array:
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if str(rd["kind"]) != kind:
			continue
		var cum: PackedFloat32Array = rd["cum"]
		var idx := 0
		for i in cum.size():
			if float(cum[i]) >= dist:
				idx = i
				break
			idx = i
		# lat > 1: metros a la derecha del borde (banquina); si no, fracción del semiancho
		if lat > 1.0:
			var hw := float(rd["hw"])
			return _pose_at(city, ri, idx, hw + lat, true)
		return _pose_at(city, ri, idx, lat)
	return []

## Centro: la calle principal (la primera «major») a unos 110 m de la plaza, yendo hacia afuera
static func _center_pt(city) -> Array:
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if str(rd["kind"]) != "major":
			continue
		var pts: PackedVector3Array = rd["pts"]
		for i in pts.size():
			if Vector2(pts[i].x, pts[i].z).length() >= 110.0:
				return _pose_at(city, ri, i, 0.5)
	return []

## La cuadra de carga con más árboles (trees = true) o más fachadas: [clave, cantidad]
static func _best_chunk(city, trees: bool) -> Array:
	var best := Vector2i.ZERO
	var bn := -1
	if trees:
		for k in city.props_in:
			var n := 0
			for id in (city.props_in[k] as PackedInt32Array):
				var t := int(city.prop_type[id])
				if t == CityProps.TREE or t == CityProps.RTREE:
					n += 1
			if n > bn:
				bn = n
				best = k
	else:
		for k in city.slabs:
			var n2: int = (city.slabs[k] as Array).size()
			if n2 > bn:
				bn = n2
				best = k
	return [best, maxi(bn, 0)]

## El punto de calle más cercano al centro de esa cuadra (sólo calles de la ciudad y del campo, no túneles ni bocas)
static func _near_chunk(city, key: Vector2i) -> Array:
	var cx := (float(key.x) + 0.5) * float(city.CELL)
	var cz := (float(key.y) + 0.5) * float(city.CELL)
	var best := 1e18
	var bri := -1
	var bi := 0
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if str(rd["kind"]) in ["tunnel", "bay"]:
			continue
		var pts: PackedVector3Array = rd["pts"]
		for i in pts.size():
			var d := (pts[i].x - cx) * (pts[i].x - cx) + (pts[i].z - cz) * (pts[i].z - cz)
			if d < best:
				best = d
				bri = ri
				bi = i
	if bri < 0:
		return []
	return _pose_at(city, bri, bi, 0.5)
