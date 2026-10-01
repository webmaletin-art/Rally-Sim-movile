extends RefCounted
## Idiomas. Todo el texto del juego está escrito en español y es la clave de la traducción: cada idioma es un archivo
## game/i18n/<código>.json con {"texto en español": "traducción"}. Los Label y Button se traducen solos (Godot busca el texto
## exacto); para los textos armados con formato se llama Tr.t("… %d …") % valor.
## El idioma sale de Opciones («auto» = el del teléfono; si no está soportado, inglés).

const LANGS := [["auto", "Automático (idioma del teléfono)"], ["es", "Español"], ["en", "English"], ["pt", "Português"], ["fr", "Français"], ["it", "Italiano"], ["de", "Deutsch"]]
const CODES := ["es", "en", "pt", "fr", "it", "de"]

static var current := "es"
static var _loaded: Array = []

## Textos nuevos que no tienen traducción (para el informe de pruebas)
static var missing: Dictionary = {}

static func resolve(setting: String) -> String:
	if setting != "auto" and CODES.has(setting):
		return setting
	var l := OS.get_locale_language()
	return l if CODES.has(l) else "en"

static func setup(profile: RefCounted) -> void:
	set_language(str(profile.setting("lang")) if profile != null else "auto")

static func set_language(setting: String) -> void:
	current = resolve(setting)
	if current != "es" and not _loaded.has(current):
		var path := "res://game/i18n/%s.json" % current
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				var t := Translation.new()
				t.locale = current
				for k in (d as Dictionary):
					if str(d[k]) != "":
						t.add_message(k, str(d[k]))
				TranslationServer.add_translation(t)
		_loaded.append(current)
	TranslationServer.set_locale(current)

## Traduce un texto en español (para los que se arman con formato o se asignan por código)
static func t(s: String) -> String:
	if current == "es":
		return s
	var r := TranslationServer.translate(s)
	if r == s and OS.is_debug_build() and s.length() > 2:
		missing[s] = true
	return r

## Idiomas que se pueden elegir: automático, español y los que tienen al menos la mitad de los textos traducidos
static func available_languages() -> Array:
	var out: Array = [["auto", "Automático"], ["es", "Español"]]
	for l in LANGS:
		var code: String = l[0]
		if code == "auto" or code == "es":
			continue
		if _coverage(code) >= 0.5:
			out.append(l)
	return out

static var _cov := {}
static func _coverage(code: String) -> float:
	if _cov.has(code):
		return _cov[code]
	var path := "res://game/i18n/%s.json" % code
	var c := 0.0
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and (d as Dictionary).size() > 0:
			var n := 0
			for k in (d as Dictionary):
				if str(d[k]) != "":
					n += 1
			c = float(n) / float((d as Dictionary).size())
	_cov[code] = c
	return c

static func lang_name(code: String) -> String:
	for l in LANGS:
		if l[0] == code:
			return str(l[1])
	return code
