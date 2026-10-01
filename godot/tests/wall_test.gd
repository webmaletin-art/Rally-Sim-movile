## Pista solo de camino: un auto que acelera y gira sin parar hacia afuera no pasa del límite lateral (muro de árboles).
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var ok := true
	for cs in [["lake", "asphalt", "t1plus", 1.0], ["forest", "dirt", "pickup", -1.0]]:
		var track = RouteTrack.new(cs[0], cs[1])
		var d: Dictionary = vehicles[cs[2]].duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var car := Car.new(track.make_view(), VehicleParams.from_dict(d), true, true, Color.RED, Color.BLACK)
		var wall: float = track.half_width + track.shoulder + 11.0
		car.wall = wall
		var sp: Array = track.start_pose(0)
		car.place(sp[0], sp[1], sp[2])
		var pv = track.make_view()
		var max_lat := 0.0
		var t := 0.0
		while t < 60.0:
			car.in_throttle = 1.0
			car.in_steer = cs[3] * 0.35 # gira siempre hacia el mismo lado: se va derecho a los árboles
			car.step(1.0 / 120.0)
			t += 1.0 / 120.0
			pv.nearest(car.phys.px, car.phys.pz)
			max_lat = maxf(max_lat, absf(pv.r_lat))
		var good := max_lat <= wall + 0.6
		ok = ok and good
		print("%s %-8s %-7s límite %.1f m · máximo alcanzado %.2f m" % ["OK  " if good else "FALLA", cs[0], cs[2], wall, max_lat])
	quit(0 if ok else 1)
