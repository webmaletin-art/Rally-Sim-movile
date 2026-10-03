extends "res://game/track/dream_world.gd"
## Los mundos fantasía planetarios, todos en papel: Marte (Monte Olimpo), la Luna (Mar de la Tranquilidad) y el Anillo de Júpiter. Usa el
## mismo armado que el Vórtice de Ensueño (camino peraltado, meseta plana a los costados con su faldón de capas, plantas en MultiMesh por
## tramos) pero con otros colores, otras piezas de papel (rocas, mesetas, cristales, módulo lunar, estaciones…), pórticos, cráteres pintados
## en el suelo, objetos flotando (anillo) y su propio cielo (space_sky.gdshader) con planeta, lunas y estrellas.

const SPACE_SKY := preload("res://game/fx/space_sky.gdshader")
const SPACE_SEA := preload("res://game/fx/space_sea.gdshader")

const SUNS := {"mars": Vector3(-0.45, 0.42, 0.78), "moon": Vector3(0.50, 0.38, 0.78), "ring": Vector3(0.62, 0.30, 0.72)}
const PLANETS := {"moon": Vector3(-0.55, 0.40, 0.55), "ring": Vector3(-0.62, -0.02, 0.55)} # hacia el planeta grande (la Tierra, Júpiter)

# Cada mundo: temas de color (ground = tres colores de banda del suelo · una lista de piezas por capa), zonas de la vuelta, capas de piezas
# [tasa por fila (~7 m) y lado, distancia mínima y máxima al borde, capa, escala mín, escala máx, distancia de visibilidad], colores del camino,
# faldón, pórticos (fracción de la vuelta), objetos de escenografía {t, lat, id, s} y objetos flotantes.
const DEFS := {
	"mars": {
		"themes": [
			{"ground": [Color(0.86, 0.50, 0.32), Color(0.78, 0.40, 0.26), Color(0.92, 0.62, 0.42)],
				"low": ["m_roca_1", "m_roca_2", "m_liquen", "m_lajas", "m_roca_3", "m_liquen"], "mid": ["m_roca_1", "m_roca_2", "m_roca_3", "m_roca_4", "m_rocas", "m_lajas"],
				"tall": ["m_picos", "m_roca_grande", "m_mesa_baja"], "huge": ["m_mesa", "m_picos_altos", "m_polvo", "m_arco"], "fill": ["m_cactus", "m_cactus2", "m_liquen", "m_cristal_rojo"]},
			{"ground": [Color(0.90, 0.66, 0.40), Color(0.82, 0.52, 0.30), Color(0.95, 0.76, 0.52)],
				"low": ["m_roca_4", "m_roca_2", "m_liquen", "m_lajas", "m_roca_1"], "mid": ["m_roca_4", "m_roca_2", "m_roca_1", "m_rocas", "m_lajas"],
				"tall": ["m_picos", "m_mesa_baja", "m_roca_grande"], "huge": ["m_mesa", "m_polvo", "m_arco", "m_picos_altos"], "fill": ["m_cristal_rojo", "m_cactus", "m_liquen"]},
			{"ground": [Color(0.52, 0.30, 0.26), Color(0.42, 0.24, 0.24), Color(0.64, 0.40, 0.34)],
				"low": ["m_roca_3", "m_roca_1", "m_lajas", "m_roca_3"], "mid": ["m_roca_3", "m_roca_1", "m_rocas", "m_roca_2"],
				"tall": ["m_picos", "m_roca_grande", "m_picos"], "huge": ["m_picos_altos", "m_mesa", "m_picos_altos"], "fill": ["m_cristal_rojo", "m_cristal_violeta", "m_liquen"]},
			{"ground": [Color(0.60, 0.40, 0.52), Color(0.46, 0.30, 0.46), Color(0.72, 0.52, 0.60)],
				"low": ["m_roca_3", "m_roca_2", "m_liquen", "m_lajas"], "mid": ["m_roca_3", "m_roca_2", "m_rocas", "m_roca_4"],
				"tall": ["m_picos", "m_mesa_baja", "m_roca_grande"], "huge": ["m_picos_altos", "m_arco", "m_mesa"], "fill": ["m_cristal_violeta", "m_cactus2", "m_cristal_violeta", "m_liquen"]},
			{"ground": [Color(0.80, 0.36, 0.24), Color(0.66, 0.28, 0.22), Color(0.90, 0.52, 0.36)],
				"low": ["m_roca_1", "m_roca_3", "m_lajas", "m_roca_2"], "mid": ["m_roca_1", "m_roca_3", "m_rocas", "m_roca_2"],
				"tall": ["m_picos", "m_mesa_baja", "m_picos"], "huge": ["m_mesa", "m_arco", "m_picos_altos", "m_mesa"], "fill": ["m_cristal_rojo", "m_cactus", "m_cactus2"]},
		],
		"zones": [[0.0, 0], [0.16, 1], [0.34, 2], [0.50, 3], [0.64, 1], [0.80, 4]],
		"layers": [[10.0, 0.6, 7.0, "low", 0.45, 1.0, 120.0], [3.0, 1.5, 14.0, "mid", 0.55, 1.15, 240.0], [1.0, 9.0, 36.0, "tall", 0.8, 1.5, 420.0],
			[0.16, 14.0, 60.0, "huge", 0.9, 1.5, 760.0], [1.4, 1.5, 16.0, "fill", 1.0, 1.9, 200.0], [2.0, 12.0, 60.0, "mid", 1.6, 2.8, 380.0]],
		"strata": [Color(0.85, 0.55, 0.38), Color(0.70, 0.38, 0.28), Color(0.52, 0.28, 0.24), Color(0.34, 0.20, 0.22)],
		"asph": Color(0.46, 0.38, 0.36), "curb_a": Color(0.97, 0.46, 0.18), "curb_b": Color(0.98, 0.93, 0.86), "shoulder": Color(0.93, 0.68, 0.48), "mid_line": Color(1.0, 0.86, 0.45),
		"porticos": [[0.0, "x_portico_marte"], [0.20, "x_portico_marte"], [0.42, "x_portico_marte"], [0.50, "x_portico_marte"], [0.66, "x_portico_marte"], [0.84, "x_portico_marte"]],
		"props": [
			{"t": 0.006, "lat": 13.5, "id": "m_bandera", "s": 1.4}, {"t": 0.006, "lat": -13.5, "id": "m_bandera", "s": 1.4},
			{"t": 0.012, "lat": 19.0, "id": "m_antena", "s": 1.3}, {"t": 0.016, "lat": -19.0, "id": "m_cupula", "s": 1.5}, {"t": 0.022, "lat": -26.0, "id": "m_paneles", "s": 1.5},
			{"t": 0.030, "lat": 17.0, "id": "m_rover", "s": 1.4}, {"t": 0.050, "lat": 21.0, "id": "m_cupula", "s": 1.3}, {"t": 0.34, "lat": 18.0, "id": "m_antena", "s": 1.4},
			{"t": 0.52, "lat": -18.0, "id": "m_rover", "s": 1.3}, {"t": 0.52, "lat": 22.0, "id": "m_bandera", "s": 1.6}, {"t": 0.74, "lat": 17.0, "id": "m_paneles", "s": 1.4},
			{"t": 0.74, "lat": -21.0, "id": "m_cupula", "s": 1.4}, {"t": 0.93, "lat": 15.0, "id": "m_antena", "s": 1.3},
		],
		"craters": 0.35, "glint": 0.25, "sea": true, "seed": 5101,
	},
	"moon": {
		"themes": [
			{"ground": [Color(0.74, 0.74, 0.76), Color(0.66, 0.66, 0.70), Color(0.84, 0.84, 0.86)],
				"low": ["l_roca_1", "l_roca_2", "l_lajas", "l_roca_4", "l_roca_3"], "mid": ["l_rocas", "l_roca_1", "l_roca_2", "l_roca_4", "l_roca_3"],
				"tall": ["l_cresta", "l_roca_grande", "l_borde_crater"], "huge": ["l_cresta", "l_borde_crater", "l_roca_grande"], "fill": ["l_cristal", "l_lajas", "l_roca_4"]},
			{"ground": [Color(0.58, 0.58, 0.62), Color(0.50, 0.50, 0.56), Color(0.68, 0.68, 0.72)],
				"low": ["l_roca_3", "l_roca_1", "l_lajas", "l_roca_2"], "mid": ["l_rocas", "l_roca_3", "l_roca_1", "l_roca_2"],
				"tall": ["l_cresta", "l_roca_grande"], "huge": ["l_cresta", "l_borde_crater"], "fill": ["l_lajas", "l_roca_3", "l_cristal"]},
			{"ground": [Color(0.40, 0.40, 0.46), Color(0.34, 0.34, 0.42), Color(0.50, 0.50, 0.58)],
				"low": ["l_roca_3", "l_roca_1", "l_lajas"], "mid": ["l_rocas", "l_roca_3", "l_roca_1"],
				"tall": ["l_roca_grande", "l_cresta"], "huge": ["l_cresta", "l_borde_crater"], "fill": ["l_cristal", "l_roca_3"]},
			{"ground": [Color(0.62, 0.66, 0.76), Color(0.52, 0.58, 0.72), Color(0.74, 0.78, 0.88)],
				"low": ["l_roca_2", "l_roca_4", "l_lajas", "l_roca_1"], "mid": ["l_rocas", "l_roca_2", "l_roca_4", "l_roca_1"],
				"tall": ["l_cresta", "l_roca_grande", "l_borde_crater"], "huge": ["l_cresta", "l_roca_grande"], "fill": ["l_cristal", "l_cristal", "l_lajas"]},
		],
		"zones": [[0.0, 0], [0.18, 1], [0.38, 2], [0.58, 3], [0.78, 1]],
		"layers": [[9.0, 0.6, 7.0, "low", 0.45, 1.05, 120.0], [2.6, 1.5, 14.0, "mid", 0.55, 1.2, 240.0], [0.8, 9.0, 36.0, "tall", 0.8, 1.6, 420.0],
			[0.14, 14.0, 60.0, "huge", 0.9, 1.6, 760.0], [0.8, 1.5, 16.0, "fill", 1.0, 1.9, 200.0], [1.6, 12.0, 60.0, "mid", 1.6, 2.8, 380.0]],
		"strata": [Color(0.72, 0.72, 0.76), Color(0.55, 0.55, 0.60), Color(0.40, 0.40, 0.46), Color(0.26, 0.26, 0.32)],
		"asph": Color(0.34, 0.34, 0.40), "curb_a": Color(0.98, 0.55, 0.16), "curb_b": Color(0.97, 0.97, 0.98), "shoulder": Color(0.80, 0.80, 0.84), "mid_line": Color(0.96, 0.96, 1.0),
		"porticos": [[0.0, "x_portico_luna"], [0.17, "x_portico_luna"], [0.36, "x_portico_luna"], [0.55, "x_portico_luna"], [0.76, "x_portico_luna"]],
		"props": [
			{"t": 0.006, "lat": 13.5, "id": "l_bandera", "s": 1.4}, {"t": 0.006, "lat": -13.5, "id": "l_bandera", "s": 1.4}, {"t": 0.016, "lat": -24.0, "id": "l_modulo", "s": 1.6},
			{"t": 0.020, "lat": 15.0, "id": "l_astronauta", "s": 1.5}, {"t": 0.036, "lat": 19.0, "id": "l_rover", "s": 1.4}, {"t": 0.30, "lat": 20.0, "id": "l_cupula", "s": 1.6},
			{"t": 0.30, "lat": -19.0, "id": "l_antena", "s": 1.4}, {"t": 0.31, "lat": 26.0, "id": "l_paneles", "s": 1.5}, {"t": 0.62, "lat": -18.0, "id": "l_rover", "s": 1.4},
			{"t": 0.62, "lat": 14.5, "id": "l_astronauta", "s": 1.5}, {"t": 0.63, "lat": -22.0, "id": "l_bandera", "s": 1.6}, {"t": 0.88, "lat": 21.0, "id": "l_modulo", "s": 1.5},
			{"t": 0.89, "lat": -17.0, "id": "l_paneles", "s": 1.4},
		],
		"craters": 0.55, "glint": 0.45, "sea": false, "seed": 5202,
	},
	"ring": {
		"themes": [
			{"ground": [Color(0.90, 0.95, 1.0), Color(0.78, 0.88, 0.98), Color(0.96, 0.97, 1.0)],
				"low": ["r_hielo_bajo", "r_hielo_2", "r_hielo_bajo", "r_roca_gris"], "mid": ["r_hielo_1", "r_hielo_2", "r_roca_gris", "r_cristal_dorado"],
				"tall": ["r_cristal_cian", "r_hielo_3", "r_cristal_magenta"], "huge": ["r_cristal_gigante", "r_hielo_3"], "fill": ["r_cristal_cian", "r_cristal_dorado", "r_hielo_1"]},
			{"ground": [Color(0.90, 0.80, 0.64), Color(0.78, 0.66, 0.50), Color(0.96, 0.88, 0.74)],
				"low": ["r_roca_ocre", "r_hielo_bajo", "r_roca_gris", "r_hielo_bajo"], "mid": ["r_roca_ocre", "r_roca_gris", "r_hielo_1", "r_cristal_dorado"],
				"tall": ["r_cristal_dorado", "r_hielo_3", "r_cristal_cian"], "huge": ["r_cristal_gigante", "r_hielo_3"], "fill": ["r_cristal_dorado", "r_roca_ocre", "r_hielo_1"]},
			{"ground": [Color(0.76, 0.70, 0.92), Color(0.64, 0.58, 0.86), Color(0.88, 0.84, 0.97)],
				"low": ["r_hielo_bajo", "r_hielo_2", "r_roca_gris"], "mid": ["r_hielo_1", "r_hielo_2", "r_cristal_magenta", "r_roca_gris"],
				"tall": ["r_cristal_magenta", "r_hielo_3", "r_cristal_cian"], "huge": ["r_cristal_gigante", "r_hielo_3"], "fill": ["r_cristal_magenta", "r_cristal_cian", "r_hielo_1"]},
			{"ground": [Color(0.96, 0.78, 0.84), Color(0.90, 0.66, 0.78), Color(0.98, 0.88, 0.92)],
				"low": ["r_hielo_bajo", "r_hielo_2", "r_roca_ocre"], "mid": ["r_hielo_1", "r_hielo_2", "r_cristal_magenta", "r_roca_ocre"],
				"tall": ["r_cristal_magenta", "r_hielo_3", "r_cristal_dorado"], "huge": ["r_cristal_gigante", "r_hielo_3"], "fill": ["r_cristal_magenta", "r_cristal_dorado", "r_hielo_1"]},
			{"ground": [Color(0.62, 0.84, 0.95), Color(0.50, 0.74, 0.92), Color(0.78, 0.92, 0.98)],
				"low": ["r_hielo_bajo", "r_hielo_2", "r_hielo_bajo"], "mid": ["r_hielo_1", "r_hielo_2", "r_cristal_cian", "r_roca_gris"],
				"tall": ["r_cristal_cian", "r_hielo_3", "r_cristal_cian"], "huge": ["r_cristal_gigante", "r_hielo_3"], "fill": ["r_cristal_cian", "r_hielo_1", "r_cristal_magenta"]},
		],
		"zones": [[0.0, 0], [0.12, 4], [0.26, 2], [0.40, 3], [0.54, 1], [0.68, 4], [0.82, 0]],
		"layers": [[9.0, 0.6, 7.0, "low", 0.6, 1.2, 120.0], [3.0, 1.5, 14.0, "mid", 0.7, 1.3, 240.0], [1.3, 8.0, 34.0, "tall", 0.8, 1.5, 420.0],
			[0.14, 14.0, 60.0, "huge", 0.9, 1.5, 760.0], [1.3, 1.5, 16.0, "fill", 1.0, 1.9, 200.0], [1.8, 12.0, 60.0, "mid", 1.6, 2.8, 380.0]],
		"strata": [Color(0.90, 0.95, 1.0), Color(0.70, 0.82, 0.95), Color(0.55, 0.60, 0.88), Color(0.30, 0.28, 0.55)],
		"asph": Color(0.30, 0.32, 0.46), "curb_a": Color(0.45, 0.90, 1.0), "curb_b": Color(0.98, 0.98, 1.0), "shoulder": Color(0.92, 0.96, 1.0), "mid_line": Color(0.65, 0.95, 1.0),
		"porticos": [[0.0, "x_portico_anillo"], [0.12, "x_portico_anillo"], [0.25, "x_portico_anillo"], [0.38, "x_portico_anillo"], [0.50, "x_portico_anillo"],
			[0.62, "x_portico_anillo"], [0.75, "x_portico_anillo"], [0.88, "x_portico_anillo"]],
		"props": [
			{"t": 0.006, "lat": 15.0, "id": "r_cristal_gigante", "s": 0.8}, {"t": 0.006, "lat": -15.0, "id": "r_cristal_gigante", "s": 0.8},
			{"t": 0.30, "lat": -30.0, "id": "r_estacion", "s": 1.8}, {"t": 0.70, "lat": 32.0, "id": "r_estacion", "s": 1.8}, {"t": 0.50, "lat": 24.0, "id": "r_cristal_gigante", "s": 1.2},
			{"t": 0.50, "lat": -24.0, "id": "r_cristal_gigante", "s": 1.2},
		],
		# [tasa por fila y lado, altura mín, altura máx, distancia mín, distancia máx al borde, piezas, escala mín, máx, visibilidad]
		"floaters": [[0.30, 10.0, 55.0, 8.0, 58.0, ["r_roca_flotante", "r_roca_flotante2", "r_cometa", "r_mini_anillo", "r_satelite"], 0.9, 1.7, 650.0],
			[0.012, 90.0, 190.0, 40.0, 240.0, ["r_luna_io", "r_luna_europa", "r_luna_ganimedes"], 3.0, 5.5, 3000.0]],
		"craters": 0.0, "glint": 1.2, "sea": false, "seed": 5303,
	},
}

