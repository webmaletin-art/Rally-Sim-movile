extends SceneTree
## Hornea los FBX de Mixamo (importados por Godot) a un archivo binario compacto: rotaciones por hueso a 15 fps (int16) + posición de la cadera.
const FPS := 15.0
func _init() -> void:
	var dir := DirAccess.open("res://fbx")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".fbx") and f != "ybot_tpose.fbx":
			files.append(f)
	files.sort()
	var clips: Array = []
	var total := 0
	for f in files:
		var sc: PackedScene = load("res://fbx/" + f)
		if sc == null:
			print("sin importar: ", f)
			continue
		var n: Node = sc.instantiate()
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		var a: Animation = ap.get_animation(ap.get_animation_list()[ap.get_animation_list().size() - 1]) if ap.get_animation_list().size() > 0 else null
		for nm in ap.get_animation_list():
			if nm != "RESET":
				a = ap.get_animation(nm)
		if a == null:
			continue
		var frames := maxi(2, int(ceil(a.length * FPS)) + 1)
		var bones: Array = []
		var rots: Array = []
		var hips_pos := PackedVector3Array()
		for i in a.get_track_count():
			var p := str(a.track_get_path(i))
			var bn := p.get_slice(":", 1).replace("mixamorig_", "").replace("mixamorig", "")
			if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				var q := PackedFloat32Array()
				for k in frames:
					var qq: Quaternion = a.rotation_track_interpolate(i, minf(float(k) / FPS, a.length))
					q.append(qq.x); q.append(qq.y); q.append(qq.z); q.append(qq.w)
				bones.append(bn)
				rots.append(q)
			elif a.track_get_type(i) == Animation.TYPE_POSITION_3D and bn == "Hips":
				for k in frames:
					hips_pos.append(a.position_track_interpolate(i, minf(float(k) / FPS, a.length)))
		clips.append({"name": f.get_basename(), "len": a.length, "frames": frames, "bones": bones, "rots": rots, "hips": hips_pos})
		total += frames * bones.size() * 8
		n.free()
	print("clips ", clips.size(), " bytes aprox ", total)
	var fa := FileAccess.open("res://menu_clips.txt", FileAccess.WRITE)
	fa.store_buffer("MXA1".to_utf8_buffer())
	fa.store_32(clips.size())
	fa.store_float(FPS)
	for c in clips:
		fa.store_pascal_string(c["name"])
		fa.store_float(c["len"])
		fa.store_32(c["frames"])
		fa.store_16((c["bones"] as Array).size())
		for b in c["bones"]:
			fa.store_pascal_string(b)
		fa.store_8(1 if (c["hips"] as PackedVector3Array).size() == c["frames"] else 0)
		for q in c["rots"]:
			# constante → una sola clave
			var arr: PackedFloat32Array = q
			var const_ := true
			for k in range(4, arr.size()):
				if absf(arr[k] - arr[k % 4]) > 0.002:
					const_ = false
					break
			fa.store_8(1 if const_ else 0)
			var cnt := 4 if const_ else arr.size()
			for k in cnt:
				fa.store_16(int(clampf(arr[k], -1.0, 1.0) * 32767.0))
		if (c["hips"] as PackedVector3Array).size() == c["frames"]:
			for v in (c["hips"] as PackedVector3Array):
				fa.store_float(v.x); fa.store_float(v.y); fa.store_float(v.z)
	fa.close()
	print("hecho ", FileAccess.get_file_as_bytes("res://menu_clips.txt").size(), " bytes")
	quit()
