## Prueba de Paper Race: la pista cerrada tiene tramos de asfalto y de tierra, la física devuelve la superficie de cada tramo,
## todas las piezas de papel cargan y el mundo de papel se arma con todas las piezas del pack.
## Uso: godot --headless --path godot --script res://tests/paper_test.gd
extends SceneTree

const PaperTrack := preload("res://game/track/paper_track.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const PaperWorld := preload("res://game/track/paper_world.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var tr := PaperTrack.new("paper", "asphalt", false, 0.6)
	check(tr.n == 1100 and tr.length > 1500.0 and tr.length < 4000.0, "pista cerrada de %.0f m" % tr.length)
	var asph := 0
	var dirt := 0
	for i in tr.n:
		if int(tr.road_surf[i]) == 1:
			dirt += 1
		else:
			asph += 1
	check(asph > 300 and dirt > 300, "tramos de asfalto (%d) y de tierra (%d)" % [asph, dirt])
	var v: Variant = tr.make_view(false)
	var ok_a := false
	var ok_d := false
	for i in tr.n:
		if tr.road_surf[(i + 3) % tr.n] != tr.road_surf[i] or tr.road_surf[(i + tr.n - 3) % tr.n] != tr.road_surf[i]:
			continue # justo en el empalme de dos tramos la búsqueda puede elegir la muestra vecina
		var p: Vector3 = tr.samples[i]
		var gi: Vector2 = v.ground_info(p.x, p.z)
		if int(tr.road_surf[i]) == 0 and int(gi.y) == 0:
			ok_a = true
		if int(tr.road_surf[i]) == 1 and int(gi.y) == 1:
			ok_d = true
		if int(tr.road_surf[i]) != int(gi.y) and absf(v.r_lat) < tr.half_width - 0.1:
			check(false, "la superficie del camino en la muestra %d no coincide (%d vs %d)" % [i, tr.road_surf[i], int(gi.y)])
			break
	check(ok_a and ok_d, "ground_info devuelve asfalto y tierra según el tramo")
	# pieza por pieza
	var bad := 0
	for c in PaperKit.catalog():
		var m := PaperKit.mesh(str(c["id"]))
		if m == null or m.get_surface_count() == 0:
			bad += 1
			print("   sin malla: ", c["id"])
	check(bad == 0 and PaperKit.catalog().size() >= 50, "%d piezas de papel cargan" % PaperKit.catalog().size())
	# el mundo usa todo lo que corresponde del pack
	var w := PaperWorld.new()
	w.setup(tr, 0.5)
	var used := {}
	for ch in w.get_children():
		if ch is MultiMeshInstance3D:
			used[ch.multimesh.mesh] = true
	check(w.inst_total > 3000, "la selva tiene %d plantas, árboles y rocas" % w.inst_total)
	var kinds := {}
	for ch in w.get_children():
		if ch is MultiMeshInstance3D:
			for c in PaperKit.catalog():
				if PaperKit.mesh(str(c["id"])) == ch.multimesh.mesh:
					kinds[str(c["id"])] = true
	check(kinds.size() >= 35, "se usan %d piezas distintas del pack" % kinds.size())
	w.free()
	quit(1 if fail else 0)
