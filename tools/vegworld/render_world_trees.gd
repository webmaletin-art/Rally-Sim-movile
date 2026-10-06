## Herramienta (no es parte del juego): dibuja las 8 vistas (0°, 45°… 315°) de cada especie del mundo abierto, con fondo transparente, misma luz y misma escala.
## Los piezas de papel (godot/game/models/paper) vienen del pack de biblioteca/vegetacion_y_suelo/arboles. Guarda imágenes CRUDAS al doble de resolución; tools/vegworld/process_world_trees.py las limpia y las deja en godot/game/city/trees.
## Uso: copiá este script a godot/tests y: xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/render_world_trees.gd -- <carpeta de salida> [id ...]
extends SceneTree

const TreeModels := preload("res://game/vegbench/tree_models.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const TreeSprites := preload("res://game/city/tree_sprites.gd")
var out_dir := "/tmp/claude-0/vegworld_raw"
var only: Array = []
var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		only.append(args[i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	TreeModels.set_ambient(env)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	TreeModels.add_sun(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.5
	cam.far = 200.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	_run()

## Pieza de papel del juego (godot/game/models/paper): las especies del mundo abierto salen de los mismos árboles de papel que ya se ven en las plazas, así se parecen
func _pap(id: String, hgt: float) -> Dictionary:
	var m := PaperKit.mesh(id)
	var ph := float(PaperKit.info(id).get("h", 1.0))
	var k := hgt / maxf(ph, 0.05)
	var bb := m.get_aabb()
	var r := maxf(maxf(absf(bb.position.x), absf(bb.end.x)), maxf(absf(bb.position.z), absf(bb.end.z))) * k
	var tris := 0
	for i in m.get_surface_count():
		tris += int(m.surface_get_array_len(i) / 3)
	return {"mesh": m, "h": hgt, "radius": r, "k": k, "tris": tris}

func _run() -> void:
	var metas := {}
	for t in TreeSprites.SPECIES:
		var id := str(t["id"])
		if not only.is_empty() and not only.has(id):
			continue
		var o := _pap(str(t["src"]), float(t["h"]))
		var h: float = o["h"]
		var r: float = o["radius"]
		var S := maxf(h, 2.0 * r) * 1.06
		var px := 512
		vp.size = Vector2i(px, px)
		for c in holder.get_children():
			c.queue_free()
		await process_frame
		var mi := MeshInstance3D.new()
		mi.mesh = o["mesh"]
		mi.scale = Vector3.ONE * float(o["k"])
		mi.material_override = PaperKit.material(null, 0.0, 0.2, 0.0)
		holder.add_child(mi)
		cam.size = S
		for ang in [0, 45, 90, 135, 180, 225, 270, 315]:
			var a := deg_to_rad(float(ang))
			cam.position = Vector3(sin(a), 0.0, cos(a)) * 60.0 + Vector3(0, h * 0.5, 0)
			cam.look_at(Vector3(0, h * 0.5, 0))
			for i in 3:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/%s_%d.png" % [out_dir, id, ang])
		metas[id] = {"S": snappedf(S, 0.001), "h": h, "radius": snappedf(r, 0.001), "res": int(t["res"]), "tris": int(o["tris"])}
		print("OK ", id, " S=", S, " tris=", o["tris"])
	var f := FileAccess.open(out_dir + "/meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(metas))
	f.close()
	quit()
