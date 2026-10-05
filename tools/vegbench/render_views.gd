## Herramienta del benchmark de vegetación (no es parte del juego): dibuja de cada árbol pesado seleccionado las 8 vistas (0°, 45°… 315°) y las 2 vistas del cruce (frente y costado)
## con fondo transparente, misma escala, misma luz y sin ningún efecto. Guarda imágenes CRUDAS al doble de resolución; tools/vegbench/process_views.py las limpia y las deja en godot/game/vegbench/tex.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://../tools/vegbench/render_views.gd -- <carpeta de salida>   (o copiá el script a godot/tests)
extends SceneTree

const TreeModels := preload("res://game/vegbench/tree_models.gd")
var out_dir := "/tmp/claude-0/vegraw"
var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out_dir = a
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

func _run() -> void:
	var metas := {}
	for t in TreeModels.TREES:
		var id := str(t["id"])
		var o := TreeModels.original(id)
		var h: float = o["h"]
		var r: float = o["radius"]
		var S := maxf(h, 2.0 * r) * 1.06
		var px := int(t["res"]) * 2
		vp.size = Vector2i(px, px)
		for c in holder.get_children():
			c.queue_free()
		await process_frame
		var mi := MeshInstance3D.new()
		mi.mesh = o["mesh"]
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
