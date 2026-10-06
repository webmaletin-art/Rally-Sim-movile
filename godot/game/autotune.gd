extends RefCounted
## Configuración gráfica automática según el teléfono. Primer arranque (o «RECALIBRAR RENDIMIENTO» en Opciones → Gráficos):
##  1) un aviso, 2) una calibración corta (dentro del mundo abierto, en el centro del pueblo: el peor caso razonable, con el HUD real) que prueba unos pocos perfiles de la
##  ESCALERA de abajo, de más a menos calidad, midiendo cuadros por segundo estables (promedio y piso, sin contar lo que sigue a cada cambio), 3) se elige el perfil de mayor calidad que
##  sostiene ~60 cuadros por segundo, 4) se guarda y 5) queda FIJO: no hay ninguna adaptación por FPS mientras se juega.
## Un perfil = RESOLUCIÓN DE FRAME (ui/frame_res.gd: todo el cuadro, HUD incluido, proporcional a la pantalla real) + ESCALA 3D (la de siempre, nunca mayor que el frame) + el nivel de
## EFECTOS que ya existía (TIERS: partículas, texturas, árboles, sombras, alcance de la vista). Se guarda en los ajustes «auto…» del perfil del jugador, que el juego ya leía en «Automático».
## Lo que el jugador eligió a mano (Opciones → Gráficos → Manual) no se toca.

const FrameRes := preload("res://game/ui/frame_res.gd")

const VERSION := 1 # sube cuando una actualización grande justifique volver a calibrar
const TARGET_FPS := 60.0
const SETTLE_S := 2.5 # lo que sigue a cada cambio no cuenta (se rearman cuadras, compila el shader…)
const MEASURE_S := 5.0
const FIRST_SETTLE_S := 4.0
const AVG_OK := 0.95 # promedio ≥ 95 % del objetivo…
const LOW_OK := 0.80 # …y el 5 % peor de los cuadros no baja del 80 % del objetivo: estable, no un pico
const SCALE3D_MAX := 0.8 # la escala 3D de siempre (tope del ajuste automático anterior); en frames más chicos nunca pasa del frame

## Por nivel: resolución del mundo 3D (tope), texturas, partículas, árboles y sombras cuando la calidad es «Automática»
const TIERS := [
	{"autoRes": 0.50, "autoTex": "low", "autoParticles": 4, "autoTrees": 1500, "autoShadows": false, "n": "Baja"},
	{"autoRes": 0.70, "autoTex": "mid", "autoParticles": 7, "autoTrees": 3000, "autoShadows": false, "n": "Media"},
	{"autoRes": 0.90, "autoTex": "high", "autoParticles": 10, "autoTrees": 4500, "autoShadows": true, "n": "Alta"},
]

## Nivel del teléfono (0..2) según su GPU, núcleos, memoria y pantalla
static func device_tier() -> int:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var t := _gpu_tier(gpu)
	var cores := OS.get_processor_count()
	if cores > 0 and cores <= 4:
		t = mini(t, 0)
	elif cores > 0 and cores <= 6:
		t = mini(t, 1)
	var mem: int = int(OS.get_memory_info().get("physical", -1))
	if mem > 0:
		var gb := float(mem) / 1073741824.0
		if gb < 3.2:
			t = mini(t, 0)
		elif gb < 5.2:
			t = mini(t, 1)
	return t

static func _gpu_tier(gpu: String) -> int:
	var re := RegEx.new()
	if "adreno" in gpu:
		re.compile("(\\d{3})")
		var m := re.search(gpu)
		if m != null:
			var n := int(m.get_string(1))
			return 2 if n >= 640 else (1 if n >= 610 else 0)
		return 1
	if "mali" in gpu:
		re.compile("g(\\d{2,3})")
		var m2 := re.search(gpu)
		if m2 != null:
			var g := int(m2.get_string(1))
			if g >= 610 or g in [77, 78, 710, 715, 720]:
				return 2
			return 1 if g >= 72 else 0
		return 0 # Mali-T y los viejos
	if "powervr" in gpu or "videocore" in gpu or "vivante" in gpu or "tegra" in gpu:
		return 0
	if "apple" in gpu or "nvidia" in gpu or "geforce" in gpu or "radeon" in gpu or "amd" in gpu or "intel" in gpu or "llvmpipe" in gpu or "swiftshader" in gpu:
		return 2 # PC / emulador: la medición del menú corrige si no llega
	return 1

