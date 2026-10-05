extends SceneTree
const Profile := preload("res://game/data/profile.gd")
func _init() -> void:
	var profile = Profile.new()
	profile.give("pickup")
	var cfg := {"type": "drift", "track": "drift", "ai": 0, "sky": "day", "car": "pickup", "state": profile.car(), "seed": 7, "back": "home", "time": 1800, "sim": "mid"}
	var r = load("res://game/race.tscn").instantiate()
	r.cfg = cfg
	r.profile = profile
	root.add_child(r)
	for f in 120:
		await process_frame
	r.controls.process_mode = Node.PROCESS_MODE_DISABLED
	var ph = r.cars[0].phys
	print("fx ", r.fx != null, " mk0 ", r.fx._mk, " state ", r.session.state if r.session != null else "-")
	for f in 600:
		await process_frame
		r.controls.gas = 1.0
		r.controls.steer = 0.8 if f > 150 else 0.0
		r.controls.hb = f > 200 and f < 260
		if f % 100 == 0:
			var spd := Vector2(ph.vx, ph.vz).length()
			var snap = r.cars[0].snap
			print(f, " v ", snappedf(spd,0.1), " mk ", r.fx._mk, " wheelfx0 ", snap.wheel_fx.slice(0,8))
	quit()
