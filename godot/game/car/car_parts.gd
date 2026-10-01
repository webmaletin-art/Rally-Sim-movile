extends RefCounted
## Piezas que se arman por código en los autos con carrocería propia: ruedas (goma, llanta), discos y pinzas de freno,
## resortes con amortiguador y brazos de suspensión. Todo cuelga de la carrocería (Body) del CarVisual.
## Los colores de la llanta, el resorte, la pinza y el disco se pueden cambiar desde el taller (set_colors).

const WheelGen := preload("res://game/car/wheel_gen.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

const DISC_TINTS := {"steel": Color(0.62, 0.64, 0.67), "dark": Color(0.22, 0.23, 0.25), "gold": Color(0.78, 0.62, 0.22), "carbon": Color(0.10, 0.10, 0.11)}

var wheels: Array = [] # {steer, spin, front, angle, side, low, up, arm}
var mats := {}
var lo := false
var meta: Dictionary = {}
var _susp_type := "car"

## defs: [[x, z, delantera]]; V: parámetros del auto; body: nodo al que cuelga todo
func build(body: Node3D, V: RefCounted, p_meta: Dictionary, p_lo: bool, rim_col: Color) -> void:
	lo = p_lo
	meta = p_meta
	var W: Dictionary = meta["wheel"]
	_susp_type = str(W.get("susp", "car"))
	_make_mats(rim_col)
	var R: float = V.wheelRadius
	var rr: float = V.rimRadius
	var a: float = V.wheelBase * (1.0 - V.weightFront)
	var b: float = V.wheelBase * V.weightFront
	var defs := [[V.trackF / 2.0, a, true], [-V.trackF / 2.0, a, true], [V.trackR / 2.0, -b, false], [-V.trackR / 2.0, -b, false]]
	var arch_top: float = float(meta.get("arch_top", 2.0 * R))
	var tread := str(W["tread"])
	for d in defs:
		var front: bool = d[2]
		var side: float = -1.0 if float(d[0]) < 0.0 else 1.0
		var tw: float = float(W["tw"]) if front else float(W["tw_r"])
		var wr := tw * 0.78
		var steer := Node3D.new()
		steer.position = Vector3(d[0], R, d[1])
		body.add_child(steer)
		var spin := Node3D.new()
		steer.add_child(spin)
		var asm := Node3D.new()
		asm.scale = Vector3(side, 1.0, 1.0)
		spin.add_child(asm)
		if not OS.has_environment("CAR_NOWHEEL"):
			_mi(asm, WheelGen.tire_mesh(R, rr, tw, tread, lo), {"tire": mats["tire"]})
			_mi(asm, WheelGen.rim_mesh(str(W["style"]), rr, wr, lo), {"rim": mats["rim"], "dark": mats["dark"], "steel": mats["steel"]})
		# freno de disco (atrás de la llanta) y pinza (no gira)
		if not lo: # de lejos (rivales) el disco y la pinza no se ven: se ahorran 3 llamadas de dibujo por rueda
			var r_out := (rr - 0.012) * 0.90
			var r_in := r_out * 0.45
			var xd := wr * 0.5 - clampf(wr * 0.26, 0.03, 0.075) - 0.06
			var disc := _mi(asm, WheelGen.disc_mesh(r_out, r_in, 0.026), {"disc": mats["disc"], "dark": mats["dark"]})
			disc.position.x = xd
			var cal_root := Node3D.new()
			cal_root.scale = Vector3(side, 1.0, 1.0)
			steer.add_child(cal_root)
			var cal := _mi(cal_root, WheelGen.caliper_mesh(r_out, r_out - 0.075, 0.026, PI / 2.0 + (0.15 if front else 0.55), PI / 2.0 + (0.85 if front else 1.25)), {"caliper": mats["caliper"]})
			cal.position.x = xd
		var w := {"steer": steer, "spin": spin, "front": front, "angle": 0.0, "side": side, "tw": tw, "x": float(d[0]), "z": float(d[1])}
		if not lo and not OS.has_environment("CAR_NOSUSP"):
			_make_susp(body, w, R, tw, arch_top)
		wheels.append(w)
	if not lo and _susp_type == "truck" and not OS.has_environment("CAR_NOSUSP"):
		_make_axles(body, V)

func _make_mats(rim_col: Color) -> void:
	var t := StandardMaterial3D.new()
	t.albedo_color = Color(0.08, 0.085, 0.09)
	t.roughness = 0.93
	mats["tire"] = t
	var r := StandardMaterial3D.new()
	r.albedo_color = rim_col
	r.metallic = 0.85
	r.roughness = 0.28
	mats["rim"] = r
	var dk := StandardMaterial3D.new()
	dk.albedo_color = Color(0.03, 0.03, 0.035)
	dk.roughness = 0.9
	mats["dark"] = dk
	var st := StandardMaterial3D.new()
	st.albedo_color = Color(0.7, 0.72, 0.75)
	st.metallic = 1.0
	st.roughness = 0.25
	mats["steel"] = st
	var dc := StandardMaterial3D.new()
	dc.albedo_color = DISC_TINTS["steel"]
	dc.metallic = 0.9
	dc.roughness = 0.35
	mats["disc"] = dc
	var ca := StandardMaterial3D.new()
	ca.albedo_color = Color(0.85, 0.08, 0.1)
	ca.metallic = 0.3
	ca.roughness = 0.35
	mats["caliper"] = ca
	var sp := StandardMaterial3D.new()
	sp.albedo_color = Color(0.9, 0.78, 0.1)
	sp.metallic = 0.3
	sp.roughness = 0.4
	mats["spring"] = sp
	var da := StandardMaterial3D.new()
	da.albedo_color = Color(0.12, 0.12, 0.14)
	da.metallic = 0.8
	da.roughness = 0.4
	mats["damper"] = da
	var rod := StandardMaterial3D.new()
	rod.albedo_color = Color(0.85, 0.86, 0.88)
	rod.metallic = 1.0
	rod.roughness = 0.15
	mats["rod"] = rod

## Pone las colores del taller. pp: {rim, tire, spring, caliper, disc}
func set_colors(pp: Dictionary) -> void:
	var W: Dictionary = meta.get("wheel", {})
	if pp.has("rim"):
		(mats["rim"] as StandardMaterial3D).albedo_color = Color(str(pp["rim"]))
	if pp.has("tire"):
		(mats["tire"] as StandardMaterial3D).albedo_color = Color(str(pp["tire"]))
	(mats["spring"] as StandardMaterial3D).albedo_color = Color(str(pp.get("spring", W.get("spring_col", "#e6c619"))))
	(mats["caliper"] as StandardMaterial3D).albedo_color = Color(str(pp.get("caliper", W.get("caliper_col", "#d9141c"))))
	(mats["disc"] as StandardMaterial3D).albedo_color = DISC_TINTS.get(str(pp.get("disc", "steel")), DISC_TINTS["steel"])

func _mi(parent: Node3D, mesh: ArrayMesh, by_name: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var names: Array = mesh.get_meta("names", [])
	for i in names.size():
		var m: Material = by_name.get(str(names[i]), mats["dark"])
		mi.set_surface_override_material(i, m)
	parent.add_child(mi)
	return mi

# ───────────────────────── suspensión ─────────────────────────
func _make_susp(body: Node3D, w: Dictionary, R: float, tw: float, arch_top: float) -> void:
	var st := _susp_type
	var side: float = w["side"]
	var front: bool = w["front"]
	var x: float = w["x"]
	var z: float = w["z"]
	# resorte: radio, hilo, vueltas · amortiguador · dónde se apoya arriba (marco de la carrocería)
	var rs := 0.034
	var wire := 0.0048
	var coils := 6.5
	var fwd := 0.45 * R * (1.0 if front else -1.0)
	var up_y := arch_top - 0.05
	var inb := tw * 0.5 + 0.06
	match st:
		"truck":
			rs = 0.048
			wire = 0.0068
			coils = 5.5
			up_y = arch_top + 0.04
			inb = tw * 0.5 + 0.10
		"buggy":
			rs = 0.044
			wire = 0.0065
			coils = 7.5
			up_y = arch_top + 0.38
			inb = tw * 0.5 + 0.14
			fwd = 0.1 * R * (1.0 if front else -1.0)
	var low_off := Vector3(-side * inb, -0.20 * R, fwd)
	var up := Vector3(x - side * (inb + (0.04 if st != "buggy" else 0.18)), up_y, z + fwd * 0.8)
	var strut := Node3D.new()
	body.add_child(strut)
	var spring := MeshInstance3D.new()
	spring.mesh = WheelGen.spring_mesh(rs, wire, coils, lo)
	spring.set_surface_override_material(0, mats["spring"])
	strut.add_child(spring)
	var dtube := MeshInstance3D.new()
	dtube.mesh = WheelGen.damper_mesh(rs)
	dtube.set_surface_override_material(0, mats["damper"])
	strut.add_child(dtube)
	# brazos inferiores (horquilla): dos barras del cubo al chasis
	var arms: Array = []
	for k in 2:
		var arm := MeshInstance3D.new()
		arm.mesh = WheelGen.tube_mesh(0.013 if st != "buggy" else 0.016, 0.0, 1.0, 6)
		arm.set_surface_override_material(0, mats["damper"])
		body.add_child(arm)
		arms.append(arm)
	w["strut"] = strut
	w["low_off"] = low_off
	w["up"] = up
	w["arms"] = arms
	w["arm_in"] = Vector3(x - side * (tw * 0.5 + 0.34 + (0.2 if st == "buggy" else 0.0)), R * 0.45, z)

## eje rígido (camión, pickup, SUV): un tubo entre las dos ruedas con el diferencial
var axles: Array = [] # {node, a: wheel idx izquierdo, b: derecho}
func _make_axles(body: Node3D, V: RefCounted) -> void:
	for pair in [[0, 1], [2, 3]]:
		var tube := MeshInstance3D.new()
		tube.mesh = WheelGen.tube_mesh(0.045, 0.0, 1.0, 8)
		tube.set_surface_override_material(0, mats["damper"])
		body.add_child(tube)
		var dif := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.28
		sm.radial_segments = 12
		sm.rings = 6
		dif.mesh = sm
		dif.set_surface_override_material(0, mats["damper"])
		body.add_child(dif)
		axles.append({"tube": tube, "dif": dif, "a": pair[0], "b": pair[1]})

## Un cilindro de altura 1 sobre +Y (origen abajo) que va del punto a al punto b
static func _span(n: Node3D, a: Vector3, b: Vector3, thick := 1.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		n.visible = false
		return
	n.visible = true
	var y := d / l
	var xv := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var zv := xv.cross(y).normalized()
	n.transform = Transform3D(Basis(xv * thick, y * l, zv * thick), a)

func sync(p: CarSnapshot, base: float, dt: float) -> void:
	for i in 4:
		var w: Dictionary = wheels[i]
		var steer: Node3D = w["steer"]
		steer.position.y = base - p.wheel_s[i]
		if w["front"]:
			steer.rotation.y = p.steerAngle
		w["angle"] += p.wheel_omega[i] * dt
		(w["spin"] as Node3D).rotation.x = w["angle"]
		if w.has("strut"):
			var low: Vector3 = steer.position + (w["low_off"] as Vector3)
			var up: Vector3 = w["up"]
			_span(w["strut"], low, up)
			var arms: Array = w["arms"]
			var hub: Vector3 = steer.position + Vector3(-float(w["side"]) * (float(w["tw"]) * 0.5 + 0.02), -0.15 * float(steer.position.y), 0.0)
			var inn: Vector3 = w["arm_in"]
			inn.y = minf(inn.y, steer.position.y)
			_span(arms[0], hub, inn + Vector3(0, 0, 0.26))
			_span(arms[1], hub, inn - Vector3(0, 0, 0.26))
	for ax in axles:
		var wa: Dictionary = wheels[ax["a"]]
		var wb: Dictionary = wheels[ax["b"]]
		var pa: Vector3 = (wa["steer"] as Node3D).position
		var pb: Vector3 = (wb["steer"] as Node3D).position
		var tube: Node3D = ax["tube"]
		var ay := minf(pa.y, pb.y)
		_span(tube, Vector3(pa.x, pa.y - 0.0, pa.z), Vector3(pb.x, pb.y, pb.z), 1.0)
		(ax["dif"] as Node3D).position = (pa + pb) * 0.5 + Vector3(0, 0.0, 0.0)
