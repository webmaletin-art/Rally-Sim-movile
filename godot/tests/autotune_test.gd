## Prueba del ajuste automático de gráficos: nivel por GPU, qué se guarda, y la medición del menú (sube o baja según los cuadros).
## Uso: godot --headless --path godot --script res://tests/autotune_test.gd
extends SceneTree

const Autotune := preload("res://game/autotune.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Stub extends RefCounted:
	var d := {"settings": {"autoTier": 1, "quality": "auto"}}
	func setting(k: String):
		return d["settings"].get(k)
	func set_setting(k: String, v) -> void:
		d["settings"][k] = v
	func save() -> void:
		pass

func _run(frame_s: float, start_tier: int, seconds: float) -> Array:
	var p := Stub.new()
	p.d["settings"]["autoTier"] = start_tier
	var pr := Autotune.Probe.new()
	pr.apply = func(t: int) -> void: Autotune.apply_tier(p, t)
	var res := {"done": false, "tier": -1}
	pr.done.connect(func(tier: int, _c: bool) -> void:
		res["done"] = true
		res["tier"] = tier)
	pr.begin(p)
	var t := 0.0
	while t < seconds and not res["done"]:
		pr._process(frame_s)
		t += frame_s
	return [res, p, t]

func _init() -> void:
	check(Autotune._gpu_tier("adreno (tm) 740") == 2, "Adreno 740 → alto")
	check(Autotune._gpu_tier("adreno (tm) 650") == 2, "Adreno 650 → alto")
	check(Autotune._gpu_tier("adreno (tm) 618") == 1, "Adreno 618 → medio")
	check(Autotune._gpu_tier("adreno (tm) 506") == 0, "Adreno 506 → bajo")
	check(Autotune._gpu_tier("mali-g78") == 2, "Mali-G78 → alto")
	check(Autotune._gpu_tier("mali-g52 mc2") == 0, "Mali-G52 → bajo")
	check(Autotune._gpu_tier("mali-g76") == 1, "Mali-G76 → medio")
	check(Autotune._gpu_tier("mali-t830") == 0, "Mali-T830 → bajo")
	check(Autotune._gpu_tier("powervr ge8320") == 0, "PowerVR → bajo")
	var dt := Autotune.device_tier()
	check(dt >= 0 and dt <= 2, "el nivel de este equipo es %d" % dt)
	# cada nivel guarda lo suyo y los niveles van de menos a más
	var p := Stub.new()
	var last_res := 0.0
	for tier in 3:
		Autotune.apply_tier(p, tier)
		var r: float = float(p.d["settings"]["autoRes"])
		check(r > last_res and int(p.d["settings"]["autoTier"]) == tier, "nivel %s: resolución %.2f, texturas %s, árboles %d" % [Autotune.tier_name(tier), r, str(p.d["settings"]["autoTex"]), int(p.d["settings"]["autoTrees"])])
		last_res = r
	# un teléfono que anda a 25 cuadros por segundo en el menú baja de nivel hasta llegar bien
	var a := _run(1.0 / 25.0, 2, 90.0)
	check(bool(a[0]["done"]) and int(a[0]["tier"]) < 2, "a 25 fps en el menú baja de nivel (queda en %d)" % int(a[0]["tier"]))
	check((a[1] as Stub).setting("autotuned") == true, "queda marcado como ajustado")
	# uno que anda perfecto (60 fps) se queda en su nivel
	var b := _run(1.0 / 60.0, 1, 90.0)
	check(bool(b[0]["done"]) and int(b[0]["tier"]) == 1, "a 60 fps se queda en su nivel (%d)" % int(b[0]["tier"]))
	# uno que anda muy sobrado (200 fps) sube un nivel, una sola vez
	var c := _run(1.0 / 200.0, 0, 90.0)
	check(bool(c[0]["done"]) and int(c[0]["tier"]) == 1, "a 200 fps sube un nivel (queda en %d)" % int(c[0]["tier"]))
	# el perfil nuevo: sin efectos de cámara y con la cámara de adentro (se ve el piloto y el copiloto)
	var def := Profile.DEFAULT_SETTINGS
	check(def["fx"] == [0, 0, 0] and int(def["lens2"]) == 0 and str(def["visual"]) == "none", "perfil nuevo: sin efectos de cámara ni filtros")
	check(int(def["camera"]) == 6, "perfil nuevo: cámara de adentro con piloto y copiloto")
	check(str(def["quality"]) == "auto" and def["autotuned"] == false, "perfil nuevo: calidad automática y sin ajustar todavía")
	quit(1 if fail else 0)
