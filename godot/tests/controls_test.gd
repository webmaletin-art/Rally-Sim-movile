## Los controles en pantalla responden como en la versión HTML (toques simulados).
## Uso: godot --headless --path godot --script res://tests/controls_test.gd
extends SceneTree

const Controls := preload("res://game/ui/controls.gd")

var fails := 0

func check(name: String, cond: bool) -> void:
	print("%s  %s" % ["OK   " if cond else "FALLA", name])
	if not cond:
		fails += 1

func _init() -> void:
	var c := Controls.new()
	root.add_child(c)
	await process_frame
	var wr := c.rect_of("wheel")
	var ctr := wr.get_center()
	# VOLANTE: tocar arriba y arrastrar un cuarto de vuelta en sentido horario (hacia la derecha)
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	check("el volante toma el dedo", c._taken("wheel"))
	for i in 10:
		var ang := -PI / 2.0 + (PI / 2.0) * float(i + 1) / 10.0
		c._touch_move(0, ctr + Vector2(cos(ang), sin(ang)) * wr.size.x * 0.4)
	for i in 30:
		c.update_inputs(1.0 / 60.0)
	check("giro horario → dirección a la derecha (positivo, como en HTML): %.2f" % c.steer, c.steer > 0.5 and c.steer <= 1.0)
	check("el volante dibujado gira: %.2f rad" % c.wheel_visual, c.wheel_visual > 1.0)
	c._touch_up(0)
	for i in 120:
		c.update_inputs(1.0 / 60.0)
	check("al soltar el volante vuelve al centro: %.3f" % c.steer, absf(c.steer) < 0.02 and absf(c.wheel_visual) < 0.05)
	# giro a la izquierda
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	for i in 10:
		var ang2 := -PI / 2.0 - (PI / 2.0) * float(i + 1) / 10.0
		c._touch_move(0, ctr + Vector2(cos(ang2), sin(ang2)) * wr.size.x * 0.4)
	for i in 30:
		c.update_inputs(1.0 / 60.0)
	check("giro antihorario → izquierda (negativo): %.2f" % c.steer, c.steer < -0.5)
	c._touch_up(0)
	# el volante se traba donde la dirección llega al tope (pedido del dueño, 19/10/2026: antes se le podían dar 3 vueltas con la dirección ya al máximo)
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	for i in 60: # una vuelta y media con el dedo
		var ang3 := -PI / 2.0 + (PI * 3.0) * float(i + 1) / 60.0
		c._touch_move(0, ctr + Vector2(cos(ang3), sin(ang3)) * wr.size.x * 0.4)
	for i in 30:
		c.update_inputs(1.0 / 60.0)
	check("el volante dibujado no pasa del tope (%.0f° de %.0f°)" % [rad_to_deg(c.wheel_visual), rad_to_deg(Controls.WHEEL_LOCK)], absf(c.wheel_visual) <= Controls.WHEEL_LOCK + 0.01)
	check("en el tope la dirección está al máximo (%.2f)" % c.steer, c.steer > 0.97)
	c._touch_up(0)
	for i in 120: # (suelto: vuelve al centro)
		c.update_inputs(1.0 / 60.0)
	# a medio giro, el dibujo marca lo mismo que la dirección (volante/tope = dirección/máximo)
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	for i in 10:
		var ang4 := -PI / 2.0 + (PI / 4.0) * float(i + 1) / 10.0 # 45° con el dedo
		c._touch_move(0, ctr + Vector2(cos(ang4), sin(ang4)) * wr.size.x * 0.4)
	for i in 60:
		c.update_inputs(1.0 / 60.0)
	check("a 45° el volante dibujado está a 45° (%.0f°)" % rad_to_deg(c.wheel_visual), absf(rad_to_deg(c.wheel_visual) - 45.0) < 2.0)
	check("y la dirección a 45/135 del tope (%.2f)" % c.steer, absf(c.steer - 45.0 / 135.0) < 0.03)
	c._touch_up(0)
	for i in 120:
		c.update_inputs(1.0 / 60.0)
	# PEDAL: arriba acelera, abajo frena, en el medio nada
	var pr := c.rect_of("pedal")
	c._touch_down(1, Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.1))
	check("pedal arriba: acelerador %.2f freno %.2f" % [c.gas, c.brake], c.gas > 0.7 and c.brake == 0.0)
	c._touch_move(1, Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.9))
	check("pedal abajo: acelerador %.2f freno %.2f" % [c.gas, c.brake], c.brake > 0.7 and c.gas == 0.0)
	c._touch_move(1, pr.get_center())
	check("pedal al medio: nada", c.gas < 0.02 and c.brake < 0.02)
	c._touch_up(1)
	# MULTITÁCTIL: volante y pedal a la vez + freno de mano
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	c._touch_down(1, Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.2))
	var hb := c.rect_of("handbrake")
	c._touch_down(2, hb.get_center())
	check("tres dedos a la vez", c._taken("wheel") and c._taken("pedal") and c.handbrake and c.gas > 0.5)
	c._touch_up(2)
	check("suelta el freno de mano", not c.handbrake)
	c._touch_up(0)
	c._touch_up(1)
	# CAJA MANUAL: tira de cambios
	c.manual = true
	var gr := c.rect_of("gears")
	c._touch_down(3, Vector2(gr.get_center().x, gr.end.y - 10.0))
	c._touch_move(3, Vector2(gr.get_center().x, gr.end.y - 10.0 - 40.0 * c._u()))
	c.update_inputs(1.0 / 60.0)
	check("deslizar hacia arriba = subir un cambio", c.shift == 1)
	c.update_inputs(1.0 / 60.0)
	check("el cambio se consume una sola vez", c.shift == 0)
	c._touch_up(3)
	c._touch_down(4, Vector2(gr.get_center().x, gr.end.y - 5.0))
	c._touch_up(4)
	c.update_inputs(1.0 / 60.0)
	check("tocar la mitad de abajo = bajar un cambio", c.shift == -1)
	# (el nitro se sacó del juego, 20/10/2026: no hay botón N₂O)
	check("no hay botón de nitro entre los controles", not ("nitro" in Controls.ITEMS) and not ("nitro" in c._active_items()))
	# modo barra
	c.manual = false
	c.steer_mode = "slider"
	var sr := c.rect_of("slider")
	c._touch_down(6, Vector2(sr.position.x + sr.size.x * 0.9, sr.get_center().y))
	for i in 30:
		c.update_inputs(1.0 / 60.0)
	check("barra hacia la derecha: %.2f" % c.steer, c.steer > 0.6)
	c._touch_up(6)
	# VOLANTE REAL (20/10/2026, pedido del dueño: «en simulación total, un volante real: dar los giros con los dedos de verdad; con el ángulo de dirección en 130 tengo que dar más vueltas»)
	c.steer_mode = "wheel"
	c.wheel_real = 0
	c.steer_pct = 0.0
	check("Arcade: el volante se traba a ±135° (%.0f°)" % rad_to_deg(c.wheel_lock()), absf(c.wheel_lock() - Controls.WHEEL_LOCK) < 0.001)
	c.wheel_real = 100
	check("Real 100 %%: tope a ±540° (%.0f°)" % rad_to_deg(c.wheel_lock()), absf(rad_to_deg(c.wheel_lock()) - 540.0) < 0.5)
	c.wheel_real = 50
	check("Real 50 %%: la mitad del volante real, ±270° (%.0f°)" % rad_to_deg(c.wheel_lock()), absf(rad_to_deg(c.wheel_lock()) - 270.0) < 0.5)
	c.wheel_real = 100
	c.steer_pct = 130.0
	check("Real 100 %% con el ángulo de dirección en 130 %%: más vueltas (%.0f°)" % rad_to_deg(c.wheel_lock()), absf(rad_to_deg(c.wheel_lock()) - 540.0 * 1.3) < 0.5)
	c.steer_pct = 0.0
	# girar 135° con el dedo: en Arcade es el tope; en el volante real es sólo un cuarto de la dirección
	c.wheel_real = 100
	c._touch_down(0, ctr + Vector2(0, -wr.size.x * 0.4))
	for i in 30:
		var ang5 := -PI / 2.0 + (PI * 0.75) * float(i + 1) / 30.0
		c._touch_move(0, ctr + Vector2(cos(ang5), sin(ang5)) * wr.size.x * 0.4)
	for i in 60:
		c.update_inputs(1.0 / 60.0)
	check("Real 100 %%: 135° con el dedo = sólo un cuarto de la dirección (%.2f)" % c.steer, absf(c.steer - 0.25) < 0.03)
	for i in 120: # tres vueltas con el dedo: llega al tope y ahí se queda
		var ang6 := -PI / 2.0 + PI * 0.75 + (PI * 6.0) * float(i + 1) / 120.0
		c._touch_move(0, ctr + Vector2(cos(ang6), sin(ang6)) * wr.size.x * 0.4)
	for i in 60:
		c.update_inputs(1.0 / 60.0)
	check("Real 100 %%: con vueltas de verdad la dirección llega al máximo (%.2f) y el dibujo no pasa del tope (%.0f°)" % [c.steer, rad_to_deg(c.wheel_visual)], c.steer > 0.97 and absf(c.wheel_visual) <= c.wheel_lock() + 0.01)
	c._touch_up(0)
	for i in 240:
		c.update_inputs(1.0 / 60.0)
	check("Real 100 %%: al soltar el volante vuelve al centro (%.3f)" % c.steer, absf(c.steer) < 0.02)
	quit(1 if fails > 0 else 0)
