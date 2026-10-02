extends "res://game/track/route_track.gd"
## Paper Race: pista angosta de ruta y tierra (cinco tramos alternados) para el mundo de papel. Es una RouteTrack común (misma física,
## IA y sesiones); solo agrega la superficie del camino por tramo. El dibujo lo hace paper_world.gd.

## [desde, hasta (fracción de la vuelta), superficie: 0 asfalto · 1 tierra]
const SECTIONS := [[0.0, 0.16, 0], [0.16, 0.42, 1], [0.42, 0.58, 0], [0.58, 0.84, 1], [0.84, 1.0, 0]]

func _init(p_route := "", p_mode := "asphalt", reverse := false, p_hills := 0.0) -> void:
	super(p_route, p_mode, reverse, p_hills)
	if n <= 0:
		return
	road_surf.resize(n)
	surf_mu.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var sf := 0
		for s in SECTIONS:
			if t >= float(s[0]) and t < float(s[1]):
				sf = int(s[2])
		road_surf[i] = sf
		surf_mu[i] = 1.0 if sf == 0 else 0.72