static func apply_tier(profile: RefCounted, tier: int) -> void:
	tier = clampi(tier, 0, TIERS.size() - 1)
	var T: Dictionary = TIERS[tier]
	for k in T:
		if k != "n":
			profile.d["settings"][k] = T[k]
	# en pantallas muy grandes el mundo 3D se dibuja un poco más chico en los teléfonos más flojos
	var px := DisplayServer.screen_get_size()
	if tier < 2 and maxi(px.x, px.y) > 2500:
		profile.d["settings"]["autoRes"] = float(profile.d["settings"]["autoRes"]) - 0.05
	profile.d["settings"]["autoTier"] = tier
	profile.save()

## ¿Hay que calibrar? (nunca se hizo, otra versión, o el perfil guardado es de otra pantalla/GPU)
static func pending(profile: RefCounted) -> bool:
	var g = profile.setting("gfx")
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return true
	var gd: Dictionary = g
	return gd.get("locked") != true or int(gd.get("version", 0)) < VERSION or str(gd.get("sig", "")) != device_sig()

static func tier_name(tier: int) -> String:
	return str((TIERS[clampi(tier, 0, TIERS.size() - 1)] as Dictionary)["n"])


# ───────────────────────── perfiles: la escalera ─────────────────────────
## Niveles de EFECTOS: los TIERS de siempre (partículas, texturas, árboles, sombras, alcance de la vista) y uno más bajo para los teléfonos más limitados. 0 = lo mejor.
static func effects(i: int) -> Dictionary:
	i = clampi(i, 0, 3)
	var e: Dictionary = (TIERS[2 - i] as Dictionary).duplicate() if i < 3 else (TIERS[0] as Dictionary).duplicate()
	e["tier"] = 2 - i if i < 3 else 0
	if i == 3:
		e["autoParticles"] = 2
		e["autoTrees"] = 1000
		e["n"] = "Muy baja"
	return e

## La ESCALERA de perfiles, de más a menos calidad: [nivel de RESOLUCIÓN DE FRAME (ui/frame_res.gd), nivel de EFECTOS]. Primero se bajan los efectos secundarios y recién después la resolución
## (100 % ALTO → 100 % MEDIO → 83 % → 67 % → 67 % BAJO → 50 % → 40 % → 40 % MUY BAJO). Son pocos a propósito: la búsqueda prueba 3 o 4, no todos.
const LADDER := [[0, 0], [0, 1], [1, 1], [2, 1], [2, 2], [3, 2], [4, 2], [4, 3]]

static func rung_name(r: int) -> String:
	return "ALTO" if r <= 0 else ("MEDIO" if r <= 3 else ("BAJO" if r <= 6 else "MUY BAJO"))

## ESCALA 3D del perfil: la de siempre (tope 0,8) y nunca mayor que el frame (no tiene sentido dibujar el mundo a más resolución que el cuadro que lo muestra)
static func scale3d_for(frame_i: int) -> float:
	return minf(SCALE3D_MAX, FrameRes.fraction_of(frame_i))

## Lo que guarda el perfil para el escalón r (los mismos ajustes «auto…» que ya leían el juego y las Opciones)
static func rung_settings(r: int) -> Dictionary:
	var L: Array = LADDER[clampi(r, 0, LADDER.size() - 1)]
	var e := effects(int(L[1]))
	return {"autoFrame": int(L[0]), "autoRes": scale3d_for(int(L[0])), "autoParticles": int(e["autoParticles"]), "autoTex": str(e["autoTex"]), "autoTrees": int(e["autoTrees"]),
		"autoShadows": bool(e["autoShadows"]), "autoTier": int(e["tier"])}

## Alcance de la vista de Dream City del nivel de efectos (el mismo que usa race._view_k con autoTier: 0,6 · 0,8 · 1,0)
static func view_k_for(tier: int) -> float:
	return [0.6, 0.8, 1.0][clampi(tier, 0, 2)]

static func apply_rung(profile: RefCounted, r: int, save := false) -> void:
	var s: Dictionary = rung_settings(r)
	for k in s:
		profile.d["settings"][k] = s[k]
	if save:
		profile.save()

## Opciones gráficas del jugador en «Automático» (el perfil calibrado manda). Sólo en memoria: se guarda cuando termina la calibración
static func reset_to_auto(profile: RefCounted) -> void:
	var st: Dictionary = profile.d["settings"]
	st["quality"] = "auto"
	st["res"] = 0
	st["frameRes"] = "auto"
	st["trees"] = "auto"
	st["shadowsQ"] = "auto"
	st["textures"] = "auto"
	st["particles"] = "auto"
	st["gfxMode"] = "auto"