var world := "mars"
var _def: Dictionary = {}

## Arma el mundo: world = "mars" | "moon" | "ring"
func setup_world(p_track, p_density: float, p_world: String) -> void:
	world = p_world
	_def = DEFS[world]
	themes = _def["themes"]
	zones = _def["zones"]
	layers = _def["layers"]
	strata = _def["strata"]
	c_asph = _def["asph"]
	c_curb_a = _def["curb_a"]
	c_curb_b = _def["curb_b"]
	c_shoulder = _def["shoulder"]
	c_mid = _def["mid_line"]
	seed_v = int(_def["seed"])
	glint_amt = float(_def["glint"])
	setup(p_track, p_density, SUNS[world])

# ───────────────────────── escenografía: pórticos, objetos, cráteres y flotantes ─────────────────────────
func _arches() -> void:
	for pc in _def["porticos"]:
		_put_yaw(int(float(pc[0]) * float(track.n)) % track.n, str(pc[1]), 0.0, 1.0, 0.0)
	for pr in _def["props"]:
		var i: int = int(float(pr["t"]) * float(track.n)) % track.n
		_put_yaw(i, str(pr["id"]), float(pr["lat"]), float(pr["s"]), rng.randf_range(-0.6, 0.6) + (PI if float(pr["lat"]) < 0.0 else 0.0))
		_vis_of[str(pr["id"])] = maxf(float(_vis_of.get(str(pr["id"]), 0.0)), 900.0)
	for pc in _def["porticos"]:
		_vis_of[str(pc[1])] = 1100.0
	if _def.has("floaters"):
		_floaters()
	if float(_def["craters"]) > 0.0:
		_craters(float(_def["craters"]))

