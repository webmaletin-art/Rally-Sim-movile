extends PanelContainer
## Selector de tarjeta (ver Kit.selector): título chico arriba y, abajo, ◀ valor ▶.

const Kit := preload("res://game/ui/ui_kit.gd")

var values: Array = []
var idx := 0
var fmt: Callable
var cb: Callable
var title_l: Label
var val_l: Label
var loop := true
var sfx: Node

func _init(p_title: String, p_values: Array, p_cur, p_fmt: Callable, p_cb: Callable, h := 64.0) -> void:
	values = p_values
	fmt = p_fmt
	cb = p_cb
	idx = maxi(0, values.find(p_cur))
	custom_minimum_size = Vector2(0, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", Kit.box(Kit.PANEL2, 12, Kit.LINE, 1, 10))
	var col := Kit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	title_l = Kit.label(p_title, 13, Kit.MUTED)
	title_l.clip_text = true
	title_l.custom_minimum_size.x = 40
	col.add_child(title_l)
	var row := Kit.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var la := Kit.label("◀", 18, Kit.ACCENT)
	la.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(la)
	val_l = Kit.label("", 19, Kit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_l.clip_text = true
	val_l.custom_minimum_size.x = 40
	row.add_child(val_l)
	var ra := Kit.label("▶", 18, Kit.ACCENT)
	ra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ra)
	_refresh()

func _refresh() -> void:
	val_l.text = str(fmt.call(values[idx])) if fmt.is_valid() else str(values[idx])

func step(d: int) -> void:
	if values.is_empty():
		return
	var n := idx + d
	if loop:
		n = posmod(n, values.size())
	else:
		n = clampi(n, 0, values.size() - 1)
	idx = n
	_refresh()
	if sfx != null:
		sfx.play("click")
	if cb.is_valid():
		cb.call(values[idx])

func set_value(v) -> void:
	idx = maxi(0, values.find(v))
	_refresh()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		step(-1 if ev.position.x < size.x * 0.5 else 1)
		accept_event()
