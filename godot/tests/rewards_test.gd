extends SceneTree
## Medallas, premios y puertas de las copas. Los premios son los de la economía justa de 1.0 (bases de las copas más bajas y 1°100 % · 2°60 % · 3°40 % · 4°20 %); las medallas y puertas siguen la versión HTML.

const Rewards := preload("res://game/data/rewards.gd")

var fails := 0

func check(name: String, got, want) -> void:
	if str(got) == str(want):
		print("OK    ", name, " = ", got)
	else:
		fails += 1
		print("FALLA ", name, " = ", got, " (esperado ", want, ")")

func _init() -> void:
	var d1 := Rewards.event_by_id("d1")
	var d2 := Rewards.event_by_id("d2")
	var d7 := Rewards.event_by_id("d7")
	var debut := Rewards.tier_by_id("debut")
	check("medalla d1 39 s (oro)", Rewards.medal_for(d1, 39.0), 3)
	check("medalla d1 44 s (plata)", Rewards.medal_for(d1, 44.0), 2)
	check("medalla d1 49 s (bronce)", Rewards.medal_for(d1, 49.0), 1)
	check("medalla d1 50 s", Rewards.medal_for(d1, 50.0), 0)
	check("medalla carrera 1°", Rewards.medal_for(d2, 1.0), 3)
	check("medalla carrera 4°", Rewards.medal_for(d2, 4.0), 0)
	check("premio d2 oro", Rewards.reward_for(d2, 3, debut), {"cr": 2000, "xp": 637})
	check("premio d2 plata", Rewards.reward_for(d2, 2, debut), {"cr": 1200, "xp": 490})
	check("premio final oro", Rewards.reward_for(d7, 3, debut), {"cr": 3200, "xp": 955})
	check("d1 jugable", Rewards.playable(d1), true)
	check("d3 (estacionar) no jugable", Rewards.playable(Rewards.event_by_id("d3")), false)
	check("d5 (drift en la plaza) jugable", Rewards.playable(Rewards.event_by_id("d5")), true)
	check("estrellas copa nacional (5 eventos jugables en la copa debut)", Rewards.stars_needed(Rewards.tier_by_id("nacional")), 10)
	print("FALLAS: ", fails)
	quit(1 if fails > 0 else 0)
