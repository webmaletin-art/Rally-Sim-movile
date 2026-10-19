extends Control
## HUD de Dream City: minimapa que gira con el auto (arriba siempre es hacia donde mirás), mapa grande fijo (norte arriba) que se abre tocando el minimapa,
## nombre de la calle y cuadra, y el GPS hasta un lugar (se elige tocando el mapa grande). Todo se dibuja con líneas a partir de las calles de CityLayout (nada de imágenes).

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CityGps := preload("res://game/city/city_gps.gd")
const WorldGps := preload("res://game/city/world_gps.gd")
const RegionData := preload("res://game/region/region_data.gd")
const CityNames := preload("res://game/city/city_names.gd")

const MINI := 176.0 # lado del minimapa (px)
const MINI_R := 230.0 # metros que muestra de radio
const KIND_COL := {"dealer": Color(0.35, 0.65, 1.0), "garage": Color(1.0, 0.6, 0.15), "view": Color(1.0, 0.88, 0.3), "fuel": Color(0.95, 0.32, 0.28), "toll": Color(0.95, 0.95, 0.95), "parking": Color(0.30, 0.55, 0.95), "drift": Color(0.55, 0.85, 1.0)}
const KIND_ICON := {"dealer": "🚗", "garage": "🔧", "view": "⛰", "fuel": "⛽", "toll": "🛣", "parking": "🅿", "drift": "🌀"}

var city
var track
var gps
var region: RegionData # (o null)
var profile # perfil (para recordar si se ven o no las referencias del mapa)
var places: Array = [] # lugares de la región: {name, pos, kind, front}
var marks: Array = [] # carreras descubiertas del mundo abierto (city_events.gd): {pos, name, col}
var refs_on := true # referencias y lugares en el mapa (se oculta con el botón del mapa grande)
var avg_v := 25.0 # velocidad promedio (m/s) para el tiempo estimado de llegada
var eta_l: Label
var _map_tex: Texture2D
var _closed_tex: Texture2D # sombra de los sectores en obra (region/sectors.gd), 400 m por píxel
var segs: Array = [] # cada tramo: {box: Rect2, pts: PackedVector2Array, hw: float, kind: String}
var car_pos := Vector2.ZERO
var heading := 0.0 # yaw del auto (adelante = (sin, cos) en x, z)
var route := PackedVector2Array()
var route_len := 0.0
var route_name := ""
var dest := Vector2.ZERO
var has_dest := false
var big := false
var street_l: Label
var gps_l: Label
var _t := 0.0
var _off_t := 0.0
var _mini: Control
var _big: Control
var _toast_cb: Callable
var _exit_warned := {}
var arrive_r := 28.0 # a esta distancia del destino se da por llegado
var race_route := PackedVector2Array() # el recorrido de la carrera del mundo abierto que estás corriendo (city_events.gd): se dibuja grueso en el minimapa y en el mapa grande
var preview_route := PackedVector2Array() # el recorrido de la carrera marcada en el mapa grande (se ve antes de largar)
var _course := false # el GPS guía por el recorrido de la carrera (no por el camino más corto al final)
var seen_pois := {} # talleres, concesionarios y gomerías que ya pasaste de cerca: sólo esos están en el mapa (se descubren manejando; clave «c:id» o «r:x,z»)
var _disc_t := 0.0
const DISCOVER_R := 70.0

