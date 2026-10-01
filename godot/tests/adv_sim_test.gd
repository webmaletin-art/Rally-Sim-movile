## Modo aventura: cada etapa se puede recorrer entera con la IA (sin quedar trabada) y dura lo pensado.
## Corre la IA con el auto del jugador (ritmo de un buen piloto) y el rival de la etapa a fondo, y muestra los tiempos.
## Uso: godot --headless --script res://tests/adv_sim_test.gd [-- --stages=0,1,2]
extends SceneTree

const AdvTrack := preload("res://game/adventure/adv_track.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const Adventure := preload("res://game/adventure/adventure.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var stages: Array = range(AdvRoute.stage_count())
	var pskill := 0.93
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stages="):
			stages = []
			for s in a.substr(9).split(","):
				stages.append(int(s))
		elif a.begins_with("--pskill="):
			pskill = float(a.substr(9))
	var ok := true
	var total := 0.0
	for si in stages:
		var t0 := Time.get_ticks_msec()
		var track = AdvTrack.new(si)
		var st := AdvData.default_state()
		var P: Dictionary = CarBuild.build_params(vehicles[AdvData.CAR], AdvData.car_state(st), {"abs": true, "tc": 30.0, "stab": 20.0})
		var S: Dictionary = AdvRoute.STAGES[si]
		var R0: Dictionary = S["rival"]
		var RP: Dictionary = CarBuild.build_params(vehicles[str(R0["car"])], Profile.new_car_state(str(R0["car"])), {"abs": true, "tc": 40.0, "stab": 30.0})
		RP["powerScale"] = float(RP["powerScale"]) * float(R0.get("power", 1.0))
		RP["gripFront"] = float(RP["gripFront"]) * float(R0.get("grip", 1.0))
		RP["gripRear"] = float(RP["gripRear"]) * float(R0.get("grip", 1.0))
		RP["vGov"] = 0.0
		var cars: Array = []
		var specs := [[P, pskill, 1.6], [RP, float(R0["skill"]), -1.6]]
		for k in 2:
			var c := Car.new(track.make_view(), VehicleParams.from_dict(specs[k][0]), k == 0, true, Color.RED, Color.BLACK)
			c.wall = 1.0
			var pose: Array = track.pose_at(track.i_start + 4 + k * 10, float(specs[k][2]))
			c.place(pose[0], pose[1], pose[2])
			c.driver = AIDriver.new(track.make_view(), c.phys, {"skill": float(specs[k][1]), "lane": float(specs[k][2])})
			cars.append(c)
		var others: Array = [cars[0].phys, cars[1].phys]
		for c in cars:
			c.driver.others = others
		var s_end: float = track.cum[track.i_end]
		var fin := [-1.0, -1.0]
		var v := [track.make_view(), track.make_view()]
		var t := 0.0
		var h := 1.0 / 120.0
		var vmax := [0.0, 0.0]
		while t < 900.0 and (fin[0] < 0.0 or fin[1] < 0.0):
			for k in 2:
				if fin[k] >= 0.0:
					continue
				cars[k].step(h)
			t += h
			if int(t * 120.0) % 12 == 0:
				for k in 2:
					if fin[k] >= 0.0:
						continue
					var ph = cars[k].phys
					v[k].nearest(ph.px, ph.pz)
					vmax[k] = maxf(vmax[k], sqrt(ph.vx * ph.vx + ph.vz * ph.vz) * 3.6)
					if float(v[k].cum[v[k].r_idx]) >= s_end:
						fin[k] = t
		var rs: Array = [cars[0].driver.respawns, cars[1].driver.respawns]
		var line := "etapa %2d %-26s %.1f km · jugador IA %s (máx %d km/h, %d reapar.) · %s %s (máx %d, %d reapar.) · %d s de cálculo" % [
			si + 1, S["name"], track.stage_len / 1000.0, _fmt(fin[0]), int(vmax[0]), rs[0], str(R0["name"]).substr(0, 14), _fmt(fin[1]), int(vmax[1]), rs[1], (Time.get_ticks_msec() - t0) / 1000]
		if fin[0] < 0.0 or fin[1] < 0.0 or int(rs[0]) > 2:
			ok = false
			line += "  ✗"
		total += maxf(fin[0], 0.0)
		print(line)
	print("total jugador IA: %.1f min" % (total / 60.0))
	print("OK" if ok else "FALLA")
	quit(0 if ok else 1)

func _fmt(t: float) -> String:
	if t < 0.0:
		return "NO TERMINÓ"
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]
