extends Node3D
## El mundo de Dream City, todo en papel y cargado por cuadras: solo existen las cuadras (de 160 m) que están cerca de la cámara; cuando te alejás se borran y cuando te
## acercás se arman (como mucho una por cuadro, para que no haya tirones). Cada cuadra es un puñado de mallas: el terreno, las calles con sus veredas y rayas, y los edificios
## (cajas de pocas caras; las ventanas las dibuja el shader fx/city_facade.gdshader). Nada lejano se dibuja: hay niebla y un horizonte pintado.

const SIGNAL_SHADER := preload("res://game/fx/city_signal.gdshader")
const WorldSurfaces := preload("res://game/world/world_surfaces.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const CityProps := preload("res://game/city/city_props.gd")
const TerrainCap := preload("res://game/world/terrain_cap.gd")
const PieceBatch := preload("res://game/city/piece_batch.gd")
const TreeSprites := preload("res://game/city/tree_sprites.gd")
const HorizonTrees := preload("res://game/city/horizon_trees.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CityNames := preload("res://game/city/city_names.gd")
const FACADE := preload("res://game/fx/city_facade.gdshader")
const TEX := "res://game/models/paper/tex/"

var track # CityTrack
var city: CityLayout
var chunks: Dictionary = {} # Vector2i -> Node3D
var radius := 3 # cuadras a la redonda que se mantienen armadas
var view_k := 1.0:
	set(v):
		view_k = v
		if region_world != null:
			region_world.view_k = v
		if _facade_mat != null: # las fachadas pierden el detalle más cerca cuando el teléfono baja la distancia de vista
			_facade_mat.set_shader_parameter("lod_from", 200.0 * maxf(v, 0.6))
			_facade_mat.set_shader_parameter("lod_to", 270.0 * maxf(v, 0.6))
var built_total := 0
var region_world: Node3D # RegionWorld: el terreno y las rutas de más allá de la ciudad
var _facade_mat: ShaderMaterial
var glow_mat: StandardMaterial3D = make_glow_material() # luces de noche (ver _glow_instance)
var signal_mat: ShaderMaterial # lámparas de los semáforos (fx/city_signal.gdshader): el color sale de la hora del mundo
var signals: RefCounted # TrafficSignals
var glow_on := false # las luces de la calle están encendidas (las cuadras nuevas nacen con este estado)
var _tunnel_mat: StandardMaterial3D # el interior de los túneles y del estacionamiento: sin luz del sol (pintado), con franjas y lámparas
var _queue: Array = []
var _frame_budget_ms := 6.0
## Interruptores del menú de diagnóstico (ui/diag_panel.gd): true = el sistema está como siempre. Apagar uno sólo hace que no se dibuje (ni choque) lo suyo; nada más cambia.
var diag := {"trees": true, "buildings": true, "veg": true, "decor": true, "asphalt": true, "dirt": true, "terrain": true, "horizon": true}
var _diag_base_todo: Array = [] # cuadras cuya malla base (terreno + calles) falta rearmar tras un cambio de asfalto / tierra / terreno
var _diag_todo: Array = [] # cuadras que faltan rearmar tras un cambio de interruptor (unas pocas por cuadro)
const DIAG_VEG := [CityProps.FLOWERS, CityProps.BUSH, CityProps.GRASS]
const DIAG_DECOR := [CityProps.LAMP, CityProps.LIGHT, CityProps.BOLLARD, CityProps.FENCE, CityProps.PFENCE, CityProps.STOP, CityProps.CURVE, CityProps.LIMIT]

class Soup:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	## cuadrilátero que mira hacia arriba (si quedó al revés, se da vuelta)
	func quad_up(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color) -> void:
		if (b - a).cross(cc - a).y < 0.0:
			quad(a, d, cc, b, col)
		else:
			quad(a, b, cc, d, col)
	## cuadrilátero que mira hacia "out" (en el plano horizontal)
	func quad_out(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, out: Vector2, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, u2: Vector2) -> void:
		var nr := (b - a).cross(cc - a)
		if nr.x * out.x + nr.z * out.y < 0.0:
			quad(a, d, cc, b, col, ua, ud, uc, ub, u2)
		else:
			quad(a, b, cc, d, col, ua, ub, uc, ud, u2)
	## cuadrilátero (a b c d en orden, visto desde el lado de la normal)
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO, u2 := Vector2.ZERO) -> void:
		tri(a, b, cc, col, ua, ub, uc, u2)
		tri(a, cc, d, col, ua, uc, ud, u2)
	func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, u2 := Vector2.ZERO) -> void:
		# la normal (a×b×c) apunta hacia afuera de la cara; Godot toma como frente el sentido horario, así que los vértices van en orden a, c, b
		var nr := (b - a).cross(cc - a).normalized()
		v.append_array(PackedVector3Array([a, cc, b]))
		n.append_array(PackedVector3Array([nr, nr, nr]))
		for i in 3:
			c.append(col)
		uv.append_array(PackedVector2Array([ua, uc, ub]))
		uv2.append_array(PackedVector2Array([u2, u2, u2]))

func setup(p_track) -> void:
	track = p_track
	city = track.city
	_facade_mat = ShaderMaterial.new()
	_facade_mat.shader = FACADE
	_facade_mat.set_shader_parameter("grain", PaperKit.grain())
	_facade_mat.set_shader_parameter("lod_from", 200.0 * maxf(view_k, 0.6))
	_facade_mat.set_shader_parameter("lod_to", 270.0 * maxf(view_k, 0.6))
	_tunnel_mat = StandardMaterial3D.new()
	_tunnel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tunnel_mat.vertex_color_use_as_albedo = true
	_tunnel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_plane()
	_horizon()
	_drift_disc()
	_route_signs()

## Un plano enorme y plano bajo todo el mundo (el color de la lejanía): lo que todavía no se armó no deja un hueco
func _ground_plane() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30000, 30000)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.66, 0.50)
	m.roughness = 1.0
	mi.material_override = m
	mi.position = Vector3(0, -6.5, 0) # más abajo que el subsuelo del Estacionamiento Central
	mi.extra_cull_margin = 100000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var sea := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(6000, 12000) # sólo bajo la ciudad: más allá (x > 3000) está el bolsillo de los túneles y los estacionamientos
	sea.mesh = pm2
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.20, 0.52, 0.70)
	sm.roughness = 0.6
	sea.material_override = sm
	sea.position = Vector3(0, 0.0, CityLayout.SEA_Z + 6000.0 + 40.0)
	sea.extra_cull_margin = 100000.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

var _hz: MeshInstance3D
var _hz_trees: Array[MeshInstance3D] = []

## Falso horizonte: dos anillos de lomas de papel (una más lejana y clara, otra más cerca y verde) que acompañan a la cámara. Donde termina lo que se arma, el mundo sigue en vez de cortarse
## en una tira de árboles. Son 72 triángulos, sin textura, y la niebla los va borrando con la distancia.
func _horizon() -> void:
	var s := Soup.new()
	var n := 36
	for layer in 2:
		var rr := 440.0 if layer == 0 else 400.0
		var col0 := Color(0.54, 0.66, 0.70) if layer == 0 else Color(0.46, 0.62, 0.48)
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var am := (a0 + a1) * 0.5
			var hgt := (32.0 + 28.0 * (0.5 + 0.5 * sin(float(i) * 2.3 + float(layer) * 1.7))) * (1.0 if layer == 0 else 0.6)
			var b0 := Vector3(cos(a0) * rr, -6.0, sin(a0) * rr)
			var b1 := Vector3(cos(a1) * rr, -6.0, sin(a1) * rr)
			var pk := Vector3(cos(am) * rr, hgt - 6.0, sin(am) * rr)
			s.tri(b0, b1, pk, col0.lerp(Color(0.62, 0.72, 0.74), 0.3 * (0.5 + 0.5 * sin(float(i) * 1.3))))
	var m := ArrayMesh.new()
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.roughness = 1.0
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface(m, s, hm)
	_hz = MeshInstance3D.new()
	_hz.mesh = m
	_hz.extra_cull_margin = 4000.0
	_hz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hz)
	for ring in HorizonTrees.build(): # el bosque lejano: dos anillos de imágenes delante de las lomas
		add_child(ring)
		_hz_trees.append(ring)

## Carteles de orientación a la salida de la ciudad en cada ruta (sólo una cara mira a quien sale y la otra a quien vuelve): qué ruta es, adónde lleva y cuánto falta.
func _route_signs() -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var labels: Array = []
	var dests := {20: "AVENTURA · Ruta de los Sueños", 60: "PLAZA DE DRIFT", 40: "CIRCUNVALACIÓN AU-1", 80: "CIRCUNVALACIÓN AU-1"}
	for rd in city.roads:
		if str(rd["kind"]) != "rural":
			continue
		var num := int(rd["num"])
		var pts: PackedVector3Array = rd["pts"]
		var cum: PackedFloat32Array = rd["cum"]
		var i := 0
		while i < pts.size() - 2 and cum[i] < 70.0:
			i += 1
		var tn3 := (pts[i + 1] - pts[i]).normalized()
		var tn := Vector2(tn3.x, tn3.z).normalized()
		var right := Vector2(tn.y, -tn.x)
		var off := float(rd["hw"]) + float(rd["sw"]) + 1.6
		var p := Vector2(pts[i].x, pts[i].z) + right * off
		var y := city.height(p.x, p.y)
		var yaw := atan2(tn.x, tn.y)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))
		CityProps.box(v, c, xf, Vector3(-2.0, 1.5, 0), Vector3(0.16, 3.0, 0.16), Color(0.55, 0.57, 0.62))
		CityProps.box(v, c, xf, Vector3(2.0, 1.5, 0), Vector3(0.16, 3.0, 0.16), Color(0.55, 0.57, 0.62))
		CityProps.box(v, c, xf, Vector3(0, 3.2, 0), Vector3(5.0, 1.9, 0.12), Color(0.10, 0.34, 0.20))
		var km := float(cum[cum.size() - 1]) / 1000.0
		if str(dests.get(num, "")).begins_with("CIRCUNVALACIÓN") and city.region != null:
			km += _region_leg_km(num) # sigue por la región hasta la circunvalación: se suma lo que falta desde la salida de la ciudad
		var dest := Tr.t(str(dests.get(num, "")))
		var front := "%s\n%s\n%.1f km" % [Tr.t("RUTA %d") % num, dest, km]
		var back := "DREAM CITY\n%s" % Tr.t("centro")
		labels.append([Vector3(p.x - sin(yaw) * 0.09, y + 3.2, p.y - cos(yaw) * 0.09), yaw + PI, front])
		labels.append([Vector3(p.x + sin(yaw) * 0.09, y + 3.2, p.y + cos(yaw) * 0.09), yaw, back])
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1400.0
	add_child(mi)
	for l in labels:
		var lab := Label3D.new()
		lab.text = str(l[2]).replace("\\n", "\n")
		lab.font_size = 56
		lab.pixel_size = 0.0105
		lab.modulate = Color(1, 1, 1)
		lab.outline_size = 8
		lab.outline_modulate = Color(0.02, 0.15, 0.08)
		lab.position = l[0]
		lab.rotation = Vector3(0, float(l[1]), 0)
		lab.visibility_range_end = 220.0
		add_child(lab)

## Km del tramo de la región que sigue a la Salida `num` de la ciudad hasta el primer empalme (la circunvalación); 0 si la región no está
func _region_leg_km(num: int) -> float:
	var rg = city.region
	if rg == null:
		return 0.0
	var ni: int = rg.node_by_id("exit%d" % num)
	if ni < 0 or (rg.node_edges[ni] as PackedInt32Array).is_empty():
		return 0.0
	var ei: int = (rg.node_edges[ni] as PackedInt32Array)[0]
	var cum: PackedFloat32Array = rg.edge_cum(ei)
	return float(cum[cum.size() - 1]) / 1000.0 if cum.size() > 0 else 0.0

## Triángulo que mira hacia arriba sea cual sea el orden de los puntos
func _up_tri(s: Soup, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	if (b - a).cross(c - a).y < 0.0:
		s.tri(a, c, b, col)
	else:
		s.tri(a, b, c, col)

## La Plaza de Drift (al final de la Ruta 60): un disco de asfalto parejo con anillos pintados donde van los conos. Es un solo objeto chico que se oculta lejos.
func _drift_disc() -> void:
	if city.drift.is_empty():
		return
	var cen: Vector2 = city.drift["c"]
	var r: float = city.drift["r"]
	var y := float(city.drift["h"]) + 0.13
	var s := Soup.new()
	var seg := 56
	var asph := Color(0.46, 0.47, 0.52)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var col := asph.lerp(Color(0.50, 0.51, 0.56), 0.5 + 0.5 * sin(float(i) * 1.9) * 0.4)
		_up_tri(s, Vector3(cen.x, y, cen.y), Vector3(cen.x + cos(a0) * r, y, cen.y + sin(a0) * r), Vector3(cen.x + cos(a1) * r, y, cen.y + sin(a1) * r), col)
	for rr in [62.0, 34.0, 10.0, r - 1.2]: # anillos blancos (los conos están sobre ellos) y el borde
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var i0 := Vector3(cen.x + cos(a0) * (rr - 0.18), y + 0.02, cen.y + sin(a0) * (rr - 0.18))
			var i1 := Vector3(cen.x + cos(a1) * (rr - 0.18), y + 0.02, cen.y + sin(a1) * (rr - 0.18))
			var o0 := Vector3(cen.x + cos(a0) * (rr + 0.18), y + 0.02, cen.y + sin(a0) * (rr + 0.18))
			var o1 := Vector3(cen.x + cos(a1) * (rr + 0.18), y + 0.02, cen.y + sin(a1) * (rr + 0.18))
			_up_tri(s, i0, i1, o1, C_WHT)
			_up_tri(s, i0, o1, o0, C_WHT)
	var m := ArrayMesh.new()
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.roughness = 1.0
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface(m, s, dm)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 900.0
	add_child(mi)

# ───────────────────────── carga por cuadras ─────────────────────────
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _hz != null:
		_hz.global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z) # el horizonte acompaña a la cámara: siempre está lejos
		_hz.scale = Vector3(view_k, 1.0, view_k) # y se acerca junto con la niebla cuando el teléfono baja la distancia de vista
		var rk: float = region_world.region_k(cam.global_position.x, cam.global_position.z) if region_world != null else 0.0
		_hz.visible = rk < 0.5 # en la región las montañas son de verdad
		var in_pocket := CityLayout.in_pocket(cam.global_position.x) # el bolsillo de los túneles y los estacionamientos: ahí no hay bosque a lo lejos
		for ring in _hz_trees:
			ring.visible = not in_pocket and bool(diag["veg"]) and bool(diag["horizon"]) and rk < 0.5
			ring.global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z)
			ring.scale = Vector3(view_k, 1.0, view_k)
	update_around(cam.global_position, 4, ASSEMBLE_MS)
	_redraw_broken()
	var nd := 0
	while not _diag_todo.is_empty() and nd < 3:
		_diag_refresh(_diag_todo.pop_back())
		nd += 1
	nd = 0
	while not _diag_base_todo.is_empty() and nd < 2:
		var bk: Vector2i = _diag_base_todo.pop_back()
		if chunks.has(bk):
			var bmi := (chunks[bk] as Node3D).get_node_or_null("base")
			if bmi != null:
				_diag_base(bmi as MeshInstance3D)
		nd += 1

## Los objetos que acaban de romperse: se arma de nuevo la malla de objetos de su cuadra (lo roto queda tirado)
## ¿Se dibuja (y choca) este tipo de objeto de la calle con los interruptores de diagnóstico actuales?
func _diag_type_on(pt: int) -> bool:
	return _diag_type_on_d(pt, diag)

## Lo mismo con una copia de los interruptores (la cuenta de una cuadra corre en un hilo y no lee el diccionario que cambia el menú)
func _diag_type_on_d(pt: int, dg: Dictionary) -> bool:
	if pt == CityProps.TREE or pt == CityProps.RTREE:
		return bool(dg["trees"])
	if pt in DIAG_VEG:
		return bool(dg["veg"])
	if pt in DIAG_DECOR:
		return bool(dg["decor"])
	return true

