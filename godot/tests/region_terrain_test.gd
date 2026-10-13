## El terreno de la región no tapa los caminos ni deja casas, cercos y guardarraíles sobre la calzada.
## Antes la malla del terreno (grilla de 8, 16 o 32 m) se levantaba por encima del asfalto en las laderas (hasta 7 m en el nivel lejano): se veía tierra y pasto sobre la ruta, con dientes de sierra en los bordes.
## Y los cercos de los pueblos, las casas y los guardarraíles pisaban las calles que cruzan.
## Uso: godot --headless --path godot --script res://tests/region_terrain_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const RegionData := preload("res://game/region/region_data.gd")

var fail := false
var rg: RegionData
var rw

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Altura de la malla del terreno (caras que miran hacia arriba) en (x, z); NAN si ese punto no cae en ninguna
func _tri_y(tris: Array, x: float, z: float) -> float:
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
		var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
		var l3 := 1.0 - l1 - l2
		if l1 >= -1e-6 and l2 >= -1e-6 and l3 >= -1e-6:
			return l1 * a.y + l2 * b.y + l3 * c.y
	return NAN

## Caras del terreno por celda de la grilla
func _cells(soup, x0: float, z0: float, step: float) -> Dictionary:
	var cells := {}
	for i in range(0, soup.v.size(), 3):
		if soup.n[i].y < 0.5:
			continue
		var a: Vector3 = soup.v[i]
		var b: Vector3 = soup.v[i + 1]
		var c: Vector3 = soup.v[i + 2]
		var cx := int(floor(((a.x + b.x + c.x) / 3.0 - x0) / step))
		var cz := int(floor(((a.z + b.z + c.z) / 3.0 - z0) / step))
		var ck := cz * 1000 + cx
		if not cells.has(ck):
			cells[ck] = []
		(cells[ck] as Array).append([a, b, c])
	return cells

