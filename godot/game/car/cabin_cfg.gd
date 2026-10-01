extends RefCounted
## Medidas del habitáculo de cada auto con carrocería propia, calculadas con las medidas del GLB (models/cars/<id>.json:
## parabrisas, techo y ancho de la cabina) más unos ajustes por auto (OVR). El habitáculo de los autos viejos (Volt, Bisonte) sigue
## usando la tabla CABIN de cockpit.gd.
## Salida (coordenadas del auto, y desde el piso):
##   eyeY, eyeZ  ojos del piloto · cowlZ, cowlY  base del parabrisas (arriba del capó) · wsTopZ, wsTopY  borde de arriba del parabrisas
##   roofY  techo · halfW  semiancho del habitáculo (el cockpit lo agranda 12 %) · belt  alto del borde de las ventanillas
##   backZ  pared de atrás del habitáculo · floorY  piso · hipY  altura de la cadera sentada · xD  distancia de las butacas al centro
##   wsHwB, wsHwT  semiancho del parabrisas abajo y arriba · open  true = sin techo ni vidrios (buggy) · mirrors  false = espejos propios del GLB

const CarVisual := preload("res://game/car/car_visual.gd")

## Ajustes por auto. Claves (todas opcionales): eye_back (m detrás del borde del parabrisas: 0.46) · eye_h (techo − ojos: 0.27) · wmul (ancho del
## habitáculo = cab_hw · wmul) · back (z de la pared de atrás) · belt · hip_drop · extra: valores que pisan los calculados
const OVR := {
	"pickup": {"wmul": 1.30, "eye_h": 0.30, "back": -1.15, "cage": false},
	"truck": {"wmul": 1.12, "eye_h": 0.36, "eye_back": 0.30, "back": 1.9, "cage": false},
	"suv": {"wmul": 1.20, "eye_h": 0.28, "back": -0.95, "cage": false},
	"hatch": {"wmul": 1.25, "eye_h": 0.27, "back": -0.95, "cage": true},
	"muscle": {"wmul": 1.45, "back": -1.15, "eye_h": 0.21, "cage": false},
	"gt": {"wmul": 1.45, "back": -0.95, "eye_h": 0.19, "cage": false},
	"gt3": {"wmul": 1.25, "back": -0.9, "eye_h": 0.2, "cage": true},
	"hyper": {"wmul": 1.30, "back": -0.7, "eye_h": 0.2, "cage": false},
	"buggy": {"cage": false, "cowlZ": 0.45, "cowlY": 0.9, "eyeZ": -0.35, "eyeY": 1.32, "back": -1.2, "halfW": 0.6},
}

static func has(id: String) -> bool:
	return CarVisual.has_own_model(id)

static func build(id: String) -> Dictionary:
	var meta := CarVisual.load_meta(id)
	var o: Dictionary = OVR.get(id, {})
	var lift := float(meta.get("lift", 0.1))
	var c := {}
	var g: Variant = meta.get("glass")
	if g is Dictionary:
		var gd: Dictionary = g
		var ws: Array = gd["ws"]
		var cab := float(gd["cab_hw"])
		var roof := float(gd["roof_y"])
		c["cowlZ"] = float(ws[0][0])
		c["cowlY"] = float(ws[0][1])
		c["wsTopZ"] = float(ws[1][0])
		c["wsTopY"] = float(ws[1][1])
		c["roofY"] = roof + 0.03
		c["halfW"] = cab * float(o.get("wmul", 1.3)) / 1.12
		c["eyeZ"] = float(ws[1][0]) - float(o.get("eye_back", 0.46))
		c["eyeY"] = roof - float(o.get("eye_h", 0.27))
		c["backZ"] = float(o.get("back", float((gd["rg"] as Array)[1][0]) + 0.1))
		c["wsHwB"] = cab * float(gd.get("ws_w0", 1.22))
		c["wsHwT"] = cab * float(gd.get("ws_w1", 0.92))
		c["open"] = false
		c["mirrors"] = false
		var pl: Array = gd["poly"]
		c["belt"] = minf(float(pl[0][1]), float(pl[3][1])) - 0.03 # borde de abajo de las ventanillas del GLB
	else:
		# buggy: jaula abierta, sin vidrios ni techo
		c["cowlZ"] = float(o.get("cowlZ", 0.72))
		c["cowlY"] = float(o.get("cowlY", 0.95))
		c["wsTopZ"] = float(o.get("cowlZ", 0.72)) - 0.2
		c["wsTopY"] = float(o.get("cowlY", 0.95)) + 0.25
		c["roofY"] = float(meta.get("H", 1.75)) - 0.05
		c["halfW"] = float(o.get("halfW", 0.62))
		c["eyeZ"] = float(o.get("eyeZ", -0.05))
		c["eyeY"] = float(o.get("eyeY", 1.12))
		c["backZ"] = float(o.get("back", -0.75))
		c["wsHwB"] = 0.6
		c["wsHwT"] = 0.6
		c["open"] = true
		c["mirrors"] = false
	for k in o:
		if c.has(k) and k != "cage":
			c[k] = o[k]
	var eyeY := float(c["eyeY"])
	var floor_y := maxf(eyeY - 1.05, lift + 0.08)
	c["floorY"] = floor_y
	c["hipY"] = maxf(eyeY - 0.66, floor_y + 0.17) if eyeY - 1.05 < lift + 0.08 else eyeY - 0.70
	if o.has("belt"):
		c["belt"] = float(o["belt"])
	elif not c.has("belt"):
		c["belt"] = float(c["cowlY"]) - 0.02
	c["xD"] = clampf(float(c["halfW"]) * 1.12 * 0.5, 0.30, 0.45)
	c["own"] = true
	c["cage"] = bool(o.get("cage", true))
	return c