## Prende o apaga un sistema del mundo para el diagnóstico (trees, buildings, veg, decor, asphalt, dirt, terrain, horizon)
func diag_set(layer: String, on: bool) -> void:
	if not diag.has(layer) or bool(diag[layer]) == on:
		return
	diag[layer] = on
	if layer == "horizon":
		_hz.visible = on # las lomas; el bosque lejano se apaga en _process con el mismo interruptor
		return
	if layer == "asphalt" or layer == "dirt" or layer == "terrain":
		_diag_base_todo = chunks.keys() # la malla base de cada cuadra se arma de nuevo sin esa parte (de a pocas por cuadro)
		return
	if layer == "buildings":
		for k in chunks:
			var bn: Node = (chunks[k] as Node3D).get_node_or_null("buildings")
			if bn != null:
				(bn as Node3D).visible = on
		return
	_diag_todo = chunks.keys() # árboles, vegetación y decoración: se rearman las mallas de objetos de cada cuadra (de a pocas por cuadro)

## Malla base de una cuadra (terreno + calzada/veredas + marcas + túnel) según los interruptores. Con todo prendido es EXACTAMENTE la malla original (la que se armó en _build_chunk);
## con algo apagado se arma una copia sin esa parte: las mismas superficies y materiales, sólo que sin el terreno y/o con un índice que saltea los triángulos de asfalto o de tierra.
func _diag_base(mi: MeshInstance3D) -> void:
	var full: ArrayMesh = mi.get_meta("diag_full")
	if bool(diag["asphalt"]) and bool(diag["dirt"]) and bool(diag["terrain"]):
		mi.mesh = full
		return
	var roles: Array = mi.get_meta("diag_roles")
	var out := ArrayMesh.new()
	for i in roles.size():
		var role: String = roles[i]
		if role == "terrain" and not bool(diag["terrain"]):
			continue
		var arr: Array = full.surface_get_arrays(i)
		if role == "road" and (not bool(diag["asphalt"]) or not bool(diag["dirt"])):
			arr[Mesh.ARRAY_INDEX] = _diag_road_index(arr[Mesh.ARRAY_COLOR] as PackedColorArray)
			if (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, full.surface_get_material(i))
	mi.mesh = out

## Qué triángulos de la superficie de calles quedan. En _road_segment cada cosa lleva su color: calzada = C_ASPH, banquina de las rutas rurales = C_RURAL_SIDE, el resto (veredas, ladrillo, cordones) otros colores
func _diag_road_index(cs: PackedColorArray) -> PackedInt32Array:
	var keep_asph := bool(diag["asphalt"])
	var keep_dirt := bool(diag["dirt"])
	var idx := PackedInt32Array()
	idx.resize(cs.size())
	var k := 0
	var i := 0
	while i + 2 < cs.size():
		var c: Color = cs[i]
		var cls := _diag_road_class(c)
		if (cls == 0 and not keep_asph) or (cls == 1 and not keep_dirt):
			i += 3
			continue
		idx[k] = i
		idx[k + 1] = i + 1
		idx[k + 2] = i + 2
		k += 3
		i += 3
	idx.resize(k)
	return idx

## 0 = calzada de asfalto · 1 = banquina de tierra de ruta rural · 2 = otra cosa (veredas, cordones…). Los colores salen de la malla (8 bits por canal), de ahí la tolerancia
func _diag_road_class(c: Color) -> int:
	if absf(c.r - C_ASPH.r) < 0.012 and absf(c.g - C_ASPH.g) < 0.012 and absf(c.b - C_ASPH.b) < 0.012:
		return 0
	if absf(c.r - C_RURAL_SIDE.r) < 0.012 and absf(c.g - C_RURAL_SIDE.g) < 0.012 and absf(c.b - C_RURAL_SIDE.b) < 0.012:
		return 1
	return 2

func _diag_refresh(key: Vector2i) -> void:
	if not chunks.has(key):
		return
	var root: Node3D = chunks[key]
	_unregister_props(key)
	var old := root.get_node_or_null("props")
	if old != null:
		old.queue_free()
		root.remove_child(old)
	var pi := _props_instance(key)
	if pi != null:
		root.add_child(pi)
	var tn := root.get_node_or_null("trees")
	if tn != null:
		(tn as Node3D).visible = bool(diag["trees"])
	_register_props(key)

func _redraw_broken() -> void:
	var fresh: PackedInt32Array = track.take_broken()
	if fresh.is_empty():
		return
	var keys := {}
	for id in fresh:
		keys[city.chunk_of(city.prop_x[id], city.prop_z[id])] = true
	for k in keys:
		var kk: Vector2i = k
		if not chunks.has(kk):
			continue
		var root: Node3D = chunks[kk]
		var old := root.get_node_or_null("props")
		if old != null:
			old.queue_free()
			root.remove_child(old)
		var pi := _props_instance(kk)
		if pi != null:
			root.add_child(pi)
		var oldt := root.get_node_or_null("trees")
		if oldt != null:
			oldt.queue_free()
			root.remove_child(oldt)
		var ti := _trees_instance(kk)
		if ti != null:
			ti.visible = bool(diag["trees"])
			root.add_child(ti)

## Los árboles de una cuadra como imágenes (tree_sprites.gd): los de la ruta (adorno, sin choque) y los de la calle (se rompen: el sano es una imagen, el roto un recorte tirado en la malla de objetos).
## Sobre cada árbol de ruta se suman 0 a 3 más, atrás, a distinta distancia del camino: así no quedan en fila y el monte se ve parejo sin costar casi nada (cuatro triángulos cada uno).
func _trees_instance(key: Vector2i) -> Node3D:
	return TreeSprites.build(tree_items(key), view_k)

## La lista de árboles de una cuadra (x, y, z, especie, escala, giro, tinte: ver TreeSprites.item). Sólo cuentas (se calcula en un hilo): brk = los objetos rotos (por defecto, los de ahora)
func tree_items(key: Vector2i, brk: Variant = null) -> Array:
	var items: Array = []
	if not city.props_in.has(key):
		return items
	var broken: Dictionary = track.broken if brk == null else brk
	for id in (city.props_in[key] as PackedInt32Array):
		var t := int(city.prop_type[id])
		var x: float = city.prop_x[id]
		var z: float = city.prop_z[id]
		var sd: float = city.prop_seed[id]
		if t == CityProps.TREE:
			if broken.has(id):
				continue
			var sp := TreeSprites.pick(x, z, sd, z > COAST_Z)
			items.append(TreeSprites.item(x, city.prop_y[id], z, sp, clampf((6.5 + 3.0 * fposmod(sd * 13.7, 1.0)) / TreeSprites.height_of(sp), 0.55, 1.25), city.prop_yaw[id], sd))
		elif t == CityProps.RTREE:
			_road_tree(id, x, z, sd, items)
	return items

const COAST_Z := 1040.0 # desde acá (la playa) entran las palmeras

## Un árbol de ruta y sus acompañantes (más chicos y más atrás del camino)
func _road_tree(id: int, x: float, z: float, sd: float, items: Array) -> void:
	var coast := z > COAST_Z
	var sp := TreeSprites.pick(x, z, sd, coast)
	var k := 0.8 + 0.5 * fposmod(sd * 23.7, 1.0)
	items.append(TreeSprites.item(x, city.prop_y[id], z, sp, k, sd * TAU, sd))
	var r := fposmod(sd * 311.7, 1.0)
	var extra := 0 if r < 0.30 else (1 if r < 0.62 else (2 if r < 0.88 else 3))
	if extra == 0:
		return
	var pr := city.probe(x, z)
	if pr[0] <= -1e8:
		return
	var away := Vector2(-float(pr[2]), -float(pr[3]))
	if away.length() < 0.1:
		return
	away = away.normalized()
	var side := Vector2(-away.y, away.x)
	for e in extra:
		var q := fposmod(sd * (47.3 + 19.1 * float(e)), 1.0)
		var q2 := fposmod(sd * (83.9 + 31.7 * float(e)), 1.0)
		var ex := x + away.x * (3.0 + 9.0 * q) + side.x * (q2 - 0.5) * 18.0
		var ez := z + away.y * (3.0 + 9.0 * q) + side.y * (q2 - 0.5) * 18.0
		if float(city.probe(ex, ez)[0]) > -3.0 or city.lot_blocked(ex, ez):
			continue
		var s2 := fposmod(sd * (13.1 + 7.9 * float(e)), 1.0)
		var sp2 := TreeSprites.pick(ex, ez, fposmod(sd * (3.7 + float(e)), 1.0), coast)
		items.append(TreeSprites.item(ex, city.height(ex, ez), ez, sp2, 0.6 + 0.55 * s2, s2 * TAU, s2))

## Malla de los objetos de la calle de una cuadra (una sola llamada de dibujo; se ve a ~150 m) y sus círculos de choque
func _props_instance(key: Vector2i) -> MeshInstance3D:
	_ensure_signals()
	return _props_node(_props_data(key, track.broken, diag))

## Los arreglos de los objetos de la calle de una cuadra: objetos (v, c, a y n: normales y UV2 ya hechas), luces (gv, gc) y lámparas de los semáforos (sv, sc, suv). Sólo cuentas, sin nodos ni
## recursos: corre en un hilo (brk = copia de los objetos rotos, dg = copia de los interruptores de diagnóstico). Vacío si la cuadra no tiene objetos.
func _props_data(key: Vector2i, brk: Dictionary, dg: Dictionary) -> Dictionary:
	if not city.props_in.has(key):
		return {}
	var sv := PackedVector3Array()
	var sc := PackedColorArray()
	var suv := PackedVector2Array()
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var gv := PackedVector3Array()
	var gc := PackedColorArray()
	for id in (city.props_in[key] as PackedInt32Array):
		var fallen: Vector2 = brk.get(id, Vector2.ZERO)
		var pt := int(city.prop_type[id])
		if pt == CityProps.RTREE or (pt == CityProps.TREE and fallen == Vector2.ZERO):
			continue # los árboles sanos son imágenes (_trees_instance)
		if not _diag_type_on_d(pt, dg):
			continue
		CityProps.emit(int(city.prop_type[id]), city.prop_x[id], city.prop_y[id], city.prop_z[id], city.prop_yaw[id], city.prop_seed[id], fallen, v, c, gv, gc)
		if int(city.prop_type[id]) == CityProps.LIGHT and fallen == Vector2.ZERO and signals.head_info.has(id):
			var hi: Vector2 = signals.head_info[id]
			CityProps.emit_signal_lamps(city.prop_x[id], city.prop_y[id], city.prop_z[id], city.prop_yaw[id], hi.x, hi.y, sv, sc, suv)
	if v.is_empty():
		return {}
	return {"arr": PaperKit.surface_arrays(v, c), "gv": gv, "gc": gc, "sv": sv, "sc": sc, "suv": suv}

## La malla (y sus luces y lámparas) de _props_data, lista para la escena
func _props_node(pd: Dictionary) -> MeshInstance3D:
	if pd.is_empty():
		return null
	var m := ArrayMesh.new()
	PaperKit.add_arrays(m, pd["arr"], PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.name = "props"
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 190.0 * maxf(view_k, 0.6)
	var gv: PackedVector3Array = pd["gv"]
	if not gv.is_empty():
		mi.add_child(_glow_instance(gv, pd["gc"], mi.visibility_range_end))
	var sv: PackedVector3Array = pd["sv"]
	if not sv.is_empty():
		var sm := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = sv
		arr[Mesh.ARRAY_COLOR] = pd["sc"]
		arr[Mesh.ARRAY_TEX_UV] = pd["suv"]
		sm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		sm.surface_set_material(0, signal_mat)
		var si := MeshInstance3D.new()
		si.name = "signals"
		si.mesh = sm
		si.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		si.visibility_range_end = mi.visibility_range_end
		mi.add_child(si)
	return mi

## Los semáforos funcionales y su material (una sola vez, en el hilo principal: los hilos de las cuadras sólo leen de acá)
func _ensure_signals() -> void:
	if signals != null:
		return
	signals = city.traffic_signals()
	signal_mat = ShaderMaterial.new()
	signal_mat.shader = SIGNAL_SHADER
	signal_mat.set_shader_parameter("cycle", signals.CYCLE)
	signal_mat.set_shader_parameter("green", signals.GREEN)
	signal_mat.set_shader_parameter("yellow", signals.YELLOW)

## Hora del mundo para los semáforos (la pone el reloj de la ciudad una vez por cuadro)
func set_signal_time(t: float) -> void:
	if signal_mat != null:
		signal_mat.set_shader_parameter("world_time", fposmod(t, 86400.0))

## Luces de noche (lámparas, charcos de luz): malla aparte con material aditivo; el reloj (CityClock) la enciende o apaga entera con el grupo «city_glow» y regula su brillo
func _glow_instance(gv: PackedVector3Array, gc: PackedColorArray, vis_end: float) -> MeshInstance3D:
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = gv
	arr[Mesh.ARRAY_COLOR] = gc
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, glow_mat)
	var gi := MeshInstance3D.new()
	gi.name = "glow"
	gi.mesh = m
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi.visibility_range_end = vis_end
	gi.visible = glow_on
	gi.add_to_group("city_glow")
	return gi

## Material aditivo de las luces: el brillo (alfa del albedo) lo pone el reloj
static func make_glow_material() -> StandardMaterial3D:
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.vertex_color_use_as_albedo = true
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	gm.albedo_color = Color(1, 1, 1, 0)
	return gm

func _register_props(key: Vector2i) -> void:
	if not city.props_in.has(key):
		return
	for id in (city.props_in[key] as PackedInt32Array):
		var rad: float = CityProps.RADIUS[int(city.prop_type[id])]
		if rad > 0.0 and not track.broken.has(id) and _diag_type_on(int(city.prop_type[id])):
			track.add_prop(id, city.prop_x[id], city.prop_z[id], rad)

## El reloj de la ciudad prende o apaga las luces: n = 0 (día) … 1 (noche)
func set_night(n: float) -> void:
	TreeSprites.set_night(n)
	HorizonTrees.set_night(n)
	if _facade_mat != null:
		_facade_mat.set_shader_parameter("night", n)
	glow_mat.albedo_color = Color(1, 1, 1, clampf(n * 1.1, 0.0, 1.0))
	var on := n > 0.03
	if on != glow_on:
		glow_on = on
		if is_inside_tree():
			for gnode in get_tree().get_nodes_in_group("city_glow"):
				(gnode as Node3D).visible = on

func _unregister_props(key: Vector2i) -> void:
	if not city.props_in.has(key):
		return
	for id in (city.props_in[key] as PackedInt32Array):
		if CityProps.RADIUS[int(city.prop_type[id])] > 0.0 and not track.broken.has(id):
			track.remove_prop(id, city.prop_x[id], city.prop_z[id])

## Cada cuadra se calcula en un hilo (_chunk_data: sólo cuentas, sin nodos ni recursos) y el cuadro principal sólo la sube a la escena, en pasos cortos (_assemble_a: terreno, calles y edificios;
## _assemble_b: objetos, árboles y choques; después, de a uno por cuadro, los locales, las estaciones y los autos de las vidrieras). El hilo arma una cuadra a la vez: en un teléfono de pocos núcleos
## no le saca tiempo al dibujo. Antes cada cuadra se armaba entera en el cuadro en que entraba en el radio (12 a 60 ms en la PC, de 3 a 6 veces más en un teléfono): al ir fuerte por las rutas
## era un tirón cada pocos segundos (reporte del dueño, 20/10/2026). warm() sigue armando todo de golpe (la carga de la pista y los viajes, con la pantalla negra).
const ASSEMBLE_MS := 2.5 # lo que se gasta por cuadro en subir cuadras a la escena (siempre se hace al menos un paso)
const NO_KEY := Vector2i(1 << 30, 1 << 30)
var _job_key := NO_KEY # la cuadra que calcula el hilo ahora (NO_KEY = ninguna)
var _job_id := -1
var _job_out: Dictionary = {} # lo que calculó el hilo (se lee recién cuando terminó)
# (Las cuentas de una cuadra llenan memorias al usarse: CityLayout._obst y _ribbons, _first_cache, _cap_chunks. Por eso corre UNA sola a la vez: o en el hilo o en el principal, y el principal
# espera a que el hilo termine antes de armar una por su cuenta, ver _chunk_data_main. Sin un Mutex: si un error de script cortara el hilo a la mitad, un Mutex quedaría tomado para siempre.)
var _ready_q: Array = [] # [clave, datos] ya calculadas: falta subirlas a la escena
var _pend_b: Array = [] # [raíz, clave, datos] con la malla base ya subida: faltan los objetos y los árboles
var _extras_q: Array = [] # [raíz, Callable] de los locales y los autos de las vidrieras: uno por cuadro
var _pending := {} # claves que están en el hilo o en la cola (todavía sin raíz)
var _bad := {} # cuadras cuyo armado falló (no se reintenta cada cuadro)
var _deferring := false # los locales de la cuadra se dejan para los cuadros siguientes (_later)
var _ck := Vector2i.ZERO
var _rad := 3

