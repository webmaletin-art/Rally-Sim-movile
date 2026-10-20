extends RefCounted
## Pantallas de la configuración gráfica automática: el aviso (primer arranque y «RECALIBRAR RENDIMIENTO»), el progreso de la calibración y el resultado.
## Son pantallas normales del juego (mismo estilo que el resto), livianas: texto fijo, sin animaciones ni partículas, para no tocar la medición.

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")

static func _modal(parent: Node, width := 880.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # nada de abajo se toca mientras tanto
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := Kit.panel(26)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var col := Kit.vbox(12)
	panel.add_child(col)
	return [dim, col]

## Aviso inicial: «CONFIGURACIÓN AUTOMÁTICA». Devuelve el control (para cerrarlo con queue_free). Al tocar CONTINUAR se cierra y se llama on_continue.
static func notice(parent: Node, on_continue: Callable) -> Control:
	var m := _modal(parent)
	var dim: Control = m[0]
	var col: VBoxContainer = m[1]
	col.add_child(Kit.label("⚙️ " + Tr.t("CONFIGURACIÓN AUTOMÁTICA"), 30, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Kit.wrap(Tr.t("Estamos configurando los gráficos automáticamente para obtener el mejor equilibrio entre calidad visual y rendimiento en este dispositivo."), 19, Kit.TEXT, 800))
	col.add_child(Kit.wrap(Tr.t("El juego analizará el dispositivo y realizará una calibración breve para seleccionar la configuración más adecuada. Es una recomendación: busca un rendimiento estable sin sacrificar calidad visual innecesariamente, y no se modifica sola mientras jugás."), 17, Kit.MUTED, 800))
	col.add_child(Kit.wrap(Tr.t("Podrás cambiarla después desde OPCIONES → GRÁFICOS si preferís más calidad visual o más rendimiento."), 17, Kit.MUTED, 800))
	col.add_child(Kit.button(Tr.t("CONTINUAR"), func() -> void:
		dim.queue_free()
		on_continue.call(), true, 24, Vector2(0, 56)))
	return dim

## Elección a mano de la calidad (BAJA / NORMAL / ALTA / ULTRA): reemplaza a la calibración automática desde el 15/10/2026 (ver autotune.gd → PRESETS).
## `suggested` lleva la marca «sugerida». Al tocar una se cierra y se llama on_pick(i).
## `info` (opcional): texto extra por calidad (los FPS medidos); `measured`: true si `suggested` sale de la medición («recomendada»); `on_measure`: botón «MEDIR AUTOMÁTICAMENTE».
## `order` (opcional): en qué orden se muestran (la recomendada primero, después la 60 FPS y las demás).
static func pick(parent: Node, presets: Array, suggested: int, on_pick: Callable, info := {}, measured := false, on_measure := Callable(), order := []) -> Control:
	var m := _modal(parent, 940.0)
	var dim: Control = m[0]
	var col: VBoxContainer = m[1]
	col.add_child(Kit.label("⚙ " + Tr.t("CALIDAD GRÁFICA"), 30, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Kit.wrap(Tr.t("Elegí la calidad con la que querés jugar. Si el juego anda lento, bajala; si anda fluido, probá una más alta."), 18, Kit.TEXT, 860))
	var grid := Kit.grid(2, 10, 10)
	col.add_child(grid)
	var idx: Array = order if order.size() == presets.size() else range(presets.size())
	for i in idx:
		var P: Dictionary = presets[i]
		var t := Tr.t(str(P["n"]))
		if i == suggested:
			t += "  ★ " + Tr.t("recomendada" if measured else "sugerida")
		var b := Kit.button(t, func() -> void:
			dim.queue_free()
			on_pick.call(i), i == suggested, 22, Vector2(420, 58))
		var box := Kit.vbox(4)
		box.add_child(b)
		box.add_child(Kit.wrap(Tr.t(str(P["d"])), 14, Kit.MUTED, 420))
		if info.has(i):
			box.add_child(Kit.label(str(info[i]), 15, Kit.GOLD if i == suggested else Kit.TEXT))
		grid.add_child(box)
	if measured:
		col.add_child(Kit.wrap(Tr.t("Medimos el rendimiento en el centro de Dream City, el lugar más pesado: la recomendada es la más linda que corre fluida en este teléfono (en el resto del mapa anda mejor); «60 FPS» baja todo hasta correr a 60."), 15, Kit.TEXT, 860))
	col.add_child(Kit.wrap(Tr.t("Podés cambiarla cuando quieras en OPCIONES → GRÁFICOS (también cada opción por separado)."), 15, Kit.MUTED, 860))
	if on_measure.is_valid():
		col.add_child(Kit.button("📏 " + Tr.t("MEDIR AUTOMÁTICAMENTE"), func() -> void:
			dim.queue_free()
			on_measure.call(), false, 17, Vector2(0, 48)))
	return dim

## Progreso de la calibración. Devuelve {root, res, perf, quality, bar} para actualizar los textos
static func progress(parent: Node) -> Dictionary:
	var m := _modal(parent)
	var dim: Control = m[0]
	var col: VBoxContainer = m[1]
	col.add_child(Kit.label("⚙️ " + Tr.t("OPTIMIZANDO RENDIMIENTO..."), 30, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Kit.wrap(Tr.t("Analizando el dispositivo y ajustando los gráficos."), 19, Kit.TEXT, 800))
	var res := Kit.label(Tr.t("Resolución: detectando..."), 20, Kit.TEXT)
	var perf := Kit.label(Tr.t("Rendimiento: calibrando..."), 20, Kit.TEXT)
	var qual := Kit.label(Tr.t("Calidad visual: ajustando..."), 20, Kit.TEXT)
	col.add_child(res)
	col.add_child(perf)
	col.add_child(qual)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	col.add_child(bar)
	col.add_child(Kit.wrap(Tr.t("No cierres el juego durante este proceso."), 16, Kit.MUTED, 800))
	return {"root": dim, "res": res, "perf": perf, "quality": qual, "bar": bar}

## Resultado: «CONFIGURACIÓN COMPLETADA». summary = una línea con lo elegido. Al tocar JUGAR se llama on_play.
static func done(parent: Node, summary: String, on_play: Callable) -> Control:
	var m := _modal(parent)
	var dim: Control = m[0]
	var col: VBoxContainer = m[1]
	col.add_child(Kit.label("✓ " + Tr.t("CONFIGURACIÓN COMPLETADA"), 30, Kit.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Kit.wrap(Tr.t("Se seleccionó automáticamente la configuración recomendada para este dispositivo."), 19, Kit.TEXT, 800))
	col.add_child(Kit.wrap(summary, 17, Kit.GOLD, 800))
	col.add_child(Kit.wrap(Tr.t("La configuración quedará fija durante el juego. Podrás modificarla desde OPCIONES → GRÁFICOS."), 17, Kit.MUTED, 800))
	col.add_child(Kit.button(Tr.t("JUGAR"), func() -> void:
		dim.queue_free()
		on_play.call(), true, 24, Vector2(0, 56)))
	return dim
