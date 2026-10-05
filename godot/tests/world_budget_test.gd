## Presupuesto de CPU de la vida del mundo (Etapa 22): si cuesta más que el tope del perfil se achican los topes solos, y se recuperan al aliviarse. Sin red ni audio.
## Uso: godot --headless --path godot --script res://tests/world_budget_test.gd
extends SceneTree

const WorldLife := preload("res://game/world/world_life.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _initialize() -> void:
	var wl := WorldLife.new()
	wl.setup(null, 160.0)
	wl.set_profile("MEDIUM")
	check(wl.throttle == 0 and wl.scaled_cap(48) == 48 and is_equal_approx(wl.hz_scale(), 1.0), "arranca sin estrangular")
	# un cuadro caro un instante no estrangula
	wl.govern(8.0, 0.016)
	check(wl.throttle == 0, "un cuadro caro suelto no estrangula")
	# 2,5 s seguidos por encima del tope (2,6 ms en MEDIA) → un escalón
	for i in 160:
		wl.govern(6.0, 0.016)
	check(wl.throttle == 1 and wl.scaled_cap(48) < 48 and wl.hz_scale() < 1.0, "pasado el tope 2 s: estrangulamiento 1 (topes −20 %%: 48 → %d)" % wl.scaled_cap(48))
	for i in 600:
		wl.govern(6.0, 0.016)
	check(wl.throttle == 3, "si sigue caro llega al máximo (3) y ahí se queda")
	for i in 600:
		wl.govern(6.0, 0.016)
	check(wl.throttle == 3 and wl.scaled_cap(48) >= 20 and wl.scaled_cap(48) <= 28, "nunca baja de ~la mitad (%d)" % wl.scaled_cap(48))
	# aliviado: holgado más de 6 s → recupera de a un escalón
	for i in 500:
		wl.govern(0.3, 0.016)
	check(wl.throttle == 2, "con holgura sostenida (6 s) recupera un escalón")
	for i in 2000:
		wl.govern(0.3, 0.016)
	check(wl.throttle == 0, "y vuelve a lo normal")
	# en la franja intermedia no cambia nada (evita el vaivén)
	wl.throttle = 1
	for i in 1000:
		wl.govern(2.0, 0.016) # entre 50 % y 100 % del tope
	check(wl.throttle == 1, "entre el 50 %% y el 100 %% del tope no cambia (sin vaivén)")
	check(wl.scaled_cap(0) == 0 and wl.scaled_cap(1) == 1, "un tope de 0 sigue en 0 y uno de 1 no desaparece")
	wl.set_profile("LOW")
	check(wl.budget_ms() < 2.6, "el perfil LOW tiene un tope más exigente")
	print("WORLD_BUDGET_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)
