## Grabación de video: arma un AVI Motion-JPEG válido (cabecera, cuadros e índice con tamaños correctos). Necesita pantalla (con xvfb-run); el CI la saltea sin imagen.
## Uso: xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/capture_video_test.gd
extends SceneTree

const CaptureVideo := preload("res://game/capture_video.gd")
const Profile := preload("res://game/data/profile.gd")

func _initialize() -> void:
	var host := Node3D.new()
	root.add_child(host)
	await process_frame
	var profile := Profile.new()
	profile.set_setting("capQuality", "low")
	var rec := CaptureVideo.new()
	print("start ", rec.start(host, profile))
	for i in 40:
		await process_frame
		rec.tick(host, 0.1)
	var p := rec.stop()
	print("path ", p, " frames ", rec.frames)
	var f := FileAccess.open(p, FileAccess.READ)
	var data := f.get_buffer(f.get_length())
	print("size ", data.size(), " riff ", data.slice(0, 4).get_string_from_ascii(), " riffsize ", data.decode_u32(4) + 8 == data.size(), " frames_hdr ", data.decode_u32(48), " len_strh ", data.decode_u32(140))
	if OS.has_environment("KEEP_AVI"):
		DirAccess.copy_absolute(p, OS.get_environment("KEEP_AVI"))
	DirAccess.remove_absolute(p)
	quit()
