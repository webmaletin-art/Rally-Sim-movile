extends Node3D
## El mundo del Vórtice de Ensueño, todo en papel: camino de asfalto peraltado con cordones de colores, una meseta plana de flores a cada
## lado (con las bandas de color de un planeta gigante), un bosque de flores, arbustos, bambúes y árboles en flor que cambia de color
## a lo largo de la vuelta, arcos de globos, un mar de gas con un agujero negro muy abajo y destellos de sol en los pétalos.
## Todo es fijo (no se mueve con el viento). Las plantas van en MultiMesh por tramos y se ocultan solas a la distancia.

const PaperKit := preload("res://game/fx/paper_kit.gd")
const CLOUDS := preload("res://game/fx/dream_clouds.gdshader")
const SKY := preload("res://game/fx/dream_sky.gdshader")
const Flare := preload("res://game/fx/dream_flare.gd")
const TEX := "res://game/models/paper/tex/"
const SUN := Vector3(-0.30, 0.55, 0.78) # hacia el sol, en el mundo: arriba y adelante de la largada
const CH := 24 # filas (de ~7 m) por tramo de dibujo

# Zonas de color de la vuelta: [desde (fracción de la vuelta), tema]
const ZONES := [[0.0, 0], [0.14, 1], [0.30, 2], [0.46, 3], [0.62, 4], [0.80, 5]]

