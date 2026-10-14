extends RefCounted
## La región del mundo abierto (todo lo que rodea a Dream City): terreno de montañas y llanuras, la circunvalación, autopistas, rutas, caminos de tierra y de montaña,
## pueblos, estaciones y peajes. Sale de `tools/world_gen` (python3 build_region.py) y se guarda en `data/region/region_1.bin` (ver export.py para el formato).
## Todas las consultas son puras (la física corre en hilos). Ejes: x al este, z al sur (el norte es −z), metros.

const FILE := "res://game/data/region/region_1.bin"
const WALL := 9.0 # metros de banquina y pasto entre el borde de la calzada y la pared invisible de la ruta
const SHOULDER := 1.9
const TOWN_WALL := 3.2 # dentro de un pueblo la pared invisible queda pegada al cerco de las casas (como en Villa Aurora)
const WALL_MONTANA := 2.6 # en las rutas de montaña la pared está pegada al guardarraíl
const JUNCTION_DISC := 18.0 # en un cruce la pared invisible es un círculo de este radio más el medio ancho de la calle más ancha (para doblar sin chocar la esquina)
const REACH := 70.0 # hasta dónde llega el corte del terreno alrededor de un camino (ver _carve)
const SURF_OF_BIOME := [3, 1, 3, 4, 6, 3, 1, 1, 5] # pampa, estepa, sierra, roca, nieve, selva, quebrada, arena, humedal → superficie de la física
const CLS_NAMES := ["anillo", "autopista", "ruta", "provincial", "camino", "tierra", "montana", "calle", "conector"]
const KIND_NAMES := ["dream", "anillo", "ciudad_salida", "ciudad", "pueblo", "villa", "cruce", "calle_fin", "paraje"]
const ROAD_SURF := [0, 1, 1] # asfalto, tierra, ripio → superficie de la física

var ok := false
var city # CityLayout (la altura base)
var x0 := 0.0
var z0 := 0.0
var gw := 0
var gh := 0
var cell := 100.0
var delta := PackedByteArray() # int16 en decímetros
var bio := PackedByteArray()
var pts := PackedInt32Array() # x, z en decímetros
var hs := PackedFloat32Array() # altura del camino en cada punto (m)
var pe := PackedInt32Array() # a qué calle pertenece cada punto
var cells: Dictionary = {} # Vector2i (128 m) -> PackedInt32Array de tramos (índice del punto donde empieza)
var edges: Array = [] # [a, b, cls, name, ancho, superficie, p0, n, largo]
var nodes: Array = [] # [id, x, z, kind, name, h, eje]
var meta: Dictionary = {}
var pois: Array = []
var tolls: Array = []
var signs: Dictionary = {}
var node_edges: Array = [] # nodo -> PackedInt32Array de calles
var e_hw := PackedFloat32Array()
var e_wall := PackedFloat32Array() # metros de pared invisible de cada calle (WALL, o WALL_MONTANA en las de montaña)
var pads: Array = [] # playones planos junto a la ruta (gasolineras, gomerías): {x, z, r, h}
var pad_cells: Dictionary = {} # Vector2i (128 m) -> PackedInt32Array de playones
var jdiscs: Array = [] # círculos libres alrededor de los cruces (sólo para la pared invisible): {x, z, r}
var jdisc_cells: Dictionary = {} # Vector2i (128 m) -> PackedInt32Array de círculos
var _cum: Dictionary = {}
var secret_sites: Array = [] # lugares secretos de algunas villas: {id, name, kind, pos, h}
var _zones: Array = [] # recintos de pueblos: {c, ax, hu, hv}
var _zone_cells: Dictionary = {} # Vector2i (256 m) -> índices de recintos

