## Idiomas: cambiar de idioma en una sesión (inglés → español → portugués) tiene que dejar los textos en el idioma elegido, no en el anterior.
## Antes, al volver a Español quedaba cargado el inglés y el idioma de respaldo («en») seguía traduciendo todo: la pantalla seguía en inglés hasta reiniciar.
## Uso: godot --headless --path godot --script res://tests/language_test.gd
extends SceneTree

const Tr := preload("res://game/i18n/tr.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var key := "APARECER AQUÍ"
	Tr.set_language("en")
	check(tr(key) == "SPAWN HERE" and Tr.t(key) == "SPAWN HERE", "inglés: «%s» → «%s»" % [key, tr(key)])
	Tr.set_language("es")
	check(tr(key) == key and Tr.t(key) == key, "de vuelta en español el texto queda en español (%s)" % tr(key))
	Tr.set_language("pt")
	check(tr(key) != key and tr(key) != "SPAWN HERE", "portugués: «%s»" % tr(key))
	Tr.set_language("es")
	check(tr(key) == key, "otra vez español")
	Tr.set_language("en")
	check(tr(key) == "SPAWN HERE", "y otra vez inglés (se vuelve a cargar)")
	check(Tr.resolve("auto") != "" and Tr.resolve("de") == "de" and Tr.resolve("klingon") != "klingon", "«automático» siempre da un idioma que existe")
	print("LANGUAGE_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)