func setup(p_track, toast_cb: Callable, p_profile = null) -> void:
	track = p_track
	city = track.city
	_toast_cb = toast_cb
	profile = p_profile
	region = track.region if "region" in track else null
	gps = WorldGps.new(CityGps.new(city), region)
	if profile != null:
		refs_on = profile.setting("mapRefs") != false
		var sp: Variant = profile.setting("poiSeen")
		if sp is Array:
			for k in (sp as Array):
				seen_pois[str(k)] = true
	if region != null:
		for i in region.nodes.size():
			var n: Array = region.nodes[i]
			var kd := int(n[3])
			if kd >= 3 and kd <= 5:
				places.append({"name": str(n[4]), "pos": Vector2(float(n[1]), float(n[2])), "kind": ["ciudad", "pueblo", "villa"][kd - 3]})
		places.append({"name": "Dream City", "pos": Vector2.ZERO, "kind": "ciudad"})
		_map_tex = load("res://game/data/region/region_map.png") as Texture2D
		var Sectors := preload("res://game/region/sectors.gd")
		if not Sectors.all_open():
			var w := int(ceil(float(region.gw) * region.cell / 400.0))
			var h := int(ceil(float(region.gh) * region.cell / 400.0))
			var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			for iz in h:
				for ix in w:
					var q := Vector2(region.x0 + (float(ix) + 0.5) * 400.0, region.z0 + (float(iz) + 0.5) * 400.0)
					var hatch := ((ix + iz) % 4) < 2 # rayado: se ve que está «en obra», no que no existe
					img.set_pixel(ix, iz, Color(0, 0, 0, 0) if Sectors.is_open(q) else (Color(0.05, 0.05, 0.07, 0.62) if hatch else Color(0.05, 0.05, 0.07, 0.45)))
			_closed_tex = ImageTexture.create_from_image(img)
	for rd in city.roads:
		if str(rd["kind"]) in ["tunnel", "bay"] and not str(rd["name"]).begins_with("Entrada Estacionamiento"):
			continue # los túneles están ocultos y las entradas de los locales son muy cortas (la del estacionamiento sí se ve)
		var pts: PackedVector3Array = rd["pts"]
		var step := 3
		var i := 0
		while i < pts.size():
			var seg := PackedVector2Array()
			var j := i
			while j < mini(i + 20 * step + 1, pts.size()):
				seg.append(Vector2(pts[j].x, pts[j].z))
				j += step
			if seg.size() < 2 and j < pts.size() + step:
				seg.append(Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z))
			var lo := seg[0]
			var hi := seg[0]
			for q in seg:
				lo = lo.min(q)
				hi = hi.max(q)
			segs.append({"box": Rect2(lo, hi - lo).grow(12.0), "pts": seg, "hw": float(rd["hw"]), "kind": str(rd["kind"])})
			i += 20 * step
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini = MapView.new()
	(_mini as MapView).hud = self
	(_mini as MapView).big = false
	_mini.position = Vector2(14.0, 100.0)
	_mini.custom_minimum_size = Vector2(MINI, MINI)
	_mini.size = Vector2(MINI, MINI)
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_set_big(true))
	add_child(_mini)
	street_l = Kit.label("", 20, Color.WHITE)
	street_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	street_l.add_theme_constant_override("outline_size", 7)
	street_l.position = Vector2(14.0 + MINI + 8.0, 104.0)
	street_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(street_l)
	gps_l = Kit.label("", 18, Color(1.0, 0.8, 0.3))
	gps_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	gps_l.add_theme_constant_override("outline_size", 7)
	gps_l.position = Vector2(14.0 + MINI + 8.0, 134.0)
	gps_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gps_l)
	# nafta (barra bajo el minimapa) y hora
	fuel_l = Kit.label("", 16, Color.WHITE)
	fuel_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	fuel_l.add_theme_constant_override("outline_size", 6)
	fuel_l.position = Vector2(14.0, 100.0 + MINI + 6.0)
	fuel_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fuel_l)
	clock_l = Kit.label("", 16, Color(1.0, 0.92, 0.6))
	clock_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	clock_l.add_theme_constant_override("outline_size", 6)
	clock_l.position = Vector2(14.0, 100.0 + MINI + 44.0)
	clock_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_l)
	fuel_bar = ColorRect.new()
	fuel_bar.position = Vector2(14.0, 100.0 + MINI + 32.0)
	fuel_bar.size = Vector2(MINI, 7.0)
	fuel_bar.color = Color(0, 0, 0, 0.55)
	fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fuel_bar)
	fuel_fill = ColorRect.new()
	fuel_fill.position = Vector2(1.0, 1.0)
	fuel_fill.size = Vector2(MINI - 2.0, 5.0)
	fuel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_bar.add_child(fuel_fill)
	_build_big()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

var _fade: ColorRect
var fuel_l: Label
var tire_txt := "" # desgaste de las gomas (lo pone CityTires): se muestra junto a la nafta
var clock_l: Label
var fuel_bar: ColorRect
var fuel_fill: ColorRect

## Nafta: level 0..1; fill ≥ 0 mientras se está cargando (progreso de la carga)
func set_fuel(level: float, fill := -1.0) -> void:
	if fuel_l == null:
		return
	var col := Color(0.35, 0.9, 0.5) if level > 0.3 else (Color(1.0, 0.75, 0.2) if level > 0.15 else Color(1.0, 0.3, 0.3))
	if fill >= 0.0:
		col = Color(0.3, 0.8, 1.0)
		fuel_l.text = "⛽ %d%% · %s %d%%" % [roundi(level * 100.0), Tr.t("cargando"), roundi(fill * 100.0)]
	else:
		fuel_l.text = "⛽ %d%%" % roundi(level * 100.0) + (("  " + tire_txt) if tire_txt != "" else "")
	fuel_fill.size.x = (MINI - 2.0) * clampf(level, 0.0, 1.0)
	fuel_fill.color = col

## Fundido a negro (entrar a un taller o a un túnel): 0 = nada · 1 = negro
func set_fade(a: float) -> void:
	if _fade != null:
		_fade.color = Color(0, 0, 0, clampf(a, 0.0, 1.0))

func _build_big() -> void:
	_big = Control.new()
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_big.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(bg)
	var mv := MapView.new()
	mv.hud = self
	mv.big = true
	mv.name = "map"
	mv.clip_contents = true
	mv.mouse_filter = Control.MOUSE_FILTER_STOP
	mv.gui_input.connect(_big_input)
	_big.add_child(mv)
	var close := Kit.button(Tr.t("✕ CERRAR"), func() -> void: _set_big(false), true, 22, Vector2(170, 56))
	close.position = Vector2(16, 12)
	_big.add_child(close)
	var clear := Kit.button(Tr.t("QUITAR GPS"), func() -> void: _clear_dest(), false, 20, Vector2(190, 56))
	clear.position = Vector2(200, 12)
	_big.add_child(clear)
	var me_btn := Kit.button("🎯 " + Tr.t("MI AUTO"), func() -> void: _center_big(), false, 18, Vector2(150, 56))
	me_btn.position = Vector2(396, 12)
	_big.add_child(me_btn)
	var zin := Kit.button("＋", func() -> void: _zoom_big(1.5), false, 26, Vector2(60, 56))
	zin.position = Vector2(554, 12)
	_big.add_child(zin)
	var zout := Kit.button("－", func() -> void: _zoom_big(1.0 / 1.5), false, 26, Vector2(60, 56))
	zout.position = Vector2(618, 12)
	_big.add_child(zout)
	var refs := Kit.button(Tr.t("🏷 REFERENCIAS") + (" ✓" if refs_on else " ✕"), Callable(), false, 16, Vector2(190, 56))
	refs.position = Vector2(690, 12)
	refs.name = "refs"
	refs.pressed.connect(func() -> void:
		refs_on = not refs_on
		refs.text = Tr.t("🏷 REFERENCIAS") + (" ✓" if refs_on else " ✕")
		if profile != null:
			profile.set_setting("mapRefs", refs_on)
		(_big.get_node("map") as Control).queue_redraw()
		_mini.queue_redraw())
	_big.add_child(refs)
	var hint := Kit.label(Tr.t("Tocá un lugar para ir con el GPS · arrastrá para mover · dos dedos para el zoom"), 18, Kit.MUTED)
	hint.position = Vector2(16, 76)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(hint)
	add_child(_big)
	_layout_big()

