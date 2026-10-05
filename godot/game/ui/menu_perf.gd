extends RefCounted
## «Prueba de rendimiento» del menú de inicio: elegir RÁPIDA o COMPLETA y largar. La prueba la maneja race.gd (PerfBench).

const Kit := preload("res://game/ui/ui_kit.gd")
const PerfBench := preload("res://game/perf_bench.gd")

var m # menu.gd

func build(_name: String, _arg) -> void:
	m.set_title("PRUEBA DE RENDIMIENTO")
	m.body.add_child(Kit.card_button("🌲 BENCHMARK — VEGETACIÓN", "3D original · 8 vistas · cross", "1000–20000 árboles", func() -> void:
		m.sfx.play("click")
		m.app.start_vegbench(), false, true, 64, 19))
	m.body.add_child(Kit.wrap("Maneja sola por una pista normal y por la plaza de drift (más pesada). Mide primero sin ningún filtro de cámara, después cada cámara, cada componente del juego y por último el lente y cada efecto (ojo de pez, oclusión, cromática…). Al final te da un informe para copiar y pegar.", 15, Kit.TEXT, 300))
	m.body.add_child(Kit.wrap("Dejá el teléfono quieto, con batería y sin otras aplicaciones abiertas. No toques la pantalla.", 14, Kit.GOLD, 300))
	for md in [["full", "🔬 COMPLETA", "recomendada"], ["quick", "⚡ RÁPIDA", "lo más importante"]]:
		var mode: String = md[0]
		var secs := PerfBench.total_seconds(PerfBench.plan(mode))
		var b := Kit.card_button("%s" % tr(str(md[1])), tr(str(md[2])), "≈ %d min" % int(ceil(secs / 60.0)), func() -> void:
			_start(mode), mode == "full", true, 70, 22)
		m.body.add_child(b)

func _start(mode: String) -> void:
	var pid: String = m.profile.current_id()
	m.sfx.play("click")
	m.launch({"type": "bench", "bench_mode": mode, "track": "lake", "ai": 3, "sky": "day", "maxPI": 999, "skill": 0.9, "seed": 7, "car": pid, "state": m.profile.car(), "back": "home"}, false)
