## Prueba de la optimización del mundo abierto: árboles de imagen (especies, variedad, nada sobre el asfalto, se rompen los de calle), bosque del horizonte, fachadas lejanas y malla de los autos civiles.
## Uso: godot --headless --path godot --script res://tests/ow_opt_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityWorld := preload("res://game/city/city_world.gd")
const CityProps := preload("res://game/city/city_props.gd")
const TreeSprites := preload("res://game/city/tree_sprites.gd")
const HorizonTrees := preload("res://game/city/horizon_trees.gd")
const CivilCarMesh := preload("res://game/world/civil_car_mesh.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _trees_node(world: Node3D, key: Vector2i) -> Node3D:
	var ch: Node3D = world.chunks.get(key)
	return ch.get_node_or_null("trees") if ch != null else null

var species_seen := {}
var total_trees := 0
var n_chunks_with := 0
var bad_pos := 0
var palms_inland := 0

func _count_chunk(world: Node3D, city, key: Vector2i) -> void:
	var tn := _trees_node(world, key)
	if tn == null:
		return
	n_chunks_with += 1
	var near: MultiMeshInstance3D = tn.get_node("arboles_8v")
	var far: MultiMeshInstance3D = tn.get_node("arboles_cruz")
	var cnt := near.multimesh.instance_count
	if cnt != world.tree_items(key).size():
		check(false, "la malla tiene los mismos árboles que la lista (cuadra %s)" % str(key))
	total_trees += cnt
	if far.multimesh.instance_count != cnt:
		check(false, "mismos árboles en las dos mallas (cuadra %s)" % str(key))
	if n_chunks_with == 1:
		check(near.visibility_range_end > 100.0 and far.visibility_range_begin == near.visibility_range_end and far.visibility_range_end > far.visibility_range_begin, "niveles de distancia coherentes")
	for it in world.tree_items(key): # (el motor de dibujo sin pantalla no guarda los datos del MultiMesh: se mira la lista de la que sale)
		var sp: int = it[3]
		species_seen[sp] = true
		var pr: PackedFloat64Array = city.probe(float(it[0]), float(it[2]))
		if pr[6] >= 0.0 and float(pr[1]) <= float(pr[5]) + 0.2:
			bad_pos += 1
		if sp >= TreeSprites.PALM_FIRST and float(it[2]) < world.COAST_Z - 30.0:
			palms_inland += 1
		if float(it[4]) < 0.4 or float(it[4]) > 1.5:
			bad_pos += 1

func _init() -> void:
	# ── autos civiles
	var tris := CivilCarMesh.triangle_count()
	var cm := CivilCarMesh.mesh()
	var carr := cm.surface_get_arrays(0)
	check(tris >= 150 and tris <= 260, "autos civiles: %d triángulos (cajas con rampas)" % tris)
	check(carr[Mesh.ARRAY_NORMAL] != null and (carr[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == (carr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "autos civiles: con normales")
	check(CivilCarMesh.mesh() == cm, "autos civiles: una sola malla compartida")
	# ── texturas de árboles
	check(TreeSprites.SPECIES.size() == 9, "9 especies")
	for sp in TreeSprites.SPECIES:
		for ang in [0, 45, 90, 135, 180, 225, 270, 315]:
			if not ResourceLoader.exists("%s%s_%d.png" % [TreeSprites.DIR, str(sp["id"]), ang]):
				check(false, "falta la imagen %s_%d" % [str(sp["id"]), ang])
	check(ResourceLoader.exists(HorizonTrees.DIR + "horizon_a.png") and ResourceLoader.exists(HorizonTrees.DIR + "horizon_b.png"), "tiras del horizonte")
	# ── el mundo
	var track := CityTrack.new()
	var city = track.city
	var world: Node3D = track.build_world()
	root.add_child(world)
	check(world._hz_trees.size() == 2, "bosque lejano: 2 anillos")
	var ring_tris := 0
	for r in world._hz_trees:
		ring_tris += int((r.mesh as ArrayMesh).surface_get_array_len(0) / 3) if (r.mesh as ArrayMesh).surface_get_array_len(0) > 0 else 0
	check(ring_tris > 0 and ring_tris <= 300, "bosque lejano: %d triángulos en total" % ring_tris)
	var fm: ShaderMaterial = world._facade_mat
	check(is_equal_approx(float(fm.get_shader_parameter("lod_from")), 200.0), "fachadas: fundido de detalle desde 200 m")
	world.view_k = 0.6
	check(is_equal_approx(float(fm.get_shader_parameter("lod_from")), 120.0), "fachadas: el fundido se acerca con el alcance de la vista")
	world.view_k = 1.0
	# cuadras con árboles: ruta 1 (este) y la plaza
	var cams := [Vector3(1500, 0, 20), Vector3(0, 0, 40), Vector3(-860, 0, -780), Vector3(0, 0, 1100)]
	var counted := {}
	for cp in cams:
		world.warm(cp)
		for key in world.chunks:
			if counted.has(key):
				continue
			counted[key] = true
			_count_chunk(world, city, key)
	check(n_chunks_with >= 8 and total_trees >= 150, "árboles de imagen: %d en %d cuadras" % [total_trees, n_chunks_with])
	check(species_seen.size() >= 6, "variedad: %d especies en uso" % species_seen.size())
	check(bad_pos == 0, "ningún árbol sobre el asfalto (%d mal)" % bad_pos)
	check(palms_inland == 0, "las palmeras sólo en la playa")
	# los árboles de ruta ya no van en la malla de objetos
	var rtree_in_props := 0
	for key in world.chunks:
		var ch: Node3D = world.chunks[key]
		var pi := ch.get_node_or_null("props")
		if pi == null or not city.props_in.has(key):
			continue
		var only_rtree := true
		for id in city.props_in[key]:
			if int(city.prop_type[id]) != CityProps.RTREE:
				only_rtree = false
		if only_rtree:
			rtree_in_props += 1
	check(rtree_in_props == 0, "una cuadra con sólo árboles de ruta no arma malla de objetos")
	# ── romper un árbol de calle: pasa a ser un recorte tirado y la imagen desaparece
	var tid := -1
	var tkey := Vector2i.ZERO
	for id in city.prop_type.size():
		if int(city.prop_type[id]) == CityProps.TREE:
			var k := city.chunk_of(city.prop_x[id], city.prop_z[id])
			if world.chunks.has(k) and _trees_node(world, k) != null:
				tid = id
				tkey = k
				break
	if tid < 0:
		world.warm(Vector3(0, 0, 40))
		for id in city.prop_type.size():
			if int(city.prop_type[id]) == CityProps.TREE:
				var k2 := city.chunk_of(city.prop_x[id], city.prop_z[id])
				if world.chunks.has(k2) and _trees_node(world, k2) != null:
					tid = id
					tkey = k2
					break
	check(tid >= 0, "hay un árbol de calle para romper")
	if tid >= 0:
		var before: int = (_trees_node(world, tkey).get_node("arboles_8v") as MultiMeshInstance3D).multimesh.instance_count
		track._break_locked(tid, Vector2(city.prop_x[tid], city.prop_z[tid]), Vector2(1, 0))
		world._redraw_broken()
		var tn2 := _trees_node(world, tkey)
		var after := 0
		if tn2 != null:
			after = (tn2.get_node("arboles_8v") as MultiMeshInstance3D).multimesh.instance_count
		check(after == before - 1, "al romper un árbol de calle sale de las imágenes (%d → %d)" % [before, after])
		var pi2 := (world.chunks[tkey] as Node3D).get_node_or_null("props")
		check(pi2 != null and (pi2 as MeshInstance3D).mesh.get_surface_count() > 0, "y queda un recorte tirado en la malla de objetos")
	# ── de noche y de día no rompe
	world.set_night(1.0)
	world.set_night(0.0)
	var st: Dictionary = world.stats()
	print("     cuadras %d · triángulos en memoria %dk" % [st["chunks"], int(st["tris"]) / 1000])
	quit(1 if fail else 0)
