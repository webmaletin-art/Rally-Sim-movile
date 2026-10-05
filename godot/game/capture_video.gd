extends RefCounted
## Grabación de video del juego (botón 🎥). Sin audio. Guarda un AVI con cuadros JPEG (Motion-JPEG): lo abren VLC, MX Player y la mayoría de los reproductores;
## la galería del juego también lo reproduce. Para no frenar el juego se graba a pocos cuadros por segundo y a tamaño reducido (según «Calidad de la captura»).
## Se escribe de a poco al disco (no se acumula en memoria) y al parar se arma el índice y se corrigen los tamaños de la cabecera.

const Capture := preload("res://game/capture.gd")
const DIR := "user://captures"
## calidad → [cuadros por segundo, ancho, calidad JPG]
const QUALITY := {"low": [12, 480, 0.6], "mid": [15, 640, 0.7], "high": [20, 854, 0.8]}
const MAX_SECONDS := 180.0 # tope: 3 minutos por video

var active := false
var path := ""
var frames := 0
var seconds := 0.0
var _f: FileAccess
var _fps := 15
var _w := 640
var _h := 360
var _jq := 0.7
var _acc := 0.0
var _index: Array = [] # [offset, tamaño] de cada cuadro (offset relativo a «movi»)
var _movi_start := 0
var _hide := false
var _hidden: Array = []

func start(host: Node, profile: RefCounted) -> bool:
	var q: Array = QUALITY.get(str(profile.setting("capQuality")), QUALITY["mid"])
	_fps = int(q[0])
	_w = int(q[1])
	_jq = float(q[2])
	var vs: Vector2 = host.get_viewport().get_visible_rect().size
	_h = maxi(2, int(round(float(_w) * vs.y / maxf(vs.x, 1.0) / 2.0)) * 2)
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	path = DIR + "/DreamRacing_%s.avi" % stamp
	_f = FileAccess.open(path, FileAccess.WRITE)
	if _f == null:
		return false
	_write_header()
	_index.clear()
	frames = 0
	seconds = 0.0
	_acc = 0.0
	active = true
	_hide = str(profile.setting("capHud")) == "hide"
	if _hide:
		_hidden = Capture._layers(host.get_tree().root)
		for n in _hidden:
			(n as CanvasLayer).visible = false
	return true

## Se llama cada cuadro con el tiempo transcurrido: saca un cuadro del video cuando toca
func tick(host: Node, dt: float) -> void:
	if not active:
		return
	_acc += dt
	seconds += dt
	if _acc < 1.0 / float(_fps):
		return
	_acc = 0.0
	var img: Image = host.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(_w, _h, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	var jpg: PackedByteArray = img.save_jpg_to_buffer(_jq)
	var off := _f.get_position() - _movi_start
	_f.store_buffer("00dc".to_ascii_buffer())
	_f.store_32(jpg.size())
	_f.store_buffer(jpg)
	if jpg.size() % 2 == 1:
		_f.store_8(0) # los bloques RIFF se alinean a 2 bytes
	_index.append([off, jpg.size()])
	frames += 1
	if seconds >= MAX_SECONDS:
		stop()

## Cierra el video (índice + cabecera con los tamaños reales). Devuelve la ruta ("" si no hubo cuadros).
func stop() -> String:
	if not active:
		return ""
	active = false
	for n in _hidden:
		if is_instance_valid(n):
			(n as CanvasLayer).visible = true
	_hidden.clear()
	var movi_end := _f.get_position()
	# índice idx1
	_f.store_buffer("idx1".to_ascii_buffer())
	_f.store_32(16 * _index.size())
	for e in _index:
		_f.store_buffer("00dc".to_ascii_buffer())
		_f.store_32(0x10) # AVIIF_KEYFRAME
		_f.store_32(int(e[0])) # offset del bloque desde la etiqueta «movi»
		_f.store_32(int(e[1]))
	var total := _f.get_position()
	# corregir tamaños
	_f.seek(4)
	_f.store_32(total - 8)
	_f.seek(48) # dwTotalFrames de avih
	_f.store_32(frames)
	_f.seek(140) # dwLength de strh
	_f.store_32(frames)
	_f.seek(_movi_start - 4) # tamaño de la lista «movi»
	_f.store_32(movi_end - _movi_start)
	_f.close()
	_f = null
	if frames == 0:
		DirAccess.remove_absolute(path)
		return ""
	var pd := Capture.pictures_dir().replace("Pictures", "Movies")
	if pd != "" and DirAccess.make_dir_recursive_absolute(pd) == OK:
		DirAccess.copy_absolute(path, pd + "/" + path.get_file()) # y una copia en Películas, si el teléfono lo permite
	return path

func _write_header() -> void:
	var us := int(1000000.0 / float(_fps))
	var f := _f
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(0) # (se corrige al cerrar)
	f.store_buffer("AVI ".to_ascii_buffer())
	f.store_buffer("LIST".to_ascii_buffer())
	f.store_32(192)
	f.store_buffer("hdrl".to_ascii_buffer())
	f.store_buffer("avih".to_ascii_buffer())
	f.store_32(56)
	f.store_32(us) # microsegundos por cuadro
	f.store_32(0)
	f.store_32(0)
	f.store_32(0x10) # AVIF_HASINDEX
	f.store_32(0) # (offset 48) total de cuadros
	f.store_32(0)
	f.store_32(1) # un flujo
	f.store_32(1 << 20)
	f.store_32(_w)
	f.store_32(_h)
	for i in 4:
		f.store_32(0)
	f.store_buffer("LIST".to_ascii_buffer())
	f.store_32(116)
	f.store_buffer("strl".to_ascii_buffer())
	f.store_buffer("strh".to_ascii_buffer())
	f.store_32(56)
	f.store_buffer("vids".to_ascii_buffer())
	f.store_buffer("MJPG".to_ascii_buffer())
	f.store_32(0)
	f.store_16(0)
	f.store_16(0)
	f.store_32(0)
	f.store_32(1) # escala
	f.store_32(_fps) # velocidad
	f.store_32(0)
	f.store_32(0) # (offset 140) largo
	f.store_32(1 << 20)
	f.store_32(0xFFFFFFFF)
	f.store_32(0)
	f.store_16(0)
	f.store_16(0)
	f.store_16(_w)
	f.store_16(_h)
	f.store_buffer("strf".to_ascii_buffer())
	f.store_32(40)
	f.store_32(40)
	f.store_32(_w)
	f.store_32(_h)
	f.store_16(1)
	f.store_16(24)
	f.store_buffer("MJPG".to_ascii_buffer())
	f.store_32(_w * _h * 3)
	f.store_32(0)
	f.store_32(0)
	f.store_32(0)
	f.store_32(0)
	f.store_buffer("LIST".to_ascii_buffer())
	f.store_32(0) # (se corrige al cerrar)
	f.store_buffer("movi".to_ascii_buffer())
	_movi_start = f.get_position() - 4 # el índice cuenta desde la etiqueta «movi»
