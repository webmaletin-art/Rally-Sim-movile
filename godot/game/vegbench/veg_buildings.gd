extends RefCounted
## Edificios de la prueba: una «calle de ciudad» a lo largo de toda la pista con tres sistemas de edificios del juego para comparar:
##  1 · DRIFT / AVENTURA: fachadas modulares de geometría con atlas de texturas (adventure/adv_props.gd, el de la plaza de drift y los pueblos de la aventura)
##  2 · DREAM CITY: cajas de pocas caras con las ventanas dibujadas por un shader (fx/city_facade.gdshader, el del mundo abierto)
##  3 · PAPEL: cajas lisas de color con el material de papel (el estilo de los objetos de los mapas fantasía)
## El reparto (lugares, medidas, colores) es el mismo para los tres y siempre igual: sólo cambia cómo se dibuja cada edificio.

const AdvProps := preload("res://game/adventure/adv_props.gd")
const MB := preload("res://game/adventure/adv_mesh.gd")
const CityWorld := preload("res://game/city/city_world.gd")
const CityProps := preload("res://game/city/city_props.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const FACADE := preload("res://game/fx/city_facade.gdshader")

const SYSTEMS := ["SIN EDIFICIOS", "DRIFT / AVENTURA", "DREAM CITY", "PAPEL"]
const MAX_B := 1000
const CHUNK := 150.0
const PALETTE := [Color(0.92, 0.86, 0.74), Color(0.80, 0.82, 0.86), Color(0.86, 0.72, 0.6), Color(0.74, 0.8, 0.74), Color(0.9, 0.88, 0.84), Color(0.7, 0.68, 0.72), Color(0.88, 0.8, 0.62)]

var spots: Array = [] # {x, y, z, yaw, w, d, floors, style, wall(Color), seed}
var _facade_mat: ShaderMaterial

func setup(track) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var view = track.make_view(false)
	view.trust = true
	var near_min: float = track.half_width + track.shoulder + 3.0
	var cand: Array = []
	var per_side := 127
	for row in 4:
		for side in [-1.0, 1.0]:
			for i in per_side:
				cand.append([row, side, i])
	# mezcla fija: cualquier cantidad queda repartida por toda la pista
	for k in range(cand.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var t: Array = cand[k]
		cand[k] = cand[j]
		cand[j] = t
	for c in cand:
		if spots.size() >= MAX_B:
			break
		var si := int(float(c[2]) * float(track.n) / float(per_side)) % int(track.n)
		var p: Vector3 = track.samples[si]
		var l: Vector3 = track.laterals[si]
		var w := rng.randf_range(12.0, 22.0)
		var d := rng.randf_range(10.0, 16.0)
		var off := (near_min + 10.0 + float(c[0]) * 34.0 + rng.randf_range(-3.0, 3.0)) * float(c[1])
		var x := p.x + l.x * off
		var z := p.z + l.z * off
		view.hint = si
		var y: float = view.ground_smooth(x, z)
		# no encima de otro tramo de la pista (curvas cerradas)
		if float(view.r_dist) < near_min + 6.0:
			continue
		var to_road := Vector2(-l.x * float(c[1]), -l.z * float(c[1])) # la fachada mira al camino
		spots.append({"x": x, "y": y, "z": z, "yaw": atan2(to_road.x, to_road.y), "w": w, "d": d, "floors": rng.randi_range(2, 7), "style": [1, 2, 2, 3, 3, 0][rng.randi() % 6],
			"wall": PALETTE[rng.randi() % PALETTE.size()], "seed": rng.randf()})

## Los primeros n edificios con el sistema elegido: devuelve un nodo con una malla por bloque de 150 m
func build(system: int, n: int) -> Node3D:
	var root := Node3D.new()
	if system <= 0:
		return root
	var groups: Dictionary = {}
	for i in mini(n, spots.size()):
		var s: Dictionary = spots[i]
		var key := Vector2i(floori(float(s["x"]) / CHUNK), floori(float(s["z"]) / CHUNK))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(s)
	for key in groups:
		var mesh: Mesh
		match system:
			1:
				mesh = _chunk_atlas(groups[key])
			2:
				mesh = _chunk_dream(groups[key])
			_:
				mesh = _chunk_paper(groups[key])
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 700.0
		root.add_child(mi)
	return root

# 1 · DRIFT / AVENTURA ───────────────────────────────────────────────────────
func _chunk_atlas(list: Array) -> Mesh:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	for s in list:
		rng.seed = int(float(s["seed"]) * 100000.0)
		var xf := Transform3D(Basis(Vector3.UP, float(s["yaw"])), Vector3(s["x"], s["y"], s["z"]))
		AdvProps.building(b, xf, float(s["w"]) - 0.5, float(s["d"]) - 0.5, int(s["floors"]), int(s["style"]), s["wall"], 0, rng)
		# zócalo bajo el piso (así no queda hueco en las lomas)
		b.box(Transform3D(xf.basis, xf * Vector3(0, -1.6, -float(s["d"]) * 0.5)), Vector3(float(s["w"]) - 0.5, 3.2, float(s["d"]) - 0.5), Color(0.5, 0.48, 0.46), Color(0, 0, 0, 0), Rect2(0.76, 0.26, 0.2, 0.2))
	return b.commit(AdvProps.material("atlas"))

# 2 · DREAM CITY ─────────────────────────────────────────────────────────────
func _chunk_dream(list: Array) -> Mesh:
	if _facade_mat == null:
		_facade_mat = ShaderMaterial.new()
		_facade_mat.shader = FACADE
		_facade_mat.set_shader_parameter("grain", PaperKit.grain())
	var sp = CityWorld.Soup.new()
	for s in list:
		var cen := Vector2(float(s["x"]), float(s["z"]))
		var yaw := float(s["yaw"])
		var w := float(s["w"])
		var d := float(s["d"])
		var h := float(int(s["floors"])) * 3.2
		var by := float(s["y"])
		var tg := Vector2(sin(yaw), cos(yaw))
		var nm := Vector2(cos(yaw), -sin(yaw))
		var c: Vector2 = cen - tg * (d * 0.5) # el centro del edificio queda detrás del frente
		var wall: Color = s["wall"]
		wall.a = float(s["seed"])
		var base := by - 3.2
		var top := by + h
		var corners := [c + nm * (-w * 0.5) + tg * (-d * 0.5), c + nm * (w * 0.5) + tg * (-d * 0.5), c + nm * (w * 0.5) + tg * (d * 0.5), c + nm * (-w * 0.5) + tg * (d * 0.5)]
		var lens := [w, d, w, d]
		for i in 4:
			var p: Vector2 = corners[i]
			var q: Vector2 = corners[(i + 1) % 4]
			var wd: float = lens[i]
			var a := Vector3(p.x, base, p.y)
			var bb := Vector3(q.x, base, q.y)
			var cc := Vector3(q.x, top, q.y)
			var dd := Vector3(p.x, top, p.y)
			var outv := ((p + q) * 0.5 - c).normalized()
			sp.quad_out(a, dd, cc, bb, wall, outv, Vector2(0, base - by), Vector2(0, h), Vector2(wd, h), Vector2(wd, base - by), Vector2(wd, h))
		var roof := Color(0.52, 0.5, 0.48, 0.0)
		sp.quad_up(Vector3(corners[0].x, top, corners[0].y), Vector3(corners[1].x, top, corners[1].y), Vector3(corners[2].x, top, corners[2].y), Vector3(corners[3].x, top, corners[3].y), roof)
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = sp.v
	arr[Mesh.ARRAY_NORMAL] = sp.n
	arr[Mesh.ARRAY_COLOR] = sp.c
	arr[Mesh.ARRAY_TEX_UV] = sp.uv
	arr[Mesh.ARRAY_TEX_UV2] = sp.uv2
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _facade_mat)
	return m

# 3 · PAPEL (cajas lisas) ───────────────────────────────────────────────────
func _chunk_paper(list: Array) -> Mesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for s in list:
		var yaw := float(s["yaw"])
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(s["x"], s["y"], s["z"]))
		var w := float(s["w"])
		var d := float(s["d"])
		var h := float(int(s["floors"])) * 3.2
		var wall: Color = s["wall"]
		CityProps.box(v, c, xf, Vector3(0, (h - 3.2) * 0.5, -d * 0.5), Vector3(w, h + 3.2, d), wall)
		CityProps.box(v, c, xf, Vector3(0, h + 0.2, -d * 0.5), Vector3(w + 0.6, 0.5, d + 0.6), wall.darkened(0.35))
		# puerta y una franja de ventanas por piso (cajas finas: sin textura)
		CityProps.box(v, c, xf, Vector3(0, 1.2, 0.04), Vector3(1.6, 2.4, 0.1), wall.darkened(0.55))
		for f in int(s["floors"]) - 1:
			CityProps.box(v, c, xf, Vector3(0, 4.4 + float(f) * 3.2, 0.04), Vector3(w * 0.8, 1.2, 0.1), Color(0.25, 0.35, 0.45))
	return PaperKit.mesh_from_triangles(v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
