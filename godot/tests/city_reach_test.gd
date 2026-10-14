## Ciudades y pueblos alcanzados (city/city_reach.gd): al llegar manejando a un lugar de la región queda anotado en el perfil y desde ahí se puede aparecer;
## los que no se alcanzaron siguen bloqueados. Uso: godot --headless --path godot --script res://tests/city_reach_test.gd
extends SceneTree

const CityReach := preload("res://game/city/city_reach.gd")
const RegionServices := preload("res://game/region/region_services.gd")

class FakeProfile:
	var s := {}
	func setting(k: String):
		return s.get(k)
	func set_setting(k: String, v) -> void:
		s[k] = v

class FakePhys:
	var px := 0.0
	var pz := 0.0

class FakeCar:
	var phys := FakePhys.new()

class FakeTrack:
	var region = 1

class FakeRace:
	var profile := FakeProfile.new()
	var cfg := {}
	var track := FakeTrack.new()
	var cars: Array = [FakeCar.new()]
	var race_hud = null

var fail := false
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	var list := RegionServices.spawn_list()
	_check(list.size() > 10, "hay lugares para aparecer en la región (%d)" % list.size())
	var race := FakeRace.new()
	var rc := CityReach.new()
	rc.setup(race)
	_check(rc.enabled and rc.places.size() == list.size(), "al principio no se llegó a ninguno (%d por alcanzar)" % rc.places.size())
	rc.update(1.0)
	_check(CityReach.reached_of(race.profile).is_empty(), "en Dream City no se alcanza ninguno")
	var sp: Dictionary = list[0]
	race.cars[0].phys.px = float(sp["x"]) + 120.0
	race.cars[0].phys.pz = float(sp["z"]) - 80.0
	rc.update(1.1)
	var got := CityReach.reached_of(race.profile)
	_check(got.size() == 1 and got.has(str(sp["name"])), "al llegar a «%s» queda anotado (%s)" % [sp["name"], str(got)])
	var rc2 := CityReach.new()
	rc2.setup(race)
	_check(rc2.places.size() == list.size() - 1, "la próxima vez ya no hace falta volver a llegar (%d por alcanzar)" % rc2.places.size())
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