func _layout_big() -> void:
	var vs := get_viewport_rect().size
	var mv: Control = _big.get_node("map")
	var side := minf(vs.x * 0.62, vs.y - 24.0)
	mv.size = Vector2(side, side)
	mv.position = Vector2(vs.x - side - 14.0, (vs.y - side) * 0.5)

func _set_big(on: bool) -> void:
	big = on
	_big.visible = on
	_mini.visible = not on
	street_l.visible = not on
	gps_l.visible = not on
	if on:
		_layout_big()
		_center_big()
		(_big.get_node("map") as Control).queue_redraw()

## En la pausa se esconde el minimapa y el GPS (se veían tapando el menú)
func set_paused(on: bool) -> void:
	if on:
		_mini.visible = false
		street_l.visible = false
		gps_l.visible = false
		_big.visible = false
	else:
		_set_big(big)

var _tp := {} # dedos apoyados en el mapa grande: índice -> posición
var _pinch_d := 0.0
var _pressing := false
var _moved := 0.0

func _center_big() -> void:
	var mv: MapView = _big.get_node("map")
	mv.pan = car_pos
	mv.zoom = 2.2 if (region == null or car_pos.length() < 2800.0) else 0.5
	mv.queue_redraw()

## Prueba: zoom y centro del mapa grande
func test_view(z: float, c: Vector2) -> void:
	var mv: MapView = _big.get_node("map")
	mv.zoom = z
	mv.pan = c
	mv.queue_redraw()

func _zoom_big(f: float) -> void:
	var mv: MapView = _big.get_node("map")
	mv.zoom_by(f, mv.size * 0.5)