# Cada tema: piezas por capa. trees · tall (flores altas) · low (flores bajas) · shrubs (arbustos y bambú) · grass · fill (algas, hongos, helechos, nenúfares)
const THEMES := [
	{ # 0 · aurora rosa
		"trees": ["d_sakura_rosa", "d_sakura_intenso", "d_sakura_blanco", "d_arbol_burbujas"],
		"tall": ["d_rosa_rosa", "d_tulipan_rosa", "d_lirio_rosa", "d_orquidea_magenta", "d_hibisco_magenta", "d_loto_rosa", "d_rosa_blanca"],
		"low": ["d_margarita_rosa", "d_flor_durazno", "d_rosa_blanca", "d_flor_lila", "d_margarita_rosa"],
		"shrubs": ["d_arbusto_rosa", "d_arbusto_coral", "d_bambu_rosado", "d_arbusto_rosa"],
		"grass": ["d_pasto_rosado", "d_pasto_lila"],
		"fill": ["d_helecho_magenta", "d_hongo_magenta", "d_nenufar"],
		"ground": [Color(0.99, 0.78, 0.86), Color(0.96, 0.66, 0.80), Color(0.95, 0.86, 0.91)], "spark": [Color(1.0, 0.35, 0.60), Color(1.0, 1.0, 1.0)],
	},
	{ # 1 · jardín violeta
		"trees": ["d_jacaranda", "d_arbol_burbujas2", "d_sakura_blanco", "d_jacaranda"],
		"tall": ["d_orquidea_lila", "d_tulipan_violeta", "d_hibisco_magenta", "d_loto_blanco", "d_orquidea_magenta", "d_tulipan_violeta"],
		"low": ["d_margarita_lila", "d_flor_lila", "d_flor_celeste", "d_margarita_lila"],
		"shrubs": ["d_arbusto_lila", "d_arbusto_turquesa", "d_arbusto_lila"],
		"grass": ["d_pasto_lila", "d_pasto_turquesa"],
		"fill": ["d_alga_azul", "d_hongo_celeste", "d_helecho_magenta"],
		"ground": [Color(0.78, 0.68, 0.96), Color(0.68, 0.56, 0.92), Color(0.89, 0.82, 0.98)], "spark": [Color(0.60, 0.30, 0.95), Color(0.80, 0.95, 1.0)],
	},
	{ # 2 · oro del cielo
		"trees": ["d_arce_dorado", "d_arbol_burbujas", "d_arbol_coral", "d_arce_dorado"],
		"tall": ["d_girasol", "d_girasol_naranja", "d_lirio_amarillo", "d_lirio_naranja", "d_tulipan_amarilla", "d_tulipan_naranja", "d_girasol"],
		"low": ["d_margarita_amarilla", "d_flor_durazno", "d_flor_menta", "d_margarita_amarilla"],
		"shrubs": ["d_arbusto_dorado", "d_bambu_dorado", "d_arbusto_coral", "d_arbusto_dorado"],
		"grass": ["d_pasto_dorado", "d_pasto_dorado", "d_pasto_rosado"],
		"fill": ["d_hongo_naranja", "d_helecho_azulado"],
		"ground": [Color(0.99, 0.88, 0.55), Color(0.97, 0.78, 0.42), Color(1.0, 0.94, 0.74)], "spark": [Color(1.0, 0.55, 0.10), Color(1.0, 1.0, 0.85)],
	},
	{ # 3 · selva turquesa
		"trees": ["d_arbol_turquesa", "d_jacaranda", "d_arbol_burbujas2", "d_arbol_turquesa"],
		"tall": ["d_loto_magenta", "d_loto_blanco", "d_orquidea_lila", "d_tropical_azul", "d_tulipan_violeta", "d_loto_rosa"],
		"low": ["d_flor_celeste", "d_flor_menta", "d_margarita_lila", "d_flor_celeste"],
		"shrubs": ["d_arbusto_turquesa", "d_bambu_verde", "d_arbusto_lila", "d_bambu_verde"],
		"grass": ["d_pasto_turquesa", "d_pasto_lila"],
		"fill": ["d_alga_turquesa", "d_alga_azul", "d_helecho_azulado", "d_hongo_celeste", "d_nenufar"],
		"ground": [Color(0.55, 0.90, 0.82), Color(0.40, 0.80, 0.78), Color(0.72, 0.95, 0.90)], "spark": [Color(0.20, 0.80, 1.0), Color(1.0, 0.7, 0.85)],
	},
	{ # 4 · coral y fuego
		"trees": ["d_arbol_coral", "d_arce_dorado", "d_sakura_intenso", "d_arbol_coral"],
		"tall": ["d_hibisco_rojo", "d_hibisco_salmon", "d_tropical_roja", "d_rosa_roja", "d_tulipan_roja", "d_lirio_naranja", "d_hibisco_rojo"],
		"low": ["d_rosa_coral", "d_flor_durazno", "d_margarita_amarilla", "d_rosa_coral"],
		"shrubs": ["d_arbusto_coral", "d_arbusto_rosa", "d_arbusto_dorado", "d_arbusto_coral"],
		"grass": ["d_pasto_dorado", "d_pasto_rosado"],
		"fill": ["d_hongo_rojo", "d_hongo_naranja"],
		"ground": [Color(0.99, 0.62, 0.55), Color(0.95, 0.50, 0.45), Color(1.0, 0.79, 0.68)], "spark": [Color(1.0, 0.85, 0.20), Color(1.0, 0.30, 0.30)],
	},
	{ # 5 · arcoíris
		"trees": ["d_arbol_burbujas", "d_arbol_burbujas2", "d_sakura_rosa", "d_jacaranda", "d_arce_dorado", "d_arbol_turquesa", "d_arbol_coral"],
		"tall": ["d_girasol", "d_tulipan_rosa", "d_tulipan_violeta", "d_tulipan_naranja", "d_lirio_amarillo", "d_loto_magenta", "d_hibisco_rojo", "d_orquidea_lila", "d_tropical_azul"],
		"low": ["d_margarita_rosa", "d_margarita_amarilla", "d_margarita_lila", "d_flor_celeste", "d_flor_menta", "d_flor_durazno", "d_flor_lila"],
		"shrubs": ["d_arbusto_rosa", "d_arbusto_lila", "d_arbusto_dorado", "d_arbusto_turquesa", "d_arbusto_coral", "d_bambu_verde"],
		"grass": ["d_pasto_rosado", "d_pasto_dorado", "d_pasto_turquesa", "d_pasto_lila"],
		"fill": ["d_hongo_rojo", "d_hongo_magenta", "d_hongo_celeste", "d_alga_turquesa", "d_nenufar"],
		"ground": [Color(0.99, 0.84, 0.70), Color(0.78, 0.86, 0.98), Color(0.98, 0.72, 0.84)], "spark": [Color(1.0, 0.45, 0.20), Color(0.30, 0.75, 1.0), Color(0.95, 0.30, 0.80)],
	},
]