## Una pieza a "lat" metros del centro del camino, girada: yaw 0 = el ancho de la pieza a lo ancho del camino
func _put_yaw(i: int, id: String, lat: float, s: float, extra: float) -> void:
	var p: Vector3 = track.samples[i % track.n]
	var l: Vector3 = track.laterals[i % track.n]
	var y := _y_at(i, lat) - 0.03
	var yaw := atan2(-l.z, l.x) + extra
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x + l.x * lat, y, p.z + l.z * lat))
	var key := "%d|%s" % [i / (CH * 2), id]
	if not _inst.has(key):
		_inst[key] = []
	(_inst[key] as Array).append(xf)
	inst_total += 1

func _floaters() -> void:
	var edge: float = track.half_width + track.shoulder
	for i in range(0, track.n, 2):
		var ch: int = i / (CH * 2)
		for side in [-1.0, 1.0]:
			var sd: float = side
			for F in _def["floaters"]:
				var cnt := int(float(F[0]) * density + rng.randf())
				for k in cnt:
					var pool: Array = F[5]
					var id := str(pool[rng.randi() % pool.size()])
					var d: float = edge + rng.randf_range(float(F[3]), float(F[4]))
					var p: Vector3 = track.samples[i % track.n]
					var l: Vector3 = track.laterals[i % track.n]
					var tg: Vector3 = track.tangents[i % track.n]
					var along := rng.randf_range(-3.6, 3.6)
					var y := _y_at(i, sd * d) + rng.randf_range(float(F[1]), float(F[2]))
					var sc := rng.randf_range(float(F[6]), float(F[7]))
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x + l.x * sd * d + tg.x * along, y, p.z + l.z * sd * d + tg.z * along))
					var key := "%d|%s" % [ch, id]
					if not _inst.has(key):
						_inst[key] = []
					(_inst[key] as Array).append(xf)
					inst_total += 1
					_vis_of[id] = maxf(float(_vis_of.get(id, 0.0)), float(F[8]))

