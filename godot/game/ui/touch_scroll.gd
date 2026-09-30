extends ScrollContainer
## ScrollContainer que se desplaza arrastrando el dedo aunque el toque empiece sobre un botón. Si el dedo se movió, el botón
## que estaba debajo no se activa (Kit.scroll_moved).

var _start := Vector2.ZERO
var _active := false
var _acc := 0.0

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var rect := get_global_rect()
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			_active = rect.has_point(ev.position)
			_start = ev.position
			_acc = 0.0
			Kit.scroll_moved = false
		else:
			_active = false
	elif event is InputEventScreenDrag and _active:
		var dr := event as InputEventScreenDrag
		_acc += absf(dr.relative.y)
		if _acc > 14.0:
			Kit.scroll_moved = true
		if Kit.scroll_moved:
			scroll_vertical -= int(dr.relative.y * (size.y / maxf(rect.size.y, 1.0)))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_active = rect.has_point(mb.position)
			_start = mb.position
			_acc = 0.0
			Kit.scroll_moved = false
		else:
			_active = false
	elif event is InputEventMouseMotion and _active and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		var mm := event as InputEventMouseMotion
		_acc += absf(mm.relative.y)
		if _acc > 14.0:
			Kit.scroll_moved = true
		if Kit.scroll_moved:
			scroll_vertical -= int(mm.relative.y)

const Kit := preload("res://game/ui/ui_kit.gd")