func _init() -> void:
	var track = CityTrack.new()
	track.build_world()
	rw = track.world_node.get_node("region")
	rg = track.region
	var chunks := {}
	for k in rg.pts.size() / 2:
		chunks[Vector2i(int(floor(float(rg.pts[k * 2]) * 0.1 / 256.0)), int(floor(float(rg.pts[k * 2 + 1]) * 0.1 / 256.0)))] = true
	var keys: Array = chunks.keys()
	keys.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	_check(keys.size() > 5000, "cuadrados con caminos: %d" % keys.size())
	# ── 1. el terreno no tapa la calzada (un cuadrado de cada 60, en los tres niveles de detalle)
	for tier in 3:
		var step: float = [8.0, 16.0, 32.0][tier]
		var n_pts := 0
		var n_bad := 0
		var worst := 0.0
		var at := Vector2.ZERO
		var idx := 0
		for k in keys:
			idx += 1
			if idx % 60 != 0:
				continue
			var x0 := float(k.x) * 256.0
			var z0 := float(k.y) * 256.0
			var soup = rw.CityWorld.Soup.new()
			rw._terrain(soup, x0, z0, step, tier)
			var cells := _cells(soup, x0, z0, step)
			for cxr in range(int(floor(x0 / 128.0)), int(floor((x0 + 256.0) / 128.0)) + 1):
				for czr in range(int(floor(z0 / 128.0)), int(floor((z0 + 256.0) / 128.0)) + 1):
					var lst: Variant = rg.cells.get(Vector2i(cxr, czr))
					if lst == null:
						continue
					for kk in (lst as PackedInt32Array):
						var ax := float(rg.pts[kk * 2]) * 0.1
						var az := float(rg.pts[kk * 2 + 1]) * 0.1
						if ax < x0 or ax >= x0 + 256.0 or az < z0 or az >= z0 + 256.0:
							continue
						var ei: int = rg.pe[kk]
						var e: Array = rg.edges[ei]
						var i := kk - int(e[6])
						if i + 1 >= int(e[7]):
							continue
						var a2 := rg.edge_point(ei, i)
						var b2 := rg.edge_point(ei, i + 1)
						if a2.distance_squared_to(b2) < 1e-4:
							continue
						var nrm := Vector2(-(b2 - a2).normalized().y, (b2 - a2).normalized().x)
						var hw: float = rg.e_hw[ei]
						var off: float = rw._road_off(ei, int(e[5]))
						for t in [0.0, 0.5]:
							var pc: Vector2 = a2.lerp(b2, t)
							var yr: float = lerpf(rg.hs[kk], rg.hs[kk + 1], t) + 0.03 + off
							for lat in [-0.95, -0.5, 0.0, 0.5, 0.95]:
								var p: Vector2 = pc + nrm * (hw * float(lat))
								if p.x < x0 or p.x >= x0 + 256.0 or p.y < z0 or p.y >= z0 + 256.0:
									continue
								var pr := rg.probe(p.x, p.y, 10.0, false)
								if int(pr[1]) != ei:
									continue
								var tl: Variant = cells.get(int(floor((p.y - z0) / step)) * 1000 + int(floor((p.x - x0) / step)))
								if tl == null:
									continue
								var ym := _tri_y(tl, p.x, p.y)
								if is_nan(ym):
									continue
								n_pts += 1
								if ym - yr > 0.02:
									n_bad += 1
									if ym - yr > worst:
										worst = ym - yr
										at = p
		_check(n_pts > 800 and n_bad == 0, "nivel %d (grilla de %.0f m): el terreno no pasa por encima de la calzada (%d puntos mirados, %d tapados, peor %.2f m en (%.0f, %.0f))" % [tier, step, n_pts, n_bad, worst, at.x, at.y])
	# ── 2. los cuadrados vecinos coinciden en los vértices del borde (si no, el terreno tendría escalones entre cuadrados)
	var pairs := 0
	var worst_d := 0.0
	var idx2 := 0
	for k in keys:
		idx2 += 1
		if idx2 % 400 != 0:
			continue
		var kb := Vector2i(k.x + 1, k.y)
		if not chunks.has(kb):
			continue
		for tier in 3:
			var step2: float = [8.0, 16.0, 32.0][tier]
			var sa = rw.CityWorld.Soup.new()
			var sb = rw.CityWorld.Soup.new()
			rw._terrain(sa, float(k.x) * 256.0, float(k.y) * 256.0, step2, tier)
			rw._terrain(sb, float(kb.x) * 256.0, float(kb.y) * 256.0, step2, tier)
			var xa := float(kb.x) * 256.0
			var ya := {}
			for i in range(0, sa.v.size(), 3):
				if sa.n[i].y < 0.5:
					continue
				for j in 3:
					var v: Vector3 = sa.v[i + j]
					if absf(v.x - xa) < 0.01:
						ya[int(round(v.z * 10.0))] = v.y
			for i in range(0, sb.v.size(), 3):
				if sb.n[i].y < 0.5:
					continue
				for j in 3:
					var v2: Vector3 = sb.v[i + j]
					if absf(v2.x - xa) < 0.01 and ya.has(int(round(v2.z * 10.0))):
						worst_d = maxf(worst_d, absf(float(ya[int(round(v2.z * 10.0))]) - v2.y))
			pairs += 1
	_check(pairs >= 15 and worst_d < 0.01, "los vértices de los bordes de cuadrados vecinos coinciden (%d pares, peor diferencia %.3f m)" % [pairs, worst_d])
	# ── 3. casas, cercos y guardarraíles no pisan una calzada (un cuadrado de pueblo de cada 6)
	var tkeys: Array = rw._places_by_chunk.keys()
	tkeys.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var tot := 0
	var on_road := 0
	var shown: Array = []
	var idx3 := 0
	for k in tkeys:
		idx3 += 1
		if idx3 % 6 != 0:
			continue
		var d: Dictionary = rw._build(k, 0)
		for nm in ["buildings", "rails"]:
			var soup2 = d[nm]
			var seen := {}
			for v in soup2.v:
				var key := Vector2i(int(round(v.x * 2.0)), int(round(v.z * 2.0)))
				if seen.has(key):
					continue
				seen[key] = true
				var pr2 := rg.probe(v.x, v.z, 10.0, false)
				if pr2[0] <= -1e8:
					continue
				tot += 1
				if pr2[4] - pr2[5] < -0.25:
					on_road += 1
					if shown.size() < 4:
						shown.append("%s (%.0f, %.0f)" % [nm, v.x, v.z])
	_check(tot > 20000 and on_road == 0, "casas, cercos y guardarraíles fuera de la calzada (%d vértices mirados, %d adentro: %s)" % [tot, on_road, str(shown)])
	# ── 4. ninguna casa ni cerco sobre una gasolinera, una gomería ni su camino de acceso (un cuadrado con playones de cada 3)
	var pkeys := {}
	for pd in rg.pads:
		pkeys[Vector2i(int(floor(float(pd["x"]) / 256.0)), int(floor(float(pd["z"]) / 256.0)))] = true
	var pk: Array = pkeys.keys()
	pk.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var ptot := 0
	var pbad := 0
	var pshown: Array = []
	var idx4 := 0
	for k in pk:
		idx4 += 1
		if idx4 % 3 != 0:
			continue
		var d2: Dictionary = rw._build(k, 0)
		var seen2 := {}
		for v in (d2["buildings"]).v:
			var key2 := Vector2i(int(round(v.x * 2.0)), int(round(v.z * 2.0)))
			if seen2.has(key2):
				continue
			seen2[key2] = true
			ptot += 1
			var pl: Variant = rg.pad_cells.get(Vector2i(int(floor(v.x / 128.0)), int(floor(v.z / 128.0))))
			if pl == null:
				continue
			for pi in (pl as PackedInt32Array):
				var pdd: Dictionary = rg.pads[pi]
				if Vector2(float(pdd["x"]) - v.x, float(pdd["z"]) - v.z).length() < float(pdd["r"]) - 0.5:
					pbad += 1
					if pshown.size() < 4:
						pshown.append("(%.0f, %.0f)" % [v.x, v.z])
					break
	_check(ptot > 5000 and pbad == 0, "casas y cercos fuera de los playones de las estaciones y gomerías (%d vértices mirados, %d adentro: %s)" % [ptot, pbad, str(pshown)])
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
