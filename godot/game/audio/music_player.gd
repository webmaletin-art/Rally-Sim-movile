extends Node
## Música de fondo, como una radio puesta despacio: temas al azar (sin repetir el último) que suenan en los menús. En Opciones → Sonido se elige:
##  · «Música»: sólo en los menús (por defecto) · también jugando · apagada
##  · «Volumen de la música» (por defecto bajo, de radio)
## Es un nodo de la aplicación (app.gd), no de la carrera: sigue sonando al pasar de un menú a otro y se apaga con un fundido al entrar a jugar (si no está en «también jugando»).
## Los temas y sus títulos están en game/audio/music/tracks.json (los arma tools/trailer/prepare_music.py: ogg con el volumen igualado).

const DIR := "res://game/audio/music/"
const BUS := "Music"
const FADE_DB_PER_S := 45.0 # velocidad de los fundidos
const SILENT_DB := -70.0

signal track_changed(title: String)

var profile: RefCounted
var tracks: Array = []
var context := "menu" # "menu" (menús) | "game" (jugando)
var now_title := ""
var _player: AudioStreamPlayer
var _cur := -1
var _last := -1
var _poll := 0.0
var _db := SILENT_DB # volumen actual (sube y baja con fundidos)
var _target_db := SILENT_DB

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # sigue en la pausa (si la música está permitida ahí)
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tracks.json")) if FileAccess.file_exists(DIR + "tracks.json") else null
	if m is Dictionary:
		tracks = (m as Dictionary).get("tracks", [])
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	_player.volume_db = SILENT_DB
	_player.finished.connect(_on_finished)
	add_child(_player)

## Dónde está el jugador: "menu" o "game". Lo llama app.gd al abrir un menú o al largar.
func set_context(c: String) -> void:
	context = c

func _setting(key: String, fallback):
	if profile == null:
		return fallback
	var v = profile.setting(key)
	return fallback if v == null else v

## ¿Tiene que sonar ahora? (por el modo elegido, el volumen y dónde se está)
func wanted() -> bool:
	if tracks.is_empty():
		return false
	var mode := str(_setting("musicMode", "menu"))
	if mode == "off" or int(_setting("volMusic", 25)) <= 0 or int(_setting("volume", 80)) <= 0:
		return false
	return mode == "always" or context == "menu"

## Volumen de la música en dB (volumen de la música × volumen general)
func level_db() -> float:
	var lin := float(_setting("volMusic", 25)) / 100.0 * float(_setting("volume", 80)) / 100.0
	return linear_to_db(maxf(lin * 0.9, 1e-4))

func _process(dt: float) -> void:
	if _player == null:
		return
	_poll += dt
	if _poll >= 0.25:
		_poll = 0.0
		if wanted():
			_target_db = level_db()
			if not _player.playing:
				_start_next()
		else:
			_target_db = SILENT_DB
	_db = move_toward(_db, _target_db, FADE_DB_PER_S * dt)
	_player.volume_db = _db
	if _player.playing and _db <= SILENT_DB + 0.5 and _target_db <= SILENT_DB:
		_player.stop() # el fundido terminó

func _on_finished() -> void:
	if wanted():
		_start_next()

## Un tema al azar que no sea el último que sonó
func _start_next() -> void:
	if tracks.is_empty():
		return
	var n := tracks.size()
	var pick := randi() % n
	if n > 1:
		while pick == _last:
			pick = randi() % n
	var t: Dictionary = tracks[pick]
	var path := DIR + str(t["file"])
	var stream := load(path) as AudioStream
	if stream == null:
		_last = pick # no se pudo cargar (archivo faltante): se prueba otro la próxima vez
		return
	_cur = pick
	_last = pick
	_player.stream = stream
	_db = minf(_db, SILENT_DB + 25.0) # empieza bajito y sube con un fundido
	_player.volume_db = _db
	_player.play()
	now_title = str(t.get("title", ""))
	track_changed.emit(now_title)

## Para las pruebas: ¿está sonando algo?
func is_playing() -> bool:
	return _player != null and _player.playing