# Paleta de los globos de los arcos y de los cordones del camino
const BALLOONS := [Color(1.0, 0.45, 0.65), Color(1.0, 0.72, 0.30), Color(0.98, 0.92, 0.45), Color(0.45, 0.85, 0.70), Color(0.45, 0.72, 1.0), Color(0.72, 0.55, 1.0)]
const C_ASPH := Color(0.55, 0.56, 0.62)
const C_CURB_A := Color(1.0, 0.55, 0.72)
const C_CURB_B := Color(0.99, 0.96, 0.92)

const ICO_F := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]

class Acc:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color) -> void:
		v.append_array(PackedVector3Array([a, b, cc, b, d, cc]))
		for k in 6:
			c.append(col)
	func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color) -> void:
		v.append_array(PackedVector3Array([a, b, cc]))
		for k in 3:
			c.append(col)

var track
var rng := RandomNumberGenerator.new()
var density := 1.0
var sun_dir := Vector3(0.35, 0.62, 0.70)
var inst_total := 0
var sea_y := -120.0
var _inst: Dictionary = {}
var _ico_v: Array[Vector3] = []

func setup(p_track, p_density := 1.0, p_sun_dir := Vector3(0.35, 0.62, 0.70)) -> void:
	track = p_track
	density = p_density
	sun_dir = p_sun_dir.normalized()
	rng.seed = 777
	var t := (1.0 + sqrt(5.0)) / 2.0
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		_ico_v.append((p as Vector3).normalized())
	var ymin := 1e9
	for i in track.n:
		ymin = minf(ymin, track.cy[i])
	sea_y = ymin - 130.0
	var chunks := int(ceil(float(track.n) / float(CH * 2)))
	for ch in chunks:
		var a := ch * CH * 2
		var b := mini(track.n, (ch + 1) * CH * 2)
		_build_ground(a, b)
		_build_road(a, b)
	_plant()
	_arches()
	_commit_instances()
	_cloud_sea()

## Cielo y luz del mapa: Júpiter gigante, niebla pastel, sol dorado y los reflejos de sol (halo y fantasmas del lente)
static func atmosphere(env: Environment, sun: DirectionalLight3D, cam: Camera3D, host: Node) -> void:
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	sm.set_shader_parameter("sun_dir", SUN.normalized())
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.70, 0.66)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 500.0
	env.fog_depth_end = 7500.0
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.78, 0.96)
	env.ambient_light_energy = 0.95
	sun.light_color = Color(1.0, 0.90, 0.74)
	sun.light_energy = 1.35
	sun.transform = Transform3D(Basis.looking_at(-SUN.normalized(), Vector3.UP), Vector3.ZERO)
	cam.far = 9000.0
	var fl := Flare.new()
	fl.cam = cam
	fl.sun_dir = SUN
	host.add_child(fl)

func _jit(c: Color, a: float) -> Color:
	var k := 1.0 + (rng.randf() - 0.5) * a
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))

