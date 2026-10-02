extends "res://game/track/route_track.gd"
## Vórtice de Ensueño: un circuito de ~9,7 km alrededor de un agujero negro, con una subida de 300 m, una cresta con curva peraltada, una
## bajada brutal y una vuelta inmensa para volver. Es una RouteTrack común (misma física, IA y sesiones) con tres agregados:
##  · peralte: en las curvas el camino se inclina hacia adentro (hasta ~6°) y la física lo siente porque cada rueda lee su altura;
##  · suelo plano a los costados: banquina y campo de flores a la altura del borde del camino (sin zanja), sobre una meseta ancha;
##  · límite lateral por muestra: se puede salir del asfalto y pisar las flores, pero a VERGE metros del borde hay una pared invisible
##    que te devuelve a la pista (los árboles y los arbustos altos la tapan a la vista).
## El dibujo lo hace dream_world.gd.

const BANK_K := 28.0 # pendiente lateral por curvatura (1/m): una curva de 300 m de radio da ~5°
const BANK_MAX := 0.11
const VERGE := 7.5 # franja de campo que se puede pisar después de la banquina

var bank := PackedFloat32Array() # pendiente lateral por muestra (positiva = el lado derecho más alto)

func _init(p_route := "", p_mode := "asphalt", reverse := false, p_hills := 0.0) -> void:
	super(p_route, p_mode, reverse, p_hills)
	if n <= 0:
		return
	_make_bank()
	var lim := half_width + shoulder + VERGE
	wall_l.resize(n)
	wall_r.resize(n)
	for i in n:
		wall_l[i] = lim
		wall_r[i] = lim

## Peralte por curvatura (suavizado): hacia adentro de la curva
func _make_bank() -> void:
	var k := PackedFloat32Array()
	k.resize(n)
	for i in n:
		var a := tangents[posmod(i - 1, n)]
		var b := tangents[(i + 1) % n]
		var ds := maxf(0.5, samples[posmod(i - 1, n)].distance_to(samples[(i + 1) % n]))
		k[i] = (b - a).dot(laterals[i]) / ds # > 0: curva a la derecha
	bank.resize(n)
	var w := 12
	for i in n:
		var s := 0.0
		for j in range(-w, w + 1):
			s += k[posmod(i + j, n)]
		bank[i] = clampf(-s / float(2 * w + 1) * BANK_K, -BANK_MAX, BANK_MAX)

func _copy_view(v: Object) -> void:
	v.bank = bank

func _bank_here() -> float:
	return lerpf(bank[r_idx], bank[(r_idx + 1) % n], r_t)

## Altura: sobre el camino y la banquina sigue el peralte; más afuera queda plano a la altura del borde (meseta de flores)
func _height_at(x: float, z: float) -> float:
	nearest(x, z)
	var se := half_width + shoulder
	return r_y + _bank_here() * clampf(r_lat, -se, se)

func ground_info(x: float, z: float) -> Vector2:
	var y := _height_at(x, z)
	var surf := _surf_of(absf(r_lat), r_idx)
	return Vector2(y + _micro_bump(x, z, surf), float(surf))

func ground_smooth(x: float, z: float) -> float:
	return _height_at(x, z)
