extends RefCounted
## Reglas de World Life (data/world_life.json). Se lee UNA sola vez y queda en memoria; nunca se relee por cuadro.

const PATH := "res://game/data/world_life.json"
static var _cfg: Dictionary = {}

static func get_config() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = d if d is Dictionary else {"version": 1}
	return _cfg

static func version() -> int:
	return int(get_config().get("version", 1))

static func profile_rules(name: String) -> Dictionary:
	var p: Dictionary = get_config().get("profiles", {})
	return p.get(name, p.get("MEDIUM", {}))

## Perfil de rendimiento según la calidad del teléfono (LOW · MEDIUM · HIGH)
static func profile_for(profile: RefCounted) -> String:
	if profile == null:
		return "MEDIUM"
	var q := str(profile.setting("quality"))
	match q:
		"low": return "LOW"
		"high": return "HIGH"
		"auto":
			return ["LOW", "MEDIUM", "HIGH"][clampi(int(profile.setting("autoTier")), 0, 2)]
	return "MEDIUM"
