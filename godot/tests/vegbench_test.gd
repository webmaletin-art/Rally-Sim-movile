## Benchmark de vegetación: imágenes y modelos de los 5 árboles, pista, reparto reproducible (los primeros N de 5000 = los N de 1000) y mallas de los dos impostores.
## Uso: godot --headless --path godot --script res://tests/vegbench_test.gd
extends SceneTree

const TreeModels := preload("res://game/vegbench/tree_models.gd")
const TreeImpostor8View := preload("res://game/vegbench/tree_impostor_8view.gd")
const TreeCross2Planes := preload("res://game/vegbench/tree_cross.gd")
const VegTrack := preload("res://game/vegbench/veg_track.gd")
const VegScatter := preload("res://game/vegbench/veg_scatter.gd")

func _init() -> void:
	var fail := false
	for t in TreeModels.TREES:
		var id := str(t["id"])
		var o := TreeModels.original(id)
		var m := TreeModels.frame_meta(id)
		var imp := TreeImpostor8View.build(id)
		var cr := TreeCross2Planes.build(id)
		var ok: bool = TreeModels.has_images(id) and int(o["tris"]) > 2000 and float(m.get("S", 0.0)) > 1.0 and int(imp["tris"]) == 2 and int(cr["tris"]) == 4 and (imp["mesh"] as ArrayMesh).get_surface_count() == 1
		for ang in TreeModels.VIEW_ANGLES:
			if not ResourceLoader.exists(TreeModels.view_path(id, int(ang))):
				ok = false
		print("%s %s · %d triángulos originales · cuadro %.1f m · 8 vistas %.1f MB · cross %.1f MB" % ["OK  " if ok else "FALLA", id, int(o["tris"]), float(m.get("S", 0.0)), float(imp["tex_bytes"]) / 1048576.0, float(cr["tex_bytes"]) / 1048576.0])
		if not ok:
			fail = true
	var tr = VegTrack.create()
	var len_ok: bool = tr.length > 1800.0 and tr.length < 4000.0
	print("%s pista: %.2f km" % ["OK  " if len_ok else "FALLA", float(tr.length) / 1000.0])
	if not len_ok:
		fail = true
	var a := VegScatter.new()
	a.setup(tr, 5)
	a.generate(300, 1000)
	var b := VegScatter.new()
	b.setup(tr, 5)
	b.generate(120, 1000)
	var same := true
	for i in 120:
		for k in 6:
			if absf(float(a.items[i][k]) - float(b.items[i][k])) > 1e-6:
				same = false
	print("%s reparto reproducible (semilla fija, el subconjunto coincide)" % ["OK  " if same else "FALLA"])
	if not same:
		fail = true
	# ningún árbol sobre el camino
	var on_road := 0
	var v = tr.make_view(false)
	for it in a.items:
		v.hint = -1
		v.ground_smooth(float(it[0]), float(it[2]))
		if float(v.r_dist) < float(tr.half_width) + 1.0:
			on_road += 1
	print("%s árboles sobre el camino: %d de %d" % ["OK  " if on_road == 0 else "FALLA", on_road, a.items.size()])
	if on_road > 0:
		fail = true
	quit(1 if fail else 0)