func _holder(m: ArrayMesh, vis_end: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = vis_end
	add_child(mi)
	return mi

## Tema (0..5) de cada punto de la vuelta; con jitter en los límites para que los colores se mezclen
func _theme_at(i: int, jitter: float) -> int:
	var t := fposmod(float(i) / float(track.n) + rng.randf_range(-jitter, jitter), 1.0)
	var th := 0
	for z in ZONES:
		if t >= float(z[0]):
			th = int(z[1])
	return th

func _bank(i: int) -> float:
	return track.bank[i % track.n]

## Altura del suelo a "lat" metros del centro del camino en la muestra i (sigue el peralte hasta el borde y sigue plano más afuera)
func _y_at(i: int, lat: float) -> float:
	var se: float = track.half_width + track.shoulder
	return float(track.cy[i % track.n]) + _bank(i) * clampf(lat, -se, se)

func _pt(i: int, lat: float, dy := 0.0) -> Vector3:
	var p: Vector3 = track.samples[i % track.n]
	var l: Vector3 = track.laterals[i % track.n]
	return Vector3(p.x + l.x * lat, _y_at(i, lat) + dy, p.z + l.z * lat)

# ───────────────────────── camino ─────────────────────────
func _build_road(i0: int, i1: int) -> void:
	var asph := Acc.new()
	var marks := Acc.new()
	var hw: float = track.half_width
	for i in range(i0, i1):
		var j := i + 1
		asph.quad(_pt(i, -hw, 0.015), _pt(i, hw, 0.015), _pt(j, -hw, 0.015), _pt(j, hw, 0.015), _jit(C_ASPH, 0.1))
		# cordones de colores en los bordes (rosa y blanco que se alternan)
		var cc := C_CURB_A if (i / 2) % 2 == 0 else C_CURB_B
		for sg in [-1.0, 1.0]:
			var s: float = sg
			marks.quad(_pt(i, s * (hw - 0.85), 0.03), _pt(i, s * hw, 0.03), _pt(j, s * (hw - 0.85), 0.03), _pt(j, s * hw, 0.03), cc)
			# línea de borde blanca, junto al cordón
			marks.quad(_pt(i, s * (hw - 1.45), 0.03), _pt(i, s * (hw - 1.25), 0.03), _pt(j, s * (hw - 1.45), 0.03), _pt(j, s * (hw - 1.25), 0.03), Color(0.97, 0.95, 0.92))
		# línea del medio dorada cortada
		if i % 4 < 2:
			marks.quad(_pt(i, -0.09, 0.03), _pt(i, 0.09, 0.03), _pt(j, -0.09, 0.03), _pt(j, 0.09, 0.03), Color(1.0, 0.85, 0.35))
		# carriles: rayas blancas cortadas a ±hw/2
		if i % 6 < 2:
			for sg in [-1.0, 1.0]:
				var s2: float = sg * hw * 0.5
				marks.quad(_pt(i, s2 - 0.07, 0.03), _pt(i, s2 + 0.07, 0.03), _pt(j, s2 - 0.07, 0.03), _pt(j, s2 + 0.07, 0.03), Color(0.96, 0.94, 0.90))
	# línea de largada en cuadros
	if i0 == 0:
		for k in 14:
			var c0 := Color(0.05, 0.05, 0.08) if k % 2 == 0 else Color(0.98, 0.98, 0.96)
			var x0 := -hw + float(k) * hw * 2.0 / 14.0
			var x1 := x0 + hw * 2.0 / 14.0
			marks.quad(_pt(2, x0, 0.035), _pt(2, x1, 0.035), _pt(3, x0, 0.035), _pt(3, x1, 0.035), c0)
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, asph.v, asph.c, PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.07))
	PaperKit.add_surface(m, marks.v, marks.c, PaperKit.material(null, 0.0, 0.2, 0.0))
	_holder(m, 900.0)

# ───────────────────────── meseta plana de flores ─────────────────────────
## Degradé cíclico suave entre los tres colores de la paleta
func _pal3(pal: Array, u: float) -> Color:
	var t := fposmod(u, 1.0) * float(pal.size())
	var k := int(floor(t))
	var f := smoothstep(0.0, 1.0, t - float(k))
	return (pal[k % pal.size()] as Color).lerp(pal[(k + 1) % pal.size()] as Color, f)