var threaded := true # false = como antes (cada cuadra se arma entera en el hilo principal): una válvula de escape para las pruebas y por si algún teléfono se llevara mal con los hilos

## Arma las cuadras de alrededor de p y borra las lejanas. max_new = cuántos pasos de subida a la escena por llamada como máximo (se corta antes si pasa budget_ms)
func update_around(p: Vector3, max_new: int, budget_ms := -1.0) -> void:
	var budget := _frame_budget_ms if budget_ms < 0.0 else budget_ms
	_ck = city.chunk_of(p.x, p.z)
	_rad = maxi(2, int(round(float(radius) * view_k)))
	_ensure_shared()
	if not threaded:
		if _job_id >= 0:
			_take_job()
		while _assemble_step():
			pass
		var t1 := Time.get_ticks_usec()
		var n1 := 0
		for k in _wanted(p, _ck, _rad):
			if n1 >= max_new:
				break
			chunks[k] = _build_chunk(k)
			add_child(chunks[k])
			built_total += 1
			n1 += 1
			if float(Time.get_ticks_usec() - t1) / 1000.0 > budget:
				break
		_unload_far(_ck, _rad)
		return
	_poll_job()
	if _job_id < 0:
		for k in _wanted(p, _ck, _rad):
			_start_job(k)
			break
	var t0 := Time.get_ticks_usec()
	var made := 0
	while made < max_new and _assemble_step():
		made += 1
		if float(Time.get_ticks_usec() - t0) / 1000.0 > budget:
			break
	_unload_far(_ck, _rad)

## Las cuadras que faltan armar alrededor de la cuadra ck, de la más cercana a la más lejana
func _wanted(p: Vector3, ck: Vector2i, rad: int) -> Array:
	var want: Array = []
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			if chunks.has(k) or _pending.has(k) or _bad.has(k):
				continue
			if region_world != null and not CityLayout.in_pocket(p.x):
				var qx := (float(k.x) + 0.5) * CityLayout.CELL
				var qz := (float(k.y) + 0.5) * CityLayout.CELL
				if qx * qx + qz * qz > 3750.0 * 3750.0:
					continue # más allá lo arma la región
			want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - ck).length_squared() < (b - ck).length_squared())
	return want

func _unload_far(ck: Vector2i, rad: int) -> void:
	for k in chunks.keys():
		var kk: Vector2i = k
		if maxi(absi(kk.x - ck.x), absi(kk.y - ck.y)) > rad + 1:
			_unregister_props(kk)
			for ex in city.exits:
				if city.chunk_of((ex["pos"] as Vector2).x, (ex["pos"] as Vector2).y) == kk:
					_gate_circles(ex, false)
			(chunks[kk] as Node3D).queue_free()
			chunks.erase(kk)

## Lo que los hilos de las cuadras sólo leen y se arma una vez, en el hilo principal: los semáforos y sus materiales, y las piezas de papel de la vegetación
func _ensure_shared() -> void:
	_ensure_signals()
	PieceBatch.warm(CityProps.FLOWER_PIECES + CityProps.PIECES)
	TreeSprites.ensure() # (las 48 imágenes de los árboles: 50 a 100 ms la primera vez)

func _start_job(k: Vector2i) -> void:
	_job_key = k
	_job_out = {}
	_pending[k] = true
	_job_id = WorkerThreadPool.add_task(_job_run.bind(k, track.broken.duplicate(), diag.duplicate()), false, "cuadra de Dream City")

func _job_run(k: Vector2i, brk: Dictionary, dg: Dictionary) -> void:
	_job_out = _chunk_data(k, brk, dg)

## ¿Terminó el hilo? Si terminó, su cuadra pasa a la cola de subida
func _poll_job() -> void:
	if _job_id >= 0 and WorkerThreadPool.is_task_completed(_job_id):
		_take_job()

func _take_job() -> void:
	WorkerThreadPool.wait_for_task_completion(_job_id)
	_job_id = -1
	var out := _job_out
	_job_out = {}
	_ready_q.append([_job_key, out if not out.is_empty() else null]) # (sin datos: el hilo falló y la cuadra se arma en el principal; el error queda en el registro)
	_job_key = NO_KEY

func _exit_tree() -> void:
	if _job_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_job_id) # (el hilo usa este objeto: no se puede borrar mientras corre)
		_job_id = -1
		_job_key = NO_KEY
		_job_out = {}
	_ready_q.clear()
	_pending.clear() # (si el mundo vuelve a entrar al árbol, las cuadras que faltan se piden de nuevo)

## Un paso de subida a la escena, el más urgente primero (false si no queda nada): los objetos de una cuadra ya subida, una cuadra nueva (terreno, calles y edificios) o un local
func _assemble_step() -> bool:
	while not _pend_b.is_empty():
		var pb: Array = _pend_b.pop_front()
		var broot: Node3D = pb[0]
		if not is_instance_valid(broot) or chunks.get(pb[1]) != broot:
			continue # (la cuadra ya se borró)
		_assemble_b(broot, pb[1], pb[2], true)
		return true
	while not _ready_q.is_empty():
		var rq: Array = _ready_q.pop_front()
		var k: Vector2i = rq[0]
		_pending.erase(k)
		if chunks.has(k) or maxi(absi(k.x - _ck.x), absi(k.y - _ck.y)) > _rad + 1:
			continue # (ya está o quedó lejos mientras se calculaba)
		var d: Variant = rq[1]
		if d == null:
			d = _chunk_data_main(k)
		if not (d is Dictionary) or (d as Dictionary).is_empty():
			_bad[k] = true # (falló dos veces: se deja sin armar en vez de reintentar en cada cuadro)
			continue
		var root := _assemble_a(k, d)
		chunks[k] = root
		add_child(root)
		built_total += 1
		_pend_b.append([root, k, d])
		return true
	while not _extras_q.is_empty():
		var ex: Array = _extras_q.pop_front()
		if is_instance_valid(ex[0]):
			_deferring = true
			(ex[1] as Callable).call()
			_deferring = false
			return true
	return false

var _primed := false

## Arma un auto de vidriera y lo tira: la primera vez se inicializan los catálogos y las piezas compartidas (~25 ms en la PC); mejor con la pantalla de carga que en medio de un cuadro
func _prime_display() -> void:
	if _primed:
		return
	_primed = true
	var car := _display_car("hatch")
	if car != null:
		car.free()

## Arma ya todas las de alrededor (la carga de la pista, antes de empezar)
func warm(p: Vector3) -> void:
	_ensure_shared()
	_prime_display()
	if _job_id >= 0:
		_take_job()
	_ck = city.chunk_of(p.x, p.z)
	_rad = maxi(2, int(round(float(radius) * view_k)))
	var guard := 0
	while _assemble_step() and guard < 100000:
		guard += 1 # (lo que ya estaba en camino se sube entero)
	for k in _wanted(p, _ck, _rad):
		chunks[k] = _build_chunk(k)
		add_child(chunks[k])
		built_total += 1
	_unload_far(_ck, _rad)
	if region_world != null:
		region_world.warm(p)

func stats() -> Dictionary:
	var tris := 0
	for k in chunks:
		for c in (chunks[k] as Node3D).get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var m := (c as MeshInstance3D).mesh as ArrayMesh
				for s in m.get_surface_count():
					tris += int(m.surface_get_array_len(s) / 3)
	return {"chunks": chunks.size(), "tris": tris, "built": built_total}

# ───────────────────────── una cuadra ─────────────────────────
## Una cuadra entera, ya (sin hilos): lo que usa warm() y lo que arma el principal si el hilo falló
func _build_chunk(key: Vector2i) -> Node3D:
	_ensure_shared()
	var d := _chunk_data_main(key)
	var root := _assemble_a(key, d)
	_assemble_b(root, key, d, false)
	return root

func _chunk_data_main(key: Vector2i) -> Dictionary:
	if _job_id >= 0:
		_take_job() # el hilo termina primero (nunca corren las dos cuentas a la vez)
	return _chunk_data(key, track.broken, diag)

## Todo lo que sale de la geometría de la ciudad: las sopas de triángulos (terreno, calles, rayas, túnel, edificios), los arreglos de los objetos y la lista de árboles. Sólo cuentas: se puede
## correr en un hilo (brk = los objetos rotos, dg = los interruptores del diagnóstico: en el hilo van copias). Nada de nodos ni recursos (el motor de dibujo se toca sólo desde el principal).
func _chunk_data(key: Vector2i, brk: Dictionary, dg: Dictionary) -> Dictionary:
	var x0 := float(key.x) * CityLayout.CELL
	var z0 := float(key.y) * CityLayout.CELL
	var terr := Soup.new()
	_terrain(terr, x0, z0)
	var rd := Soup.new()
	var mk := Soup.new()
	var tn := Soup.new()
	_roads(rd, mk, key, tn)
	var bl := Soup.new()
	var pois := _buildings_soup(bl, key)
	return {"terr": terr, "rd": rd, "mk": mk, "tn": tn, "bl": bl, "pois": pois, "props": _props_data(key, brk, dg), "trees": tree_items(key, brk), "brk": brk.size(), "dg": dg}

## Paso 1 de la subida a la escena: el terreno, las calles y los edificios de la cuadra
func _assemble_a(key: Vector2i, d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "c%d_%d" % [key.x, key.y]
	var terr: Soup = d["terr"]
	var rd: Soup = d["rd"]
	var mk: Soup = d["mk"]
	var tn: Soup = d["tn"]
	var bl: Soup = d["bl"]
	var m := ArrayMesh.new()
	_surface(m, terr, PaperKit.material(null, 0.0, 0.2, 0.25))
	_surface(m, rd, PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.07))
	_surface(m, mk, PaperKit.mark_material())
	_surface(m, tn, _tunnel_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "base"
	var roles: Array = [] # qué es cada superficie de la malla base, en el orden en que se agregaron (las vacías no se agregan)
	for pr in [[terr, "terrain"], [rd, "road"], [mk, "marks"], [tn, "tunnel"]]:
		var part: Array = pr
		if (part[0] as Soup).v.size() > 0:
			roles.append(part[1])
	mi.set_meta("diag_full", m)
	mi.set_meta("diag_roles", roles)
	root.add_child(mi)
	if not (bool(diag["asphalt"]) and bool(diag["dirt"]) and bool(diag["terrain"])):
		_diag_base(mi)
	if bl.v.size() > 0:
		var bm := ArrayMesh.new()
		_surface(bm, bl, _facade_mat)
		var bi := MeshInstance3D.new()
		bi.mesh = bm
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bi.name = "buildings"
		bi.visible = bool(diag["buildings"])
		root.add_child(bi)
	return root

## Paso 2: los objetos de la calle, los árboles, los círculos de choque y los locales (con defer, los locales y las vidrieras se van armando uno por cuadro)
func _assemble_b(root: Node3D, key: Vector2i, d: Dictionary, defer: bool) -> void:
	var pd: Dictionary = d["props"]
	var items: Array = d["trees"]
	if int(d["brk"]) != track.broken.size() or d["dg"] != diag:
		pd = _props_data(key, track.broken, diag) # (se rompió algo o se movió un interruptor mientras se calculaba)
		items = tree_items(key)
	var pi := _props_node(pd)
	if pi != null:
		if root.get_node_or_null("props") == null: # (si se rompió algo antes de que llegue este paso, _redraw_broken ya lo armó)
			root.add_child(pi)
		else:
			pi.free()
	var ti := TreeSprites.build(items, view_k)
	if ti != null:
		if root.get_node_or_null("trees") == null:
			ti.visible = bool(diag["trees"])
			root.add_child(ti)
		else:
			ti.free()
	_register_props(key)
	var was := _deferring
	_deferring = defer
	for pb in d["pois"]:
		var b: Dictionary = pb
		_later(root, func() -> void: root.add_child(_shop_front(b)))
	for mo in city.mouths:
		if city.chunk_of((mo["pos"] as Vector2).x, (mo["pos"] as Vector2).y) == key:
			var mm: Dictionary = mo
			_later(root, func() -> void: root.add_child(_mouth(mm)))
	for st in city.stations:
		if not st.get("region", false) and city.chunk_of((st["center"] as Vector2).x, (st["center"] as Vector2).y) == key:
			var sd: Dictionary = st
			_later(root, func() -> void: root.add_child(_station(sd)))
	for tl in city.tolls:
		if not tl.get("region", false) and city.chunk_of((tl["pos"] as Vector2).x, (tl["pos"] as Vector2).y) == key:
			var td: Dictionary = tl
			_later(root, func() -> void: root.add_child(_toll(td)))
	for h in city.halls:
		if city.chunk_of((h["pos"] as Vector2).x, (h["pos"] as Vector2).y) == key:
			var hd: Dictionary = h
			_later(root, func() -> void: root.add_child(_hall(hd)))
	if not city.garage.is_empty() and city.chunk_of((city.garage["p"] as Vector2).x, (city.garage["p"] as Vector2).y) == key:
		_later(root, func() -> void: root.add_child(_garage_sign()))
	for l in city.links:
		if str(l["label"]) != "" and city.chunk_of((l["label_pos"] as Vector2).x, (l["label_pos"] as Vector2).y) == key:
			var ld: Dictionary = l
			_later(root, func() -> void: root.add_child(_link_label(ld)))
	for ex in city.exits:
		if str(ex.get("to", "")) == "region":
			continue # la ruta sigue por la región: sin portón, sin cartel y sin nada que choque
		if city.chunk_of((ex["pos"] as Vector2).x, (ex["pos"] as Vector2).y) == key:
			var ed: Dictionary = ex
			_gate_circles(ed, true) # (los círculos de choque enseguida: el portón se dibuja cuando le toca)
			_later(root, func() -> void: root.add_child(_gate(ed)))
	_deferring = was

## Algo de la cuadra que se arma ahora (cuadra sin hilos) o en uno de los cuadros que siguen (_extras_q)
func _later(root: Node3D, c: Callable) -> void:
	if _deferring:
		_extras_q.append([root, c])
	else:
		c.call()

func _surface(m: ArrayMesh, s: Soup, mat: Material) -> void:
	if s.v.size() == 0:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = s.v
	arr[Mesh.ARRAY_NORMAL] = s.n
	arr[Mesh.ARRAY_COLOR] = s.c
	arr[Mesh.ARRAY_TEX_UV] = s.uv
	arr[Mesh.ARRAY_TEX_UV2] = s.uv2
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)

# ───────────────────────── terreno ─────────────────────────
const TC := 16.0 # lado de una celda del terreno
const TC_REGION_ROADS := 8.0 # donde pasan caminos de la región la malla es más fina (como la de cerca de la región): una calzada de 9 a 18 m no cabe en una grilla de 16 m

func _ground_color(x: float, z: float, y: float) -> Color:
	for oa in city.open_areas:
		if Vector2(x, z).distance_to(oa["pos"]) < float(oa["r"]) + 6.0:
			if oa.get("flat", false):
				continue # la plaza de drift tiene su propio disco: el suelo de alrededor es campo
			if oa.get("dark", false):
				return Color(0.22, 0.23, 0.27)
			if oa.get("station", false):
				return Color(0.58, 0.60, 0.65)
			return Color(0.66, 0.68, 0.72) if bool(oa["paving"]) else Color(0.46, 0.64, 0.36) # parque del drift: pavimento · plaza: pasto
	var zone := city.zone_of(x, z)
	var jit := 0.012 * sin(x * 0.011) * cos(z * 0.009)
	var sc := WorldSurfaces.color(y, z, jit) # playa, roca y nieve (las mismas alturas que ground_info)
	if sc != Color.TRANSPARENT:
		return sc
	match zone:
		0, 1:
			return Color(0.80 + jit, 0.76 + jit, 0.68 + jit)
		2:
			return Color(0.74 + jit, 0.76 + jit, 0.58 + jit)
		3:
			return Color(0.90 + jit, 0.82 + jit, 0.62 + jit) if z > 1060.0 else Color(0.78 + jit, 0.76 + jit, 0.66 + jit)
		4:
			return Color(0.50 + jit, 0.64 + jit, 0.36 + jit)
	return Color(0.58 + jit, 0.68 + jit, 0.42 + jit)

