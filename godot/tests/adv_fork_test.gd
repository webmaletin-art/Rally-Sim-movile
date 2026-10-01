## Modo aventura: en cada bifurcación un auto puede tomar el ramal (la física pasa al otro camino sin chocar contra un muro
## invisible) y también seguir por el principal; muestra cuánto tarda cada opción entre la separación y la unión.
extends SceneTree

const AdvTrack := preload("res://game/adventure/adv_track.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const CarBuild := preload("res://game/data/car_build.gd")

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var ok := true
	for si in AdvRoute.stage_count():
		var main = AdvTrack.new(si)
		if main.forks.is_empty():
			continue
		var alt = AdvTrack.new(si, int(main.forks[0]["fork"]))
		main.cross_clear(alt)
		alt.cross_clear(main)
		var P: Dictionary = CarBuild.build_params(vehicles[AdvData.CAR], AdvData.car_state(AdvData.default_state()), {"abs": true, "tc": 30.0, "stab": 20.0})
		for take_alt in [false, true]:
			var view = main.make_view()
			view.link_other(alt.make_view())
			var car := Car.new(view, VehicleParams.from_dict(P), true, true, Color.RED, Color.BLACK)
			car.wall = 1.0
			var a0: int = int(main.forks[0]["split"]) - 60
			var pose: Array = main.pose_at(a0, 1.6)
			car.place(pose[0], pose[1], pose[2])
			var drv_track = alt if take_alt else main
			car.driver = AIDriver.new(drv_track.make_view(), car.phys, {"skill": 0.9, "lane": 0.0})
			var t := 0.0
			var h := 1.0 / 120.0
			var switched := false
			var hits := 0
			var fin := -1.0
			var t0 := -1.0
			while t < 120.0:
				car.step(h)
				if car.wall_hit > 2.0:
					hits += 1
				car.wall_hit = 0.0
				t += h
				if int(t * 120.0) % 6 == 0:
					if int(view.variant) >= 0:
						switched = true
					var s: float = float(view.cum[view.r_idx])
					var split_s: float = float(view.cum[int(main.forks[0]["split"])])
					if t0 < 0.0 and s >= split_s:
						t0 = t
					# llegó a la unión (contando en la variante en la que esté)
					var join_i: int = int(view.join) if int(view.variant) >= 0 else int(main.forks[0]["join"])
					if s >= float(view.cum[mini(join_i + 20, int(view.n) - 1)]):
						fin = t
						break
			var good: bool = fin > 0.0 and (switched or not take_alt) and hits < 4
			if not good:
				ok = false
			print("etapa %2d %-24s %s: %s · pasó al ramal %s · golpes %d %s" % [si + 1, AdvRoute.STAGES[si]["name"], "RAMAL    " if take_alt else "PRINCIPAL", ("%.1f s" % (fin - t0)) if fin > 0.0 else "NO LLEGÓ", "sí" if switched else "no", hits, "" if good else "✗"])
	print("OK" if ok else "FALLA")
	quit(0 if ok else 1)