func _build_ground(i0: int, i1: int) -> void:
	var gr := Acc.new()
	var sk := Acc.new()
	var hw: float = track.half_width
	var sho: float = track.shoulder
	var edge := hw + sho
	var bands: Array[float] = [hw, edge, edge + 2.0, edge + 4.5, edge + 7.5, edge + 11.0, edge + 15.0, edge + 20.0, edge + 26.0, edge + 33.0, edge + 41.0, edge + 50.0, edge + 62.0]
	var strata := [Color(0.99, 0.90, 0.82), Color(0.90, 0.62, 0.74), Color(0.62, 0.46, 0.78), Color(0.38, 0.30, 0.62)]
	for i in range(i0, i1, 2):
		var j := mini(i + 2, i1 + 1)
		var th := _theme_at(i, 0.012)
		var pal: Array = (THEMES[th] as Dictionary)["ground"]
		for side in [-1.0, 1.0]:
			var sd: float = side
			for k in bands.size() - 1:
				var col: Color
				if k == 0:
					col = _jit(Color(0.99, 0.90, 0.84), 0.08) # banquina de pétalos claros
				else:
					# bandas de color paralelas al camino, como las nubes de Júpiter: un degradé suave que ondula a lo largo de la vuelta
					var mid := (bands[k] + bands[k + 1]) * 0.5 - edge
					var u := mid * 0.052 + 0.55 * sin(float(i) * 0.038 + mid * 0.045 + sd) + 0.25 * sin(float(i) * 0.11 - mid * 0.09)
					col = _jit(_pal3(pal, u), 0.05)
				gr.quad(_pt(i, sd * bands[k]), _pt(i, sd * bands[k + 1]), _pt(j, sd * bands[k]), _pt(j, sd * bands[k + 1]), col)
			# faldón: capas de colores bajando hacia el mar de gas (el borde de la meseta flota)
			var lo: float = bands[bands.size() - 1]
			var top_a := _pt(i, sd * lo)
			var top_b := _pt(j, sd * lo)
			var depth := [0.0, 5.0, 14.0, 30.0, 52.0]
			for s in 4:
				var da: float = depth[s]
				var db: float = depth[s + 1]
				sk.quad(top_a + Vector3(0, -da, 0), top_a + Vector3(0, -db, 0), top_b + Vector3(0, -da, 0), top_b + Vector3(0, -db, 0), _jit(strata[s] as Color, 0.1))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, gr.v, gr.c, PaperKit.material(load(TEX + "grass.png") as Texture2D, 0.18, 0.16, 0.30))
	PaperKit.add_surface(m, sk.v, sk.c, PaperKit.material(null, 0.0, 0.2, 0.35))
	_holder(m, 950.0)

# ───────────────────────── vegetación ─────────────────────────
func _pick(pool: Array) -> String:
	return str(pool[rng.randi() % pool.size()])

func _put(chunk: int, id: String, i: int, lat: float, along: float, s: float) -> void:
	var p: Vector3 = track.samples[i % track.n]
	var l: Vector3 = track.laterals[i % track.n]
	var tg: Vector3 = track.tangents[i % track.n]
	var y := _y_at(i, lat) - 0.03
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x + l.x * lat + tg.x * along, y, p.z + l.z * lat + tg.z * along))
	var key := "%d|%s" % [chunk, id]
	if not _inst.has(key):
		_inst[key] = []
	(_inst[key] as Array).append(xf)
	inst_total += 1

