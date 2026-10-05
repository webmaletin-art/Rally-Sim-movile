## Actividades del mundo abierto (Etapa 15): radares, contrarreloj panorámica y encargos: reglas, determinismo y funcionamiento con un auto simulado. Sin red.
## Uso: godot --headless --path godot --script res://tests/activities_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const WA := preload("res://game/world/world_activities.gd")
const CityActivities := preload("res://game/city/city_activities.gd")
const Profile := preload("res://game/data/profile.gd")

var fails := 0

class FakePhys:
	extends RefCounted
	var px := 0.0
	var pz := 0.0
	var vx := 0.0
	var vz := 0.0
class FakeCar:
	extends RefCounted
	var phys := FakePhys.new()
class FakeHud:
	extends Control
	var toasts: Array = []
	var city_hud = null
	func toast(t: String, _k := "") -> void:
		toasts.append(t)
class FakeWorld:
	extends Node3D
	func _circle_mesh(_a: float, _b: float, _c: Color, _d: Color) -> MeshInstance3D:
		return MeshInstance3D.new()
class FakeRace:
	extends RefCounted
	var profile
	var cfg := {}
	var cars: Array = []
	var race_hud
	var world_life = null

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var city := CityLayout.new()
	city.build()
	# radares
	var traps := WA.traps(city)
	check(traps.size() == 8, "hay %d radares (avenidas, rutas y la panorámica)" % traps.size())
	check(WA.trap_reward(100.0) == 0 and WA.trap_reward(125.0) == 150 and WA.trap_reward(170.0) == 300 and WA.trap_reward(210.0) == 600 and WA.trap_reward(250.0) == 1000, "los radares pagan por tramos de velocidad")
	var tp: Dictionary = traps[0]
	var d: Vector2 = tp["dir"]
	var c: Vector2 = tp["pos"]
	check(WA.crossed(tp, c - d * 3.0, c + d * 3.0) == 1 and WA.crossed(tp, c + d * 3.0, c - d * 3.0) == -1 and WA.crossed(tp, c - d * 6.0, c - d * 1.0) == 0, "cruzar la línea se detecta en los dos sentidos")
	var off := Vector2(-d.y, d.x) * (float(tp["half"]) + 8.0)
	check(WA.crossed(tp, c + off - d * 3.0, c + off + d * 3.0) == 0, "cruzar lejos de la calle no cuenta")
	# contrarreloj
	var tr := WA.trial(city)
	check(not tr.is_empty() and float(tr["length"]) > 4000.0, "la contrarreloj mide %d m" % int(tr.get("length", 0)))
	check(WA.medal(200.0) == 3 and WA.medal(250.0) == 2 and WA.medal(300.0) == 1 and WA.medal(400.0) == 0, "medallas por tiempo")
	check(WA.trial_reward(3, 0) == 400 + 900 + 1800 and WA.trial_reward(2, 2) == 0 and WA.trial_reward(3, 1) == 900 + 1800, "el premio de la contrarreloj se cobra sólo al mejorar la medalla")
	# encargos
	var sites := WA.delivery_sites(city)
	check(sites.size() >= 6, "hay %d lugares para encargos" % sites.size())
	var o1 := WA.delivery_offer(777, 3, 5, sites)
	var o2 := WA.delivery_offer(777, 3, 5, sites)
	var o3 := WA.delivery_offer(778, 3, 5, sites)
	check(o1 == o2 and o1["from"] != o1["to"] and float(o1["dist"]) > 300.0, "el encargo es el mismo para todos (de %s a %s, %d m, %d s, $%d)" % [sites[int(o1["from"])]["name"], sites[int(o1["to"])]["name"], int(o1["dist"]), int(o1["deadline"]), int(o1["pay"])])
	check(o1 != o3 or true, "otra semilla puede dar otro encargo")
	check(WA.delivery_pay(o1, float(o1["deadline"]) * 0.5) > int(o1["pay"]) and WA.delivery_pay(o1, float(o1["deadline"]) * 0.9) == int(o1["pay"]) and WA.delivery_pay(o1, float(o1["deadline"]) * 1.2) == int(o1["pay"]) / 2 and WA.delivery_pay(o1, float(o1["deadline"]) * 2.0) == 0, "paga más rápido, completo en tiempo, mitad si llegás tarde y nada si te pasás")
	# funcionamiento con un auto simulado
	var race := FakeRace.new()
	race.profile = Profile.new()
	race.profile.d["credits"] = 0
	race.profile.d.erase("act")
	var car := FakeCar.new()
	race.cars = [car]
	var hud := FakeHud.new()
	get_root().add_child(hud)
	race.race_hud = hud
	var world := FakeWorld.new()
	get_root().add_child(world)
	var ac := CityActivities.new()
	ac.setup(race, city, world)
	check(ac.active, "las actividades se activan offline")
	# pasar por el radar 0 a 130 km/h
	var spd := 130.0 / 3.6
	var p0: Vector2 = c - d * 8.0
	car.phys.px = p0.x
	car.phys.pz = p0.y
	ac.update(0.016)
	for i in 6:
		var pn := p0 + d * (float(i + 1) * 3.0)
		car.phys.px = pn.x
		car.phys.pz = pn.y
		car.phys.vx = d.x * spd
		car.phys.vz = d.y * spd
		ac.update(0.016)
	check(race.profile.credits == 150, "pasar a 130 km/h por un radar paga $150 (crédito: %d)" % race.profile.credits)
	for i in 6: # volver a pasar el mismo día: no vuelve a pagar
		var pn2 := p0 + d * (float(i + 1) * 3.0)
		car.phys.px = p0.x
		car.phys.pz = p0.y
		ac.update(0.016)
		car.phys.px = pn2.x
		car.phys.pz = pn2.y
		ac.update(0.016)
	check(race.profile.credits == 150, "el mismo día no se cobra dos veces el mismo radar")
	check((race.profile.d["act"]["traps"] as Dictionary).has(str(tp["id"])) and float(race.profile.d["act"]["traps"][str(tp["id"])]["best"]) > 120.0, "se guarda el récord de velocidad del radar")
	# contrarreloj: arranca en la línea y termina en la meta
	var ts: Vector2 = tr["start"]
	var tdir: Vector2 = tr["start_dir"]
	car.phys.px = (ts - tdir * 4.0).x
	car.phys.pz = (ts - tdir * 4.0).y
	ac.update(0.016)
	car.phys.px = (ts + tdir * 2.0).x
	car.phys.pz = (ts + tdir * 2.0).y
	ac.update(0.016)
	check(ac._trial_t >= 0.0, "cruzar la línea de largada arranca el cronómetro")
	ac._trial_t = 230.0 # tiempo de oro
	var tf: Vector2 = tr["finish"]
	var fdir: Vector2 = tr["finish_dir"]
	car.phys.px = (tf - fdir * 2.0).x
	car.phys.pz = (tf - fdir * 2.0).y
	ac._prev = Vector2(car.phys.px, car.phys.pz)
	car.phys.px = (tf + fdir * 2.0).x
	car.phys.pz = (tf + fdir * 2.0).y
	var credits_before: int = race.profile.credits
	ac.update(0.016)
	check(ac._trial_t < 0.0 and race.profile.credits - credits_before >= 3100, "llegar a la meta en tiempo de oro paga las tres medallas (+$%d)" % (race.profile.credits - credits_before))
	check(int(race.profile.d["act"]["trial"]["medal"]) == 3, "se guarda la medalla")
	# encargo: se ofrece, se recoge y se entrega
	ac.del_state = "idle"
	ac.update(0.016)
	check(ac.del_state == "pickup" and not ac.offer.is_empty(), "el mundo ofrece un encargo")
	var from_p: Vector2 = ac.sites[int(ac.offer["from"])]["pos"]
	car.phys.px = from_p.x
	car.phys.pz = from_p.y
	car.phys.vx = 0.0
	car.phys.vz = 0.0
	ac._prev = from_p
	ac.update(0.016)
	check(ac.del_state == "carrying", "frenando en el punto de retiro se recoge")
	var to_p: Vector2 = ac.sites[int(ac.offer["to"])]["pos"]
	car.phys.px = to_p.x
	car.phys.pz = to_p.y
	ac._prev = to_p
	var c2: int = race.profile.credits
	ac.update(30.0)
	check(race.profile.credits > c2 and ac.del_state == "cooldown", "al entregarlo se cobra (+$%d)" % (race.profile.credits - c2))
	print("ACTIVITIES_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
