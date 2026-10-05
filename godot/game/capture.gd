extends RefCounted
## Capturas de pantalla del juego (para trailers y para compartir): se pueden sacar con o sin el HUD, con calidad y formato a elección.
## Se guardan en user://captures y, si el teléfono lo permite, también en Imágenes/DreamRacing. La galería las lista y las borra.

const DIR := "user://captures"
## calidad → [escala, calidad del JPG]
const QUALITY := {"low": [0.5, 0.70], "mid": [0.75, 0.88], "high": [1.0, 0.95]}

static func pictures_dir() -> String:
	var p := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	return (p + "/DreamRacing") if p != "" else ""

static func _layers(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).layer >= 1:
			out.append(n)
	return out

## Saca una captura de la pantalla. Devuelve la ruta guardada ("" si falló). Es una corrutina: usar con await.
static func take(host: Node, profile: RefCounted, force_hide := false) -> String:
	var tree := host.get_tree()
	var hide := force_hide or str(profile.setting("capHud")) == "hide"
	var hidden: Array = []
	if hide:
		for n in _layers(tree.root):
			var cl := n as CanvasLayer
			if cl.visible:
				hidden.append(cl)
				cl.visible = false
	await tree.process_frame
	await tree.process_frame
	var img: Image = host.get_viewport().get_texture().get_image()
	for n in hidden:
		(n as CanvasLayer).visible = true
	if img == null or img.is_empty():
		return ""
	var q: Array = QUALITY.get(str(profile.setting("capQuality")), QUALITY["mid"])
	if float(q[0]) < 1.0:
		img.resize(int(img.get_width() * float(q[0])), int(img.get_height() * float(q[0])), Image.INTERPOLATE_LANCZOS)
	var png := str(profile.setting("capFormat")) == "png"
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var fname := "DreamRacing_%s.%s" % [stamp, "png" if png else "jpg"]
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR + "/" + fname
	var ok := (img.save_png(path) if png else img.save_jpg(path, float(q[1]))) == OK
	var pd := pictures_dir()
	if ok and pd != "" and DirAccess.make_dir_recursive_absolute(pd) == OK:
		var p2 := pd + "/" + fname
		if png:
			img.save_png(p2)
		else:
			img.save_jpg(p2, float(q[1]))
	return path if ok else ""

## Capturas guardadas, la más nueva primero
static func list() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".jpg") or f.ends_with(".png") or f.ends_with(".avi"):
			out.append(DIR + "/" + f)
	out.sort()
	out.reverse()
	return out

static func delete(path: String) -> void:
	DirAccess.remove_absolute(path)
	var pd := pictures_dir()
	if pd != "":
		var p2 := pd + "/" + path.get_file()
		if FileAccess.file_exists(p2):
			DirAccess.remove_absolute(p2)
		var p3 := pd.replace("Pictures", "Movies") + "/" + path.get_file()
		if FileAccess.file_exists(p3):
			DirAccess.remove_absolute(p3)

## Primer cuadro de un video AVI (Motion-JPEG): se busca el primer bloque «00dc» y se decodifica
static func video_frame(path: String) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 300:
		return null
	f.seek(224) # justo después de la cabecera, donde empieza el primer cuadro
	if f.get_buffer(4).get_string_from_ascii() != "00dc":
		return null
	var n := f.get_32()
	var img := Image.new()
	return img if img.load_jpg_from_buffer(f.get_buffer(n)) == OK else null

static func thumb(path: String, w := 168, h := 94) -> Texture2D:
	var img: Image = video_frame(path) if path.ends_with(".avi") else Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)