# ───────────────────────── carga ─────────────────────────
func load_file(p_city, path := FILE) -> bool:
	city = p_city
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var buf := f.get_buffer(f.get_length())
	f.close()
	if buf.size() < 16 or buf.slice(0, 4).get_string_from_ascii() != "DRRG":
		return false
	var jl := buf.decode_u32(8)
	var js := buf.slice(12, 12 + jl).get_string_from_utf8()
	var m: Variant = JSON.parse_string(js)
	if not (m is Dictionary):
		return false
	meta = m
	var g: Dictionary = meta["grid"]
	x0 = float(g["x0"])
	z0 = float(g["z0"])
	gw = int(g["w"])
	gh = int(g["h"])
	cell = float(g["cell"])
	var off := 12 + jl
	var ng := gw * gh
	delta = buf.slice(off, off + ng * 2)
	off += ng * 2
	bio = buf.slice(off, off + ng)
	off += ng + ((4 - ng % 4) % 4)
	var n := int(meta["n_pts"])
	pts = buf.slice(off, off + n * 8).to_int32_array()
	off += n * 8
	hs = buf.slice(off, off + n * 4).to_float32_array()
	off += n * 4
	pe = buf.slice(off, off + n * 4).to_int32_array()
	off += n * 4
	var nc := int(meta["n_cells"])
	var cl := buf.slice(off, off + nc * 16).to_int32_array()
	off += nc * 16
	var ns := int(meta["n_segs"])
	var sg := buf.slice(off, off + ns * 4).to_int32_array()
	for i in nc:
		cells[Vector2i(cl[i * 4], cl[i * 4 + 1])] = sg.slice(cl[i * 4 + 2], cl[i * 4 + 2] + cl[i * 4 + 3])
	edges = meta["edges"]
	nodes = meta["nodes"]
	pois = meta.get("pois", [])
	tolls = meta.get("tolls", [])
	signs = meta.get("signs", {})
	e_hw.resize(edges.size())
	e_wall.resize(edges.size())
	for i in edges.size():
		e_hw[i] = float(edges[i][4]) * 0.5
		e_wall[i] = WALL_MONTANA if str(CLS_NAMES[int((edges[i] as Array)[2])]) == "montana" else WALL
	node_edges.resize(nodes.size())
	for i in nodes.size():
		node_edges[i] = PackedInt32Array()
	for ei in edges.size():
		var e: Array = edges[ei]
		var a: PackedInt32Array = node_edges[int(e[0])]
		a.append(ei)
		node_edges[int(e[0])] = a
		if int(e[1]) != int(e[0]):
			var b: PackedInt32Array = node_edges[int(e[1])]
			b.append(ei)
			node_edges[int(e[1])] = b
	_build_zones()
	_build_secrets()
	_build_junction_discs()
	# las distancias acumuladas de todas las calles, ya: edge_cum() se usa desde los hilos que arman el terreno (region_world._build → _road_caps → _fillets)
	# y a la vez desde el hilo principal (GPS, policía, carreras). Antes se llenaban a demanda y dos hilos escribían la misma tabla al mismo tiempo:
	# un error nativo (SIGSEGV, «estado 11») que cerraba el juego sólo en el mundo abierto (docs/REGISTRO_TECNICO.md, 14/10/2026). Así, durante el juego, sólo se lee.
	for ei in edges.size():
		edge_cum(ei)
	ok = true
	return true

## En un cruce de tres o más calles la pared invisible es un círculo que cubre la esquina: un auto que dobla rápido en un cruce (sobre todo de montaña, donde la pared está pegada
## al guardarraíl) corta la curva por el pasto sin chocar contra una pared que no se ve. Es sólo para la pared (el terreno y las alturas no lo usan). Dentro de los pueblos no se arma.
func _build_junction_discs() -> void:
	jdiscs.clear()
	jdisc_cells.clear()
	for ni in nodes.size():
		var eds: PackedInt32Array = node_edges[ni]
		if eds.size() < 3:
			continue
		var nd: Array = nodes[ni]
		var x := float(nd[1])
		var z := float(nd[2])
		if in_town(x, z):
			continue
		var hw := 0.0
		for ei in eds:
			hw = maxf(hw, e_hw[ei])
		var r := hw + JUNCTION_DISC
		var idx := jdiscs.size()
		jdiscs.append({"x": x, "z": z, "r": r})
		for cx in range(int(floor((x - r) / 128.0)), int(floor((x + r) / 128.0)) + 1):
			for cz in range(int(floor((z - r) / 128.0)), int(floor((z + r) / 128.0)) + 1):
				var k := Vector2i(cx, cz)
				var a: PackedInt32Array = jdisc_cells.get(k, PackedInt32Array())
				a.append(idx)
				jdisc_cells[k] = a

## Los recintos de los pueblos y ciudades (el rectángulo de sus calles, con margen): ahí la pared invisible de las calles se acerca
func _build_zones() -> void:
	_zones.clear()
	_zone_cells.clear()
	for nd in nodes:
		var kind := int(nd[3])
		if kind < 3 or kind > 5:
			continue
		var ax: Array = nd[6] if (nd as Array).size() > 6 else []
		if ax.size() < 2:
			continue
		var half: Vector2 = [Vector2(345.0, 270.0), Vector2(285.0, 165.0), Vector2(150.0, 95.0)][kind - 3]
		var z := {"c": Vector2(float(nd[1]), float(nd[2])), "ax": Vector2(float(ax[0]), float(ax[1])), "hu": half.x, "hv": half.y}
		var idx := _zones.size()
		_zones.append(z)
		var r := half.length()
		var c: Vector2 = z["c"]
		for cx in range(int(floor((c.x - r) / 256.0)), int(floor((c.x + r) / 256.0)) + 1):
			for cz in range(int(floor((c.y - r) / 256.0)), int(floor((c.y + r) / 256.0)) + 1):
				var k := Vector2i(cx, cz)
				var a: PackedInt32Array = _zone_cells.get(k, PackedInt32Array())
				a.append(idx)
				_zone_cells[k] = a