## Mapa grande: un toque elige el destino; arrastrar con un dedo lo mueve; con dos dedos (pinza) o la rueda se acerca y se aleja
func _big_input(e: InputEvent) -> void:
	var mv: MapView = _big.get_node("map")
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_tp[st.index] = st.position
		else:
			_tp.erase(st.index)
		_pinch_d = 0.0
		if _tp.size() >= 2:
			_moved = 999.0 # con dos dedos nunca es un toque
		return
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		_tp[sd.index] = sd.position
		if _tp.size() >= 2:
			var ks := _tp.keys()
			var pa: Vector2 = _tp[ks[0]]
			var pb: Vector2 = _tp[ks[1]]
			var d := pa.distance_to(pb)
			if _pinch_d > 8.0 and d > 8.0:
				mv.zoom_by(d / _pinch_d, (pa + pb) * 0.5)
			_pinch_d = d
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			mv.zoom_by(1.25, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			mv.zoom_by(0.8, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_moved = 0.0
			else:
				if _pressing and _moved < 14.0 and _tp.size() < 2:
					_pick(mb.position)
				_pressing = false
		return
	if e is InputEventMouseMotion and _pressing and _tp.size() < 2:
		var mm := e as InputEventMouseMotion
		_moved += mm.relative.length()
		if _moved >= 14.0:
			mv.pan_by(mm.relative)

func _pick(p: Vector2) -> void:
	var mv: MapView = _big.get_node("map")
	var w := mv.to_world(p)
	# un lugar de la lista si el toque cae cerca
	var best := -1
	var bd := 34.0 / mv.scale_px()
	for i in city.pois.size():
		if city.pois[i].get("region", false) or not poi_known(city.pois[i]):
			continue # los de la región se eligen más abajo; los talleres que todavía no pasaste no están en el mapa
		var d: float = (city.pois[i]["pos"] as Vector2).distance_to(w)
		if d < bd:
			bd = d
			best = i
	# una carrera descubierta (va primero: es lo que se busca en el mapa)
	var bm := 30.0 / mv.scale_px()
	for mk in marks:
		if (mk["pos"] as Vector2).distance_to(w) < bm:
			if mk.get("unk", false) == true:
				set_dest(mk["pos"], Tr.t("❓ Carrera por descubrir"))
			else:
				set_dest(mk["pos"], str(mk["name"]))
				if mk.has("route"):
					preview_route = mk["route"] # el recorrido de esa carrera, en el mapa
				if _toast_cb.is_valid() and mk.has("info"):
					_toast_cb.call(str(mk["info"]))
			_set_big(false)
			return
	# un lugar de la región (ciudad, pueblo, villa, estación o gomería)
	var rb := ""
	var rpos := Vector2.ZERO
	if refs_on and region != null:
		var bd2 := 34.0 / mv.scale_px()
		for pl in places:
			var dd: float = (pl["pos"] as Vector2).distance_to(w)
			if dd < bd2 and (str(pl["kind"]) != "villa" or mv.view_m() < 9000.0) and (str(pl["kind"]) != "pueblo" or mv.view_m() < 45000.0):
				bd2 = dd
				rb = CityNames.t(str(pl["name"]))
				rpos = pl["pos"]
		if mv.view_m() < 14000.0:
			for pp in region.pois:
				if not region_poi_known(pp):
					continue
				var pv := Vector2(float(pp["x"]), float(pp["z"]))
				var dd2 := pv.distance_to(w)
				if dd2 < bd2:
					bd2 = dd2
					rb = CityNames.t(str(pp["name"]))
					rpos = pv
		if rb != "" and (best < 0 or bd2 < bd):
			set_dest(rpos, rb)
			_set_big(false)
			return
	if best >= 0:
		set_dest(city.pois[best]["front"], CityNames.t(str(city.pois[best]["name"])))
	else:
		set_dest(w, Tr.t("el punto elegido"))
	_set_big(false)

func set_dest(p: Vector2, nm: String, quiet := false) -> void:
	if _course:
		return # (durante una carrera el GPS es el recorrido)
	preview_route = PackedVector2Array()
	dest = p
	has_dest = true
	route_name = nm
	_reroute()
	if _toast_cb.is_valid() and not quiet: # (quiet: un destino que se mueve, como el auto de la Caza recompensas)
		_toast_cb.call(Tr.t("📍 GPS: %s") % nm)

func clear_dest() -> void:
	_clear_dest()

## Carrera del mundo abierto: el GPS guía por el recorrido (no por el camino más corto hasta el final: en un circuito el final es la largada) y el mapa lo dibuja entero
func set_course(pts: PackedVector2Array, nm: String) -> void:
	race_route = pts
	_course = true
	has_dest = pts.size() > 1
	route_name = nm
	route = pts.duplicate()
	if has_dest:
		dest = pts[pts.size() - 1]
	_mini.queue_redraw()

## Dónde va el auto en el recorrido (índice): el GPS sigue desde ahí; en un circuito, dando la vuelta
func course_at(i: int, loop: bool) -> void:
	if not _course or race_route.size() < 2:
		return
	i = clampi(i, 0, race_route.size() - 2)
	var r := race_route.slice(i)
	if loop:
		r.append_array(race_route.slice(0, i + 1))
	route = r

func clear_course() -> void:
	race_route = PackedVector2Array()
	if _course:
		_course = false
		_clear_dest()

func _clear_dest() -> void:
	preview_route = PackedVector2Array()
	if _course:
		return # (una carrera en curso se quita con clear_course)
	has_dest = false
	route = PackedVector2Array()
	gps_l.text = ""
	_mini.queue_redraw()
	(_big.get_node("map") as Control).queue_redraw()

func _reroute() -> void:
	var r: Dictionary = gps.route(car_pos, dest)
	route = r["pts"]
	route_len = float(r["len"])
	if route.is_empty():
		has_dest = false
		gps_l.text = Tr.t("GPS: no hay camino")

## La nafta y la hora van arriba, al lado del velocímetro (lejos del volante y de los pedales)
func _layout_fuel() -> void:
	if fuel_l == null:
		return
	var cx := get_viewport_rect().size.x * 0.5 + 190.0
	fuel_l.position = Vector2(cx, 34.0)
	fuel_bar.position = Vector2(cx, 62.0)
	clock_l.position = Vector2(cx, 74.0)

var _big_t := 0.0

## Nombre de la ruta de la región donde está el auto y hacia dónde va: «AU-3 → Santa Aurora · 23 km»
func _region_street() -> String:
	var rp: PackedFloat64Array = region.probe(car_pos.x, car_pos.y, 40.0, false) # sólo calles: dentro de una estación o gomería la sonda con playones devuelve el playón (índice negativo)
	if rp[0] < -22.0 or int(rp[1]) < 0:
		return ""
	var ei := int(rp[1])
	var k := int(rp[2])
	var cls := region.edge_cls(ei)
	if cls == "calle":
		var best := ""
		var bd := 500.0
		for pl in places:
			var d: float = (pl["pos"] as Vector2).distance_to(car_pos)
			if d < bd:
				bd = d
				best = CityNames.t(str(pl["name"]))
		return ("%s %s" % [Tr.t("Calle de"), best]) if best != "" else Tr.t("Calle")
	var nm := region.edge_name(ei)
	var a := region.edge_point(ei, k - int((region.edges[ei] as Array)[6]))
	var b := region.edge_point(ei, mini(k - int((region.edges[ei] as Array)[6]) + 1, region.edge_n(ei) - 1))
	var fwd := (b - a).dot(Vector2(sin(heading), cos(heading))) >= 0.0
	var s := region.arc_at(ei, k, float(rp[3]))
	var dst: Array = region.edge_dest(ei, s, fwd)
	var txt := nm
	if str(dst[0]) != "":
		var dkm := float(dst[1]) / 1000.0
		txt += " → %s · %s" % [CityNames.t(str(dst[0])), (("%.1f km" % dkm) if dkm >= 1.0 else ("%d m" % int(round(float(dst[1]) / 10.0) * 10.0)))]
	return txt

## ¿Este lugar ya está en el mapa? Las estaciones de servicio, los peajes y las ciudades siempre; los talleres, concesionarios y gomerías, después de pasar de cerca
## (pedido del dueño, 19/10/2026: «si cruzo por el taller, ya se me registra en el mapa; no hace falta que me muestre todo de entrada»)
func poi_known(p: Dictionary) -> bool:
	return str(p.get("shop", "")) == "" or seen_pois.has("c:" + str(p["id"]))

func region_poi_known(p: Dictionary) -> bool:
	return str(p.get("kind", "")) != "tires" or seen_pois.has(_rkey(p))

static func _rkey(p: Dictionary) -> String:
	return "r:%d,%d" % [int(float(p["x"])), int(float(p["z"]))]

## Cada medio segundo: ¿pasaste a menos de DISCOVER_R de un taller, concesionario o gomería que no conocías? Queda en el mapa, en silencio (sin carteles).
func _discover() -> void:
	var found := false
	for p in city.pois:
		if str(p.get("shop", "")) == "" or p.get("region", false) or poi_known(p):
			continue
		if (p["pos"] as Vector2).distance_to(car_pos) < DISCOVER_R:
			seen_pois["c:" + str(p["id"])] = true
			found = true
	if region != null:
		for p in region.pois:
			if str(p["kind"]) != "tires" or region_poi_known(p):
				continue
			if absf(float(p["x"]) - car_pos.x) < DISCOVER_R and absf(float(p["z"]) - car_pos.y) < DISCOVER_R and Vector2(float(p["x"]), float(p["z"])).distance_to(car_pos) < DISCOVER_R:
				seen_pois[_rkey(p)] = true
				found = true
	if found:
		_save_seen()
		_mini.queue_redraw()
		(_big.get_node("map") as Control).queue_redraw()

func _save_seen() -> void:
	if profile != null and profile.has_method("set_setting"):
		profile.set_setting("poiSeen", seen_pois.keys())

func update_hud(dt: float, car) -> void:
	car_pos = Vector2(car.phys.px, car.phys.pz)
	heading = car.phys.yaw
	_disc_t += dt
	if _disc_t > 0.5:
		_disc_t = 0.0
		_discover()
	_t += dt
	if _t < 0.06:
		return
	_layout_fuel()
	var step := _t
	_t = 0.0
	_mini.queue_redraw()
	_big_t += step
	if big and _big_t > 0.25:
		_big_t = 0.0
		(_big.get_node("map") as Control).queue_redraw() # (el mapa grande cuesta más: se redibuja 4 veces por segundo)
	var spd := sqrt(car.phys.vx * car.phys.vx + car.phys.vz * car.phys.vz)
	avg_v = lerpf(avg_v, maxf(spd, 14.0), clampf(step * 0.25, 0.0, 1.0))
	var loc: Dictionary = city.locate(car_pos.x, car_pos.y)
	if int(loc["road"]) >= 0 or str(loc["name"]) != "":
		street_l.text = "%s · %s %d" % [CityNames.t(str(loc["name"])), Tr.t("cuadra"), int(loc["cuadra"])]
	elif region != null and _region_street() != "":
		street_l.text = _region_street()
	else:
		street_l.text = Tr.t("Fuera de calle")
	for ex in city.exits:
		if _exit_warned.has(ex["num"]) or car_pos.distance_to(ex["pos"]) >= 140.0:
			continue
		_exit_warned[ex["num"]] = true
		if not _toast_cb.is_valid():
			continue
		if str(ex.get("to", "")) == "plaza":
			_toast_cb.call(Tr.t("%s: seguí derecho hasta la Plaza de Drift") % CityNames.t(str(ex["name"])))
		elif str(ex.get("to", "")) != "":
			_toast_cb.call(Tr.t("%s: seguí derecho para salir de la ciudad") % CityNames.t(str(ex["name"])))
		else:
			_toast_cb.call(Tr.t("%s: esa ciudad abre en la próxima actualización") % CityNames.t(str(ex["name"])))
	if has_dest and _course:
		_gps_text()
	elif has_dest:
		_off_t += step
		_trim_route()
		_gps_text()
		var to_dest := car_pos.distance_to(dest)
		if to_dest < arrive_r:
			if _toast_cb.is_valid():
				_toast_cb.call(Tr.t("🏁 ¡Llegaste a %s!") % route_name)
			_clear_dest()
			return
		if _off_t > 1.2 and _route_dist() > 24.0:
			_off_t = 0.0
			_reroute()

## La línea del GPS arranca en el auto: lo que ya pasaste se borra a medida que avanzás
func _trim_route() -> void:
	if route.size() < 3:
		return
	var bi := 0
	var bd := 1e9
	for i in mini(route.size(), 40):
		var d := route[i].distance_to(car_pos)
		if d < bd:
			bd = d
			bi = i
	if bi >= 1 and bd < 40.0:
		route = route.slice(bi)
	if route.size() > 1 and bd < 40.0:
		route[0] = car_pos

## distancia del auto al punto más cercano de la ruta
func _route_dist() -> float:
	var bd := 1e9
	for q in route:
		bd = minf(bd, q.distance_to(car_pos))
	return bd

func _gps_text() -> void:
	if route.size() < 2:
		return
	var bi := 0
	var bd := 1e9
	for i in route.size():
		var d := route[i].distance_to(car_pos)
		if d < bd:
			bd = d
			bi = i
	var left := 0.0
	for i in range(bi, route.size() - 1):
		left += route[i].distance_to(route[i + 1])
	# próxima curva: el primer cambio de rumbo grande más adelante
	var turn := ""
	var turn_d := 0.0
	var acc := 0.0
	var i := bi
	while i + 3 < route.size() and acc < 600.0:
		var a := (route[i + 1] - route[i]).normalized()
		var b := (route[i + 3] - route[i + 2]).normalized()
		var ang := rad_to_deg(a.angle_to(b))
		acc += route[i].distance_to(route[i + 1])
		if absf(ang) > 38.0:
			turn = Tr.t("↱ Doblá a la derecha") if ang > 0.0 else Tr.t("↰ Doblá a la izquierda")
			turn_d = acc
			break
		i += 1
	var dist_txt := ("%d m" % int(round(left / 10.0) * 10.0)) if left < 1000.0 else ("%.1f km" % (left / 1000.0))
	var eta_s := left / maxf(avg_v, 14.0)
	var eta_txt := ("%d s" % int(round(eta_s / 5.0) * 5.0)) if eta_s < 90.0 else (("%d min" % int(round(eta_s / 60.0))) if eta_s < 3600.0 else ("%d h %02d min" % [int(eta_s / 3600.0), int(fmod(eta_s, 3600.0) / 60.0)]))
	if turn != "":
		gps_l.text = "%s · %d m\n%s %s · %s" % [turn, int(round(turn_d / 10.0) * 10.0), route_name, dist_txt, eta_txt]
	else:
		gps_l.text = "%s\n%s %s · %s" % [Tr.t("Seguí derecho"), route_name, dist_txt, eta_txt]

## Un mapa: el chico gira con el auto y el grande es fijo con el norte arriba
class MapView extends Control:
	var hud
	var big := false

	var zoom := 1.0 # solo el mapa grande
	var pan := Vector2.ZERO # punto del mundo que queda en el centro del mapa grande

	func scale_px() -> float:
		if big:
			return minf(size.x, size.y) / 2600.0 * zoom
		return size.x * 0.5 / MINI_R

	## ancho (m) que muestra el mapa grande
	func view_m() -> float:
		return minf(size.x, size.y) / maxf(scale_px(), 1e-6) if big else MINI_R * 2.0

	func zoom_by(f: float, at: Vector2) -> void:
		var w0 := to_world(at)
		zoom = clampf(zoom * f, 0.012 if hud.region != null else 0.45, 16.0)
		pan = w0 - (at - size * 0.5) / scale_px() # el punto bajo los dedos no se mueve
		_clamp_pan()
		queue_redraw()

	func pan_by(rel: Vector2) -> void:
		pan -= rel / scale_px()
		_clamp_pan()
		queue_redraw()

	func _clamp_pan() -> void:
		if hud.region != null:
			pan = pan.clamp(Vector2(hud.region.x0, hud.region.z0), Vector2(hud.region.x0 + float(hud.region.gw) * hud.region.cell, hud.region.z0 + float(hud.region.gh) * hud.region.cell))
		else:
			pan = pan.clamp(Vector2(-3200.0, -3200.0), Vector2(3200.0, 3200.0))

	## mundo → pantalla del control
	func _xf() -> Transform2D:
		var s := scale_px()
		var ctr := size * 0.5
		if big:
			return Transform2D(Vector2(s, 0.0), Vector2(0.0, s), ctr - pan * s)
		var f := Vector2(sin(hud.heading), cos(hud.heading))
		var xa := Vector2(-f.y, -f.x) * s
		var ya := Vector2(f.x, -f.y) * s
		var cp: Vector2 = hud.car_pos
		return Transform2D(xa, ya, ctr - (xa * cp.x + ya * cp.y))

	func to_world(p: Vector2) -> Vector2:
		return _xf().affine_inverse() * p

	## ciudades, pueblos y villas de la región con su nombre, y las estaciones, gomerías y peajes cuando se ve de cerca
	func _draw_region_places(xf: Transform2D, f: Font) -> void:
		var vm := view_m()
		var rect := Rect2(Vector2.ZERO, size).grow(14.0)
		for pl in hud.places:
			var kd := str(pl["kind"])
			if kd == "villa" and (not big or vm > 9000.0):
				continue
			if kd == "pueblo" and (not big or vm > 45000.0):
				continue
			var sp: Vector2 = xf * (pl["pos"] as Vector2)
			if not rect.has_point(sp):
				continue
			var rad := 9.0 if kd == "ciudad" else (6.5 if kd == "pueblo" else 4.5)
			draw_circle(sp, rad + 2.0, Color(0, 0, 0, 0.75))
			draw_circle(sp, rad, Color(1.0, 0.92, 0.45) if kd == "ciudad" else (Color(0.95, 0.95, 0.95) if kd == "pueblo" else Color(0.75, 0.85, 0.95)))
			if big:
				var fs := 21 if kd == "ciudad" else (17 if kd == "pueblo" else 14)
				var nm := CityNames.t(str(pl["name"]))
				draw_string_outline(f, sp + Vector2(rad + 5.0, 6.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85))
				draw_string(f, sp + Vector2(rad + 5.0, 6.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if vm < 14000.0:
			for p in hud.region.pois:
				if not hud.region_poi_known(p):
					continue
				var sp2: Vector2 = xf * Vector2(float(p["x"]), float(p["z"]))
				if not rect.has_point(sp2):
					continue
				var col := Color(0.95, 0.32, 0.28) if str(p["kind"]) == "fuel" else Color(1.0, 0.6, 0.15)
				draw_circle(sp2, 6.0, Color(0, 0, 0, 0.7))
				draw_circle(sp2, 4.2, col)
			for t in hud.region.tolls:
				var sp3: Vector2 = xf * Vector2(float(t["x"]), float(t["z"]))
				if rect.has_point(sp3):
					draw_rect(Rect2(sp3 - Vector2(5, 5), Vector2(10, 10)), Color(0.95, 0.95, 0.95))

	const REG_COL := [Color(0.98, 0.98, 0.98), Color(0.98, 0.98, 0.98), Color(0.94, 0.93, 0.86), Color(0.98, 0.90, 0.58), Color(0.88, 0.80, 0.62), Color(0.72, 0.56, 0.40), Color(0.97, 0.68, 0.84), Color(0.82, 0.82, 0.84), Color(0.94, 0.93, 0.86)]
	const REG_PX := [5.5, 5.5, 4.2, 3.4, 2.8, 2.4, 3.0, 2.0, 3.6] # grosor mínimo en píxeles por clase (anillo, autopista, ruta, provincial, camino, tierra, montaña, calle, conector)

	## Las rutas de la región: en el mapa grande por calle (decimadas si se ve mucho), en el chico los tramos de las celdas cercanas
	func _draw_region(view_w: Rect2, s: float) -> void:
		var rg = hud.region
		if big:
			var vm := view_m()
			var step := 1 if vm < 1800.0 else (4 if vm < 9000.0 else 0)
			if step == 0:
				return # el mapa de afuera ya trae las rutas dibujadas
			for pass_i in 2:
				for ei in rg.edges.size():
					var cls := int((rg.edges[ei] as Array)[2])
					if cls == 7 and vm > 3000.0:
						continue
					if not view_w.intersects(rg.edge_box(ei)):
						continue
					var poly: PackedVector2Array = rg.edge_poly(ei, step)
					var wpx := maxf(float(rg.e_hw[ei]) * 2.0, float(REG_PX[cls]) / s) + (3.0 / s if pass_i == 0 else 0.0)
					draw_polyline(poly, Color(0.12, 0.14, 0.18, 0.95) if pass_i == 0 else REG_COL[cls], wpx, false)
		else:
			var kx0 := int(floor(view_w.position.x / 128.0))
			var kx1 := int(floor(view_w.end.x / 128.0))
			var kz0 := int(floor(view_w.position.y / 128.0))
			var kz1 := int(floor(view_w.end.y / 128.0))
			var segs: Array = [[], []]
			var seen := {}
			for cx in range(kx0, kx1 + 1):
				for cz in range(kz0, kz1 + 1):
					var lst: Variant = rg.cells.get(Vector2i(cx, cz))
					if lst == null:
						continue
					for k in (lst as PackedInt32Array):
						if seen.has(k):
							continue
						seen[k] = true
						var a := Vector2(float(rg.pts[k * 2]) * 0.1, float(rg.pts[k * 2 + 1]) * 0.1)
						var b := Vector2(float(rg.pts[k * 2 + 2]) * 0.1, float(rg.pts[k * 2 + 3]) * 0.1)
						var cls := int((rg.edges[rg.pe[k]] as Array)[2])
						draw_line(a, b, Color(0.92, 0.94, 0.97, 0.9), maxf(float(rg.e_hw[rg.pe[k]]) * 2.0 + 3.0, 4.2 / s), false)
						draw_line(a, b, REG_COL[cls].darkened(0.35), maxf(float(rg.e_hw[rg.pe[k]]) * 2.0, 3.2 / s), false)

	func _draw() -> void:
		if hud == null or hud.city == null:
			return
		var s := scale_px()
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.10, 0.13, 0.17, 0.80) if not big else Color(0.12, 0.16, 0.20, 1.0), true)
		var xf := _xf()
		# el mar (al sur de la costa) en el mapa grande y en el chico
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var view_w := Rect2(to_world(Vector2.ZERO), Vector2.ZERO)
		for q in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]:
			view_w = view_w.expand(to_world(q))
		view_w = view_w.grow(6.0)
		draw_set_transform_matrix(xf)
		if hud.region != null and big and hud._map_tex != null:
			# el relieve de toda la región (una imagen: 1 píxel = 100 m)
			draw_texture_rect(hud._map_tex, Rect2(hud.region.x0, hud.region.z0, float(hud.region.gw) * hud.region.cell, float(hud.region.gh) * hud.region.cell), false)
			if hud._closed_tex != null:
				draw_texture_rect(hud._closed_tex, Rect2(hud.region.x0, hud.region.z0, float(hud._closed_tex.get_width()) * 400.0, float(hud._closed_tex.get_height()) * 400.0), false)
		else:
			var sea := PackedVector2Array([Vector2(-5000.0, 1260.0), Vector2(5000.0, 1260.0), Vector2(5000.0, 5000.0), Vector2(-5000.0, 5000.0)])
			draw_colored_polygon(sea, Color(0.16, 0.34, 0.50, 0.9))
		if hud.region != null:
			_draw_region(view_w, s)
		# calles: primero un borde claro y encima el asfalto
		for pass_i in 2:
			for sg in hud.segs:
				if not view_w.intersects(sg["box"]):
					continue
				var hw: float = sg["hw"]
				var wpx := maxf(hw * 2.0 + (3.0 if pass_i == 0 else 0.0), (4.5 if big else 3.0) / s)
				if not big:
					wpx = maxf(wpx, 3.2 / s)
				var col := Color(0.92, 0.94, 0.97, 0.9) if pass_i == 0 else (Color(0.42, 0.46, 0.54) if str(sg["kind"]) in ["rural", "hill", "scenic"] else Color(0.30, 0.34, 0.42))
				draw_polyline(sg["pts"], col, wpx if big else minf(wpx, 11.0 / s), false)
		if hud.preview_route.size() > 1:
			draw_polyline(hud.preview_route, Color(0.05, 0.12, 0.2, 0.9), 14.0 / s, false)
			draw_polyline(hud.preview_route, Color(0.35, 0.95, 0.55), 8.0 / s, false)
		if hud.race_route.size() > 1: # la pista de la carrera: verde y gruesa, y el GPS (naranja) va encima
			draw_polyline(hud.race_route, Color(0.05, 0.12, 0.2, 0.95), 16.0 / s, false)
			draw_polyline(hud.race_route, Color(0.35, 0.95, 0.55), 10.0 / s, false)
		elif hud.has_dest and hud.route.size() > 1:
			draw_polyline(hud.route, Color(0.05, 0.12, 0.2, 0.9), 12.0 / s, false)
			draw_polyline(hud.route, Color(1.0, 0.72, 0.1), 7.0 / s, false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# lugares
		var f := ThemeDB.fallback_font
		if hud.region != null and hud.refs_on:
			_draw_region_places(xf, f)
		for p in (hud.city.pois if (hud.refs_on and (not big or view_m() < 6000.0)) else []):
			if p.get("region", false) or not hud.poi_known(p):
				continue
			var sp: Vector2 = xf * (p["pos"] as Vector2)
			if not Rect2(Vector2.ZERO, sz).grow(12.0).has_point(sp):
				continue
			var col: Color = KIND_COL.get(str(p["kind"]), Color.WHITE)
			draw_circle(sp, 9.0 if big else 6.5, Color(0, 0, 0, 0.7))
			draw_circle(sp, 7.0 if big else 5.0, col)
			if big:
				draw_string(f, sp + Vector2(12.0, 6.0), CityNames.t(str(p["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		for mk in hud.marks: # carreras descubiertas: bandera de color (verde = ya ganada); por descubrir: «?» chico
			var spm: Vector2 = xf * (mk["pos"] as Vector2)
			if not Rect2(Vector2.ZERO, sz).grow(12.0).has_point(spm):
				continue
			if mk.get("unk", false) == true:
				draw_circle(spm, 8.0 if big else 6.0, Color(0, 0, 0, 0.7))
				draw_circle(spm, 6.5 if big else 4.5, mk["col"])
				if big:
					draw_string(f, spm + Vector2(-4.0, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.05, 0.08, 0.15))
				continue
			draw_rect(Rect2(spm - Vector2(7, 7), Vector2(14, 14)), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(spm - Vector2(5, 5), Vector2(10, 10)), mk["col"])
			if big and view_m() < 30000.0:
				draw_string_outline(f, spm + Vector2(10.0, 5.0), str(mk["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.85))
				draw_string(f, spm + Vector2(10.0, 5.0), str(mk["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, mk["col"])
		for ex in (hud.city.exits if (not big or view_m() < 6000.0) else []):
			var sp: Vector2 = xf * (ex["pos"] as Vector2)
			if Rect2(Vector2.ZERO, sz).grow(12.0).has_point(sp):
				draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(0.3, 0.9, 0.5))
				if big:
					draw_string(f, sp + Vector2(10.0, 5.0), CityNames.t(str(ex["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.7))
		if hud.has_dest:
			var dp: Vector2 = xf * (hud.dest as Vector2)
			if Rect2(Vector2.ZERO, sz).grow(12.0).has_point(dp):
				draw_circle(dp, 9.0, Color(1, 0.25, 0.2))
				draw_circle(dp, 4.0, Color.WHITE)
		# el auto: en el chico siempre en el centro mirando hacia arriba; en el grande en su lugar y rotado
		var me: Vector2 = xf * (hud.car_pos as Vector2)
		var fwd := Vector2(0.0, -1.0) # en el mapa grande: x al este, z al sur (en pantalla y crece hacia el sur)
		if big:
			fwd = Vector2(sin(hud.heading), cos(hud.heading))
		var rgt := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([me + fwd * 11.0, me - fwd * 7.0 + rgt * 7.0, me - fwd * 3.0, me - fwd * 7.0 - rgt * 7.0])
		draw_colored_polygon(tri, Color(1.0, 0.5, 0.1))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color.WHITE, 1.6, true)
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.35), false, 2.0)
		if not big:
			# la N del norte, girando con el mapa
			var nrm: Vector2 = xf * (hud.car_pos + Vector2(0.0, -MINI_R * 0.8))
			draw_string(f, nrm - Vector2(5.0, -6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.45, 0.4))
