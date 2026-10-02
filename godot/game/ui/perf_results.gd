extends Control
## Pantalla final de la prueba de rendimiento: el informe completo en texto (se desplaza con el dedo) y los botones
## COPIAR TODO (al portapapeles) y VOLVER. El informe también queda guardado en user://informe_rendimiento.txt.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")

signal exit_pressed

var report := ""
var _copy_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 14)
	add_child(m)
	var v := Kit.vbox(8)
	m.add_child(v)
	v.add_child(Kit.label(tr("PRUEBA TERMINADA"), 26, Kit.ACCENT))
	v.add_child(Kit.label(tr("El informe ya quedó copiado. Pegalo en el chat para que lo analice."), 15, Kit.MUTED))
	var sc := TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var lb := Label.new()
	lb.text = report
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.add_theme_font_size_override("font_size", 13)
	lb.add_theme_color_override("font_color", Kit.TEXT)
	sc.add_child(lb)
	var row := Kit.hbox(8)
	v.add_child(row)
	_copy_btn = Kit.button(tr("📋 COPIAR TODO"), func() -> void:
		DisplayServer.clipboard_set(report)
		_copy_btn.text = tr("✔ COPIADO"), true, 20, Vector2(0, 54))
	_copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_copy_btn)
	var back := Kit.button(tr("VOLVER AL MENÚ"), func() -> void: exit_pressed.emit(), false, 20, Vector2(0, 54))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
