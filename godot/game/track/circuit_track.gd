extends "res://game/physics/track_base.gd"
## Circuito cerrado de prueba (anillo con curvas), plano. Sirve para medir rendimiento y probar los autos.
## El camino tiene ancho HALF_W*2; después viene la banquina y después pasto.

const HALF_W := 5.5
const SHOULDER := 3.0
const N_POINTS := 480

func radius(th: float) -> float:
	return 300.0 + 55.0 * sin(3.0 * th) + 25.0 * sin(5.0 * th + 1.0) + 18.0 * sin(2.0 * th + 2.0)

func center(th: float) -> Vector2:
	var r := radius(th)
	return Vector2(r * cos(th), r * sin(th))

func tangent(th: float) -> Vector2:
	var e := 0.001
	return (center(th + e) - center(th - e)).normalized()

func ground_info(x: float, z: float) -> Vector2:
	var th := atan2(z, x)
	var d := absf(sqrt(x * x + z * z) - radius(th))
	if d < HALF_W:
		return Vector2(0.0, 0.0)
	if d < HALF_W + SHOULDER:
		return Vector2(0.0, 2.0)
	return Vector2(0.0, 3.0)

## Pose de largada en la fila "slot" (0 = adelante): x, z, yaw
func start_pose(slot: int) -> Array:
	var th := -0.03 * float(floori(slot / 2.0) + 1)
	var c := center(th)
	var t := tangent(th)
	var left := Vector2(-t.y, t.x) # a la izquierda del sentido de marcha (x izquierda, z adelante → normal en el plano)
	var side := 1.0 if slot % 2 == 0 else -1.0
	var p := c + left * side * 2.6
	return [p.x, p.y, atan2(t.x, t.y)]

## Vértices del asfalto y líneas para dibujar el camino (una sola malla con colores por vértice)
func build_road_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var asphalt := Color(0.16, 0.165, 0.18)
	var shoulder_c := Color(0.30, 0.27, 0.22)
	var line_c := Color(0.85, 0.85, 0.82)
	var dash_c := Color(0.9, 0.78, 0.2)
	for i in N_POINTS:
		var th0 := TAU * float(i) / N_POINTS
		var th1 := TAU * float(i + 1) / N_POINTS
		var c0 := center(th0)
		var c1 := center(th1)
		var t0 := tangent(th0)
		var t1 := tangent(th1)
		var n0 := Vector2(-t0.y, t0.x)
		var n1 := Vector2(-t1.y, t1.x)
		var bands := [
			[-HALF_W - SHOULDER, -HALF_W, shoulder_c, 0.02], [-HALF_W, HALF_W, asphalt, 0.03], [HALF_W, HALF_W + SHOULDER, shoulder_c, 0.02],
			[-HALF_W + 0.25, -HALF_W + 0.55, line_c, 0.045], [HALF_W - 0.55, HALF_W - 0.25, line_c, 0.045]]
		if i % 6 < 3:
			bands.append([-0.12, 0.12, dash_c, 0.045])
		for b in bands:
			var a: Vector2 = c0 + n0 * float(b[0])
			var bb: Vector2 = c0 + n0 * float(b[1])
			var c: Vector2 = c1 + n1 * float(b[0])
			var d: Vector2 = c1 + n1 * float(b[1])
			var y: float = b[3]
			var base := verts.size()
			verts.append_array([Vector3(a.x, y, a.y), Vector3(bb.x, y, bb.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y)])
			for k in 4:
				cols.append(b[2])
				norms.append(Vector3.UP)
			# orientación: cara hacia arriba (sentido horario visto desde arriba en Godot)
			idx.append_array([base, base + 2, base + 1, base + 1, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
