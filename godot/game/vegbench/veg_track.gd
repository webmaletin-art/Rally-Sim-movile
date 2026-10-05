extends "res://game/track/route_track.gd"
## Pista corta de rally del benchmark de vegetación: una vuelta cerrada de ~2,3 km con curvas, subidas y bajadas, tramos abiertos y tramos con vistas largas.
## Usa la clase de pistas por curva del juego (RouteTrack: la misma física y el mismo dibujo del camino) sin tocar routes.json: los puntos están acá.

## VegTrack.create() arma la pista; make_view() (de la clase base) crea copias sin volver a armar (por eso el constructor no arma nada por defecto)
func _init(p_build := false) -> void:
	if not p_build:
		return
	route_id = "vegtest"
	mode = "dirt"
	half_width = 4.6
	shoulder = 2.4
	hills = 0.55
	n_samples = 1100
	# curva base en polar con tres lóbulos + algunos giros cerrados; la altura sube y baja suave (colina larga y un valle)
	var pts := 34
	for i in pts:
		var th := TAU * float(i) / float(pts)
		var r := 330.0 * (1.0 + 0.30 * sin(2.0 * th + 0.4) + 0.14 * sin(3.0 * th + 1.7) + 0.05 * sin(7.0 * th))
		var x := r * cos(th) * 1.35
		var z := r * sin(th) * 0.95
		var y := 30.0 + 16.0 * sin(th * 2.0 + 0.5) + 6.0 * sin(th * 3.0 + 2.0)
		ctrl.append(Vector3(x, y, z))
	_build()

static func create() -> Object:
	return (load("res://game/vegbench/veg_track.gd") as GDScript).new(true)