## Cráteres pintados sobre el suelo plano: un aro claro (el borde), el fondo más oscuro y una sombra adentro
func _craters(rate: float) -> void:
	var edge: float = track.half_width + track.shoulder
	var acc: Dictionary = {}
	for i in range(0, track.n, 2):
		var ch: int = i / (CH * 2)
		for side in [-1.0, 1.0]:
			var sd: float = side
			var cnt := int(rate * density + rng.randf())
			for k in cnt:
				var r := rng.randf_range(3.0, 12.0)
				var lat: float = sd * (edge + r + 1.0 + rng.randf_range(0.0, 46.0))
				var base: Color = ((themes[_theme_at(i, 0.0)] as Dictionary)["ground"] as Array)[1]
				var a: Acc = acc.get(ch, null)
				if a == null:
					a = Acc.new()
					acc[ch] = a
				var c := _pt(i, lat, 0.045)
				var n := 10
				for q in n:
					var a0 := TAU * float(q) / float(n)
					var a1 := TAU * float(q + 1) / float(n)
					var o0 := Vector3(cos(a0), 0, sin(a0))
					var o1 := Vector3(cos(a1), 0, sin(a1))
					a.quad(c + o0 * r * 0.78, c + o0 * r * 1.12, c + o1 * r * 0.78, c + o1 * r * 1.12, _jit(base.lightened(0.28), 0.06))
					a.quad(c + o0 * r * 0.34, c + o0 * r * 0.78, c + o1 * r * 0.34, c + o1 * r * 0.78, _jit(base.darkened(0.10), 0.05))
					a.tri(c + o0 * r * 0.34, c + o1 * r * 0.34, c, _jit(base.darkened(0.30), 0.05))
	for ch in acc:
		var a2: Acc = acc[ch]
		var m := ArrayMesh.new()
		PaperKit.add_surface(m, a2.v, a2.c, PaperKit.material(null, 0.0, 0.2, 0.25))
		_holder(m, 420.0)

