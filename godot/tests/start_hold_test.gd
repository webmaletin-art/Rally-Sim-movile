## Largada (15/10/2026, reporte del dueño: «los autos vuelven marcha atrás sin empezar las carreras, en cualquier carrera y con cualquier auto»).
## En la cuenta regresiva race.gd tiene al auto con freno a fondo + freno de mano; la caja automática pasaba a reversa (frenado y parado 0,35 s)
## y en reversa el freno es el acelerador → se iba para atrás. Comprueba con TODOS los autos: 4 s en la largada no entra reversa ni se mueve,
## al soltar todo sigue quieto, y la reversa a propósito (frenar parado sin freno de mano) sigue andando.
## Uso: godot --headless --path godot --script res://tests/start_hold_test.gd
extends SceneTree

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var bad_hold: Array = []
	var bad_rev: Array = []
	var h := 1.0 / 120.0
	for vid in vehicles:
		var ph := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict((vehicles[vid] as Dictionary).duplicate()))
		ph.reset(0.0, 0.0, 0.0)
		var moved := 0.0
		var min_gear := 9
		for i in int(4.0 / h): # cuenta regresiva: freno a fondo + freno de mano (race.gd)
			ph.step(h, 0.0, 1.0, 0.0, true, false)
			moved = maxf(moved, Vector2(ph.px, ph.pz).length())
			min_gear = mini(min_gear, ph.gear)
		for i in int(2.0 / h): # «¡YA!» sin tocar nada
			ph.step(h, 0.0, 0.0, 0.0, false, false)
			moved = maxf(moved, Vector2(ph.px, ph.pz).length())
			min_gear = mini(min_gear, ph.gear)
		if min_gear < 0 or moved > 0.3:
			bad_hold.append("%s (marcha mínima %d, se movió %.2f m)" % [vid, min_gear, moved])
		# reversa a propósito: frenar parado sin freno de mano
		var pr := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict((vehicles[vid] as Dictionary).duplicate()))
		pr.reset(0.0, 0.0, 0.0)
		for i in int(3.0 / h):
			pr.step(h, 0.0, 1.0, 0.0, false, false)
		if pr.gear != -1 or pr.vLong > -0.5:
			bad_rev.append("%s (marcha %d, %.1f m/s)" % [vid, pr.gear, pr.vLong])
	_check(bad_hold.is_empty(), "%d autos: en la largada no entran reversa ni se mueven, y al «¡YA!» sin tocar nada siguen quietos %s" % [vehicles.size(), str(bad_hold)])
	_check(bad_rev.is_empty(), "la reversa a propósito (frenar parado) sigue andando %s" % str(bad_rev))
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
