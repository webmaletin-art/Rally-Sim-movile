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
	# NITRO
	c.has_nitro = true
	c._touch_down(5, c.rect_of("nitro").get_center())
	check("nitro mientras se mantiene", c.nitro)
	c._touch_up(5)
	check("nitro se apaga al soltar", not c.nitro)
	# modo barra
	c.manual = false
	c.has_nitro = false
	c.steer_mode = "slider"
	var sr := c.rect_of("slider")
	c._touch_down(6, Vector2(sr.position.x + sr.size.x * 0.9, sr.get_center().y))
	for i in 30:
		c.update_inputs(1.0 / 60.0)
	check("barra hacia la derecha: %.2f" % c.steer, c.steer > 0.6)
	c._touch_up(6)
	quit(1 if fails > 0 else 0)
