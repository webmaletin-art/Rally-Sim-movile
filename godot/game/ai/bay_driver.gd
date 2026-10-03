extends RefCounted
## Piloto automático de la entrada a un taller: el auto espera quieto mientras se abre el portón y después avanza derecho hacia adentro.

var hb := false
var nitro := false
var enabled := true
var go := false

func update(ph, _dt: float) -> Vector3:
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	if not go:
		return Vector3(0.0, 1.0, 0.0)
	return Vector3(0.6 if spd < 5.0 else 0.0, 0.0, 0.0)