# ───────────────────────── el dispositivo ─────────────────────────
## Lo que Godot 4.4.1 sabe del teléfono, sin depender de que esté completo (la autoridad es la medición)
static func device_info() -> Dictionary:
	var win := Vector2i(DisplayServer.window_get_size())
	var scr := DisplayServer.screen_get_size()
	var hz := DisplayServer.screen_get_refresh_rate()
	var mem: int = int(OS.get_memory_info().get("physical", -1))
	return {"w": win.x, "h": win.y, "screen": [scr.x, scr.y], "aspect": snappedf(float(win.x) / maxf(1.0, float(win.y)), 0.001), "hz": hz if is_finite(hz) and hz > 0.0 else 0.0,
		"model": OS.get_model_name(), "os": "%s %s" % [OS.get_name(), OS.get_version()], "gpu": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "cores": OS.get_processor_count(),
		"mem_mb": int(float(mem) / 1048576.0) if mem > 0 else 0, "hint_tier": device_tier()}

## Firma del dispositivo para saber si el perfil guardado es de este teléfono: pantalla real + GPU
static func device_sig() -> String:
	var win := DisplayServer.window_get_size()
	return "%dx%d|%s" % [win.x, win.y, RenderingServer.get_video_adapter_name()]

## Cuadros por segundo objetivo: 60, o el de la pantalla si es menor
static func target_fps() -> float:
	var hz := DisplayServer.screen_get_refresh_rate()
	return clampf(hz if is_finite(hz) and hz > 0.0 else TARGET_FPS, 30.0, TARGET_FPS)

# ───────────────────────── medición y búsqueda ─────────────────────────
## Promedio de cuadros por segundo y «piso» (el 5 % peor de los cuadros) de una lista de duraciones de cuadro (s)
static func stats(frame_times: PackedFloat32Array) -> Dictionary:
	var n := frame_times.size()
	if n < 3:
		return {"avg": 0.0, "low": 0.0, "n": n}
	var sum := 0.0
	for t in frame_times:
		sum += t
	var sorted := frame_times.duplicate()
	sorted.sort()
	var p95: float = sorted[mini(n - 1, int(ceil(0.95 * float(n))) - 1)]
	return {"avg": float(n) / maxf(sum, 0.0001), "low": 1.0 / maxf(p95, 0.0001), "n": n}

## ¿Estable? promedio cerca del objetivo Y sin caídas frecuentes (no basta un pico)
static func is_stable(m: Dictionary, target: float) -> bool:
	return float(m["avg"]) >= AVG_OK * target and float(m["low"]) >= LOW_OK * target

## Búsqueda binaria incremental sobre la escalera (la calidad baja monótonamente): next() dice qué escalón medir (o -1 si ya está), report() recibe lo medido, finish() da el resultado.
## Nunca vuelve a subir: si un escalón más alto no es estable, ese teléfono se queda abajo aunque algún pico llegue a 60.
## Si ni el último escalón es estable: el de mayor calidad entre los medidos que rinda cerca del mejor rendimiento logrado (no se promete llegar a 60).
class Searcher extends RefCounted:
	var target := 60.0
	var lo := 0
	var hi := 7
	var cache := {}

	func _init(p_target := 60.0, n := 8) -> void:
		target = p_target
		hi = n - 1

	func ok(m: Dictionary) -> bool:
		return float(m["avg"]) >= 0.95 * target and float(m["low"]) >= 0.80 * target

	func next() -> int:
		while lo < hi:
			var mid := (lo + hi) / 2
			if not cache.has(mid):
				return mid
			if ok(cache[mid]):
				hi = mid
			else:
				lo = mid + 1
		if not cache.has(lo):
			return lo
		return -1

	func report(r: int, m: Dictionary) -> void:
		cache[r] = m

	func finish() -> Dictionary:
		var chosen := lo
		var stable := cache.has(lo) and ok(cache[lo])
		if not stable:
			var best := 0.0
			for r in cache:
				best = maxf(best, float((cache[r] as Dictionary)["avg"]))
			for r in cache:
				var m: Dictionary = cache[r]
				if float(m["avg"]) >= 0.92 * best and float(m["low"]) >= 0.80 * 0.92 * best and int(r) < chosen:
					chosen = int(r)
		return {"rung": chosen, "stable": stable, "stats": cache.get(chosen, {"avg": 0.0, "low": 0.0, "n": 0}), "probes": cache}

