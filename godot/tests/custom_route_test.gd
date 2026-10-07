## Las rutas importadas del generador HTML (marcadas «custom» en routes.json): la IA da una vuelta completa sin salirse ni trabarse.
## Uso: godot --headless --path godot --script res://tests/custom_route_test.gd [-- --id=<ruta>]   (sin --id prueba todas las «custom»)
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			only = a.substr(5)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var fail := false
	var n := 0
	for mid in data["maps"]:
		var mp: Dictionary = data["maps"][mid]
		if not bool(mp.get("custom", false)) or (only != "" and only != str(mid) and only != str(mp.get("route", ""))):
			continue
		n += 1
		for car in ["pickup", "t1plus"]:
			var track = RouteTrack.new(str(mp["route"]), str(mp["mode"]), bool(mp.get("reverse", false)), float(mp.get("hills", 0.0)))
			var d: Dictionary = vehicles[car].duplicate()
			d["camberF"] = -1.0
			d["camberR"] = -0.5
			d["toeF"] = 0.0
			d["toeR"] = 0.1
			d["pressF"] = 30.0
			d["pressR"] = 30.0
			var sp: Array = track.start_pose(0)
			var ph := VehiclePhysics.new(track.make_view(), VehicleParams.from_dict(d))
			ph.reset(sp[0], sp[1], sp[2])
			var drv := AIDriver.new(track.make_view(), ph, {"skill": 0.95})
			var pv = track.make_view()
			var prev: float = pv.arc_pos(ph.px, ph.pz)
			var dist := 0.0
			var max_lat := 0.0
			var t := 0.0
			var lap_t := -1.0
			var h := 1.0 / 120.0
			while t < 900.0:
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
				if lap_t < 0.0 and dist >= track.length:
					lap_t = t
					break
			var good: bool = lap_t > 0.0 and drv.respawns <= 1 and max_lat < track.half_width + track.shoulder + 3.0
			if not good:
				fail = true
			print("%s %-14s %-7s vuelta de %.0f m en %s · máx. desvío %.1f m (camino ±%.1f) · reapariciones %d · vel. media %.0f km/h" % [
				"OK  " if good else "FALLA", mid, car, track.length, ("%.0f s" % lap_t) if lap_t > 0.0 else "NO TERMINÓ", max_lat, track.half_width, drv.respawns, track.length / maxf(lap_t, 1.0) * 3.6])
	print("rutas custom probadas: %d" % n)
	quit(1 if fail else 0)
