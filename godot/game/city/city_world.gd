extends Node3D
## El mundo de Puerto Aurelia, todo en papel y cargado por cuadras: solo existen las cuadras (de 160 m) que están cerca de la cámara; cuando te alejás se borran y cuando te
## acercás se arman (como mucho una por cuadro, para que no haya tirones). Cada cuadra es un puñado de mallas: el terreno, las calles con sus veredas y rayas, y los edificios
## (cajas de pocas caras; las ventanas las dibuja el shader fx/city_facade.gdshader). Nada lejano se dibuja: hay niebla y un horizonte pintado.

const PaperKit := preload("res://game/fx/paper_kit.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const CityProps := preload("res://game/city/city_props.gd")
const FACADE := preload("res://game/fx/city_facade.gdshader")
const TEX := "res://game/models/paper/tex/"

var track # CityTrack
var city: CityLayout
var chunks: Dictionary = {} # Vector2i -> Node3D
var radius := 3 # cuadras a la redonda que se mantienen armadas
var view_k := 1.0
var built_total := 0
var _facade_mat: ShaderMaterial
var _queue: Array = []
var _frame_budget_ms := 6.0

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
		var nr := (b - a).cross(cc - a).normalized()
		v.append_array(PackedVector3Array([a, b, cc]))
		n.append_array(PackedVector3Array([nr, nr, nr]))
		for i in 3:
			c.append(col)
		uv.append_array(PackedVector2Array([ua, ub, uc]))
		uv2.append_array(PackedVector2Array([u2, u2, u2]))

func setup(p_track) -> void:
	track = p_track
	city = track.city
	_facade_mat = ShaderMaterial.new()
	_facade_mat.shader = FACADE
	_ground_plane()

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
	mi.position = Vector3(0, -3.0, 0)
	mi.extra_cull_margin = 100000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var sea := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(30000, 12000)
	sea.mesh = pm2
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.20, 0.52, 0.70)
	sm.roughness = 0.6
	sea.material_override = sm
	sea.position = Vector3(0, 0.0, CityLayout.SEA_Z + 6000.0 + 40.0)
	sea.extra_cull_margin = 100000.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)

# ───────────────────────── carga por cuadras ─────────────────────────
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	update_around(cam.global_position, 1)
	_redraw_broken()

## Los objetos que acaban de romperse: se arma de nuevo la malla de objetos de su cuadra (lo roto queda tirado)
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

## Malla de los objetos de la calle de una cuadra (una sola llamada de dibujo; se ve a ~150 m) y sus círculos de choque
func _props_instance(key: Vector2i) -> MeshInstance3D:
	if not city.props_in.has(key):
		return null
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for id in (city.props_in[key] as PackedInt32Array):
		var fallen: Vector2 = track.broken.get(id, Vector2.ZERO)
		CityProps.emit(int(city.prop_type[id]), city.prop_x[id], city.prop_y[id], city.prop_z[id], city.prop_yaw[id], city.prop_seed[id], fallen, v, c)
	if v.is_empty():
		return null
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.name = "props"
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 170.0 * maxf(view_k, 0.6)
	return mi

func _register_props(key: Vector2i) -> void:
	if not city.props_in.has(key):
		return
	for id in (city.props_in[key] as PackedInt32Array):
		if not track.broken.has(id):
			track.add_prop(id, city.prop_x[id], city.prop_z[id], CityProps.RADIUS[int(city.prop_type[id])])

func _unregister_props(key: Vector2i) -> void:
	if not city.props_in.has(key):
		return
	for id in (city.props_in[key] as PackedInt32Array):
		if not track.broken.has(id):
			track.remove_prop(id, city.prop_x[id], city.prop_z[id])

## Arma las cuadras de alrededor de p (hasta max_new por llamada) y borra las lejanas
func update_around(p: Vector3, max_new: int, budget_ms := -1.0) -> void:
	var budget := _frame_budget_ms if budget_ms < 0.0 else budget_ms
	var ck := city.chunk_of(p.x, p.z)
	var rad := maxi(2, int(round(float(radius) * view_k)))
	var want: Array = []
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			if not chunks.has(k):
				want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - ck).length_squared() < (b - ck).length_squared())
	var t0 := Time.get_ticks_usec()
	var made := 0
	for k in want:
		if made >= max_new:
			break
		chunks[k] = _build_chunk(k)
		add_child(chunks[k])
		built_total += 1
		made += 1
		if float(Time.get_ticks_usec() - t0) / 1000.0 > budget:
			break
	for k in chunks.keys():
		var kk: Vector2i = k
		if maxi(absi(kk.x - ck.x), absi(kk.y - ck.y)) > rad + 1:
			_unregister_props(kk)
			(chunks[kk] as Node3D).queue_free()
			chunks.erase(kk)