## Búsqueda completa con una función de medición síncrona (para pruebas): measure(r) → {avg, low, n} del escalón r
static func search(measure: Callable, target: float) -> Dictionary:
	var sr := Searcher.new(target, LADDER.size())
	var r := sr.next()
	while r >= 0:
		sr.report(r, measure.call(r))
		r = sr.next()
	return sr.finish()

# ───────────────────────── guardar ─────────────────────────
## Guarda el perfil elegido (en los ajustes «auto…» + el registro «gfx») y lo deja FIJO y en Automático
static func save_result(profile: RefCounted, result: Dictionary, target: float) -> void:
	var r: int = int(result["rung"])
	apply_rung(profile, r)
	reset_to_auto(profile)
	var L: Array = LADDER[r]
	var win := Vector2i(DisplayServer.window_get_size())
	var fpx := FrameRes.size_for(win, int(L[0]))
	var probes: Array = []
	for k in (result["probes"] as Dictionary):
		var m: Dictionary = result["probes"][k]
		probes.append({"rung": int(k), "avg": snappedf(float(m["avg"]), 0.1), "low": snappedf(float(m["low"]), 0.1)})
	var st: Dictionary = result["stats"]
	profile.d["settings"]["gfx"] = {"locked": true, "version": VERSION, "sig": device_sig(), "device": device_info(), "profile": rung_name(r), "rung": r,
		"frame_level": int(L[0]), "frame_pct": int(round(FrameRes.fraction_of(int(L[0])) * 100.0)), "frame_px": [fpx.x, fpx.y], "scale3d": scale3d_for(int(L[0])),
		"world_px": [int(float(win.x) * scale3d_for(int(L[0]))), int(float(win.y) * scale3d_for(int(L[0])))], "effects": str(effects(int(L[1]))["n"]),
		"particles": int(effects(int(L[1]))["autoParticles"]), "tex": str(effects(int(L[1]))["autoTex"]), "target": target, "stable": bool(result["stable"]),
		"fps_avg": snappedf(float(st["avg"]), 0.1), "fps_low": snappedf(float(st["low"]), 0.1), "probes": probes, "date": Time.get_datetime_string_from_system()}
	profile.d["settings"]["autotuned"] = true
	profile.save()

## Resumen del perfil guardado para el menú de diagnóstico (el jugador no lo ve)
static func info_lines(profile: RefCounted) -> Array:
	var g = profile.setting("gfx")
	var out: Array = []
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		out.append("PERFIL: (sin calibrar)")
		out.append("MODO: %s" % ("AUTOMÁTICO" if str(profile.setting("gfxMode")) == "auto" else "MANUAL"))
		return out
	var gd: Dictionary = g
	out.append("PERFIL: %s%s" % [str(gd.get("profile", "?")), "" if bool(gd.get("stable", false)) else " (sin llegar al objetivo)"])
	out.append("ESCALA FRAME: %d%%" % int(gd.get("frame_pct", 0)))
	out.append("ESCALA 3D (perfil): %.2f" % float(gd.get("scale3d", 0.0)))
	out.append("PARTÍCULAS: %d/10 · EFECTOS: %s · TEXTURAS: %s" % [int(gd.get("particles", 0)), str(gd.get("effects", "?")), str(gd.get("tex", "?"))])
	out.append("CALIDAD DE MODELO: la de siempre (no es parte del perfil)")
	out.append("FPS CALIBRACIÓN: %.1f (piso %.1f)" % [float(gd.get("fps_avg", 0.0)), float(gd.get("fps_low", 0.0))])
	out.append("OBJETIVO: %d FPS" % int(float(gd.get("target", TARGET_FPS))))
	out.append("PERFIL BLOQUEADO: %s" % ("SÍ" if bool(gd.get("locked", false)) else "NO"))
	out.append("MODO: %s" % ("AUTOMÁTICO" if str(profile.setting("gfxMode")) == "auto" else "MANUAL"))
	return out

## Línea para el jugador (Opciones → Gráficos): qué perfil se calibró en este teléfono
static func player_summary(profile: RefCounted) -> String:
	var g = profile.setting("gfx")
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return ""
	var gd: Dictionary = g
	var px: Array = gd.get("frame_px", [0, 0])
	return "Perfil calibrado: %s · imagen a %d×%d (%d%%)" % [str(gd.get("profile", "?")), int(px[0]), int(px[1]), int(gd.get("frame_pct", 100))]
