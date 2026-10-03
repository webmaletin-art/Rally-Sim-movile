extends RefCounted
## Los nombres de las calles y los lugares de Dream City en el idioma elegido: el generador los arma en español («Avenida 3», «Calle Vieja 2», «Salida 20») y acá se traduce
## la parte de palabras y se deja el número (así el juego no mezcla idiomas).

const Tr := preload("res://game/i18n/tr.gd")

static func t(name: String) -> String:
	if name == "":
		return ""
	var i := name.length()
	while i > 0 and name[i - 1] >= "0" and name[i - 1] <= "9":
		i -= 1
	if i < name.length() and i > 0:
		var base := name.substr(0, i).strip_edges()
		return "%s %s" % [Tr.t(base), name.substr(i)]
	if name.begins_with("Entrada "):
		return "%s %s" % [Tr.t("Entrada"), Tr.t(name.substr(8))]
	return Tr.t(name)
