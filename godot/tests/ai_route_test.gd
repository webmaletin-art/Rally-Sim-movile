## La IA (js/ai.js portada) da una vuelta completa a cada pista por curva sin salirse ni trabarse.
## Uso: godot --headless --path godot --script res://tests/ai_route_test.gd
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

## asphaltLong con el t1plus y el genesis: la IA de la versión HTML también se sale ahí (idéntico resultado, ver tools/godot/ai_reference.mjs); queda anotado para mejorar
const CASES := [["forest", "dirt", "t1plus"], ["quarry", "dirt", "pickup"], ["lake", "asphalt", "t1plus"], ["asphaltLong", "asphalt", "pickup"], ["descent", "asphalt", "t1plus"], ["lake", "asphalt", "genesis"], ["forest", "dirt", "truck"]]

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var fail := false
	for cs in CASES:
		var track = RouteTrack.new(cs[0], cs[1])
		var d: Dictionary = vehicles[cs[2]].duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var view = track.make_view()
		var sp: Array = track.start_pose(0)
		var ph := VehiclePhysics.new(view, VehicleParams.from_dict(d))
		ph.reset(sp[0], sp[1], sp[2])
		var drv := AIDriver.new(track.make_view(), ph, {"skill": 0.95})
		var pv = track.make_view()
		var prev: float = pv.arc_pos(ph.px, ph.pz)
		var dist := 0.0
		var max_lat := 0.0
		var off := 0
		var t := 0.0
		var lap_t := -1.0
		var h := 1.0 / 120.0
		while t < 420.0:
			var c: Vector3 = drv.update(ph, h)
			ph.step(h, c.x, c.y, c.z, false, drv.nitro)
			t += h
			var a: float = pv.arc_pos(ph.px, ph.pz)
			var da: float = a - prev
			if da < -track.length * 0.5:
				da += track.length
			elif da > track.length * 0.5:
				da -= track.length
			dist += da
			prev = a
			max_lat = maxf(max_lat, absf(pv.r_lat))
			if absf(pv.r_lat) > track.half_width:
				off += 1
			if lap_t < 0.0 and dist >= track.length:
				lap_t = t
				break
		var good: bool = lap_t > 0.0 and drv.respawns <= 1 and max_lat < track.half_width + track.shoulder + 3.0
		if not good:
			fail = true
		print("%s %-12s %-8s vuelta de %.0f m en %s · máx. desvío %.1f m (camino ±%.1f) · pasos fuera del camino %d · reapariciones %d · vel. media %.0f km/h" % [
			"OK  " if good else "FALLA", cs[0], cs[2], track.length, ("%.0f s" % lap_t) if lap_t > 0.0 else "NO TERMINÓ", max_lat, track.half_width, off, drv.respawns,
			track.length / maxf(lap_t, 1.0) * 3.6])
	quit(1 if fail else 0)