## Arma ya todas las de alrededor (la carga de la pista, antes de empezar)
func warm(p: Vector3) -> void:
	update_around(p, 999, 1e9)

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
func _build_chunk(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	root.name = "c%d_%d" % [key.x, key.y]
	var x0 := float(key.x) * CityLayout.CELL
	var z0 := float(key.y) * CityLayout.CELL
	var terr := Soup.new()
	_terrain(terr, x0, z0)
	var rd := Soup.new()
	var mk := Soup.new()
	_roads(rd, mk, key)
	var bl := Soup.new()
	var specials := _buildings(bl, key)
	var m := ArrayMesh.new()
	_surface(m, terr, PaperKit.material(null, 0.0, 0.2, 0.25))
	_surface(m, rd, PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.07))
	_surface(m, mk, PaperKit.material(null, 0.0, 0.2, 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if bl.v.size() > 0:
		var bm := ArrayMesh.new()
		_surface(bm, bl, _facade_mat)
		var bi := MeshInstance3D.new()
		bi.mesh = bm
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bi)
	for sp in specials:
		root.add_child(sp)
	var pi := _props_instance(key)
	if pi != null:
		root.add_child(pi)
	_register_props(key)
	return root

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

func _ground_color(x: float, z: float, y: float) -> Color:
	var zone := city.zone_of(x, z)
	var jit := 0.012 * sin(x * 0.011) * cos(z * 0.009)
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

func _terrain(s: Soup, x0: float, z0: float) -> void:
	var n := int(CityLayout.CELL / TC)
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			var wx := x0 + float(ix) * TC
			var wz := z0 + float(iz) * TC
			var h := city.height(wx, wz)
			# donde hay una calle el terreno se hunde un poco para que el asfalto quede por encima aunque la ladera suba al costado
			var pr := city.probe(wx, wz)
			if pr[6] >= 0.0 and pr[0] > -7.0:
				h = minf(h, float(pr[4]) - 0.5)
			hs[iz * (n + 1) + ix] = h
	for iz in n:
		for ix in n:
			var wx := x0 + float(ix) * TC
			var wz := z0 + float(iz) * TC
			var a := Vector3(wx, hs[iz * (n + 1) + ix], wz)
			var b := Vector3(wx + TC, hs[iz * (n + 1) + ix + 1], wz)
			var c := Vector3(wx + TC, hs[(iz + 1) * (n + 1) + ix + 1], wz + TC)
			var d := Vector3(wx, hs[(iz + 1) * (n + 1) + ix], wz + TC)
			var col := _ground_color(wx + TC * 0.5, wz + TC * 0.5, a.y)
			s.quad_up(a, d, c, b, col)

# ───────────────────────── calles ─────────────────────────
const C_ASPH := Color(0.50, 0.51, 0.56)
const C_SIDE := Color(0.84, 0.80, 0.72)
const C_CURB := Color(0.70, 0.67, 0.62)
const C_YEL := Color(1.0, 0.82, 0.30)
const C_WHT := Color(0.97, 0.96, 0.93)

func _roads(rd: Soup, mk: Soup, key: Vector2i) -> void:
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
				_road_segment(rd, mk, si, ni)

## Normal (hacia la derecha del avance) en el punto si, unida con la del tramo anterior para que las curvas no queden con huecos. Devuelve (nx, nz, escala del ancho)
func _miter(si: int) -> Vector3:
	var ni: int = city.s_next[si]
	var pi: int = city.s_prev[si]
	var d1 := Vector2.ZERO
	var d0 := Vector2.ZERO
	if ni >= 0:
		d1 = Vector2(city.s_x[ni] - city.s_x[si], city.s_z[ni] - city.s_z[si]).normalized()
	if pi >= 0:
		d0 = Vector2(city.s_x[si] - city.s_x[pi], city.s_z[si] - city.s_z[pi]).normalized()
	if d1 == Vector2.ZERO:
		d1 = d0
	if d0 == Vector2.ZERO:
		d0 = d1
	var n1 := Vector2(-d1.y, d1.x)
	var n0 := Vector2(-d0.y, d0.x)
	var m := n0 + n1
	if m.length() < 0.05:
		return Vector3(n1.x, n1.y, 1.0)
	m = m.normalized()
	var k := clampf(1.0 / maxf(m.dot(n1), 0.55), 1.0, 1.8)
	return Vector3(m.x, m.y, k)

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

func _road_segment(rd: Soup, mk: Soup, si: int, ni: int) -> void:
	var road: Dictionary = city.roads[city.s_road[si]]
	var hw: float = road["hw"]
	var sw: float = road["sw"]
	var kind: String = road["kind"]
	var a := Vector3(city.s_x[si], city.s_y[si], city.s_z[si])
	var b := Vector3(city.s_x[ni], city.s_y[ni], city.s_z[ni])
	if Vector2(b.x - a.x, b.z - a.z).length() < 0.05:
		return
	var ma := _miter(si)
	var mb := _miter(ni)
	var na := Vector3(ma.x, 0.0, ma.y)
	var nb := Vector3(mb.x, 0.0, mb.y)
	var ka := ma.z
	var kb := mb.z
	var up := Vector3(0, 0.04, 0)
	rd.quad_up(a - na * (hw * ka) + up, b - nb * (hw * kb) + up, b + nb * (hw * kb) + up, a + na * (hw * ka) + up, C_ASPH)
	# veredas con cordón (más altas); no se dibujan donde cruza otra calle
	var curb := 0.16
	var cu := Vector3(0, curb, 0)
	var side_col := C_SIDE
	if kind == "rural" or kind == "shortcut":
		side_col = Color(0.66, 0.62, 0.50)
	elif kind == "alley":
		side_col = Color(0.72, 0.46, 0.42) # veredas de ladrillo rojo
	var mid := (a + b) * 0.5
	for sg in [-1.0, 1.0]:
		var s: float = sg
		var nmid := (na + nb).normalized()
		var probe_pt := mid + nmid * (s * (hw + sw * 0.5))
		if _in_other_road(probe_pt.x, probe_pt.z, city.s_road[si]):
			continue
		var e0a := a + na * (s * hw * ka)
		var e0b := b + nb * (s * hw * kb)
		var e1a := a + na * (s * (hw + sw) * ka)
		var e1b := b + nb * (s * (hw + sw) * kb)
		rd.quad_up(e0a + cu, e0b + cu, e1b + cu, e1a + cu, side_col)
		# cara vertical del cordón
		var cface_out := Vector2(-nmid.x * s, -nmid.z * s) # el cordón mira hacia la calzada
		var qn := (e0b + up - (e0a + up)).cross(e0b + cu - (e0a + up))
		if qn.x * cface_out.x + qn.z * cface_out.y > 0.0:
			rd.quad(e0a + up, e0b + up, e0b + cu, e0a + cu, C_CURB)
		else:
			rd.quad(e0b + up, e0a + up, e0a + cu, e0b + cu, C_CURB)
	# rayas (no cerca de los cruces)
	var local_i := si - _first_sample(city.s_road[si])
	var nj: PackedByteArray = road["nj"]
	var junc := nj.size() > local_i and nj[local_i] != 0
	if not junc and kind != "plaza":
		var lw := 0.11
		var mu := Vector3(0, 0.055, 0)
		if kind in ["major", "ring", "coast", "hill", "rural"] and hw >= 4.0:
			if local_i % 3 != 2: # raya del medio cortada
				var cc := C_YEL if kind != "ring" else C_WHT
				mk.quad_up(a - na * lw + mu, b - nb * lw + mu, b + nb * lw + mu, a + na * lw + mu, cc)
			for sg in [-1.0, 1.0]:
				var s2: float = sg
				var o := (hw - 0.45) * s2
				mk.quad_up(a + na * (o - 0.07) + mu, b + nb * (o - 0.07) + mu, b + nb * (o + 0.07) + mu, a + na * (o + 0.07) + mu, C_WHT)
		elif local_i % 4 < 2:
			mk.quad_up(a - na * 0.08 + mu, b - nb * 0.08 + mu, b + nb * 0.08 + mu, a + na * 0.08 + mu, C_WHT)

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
	if not city.buildings.has(key):
		return specials
	for b in city.buildings[key]:
		_box_building(s, b)
		if b.has("poi"):
			specials.append(_sign(b))
	return specials

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

## Cartel de un edificio especial (concesionario, taller)
func _sign(b: Dictionary) -> Node3D:
	var lab := Label3D.new()
	var nm := str(b["poi"])
	var title := nm
	for p in city.pois:
		if str(p["id"]) == nm:
			title = str(p["name"])
	lab.text = title
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