## Altura de la malla del terreno en un vértice: la del mundo, hundida donde pasa una calle de la ciudad o hay una sala del estacionamiento
func _terrain_h(wx: float, wz: float) -> float:
	var h := city.height(wx, wz)
	# junto a una ruta de campo (a menos de VERGE_BW_MAX m del borde): terraplén del lado de abajo y cuneta del de arriba, la misma altura que usa la física (CityLayout.verge_height)
	var vg := city.verge_roads(wx, wz)
	var near_rural := not vg.is_empty() and CityLayout.verge_min_e(vg) > 0.0
	if near_rural:
		h = CityLayout.verge_height(h, vg)
	# donde hay una calle el terreno se hunde un poco para que el asfalto quede por encima aunque la ladera suba al costado
	var pr := city.probe(wx, wz)
	if pr[6] >= 0.0 and not near_rural and city.is_dense_road(int(pr[6])):
		h = city.dense_ground(h, pr) # calles de la ciudad: el terreno a ras del asfalto (apenas por debajo)
	elif pr[6] >= 0.0 and not near_rural:
		# el hundimiento se desvanece con la distancia al borde de la vereda (antes era todo o nada por vértice y en las banquinas se veían escalones de 16 m);
		# bajo tierra se hunde más lejos: si no, las lomas del terreno asoman por adentro de la rampa
		var lim := 20.0 if float(pr[4]) < -0.3 else 7.0
		var wcut := smoothstep(-lim - 9.0, -lim + 3.0, float(pr[0]))
		if wcut > 0.0:
			h = lerpf(h, minf(h, float(pr[4]) - 0.5), wcut)
	for oa in city.open_areas:
		# las salas del estacionamiento a distinta altura: el suelo queda por debajo (y bastante más allá de la pared)
		if (oa as Dictionary).has("y") and Vector2(wx, wz).distance_to(oa["pos"]) < float(oa["r"]) + 22.0:
			h = minf(h, float(oa["y"]) - 0.5)
		if (oa as Dictionary).get("flat", false) and Vector2(wx, wz).distance_to(oa["pos"]) < float(oa["r"]) + 22.0:
			h = minf(h, float(city.drift["h"]) - 0.2) # el terreno queda un poco por debajo del disco de asfalto
	return h

## ¿Esta cuadra puede tener caminos de la región? (más allá de REGION_R el suelo lo da la región y sus caminos pasan por acá: la circunvalación, el comienzo de las rutas)
func _has_region_roads(x0: float, z0: float) -> bool:
	if region_world == null or x0 > CityLayout.POCKET_X0:
		return false
	var fx := maxf(absf(x0), absf(x0 + CityLayout.CELL))
	var fz := maxf(absf(z0), absf(z0 + CityLayout.CELL))
	var r := CityLayout.REGION_R - 40.0
	return fx * fx + fz * fz > r * r

var _cap_chunks: Dictionary = {} # cuadras (Vector2i) con una ruta de campo o un camino de la colina cerca: el terreno ahí se recorta para no tapar el asfalto (_city_caps)

## ¿Hay una ruta de campo (rural, atajo, panorámica, colina) a menos de 24 m de esta cuadra? (se arma la primera vez, mirando todos los puntos de las calles)
func _has_cap_roads(x0: float, z0: float) -> bool:
	if _cap_chunks.is_empty():
		_cap_chunks[Vector2i(1 << 30, 1 << 30)] = false # (marca de «ya armado»)
		for si in city.s_x.size():
			if city.s_next[si] < 0 or city._verge_road[city.s_road[si]] == 0:
				continue
			var px: float = city.s_x[si]
			var pz: float = city.s_z[si]
			for ox in [-24.0, 24.0]:
				for oz in [-24.0, 24.0]:
					_cap_chunks[city.chunk_of(px + float(ox), pz + float(oz))] = true
	return _cap_chunks.has(Vector2i(int(floor(x0 / CityLayout.CELL)), int(floor(z0 / CityLayout.CELL))))

## El terreno nunca tapa el asfalto de las rutas de campo y los caminos de la colina (TerrainCap): para cada punto de la calzada y de la banquina (cada 1,5 m a lo largo y 7 puntos a lo ancho)
## se baja el nivel de corte de los vértices de la malla que lo taparían. (ox, oz) = posición del vértice (0, 0) de la grilla de w×w vértices (con un anillo de más alrededor de la cuadra).
func _city_caps(ox: float, oz: float, step: float, w: int, cap: PackedFloat32Array, y0: PackedFloat32Array) -> void:
	var span := float(w - 1) * step
	var seen := {}
	for kx in range(int(floor((ox - 24.0) / CityLayout.HC)), int(floor((ox + span + 24.0) / CityLayout.HC)) + 1):
		for kz in range(int(floor((oz - 24.0) / CityLayout.HC)), int(floor((oz + span + 24.0) / CityLayout.HC)) + 1):
			var lst: Variant = city._hash.get(Vector2i(kx, kz))
			if lst == null:
				continue
			for si in (lst as PackedInt32Array):
				if seen.has(si):
					continue
				seen[si] = true
				var rid: int = city.s_road[si]
				var ni: int = city.s_next[si]
				if ni < 0 or city._verge_road[rid] == 0:
					continue
				var a := Vector2(city.s_x[si], city.s_z[si])
				var b := Vector2(city.s_x[ni], city.s_z[ni])
				var seg_len := a.distance_to(b)
				if seg_len < 0.05:
					continue
				var rd: Dictionary = city.roads[rid]
				var hw: float = rd["hw"]
				var sw: float = rd["sw"]
				var reach := hw + sw + 3.0
				if maxf(a.x, b.x) < ox - reach or minf(a.x, b.x) > ox + span + reach or maxf(a.y, b.y) < oz - reach or minf(a.y, b.y) > oz + span + reach:
					continue
				var dir := (b - a) / seg_len
				var nrm := Vector2(-dir.y, dir.x)
				var ya: float = city.s_y[si]
				var yb: float = city.s_y[ni]
				var grade := (yb - ya) / seg_len # el tope sigue el plano de la calzada
				var m := maxi(1, int(ceil(seg_len / 1.5)))
				for k in m + 1:
					var t := float(k) / float(m)
					var c := a.lerp(b, t)
					var yr := lerpf(ya, yb, t)
					for lat in [-hw - sw, -hw, -hw * 0.5, 0.0, hw * 0.5, hw, hw + sw]:
						var l: float = lat
						# la calzada se dibuja a ROAD_UP y la banquina a CURB sobre el eje; la malla queda 3 cm por debajo
						var target := yr + (CityLayout.ROAD_UP if absf(l) <= hw + 0.01 else CityLayout.CURB) - 0.03
						TerrainCap.point(c.x + nrm.x * l, c.y + nrm.y * l, target, dir.x * grade, dir.y * grade, ox, oz, step, w, y0, cap)

func _terrain(s: Soup, x0: float, z0: float) -> void:
	var tc := TC
	var capped := _has_region_roads(x0, z0)
	var city_caps := _has_cap_roads(x0, z0)
	if capped:
		tc = TC_REGION_ROADS
	var n := int(CityLayout.CELL / tc)
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	if capped or city_caps:
		# el terreno de la ciudad también tapaba los caminos de la región (la malla queda por encima de una calzada que cruza una ladera): se calcula el corte igual que en
		# RegionWorld._terrain (con la misma grilla de 8 m), sobre una grilla con un anillo de vértices de más alrededor (los bordes de las cuadras vecinas salen iguales)
		var w := n + 3
		var y0 := PackedFloat32Array()
		y0.resize(w * w)
		for iz in w:
			for ix in w:
				y0[iz * w + ix] = _terrain_h(x0 + float(ix - 1) * tc, z0 + float(iz - 1) * tc)
		var cap := PackedFloat32Array()
		if capped:
			cap = region_world.road_caps(x0 - tc, z0 - tc, tc, w, y0)
		else:
			cap.resize(w * w)
			cap.fill(1.0e9)
		if city_caps:
			_city_caps(x0 - tc, z0 - tc, tc, w, cap, y0)
		for iz in n + 1:
			for ix in n + 1:
				var j := (iz + 1) * w + ix + 1
				hs[iz * (n + 1) + ix] = minf(y0[j], cap[j])
	else:
		for iz in n + 1:
			for ix in n + 1:
				hs[iz * (n + 1) + ix] = _terrain_h(x0 + float(ix) * tc, z0 + float(iz) * tc)
	for iz in n:
		for ix in n:
			var wx := x0 + float(ix) * tc
			var wz := z0 + float(iz) * tc
			var a := Vector3(wx, hs[iz * (n + 1) + ix], wz)
			var b := Vector3(wx + tc, hs[iz * (n + 1) + ix + 1], wz)
			var c := Vector3(wx + tc, hs[(iz + 1) * (n + 1) + ix + 1], wz + tc)
			var d := Vector3(wx, hs[(iz + 1) * (n + 1) + ix], wz + tc)
			var col := _ground_color(wx + tc * 0.5, wz + tc * 0.5, a.y)
			s.quad_up(a, d, c, b, col)

# ───────────────────────── calles ─────────────────────────
const C_ASPH := Color(0.50, 0.51, 0.56)
const C_SIDE := Color(0.84, 0.80, 0.72)
const C_CURB := Color(0.70, 0.67, 0.62)
const C_YEL := Color(1.0, 0.82, 0.30)
const C_WHT := Color(0.97, 0.96, 0.93)
const C_RURAL_SIDE := Color(0.66, 0.62, 0.50) # banquina de las rutas rurales (la usa _road_segment y el diagnóstico)

func _roads(rd: Soup, mk: Soup, key: Vector2i, tn: Soup) -> void:
	var x0 := float(key.x) * CityLayout.CELL
	var z0 := float(key.y) * CityLayout.CELL
	var x1 := x0 + CityLayout.CELL
	var z1 := z0 + CityLayout.CELL
	# los puntos de las calles que caen en esta cuadra (cada tramo dibuja hasta el punto siguiente)
	var kx0 := int(floor((x0 - 12.0) / CityLayout.HC))
	var kx1 := int(floor((x1 + 12.0) / CityLayout.HC))
	var kz0 := int(floor((z0 - 12.0) / CityLayout.HC))
	var kz1 := int(floor((z1 + 12.0) / CityLayout.HC))
	for kx in range(kx0, kx1 + 1):
		for kz in range(kz0, kz1 + 1):
			var k2 := Vector2i(kx, kz)
			if not city._hash.has(k2):
				continue
			for si in (city._hash[k2] as PackedInt32Array):
				var px: float = city.s_x[si]
				var pz: float = city.s_z[si]
				if px < x0 or px >= x1 or pz < z0 or pz >= z1:
					continue
				var ni: int = city.s_next[si]
				if ni < 0:
					continue
				_road_segment(rd, mk, si, ni, tn)
	# esquinas redondeadas de los cruces (asfalto): las dibuja la cuadra donde cae el centro de cada una
	for f in city.fillets_in(Rect2(x0, z0, CityLayout.CELL, CityLayout.CELL)):
		var fc := CityLayout.poly_box(f).get_center()
		if fc.x < x0 or fc.x >= x1 or fc.y < z0 or fc.y >= z1:
			continue
		_flat(rd, f, func(q: Vector2) -> float: return city.road_y_near(q), CityLayout.ROAD_UP, C_ASPH)

## Normal (hacia la derecha del avance) en el punto si, unida con la del tramo anterior (CityLayout.miter)
func _miter(si: int) -> Vector3:
	return city.miter(si)