## Cada secreto de los datos queda al final de una calle lateral de su villa (se llega manejando por esa calle)
func _build_secrets() -> void:
	secret_sites.clear()
	var by_id := {}
	for nd in nodes:
		by_id[str(nd[0])] = nd
	var i := 0
	for sc in meta.get("secrets", []):
		var nd: Variant = by_id.get(str(sc["near"]))
		if nd != null and (nd as Array).size() > 6 and ((nd as Array)[6] as Array).size() >= 2:
			var ax := Vector2(float((nd[6] as Array)[0]), float((nd[6] as Array)[1]))
			var nrm := Vector2(-ax.y, ax.x)
			var pos := Vector2(float(nd[1]), float(nd[2])) + ax * -45.0 + nrm * 92.0
			secret_sites.append({"id": "secret_%d" % i, "name": str(sc["name"]), "kind": str(sc["kind"]), "pos": pos, "ax": ax, "idx": i})
		i += 1

func in_town(x: float, z: float) -> bool:
	var lst: Variant = _zone_cells.get(Vector2i(int(floor(x / 256.0)), int(floor(z / 256.0))))
	if lst == null:
		return false
	for i in (lst as PackedInt32Array):
		var zn: Dictionary = _zones[i]
		var d := Vector2(x, z) - (zn["c"] as Vector2)
		var ax: Vector2 = zn["ax"]
		var u := d.x * ax.x + d.y * ax.y
		var v := -d.x * ax.y + d.y * ax.x
		if absf(u) < float(zn["hu"]) and absf(v) < float(zn["hv"]):
			return true
	return false

## Un playón circular plano a la altura h (una zona abierta: el auto lo pisa y sale a la ruta por la abertura donde se tocan)
func add_pad(x: float, z: float, r: float, h: float) -> void:
	var idx := pads.size()
	pads.append({"x": x, "z": z, "r": r, "h": h})
	for cx in range(int(floor((x - r) / 128.0)), int(floor((x + r) / 128.0)) + 1):
		for cz in range(int(floor((z - r) / 128.0)), int(floor((z + r) / 128.0)) + 1):
			var k := Vector2i(cx, cz)
			var a: PackedInt32Array = pad_cells.get(k, PackedInt32Array())
			a.append(idx)
			pad_cells[k] = a

# ───────────────────────── terreno ─────────────────────────
func _d16(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, gw - 1)
	iz = clampi(iz, 0, gh - 1)
	return float(delta.decode_s16((iz * gw + ix) * 2)) * 0.1

## Diferencia entre el terreno de la región y el de la ciudad (0 cerca de Dream City), interpolada
func delta_at(x: float, z: float) -> float:
	var fx := (x - x0) / cell - 0.5
	var fz := (z - z0) / cell - 0.5
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var a := lerpf(_d16(ix, iz), _d16(ix + 1, iz), tx)
	var b := lerpf(_d16(ix, iz + 1), _d16(ix + 1, iz + 1), tx)
	return lerpf(a, b, tz)

func biome_at(x: float, z: float) -> int:
	var ix := clampi(int(floor((x - x0) / cell)), 0, gw - 1)
	var iz := clampi(int(floor((z - z0) / cell)), 0, gh - 1)
	return bio[iz * gw + ix]

func in_bounds(x: float, z: float) -> bool:
	return x > x0 and x < x0 + float(gw) * cell and z > z0 and z < z0 + float(gh) * cell

## Altura del terreno sin tocar por los caminos
func base_height(x: float, z: float) -> float:
	return city.base_height(x, z) + delta_at(x, z)

## Altura final: el terreno se corta o se rellena alrededor de cada camino (la calzada y su banquina quedan a la altura del camino y el terreno se une a ella de a poco)
func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	var pr := probe(x, z, REACH)
	if pr[0] <= -1e8:
		return h
	return _carve(h, pr)

## Altura final y cuánto influye el camino en ese punto (1 = sobre la calzada o la banquina, 0 = nada): para armar la malla del terreno
func height_w(x: float, z: float) -> Vector2:
	var h := base_height(x, z)
	var pr := probe(x, z, REACH)
	if pr[0] <= -1e8:
		return Vector2(h, 0.0)
	var hc := _carve(h, pr)
	var d: float = pr[4]
	var edge: float = pr[5] + (SHOULDER if pr[1] >= 0.0 else 0.0)
	if d <= edge:
		return Vector2(hc, 1.0)
	var bw := clampf(absf(h - pr[6]) * 1.7 + 6.0, 6.0, 55.0)
	return Vector2(hc, 1.0 - smoothstep(edge, edge + bw, d))