# ───────────────────────── mar de polvo (Marte) ─────────────────────────
func _cloud_sea() -> void:
	if not bool(_def["sea"]):
		return
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = SPACE_SEA
	mi.material_override = m
	mi.position = Vector3(0, sea_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 100000.0
	add_child(mi)
	_sea = m

# ───────────────────────── cielo y luz de cada mundo ─────────────────────────
static func atmosphere_of(w: String, env: Environment, sun: DirectionalLight3D, cam: Camera3D, host: Node) -> void:
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SPACE_SKY
	var sd: Vector3 = SUNS[w]
	sm.set_shader_parameter("sun_dir", sd.normalized())
	var fog_col := Color(0.2, 0.2, 0.2)
	var fog_range := Vector2(500.0, 7500.0)
	var amb := Color(0.8, 0.8, 0.8)
	var amb_e := 0.9
	var sun_col := Color(1, 1, 1)
	var sun_e := 1.3
	var dust := [Color(1.0, 0.8, 0.6), Color(1.0, 0.6, 0.4), Color(1.0, 1.0, 1.0)]
	match w:
		"mars":
			sm.set_shader_parameter("hor_col", Color(0.97, 0.64, 0.44))
			sm.set_shader_parameter("mid_col", Color(0.80, 0.46, 0.42))
			sm.set_shader_parameter("top_col", Color(0.30, 0.14, 0.30))
			sm.set_shader_parameter("below_col", Color(0.60, 0.34, 0.28))
			sm.set_shader_parameter("stars", 0.9975)
			sm.set_shader_parameter("star_floor", 0.45)
			sm.set_shader_parameter("haze_amt", 0.7)
			sm.set_shader_parameter("haze_col", Color(1.0, 0.74, 0.52))
			sm.set_shader_parameter("sun_col", Color(1.0, 0.88, 0.72))
			sm.set_shader_parameter("sun_size", 0.8)
			sm.set_shader_parameter("moon1_dir", Vector3(0.55, 0.62, -0.55))
			sm.set_shader_parameter("moon1_r", 0.030)
			sm.set_shader_parameter("moon1_col", Color(0.78, 0.68, 0.60))
			sm.set_shader_parameter("moon2_dir", Vector3(-0.30, 0.74, -0.60))
			sm.set_shader_parameter("moon2_r", 0.018)
			sm.set_shader_parameter("moon2_col", Color(0.70, 0.64, 0.60))
			fog_col = Color(0.95, 0.62, 0.45)
			fog_range = Vector2(450.0, 6500.0)
			amb = Color(0.96, 0.78, 0.68)
			amb_e = 0.95
			sun_col = Color(1.0, 0.86, 0.70)
			sun_e = 1.35
			dust = [Color(0.95, 0.72, 0.5), Color(0.85, 0.55, 0.4), Color(1.0, 0.85, 0.7)]
		"moon":
			sm.set_shader_parameter("hor_col", Color(0.10, 0.11, 0.16))
			sm.set_shader_parameter("mid_col", Color(0.03, 0.04, 0.09))
			sm.set_shader_parameter("top_col", Color(0.0, 0.0, 0.02))
			sm.set_shader_parameter("below_col", Color(0.0, 0.0, 0.015))
			sm.set_shader_parameter("stars", 0.991)
			sm.set_shader_parameter("star_floor", 0.0)
			sm.set_shader_parameter("stars_below", 1.0)
			sm.set_shader_parameter("haze_amt", 0.0)
			sm.set_shader_parameter("sun_size", 1.4)
			sm.set_shader_parameter("planet_type", 2)
			sm.set_shader_parameter("planet_dir", PLANETS["moon"])
			sm.set_shader_parameter("planet_r", 0.15)
			sm.set_shader_parameter("glow_col", Color(0.35, 0.6, 1.0))
			fog_col = Color(0.02, 0.02, 0.05)
			fog_range = Vector2(700.0, 8000.0)
			amb = Color(0.58, 0.62, 0.78)
			amb_e = 0.6
			sun_e = 1.9
			dust = [Color(1.0, 1.0, 1.0), Color(0.8, 0.9, 1.0), Color(1.0, 1.0, 1.0)]
		"ring":
			sm.set_shader_parameter("hor_col", Color(0.22, 0.16, 0.34))
			sm.set_shader_parameter("mid_col", Color(0.09, 0.07, 0.22))
			sm.set_shader_parameter("top_col", Color(0.02, 0.02, 0.09))
			sm.set_shader_parameter("below_col", Color(0.12, 0.08, 0.20))
			sm.set_shader_parameter("stars", 0.992)
			sm.set_shader_parameter("star_floor", 0.0)
			sm.set_shader_parameter("stars_below", 1.0)
			sm.set_shader_parameter("haze_amt", 0.0)
			sm.set_shader_parameter("nebula", 0.55)
			sm.set_shader_parameter("sun_size", 0.6)
			sm.set_shader_parameter("sun_col", Color(1.0, 0.95, 0.85))
			sm.set_shader_parameter("planet_type", 1)
			sm.set_shader_parameter("planet_dir", PLANETS["ring"])
			sm.set_shader_parameter("planet_r", 0.85)
			sm.set_shader_parameter("moon1_dir", Vector3(0.62, 0.30, 0.50))
			sm.set_shader_parameter("moon1_r", 0.045)
			sm.set_shader_parameter("moon1_col", Color(0.96, 0.78, 0.30))
			sm.set_shader_parameter("moon2_dir", Vector3(0.20, 0.55, 0.78))
			sm.set_shader_parameter("moon2_r", 0.028)
			sm.set_shader_parameter("moon2_col", Color(0.95, 0.93, 0.88))
			fog_col = Color(0.12, 0.10, 0.28)
			fog_range = Vector2(600.0, 9000.0)
			amb = Color(0.74, 0.78, 1.0)
			amb_e = 0.75
			sun_col = Color(1.0, 0.95, 0.88)
			sun_e = 1.25
			dust = [Color(0.7, 0.95, 1.0), Color(1.0, 0.8, 1.0), Color(1.0, 1.0, 1.0)]
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = fog_col
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = fog_range.x
	env.fog_depth_end = fog_range.y
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb
	env.ambient_light_energy = amb_e
	sun.light_color = sun_col
	sun.light_energy = sun_e
	sun.transform = Transform3D(Basis.looking_at(-sd.normalized(), Vector3.UP), Vector3.ZERO)
	cam.far = 9000.0
	var fl := Flare.new()
	fl.cam = cam
	fl.sun_dir = sd
	host.add_child(fl)
	if w == "moon":
		return # sin aire no flota nada
	var motes := _petals()
	motes.amount = 90
	var pm := motes.process_material as ParticleProcessMaterial
	var g := Gradient.new()
	g.colors = PackedColorArray(dust)
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	# puntitos redondos y suaves (no cuadrados)
	var dot := Gradient.new()
	dot.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.0)])
	dot.offsets = PackedFloat32Array([0.35, 1.0])
	var dt := GradientTexture2D.new()
	dt.gradient = dot
	dt.fill = GradientTexture2D.FILL_RADIAL
	dt.fill_from = Vector2(0.5, 0.5)
	dt.fill_to = Vector2(1.0, 0.5)
	dt.width = 32
	dt.height = 32
	var qm := motes.draw_pass_1 as QuadMesh
	var mat := qm.material as StandardMaterial3D
	mat.albedo_texture = dt
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cam.add_child(motes)
