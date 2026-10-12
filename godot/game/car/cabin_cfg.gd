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
	"hatch": {"wmul": 1.30, "eye_h": 0.27, "back": -1.0, "halfW": 0.72, "cage": false},
	"hatch2": {"wmul": 1.30, "eye_h": 0.27, "back": -1.15, "halfW": 0.68, "cage": true},
	"torito": {"wmul": 1.30, "eye_h": 0.28, "back": -1.2, "cage": false},
	"clasico60": {"wmul": 1.30, "eye_h": 0.24, "back": -1.1, "cage": false},
	"muscle": {"wmul": 1.35, "eye_h": 0.22, "back": -1.15, "cage": false},
	"rally80": {"wmul": 1.30, "eye_h": 0.25, "back": -1.1, "cage": true},
	"buggy": {"cage": false, "cowlZ": 0.45, "cowlY": 0.9, "eyeZ": -0.35, "eyeY": 1.32, "back": -1.2, "halfW": 0.6},
	"pickup": {"wmul": 1.30, "eye_h": 0.30, "back": -1.15, "cage": false},
	"camo": {"wmul": 1.30, "eye_h": 0.30, "back": -1.2, "cage": false},
	"kodiak": {"wmul": 1.25, "eye_h": 0.30, "back": -1.05, "cage": true},
	"suv": {"wmul": 1.30, "eye_h": 0.28, "back": -1.3, "cage": false},
	"truck": {"wmul": 1.20, "eye_h": 0.36, "eye_back": 0.30, "back": 1.9, "halfW": 1.0, "cage": false},
	"titan": {"wmul": 1.12, "eye_h": 0.36, "eye_back": 0.30, "back": 0.45, "cage": false},
	"gt": {"wmul": 1.45, "back": -1.0, "eye_h": 0.20, "cage": false},
	"kl5": {"wmul": 1.40, "eye_h": 0.20, "back": -1.05, "cage": false},
	"trilux": {"wmul": 1.45, "eye_h": 0.22, "back": -1.45, "cage": false},
	"trilux_s": {"wmul": 1.45, "eye_h": 0.22, "back": -1.45, "cage": false},
	"trilux_gt": {"wmul": 1.45, "eye_h": 0.22, "back": -1.45, "cage": true},
	"pro_gt": {"wmul": 1.45, "eye_h": 0.22, "back": -1.0, "halfW": 0.74, "cage": true},
	"gt3": {"wmul": 1.30, "eye_h": 0.20, "back": -0.9, "halfW": 0.66, "cage": true},
	"veltor": {"wmul": 1.60, "eye_h": 0.20, "back": -0.95, "cage": false},
	"veltor_s": {"wmul": 1.60, "eye_h": 0.20, "back": -0.95, "cage": false},
	"veltor_gtr": {"wmul": 1.55, "eye_h": 0.20, "back": -0.95, "cage": true},
	"moust": {"wmul": 1.50, "eye_h": 0.21, "back": -1.0, "halfW": 0.74, "cage": true},
	"hyper": {"wmul": 1.30, "back": -0.7, "eye_h": 0.2, "cage": false},
	"genesis": {"cowlZ": 0.98, "cowlY": 1.12, "wsTopZ": 0.30, "wsTopY": 1.31, "eyeY": 1.08, "eyeZ": -0.12, "roofY": 1.36, "halfW": 0.74, "back": -1.1, "wsHwB": 0.72, "wsHwT": 0.62, "cage": false},
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
		var pl: Array = gd["poly"]
		if absf(float(ws[0][0]) - float(ws[1][0])) < 0.35: # parabrisas medido sobre un perfil casi vertical (capó alto): se usa el polígono del vidrio
			ws = [pl[0], pl[1]]
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
