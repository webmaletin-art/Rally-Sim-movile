extends RefCounted
## Corte del terreno para que la malla nunca tape un camino ([B] 19/10/2026). Lo usan el terreno de la región (RegionWorld._cap_point) y el de la ciudad (CityWorld._city_caps).
## La malla es una grilla de triángulos (diagonal de (ix, iz) a (ix+1, iz+1)); un camino de 7–12 m que cruza una ladera no cabe en una grilla de 8 o 16 m: entre un vértice sobre la calzada y
## otro más alto afuera, la malla queda por encima del asfalto (tierra y pasto sobre la ruta). Cada punto de la calzada pide que la malla pase por debajo y se baja el «nivel de corte»
## de los vértices del triángulo que lo contiene (los más altos primero; los que ya están abajo no se tocan).

## Un punto (px, pz) que tiene que quedar por encima de la malla: si la malla pasa por arriba de `target` se baja el nivel de corte de los vértices del triángulo.
## El camino tiene pendiente (gx, gz son los metros que sube por metro hacia cada eje): se trabaja con las alturas de los vértices «sin la pendiente» (como si el camino fuera horizontal) y el nivel
## de corte se vuelve a inclinar con el camino. Antes todos los vértices se bajaban al mismo nivel, el del punto más bajo del camino dentro del triángulo: en una subida del 7 % y una grilla de 8 m
## el terreno quedaba hasta medio metro por debajo de la calzada (el asfalto parecía flotar y «doblado»).
static func point(px: float, pz: float, target: float, gx: float, gz: float, ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array, cap: PackedFloat32Array) -> void:
	var fx := (px - ox) / step
	var fz := (pz - oz) / step
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	if ix < 0 or iz < 0 or ix >= w - 1 or iz >= w - 1:
		return
	var u := fx - float(ix)
	var v := fz - float(iz)
	var j1 := iz * w + ix
	var j2: int
	var l1: float
	var l2: float
	var l3: float
	var x1 := ox + float(ix) * step
	var z1 := oz + float(iz) * step
	var x3 := x1 + step
	var z3 := z1 + step
	var x2: float
	var z2: float
	if u >= v:
		j2 = j1 + 1
		l1 = 1.0 - u
		l2 = u - v
		l3 = v
		x2 = x3
		z2 = z1
	else:
		j2 = j1 + w
		l1 = 1.0 - v
		l2 = v - u
		l3 = u
		x2 = x1
		z2 = z3
	var j3 := j1 + w + 1
	if l1 * y0[j1] + l2 * y0[j2] + l3 * y0[j3] <= target:
		return
	# alturas sin la pendiente del camino (distancia al punto medida sobre el camino × pendiente)
	var s1 := gx * (x1 - px) + gz * (z1 - pz)
	var s2 := gx * (x2 - px) + gz * (z2 - pz)
	var s3 := gx * (x3 - px) + gz * (z3 - pz)
	var y1 := y0[j1] - s1
	var y2 := y0[j2] - s2
	var y3 := y0[j3] - s3
	# se ordenan los tres vértices de menor a mayor altura
	var t_j: int
	var t_y: float
	var t_l: float
	var t_s: float
	if y1 > y2:
		t_j = j1; t_y = y1; t_l = l1; t_s = s1
		j1 = j2; y1 = y2; l1 = l2; s1 = s2
		j2 = t_j; y2 = t_y; l2 = t_l; s2 = t_s
	if y2 > y3:
		t_j = j2; t_y = y2; t_l = l2; t_s = s2
		j2 = j3; y2 = y3; l2 = l3; s2 = s3
		j3 = t_j; y3 = t_y; l3 = t_l; s3 = t_s
		if y1 > y2:
			t_j = j1; t_y = y1; t_l = l1; t_s = s1
			j1 = j2; y1 = y2; l1 = l2; s1 = s2
			j2 = t_j; y2 = t_y; l2 = t_l; s2 = t_s
	# nivel de corte L: l1·min(y1, L) + l2·min(y2, L) + l3·min(y3, L) = target
	var lvl := target
	if lvl > y1:
		var s_low := l1 * y1
		lvl = (target - s_low) / maxf(l2 + l3, 1.0e-6)
		if lvl > y2:
			s_low += l2 * y2
			lvl = (target - s_low) / maxf(l3, 1.0e-6)
	if l1 > 1.0e-4:
		cap[j1] = minf(cap[j1], lvl + s1)
	if l2 > 1.0e-4:
		cap[j2] = minf(cap[j2], lvl + s2)
	if l3 > 1.0e-4:
		cap[j3] = minf(cap[j3], lvl + s3)
