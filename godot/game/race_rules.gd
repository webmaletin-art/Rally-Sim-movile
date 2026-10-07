extends RefCounted
## Reglas especiales de la Carrera rápida sobre un mapa de rutas (se activan con cfg["rule"]):
##  · "chase" — PERSECUCIÓN contra un rival. Quien va atrás es el que persigue; si el de adelante se escapa a más de `max_gap` metros, gana. Si lo pasás, los roles se cambian:
##    ahora te persigue a vos (pegado, y de a ratos intenta pasarte). Termina cuando uno se escapa a `max_gap` (o si se llega a la meta, en un tramo A→B).
##  · "elim"  — ELIMINACIÓN: cada `every` segundos sale el último de los que quedan (el que va más atrás). Gana el que queda en pie.
## No dibuja nada: le pasa al HUD el texto (session.rule_text / rule_sub) y los avisos (session.messages) y cierra la sesión (session.state = "done").

const AIDriver := preload("res://game/ai/ai_driver.gd")

var kind := ""
var session
var cars: Array = []
var hud # race_hud (big): puede ser null en las pruebas
var names: Array = []
var done := false
var win := false
var note := ""
# persecución
var max_gap := 150.0
var diff := 0.5 # 0..1: qué tan fuerte es el rival (de la habilidad de su IA)
var lead_player := false # ¿el jugador va adelante?
var pass_t := 0.0 # el rival está atacando para pasar (segundos que le quedan)
var close_t := 0.0 # tiempo seguido que lleva pegado atrás
var gap := 0.0 # metros que le lleva el rival al jugador (negativo: el jugador va adelante)
var swaps := 0
# eliminación
var every := 30.0
var next_t := 30.0
var alive_n := 0
var out_n := 0

## opts: {max_gap, every, skill, names}
func setup(p_kind: String, p_session, p_cars: Array, p_hud, opts := {}) -> void:
	kind = p_kind
	session = p_session
	cars = p_cars
	hud = p_hud
	names = opts.get("names", [])
	max_gap = float(opts.get("max_gap", 150.0))
	every = float(opts.get("every", 30.0))
	next_t = every
	diff = clampf((float(opts.get("skill", 0.9)) - 0.62) / 0.42, 0.0, 1.0)
	alive_n = cars.size()
	session.out_t.fill(-1.0)

func update(dt: float) -> void:
	if done or session == null or session.state != "run":
		return
	match kind:
		"chase":
			_chase(dt)
		"elim":
			_elim(dt)

func _say(t: String, color := Color.WHITE) -> void:
	if hud != null:
		hud.big(t, color)

# ───────────────────────── persecución ─────────────────────────
func _chase(dt: float) -> void:
	if cars.size() < 2:
		return
	gap = session.prog[1] - session.prog[0]
	# roles: cambian cuando alguien pasa al otro por más de unos metros (así no parpadean en un codo a codo)
	if lead_player and gap > 3.0:
		lead_player = false
		swaps += 1
		session.messages.append(["⬇ ¡Te pasó! Ahora lo perseguís", "down"])
		close_t = 0.0
		pass_t = 0.0
	elif not lead_player and gap < -3.0:
		lead_player = true
		swaps += 1
		session.messages.append(["⬆ ¡Lo pasaste! Ahora te persigue", "up"])
		close_t = 0.0
		pass_t = 0.0
	# fin: uno se escapa a max_gap
	if gap >= max_gap or gap <= -max_gap:
		win = gap <= -max_gap
		_finish("¡LO DEJASTE ATRÁS!" if win else "¡SE TE ESCAPÓ!", win)
		return
	# el rival: su ritmo propio depende del nivel (de 0,90 a 1,04 del ritmo de la IA). Adelante sostiene ese ritmo (si es más rápido que vos, se escapa); atrás acelera hasta un 5 % más para alcanzarte,
	# se queda pegado a unos 12 m y de a ratos ataca (un 6 % más) para pasarte
	var d = cars[1].driver
	if d is AIDriver:
		var base := lerpf(0.90, 1.04, diff)
		var pace := base
		if lead_player:
			var behind := -gap
			pace = base + clampf((behind - 12.0) / 60.0, 0.0, 1.0) * 0.05
			if pass_t > 0.0:
				pass_t -= dt
				pace = base + 0.06
			else:
				close_t = close_t + dt if behind < 30.0 else maxf(0.0, close_t - dt)
				if close_t > lerpf(22.0, 9.0, diff):
					pass_t = 8.0
					close_t = 0.0
		d.pace = lerpf(d.pace, pace, clampf(dt * 1.5, 0.0, 1.0))
		cars[1].phys.powerMul = 1.0
	# texto del HUD
	session.rule_text = "🎯 %s · %d / %d m" % ["VAS ADELANTE" if lead_player else "PERSEGUÍS", int(absf(gap)), int(max_gap)]
	var frac := absf(gap) / max_gap
	if not lead_player and frac > 0.66:
		session.rule_sub = "⚠ ¡SE ESCAPA! %d m" % int(absf(gap))
		session.rule_warn = true
	elif lead_player and frac > 0.66:
		session.rule_sub = "¡Casi lo dejás atrás! %d m" % int(absf(gap))
		session.rule_warn = false
	else:
		session.rule_sub = ""
		session.rule_warn = false

