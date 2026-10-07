## Genera las miniaturas de los autos del carrusel del garaje (godot/game/ui/thumbs/<id>.png): cada auto, con su pintura de fábrica, sobre la plataforma oscura.
## Uso (con pantalla virtual): xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://../tools/godot/gen_thumbs.gd
## (se corre una sola vez o cuando cambian los modelos; los PNG se versionan)
extends SceneTree

const Showroom := preload("res://game/ui/showroom.gd")
const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var prof := Profile.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 320)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sh: Node3D = Showroom.new()
	vp.add_child(sh)
	for i in 4:
		await process_frame
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.near = 0.3
	cam.far = 80.0
	vp.add_child(cam)
	cam.make_current()
	var out_dir := ProjectSettings.globalize_path("res://game/ui/thumbs")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for id in CarBuild.catalog()["order"]:
		sh.set_car(str(id), prof.new_car_state(str(id)), vehicles)
		for c in sh.crew:
			(c["node"] as Node3D).visible = false
		var room := sh.get_node_or_null("GarageRoom")
		if room != null:
			room.visible = false
		for ch in sh.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is CylinderMesh:
				ch.visible = false # la plataforma brillante hace un reflejo blanco: en la miniatura queda el piso oscuro de fondo
		var d: float = sh.car_len * 1.34 + 0.7
		var a := 0.62
		var target := Vector3(0.0, 0.55, 0.0)
		cam.position = target + Vector3(sin(a) * d, 0.55, cos(a) * d)
		cam.look_at(target)
		for i in 8:
			await process_frame
		var img := vp.get_texture().get_image()
		img.resize(320, 160, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/%s.png" % [out_dir, str(id)])
		print("miniatura ", id)
	quit()
