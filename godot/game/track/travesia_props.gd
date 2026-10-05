extends Node3D
## Lo que le da carácter a la Travesía X además del camino: el agua del vado (el lago que se cruza) y piedras al costado del pedregal y a lo largo de la ruta.
## Todo es visual y liviano (una malla de agua y un solo MultiMesh de piedras). El arrastre del agua lo aplica race.gd con water_drag().

var track # RouteTrack de la Travesía (con water y sections)

func setup(p_track) -> void:
	track = p_track
	for z in track.water:
		add_child(_water_strip(z as Dictionary))
	var rocks := _rocks()
	if rocks != null:
		add_child(rocks)

func _water_strip(z: Dictionary) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var half := float(z["half"])
	var wy := float(z["y"])
	var k := 0
	var i := int(z["i0"])
	var i1 := int(z["i1"])
	while i <= i1:
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		verts.append(Vector3(p.x - l.x * half, wy, p.z - l.z * half))
		verts.append(Vector3(p.x + l.x * half, wy, p.z + l.z * half))
		uvs.append(Vector2(0.0, float(i) * 0.05))
		uvs.append(Vector2(1.0, float(i) * 0.05))
		if k > 0:
			var a := (k - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
		k += 1
		i += 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.36, 0.40, 0.74)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.07
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Piedras a los lados: muchas en el pedregal, algunas sueltas en el resto
func _rocks() -> MultiMeshInstance3D:
	var view = track.make_view(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var rock_zone: Array = []
	for s in track.sections:
		if str(s["name"]) == "pedregal":
			rock_zone = [int(s["i0"]), int(s["i1"])]
	var xf: Array = []
	var edge: float = float(track.half_width + track.shoulder)
	var i := 0
	while i < track.n:
		var dense: bool = not rock_zone.is_empty() and i >= int(rock_zone[0]) and i <= int(rock_zone[1])
		var step := 3 if dense else 16
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var off := edge * (0.78 if dense else 0.95) + rng.randf_range(0.0, 5.0 if dense else 3.0)
		var x := p.x + l.x * side * off
		var z := p.z + l.z * side * off
		var sc := rng.randf_range(0.5, 1.7 if dense else 1.2)
		var y: float = view.ground_smooth(x, z)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc * rng.randf_range(0.8, 1.4), sc * rng.randf_range(0.55, 0.9), sc * rng.randf_range(0.8, 1.3)))
		xf.append(Transform3D(b, Vector3(x, y + sc * 0.18, z)))
		i += step
	if xf.is_empty():
		return null
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.2
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.43, 0.39)
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	sm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 420.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## Arrastre del agua: 0 = fuera del agua, hasta 1 = bien metido (el agua frena y salpica). Se pregunta con la posición del auto.
func water_depth(x: float, z: float) -> float:
	for w in track.water:
		var i0 := int(w["i0"])
		var i1 := int(w["i1"])
		var a: Vector3 = track.samples[i0]
		var b: Vector3 = track.samples[i1]
		var half := float(w["half"]) + 60.0
		var cx := (a.x + b.x) * 0.5
		var cz := (a.z + b.z) * 0.5
		var span := a.distance_to(b) * 0.5 + half
		if absf(x - cx) > span or absf(z - cz) > span:
			continue
		var best := 1e18
		var bi := i0
		var i := i0
		while i <= i1:
			var dx: float = track.samples[i].x - x
			var dz: float = track.samples[i].z - z
			var d := dx * dx + dz * dz
			if d < best:
				best = d
				bi = i
			i += 2
		var cyv: float = track.cy[bi]
		return clampf((float(w["y"]) - cyv) / 0.5, 0.0, 1.0) if best < 36.0 else 0.0
	return 0.0