# ───────────────────────── eliminación ─────────────────────────
func _elim(_dt: float) -> void:
	var t: float = session.time
	var left := next_t - t
	if left <= 0.0:
		var worst := -1
		for i in cars.size():
			if session.out_t[i] >= 0.0:
				continue
			if worst < 0 or session.prog[i] < session.prog[worst]:
				worst = i
		if worst >= 0:
			_eliminate(worst)
		next_t += every
		left = next_t - t
		if done:
			return
	var pos := 1
	for i in range(1, cars.size()):
		if session.out_t[i] < 0.0 and session.prog[i] > session.prog[0]:
			pos += 1
	var worst_pos := alive_n
	session.rule_text = "💀 QUEDAN %d de %d · sale otro en %d s" % [alive_n, cars.size(), int(ceil(left))]
	if pos == worst_pos and alive_n > 1:
		session.rule_sub = "⚠ ¡VAS ÚLTIMO! ¡Pasá a alguien!" if left <= 12.0 else "vas último (%d°)" % pos
		session.rule_warn = left <= 12.0
	else:
		session.rule_sub = "vas %d° de los que quedan" % pos
		session.rule_warn = false
	if left <= 3.0 and int(ceil(left)) != int(ceil(left + _dt)) and pos == worst_pos and alive_n > 1:
		session.messages.append(["⚠ ¡%d!" % int(ceil(left)), "down"])

func _eliminate(i: int) -> void:
	session.out_t[i] = session.time
	alive_n -= 1
	out_n += 1
	var c = cars[i]
	var nm := str(names[i]) if i < names.size() else "Auto %d" % i
	if i == 0:
		win = false
		_finish("¡ELIMINADO!", false)
		return
	# el auto sale de la carrera: se lo saca de la pista y se lo frena (no estorba ni se ve)
	if c.driver != null:
		c.driver.enabled = false
	c.out = true
	c.visual.visible = false
	c.place(1.0e5 + float(i) * 50.0, 1.0e5, 0.0)
	session.messages.append(["💀 %s eliminado" % nm, "up"])
	if alive_n <= 1:
		win = true
		_finish("¡GANASTE LA ELIMINACIÓN!", true)

# ───────────────────────── final ─────────────────────────
func _finish(text: String, p_win: bool) -> void:
	done = true
	win = p_win
	note = text
	session.rule_text = text
	session.rule_sub = ""
	session.state = "done"
	session.finished[0] = true
	session.finish_time[0] = session.time
	_say(text, Color(0.5, 1.0, 0.6) if p_win else Color(1.0, 0.35, 0.3))

## Puesto final del jugador (1 = ganó)
func result_pos() -> int:
	if kind == "chase":
		return 1 if win else 2
	return session.position_of(0, cars.size())
