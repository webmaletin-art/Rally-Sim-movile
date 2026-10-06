extends RefCounted
## Pantalla del menú para el DIAGNÓSTICO / RENDIMIENTO (MUNDO ABIERTO → DIAGNÓSTICO): explica la herramienta, prende o apaga el botón 📊 del juego y muestra / copia / borra el registro.
## Lo que se mide y cómo se arma el texto está en data/diag_log.gd; el panel que se usa conduciendo es ui/diag_panel.gd. `m` es el menú (menu.gd).

const Kit := preload("res://game/ui/ui_kit.gd")
const DiagLog := preload("res://game/data/diag_log.gd")

var m # menu.gd
var _confirm_clear := false

func build(arg) -> void:
	m.set_title(tr("DIAGNÓSTICO / RENDIMIENTO"))
	DiagLog.ensure_loaded()
	if str(arg) == "log":
		_log_view()
		return
	m.body.add_child(Kit.wrap(tr("Herramienta para descubrir QUÉ sistema del mundo abierto baja los FPS. No prueba nada sola: manejás vos, apagás sistemas (árboles, edificios, autos civiles, vegetación, decoración, peatones), cambiás hora y clima o te movés de lugar, y con 📸 CAPTURAR queda anotado el FPS promedio y mínimo de cada condición, con la diferencia respecto de la prueba anterior."), 15, Kit.TEXT, 300))
	m.body.add_child(Kit.wrap(tr("Dentro del juego tocá el botón 📊 (al costado de la pantalla). Después pegá acá el resultado de 📋 COPIAR TODO."), 14, Kit.MUTED, 300))
	var on: bool = m.profile.setting("diagBtn") != false
	m.body.add_child(m.menu_button("📊 " + tr("Botón de diagnóstico en el juego: %s") % (tr("SÍ") if on else tr("NO")), tr("tocá para cambiar"), func() -> void:
		m.sfx.play("click")
		m.profile.set_setting("diagBtn", not on)
		m.go("diag", null, false), false))
	var sessions := DiagLog.sessions.size()
	m.body.add_child(Kit.label(tr("Sesiones: %d · Pruebas anotadas: %d") % [sessions, DiagLog.test_count()], 16, Kit.GOLD))
	m.body.add_child(m.menu_button("📄 " + tr("VER REGISTRO"), tr("todas las sesiones, en orden"), func() -> void:
		m.sfx.play("click")
		m.go("diag", "log"), true))
	m.body.add_child(m.menu_button("📋 " + tr("COPIAR TODO"), tr("queda en el portapapeles, listo para pegar"), func() -> void:
		_copy()
		m.sfx.play("click"), false))
	_clear_button()

func _copy() -> void:
	var txt := DiagLog.export_text()
	DisplayServer.clipboard_set(txt)
	var f := FileAccess.open("user://informe_diagnostico.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	m.toast(tr("📋 Registro copiado. Pegalo en el chat."))

func _clear_button() -> void:
	var b := Kit.button("🗑 " + (tr("TOCÁ DE NUEVO PARA BORRAR TODO") if _confirm_clear else tr("BORRAR EL REGISTRO")), func() -> void:
		if _confirm_clear:
			_confirm_clear = false
			DiagLog.clear_all()
			m.toast(tr("Registro borrado"))
		else:
			_confirm_clear = true
		m.go("diag", m.screen_arg, false), false, 16, Vector2(0, 48))
	m.body.add_child(b)

func _log_view() -> void:
	m.body.add_child(m.menu_button("📋 " + tr("COPIAR TODO"), "", func() -> void:
		_copy()
		m.sfx.play("click"), true))
	var l := Kit.wrap(DiagLog.export_text(), 12, Kit.TEXT, 300)
	m.body.add_child(l)