func _carve(h: float, pr: PackedFloat64Array) -> float:
	var d: float = pr[4]
	var hw: float = pr[5]
	var hr: float = pr[6]
	var edge := hw + (SHOULDER if pr[1] >= 0.0 else 0.0)
	if d <= edge:
		return hr
	var bw := clampf(absf(h - hr) * 1.7 + 6.0, 6.0, 55.0)
	return lerpf(hr, h, smoothstep(edge, edge + bw, d))

# ───────────────────────── caminos ─────────────────────────
## El camino más cercano (por holgura al borde): [holgura (m, >0 adentro de la calzada+banquina), calle, índice del punto, t, distancia al eje, medio ancho, altura del camino, nx, nz (hacia el eje), superficie]
## Todo −1e9 si no hay ningún camino a la vista (a menos de unos 128 m). `with_pads` en falso ignora los playones (sólo calles).
func probe(x: float, z: float, reach := 30.0, with_pads := true) -> PackedFloat64Array:
	var out := PackedFloat64Array([-1e9, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var kx := int(floor(x / 128.0))
	var kz := int(floor(z / 128.0))
	var best := -1e9
	var fx := fposmod(x, 128.0)
	var fz := fposmod(z, 128.0)
	# sólo se miran las celdas vecinas si el punto está a menos de `reach` m del borde de su celda (los tramos se anotan en todas las celdas que tocan)
	var x_lo := -1 if fx < reach else 0
	var x_hi := 1 if fx > 128.0 - reach else 0
	var z_lo := -1 if fz < reach else 0
	var z_hi := 1 if fz > 128.0 - reach else 0
	for dx in range(x_lo, x_hi + 1):
		for dz in range(z_lo, z_hi + 1):
			var pl: Variant = pad_cells.get(Vector2i(kx + dx, kz + dz)) if (with_pads and not pads.is_empty()) else null
			if pl != null:
				for pi in (pl as PackedInt32Array):
					var pd: Dictionary = pads[pi]
					var pdx: float = float(pd["x"]) - x
					var pdz: float = float(pd["z"]) - z
					var pdist := sqrt(pdx * pdx + pdz * pdz)
					var pslack: float = float(pd["r"]) - pdist
					if pslack > best:
						best = pslack
						var pinv := 1.0 / maxf(pdist, 0.0001)
						out[0] = pslack
						out[1] = -2.0 - float(pi)
						out[2] = 0.0
						out[3] = 0.0
						out[4] = pdist
						out[5] = float(pd["r"])
						out[6] = float(pd["h"])
						out[7] = pdx * pinv
						out[8] = pdz * pinv
						out[9] = 0.0
			var lst: Variant = cells.get(Vector2i(kx + dx, kz + dz))
			if lst == null:
				continue
			for k in (lst as PackedInt32Array):
				var ax := float(pts[k * 2]) * 0.1
				var az := float(pts[k * 2 + 1]) * 0.1
				var ex := float(pts[k * 2 + 2]) * 0.1 - ax
				var ez := float(pts[k * 2 + 3]) * 0.1 - az
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var d2 := ddx * ddx + ddz * ddz
				var ei := pe[k]
				var hw := e_hw[ei]
				if best > -1e8:
					var lim := hw + SHOULDER - best # sólo vale la pena si está más cerca que el mejor hasta ahora
					if lim <= 0.0 or d2 >= lim * lim:
						continue
				var d := sqrt(d2)
				var slack := hw + SHOULDER - d
				if slack > best:
					best = slack
					var inv := 1.0 / maxf(d, 0.0001)
					out[0] = slack
					out[1] = float(ei)
					out[2] = float(k)
					out[3] = t
					out[4] = d
					out[5] = hw
					out[6] = hs[k] + (hs[k + 1] - hs[k]) * t
					out[7] = ddx * inv
					out[8] = ddz * inv
					out[9] = float(edges[ei][5])
	return out

## ¿Hay un camino de la región a la vista de (x, z)?
func near_road(x: float, z: float) -> bool:
	return probe(x, z)[0] > -1e8

## Superficie de la física (código de VehicleParams) en (x, z) fuera de la calzada
func surface_off_road(x: float, z: float) -> int:
	return SURF_OF_BIOME[clampi(biome_at(x, z), 0, SURF_OF_BIOME.size() - 1)]

## Altura y superficie de la física en (x, z)
func ground(x: float, z: float) -> Vector2:
	var h := base_height(x, z)
	var pr := probe(x, z, REACH)
	if pr[0] <= -1e8:
		return Vector2(h, float(surface_off_road(x, z)))
	var hc := _carve(h, pr)
	if pr[0] >= 0.0 and pr[4] <= pr[5]:
		return Vector2(hc, float(ROAD_SURF[clampi(int(pr[9]), 0, 2)]))
	if pr[1] < 0.0 and pr[0] >= -0.05:
		return Vector2(hc, 0.0)
	if pr[0] >= 0.0:
		return Vector2(hc, 2.0) # banquina
	return Vector2(hc, float(surface_off_road(x, z)))

## Metros de pared invisible de la calle ei, medidos desde el borde de la calzada
func wall_of(ei: int) -> float:
	if ei < 0:
		return 0.3 # un playón: la pared es su borde
	return WALL_MONTANA if str(CLS_NAMES[int((edges[ei] as Array)[2])]) == "montana" else WALL

## La pared de la calle ei en el punto (x, z): igual que wall_of, pero pegada a las casas dentro de un pueblo
func wall_at(ei: int, x: float, z: float) -> float:
	if ei >= 0 and in_town(x, z) and str(CLS_NAMES[int((edges[ei] as Array)[2])]) != "montana":
		return TOWN_WALL
	return wall_of(ei)

## Empuja un círculo (x, z, r) hacia adentro del corredor más cercano: (nx, nz, profundidad); profundidad ≤ 0 = nada que empujar
func wall_push(x: float, z: float, r: float) -> Vector3:
	var cm := corridor(x, z, r)
	if cm[0] >= 1e8 or cm[0] <= 0.0:
		return Vector3.ZERO
	return Vector3(cm[1], cm[2], minf(cm[0], 6.0))

## ¿(x, z) está adentro de algún corredor (calle + pared invisible, o playón)?
func in_corridor(x: float, z: float) -> bool:
	return corridor(x, z, 0.0)[0] < 0.0

## La pared es la UNIÓN de los corredores: un auto (círculo de radio r) cabe si cabe en el corredor de ALGUNA calle (calzada + banquina + pared) o de algún playón (radio + 0,3 m).
## Devuelve [penetración mínima (m), nx, nz] hacia el corredor más cercano (penetración ≤ 0 = cabe en alguno); 1e9 si no hay ningún camino ni playón a la vista.
## (Antes se miraba sólo el de mayor holgura: un playón que no se cruzaba con la banquina de la calle por unos centímetros dejaba al auto encerrado.)
func corridor(x: float, z: float, r: float, reach := 30.0) -> PackedFloat64Array:
	var out := PackedFloat64Array([1e9, 0.0, 0.0])
	var kx := int(floor(x / 128.0))
	var kz := int(floor(z / 128.0))
	var fx := fposmod(x, 128.0)
	var fz := fposmod(z, 128.0)
	var x_lo := -1 if fx < reach else 0
	var x_hi := 1 if fx > 128.0 - reach else 0
	var z_lo := -1 if fz < reach else 0
	var z_hi := 1 if fz > 128.0 - reach else 0
	var in_t := -1 # ¿está en un pueblo? (se mira una sola vez y sólo si hace falta)
	for dx in range(x_lo, x_hi + 1):
		for dz in range(z_lo, z_hi + 1):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not pads.is_empty():
				var pl: Variant = pad_cells.get(k2)
				if pl != null:
					for pi in (pl as PackedInt32Array):
						var pd: Dictionary = pads[pi]
						var pdx: float = float(pd["x"]) - x
						var pdz: float = float(pd["z"]) - z
						var pdist := sqrt(pdx * pdx + pdz * pdz)
						var pen := pdist + r - (float(pd["r"]) + 0.3)
						if pen < out[0]:
							var pinv := 1.0 / maxf(pdist, 0.0001)
							out[0] = pen
							out[1] = pdx * pinv
							out[2] = pdz * pinv
			if not jdiscs.is_empty():
				var jl: Variant = jdisc_cells.get(k2)
				if jl != null:
					for ji in (jl as PackedInt32Array):
						var jd: Dictionary = jdiscs[ji]
						var jdx: float = float(jd["x"]) - x
						var jdz: float = float(jd["z"]) - z
						var jdist := sqrt(jdx * jdx + jdz * jdz)
						var jpen := jdist + r - float(jd["r"])
						if jpen < out[0]:
							var jinv := 1.0 / maxf(jdist, 0.0001)
							out[0] = jpen
							out[1] = jdx * jinv
							out[2] = jdz * jinv
			var lst: Variant = cells.get(k2)
			if lst == null:
				continue
			for k in (lst as PackedInt32Array):
				var ax := float(pts[k * 2]) * 0.1
				var az := float(pts[k * 2 + 1]) * 0.1
				var ex := float(pts[k * 2 + 2]) * 0.1 - ax
				var ez := float(pts[k * 2 + 3]) * 0.1 - az
				var l2 := ex * ex + ez * ez
				var t := 0.0
				if l2 > 1e-6:
					t = clampf(((x - ax) * ex + (z - az) * ez) / l2, 0.0, 1.0)
				var ddx := ax + ex * t - x
				var ddz := az + ez * t - z
				var d2 := ddx * ddx + ddz * ddz
				var ei := pe[k]
				var hw := e_hw[ei]
				var big := hw + WALL + r
				if d2 >= big * big and out[0] < 1e8:
					continue # tan lejos que ni la pared más ancha lo alcanza, y ya hay otro corredor a la vista
				var d := sqrt(d2)
				var wl := e_wall[ei]
				if wl > TOWN_WALL:
					if in_t < 0:
						in_t = 1 if in_town(x, z) else 0
					if in_t == 1:
						wl = TOWN_WALL
				var pen2 := d + r - (hw + wl)
				if pen2 < out[0]:
					var inv := 1.0 / maxf(d, 0.0001)
					out[0] = pen2
					out[1] = ddx * inv
					out[2] = ddz * inv
	return out

# ───────────────────────── geometría de las calles ─────────────────────────
func edge_point(ei: int, i: int) -> Vector2:
	var k: int = int((edges[ei] as Array)[6]) + i
	return Vector2(float(pts[k * 2]) * 0.1, float(pts[k * 2 + 1]) * 0.1)

func edge_n(ei: int) -> int:
	return int((edges[ei] as Array)[7])

## Distancia acumulada a cada punto de la calle ei. Se calculan todas en load_file (antes de que arranquen los hilos): durante el juego sólo se leen.
func edge_cum(ei: int) -> PackedFloat32Array:
	if _cum.has(ei):
		return _cum[ei]
	var n := edge_n(ei)
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	var prev := edge_point(ei, 0)
	for i in n:
		var p := edge_point(ei, i)
		acc += prev.distance_to(p)
		out[i] = acc
		prev = p
	_cum[ei] = out
	return out

## Distancia recorrida sobre la calle ei hasta el punto k (índice global) con la fracción t
func arc_at(ei: int, k: int, t: float) -> float:
	var cum := edge_cum(ei)
	var i := k - int((edges[ei] as Array)[6])
	if i + 1 >= cum.size():
		return cum[i]
	return cum[i] + (cum[i + 1] - cum[i]) * t

## Punto y rumbo (vector unitario) a s metros del inicio de la calle ei
func point_at(ei: int, s: float) -> Array:
	var cum := edge_cum(ei)
	s = clampf(s, 0.0, cum[cum.size() - 1])
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var a := edge_point(ei, lo)
	var b := edge_point(ei, hi)
	var seg := maxf(cum[hi] - cum[lo], 1e-4)
	return [a.lerp(b, (s - cum[lo]) / seg), (b - a).normalized(), lo]

func node_pos(ni: int) -> Vector2:
	var n: Array = nodes[ni]
	return Vector2(float(n[1]), float(n[2]))

func node_by_id(nid: String) -> int:
	for i in nodes.size():
		if str((nodes[i] as Array)[0]) == nid:
			return i
	return -1

## El destino con nombre de una ruta en el sentido en que se maneja: (nombre, metros que faltan desde la posición s (m desde el inicio de la calle)); forward = hacia el final de la calle
func edge_dest(ei: int, s: float, forward: bool) -> Array:
	var e: Array = edges[ei]
	if e.size() < 13:
		return ["", 0.0]
	var L := float(e[8])
	if forward:
		return [str(e[9]), maxf(float(e[10]) - s, 0.0)]
	return [str(e[11]), maxf(float(e[12]) - (L - s), 0.0)]

var _box: Dictionary = {}
var _poly: Dictionary = {}

## Rectángulo que contiene a una calle (para el mapa)
func edge_box(ei: int) -> Rect2:
	if _box.has(ei):
		return _box[ei]
	var n := edge_n(ei)
	var p0 := int((edges[ei] as Array)[6])
	var lo := Vector2(1e18, 1e18)
	var hi := Vector2(-1e18, -1e18)
	for i in n:
		var k := p0 + i
		var x := float(pts[k * 2]) * 0.1
		var z := float(pts[k * 2 + 1]) * 0.1
		lo = Vector2(minf(lo.x, x), minf(lo.y, z))
		hi = Vector2(maxf(hi.x, x), maxf(hi.y, z))
	var r := Rect2(lo, hi - lo).grow(8.0)
	_box[ei] = r
	return r

## La calle ei como poligonal para dibujar en el mapa, un punto de cada `step` (con el último siempre)
func edge_poly(ei: int, step: int) -> PackedVector2Array:
	var key := ei * 16 + step
	if _poly.has(key):
		return _poly[key]
	var n := edge_n(ei)
	var p0 := int((edges[ei] as Array)[6])
	var out := PackedVector2Array()
	var i := 0
	while i < n:
		var k := p0 + i
		out.append(Vector2(float(pts[k * 2]) * 0.1, float(pts[k * 2 + 1]) * 0.1))
		i += step
	if (i - step) != n - 1:
		var k2 := p0 + n - 1
		out.append(Vector2(float(pts[k2 * 2]) * 0.1, float(pts[k2 * 2 + 1]) * 0.1))
	_poly[key] = out
	return out

func edge_name(ei: int) -> String:
	return str((edges[ei] as Array)[3])

func edge_cls(ei: int) -> String:
	return CLS_NAMES[int((edges[ei] as Array)[2])]

# ───────────────────────── rutas (GPS) ─────────────────────────
## Camino más corto entre dos puntos por las calles de la región: {pts: PackedVector2Array, len: metros, ok}. Parte de la calle más cercana a cada punto.
func route(a: Vector2, b: Vector2) -> Dictionary:
	var pa := _snap(a)
	var pb := _snap(b)
	if pa.is_empty() or pb.is_empty():
		return {"pts": PackedVector2Array(), "len": 0.0, "ok": false}
	var ea := int(pa[0])
	var eb := int(pb[0])
	var sa := float(pa[1])
	var sb := float(pb[1])
	if ea == eb:
		var seg := _slice(ea, sa, sb)
		return {"pts": _dedup(seg), "len": absf(sb - sa), "ok": true}
	var la := float((edges[ea] as Array)[8])
	var lb := float((edges[eb] as Array)[8])
	# Dijkstra sobre los nodos
	var n := nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1e30)
	var prev_n := PackedInt32Array()
	prev_n.resize(n)
	prev_n.fill(-1)
	var prev_e := PackedInt32Array()
	prev_e.resize(n)
	prev_e.fill(-1)
	var hk := PackedFloat32Array()
	var hv := PackedInt32Array()
	for end in [[int((edges[ea] as Array)[0]), sa], [int((edges[ea] as Array)[1]), la - sa]]:
		var nd: int = end[0]
		var dd: float = end[1]
		if dd < dist[nd]:
			dist[nd] = dd
			prev_n[nd] = -2 - (0 if nd == int((edges[ea] as Array)[0]) else 1) # entra por la calle de origen
			prev_e[nd] = ea
			_heap_push(hk, hv, dd, nd)
	var goal0 := int((edges[eb] as Array)[0])
	var goal1 := int((edges[eb] as Array)[1])
	var best_total := 1e30
	var best_goal := -1
	while hk.size() > 0:
		var top := _heap_pop(hk, hv)
		var u: int = top[1]
		var du: float = top[0]
		if du > dist[u]:
			continue
		if du >= best_total:
			break
		if u == goal0 and du + sb < best_total:
			best_total = du + sb
			best_goal = goal0
		if u == goal1 and du + (lb - sb) < best_total:
			best_total = du + (lb - sb)
			best_goal = goal1
		for ei in (node_edges[u] as PackedInt32Array):
			var e: Array = edges[ei]
			var v: int = int(e[1]) if int(e[0]) == u else int(e[0])
			var nd2 := du + float(e[8])
			if nd2 < dist[v]:
				dist[v] = nd2
				prev_n[v] = u
				prev_e[v] = ei
				_heap_push(hk, hv, nd2, v)
	if best_goal < 0:
		return {"pts": PackedVector2Array(), "len": 0.0, "ok": false}
	# armar la poligonal de atrás para adelante
	var chain: Array = [] # [calle, desde nodo, hasta nodo]
	var cur := best_goal
	while prev_n[cur] >= 0:
		chain.push_front([prev_e[cur], prev_n[cur], cur])
		cur = prev_n[cur]
	var first_node := cur
	var out := PackedVector2Array()
	var a_end0 := int((edges[ea] as Array)[0])
	out.append_array(_slice(ea, sa, 0.0 if first_node == a_end0 else la))
	for c in chain:
		var seg2 := _slice(int(c[0]), 0.0 if int((edges[int(c[0])] as Array)[0]) == int(c[1]) else float((edges[int(c[0])] as Array)[8]), float((edges[int(c[0])] as Array)[8]) if int((edges[int(c[0])] as Array)[0]) == int(c[1]) else 0.0)
		out.append_array(seg2)
	var b_start := 0.0 if best_goal == goal0 else lb
	out.append_array(_slice(eb, b_start, sb))
	return {"pts": _dedup(out), "len": best_total, "ok": true}

## Los empalmes entre calles repiten el punto del cruce: sin duplicados, quien sigue la ruta (la IA, el GPS) ve bien la esquina
func _dedup(p: PackedVector2Array) -> PackedVector2Array:
	var d := PackedVector2Array()
	for q in p:
		if d.is_empty() or d[d.size() - 1].distance_to(q) > 0.75:
			d.append(q)
	return _round_corners(d)

## Las esquinas de los cruces (empalme en T o a 90°) se redondean unos 40 m a cada lado: la IA y el GPS siguen una curva que se puede tomar, no un quiebre
func _round_corners(p: PackedVector2Array) -> PackedVector2Array:
	const D := 40.0
	var n := p.size()
	if n < 3:
		return p
	var out := PackedVector2Array()
	var i := 0
	out.append(p[0])
	i = 1
	while i < n - 1:
		var u := (p[i] - p[i - 1]).normalized()
		var v := (p[i + 1] - p[i]).normalized()
		if u.dot(v) < 0.94: # giro de más de ~20°
			# hacia atrás y hacia adelante D metros por la poligonal
			var ia := i
			var acc := 0.0
			while ia > 0 and acc < D:
				acc += p[ia].distance_to(p[ia - 1])
				ia -= 1
			var ib := i
			acc = 0.0
			while ib < n - 1 and acc < D:
				acc += p[ib].distance_to(p[ib + 1])
				ib += 1
			# se descartan los puntos entre ia e i que ya se agregaron
			while out.size() > 1 and out[out.size() - 1].distance_to(p[i]) < D * 0.9:
				out.remove_at(out.size() - 1)
			var a0: Vector2 = out[out.size() - 1] if out.size() > 0 else p[ia]
			var b0: Vector2 = p[ib]
			var steps := 14
			for k in range(1, steps):
				var t := float(k) / float(steps)
				out.append(a0 * (1.0 - t) * (1.0 - t) + p[i] * 2.0 * t * (1.0 - t) + b0 * t * t)
			i = ib
			out.append(p[i])
			i += 1
			continue
		out.append(p[i])
		i += 1
	if out[out.size() - 1] != p[n - 1]:
		out.append(p[n - 1])
	return out

func _snap(p: Vector2) -> Array:
	var rad := 40.0
	# búsqueda cada vez más amplia: la calle más cercana a menos de ~400 m
	while rad <= 640.0:
		var best := -1
		var bd := rad * rad
		var kx := int(floor(p.x / 128.0))
		var kz := int(floor(p.y / 128.0))
		var c := int(ceil(rad / 128.0))
		var bk := -1
		var bt := 0.0
		for dx in range(-c, c + 1):
			for dz in range(-c, c + 1):
				var lst: Variant = cells.get(Vector2i(kx + dx, kz + dz))
				if lst == null:
					continue
				for k in (lst as PackedInt32Array):
					var ax := float(pts[k * 2]) * 0.1
					var az := float(pts[k * 2 + 1]) * 0.1
					var ex := float(pts[k * 2 + 2]) * 0.1 - ax
					var ez := float(pts[k * 2 + 3]) * 0.1 - az
					var l2 := ex * ex + ez * ez
					var t := 0.0
					if l2 > 1e-6:
						t = clampf(((p.x - ax) * ex + (p.y - az) * ez) / l2, 0.0, 1.0)
					var d2 := (ax + ex * t - p.x) * (ax + ex * t - p.x) + (az + ez * t - p.y) * (az + ez * t - p.y)
					if d2 < bd and str(CLS_NAMES[int((edges[pe[k]] as Array)[2])]) != "calle_x":
						bd = d2
						bk = k
						bt = t
		if bk >= 0:
			var ei := pe[bk]
			return [ei, arc_at(ei, bk, bt)]
		rad *= 2.0
		best = best
	return []

func _slice(ei: int, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cum := edge_cum(ei)
	var n := cum.size()
	out.append(point_at(ei, s0)[0])
	if s1 >= s0:
		for i in n:
			if cum[i] > s0 and cum[i] < s1:
				out.append(edge_point(ei, i))
	else:
		for i in range(n - 1, -1, -1):
			if cum[i] < s0 and cum[i] > s1:
				out.append(edge_point(ei, i))
	out.append(point_at(ei, s1)[0])
	return out

func _heap_push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p

func _heap_pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> Array:
	var rk := hk[0]
	var rv := hv[0]
	var lk: float = hk[hk.size() - 1]
	var lv: int = hv[hv.size() - 1]
	hk.resize(hk.size() - 1)
	hv.resize(hv.size() - 1)
	if hk.size() > 0:
		var i := 0
		var m := hk.size()
		while true:
			var l := i * 2 + 1
			if l >= m:
				break
			var r := l + 1
			var c := r if (r < m and hk[r] < hk[l]) else l
			if hk[c] >= lk:
				break
			hk[i] = hk[c]
			hv[i] = hv[c]
			i = c
		hk[i] = lk
		hv[i] = lv
	return [rk, rv]
