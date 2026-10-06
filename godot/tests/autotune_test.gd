## Prueba de la configuración gráfica automática: nivel por GPU (pista de hardware), resoluciones proporcionales de la RESOLUCIÓN DE FRAME para cualquier pantalla, la escalera de perfiles,
## la búsqueda del mejor perfil ESTABLE (sin volver a subir por un pico), qué se guarda y cuándo hay que recalibrar.
## Uso: godot --headless --path godot --script res://tests/autotune_test.gd
extends SceneTree

const Autotune := preload("res://game/autotune.gd")
const Profile := preload("res://game/data/profile.gd")
const FrameRes := preload("res://game/ui/frame_res.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Stub extends RefCounted:
	var d := {"settings": {"autoTier": 1, "quality": "auto", "gfx": {}, "res": 0, "frameRes": "auto", "trees": "auto", "shadowsQ": "auto", "textures": "auto", "particles": "auto", "gfxMode": "manual"}}
	func setting(k: String):
		return d["settings"].get(k)
	func set_setting(k: String, v) -> void:
		d["settings"][k] = v
	func save() -> void:
		pass

## Un teléfono simulado: cuadros por segundo de cada escalón (el piso = 90 % del promedio, salvo que se pida otro)
func _phone(fps: Array, low_k := 0.9) -> Array:
	var calls := []
	var m := func(r: int) -> Dictionary:
		calls.append(r)
		return {"avg": float(fps[r]), "low": float(fps[r]) * low_k, "n": 100}
	var res := Autotune.search(m, 60.0)
	return [res, calls]

func _init() -> void:
	# pista de hardware (no manda: la autoridad es la medición)
	check(Autotune._gpu_tier("adreno (tm) 740") == 2 and Autotune._gpu_tier("adreno (tm) 618") == 1 and Autotune._gpu_tier("adreno (tm) 506") == 0, "pista por GPU: Adreno")
	check(Autotune._gpu_tier("mali-g78") == 2 and Autotune._gpu_tier("mali-g52 mc2") == 0 and Autotune._gpu_tier("mali-t830") == 0, "pista por GPU: Mali")
	var dt := Autotune.device_tier()
	check(dt >= 0 and dt <= 2, "el nivel de este equipo es %d" % dt)
	var info := Autotune.device_info()
	check(info.has("w") and info.has("h") and info.has("gpu") and info.has("model") and info.has("hz"), "la información del dispositivo no falla aunque falten datos (%dx%d)" % [int(info["w"]), int(info["h"])])
	check(Autotune.target_fps() >= 30.0 and Autotune.target_fps() <= 60.0, "objetivo %d FPS" % int(Autotune.target_fps()))

	# RESOLUCIÓN DE FRAME: proporcional a la pantalla real, conserva el aspecto
	var s2400 := Vector2i(2400, 1080)
	check(FrameRes.size_for(s2400, 0) == s2400 and FrameRes.size_for(s2400, 1) == Vector2i(1992, 896) and FrameRes.size_for(s2400, 2) == Vector2i(1608, 724) \
		and FrameRes.size_for(s2400, 3) == Vector2i(1200, 540) and FrameRes.size_for(s2400, 4) == Vector2i(960, 432), "2400×1080 → 2400×1080 · 1992×896 · 1608×724 · 1200×540 · 960×432")
	var s1920 := Vector2i(1920, 1080)
	check(FrameRes.size_for(s1920, 0) == s1920 and FrameRes.size_for(s1920, 1) == Vector2i(1594, 896) and FrameRes.size_for(s1920, 2) == Vector2i(1286, 724) \
		and FrameRes.size_for(s1920, 3) == Vector2i(960, 540) and FrameRes.size_for(s1920, 4) == Vector2i(768, 432), "1920×1080 → 1920×1080 · 1594×896 · 1286×724 · 960×540 · 768×432")
	var aspect_ok := true
	for scr in [Vector2i(2340, 1080), Vector2i(1600, 720), Vector2i(2560, 1440), Vector2i(2400, 1080), Vector2i(1280, 800)]:
		for i in 5:
			var f := FrameRes.size_for(scr, i)
			if absf(float(f.x) / float(f.y) - float(scr.x) / float(scr.y)) > 0.01:
				aspect_ok = false
	check(aspect_ok, "la relación de aspecto se conserva en 2340×1080, 1600×720, 2560×1440, 2400×1080 y 1280×800")

	# la escalera: de más a menos calidad, la escala 3D nunca pasa del frame y los efectos de siempre
	var mono := true
	var last_f := -1
	var last_e := -1
	var last_s := 9.0
	for r in Autotune.LADDER.size():
		var L: Array = Autotune.LADDER[r]
		var st := Autotune.rung_settings(r)
		if int(L[0]) < last_f or int(L[1]) < last_e or float(st["autoRes"]) > last_s + 0.0001 or float(st["autoRes"]) > FrameRes.fraction_of(int(L[0])) + 0.0001:
			mono = false
		last_f = int(L[0])
		last_e = int(L[1])
		last_s = float(st["autoRes"])
	check(mono, "la escalera baja de calidad de a poco: frame y efectos nunca suben, y la escala 3D (%.2f → %.2f) nunca pasa del frame" % [float(Autotune.rung_settings(0)["autoRes"]), float(Autotune.rung_settings(Autotune.LADDER.size() - 1)["autoRes"])])
	check(Autotune.LADDER.size() <= 10, "pocos escalones (%d), no cientos de combinaciones" % Autotune.LADDER.size())
	check(Autotune.rung_name(0) == "ALTO" and Autotune.rung_name(2) == "MEDIO" and Autotune.rung_name(5) == "BAJO" and Autotune.rung_name(7) == "MUY BAJO", "nombres de perfil")
	var e_ok := true
	for i in 3:
		e_ok = e_ok and int(Autotune.effects(i)["tier"]) == 2 - i
	check(e_ok and int(Autotune.effects(3)["autoParticles"]) < int(Autotune.effects(2)["autoParticles"]), "los efectos reutilizan los niveles de siempre (Alta, Media, Baja) y suman uno más bajo")

	# medición: promedio y piso (no un pico)
	var steady := PackedFloat32Array()
	for i in 300:
		steady.append(1.0 / 60.0)
	var sm := Autotune.stats(steady)
	check(absf(float(sm["avg"]) - 60.0) < 0.1 and Autotune.is_stable(sm, 60.0), "60 cuadros parejos → estable")
	var jerky := PackedFloat32Array()
	for i in 300:
		jerky.append(1.0 / 75.0 if i % 5 != 0 else 1.0 / 25.0) # promedio alto pero con caídas frecuentes
	var jm := Autotune.stats(jerky)
	check(float(jm["avg"]) > 50.0 and not Autotune.is_stable(jm, 60.0), "promedio alto con caídas frecuentes (piso %d) → NO estable" % int(float(jm["low"])))
	check(not Autotune.is_stable({"avg": 56.0, "low": 50.0}, 60.0) and Autotune.is_stable({"avg": 58.0, "low": 50.0}, 60.0), "margen: 58 FPS parejos sí, 56 no")

	# búsqueda del perfil (pocas pruebas, estable, sin volver a subir)
	var strong := _phone([55, 60, 60, 60, 60, 60, 60, 61])
	check(int(strong[0]["rung"]) == 1 and bool(strong[0]["stable"]) and (strong[1] as Array).size() <= 4, "teléfono potente: elige el escalón %d (%s) con %d pruebas, sin subir a 100%% ALTO" % [int(strong[0]["rung"]), Autotune.rung_name(int(strong[0]["rung"])), (strong[1] as Array).size()])
	var mid := _phone([38, 45, 52, 59, 60, 60, 60, 61])
	check(int(mid[0]["rung"]) == 3 and (mid[1] as Array).size() <= 4, "teléfono medio: 67%% con efectos medios (escalón %d)" % int(mid[0]["rung"]))
	var drops := _phone([38, 45, 52, 60, 60, 60, 60, 61], 0.66) # el escalón 3 llega a 60 de promedio pero con caídas a 40: no es estable
	check(int(drops[0]["rung"]) > 3, "60 de promedio con caídas frecuentes no alcanza: elige uno más bajo (escalón %d)" % int(drops[0]["rung"]))
	var weak := _phone([25, 28, 31, 38, 42, 47, 52, 61])
	check(int(weak[0]["rung"]) == 7 and bool(weak[0]["stable"]), "teléfono muy limitado: queda en el último escalón (%s) aunque otros hayan dado un pico" % Autotune.rung_name(7))
	var spike := _phone([25, 28, 31, 38, 42, 47, 59, 61], 0.9) # el escalón 6 llega a 59: sigue sin ser estable (low 53 ≥ 48, avg 59 ≥ 57 → sí) → lo es
	check(int(spike[0]["rung"]) == 6, "cuando un escalón sí sostiene el objetivo se elige ese, no uno más bajo (%d)" % int(spike[0]["rung"]))
	var none := _phone([20, 22, 24, 26, 28, 30, 33, 35])
	check(not bool(none[0]["stable"]) and int(none[0]["rung"]) >= 5, "si nada llega a 60 se elige el mejor rendimiento posible (escalón %d), sin prometer 60" % int(none[0]["rung"]))

	# qué se guarda y cuándo hay que recalibrar
	var p := Stub.new()
	check(Autotune.pending(p), "sin perfil calibrado: hay que calibrar")
	Autotune.save_result(p, mid[0], 60.0)
	var g: Dictionary = p.setting("gfx")
	check(bool(g["locked"]) and str(g["profile"]) == "MEDIO" and int(g["frame_pct"]) == 67 and float(g["scale3d"]) <= 0.67 + 0.0001 and int(g["target"]) == 60, "se guarda el perfil: %s, frame %d%%, escala 3D %.2f, FPS %.1f" % [str(g["profile"]), int(g["frame_pct"]), float(g["scale3d"]), float(g["fps_avg"])])
	check(int(p.setting("autoFrame")) == 2 and float(p.setting("autoRes")) <= 0.67 + 0.0001 and str(p.setting("gfxMode")) == "auto" and str(p.setting("frameRes")) == "auto" and str(p.setting("particles")) == "auto", "queda en Automático con los ajustes «auto…» del perfil")
	check(not Autotune.pending(p), "perfil guardado de este equipo: no se vuelve a calibrar")
	var other: Stub = Stub.new()
	other.d["settings"]["gfx"] = (g as Dictionary).duplicate()
	other.d["settings"]["gfx"]["sig"] = "1x1|otro"
	check(Autotune.pending(other), "perfil de otro teléfono/pantalla: hay que recalibrar")
	var old: Stub = Stub.new()
	old.d["settings"]["gfx"] = (g as Dictionary).duplicate()
	old.d["settings"]["gfx"]["version"] = 0
	check(Autotune.pending(old), "perfil de una versión anterior: se puede recalibrar")
	check(Autotune.info_lines(p).size() >= 8, "el diagnóstico puede mostrar el perfil (%d líneas)" % Autotune.info_lines(p).size())

	# el perfil nuevo
	var def := Profile.DEFAULT_SETTINGS
	check(def["fx"] == [0, 0, 0] and int(def["lens2"]) == 0 and str(def["visual"]) == "none", "perfil nuevo: sin efectos de cámara ni filtros")
	check(int(def["camera"]) == 6, "perfil nuevo: cámara de adentro con piloto y copiloto")
	check(str(def["quality"]) == "auto" and def["autotuned"] == false and str(def["gfxMode"]) == "auto" and str(def["frameRes"]) == "auto" and (def["gfx"] as Dictionary).is_empty(), "perfil nuevo: automático y sin calibrar todavía")
	quit(1 if fail else 0)
