extends RefCounted
## Ajuste automático de gráficos según el teléfono. La primera vez que se abre el juego (o cuando se pide «Ajuste automático» en Opciones):
##  1) por el teléfono (GPU, núcleos, memoria y pantalla) se elige un nivel inicial: 0 bajo · 1 medio · 2 alto;
##  2) ya en el menú se miden los cuadros por segundo unos segundos (con el auto y los pilotos en pantalla) y se sube o baja un nivel si hace falta,
##     así la primera carrera ya sale bien y no hay que esperar a que la resolución se ajuste corriendo.
## Solo toca lo que está en «Automático»: lo que el jugador eligió a mano no se cambia.

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

## ¿Hay que ajustar? (todavía no se hizo y la calidad general está en «Automática»)
static func pending(profile: RefCounted) -> bool:
	return profile.setting("autotuned") != true and str(profile.setting("quality")) == "auto"

static func tier_name(tier: int) -> String:
	return str((TIERS[clampi(tier, 0, TIERS.size() - 1)] as Dictionary)["n"])

## Mide los cuadros por segundo del menú y corrige el nivel. Se agrega como nodo al menú; avisa con «done(tier)» al terminar.
class Probe extends Node:
	signal done(tier: int, changed: bool)
	var profile: RefCounted
	var apply: Callable # Callable(tier): guarda los ajustes del nivel
	var tier := 1
	var start_tier := 1
	var _warm := 3.5
	var _t := 0.0
	var _sum := 0.0
	var _n := 0
	var _good := 0
	var _windows := 0
	var _raised := false

	func begin(p_profile: RefCounted) -> void:
		profile = p_profile
		tier = int(profile.setting("autoTier"))
		start_tier = tier
		set_process(true)

	func _process(dt: float) -> void:
		if profile == null:
			return
		if dt > 0.25: # un tirón de carga o una transición: no cuenta
			return
		if _warm > 0.0:
			_warm -= dt
			return
		_t += dt
		_sum += dt
		_n += 1
		if _t < 2.5:
			return
		var avg := _sum / float(_n)
		_t = 0.0
		_sum = 0.0
		_n = 0
		_windows += 1
		var refresh := DisplayServer.screen_get_refresh_rate()
		var target := 1.0 / clampf(refresh if is_finite(refresh) and refresh > 0.0 else 60.0, 30.0, 60.0)
		if avg > target * 1.35 and tier > 0:
			tier -= 1
			apply.call(tier)
			_warm = 1.2
			_good = 0
		elif avg < target * 0.55 and tier < 2 and tier <= start_tier and not _raised and _windows >= 2:
			tier += 1 # le sobra mucho: un nivel más, una sola vez
			_raised = true
			apply.call(tier)
			_warm = 1.2
			_good = 0
		else:
			_good += 1
		if _good >= 2 or _windows >= 6:
			_finish()

	func _finish() -> void:
		set_process(false)
		profile.set_setting("autotuned", true)
		profile.set_setting("autoTier", tier)
		done.emit(tier, tier != start_tier)
		queue_free()