## ¿Este punto cae adentro de la calzada de OTRA calle? (ahí no se dibuja la vereda: se cruza la calle)
func _in_other_road(x: float, z: float, own: int) -> bool:
	var kx := int(floor(x / CityLayout.HC))
	var kz := int(floor(z / CityLayout.HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not city._hash.has(k2):
				continue
			for sj in (city._hash[k2] as PackedInt32Array):
				var rid: int = city.s_road[sj]
				if rid == own:
					continue
				var nj: int = city.s_next[sj]
				if nj < 0:
					continue
				var ax: float = city.s_x[sj]
				var az: float = city.s_z[sj]
				var ex: float = city.s_x[nj] - ax
				var ez: float = city.s_z[nj] - az
				var l2 := ex * ex + ez * ez
				var t := clampf(((x - ax) * ex + (z - az) * ez) / maxf(l2, 0.0001), 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var hwo: float = (city.roads[rid] as Dictionary)["hw"]
				if ddx * ddx + ddz * ddz < (hwo + 0.3) * (hwo + 0.3):
					return true
	return false

func _road_segment(rd: Soup, mk: Soup, si: int, ni: int, tn: Soup) -> void:
	var road: Dictionary = city.roads[city.s_road[si]]
	var hw: float = road["hw"]
	var sw: float = road["sw"]
	var kind: String = road["kind"]
	var a := Vector3(city.s_x[si], city.s_y[si], city.s_z[si])
	var b := Vector3(city.s_x[ni], city.s_y[ni], city.s_z[ni])
	if Vector2(b.x - a.x, b.z - a.z).length() < 0.05:
		return
	if kind == "tunnel":
		_tunnel_segment(tn, si, ni)
		return
	var ma := _miter(si)
	var mb := _miter(ni)
	var na := Vector3(ma.x, 0.0, ma.y)
	var nb := Vector3(mb.x, 0.0, mb.y)
	var ka := ma.z
	var kb := mb.z
	var up := Vector3(0, CityLayout.ROAD_UP, 0)
	rd.quad_up(a - na * (hw * ka) + up, b - nb * (hw * kb) + up, b + nb * (hw * kb) + up, a + na * (hw * ka) + up, C_ASPH)
	# veredas: un plano a 1 cm del asfalto (sin cordón). Cada tramo se recorta contra las calzadas de las otras calles y las esquinas redondeadas (CityLayout.clip_obstacles): la vereda
	# termina donde empieza el cruce y no se mete en la calle de al lado (antes se salteaba entera si su medio caía en otra calle y quedaban escalones y cuñas)
	var side_col := C_SIDE
	if kind == "rural" or kind == "shortcut" or kind == "scenic":
		side_col = WorldSurfaces.side_color(C_RURAL_SIDE, (a.y + b.y) * 0.5) # (con nieve, la banquina no es tierra limpia)
	elif kind == "alley":
		side_col = Color(0.72, 0.46, 0.42) # veredas de ladrillo rojo
	var obst: Array = city.clip_obstacles(si)
	for sg in ([] if sw < 0.01 else [-1.0, 1.0]):
		var s: float = sg
		var e0a := a + na * (s * hw * ka)
		var e0b := b + nb * (s * hw * kb)
		var e1a := a + na * (s * (hw + sw) * ka)
		var e1b := b + nb * (s * (hw + sw) * kb)
		var quad := PackedVector2Array([Vector2(e0a.x, e0a.z), Vector2(e0b.x, e0b.z), Vector2(e1b.x, e1b.z), Vector2(e1a.x, e1a.z)])
		for part in _clip_all(quad, obst, 0.0):
			_sidewalk_part(rd, part, a, b, side_col, quad)
	# rayas: el borde de la calzada (blanco) y el eje (amarillo o blanco cortado). Se recortan contra las otras calzadas y esquinas: ninguna raya cruza otra calle. Las del eje no se
	# pintan cerca de los cruces (como antes); las del eje de una calle chica terminan donde empieza la calle grande.
	var local_i := si - _first_sample(city.s_road[si])
	var nj: PackedByteArray = road["nj"]
	var junc := nj.size() > local_i and nj[local_i] != 0
	if kind != "plaza" and kind != "bay":
		var lw := 0.11
		var mdy := CityLayout.ROAD_UP + PaperKit.MARK_UP # a 1,2 cm del asfalto; el shader de las rayas las sube con la distancia (antes 7 cm fijos: se veían flotando y tapaban las ruedas)
		if kind in ["major", "ring", "coast", "hill", "rural", "scenic"] and hw >= 4.0:
			if local_i % 3 != 2 and not junc: # raya del medio cortada
				var cc := C_YEL if kind != "ring" else C_WHT
				_mark_part(mk, a, b, na, nb, -lw, lw, mdy, cc, obst, hw)
			for sg in [-1.0, 1.0]:
				var s2: float = sg
				var o := (hw - 0.45) * s2
				_mark_part(mk, a, b, na, nb, o - 0.07, o + 0.07, mdy, C_WHT, obst, -1.0)
		elif local_i % 4 < 2 and not junc:
			_mark_part(mk, a, b, na, nb, -0.08, 0.08, mdy, C_WHT, obst, hw)

## Recorta el polígono p contra los obstáculos (calzadas ajenas y esquinas): lo que queda, en pedazos. min_hw: sólo recortan las calzadas con medio ancho ≥ ese valor (0 = todas)
func _clip_all(p: PackedVector2Array, obst: Array, min_hw: float) -> Array:
	var parts: Array = [p]
	if obst.is_empty():
		return parts
	var box := CityLayout.poly_box(p)
	for o in obst:
		if float(o["hw"]) < min_hw:
			continue
		var op: PackedVector2Array = o["poly"]
		if not CityLayout.poly_box(op).intersects(box):
			continue
		var next: Array = []
		for q in parts:
			if not CityLayout.poly_box(q).intersects(CityLayout.poly_box(op)):
				next.append(q)
				continue
			for r in Geometry2D.clip_polygons(q, op):
				if not Geometry2D.is_polygon_clockwise(r) and CityLayout.poly_area(r) > 0.02:
					next.append(r)
		parts = next
		if parts.is_empty():
			break
	return parts

## Altura del eje en el punto q (x, z) de un tramo a → b
func _y_on(q: Vector2, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l2 := ab.length_squared()
	var t := clampf((q - Vector2(a.x, a.z)).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0001 else 0.0
	return lerpf(a.y, b.y, t)

## Triángulos horizontales de un polígono (x, z) a la altura que da y_of + dy
func _flat(s: Soup, poly: PackedVector2Array, y_of: Callable, dy: float, col: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var p0: Vector2 = poly[idx[i]]
		var p1: Vector2 = poly[idx[i + 1]]
		var p2: Vector2 = poly[idx[i + 2]]
		var v0 := Vector3(p0.x, float(y_of.call(p0)) + dy, p0.y)
		var v1 := Vector3(p1.x, float(y_of.call(p1)) + dy, p1.y)
		var v2 := Vector3(p2.x, float(y_of.call(p2)) + dy, p2.y)
		var cy := (v1 - v0).cross(v2 - v0).y
		if absf(cy) < 2.0e-4:
			continue # triángulo sin área (la triangulación de un polígono recortado deja puntas repetidas)
		if cy < 0.0:
			s.tri(v0, v2, v1, col)
		else:
			s.tri(v0, v1, v2, col)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1.0e-9 else 0.0
	return p.distance_to(a + ab * t)

## Un pedazo de vereda (ya recortado): un plano a 1 cm del asfalto, sin cordón ni cara vertical (pedido del dueño, 20/10/2026: «un plano nomás, sin polígonos, sin altura»).
## quad = el cuadrilátero original del tramo (ya no hace falta para el cordón: se deja el parámetro por las llamadas).
func _sidewalk_part(rd: Soup, part: PackedVector2Array, a: Vector3, b: Vector3, col: Color, _quad: PackedVector2Array) -> void:
	var yf := func(q: Vector2) -> float: return _y_on(q, a, b)
	_flat(rd, part, yf, CityLayout.CURB, col)

## Una raya entre los desplazamientos o0 y o1 (a la derecha del eje) del tramo a → b, recortada contra las calzadas ajenas con medio ancho ≥ min_hw (−1 = contra todas)
func _mark_part(mk: Soup, a: Vector3, b: Vector3, na: Vector3, nb: Vector3, o0: float, o1: float, dy: float, col: Color, obst: Array, min_hw: float) -> void:
	var poly := PackedVector2Array([Vector2(a.x + na.x * o0, a.z + na.z * o0), Vector2(b.x + nb.x * o0, b.z + nb.z * o0), Vector2(b.x + nb.x * o1, b.z + nb.z * o1), Vector2(a.x + na.x * o1, a.z + na.z * o1)])
	var yf := func(q: Vector2) -> float: return _y_on(q, a, b)
	for part in _clip_all(poly, obst, maxf(min_hw, 0.0)):
		_flat(mk, part, yf, dy, col)

var _first_cache: Dictionary = {}
func _first_sample(road_id: int) -> int:
	if _first_cache.has(road_id):
		return _first_cache[road_id]
	var f := 0
	for i in city.s_road.size():
		if city.s_road[i] == road_id:
			f = i
			break
	_first_cache[road_id] = f
	return f

func _jit(c: Color, k: float) -> Color:
	var v := 0.025 * sin(k * 3.1)
	return Color(c.r + v, c.g + v, c.b + v)

# ───────────────────────── edificios ─────────────────────────
func _buildings(s: Soup, key: Vector2i) -> Array:
	var specials: Array = []
	for b in _buildings_soup(s, key):
		specials.append(_shop_front(b))
	return specials

## Las paredes y los techos de la cuadra (en la sopa s); devuelve los edificios con local (los frentes se arman aparte, en el principal). Sólo cuentas.
func _buildings_soup(s: Soup, key: Vector2i) -> Array:
	var pois: Array = []
	_slabs(s, key)
	if not city.buildings.has(key):
		return pois
	for b in city.buildings[key]:
		_box_building(s, b)
		if b.has("poi"):
			pois.append(b)
	return pois

func _box_building(s: Soup, b: Dictionary) -> void:
	var cen := Vector2(b["x"], b["z"])
	var w: float = b["w"]
	var d: float = b["d"]
	var h: float = b["h"]
	var by: float = b["y"]
	var yaw: float = b["yaw"]
	var tg := Vector2(sin(yaw), cos(yaw))
	var nm := Vector2(cos(yaw), -sin(yaw))
	var wall: Color = b["wall"]
	wall.a = float(b["seed"])
	var roof: Color = b["roof"]
	var base := by - 3.2 # el faldón baja bajo el nivel de la calle: así no quedan huecos en las lomas
	var top := by + h
	var c: Array = []
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			pass
	# esquinas en orden antihorario visto desde arriba: (-w,-d) (+w,-d) (+w,+d) (-w,+d)
	var corners := [cen + tg * (-w * 0.5) + nm * (-d * 0.5), cen + tg * (w * 0.5) + nm * (-d * 0.5), cen + tg * (w * 0.5) + nm * (d * 0.5), cen + tg * (-w * 0.5) + nm * (d * 0.5)]
	var lens := [w, d, w, d]
	for i in 4:
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		var wd: float = lens[i]
		# la pared visible desde afuera: orden elegido para que la normal salga del edificio
		var a := Vector3(p.x, base, p.y)
		var bb := Vector3(q.x, base, q.y)
		var cc := Vector3(q.x, top, q.y)
		var dd := Vector3(p.x, top, p.y)
		var sz := Vector2(wd, h)
		# v empieza en 0 a la altura de la calle (por debajo es el faldón)
		var outv := ((p + q) * 0.5 - cen).normalized()
		if b.has("show") and outv.dot(b["fn"]) > 0.9:
			# concesionario: la planta baja del frente es la vidriera (_showroom); la pared va abajo de la vereda y arriba de la vidriera
			var lo := Vector3(0, by + 0.1 - base, 0)
			var hi := Vector3(0, by + SHOW_H - base, 0)
			s.quad_out(a, a + lo, bb + lo, bb, wall, outv, Vector2(0, base - by), Vector2(0, 0.1), Vector2(wd, 0.1), Vector2(wd, base - by), sz)
			s.quad_out(a + hi, dd, cc, bb + hi, wall, outv, Vector2(0, SHOW_H), Vector2(0, h), Vector2(wd, h), Vector2(wd, SHOW_H), sz)
			continue
		s.quad_out(a, dd, cc, bb, wall, outv, Vector2(0, base - by), Vector2(0, h), Vector2(wd, h), Vector2(wd, base - by), sz)
	# techo
	if bool(b["hip"]):
		var apex := Vector3(cen.x, top + minf(w, d) * 0.38, cen.y)
		for i in 4:
			var p: Vector2 = corners[i]
			var q: Vector2 = corners[(i + 1) % 4]
			var t0 := Vector3(p.x, top, p.y)
			var t1 := Vector3(q.x, top, q.y)
			if (apex - t0).cross(t1 - t0).y > 0.0:
				s.tri(t0, apex, t1, roof)
			else:
				s.tri(t0, t1, apex, roof)
	else:
		var r0 := Vector3(corners[0].x, top, corners[0].y)
		var r1 := Vector3(corners[1].x, top, corners[1].y)
		var r2 := Vector3(corners[2].x, top, corners[2].y)
		var r3 := Vector3(corners[3].x, top, corners[3].y)
		s.quad_up(r0, r1, r2, r3, roof.darkened(0.15))
		# cajita en el techo (tanque de agua o salida de escalera) en algunos
		if float(b["seed"]) > 0.55 and w > 11.0:
			var bc := cen + tg * (w * 0.15) + nm * (d * 0.1)
			var bw := 3.2
			var bh := 2.4
			var q0 := Vector3(bc.x - bw * 0.5, top, bc.y - bw * 0.5)
			var q1 := Vector3(bc.x + bw * 0.5, top, bc.y - bw * 0.5)
			var q2 := Vector3(bc.x + bw * 0.5, top, bc.y + bw * 0.5)
			var q3 := Vector3(bc.x - bw * 0.5, top, bc.y + bw * 0.5)
			var up := Vector3(0, bh, 0)
			var cw := Color(0.78, 0.76, 0.72, 0.0)
			var bcv := Vector2(bc.x, bc.y)
			for fq in [[q0, q1], [q1, q2], [q2, q3], [q3, q0]]:
				var e0: Vector3 = fq[0]
				var e1: Vector3 = fq[1]
				var mid2 := Vector2((e0.x + e1.x) * 0.5, (e0.z + e1.z) * 0.5) - bcv
				s.quad_out(e0, e0 + up, e1 + up, e1, cw, mid2, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			s.quad_up(q0 + up, q1 + up, q2 + up, q3 + up, cw.darkened(0.12))

## Portón cerrado al final de una ruta rural: la salida a otra ciudad todavía no abrió (próxima actualización)
func _gate(ex: Dictionary) -> Node3D:
	var root := Node3D.new()
	var pos: Vector2 = ex["pos"]
	var yaw: float = ex["yaw"]
	var rd: Dictionary = city.roads[int(ex["road"])]
	var half := float(rd["hw"]) + float(rd["sw"]) - 0.4
	var y := city.height(pos.x, pos.y) + 0.05
	# a 1 m del final: el auto choca antes (los círculos de choque están en _gate_circles)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, y, pos.y))
	var v := PackedVector3Array()
	var c := PackedColorArray()
	CityProps.box(v, c, xf, Vector3(-half, 1.6, 0), Vector3(0.45, 3.2, 0.45), Color(0.9, 0.9, 0.9))
	CityProps.box(v, c, xf, Vector3(half, 1.6, 0), Vector3(0.45, 3.2, 0.45), Color(0.9, 0.9, 0.9))
	var open_gate := str(ex.get("to", "")) != ""
	var n := 0 if open_gate else int(ceil(half * 2.0 / 1.6)) # abierta: sin barrera, solo el pórtico
	for i in n:
		var cx := -half + (float(i) + 0.5) * (half * 2.0 / float(n))
		CityProps.box(v, c, xf, Vector3(cx, 1.1, 0), Vector3(half * 2.0 / float(n) + 0.02, 0.5, 0.2), Color(0.92, 0.2, 0.15) if i % 2 == 0 else Color(0.97, 0.97, 0.97))
	CityProps.box(v, c, xf, Vector3(0, 4.6, 0), Vector3(half * 2.0 + 1.2, 2.6, 0.3), Color(0.12, 0.28, 0.52))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var lab := Label3D.new()
	var dest_txt := Tr.t("PRÓXIMAMENTE")
	if open_gate:
		dest_txt = Tr.t("AVENTURA") if str(ex["to"]) == "adventure" else Tr.t("PLAZA DE DRIFT")
	lab.text = "%s\n%s" % [Tr.t("SALIDA %d") % int(ex["num"]), dest_txt]
	lab.font_size = 80
	lab.pixel_size = 0.012
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 14
	lab.outline_modulate = Color(0.05, 0.1, 0.2)
	lab.position = Vector3(pos.x - sin(yaw) * 0.25, y + 4.6, pos.y - cos(yaw) * 0.25)
	lab.rotation = Vector3(0, yaw + PI, 0)
	root.add_child(lab)
	return root

var _gate_ids := {}

## Círculos de choque que cierran la ruta (no se rompen): se agregan al armarse la cuadra y se sacan al borrarse
func _gate_circles(ex: Dictionary, add: bool) -> void:
	if str(ex.get("to", "")) != "":
		return # la salida abierta no tiene barrera
	var pos: Vector2 = ex["pos"]
	var yaw: float = ex["yaw"]
	var rd: Dictionary = city.roads[int(ex["road"])]
	var half := float(rd["hw"]) + float(rd["sw"])
	var tn := Vector2(sin(yaw), cos(yaw))
	var lat := Vector2(-tn.y, tn.x)
	var base_id := 100000 + int(ex["num"]) * 100
	var j := 0
	var d := -half
	while d <= half + 0.01:
		var p := pos - tn * 1.0 + lat * d
		if add:
			track.add_prop(base_id + j, p.x, p.y, 1.3)
		else:
			track.remove_prop(base_id + j, p.x, p.y)
		d += 2.0
		j += 1

## Frentes de la cuadra: las losas de pared pegadas a la calle (ver CityLayout._place_facades)
func _slabs(s: Soup, key: Vector2i) -> void:
	if not city.slabs.has(key):
		return
	for sl in (city.slabs[key] as Array):
		var pts: PackedVector3Array = sl["pts"]
		var away: PackedVector2Array = sl["away"]
		var h: float = sl["h"]
		var depth: float = sl["depth"]
		var wall: Color = sl["wall"]
		wall.a = float(sl["seed"])
		var side_col := Color(wall.r * 0.9, wall.g * 0.9, wall.b * 0.9, wall.a)
		var roof: Color = sl["roof"]
		var house: bool = sl["house"]
		var rise := minf(depth * 0.34, 3.0)
		# ancho total (para repartir las ventanas)
		var total := 0.0
		for i in pts.size() - 1:
			total += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
		var u0 := 0.0
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			var ap := away[i]
			var aq := away[i + 1]
			var ln := Vector2(q.x - p.x, q.z - p.z).length()
			if ln < 0.02:
				continue
			var u1 := u0 + ln
			var outv := -(ap + aq) * 0.5
			var f0 := Vector3(p.x, p.y - 3.2, p.z)
			var f1 := Vector3(q.x, q.y - 3.2, q.z)
			var t1 := Vector3(q.x, q.y + h, q.z)
			var t0 := Vector3(p.x, p.y + h, p.z)
			s.quad_out(f0, t0, t1, f1, wall, outv, Vector2(u0, -3.2), Vector2(u0, h), Vector2(u1, h), Vector2(u1, -3.2), Vector2(total, h))
			var bp := Vector3(p.x + ap.x * depth, p.y + h, p.z + ap.y * depth)
			var bq := Vector3(q.x + aq.x * depth, q.y + h, q.z + aq.y * depth)
			var bp0 := Vector3(bp.x, p.y - 3.2, bp.z)
			var bq0 := Vector3(bq.x, q.y - 3.2, bq.z)
			# pared de atrás (lisa): solo se ve desde una cámara alta
			s.quad_out(bp0, bp, bq, bq0, side_col, -outv, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			if house:
				var rp := Vector3((p.x + bp.x) * 0.5, p.y + h + rise, (p.z + bp.z) * 0.5)
				var rq := Vector3((q.x + bq.x) * 0.5, q.y + h + rise, (q.z + bq.z) * 0.5)
				s.quad_up(t0, t1, rq, rp, roof)
				s.quad_up(rp, rq, bq, bp, roof.darkened(0.12))
			else:
				s.quad_up(t0, t1, bq, bp, roof.darkened(0.15))
			u0 = u1
		# costados donde el vecino es más bajo (o no hay vecino y es una casa: el hastial)
		var p0 := pts[0]
		var pe := pts[pts.size() - 1]
		var tg0 := Vector2(pts[1].x - p0.x, pts[1].z - p0.z).normalized()
		var tge := Vector2(pe.x - pts[pts.size() - 2].x, pe.z - pts[pts.size() - 2].z).normalized()
		var hp: float = sl["hp"]
		var hn: float = sl["hn"]
		# los edificios son cajas cerradas (pedido del dueño): sin vecino, o con un vecino menos hondo, el costado va entero desde abajo
		if hp <= 0.0 or float(sl.get("dp", depth)) < depth - 0.1:
			_side_wall(s, p0, away[0], depth, -3.2, h, -tg0, side_col)
		elif hp < h - 0.1:
			_side_wall(s, p0, away[0], depth, hp, h, -tg0, side_col)
		if hn <= 0.0 or float(sl.get("dn", depth)) < depth - 0.1:
			_side_wall(s, pe, away[away.size() - 1], depth, -3.2, h, tge, side_col)
		elif hn < h - 0.1:
			_side_wall(s, pe, away[away.size() - 1], depth, hn, h, tge, side_col)
		if house:
			if hp < h + rise:
				_gable(s, p0, away[0], depth, h, rise, -tg0, side_col)
			if hn < h + rise:
				_gable(s, pe, away[away.size() - 1], depth, h, rise, tge, side_col)

## Costado de una losa entre la altura del vecino (y0) y la propia (y1): un rectángulo que mira hacia out
func _side_wall(s: Soup, p: Vector3, a: Vector2, depth: float, h0: float, h1: float, out: Vector2, col: Color) -> void:
	var b := Vector3(p.x + a.x * depth, p.y, p.z + a.y * depth)
	# el costado también lleva ventanas (el shader las dibuja con la altura sobre la calle: v de h0 a h1)
	s.quad_out(Vector3(p.x, p.y + h0, p.z), Vector3(p.x, p.y + h1, p.z), Vector3(b.x, p.y + h1, b.z), Vector3(b.x, p.y + h0, b.z), col, out, Vector2(0, h0), Vector2(0, h1), Vector2(depth, h1), Vector2(depth, h0), Vector2(depth, h1))

## Triángulo de hastial de una casa (el costado del techo a dos aguas)
func _gable(s: Soup, p: Vector3, a: Vector2, depth: float, h: float, rise: float, out: Vector2, col: Color) -> void:
	var t0 := Vector3(p.x, p.y + h, p.z)
	var tb := Vector3(p.x + a.x * depth, p.y + h, p.z + a.y * depth)
	var rg := Vector3(p.x + a.x * depth * 0.5, p.y + h + rise, p.z + a.y * depth * 0.5)
	var nr := (tb - t0).cross(rg - t0)
	if nr.x * out.x + nr.z * out.y < 0.0:
		s.tri(t0, rg, tb, col)
	else:
		s.tri(t0, tb, rg, col)

## Un tramo del túnel: piso con rayas y manchas de luz, dos paredes con franja, techo y lámparas. En el cruce del centro las paredes se abren hacia la otra calle.
func _tunnel_segment(tn: Soup, si: int, ni: int) -> void:
	var rid: int = city.s_road[si]
	var road: Dictionary = city.roads[rid]
	var hw: float = road["hw"]
	var a := Vector3(city.s_x[si], city.s_y[si], city.s_z[si])
	var b := Vector3(city.s_x[ni], city.s_y[ni], city.s_z[ni])
	var ma := _miter(si)
	var mb := _miter(ni)
	var na := Vector3(ma.x, 0.0, ma.y)
	var nb := Vector3(mb.x, 0.0, mb.y)
	var li := si - _first_sample(rid)
	var hgt := 6.2
	var wx := hw + 0.3
	var up := Vector3(0, hgt, 0)
	var lit := li % 2 == 0
	tn.quad(a - na * wx, b - nb * wx, b + nb * wx, a + na * wx, Color(0.30, 0.31, 0.36) if lit else Color(0.20, 0.21, 0.25))
	var lu := Vector3(0, 0.03, 0)
	if li % 3 != 2:
		tn.quad(a - na * 0.12 + lu, b - nb * 0.12 + lu, b + nb * 0.12 + lu, a + na * 0.12 + lu, Color(0.95, 0.80, 0.15))
	for sg in [-1.0, 1.0]:
		var s: float = sg
		tn.quad(a + na * (hw - 0.55) * s + lu, b + nb * (hw - 0.55) * s + lu, b + nb * (hw - 0.4) * s + lu, a + na * (hw - 0.4) * s + lu, Color(0.92, 0.92, 0.92))
		var mid := (a + b) * 0.5 + (na + nb) * 0.5 * (wx * s)
		if not str(road["name"]).begins_with("Rampa") and _in_other_road(mid.x, mid.z, rid):
			continue # la bifurcación: acá la pared se abre hacia la otra calle
		var wa := a + na * (wx * s)
		var wb := b + nb * (wx * s)
		tn.quad(wa, wa + up, wb + up, wb, Color(0.66, 0.68, 0.72) if lit else Color(0.57, 0.59, 0.64))
		tn.quad(wa + Vector3(0, 0.9, 0), wa + Vector3(0, 1.5, 0), wb + Vector3(0, 1.5, 0), wb + Vector3(0, 0.9, 0), Color(0.95, 0.52, 0.14)) # franja naranja
		tn.quad(wa + Vector3(0, 5.0, 0), wa + Vector3(0, 5.25, 0), wb + Vector3(0, 5.25, 0), wb + Vector3(0, 5.0, 0), Color(1.0, 0.96, 0.75) if lit else Color(0.85, 0.82, 0.62)) # tira de luz
	var ceil_y := Vector3(0, hgt + float(rid % 3) * 0.02, 0)
	tn.quad(a - na * wx + ceil_y, b - nb * wx + ceil_y, b + nb * wx + ceil_y, a + na * wx + ceil_y, Color(0.34, 0.35, 0.40))
	if lit:
		var l0 := a.lerp(b, 0.2)
		var l1 := a.lerp(b, 0.8)
		var cy := Vector3(0, hgt - 0.02, 0)
		tn.quad(l0 - na * 0.8 + cy, l1 - nb * 0.8 + cy, l1 + nb * 0.8 + cy, l0 + na * 0.8 + cy, Color(1.0, 0.97, 0.78))
	# cierres de las puntas de los brazos: pared verde (la salida); las rampas del estacionamiento quedan abiertas a las salas
	var is_ramp := str(road["name"]).begins_with("Rampa")
	if city.s_prev[si] < 0 and not is_ramp:
		tn.quad(a - na * wx, a - na * wx + up, a + na * wx + up, a + na * wx, Color(0.18, 0.62, 0.34))
	if city.s_next[ni] < 0 and not is_ramp:
		tn.quad(b - nb * wx, b - nb * wx + up, b + nb * wx + up, b + nb * wx, Color(0.18, 0.62, 0.34))

## Una gasolinera: playón con techo sobre las islas de surtidores, carriles con círculos verdes (3 a 6 puntos de carga), kiosco al fondo con vidriera, poste de precios y carteles.
## Las medidas salen de CityLayout.STATION_KINDS (grande de carga rápida, mediana y chica). Los surtidores, las columnas y los bloques del kiosco son objetos (no se rompen).
func _station(st: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "station_" + str(st["id"])
	var kd: Dictionary = CityLayout.STATION_KINDS[str(st["kind"])]
	var c: Vector2 = st["center"]
	var nr: Vector2 = st["dir"]
	var col: Color = st["color"]
	var fast: bool = bool(st["fast"])
	var y := city.height(c.x, c.y)
	var xf := Transform3D(Basis(Vector3.UP, atan2(nr.x, nr.y)), Vector3(c.x, y, c.y)) # +z local = hacia el fondo del lote, +x = a lo largo de la calle
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	var white := Color(0.97, 0.97, 0.96)
	var dark := Color(0.25, 0.27, 0.30)
	var cw: float = kd["canopy"][0]
	var cd: float = kd["canopy"][1]
	# techo: losa del color de la marca con cantos blancos (a rayas amarillas y negras en la de carga rápida) y la cara de abajo clara
	CityProps.prism_roof(v, cl, xf, cw, cd, 4.95, 1.1, col, Color(0.92, 0.92, 0.9))
	CityProps.box(v, cl, xf, Vector3(0, 5.2, -cd * 0.5 - 0.02), Vector3(cw + 0.2, 0.9, 0.3), white)
	CityProps.box(v, cl, xf, Vector3(0, 5.2, cd * 0.5 + 0.02), Vector3(cw + 0.2, 0.9, 0.3), white)
	# banderines de papel colgando de los aleros (de la marca, blancos y amarillos)
	var flags: Array = [col, white, Color(0.97, 0.80, 0.15), col.lightened(0.25), white]
	CityProps.bunting(v, cl, xf, Vector3(-cw * 0.5, 4.7, -cd * 0.5 - 0.25), Vector3(cw * 0.5, 4.7, -cd * 0.5 - 0.25), flags)
	CityProps.bunting(v, cl, xf, Vector3(-cw * 0.5, 4.7, cd * 0.5 + 0.25), Vector3(cw * 0.5, 4.7, cd * 0.5 + 0.25), flags)
	if fast:
		var nst := int(cw / 2.0)
		for k in nst:
			if k % 2 == 0:
				CityProps.box(v, cl, xf, Vector3(-cw * 0.5 + 1.0 + float(k) * 2.0, 5.2, -cd * 0.5 - 0.06), Vector3(1.0, 0.92, 0.1), Color(0.12, 0.12, 0.14))
	# islas de surtidores (con cordón amarillo) y base de las columnas
	var pz: Array = [0.0] if float(kd["isle"][1]) == 0.0 else [-float(kd["isle"][1]), float(kd["isle"][1])]
	for iz in pz:
		CityProps.box(v, cl, xf, Vector3(0, 0.1, float(iz)), Vector3(float(kd["isle"][0]), 0.2, 1.7), Color(0.78, 0.78, 0.75))
		CityProps.box(v, cl, xf, Vector3(0, 0.21, float(iz)), Vector3(float(kd["isle"][0]) + 0.1, 0.03, 0.4), Color(0.96, 0.82, 0.12))
	for pc in st["pillars"]:
		var lp: Vector2 = pc
		var rel := lp - c
		var lxw: Vector2 = st["lx"]
		var lxz := rel.dot(lxw)
		var lzz := rel.dot(nr)
		if absf(lxz) < cw * 0.5 and absf(lzz) < cd * 0.5:
			CityProps.box(v, cl, xf, Vector3(lxz, 2.6, lzz), Vector3(0.9, 5.2, 0.9), white)
			CityProps.box(v, cl, xf, Vector3(lxz, 0.7, lzz), Vector3(1.0, 1.4, 1.0), col.darkened(0.15))
	# kiosco al fondo: vidriera iluminada, puerta y techo del color de la marca
	var kw: float = kd["kiosk"][0]
	var kdp: float = kd["kiosk"][1]
	var kz: float = kd["kiosk"][2]
	CityProps.box(v, cl, xf, Vector3(0, 2.1, kz), Vector3(kw, 4.2, kdp), Color(0.93, 0.92, 0.88))
	CityProps.box(v, cl, xf, Vector3(0, 4.45, kz), Vector3(kw + 1.0, 0.5, kdp + 1.0), col)
	CityProps.box(v, cl, xf, Vector3(-kw * 0.12, 1.9, kz - kdp * 0.5 - 0.04), Vector3(kw * 0.62, 2.2, 0.12), Color(0.16, 0.30, 0.45))
	CityProps.box(v, cl, xf, Vector3(kw * 0.36, 1.3, kz - kdp * 0.5 - 0.04), Vector3(1.4, 2.6, 0.14), col.darkened(0.2))
	# poste de precios junto a la calle (en el último «pilar» de la lista)
	var tp: Vector2 = (st["pillars"] as Array)[(st["pillars"] as Array).size() - 1]
	var trel := tp - c
	var tx := trel.dot(st["lx"] as Vector2)
	var tz := trel.dot(nr)
	CityProps.box(v, cl, xf, Vector3(tx, 4.0, tz), Vector3(0.5, 8.0, 0.5), dark)
	CityProps.box(v, cl, xf, Vector3(tx, 7.6, tz), Vector3(3.4, 2.4, 0.4), col)
	CityProps.box(v, cl, xf, Vector3(tx, 7.6, tz - 0.22), Vector3(3.0, 2.0, 0.1), white)
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, cl, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# de noche: luces del techo, vidriera y un charco de luz bajo la marquesina
	var gv := PackedVector3Array()
	var gc := PackedColorArray()
	CityProps.box(gv, gc, xf, Vector3(0, 4.82, 0), Vector3(cw - 1.0, 0.08, cd - 1.0), Color(1.0, 0.96, 0.82, 1.0))
	CityProps.box(gv, gc, xf, Vector3(-kw * 0.12, 1.9, kz - kdp * 0.5 - 0.1), Vector3(kw * 0.6, 2.0, 0.1), Color(1.0, 0.85, 0.5, 0.8))
	CityProps.halo(gv, gc, xf, Vector3(0, 0.07, 0), maxf(cw, cd) * 0.62, Color(1.0, 0.92, 0.7, 0.55), 16)
	root.add_child(_glow_instance(gv, gc, 260.0))
	for fp in st["fuel_points"]:
		var ring := _circle_mesh(1.9, 2.3, Color(0.20, 0.85, 0.35), Color(0.97, 0.97, 0.97))
		ring.position = Vector3((fp as Vector2).x, city.height((fp as Vector2).x, (fp as Vector2).y) + 0.1, (fp as Vector2).y)
		root.add_child(ring)
	# carteles: en el frente del techo (hacia la calle) y en el poste de precios
	var face := atan2(-nr.x, -nr.y)
	var fp0 := c - nr * (cd * 0.5 + 0.2)
	var title := Tr.t("CARGA RÁPIDA") if fast else Tr.t("GASOLINERA")
	root.add_child(_label3d(title, Vector3(fp0.x, y + 5.2, fp0.y), face, 0.016 if cw > 30.0 else 0.012, Color(0.1, 0.1, 0.12) if fast else Color(1, 1, 1), 72))
	var tw := c + (st["lx"] as Vector2) * tx + nr * (tz - 0.3)
	root.add_child(_label3d(Tr.t("GASOLINERA") if not fast else Tr.t("CARGA RÁPIDA"), Vector3(tw.x, y + 7.6, tw.y), face, 0.0075, Color(0.1, 0.1, 0.12), 60))
	return root

func _label3d(text: String, pos: Vector3, yaw: float, px: float, col: Color, fsize: int) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = fsize
	lab.pixel_size = px
	lab.modulate = col
	lab.outline_size = 10
	lab.outline_modulate = Color(0.97, 0.97, 0.95) if col.v < 0.4 else Color(0.1, 0.1, 0.12)
	lab.position = pos
	lab.rotation = Vector3(0, yaw, 0)
	return lab

## Un peaje: pórtico sobre la ruta, isla central con la cabina y una barrera por carril (las barreras las mueve CityToll). Marco local: +z = hacia afuera de la ciudad.
func _toll(t: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "toll_" + str(t["id"])
	var pos: Vector2 = t["pos"]
	var tn: Vector2 = t["tn"]
	var hw: float = t["hw"]
	var y := city.height(pos.x, pos.y)
	var xf := Transform3D(Basis(Vector3.UP, atan2(tn.x, tn.y)), Vector3(pos.x, y, pos.y))
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	var white := Color(0.97, 0.97, 0.96)
	var red := Color(0.85, 0.18, 0.15)
	var gray := Color(0.30, 0.32, 0.36)
	var toll_trees: Array = []
	# pórtico: dos postes junto a la banquina y una viga con franja roja
	for sx in [-1.0, 1.0]:
		CityProps.box(v, cl, xf, Vector3(float(sx) * (hw + 1.0), 3.3, 0), Vector3(0.7, 6.6, 0.7), white)
		CityProps.box(v, cl, xf, Vector3(float(sx) * (hw + 1.0), 0.5, 0), Vector3(0.9, 1.0, 0.9), red)
	CityProps.box(v, cl, xf, Vector3(0, 6.3, 0), Vector3(hw * 2.0 + 3.2, 1.1, 4.0), white)
	CityProps.box(v, cl, xf, Vector3(0, 6.05, -2.02), Vector3(hw * 2.0 + 3.3, 0.4, 0.1), red)
	CityProps.box(v, cl, xf, Vector3(0, 6.05, 2.02), Vector3(hw * 2.0 + 3.3, 0.4, 0.1), red)
	# isla central con la cabina (se ve desde los dos carriles)
	CityProps.box(v, cl, xf, Vector3(0, 0.12, 0), Vector3(2.2, 0.24, 12.0), Color(0.78, 0.78, 0.75))
	CityProps.box(v, cl, xf, Vector3(0, 0.25, 0), Vector3(2.3, 0.04, 12.1), Color(0.96, 0.82, 0.12))
	CityProps.box(v, cl, xf, Vector3(0, 1.8, 0.0), Vector3(1.7, 3.2, 3.6), white)
	CityProps.box(v, cl, xf, Vector3(0, 2.2, 0.0), Vector3(1.78, 1.2, 2.8), Color(0.16, 0.30, 0.45))
	CityProps.box(v, cl, xf, Vector3(0, 3.55, 0.0), Vector3(2.4, 0.3, 4.4), red)
	# postes de las barreras
	for sx in [-1.0, 1.0]:
		CityProps.box(v, cl, xf, Vector3(float(sx) * 1.3, 0.55, 3.2), Vector3(0.35, 1.1, 0.35), gray)
	# conos y marcas
	for sx in [-1.0, 1.0]:
		for k in 3:
			CityProps.frustum(v, cl, xf, Vector3(float(sx) * (hw - 0.6), 0.0, -5.0 - float(k) * 3.0), 0.32, 0.04, 0.7, 4, Color(1.0, 0.45, 0.1), 0.785)
	# banderines de papel en el pórtico y canteros con flores y árboles a los costados (de adorno, fuera de la calzada)
	var tflags: Array = [red, white, Color(0.97, 0.80, 0.15), white]
	CityProps.bunting(v, cl, xf, Vector3(-hw - 1.0, 5.7, -2.3), Vector3(hw + 1.0, 5.7, -2.3), tflags)
	CityProps.bunting(v, cl, xf, Vector3(-hw - 1.0, 5.7, 2.3), Vector3(hw + 1.0, 5.7, 2.3), tflags)
	for sx in [-1.0, 1.0]:
		PieceBatch.add("bush_flower_box", Vector3(float(sx) * (hw + 3.2), 0.0, 3.5), 1.57, 0.0, v, cl, xf)
		PieceBatch.add("bush_plant_box", Vector3(float(sx) * (hw + 3.2), 0.0, -4.0), 1.57, 0.0, v, cl, xf)
		for tt in [[hw + 5.2, 7.0, 1, 0.65], [hw + 5.6, -9.0, 5, 0.75]]: # dos árboles de imagen por lado
			var tw: Vector3 = xf * Vector3(float(sx) * float(tt[0]), 0.0, float(tt[1]))
			toll_trees.append(TreeSprites.item(tw.x, city.height(tw.x, tw.z), tw.z, int(tt[2]), float(tt[3]), 0.4 + float(tt[1]), fposmod(float(tt[1]) * 0.173 + 0.3, 1.0)))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, cl, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var ttn := TreeSprites.build(toll_trees, view_k)
	if ttn != null:
		root.add_child(ttn)
	# las barreras: una barra a rayas rojas y blancas que gira sobre su poste (arm0 a la derecha, arm1 a la izquierda); viven en un marco con la orientación del peaje
	var frame := Node3D.new()
	frame.name = "frame"
	frame.transform = xf
	root.add_child(frame)
	for lane in 2:
		var sg := 1.0 if lane == 0 else -1.0
		var pivot := Node3D.new()
		pivot.name = "arm%d" % lane
		pivot.position = Vector3(sg * 1.3, 1.0, 3.2)
		var av := PackedVector3Array()
		var ac := PackedColorArray()
		var seg := 6
		var len := hw - 1.3 + 0.3
		for k in seg:
			CityProps.box(av, ac, Transform3D(), Vector3(sg * (len / float(seg)) * (float(k) + 0.5), 0.0, 0.0), Vector3(len / float(seg), 0.16, 0.16), red if k % 2 == 0 else white)
		var am := ArrayMesh.new()
		PaperKit.add_surface(am, av, ac, PaperKit.material(null, 0.0, 0.2, 0.3))
		var ami := MeshInstance3D.new()
		ami.mesh = am
		ami.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(ami)
		frame.add_child(pivot)
	# cartel del pórtico, a los dos lados
	var face_in := atan2(-tn.x, -tn.y)
	var sign_pos := pos - tn * 2.15
	root.add_child(_label3d("%s · %d" % [Tr.t("PEAJE"), int(t["price"])], Vector3(sign_pos.x, y + 6.3, sign_pos.y), face_in, 0.014, Color(0.1, 0.1, 0.12), 72))
	var sign_pos2 := pos + tn * 2.15
	root.add_child(_label3d(Tr.t("PEAJE"), Vector3(sign_pos2.x, y + 6.3, sign_pos2.y), face_in + PI, 0.014, Color(0.1, 0.1, 0.12), 72))
	# de noche: luz bajo el pórtico y charco sobre la calzada
	var gv := PackedVector3Array()
	var gc := PackedColorArray()
	CityProps.box(gv, gc, xf, Vector3(0, 5.7, 0), Vector3(hw * 2.0 + 1.0, 0.08, 3.0), Color(1.0, 0.96, 0.82, 1.0))
	CityProps.box(gv, gc, xf, Vector3(0, 2.2, -0.92), Vector3(1.4, 1.0, 0.08), Color(1.0, 0.85, 0.5, 0.8))
	CityProps.halo(gv, gc, xf, Vector3(0, 0.08, 0), 11.0, Color(1.0, 0.9, 0.65, 0.5), 14)
	root.add_child(_glow_instance(gv, gc, 260.0))
	return root

## Marca circular del suelo (el círculo verde de los locales y de las salidas)
func _circle_mesh(r_in: float, r_out: float, col_in: Color, col_out: Color) -> MeshInstance3D:
	var cv := PackedVector3Array()
	var cc := PackedColorArray()
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var c0 := Vector3(cos(a0) * r_in, 0, sin(a0) * r_in)
		var c1 := Vector3(cos(a1) * r_in, 0, sin(a1) * r_in)
		cv.append_array(PackedVector3Array([Vector3.ZERO, c0, c1]))
		for k in 3:
			cc.append(col_in)
		var o0 := Vector3(cos(a0) * r_out, 0, sin(a0) * r_out)
		var o1 := Vector3(cos(a1) * r_out, 0, sin(a1) * r_out)
		cv.append_array(PackedVector3Array([c0, o0, o1, c0, o1, c1]))
		for k in 6:
			cc.append(col_out)
	var cm := ArrayMesh.new()
	PaperKit.add_surface(cm, cv, cc, PaperKit.material(null, 0.0, 0.2, 0.0))
	var cmi := MeshInstance3D.new()
	cmi.mesh = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cmi

## Sala del estacionamiento subterráneo: piso con rayas, pared redonda con franja, techo con lámparas y el círculo verde de la salida (los pilares y los autos son objetos)
func _hall(h: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "sala"
	var c: Vector2 = h["pos"]
	var r: float = h["r"]
	var hgt: float = h["h"]
	var fy: float = h.get("y", 0.0) # altura del piso de esta sala
	var gaps: Array = h.get("gaps", [])
	var s := Soup.new()
	var n := 40
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := Vector3(c.x + cos(a0) * r, fy, c.y + sin(a0) * r)
		var p1 := Vector3(c.x + cos(a1) * r, fy, c.y + sin(a1) * r)
		var cen := Vector3(c.x, fy, c.y)
		var cu := Vector3(0, hgt, 0)
		s.tri(cen + Vector3(0, 0.02, 0), p0 + Vector3(0, 0.02, 0), p1 + Vector3(0, 0.02, 0), Color(0.25, 0.26, 0.30))
		s.tri(cen + cu, p0 + cu, p1 + cu, Color(0.32, 0.33, 0.38))
		# la pared se abre donde empieza una rampa (el techo y el piso siguen)
		var am := (a0 + a1) * 0.5
		var open := false
		for g in gaps:
			if absf(wrapf(am - float(g[0]), -PI, PI)) < float(g[1]) - 0.5 * (a1 - a0) * 0.5:
				open = true
		if open:
			continue
		var sk := Vector3(0, -7.0, 0)
		s.quad(p0 + sk, p0 + cu, p1 + cu, p1 + sk, Color(0.64, 0.66, 0.70) if i % 2 == 0 else Color(0.56, 0.58, 0.63))
		s.quad(p0 + Vector3(0, 0.9, 0), p0 + Vector3(0, 1.5, 0), p1 + Vector3(0, 1.5, 0), p1 + Vector3(0, 0.9, 0), Color(0.95, 0.52, 0.14))
	# rayas de los lugares: líneas radiales en la corona exterior y el borde del pasillo (proporcional al radio: la sala de 42 m las dibuja entre 29 y 41 m)
	for i in 44:
		var a := TAU * float(i) / 44.0
		var skip := false
		for g in gaps:
			if absf(wrapf(a - float(g[0]), -PI, PI)) < float(g[1]) + 0.12:
				skip = true
		if skip:
			continue
		var d := Vector3(cos(a), 0, sin(a))
		var t := Vector3(-sin(a), 0, cos(a))
		var p_in := Vector3(c.x, fy + 0.04, c.y) + d * (r * 0.7)
		var p_out := Vector3(c.x, fy + 0.04, c.y) + d * (r * 0.975)
		s.quad(p_in - t * 0.07, p_out - t * 0.07, p_out + t * 0.07, p_in + t * 0.07, Color(0.92, 0.92, 0.92))
	for k in [r * 0.285, r * 0.57, r * 0.81]:
		var m_n := 8 if k < r * 0.48 else (12 if k < r * 0.71 else 14)
		for i in m_n:
			var a := TAU * (float(i) + 0.5) / float(m_n)
			var lc := Vector3(c.x + cos(a) * k, fy + hgt - 0.02, c.y + sin(a) * k)
			s.quad(lc + Vector3(-1.4, 0, -0.5), lc + Vector3(1.4, 0, -0.5), lc + Vector3(1.4, 0, 0.5), lc + Vector3(-1.4, 0, 0.5), Color(1.0, 0.97, 0.78))
	var m := ArrayMesh.new()
	_surface(m, s, _tunnel_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root

## La boca de un túnel (en la superficie) o del estacionamiento: una masa de papel con la entrada oscura
func _mouth(mo: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "boca_" + str(mo["id"])
	var pos: Vector2 = mo["pos"]
	var d: Vector2 = mo["dir"]
	var y := city.height(pos.x, pos.y)
	var xf := Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3(pos.x, y, pos.y)) # +z local = hacia adentro de la boca
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var mouth_trees: Array = []
	if str(mo["kind"]) == "park":
		CityProps.box(v, c, xf, Vector3(0, 2.2, 5.0), Vector3(17.0, 4.4, 10.0), Color(0.64, 0.66, 0.70))
		CityProps.box(v, c, xf, Vector3(0, 1.6, -0.08), Vector3(8.4, 3.2, 0.3), Color(0.07, 0.07, 0.09))
		CityProps.box(v, c, xf, Vector3(0, 4.9, -0.1), Vector3(7.0, 1.7, 0.4), Color(0.14, 0.34, 0.80))
		for k in 8:
			CityProps.box(v, c, xf, Vector3(-3.5 + 1.0 * float(k), 3.4, -0.1), Vector3(0.9, 0.35, 0.3), Color(0.95, 0.80, 0.15) if k % 2 == 0 else Color(0.12, 0.12, 0.14))
	else:
		# la ladera: un cerro de papel (tronco de cono con lomas) con el frente de roca alrededor de la boca y algunos árboles arriba
		CityProps.frustum(v, c, xf, Vector3(0, 0, 16.0), 30.0, 11.0, 14.0, 9, Color(0.46, 0.60, 0.40), 0.3)
		CityProps.frustum(v, c, xf, Vector3(-14.0, 0, 11.0), 12.0, 4.0, 8.5, 7, Color(0.52, 0.62, 0.42), 0.1)
		CityProps.frustum(v, c, xf, Vector3(15.0, 0, 9.0), 10.0, 3.5, 6.5, 7, Color(0.50, 0.58, 0.40), 0.5)
		CityProps.box(v, c, xf, Vector3(0, 4.0, 2.0), Vector3(22.0, 8.0, 4.0), Color(0.58, 0.58, 0.54))
		CityProps.box(v, c, xf, Vector3(-9.0, 7.6, 3.0), Vector3(6.0, 1.2, 5.0), Color(0.66, 0.66, 0.62))
		for tk in 5: # algunos árboles arriba (imágenes)
			var tx := float(pos.x) + (float(tk) - 2.0) * 3.5 * cos(atan2(d.x, d.y)) + d.x * 14.0
			var tz := float(pos.y) - (float(tk) - 2.0) * 3.5 * sin(atan2(d.x, d.y)) + d.y * 14.0
			var tsp := TreeSprites.pick(tx, tz, fposmod(0.2 * float(tk) + 0.13, 1.0))
			mouth_trees.append(TreeSprites.item(tx, y + 12.5 - absf(float(tk) - 2.0) * 0.8, tz, tsp, 0.7, 0.2 * float(tk), fposmod(0.2 * float(tk) + 0.31, 1.0)))
		CityProps.box(v, c, xf, Vector3(0, 2.7, -0.1), Vector3(10.4, 5.4, 0.3), Color(0.05, 0.05, 0.07))
		for k in 10:
			CityProps.box(v, c, xf, Vector3(-4.5 + 1.0 * float(k), 5.9, -0.1), Vector3(0.9, 0.7, 0.4), Color(0.95, 0.52, 0.14) if k % 2 == 0 else Color(0.10, 0.10, 0.12))
		for sgn in [-1.0, 1.0]:
			CityProps.box(v, c, xf, Vector3(6.1 * float(sgn), 1.6, -7.0), Vector3(0.8, 3.2, 14.0), Color(0.72, 0.72, 0.74))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var mtn := TreeSprites.build(mouth_trees, view_k)
	if mtn != null:
		root.add_child(mtn)
	if str(mo["kind"]) == "park":
		var lab := Label3D.new()
		lab.text = "P  " + Tr.t("ESTACIONAMIENTO")
		lab.font_size = 64
		lab.pixel_size = 0.012
		lab.modulate = Color(1, 1, 1)
		lab.outline_size = 12
		lab.outline_modulate = Color(0.05, 0.12, 0.35)
		lab.position = Vector3(pos.x - d.x * 0.35, y + 4.9, pos.y - d.y * 0.35)
		lab.rotation = Vector3(0, atan2(-d.x, -d.y), 0)
		root.add_child(lab)
	return root

## La entrada del Estacionamiento Central, vista desde la ruta: un tablero azul con la «P» sobre dos postes, al costado del camino de entrada
func _garage_sign() -> Node3D:
	var root := Node3D.new()
	root.name = "cartel_estacionamiento"
	var p0: Vector2 = city.garage["p"]
	var nrm: Vector2 = city.garage["nrm"]
	var tn: Vector2 = city.garage["tn"]
	var hw_r: float = float((city.roads[int(city.garage["road"])] as Dictionary)["hw"])
	var base: Vector2 = p0 + nrm * (hw_r + 3.2) + tn * 9.0
	var y: float = float((city.garage["y"] as Array)[0])
	var yaw := atan2(-tn.x, -tn.y) # el tablero mira al tránsito que viene de la ciudad
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(base.x, y, base.y))
	var v := PackedVector3Array()
	var c := PackedColorArray()
	CityProps.box(v, c, xf, Vector3(-1.4, 2.0, 0), Vector3(0.22, 4.0, 0.22), Color(0.55, 0.56, 0.60))
	CityProps.box(v, c, xf, Vector3(1.4, 2.0, 0), Vector3(0.22, 4.0, 0.22), Color(0.55, 0.56, 0.60))
	CityProps.box(v, c, xf, Vector3(0, 4.6, 0), Vector3(3.6, 2.4, 0.2), Color(0.97, 0.97, 0.96))
	CityProps.box(v, c, xf, Vector3(0, 4.6, 0.06), Vector3(3.3, 2.1, 0.2), Color(0.10, 0.28, 0.72))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var lab := Label3D.new()
	lab.text = "P"
	lab.font_size = 220
	lab.pixel_size = 0.011
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 0
	lab.position = xf * Vector3(0, 4.6, 0.25)
	lab.rotation = Vector3(0, yaw, 0)
	root.add_child(lab)
	return root

## Cartel «SALIDA» de las puntas de los brazos del túnel y de la sala del estacionamiento
func _link_label(l: Dictionary) -> Node3D:
	var root := Node3D.new()
	var lp: Vector2 = l["label_pos"]
	var lab := Label3D.new()
	lab.text = Tr.t(str(l["label"]))
	lab.font_size = 96
	lab.pixel_size = 0.014
	lab.modulate = Color(0.75, 1.0, 0.8)
	lab.outline_size = 16
	lab.outline_modulate = Color(0.02, 0.2, 0.08)
	var yw: float = l["label_yaw"]
	lab.position = Vector3(lp.x + sin(yw) * 0.4, 3.6, lp.y + cos(yw) * 0.4)
	lab.rotation = Vector3(0, yw, 0)
	root.add_child(lab)
	if str(l["id"]).begins_with("salida_"):
		var ring := _circle_mesh(3.0, 3.5, Color(0.20, 0.85, 0.35), Color(0.97, 0.97, 0.97))
		ring.position = Vector3(float((l["pos"] as Vector2).x), 0.1, float((l["pos"] as Vector2).y))
		root.add_child(ring)
	return root

## El frente de un local: el cartel, el portón de garage (que se abre), la boca oscura de adentro y el círculo verde donde hay que frenar para entrar
func _shop_front(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "shop_" + str(b["poi"])
	root.add_child(_sign(b))
	var p: Dictionary = {}
	for q in city.pois:
		if str(q["id"]) == str(b["poi"]):
			p = q
	if p.is_empty() or str(p["shop"]) == "":
		return root
	if b.has("show"):
		root.add_child(_showroom(b, p))
	var col: Color = p["color"]
	var door_p: Vector2 = p["door"]
	var dir: Vector2 = p["dir"]
	var y := city.height(door_p.x, door_p.y) + 0.15
	var yaw := atan2(-dir.x, -dir.y) # +z local mira hacia la calle
	# la boca (lo que se ve cuando el portón sube) y el dintel
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(door_p.x - dir.x * 0.06, y, door_p.y - dir.y * 0.06))
	CityProps.box(v, c, xf, Vector3(0, 2.1, 0), Vector3(7.2, 4.2, 0.1), Color(0.09, 0.08, 0.10))
	CityProps.box(v, c, xf, Vector3(0, 4.55, 0.05), Vector3(8.0, 0.5, 0.3), col)
	CityProps.box(v, c, xf, Vector3(-3.75, 2.1, 0.05), Vector3(0.4, 4.2, 0.3), col.darkened(0.15))
	CityProps.box(v, c, xf, Vector3(3.75, 2.1, 0.05), Vector3(0.4, 4.2, 0.3), col.darkened(0.15))
	if str(p["kind"]) == "parking":
		# el cartel grande de la «P» sobre el portón: un tablero azul de papel con la letra blanca
		CityProps.box(v, c, xf, Vector3(0, 7.4, 0.2), Vector3(4.6, 4.6, 0.3), Color(0.10, 0.28, 0.72))
		CityProps.box(v, c, xf, Vector3(0, 7.4, 0.12), Vector3(5.0, 5.0, 0.2), Color(0.97, 0.97, 0.96))
		var pl := Label3D.new()
		pl.text = "P"
		pl.font_size = 360
		pl.pixel_size = 0.011
		pl.modulate = Color(1, 1, 1)
		pl.outline_size = 0
		pl.position = xf * Vector3(0, 7.4, 0.42)
		pl.rotation = Vector3(0, yaw, 0)
		root.add_child(pl)
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mouth := MeshInstance3D.new()
	mouth.mesh = m
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mouth)
	# el portón: tablillas de papel que suben (el pivote está arriba, el escalado en y lo recoge)
	var door := Node3D.new()
	door.name = "door"
	door.position = Vector3(door_p.x - dir.x * 0.16, y + 4.2, door_p.y - dir.y * 0.16)
	door.rotation = Vector3(0, yaw, 0)
	var dv := PackedVector3Array()
	var dc := PackedColorArray()
	var slat := 0.6
	for k in 7:
		CityProps.box(dv, dc, Transform3D.IDENTITY, Vector3(0, -(float(k) + 0.5) * slat, 0), Vector3(6.9, slat - 0.04, 0.12), col.lightened(0.18) if k % 2 == 0 else col)
	var dm := ArrayMesh.new()
	PaperKit.add_surface(dm, dv, dc, PaperKit.material(null, 0.0, 0.2, 0.3))
	var dmi := MeshInstance3D.new()
	dmi.mesh = dm
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	door.add_child(dmi)
	root.add_child(door)
	# círculo verde sobre el asfalto
	var front: Vector2 = p["front"]
	var circle := Node3D.new()
	circle.name = "circle"
	circle.position = Vector3(front.x, city.height(front.x, front.y) + 0.1, front.y)
	var cv := PackedVector3Array()
	var cc := PackedColorArray()
	var green := Color(0.20, 0.85, 0.35)
	var n := 28
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var r0 := 3.0
		var r1 := 3.5
		var c0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var c1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		cv.append_array(PackedVector3Array([Vector3.ZERO, c0, c1]))
		for k in 3:
			cc.append(green)
		var o0 := Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var o1 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		cv.append_array(PackedVector3Array([c0, o0, o1, c0, o1, c1]))
		for k in 6:
			cc.append(Color(0.97, 0.97, 0.97))
	# la rampa de entrada: una franja de asfalto sobre la vereda, del círculo al portón, con bordes amarillos
	var ap_v := PackedVector3Array()
	var ap_c := PackedColorArray()
	var lat := Vector2(-dir.y, dir.x)
	var a0 := front + dir * 3.4
	var a1 := door_p + dir * 0.4
	var hwb := 3.2
	var ya0 := city.height(a0.x, a0.y) + 0.2
	var ya1 := city.height(a1.x, a1.y) + 0.2
	var q00 := Vector3(a0.x - lat.x * hwb, ya0, a0.y - lat.y * hwb)
	var q01 := Vector3(a0.x + lat.x * hwb, ya0, a0.y + lat.y * hwb)
	var q10 := Vector3(a1.x - lat.x * hwb, ya1, a1.y - lat.y * hwb)
	var q11 := Vector3(a1.x + lat.x * hwb, ya1, a1.y + lat.y * hwb)
	ap_v.append_array(PackedVector3Array([q00, q01, q11, q00, q11, q10]))
	for k in 6:
		ap_c.append(Color(0.30, 0.34, 0.42))
	var sidec := Color(0.98, 0.85, 0.15)
	for side_s in [-1.0, 1.0]:
		var o0 := Vector3(a0.x + lat.x * (hwb - 0.35) * side_s, ya0 + 0.01, a0.y + lat.y * (hwb - 0.35) * side_s)
		var o1 := Vector3(a1.x + lat.x * (hwb - 0.35) * side_s, ya1 + 0.01, a1.y + lat.y * (hwb - 0.35) * side_s)
		var i0 := Vector3(a0.x + lat.x * (hwb - 0.1) * side_s, ya0 + 0.01, a0.y + lat.y * (hwb - 0.1) * side_s)
		var i1 := Vector3(a1.x + lat.x * (hwb - 0.1) * side_s, ya1 + 0.01, a1.y + lat.y * (hwb - 0.1) * side_s)
		ap_v.append_array(PackedVector3Array([o0, i0, i1, o0, i1, o1]))
		for k in 6:
			ap_c.append(sidec)
	var apm := ArrayMesh.new()
	PaperKit.add_surface(apm, ap_v, ap_c, PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.07))
	var api := MeshInstance3D.new()
	api.mesh = apm
	api.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(api)
	var cm := ArrayMesh.new()
	PaperKit.add_surface(cm, cv, cc, PaperKit.material(null, 0.0, 0.2, 0.0))
	var cmi := MeshInstance3D.new()
	cmi.mesh = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	circle.add_child(cmi)
	root.add_child(circle)
	return root

## Vidriera de un concesionario (pedido del dueño: «autos reales del catálogo en vidrieras»): a cada lado del portón un salón de 9 m de fondo con piso
## claro, luces en el techo, vidrio y 3 autos de verdad (los modelos livianos de la carrera, con la pintura de fábrica) que cambian según el local
## (data/shops.gd → display). El edificio sigue siendo una caja sólida para los choques: la vidriera no se atraviesa.
const SHOW_H := 5.4 # alto de la planta baja vidriada
const SHOW_D := 9.0 # fondo del salón
const Shops := preload("res://game/data/shops.gd")
const CarBuildS := preload("res://game/data/car_build.gd")
const ProfileS := preload("res://game/data/profile.gd")
const CarVisualS := preload("res://game/car/car_visual.gd")
const VehicleParamsS := preload("res://game/physics/vehicle_params.gd")
static var _veh_cache: Dictionary = {}
static var _glass_mat: StandardMaterial3D
static var _lamp_mat: StandardMaterial3D

func _showroom(b: Dictionary, p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "showroom"
	var door_p: Vector2 = p["door"]
	var dir: Vector2 = p["dir"]
	var yaw := atan2(-dir.x, -dir.y) # +z local mira hacia la calle
	var by: float = b["y"]
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(door_p.x, by, door_p.y))
	var hw: float = float(b["w"]) * 0.5 - 0.25
	var gap := 4.0 # medio ancho del pasillo del portón
	var wall: Color = b["wall"]
	wall.a = 1.0
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var lv := PackedVector3Array()
	var lc := PackedColorArray()
	var floor_c := Color(0.36, 0.37, 0.40) # piso pulido oscuro: los autos se despegan
	var in_c := Color(0.74, 0.73, 0.70)
	var frame_c := Color(0.13, 0.13, 0.15)
	for sd in [-1.0, 1.0]:
		var x0: float = gap * sd
		var x1: float = hw * sd
		var cx: float = (x0 + x1) * 0.5
		var w := absf(x1 - x0)
		CityProps.box(v, c, xf, Vector3(cx, 0.1, -SHOW_D * 0.5), Vector3(w, 0.2, SHOW_D), floor_c) # piso
		CityProps.box(v, c, xf, Vector3(cx, SHOW_H - 0.1, -SHOW_D * 0.5), Vector3(w, 0.2, SHOW_D), in_c) # techo
		CityProps.box(v, c, xf, Vector3(cx, SHOW_H * 0.5, -SHOW_D), Vector3(w, SHOW_H, 0.2), wall.lerp(Color(0.95, 0.95, 0.95), 0.55)) # fondo
		CityProps.box(v, c, xf, Vector3(x0, SHOW_H * 0.5, -SHOW_D * 0.5), Vector3(0.2, SHOW_H, SHOW_D), in_c) # costado del pasillo
		CityProps.box(v, c, xf, Vector3(x1, SHOW_H * 0.5, -SHOW_D * 0.5), Vector3(0.2, SHOW_H, SHOW_D), in_c) # costado de afuera
		CityProps.box(v, c, xf, Vector3(cx, SHOW_H * 0.72, -SHOW_D + 0.12), Vector3(w * 0.8, 0.5, 0.05), wall) # franja del color del local
		CityProps.box(v, c, xf, Vector3(cx, 0.25, 0.0), Vector3(w, 0.3, 0.16), frame_c) # zócalo
		CityProps.box(v, c, xf, Vector3(cx, SHOW_H - 0.12, 0.0), Vector3(w, 0.24, 0.16), frame_c) # dintel
		var nm := int(ceil(w / 3.2))
		for k in nm + 1:
			CityProps.box(v, c, xf, Vector3(x0 + (x1 - x0) * float(k) / float(nm), SHOW_H * 0.5, 0.0), Vector3(0.12, SHOW_H, 0.16), frame_c) # parantes
		for k in 3:
			CityProps.box(lv, lc, xf, Vector3(cx, SHOW_H - 0.22, -1.6 - float(k) * 2.9), Vector3(w * 0.8, 0.05, 0.35), Color(1, 1, 1)) # luces
	CityProps.box(v, c, xf, Vector3(0, (4.8 + SHOW_H) * 0.5, 0.0), Vector3(gap * 2.0, SHOW_H - 4.8, 0.3), wall) # pared sobre el portón
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if _lamp_mat == null:
		_lamp_mat = StandardMaterial3D.new()
		_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lamp_mat.vertex_color_use_as_albedo = true
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.albedo_color = Color(0.62, 0.76, 0.86, 0.18)
		_glass_mat.metallic = 0.5
		_glass_mat.roughness = 0.04
		_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lm := ArrayMesh.new()
	PaperKit.add_surface(lm, lv, lc, _lamp_mat)
	var lmi := MeshInstance3D.new()
	lmi.mesh = lm
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lmi)
	# el vidrio: un plano por salón, delante de los parantes
	for sd in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(hw - gap, SHOW_H - 0.4)
		g.mesh = qm
		g.material_override = _glass_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.transform = xf * Transform3D(Basis.IDENTITY, Vector3((gap + hw) * 0.5 * sd, SHOW_H * 0.5 + 0.1, 0.1))
		root.add_child(g)
	# los autos: dos en el salón izquierdo y uno sobre una tarima en el derecho
	var disp: Array = Shops.get_shop(str(b["show"])).get("display", [])
	var spots := [[Vector3(-hw + 3.4, 0.2, -4.6), 0.62], [Vector3(-gap - 3.1, 0.2, -4.4), 0.62], [Vector3((gap + hw) * 0.5, 0.42, -4.5), -0.7]]
	for i in mini(disp.size(), spots.size()):
		var vid := str(disp[i])
		var sp: Array = spots[i]
		var ii := i
		if _deferring:
			_prefetch_display(vid)
		_later(root, func() -> void: _showroom_car(root, vid, ii, sp, xf)) # (cada auto es un modelo entero: se arma en su propio cuadro)
	return root

## Las rutas de los modelos que usa el auto vid de una vidriera (el liviano de la carrera)
func _display_models(vid: String) -> Array:
	if _veh_cache.is_empty():
		_veh_cache = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var vt := str((_veh_cache.get(vid, {}) as Dictionary).get("visualType", ""))
	if CarVisualS.has_own_model(vt):
		return ["res://game/models/cars/%s_lo.glb" % vt]
	return ["res://game/models/volt_body_lo.glb", "res://game/models/volt_wheel_lo.glb"]

## Cargar el modelo de un auto es lo más caro de armar una vidriera (~35 ms en la PC, el resto ~1,5 ms): se pide en un hilo apenas aparece la cuadra y el auto se arma cuando ya está listo
func _prefetch_display(vid: String) -> void:
	for pth in _display_models(vid):
		if ResourceLoader.exists(pth):
			ResourceLoader.load_threaded_request(pth)

func _display_loading(vid: String) -> bool:
	for pth in _display_models(vid):
		if ResourceLoader.load_threaded_get_status(pth) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return true
	return false

## Un auto de la vidriera (el tercero va sobre una tarima)
func _showroom_car(root: Node3D, vid: String, i: int, sp: Array, xf: Transform3D, tries := 0) -> void:
	if _deferring and tries < 900 and _display_loading(vid):
		_extras_q.append([root, func() -> void: _showroom_car(root, vid, i, sp, xf, tries + 1)]) # (el modelo todavía se está leyendo: se prueba de nuevo en el cuadro que sigue)
		return
	var car := _display_car(vid)
	if car == null:
		return
	var at: Vector3 = sp[0]
	if i == 2:
		var tb := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 3.0
		cy.bottom_radius = 3.1
		cy.height = 0.22
		cy.radial_segments = 24
		tb.mesh = cy
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.16, 0.16, 0.18)
		tm.metallic = 0.6
		tm.roughness = 0.25
		tb.material_override = tm
		tb.transform = xf * Transform3D(Basis.IDENTITY, Vector3(at.x, 0.31, at.z))
		root.add_child(tb)
	var vp = car.get_meta("vp")
	car.transform = xf * Transform3D(Basis(Vector3.UP, float(sp[1])), at + Vector3(0, float(vp.comHeight) - float(vp.rideOffset), 0))
	root.add_child(car)

## Un auto del catálogo con la pintura de fábrica, quieto (modelo liviano, el de los rivales)
func _display_car(vid: String) -> Node3D:
	if _veh_cache.is_empty():
		_veh_cache = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	if not _veh_cache.has(vid) or not (CarBuildS.catalog()["cars"] as Dictionary).has(vid):
		return null
	var st: Dictionary = ProfileS.new_car_state(vid)
	var pp: Dictionary = st["paint"]
	var vp = VehicleParamsS.from_dict(CarBuildS.build_params(_veh_cache[vid], st))
	var vis := CarVisualS.new()
	vis.mods = st.get("mods", {})
	vis.setup(vp, true, Color(str(pp.get("body", "#1a4fe0"))), Color(str(pp.get("rim", "#2a2d33"))), str(pp.get("finish", "gloss")))
	if int(pp.get("livery", 0)) > 0:
		vis.race_number = str(pp.get("number", "77"))
		vis.set_livery(int(pp["livery"]), Color(str(pp["body"])), Color(str(pp.get("accent", "#ff6a08"))), str(pp.get("finish", "gloss")), Color(str(pp.get("text", "#f2f2ee"))))
	if pp.has("tire"):
		vis.set_tire_color(Color(str(pp["tire"])))
	vis.set_parts(pp)
	vis.set_meta("vp", vp)
	for n in vis.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).visibility_range_end = 220.0 # de lejos no se dibujan (detrás del vidrio no se distinguen)
	return vis

## Cartel de un edificio especial (concesionario, taller)
func _sign(b: Dictionary) -> Node3D:
	var lab := Label3D.new()
	var nm := str(b["poi"])
	var title := nm
	for p in city.pois:
		if str(p["id"]) == nm:
			title = str(p["name"])
	lab.text = Tr.t(title)
	lab.font_size = 96
	lab.pixel_size = 0.012
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 22
	lab.outline_modulate = Color(0.1, 0.1, 0.12)
	lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var yaw: float = b["yaw"]
	var tg := Vector2(sin(yaw), cos(yaw))
	var nmv := Vector2(cos(yaw), -sin(yaw))
	var face: float = float(b["side"])
	var pos := Vector2(b["x"], b["z"]) + nmv * (face * (float(b["d"]) * 0.5 + 0.2))
	lab.position = Vector3(pos.x, float(b["y"]) + 6.2, pos.y)
	lab.rotation = Vector3(0, atan2(nmv.x * face, nmv.y * face), 0)
	return lab
