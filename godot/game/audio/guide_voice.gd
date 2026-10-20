extends CanvasLayer
## Guía hablada del Modo de prueba (20/10/2026, pedido del dueño: «hacerlo guiado con tu voz, Claudio… que sea mucho más interactivo para el jugador»).
## Cada línea del guion (game/data/guide_script.json, en español) se muestra como SUBTÍTULO abajo en el medio y, si existe su audio —game/audio/guide/<idioma>/<id>.ogg (o .mp3 / .wav;
## si falta en ese idioma se usa el de es/)—, se reproduce con la voz. Sin audio se ve sólo el texto: el juego anda igual y el dueño va sumando las grabaciones cuando las tenga
## (lista de lo que falta: tools/audio/guide_voice_todo.py; guion con todos los textos: docs/GUION_VOZ_GUIA.md).
## say(id) dice una línea una sola vez por sesión (salvo force); si ya está hablando, la próxima espera su turno (no se pisan). El modo viene del perfil: full (voz y texto) · text · off.

const Tr := preload("res://game/i18n/tr.gd")

const SCRIPT_PATH := "res://game/data/guide_script.json"
const DIR := "res://game/audio/guide/"
const EXTS := [".ogg", ".mp3", ".wav"]
const MODES := ["full", "text", "off"]
const MAX_QUEUE := 3

signal said(id: String, text: String)

var mode := "full" # full: voz y texto · text: sólo texto · off: nada
var dock := "center" # dónde van los subtítulos: abajo en el medio («center», jugando) o sobre la parte de la derecha («right»: en los menús y la pausa, donde a la izquierda hay paneles)
var last_id := ""
var heard: Dictionary = {} # id → veces (esta sesión)
var _lines: Dictionary = {} # id → {"es": texto, "ctx": dónde}
var _order: Array = []
var _player: AudioStreamPlayer
var _panel: PanelContainer
var _label: Label
var _hide_t := 0.0
var _queue: Array = []
var _speaking := false

func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_script()

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "Master"
	add_child(_player)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -22.0
	_apply_dock()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.82)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(0.4, 0.75, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_panel.add_child(col)
	var who := Label.new()
	who.text = "🎓 CLAUDIO"
	who.add_theme_font_size_override("font_size", 13)
	who.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0))
	col.add_child(who)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(560, 0)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	col.add_child(_label)
	_panel.visible = false
	root.add_child(_panel)

func _load_script() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCRIPT_PATH))
	if not (d is Dictionary):
		return
	for l in (d as Dictionary).get("lines", []):
		var e: Dictionary = l
		_lines[str(e["id"])] = e
		_order.append(str(e["id"]))

## Todas las líneas del guion (ids en orden)
func ids() -> Array:
	return _order

func has_line(id: String) -> bool:
	return _lines.has(id)

## El texto de una línea en el idioma actual
func text_of(id: String) -> String:
	if not _lines.has(id):
		return ""
	return Tr.t(str((_lines[id] as Dictionary).get("es", "")))

## Ruta del audio de una línea ("" si no hay): primero el idioma actual y después el español
func clip_path(id: String) -> String:
	for lang in [Tr.current, "es"]:
		for ext in EXTS:
			var p := "%s%s/%s%s" % [DIR, lang, id, ext]
			if ResourceLoader.exists(p):
				return p
	return ""

## Subtítulos abajo en el medio (jugando) o sobre la parte derecha de la pantalla (menús y pausa: los paneles ocupan la izquierda)
func set_dock(side: String) -> void:
	dock = "right" if side == "right" else "center"
	_apply_dock()

func _apply_dock() -> void:
	if _panel == null:
		return
	var ax := 0.745 if dock == "right" else 0.5
	_panel.anchor_left = ax
	_panel.anchor_right = ax

func set_mode(m: String) -> void:
	mode = m if MODES.has(m) else "full"
	if mode == "off":
		stop()

## Pasa al modo siguiente (voz y texto → sólo texto → apagada) y lo devuelve
func cycle_mode() -> String:
	mode = str(MODES[(MODES.find(mode) + 1) % MODES.size()])
	if mode == "off":
		stop()
	return mode

## Lo que dice el botón del modo
static func mode_label(m: String) -> String:
	match m:
		"text":
			return "💬 " + Tr.t("GUÍA: SÓLO TEXTO")
		"off":
			return "🔇 " + Tr.t("GUÍA: APAGADA")
	return "🔊 " + Tr.t("GUÍA: VOZ Y TEXTO")

## La versión corta del botón (para el armado de la prueba, donde no hay lugar)
static func mode_short(m: String) -> String:
	match m:
		"text":
			return "💬 " + Tr.t("TEXTO")
		"off":
			return "🔇 " + Tr.t("SIN GUÍA")
	return "🔊 " + Tr.t("VOZ")

## Dice una línea (una sola vez por sesión, salvo force). Devuelve true si la dijo o la dejó en cola.
## interrupt: corta lo que estaba diciendo y la dice ya (lo que el jugador acaba de tocar se explica en el momento, sin esperar turno)
func say(id: String, force := false, interrupt := false) -> bool:
	if mode == "off" or not _lines.has(id):
		return false
	if heard.has(id) and not force:
		return false
	heard[id] = int(heard.get(id, 0)) + 1
	if interrupt:
		_queue.clear()
		if _player != null:
			_player.stop()
		_speak(id)
		return true
	if _speaking:
		if not _queue.has(id):
			_queue.append(id)
			while _queue.size() > MAX_QUEUE:
				_queue.pop_front()
		return true
	_speak(id)
	return true

func _speak(id: String) -> void:
	_speaking = true
	last_id = id
	var txt := text_of(id)
	_label.text = txt
	_panel.visible = true
	_hide_t = clampf(1.2 + 0.06 * float(txt.length()), 3.0, 14.0)
	if mode == "full":
		var p := clip_path(id)
		if p != "":
			var st: Variant = load(p)
			if st is AudioStream:
				_player.stream = st
				_player.play()
				_hide_t = maxf(_hide_t, float((st as AudioStream).get_length()) + 0.7)
	said.emit(id, txt)

func stop() -> void:
	_queue.clear()
	_speaking = false
	_hide_t = 0.0
	if _player != null:
		_player.stop()
	if _panel != null:
		_panel.visible = false

func is_speaking() -> bool:
	return _speaking

func _process(dt: float) -> void:
	if not _speaking:
		return
	_hide_t -= dt
	if _hide_t > 0.0:
		return
	if _player != null and _player.playing:
		_hide_t = 0.2
		return
	_speaking = false
	if not _queue.is_empty():
		_speak(str(_queue.pop_front()))
	elif _panel != null:
		_panel.visible = false
