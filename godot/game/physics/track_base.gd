## Interfaz de pista para la física: altura del piso y tipo de superficie en un punto.
## Las pistas reales (circuitos, mundo abierto, ciudades) heredan de esta clase.
extends RefCounted

## Multiplicador de agarre global de la pista (lluvia, etc.)
var grip_mul := 1.0

## Devuelve Vector2(altura, id_de_superficie): 0 asfalto · 1 tierra · 2 banquina · 3 pasto · 4 afuera · 5 barro
func ground_info(_x: float, _z: float) -> Vector2:
	return Vector2(0.0, 0.0)

func ground_y(x: float, z: float) -> float:
	return ground_info(x, z).x