func _plant() -> void:
	var hw: float = track.half_width
	var edge: float = hw + track.shoulder
	# [tasa por fila (~7 m) y lado, distancia mínima y máxima al borde, capa, escala mín, escala máx]
	var layers := [
		[15.0, 0.6, 7.2, "low", 1.8, 3.0], [12.0, 0.4, 7.2, "grass", 1.0, 1.8], [4.0, 2.0, 10.0, "tall", 1.2, 2.1], [3.4, 6.5, 14.5, "shrubs", 1.1, 2.0],
		[3.0, 1.5, 16.0, "fill", 1.2, 2.2], [0.9, 8.5, 21.0, "trees", 1.0, 1.5], [1.5, 18.0, 56.0, "trees", 1.2, 2.0], [6.0, 12.0, 56.0, "low", 2.2, 3.6],
		[2.2, 10.0, 54.0, "tall", 1.8, 3.0], [5.0, 8.0, 56.0, "grass", 1.4, 2.4],
	]
	for i in range(0, track.n, 2):
		var ch: int = i / (CH * 2)
		for side in [-1.0, 1.0]:
			var sd: float = side
			for L in layers:
				var cnt := int(float(L[0]) * density + rng.randf())
				for k in cnt:
					var th := _theme_at(i, 0.03)
					var pool: Array = (THEMES[th] as Dictionary)[str(L[3])]
					var d: float = edge + rng.randf_range(float(L[1]), float(L[2]))
					_put(ch, _pick(pool), i, sd * d, rng.randf_range(-3.6, 3.6), rng.randf_range(float(L[4]), float(L[5])))

# ───────────────────────── arcos de globos ─────────────────────────
func _ico(acc: Acc, c: Vector3, r: float, col: Color) -> void:
	for f in ICO_F:
		acc.tri(c + _ico_v[int(f[0])] * r, c + _ico_v[int(f[1])] * r, c + _ico_v[int(f[2])] * r, _jit(col, 0.12))

func _arches() -> void:
	var hw: float = track.half_width
	var r: float = hw + track.shoulder + 2.5
	for t in [0.0, 0.10, 0.24, 0.36, 0.45, 0.55, 0.66, 0.78, 0.90]:
		var acc := Acc.new()
		var i := int(float(t) * float(track.n))
		var n := 17
		for k in n:
			var a := PI * float(k) / float(n - 1)
			var lat := cos(a) * r
			var base := _y_at(i, lat)
			var c := _pt(i, lat) + Vector3(0, sin(a) * r * 1.05 + 1.0, 0)
			c.y = maxf(c.y, base + 1.2)
			_ico(acc, c, 1.55 + 0.25 * sin(a * 3.0), BALLOONS[(k + i) % BALLOONS.size()])
		# pilares: globos apilados a cada lado
		for sg in [-1.0, 1.0]:
			var s: float = sg
			for k in 3:
				_ico(acc, _pt(i, s * r) + Vector3(0, 1.2 + float(k) * 2.4, 0), 1.3, BALLOONS[(k + i + 2) % BALLOONS.size()])
		var m := ArrayMesh.new()
		PaperKit.add_surface(m, acc.v, acc.c, PaperKit.material(null, 0.0, 0.2, 0.5))
		_holder(m, 800.0) # un objeto por arco: la distancia de visibilidad se mide a cada uno

func _commit_instances() -> void:
	var mat := PaperKit.glint_material(sun_dir, 1.0)
	for key in _inst:
		var parts := str(key).split("|")
		var id: String = parts[1]
		var arr: Array = _inst[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = PaperKit.mesh(id)
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cat := str(PaperKit.info(id).get("cat", ""))
		mmi.visibility_range_end = 560.0 if cat == "arbol" else (280.0 if cat in ["arbusto", "bambu"] else 160.0)
		add_child(mmi)
	_inst.clear()

# ───────────────────────── mar de gas con el agujero negro ─────────────────────────
func _cloud_sea() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60000, 60000)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = CLOUDS
	m.set_shader_parameter("center", Vector2(0, 0))
	m.set_shader_parameter("hole_r", 520.0)
	mi.material_override = m
	mi.position = Vector3(0, sea_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 100000.0
	add_child(mi)
	_sea = m

var _sea: ShaderMaterial

func _process(_dt: float) -> void:
	if _sea != null:
		_sea.set_shader_parameter("tm", float(Time.get_ticks_msec()) * 0.001)
