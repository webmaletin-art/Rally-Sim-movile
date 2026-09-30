extends RefCounted
## Sintetizador del sonido del auto: la misma cadena de Web Audio de la versión HTML (AudioEngine, js/main.js), calculada muestra
## a muestra: 5 osciladores del motor + modulación + saturación + pasabajos, ruido filtrado (motor, rodado, chillido de gomas,
## grava, viento, soplido del turbo, lluvia), silbido del turbo, caja de engranajes rectos, motor de un rival cercano,
## ráfagas (flutter del turbo, petardeos) y golpes. Los parámetros se cargan con set_target() y cada uno se acerca de a poco
## (como setTargetAtTime), así que no hay saltos. render() devuelve bloques de audio; se llama desde un hilo aparte.

const FS := 22050.0
const NOISE_N := 65536
const P_F0 := 0 # frecuencia base del motor (Hz) = rpm/60 · orden de encendido
const P_CUT := 1 # corte del pasabajos del motor
const P_ENG := 2 # volumen del motor
const P_ENGN := 3 # ruido del motor
const P_ROLL := 4
const P_SQ := 5
const P_SQF := 6
const P_GRAV := 7
const P_WIND := 8
const P_WINDF := 9
const P_GW := 10 # volumen de la caja
const P_WF := 11 # frecuencia de la caja (Hz)
const P_GWE := 12
const P_GWEF := 13
const P_TW := 14 # silbido del turbo
const P_TWF := 15
const P_TB := 16 # soplido del turbo
const P_TBF := 17
const P_RAIN := 18
const P_AI := 19 # motor de un rival
const P_AIF := 20
const P_MASTER := 21
const NP := 22

## constante de tiempo (s) con la que cada parámetro alcanza su objetivo (0 = salta de una)
const TIME_K := [0.012, 0.03, 0.03, 0.05, 0.08, 0.05, 0.03, 0.03, 0.1, 0.1, 0.05, 0.03, 0.04, 0.02, 0.05, 0.06, 0.08, 0.05, 0.4, 0.08, 0.05, 0.05]

var target := PackedFloat32Array()
var cur := PackedFloat32Array()
var tau_gw_fast := false # la caja se corta más rápido cuando se suelta el embrague
var gw_tau := 0.05

# osciladores (fase 0..1)
var ph1 := 0.0
var ph2 := 0.0
var ph3 := 0.0
var ph4 := 0.0
var ph5 := 0.0
var ph_lfo := 0.0
var ph_g1 := 0.0
var ph_g2 := 0.0
var ph_g3 := 0.0
var ph_ge := 0.0
var ph_tw := 0.0
var ph_ai1 := 0.0
var ph_ai2 := 0.0
# ruido
var noise := PackedFloat32Array()
var np := 0
# biquads (x1,x2,y1,y2) + coeficientes
var lp_e := [0.0, 0.0, 0.0, 0.0] # motor: pasabajos
var bp_en := [0.0, 0.0, 0.0, 0.0] # ruido del motor
var bp_roll := [0.0, 0.0, 0.0, 0.0]
var bp_sq := [0.0, 0.0, 0.0, 0.0]
var hp_gr := [0.0, 0.0, 0.0, 0.0]
var bp_gr := [0.0, 0.0, 0.0, 0.0]
var bp_wind := [0.0, 0.0, 0.0, 0.0]
var bp_gw := [0.0, 0.0, 0.0, 0.0]
var bp_tb := [0.0, 0.0, 0.0, 0.0]
var hp_rain := [0.0, 0.0, 0.0, 0.0]
var lp_ai := [0.0, 0.0, 0.0, 0.0]
var c_lp_e := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_en := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_roll := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_sq := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_hp_gr := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_gr := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_wind := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_gw := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_bp_tb := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_hp_rain := [0.0, 0.0, 0.0, 0.0, 0.0]
var c_lp_ai := [0.0, 0.0, 0.0, 0.0, 0.0]
# compresor
var comp_env := 0.0
# ráfagas y golpes
var _queue: Array = [] # pendientes: {at (muestra), dur, f, q, amp, type}
var _mutex := Mutex.new()
var bursts: Array = [] # activas
var samples_done := 0

func _init() -> void:
	target.resize(NP)
	cur.resize(NP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	noise.resize(NOISE_N)
	for i in NOISE_N:
		noise[i] = (rng.randf() * 2.0 - 1.0) * 0.7071 # a 22 kHz hay el doble de densidad de ruido que a 44 kHz: se compensa para sonar como Web Audio
	cur[P_CUT] = 400.0
	target[P_CUT] = 400.0
	cur[P_F0] = 50.0
	target[P_F0] = 50.0
	cur[P_SQF] = 1150.0
	target[P_SQF] = 1150.0
	cur[P_WINDF] = 700.0
	target[P_WINDF] = 700.0
	cur[P_WF] = 400.0
	target[P_WF] = 400.0
	cur[P_GWEF] = 100.0
	target[P_GWEF] = 100.0
	cur[P_TWF] = 2000.0
	target[P_TWF] = 2000.0
	cur[P_TBF] = 3600.0
	target[P_TBF] = 3600.0
	cur[P_AIF] = 80.0
	target[P_AIF] = 80.0
	cur[P_MASTER] = 0.55
	target[P_MASTER] = 0.55

func set_target(idx: int, v: float) -> void:
	target[idx] = v

func now_samples() -> int:
	return samples_done

## ráfaga de ruido filtrado (pasabanda o pasabajos) con ataque de 4 ms y caída exponencial hasta 0,0008. delay en segundos.
func burst(delay: float, dur: float, f: float, q: float, amp: float, lowpass := false) -> void:
	_mutex.lock()
	_queue.append({"at": samples_done + int(delay * FS), "dur": dur, "f": f, "q": q, "amp": amp, "type": 1 if lowpass else 0})
	_mutex.unlock()

## golpe grave (aterrizaje, choque): seno que baja de 75 a 38 Hz + ráfaga grave
func thump(strength: float, impacts: float) -> void:
	var a := minf(1.0, strength) * impacts
	_mutex.lock()
	_queue.append({"at": samples_done, "dur": 0.28, "f": 75.0, "q": 0.0, "amp": a * 0.9, "type": 2})
	_mutex.unlock()
	burst(0.0, 0.12, 180.0, 0.7, a * 0.6, true)

# ───────────────────────── biquads (fórmulas de Web Audio) ─────────────────────────
## tipo: 0 pasabajos (Q en dB), 1 pasaaltos (Q en dB), 2 pasabanda (Q lineal)
static func coeffs(c: Array, type: int, f: float, q: float) -> void:
	f = clampf(f, 10.0, FS * 0.49)
	var w0 := TAU * f / FS
	var cw := cos(w0)
	var sw := sin(w0)
	var b0: float
	var b1: float
	var b2: float
	var alpha: float
	if type == 2:
		alpha = sw / (2.0 * maxf(q, 0.01))
		b0 = alpha
		b1 = 0.0
		b2 = -alpha
	else:
		alpha = sw / (2.0 * pow(10.0, q / 20.0))
		if type == 0:
			b0 = (1.0 - cw) * 0.5
			b1 = 1.0 - cw
			b2 = b0
		else:
			b0 = (1.0 + cw) * 0.5
			b1 = -(1.0 + cw)
			b2 = (1.0 + cw) * 0.5
	var a0 := 1.0 + alpha
	c[0] = b0 / a0
	c[1] = b1 / a0
	c[2] = b2 / a0
	c[3] = -2.0 * cw / a0
	c[4] = (1.0 - alpha) / a0

static func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var y := (t - 1.0) / dt
		return y * y + y + y + 1.0
	return 0.0

## Genera n muestras (mono, ya con la compresión y el volumen general)
func render(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var blk := float(n) / FS
	# se acercan los parámetros a su objetivo (como setTargetAtTime): valor al principio y al final del bloque
	var v0 := PackedFloat32Array(cur)
	for i in NP:
		var tau: float = TIME_K[i]
		if i == P_GW:
			tau = gw_tau
		var k := 1.0 - exp(-blk / tau) if tau > 0.0 else 1.0
		cur[i] += (target[i] - cur[i]) * k
	var v1 := cur
	# coeficientes de los filtros que cambian
	coeffs(c_lp_e, 0, v1[P_CUT], 0.8)
	coeffs(c_bp_en, 2, v1[P_F0], 1.5)
	coeffs(c_bp_roll, 2, 380.0, 0.7)
	coeffs(c_bp_sq, 2, v1[P_SQF], 7.0)
	coeffs(c_hp_gr, 1, 900.0, 0.7)
	coeffs(c_bp_gr, 2, 2500.0, 0.8)
	coeffs(c_bp_wind, 2, v1[P_WINDF], 0.5)
	coeffs(c_bp_gw, 2, maxf(200.0, v1[P_WF] * 1.05), 6.0)
	coeffs(c_bp_tb, 2, v1[P_TBF], 4.0)
	coeffs(c_hp_rain, 1, 1800.0, 0.7)
	coeffs(c_lp_ai, 0, 900.0, 1.0)
	# ráfagas pendientes → activas
	_mutex.lock()
	var keep: Array = []
	for b in _queue:
		if b["at"] < samples_done + n:
			var v := {"at": b["at"], "n": 0, "dur": b["dur"], "type": b["type"], "f": b["f"], "amp": b["amp"], "c": [0.0, 0.0, 0.0, 0.0, 0.0], "s": [0.0, 0.0, 0.0, 0.0], "ph": 0.0}
			if b["type"] != 2:
				coeffs(v["c"], 0 if b["type"] == 1 else 2, b["f"], b["q"] if b["type"] == 0 else 0.7)
			bursts.append(v)
		else:
			keep.append(b)
	_queue = keep
	_mutex.unlock()

	var g_eng0: float = v0[P_ENG]
	var g_eng1: float = v1[P_ENG]
	var f0a: float = v0[P_F0]
	var f0b: float = v1[P_F0]
	var enn0: float = v0[P_ENGN]
	var enn1: float = v1[P_ENGN]
	var roll0: float = v0[P_ROLL]
	var roll1: float = v1[P_ROLL]
	var sq0: float = v0[P_SQ]
	var sq1: float = v1[P_SQ]
	var gr0: float = v0[P_GRAV]
	var gr1: float = v1[P_GRAV]
	var wi0: float = v0[P_WIND]
	var wi1: float = v1[P_WIND]
	var gw0: float = v0[P_GW]
	var gw1: float = v1[P_GW]
	var wfa: float = v0[P_WF]
	var wfb: float = v1[P_WF]
	var ge0: float = v0[P_GWE]
	var ge1: float = v1[P_GWE]
	var gef0: float = v0[P_GWEF]
	var gef1: float = v1[P_GWEF]
	var tw0: float = v0[P_TW]
	var tw1: float = v1[P_TW]
	var twf0: float = v0[P_TWF]
	var twf1: float = v1[P_TWF]
	var tb0: float = v0[P_TB]
	var tb1: float = v1[P_TB]
	var rn0: float = v0[P_RAIN]
	var rn1: float = v1[P_RAIN]
	var ai0: float = v0[P_AI]
	var ai1: float = v1[P_AI]
	var aif0: float = v0[P_AIF]
	var aif1: float = v1[P_AIF]
	var ms0: float = v0[P_MASTER]
	var ms1: float = v1[P_MASTER]
	var run_eng := g_eng0 > 1e-5 or g_eng1 > 1e-5
	var run_enn := (enn0 > 1e-5 or enn1 > 1e-5) and run_eng
	var run_roll := roll0 > 1e-5 or roll1 > 1e-5
	var run_sq := sq0 > 1e-5 or sq1 > 1e-5
	var run_gr := gr0 > 1e-5 or gr1 > 1e-5
	var run_wi := wi0 > 1e-5 or wi1 > 1e-5
	var run_gw := gw0 > 1e-5 or gw1 > 1e-5
	var run_ge := ge0 > 1e-5 or ge1 > 1e-5
	var run_tw := tw0 > 1e-5 or tw1 > 1e-5
	var run_tb := tb0 > 1e-5 or tb1 > 1e-5
	var run_rn := rn0 > 1e-5 or rn1 > 1e-5
	var run_ai := ai0 > 1e-5 or ai1 > 1e-5
	var inv := 1.0 / float(n)
	var ninv := 1.0 / FS
	var npos := np
	var mask := NOISE_N - 1
	var tot_gain0 := ms0
	for s in n:
		var a := float(s) * inv
		var ms := ms0 + (ms1 - ms0) * a
		var mix := 0.0
		var f0 := f0a + (f0b - f0a) * a
		# ── motor ──
		if run_eng:
			var d1 := f0 * ninv
			ph1 += d1
			if ph1 >= 1.0:
				ph1 -= 1.0
			ph2 += d1 * 0.5
			if ph2 >= 1.0:
				ph2 -= 1.0
			ph3 += d1 * 2.0
			if ph3 >= 1.0:
				ph3 -= 1.0
			ph4 += d1 * 0.25
			if ph4 >= 1.0:
				ph4 -= 1.0
			ph5 += d1 * 1.5
			if ph5 >= 1.0:
				ph5 -= 1.0
			ph_lfo += d1 * 0.125
			if ph_lfo >= 1.0:
				ph_lfo -= 1.0
			var saw1 := 2.0 * ph1 - 1.0 - _blep(ph1, d1)
			var saw2 := 2.0 * ph2 - 1.0 - _blep(ph2, d1 * 0.5)
			var sqr := (1.0 if ph3 < 0.5 else -1.0) + _blep(ph3, d1 * 2.0) - _blep(fposmod(ph3 + 0.5, 1.0), d1 * 2.0)
			var sn := sin(TAU * ph4)
			var tri := 4.0 * absf(ph5 - 0.5) - 1.0
			var m := saw1 * 0.45 + saw2 * 0.35 + sqr * 0.08 + sn * 0.45 + tri * 0.10
			m *= 0.75 + 0.25 * sin(TAU * ph_lfo)
			m = tanh(2.2 * clampf(m, -1.0, 1.0))
			# pasabajos del motor
			var y: float = c_lp_e[0] * m + c_lp_e[1] * lp_e[0] + c_lp_e[2] * lp_e[1] - c_lp_e[3] * lp_e[2] - c_lp_e[4] * lp_e[3]
			lp_e[1] = lp_e[0]
			lp_e[0] = m
			lp_e[3] = lp_e[2]
			lp_e[2] = y
			var ge := g_eng0 + (g_eng1 - g_eng0) * a
			mix += y * ge
			if run_enn:
				var nz := noise[(npos + 11113) & mask]
				var yn: float = c_bp_en[0] * nz + c_bp_en[2] * bp_en[1] - c_bp_en[3] * bp_en[2] - c_bp_en[4] * bp_en[3]
				bp_en[1] = bp_en[0]
				bp_en[0] = nz
				bp_en[3] = bp_en[2]
				bp_en[2] = yn
				mix += yn * (enn0 + (enn1 - enn0) * a) * ge
		# ── ruido de las gomas y el viento ──
		if run_roll:
			var nz2 := noise[(npos + 3001) & mask]
			var yr: float = c_bp_roll[0] * nz2 + c_bp_roll[2] * bp_roll[1] - c_bp_roll[3] * bp_roll[2] - c_bp_roll[4] * bp_roll[3]
			bp_roll[1] = bp_roll[0]
			bp_roll[0] = nz2
			bp_roll[3] = bp_roll[2]
			bp_roll[2] = yr
			mix += yr * (roll0 + (roll1 - roll0) * a)
		if run_sq:
			var nz3 := noise[(npos + 22003) & mask]
			var ys: float = c_bp_sq[0] * nz3 + c_bp_sq[2] * bp_sq[1] - c_bp_sq[3] * bp_sq[2] - c_bp_sq[4] * bp_sq[3]
			bp_sq[1] = bp_sq[0]
			bp_sq[0] = nz3
			bp_sq[3] = bp_sq[2]
			bp_sq[2] = ys
			mix += ys * (sq0 + (sq1 - sq0) * a)
		if run_gr:
			var nz4 := noise[(npos + 40009) & mask]
			var yh: float = c_hp_gr[0] * nz4 + c_hp_gr[1] * hp_gr[0] + c_hp_gr[2] * hp_gr[1] - c_hp_gr[3] * hp_gr[2] - c_hp_gr[4] * hp_gr[3]
			hp_gr[1] = hp_gr[0]
			hp_gr[0] = nz4
			hp_gr[3] = hp_gr[2]
			hp_gr[2] = yh
			var yg: float = c_bp_gr[0] * yh + c_bp_gr[2] * bp_gr[1] - c_bp_gr[3] * bp_gr[2] - c_bp_gr[4] * bp_gr[3]
			bp_gr[1] = bp_gr[0]
			bp_gr[0] = yh
			bp_gr[3] = bp_gr[2]
			bp_gr[2] = yg
			mix += yg * (gr0 + (gr1 - gr0) * a)
		if run_wi:
			var nz5 := noise[(npos + 51001) & mask]
			var yw: float = c_bp_wind[0] * nz5 + c_bp_wind[2] * bp_wind[1] - c_bp_wind[3] * bp_wind[2] - c_bp_wind[4] * bp_wind[3]
			bp_wind[1] = bp_wind[0]
			bp_wind[0] = nz5
			bp_wind[3] = bp_wind[2]
			bp_wind[2] = yw
			mix += yw * (wi0 + (wi1 - wi0) * a)
		# ── caja de engranajes rectos: dos tonos casi iguales (batido metálico) + uno que sigue al motor ──
		if run_gw:
			var wf := wfa + (wfb - wfa) * a
			var dg := maxf(40.0, wf) * ninv
			ph_g1 += dg
			if ph_g1 >= 1.0:
				ph_g1 -= 1.0
			ph_g2 += dg * 1.007
			if ph_g2 >= 1.0:
				ph_g2 -= 1.0
			ph_g3 += dg * 2.0
			if ph_g3 >= 1.0:
				ph_g3 -= 1.0
			var t1 := 4.0 * absf(ph_g1 - 0.5) - 1.0
			var t2 := 4.0 * absf(ph_g2 - 0.5) - 1.0
			var s3 := 2.0 * ph_g3 - 1.0 - _blep(ph_g3, dg * 2.0)
			var gin := t1 * 0.6 + t2 * 0.45 + s3 * 0.12
			var yq: float = c_bp_gw[0] * gin + c_bp_gw[2] * bp_gw[1] - c_bp_gw[3] * bp_gw[2] - c_bp_gw[4] * bp_gw[3]
			bp_gw[1] = bp_gw[0]
			bp_gw[0] = gin
			bp_gw[3] = bp_gw[2]
			bp_gw[2] = yq
			mix += yq * (gw0 + (gw1 - gw0) * a)
		if run_ge:
			var dge := (gef0 + (gef1 - gef0) * a) * ninv
			ph_ge += dge
			if ph_ge >= 1.0:
				ph_ge -= 1.0
			mix += (4.0 * absf(ph_ge - 0.5) - 1.0) * (ge0 + (ge1 - ge0) * a)
		# ── turbo: silbido (seno) y soplido ──
		if run_tw:
			ph_tw += (twf0 + (twf1 - twf0) * a) * ninv
			if ph_tw >= 1.0:
				ph_tw -= 1.0
			mix += sin(TAU * ph_tw) * (tw0 + (tw1 - tw0) * a)
		if run_tb:
			var nz6 := noise[(npos + 12007) & mask]
			var yt: float = c_bp_tb[0] * nz6 + c_bp_tb[2] * bp_tb[1] - c_bp_tb[3] * bp_tb[2] - c_bp_tb[4] * bp_tb[3]
			bp_tb[1] = bp_tb[0]
			bp_tb[0] = nz6
			bp_tb[3] = bp_tb[2]
			bp_tb[2] = yt
			mix += yt * (tb0 + (tb1 - tb0) * a)
		if run_rn:
			var nz7 := noise[(npos + 30011) & mask]
			var yl: float = c_hp_rain[0] * nz7 + c_hp_rain[1] * hp_rain[0] + c_hp_rain[2] * hp_rain[1] - c_hp_rain[3] * hp_rain[2] - c_hp_rain[4] * hp_rain[3]
			hp_rain[1] = hp_rain[0]
			hp_rain[0] = nz7
			hp_rain[3] = hp_rain[2]
			hp_rain[2] = yl
			mix += yl * (rn0 + (rn1 - rn0) * a)
		# ── motor de un rival cercano ──
		if run_ai:
			var da := (aif0 + (aif1 - aif0) * a) * ninv
			ph_ai1 += da
			if ph_ai1 >= 1.0:
				ph_ai1 -= 1.0
			ph_ai2 += da * 0.5
			if ph_ai2 >= 1.0:
				ph_ai2 -= 1.0
			var ain := (2.0 * ph_ai1 - 1.0 - _blep(ph_ai1, da)) + (2.0 * ph_ai2 - 1.0 - _blep(ph_ai2, da * 0.5))
			var ya: float = c_lp_ai[0] * ain + c_lp_ai[1] * lp_ai[0] + c_lp_ai[2] * lp_ai[1] - c_lp_ai[3] * lp_ai[2] - c_lp_ai[4] * lp_ai[3]
			lp_ai[1] = lp_ai[0]
			lp_ai[0] = ain
			lp_ai[3] = lp_ai[2]
			lp_ai[2] = ya
			mix += ya * (ai0 + (ai1 - ai0) * a)
		npos += 1
		# ── ráfagas y golpes ──
		if not bursts.is_empty():
			var gidx := samples_done + s
			var bi := 0
			while bi < bursts.size():
				var bv: Dictionary = bursts[bi]
				var tt := float(gidx - int(bv["at"])) * ninv
				if tt < 0.0:
					bi += 1
					continue
				var dur: float = bv["dur"]
				if tt >= dur:
					bursts.remove_at(bi)
					continue
				var amp: float = bv["amp"]
				var env := 0.0
				if bv["type"] == 2:
					# seno grave que cae de 75 a 38 Hz, con caída exponencial
					var fq := 75.0 * pow(38.0 / 75.0, minf(tt / 0.22, 1.0))
					bv["ph"] = fposmod(float(bv["ph"]) + fq * ninv, 1.0)
					env = amp * pow(0.001 / maxf(amp, 0.001), tt / dur)
					mix += sin(TAU * float(bv["ph"])) * env
				else:
					if tt < 0.004:
						env = amp * tt / 0.004
					else:
						env = amp * pow(0.0008 / maxf(amp, 0.0008), (tt - 0.004) / maxf(dur - 0.004, 0.001))
					var c: Array = bv["c"]
					var st: Array = bv["s"]
					var nzb := noise[(npos + int(bv["at"]) * 7) & mask]
					var yb: float
					if bv["type"] == 1:
						yb = c[0] * nzb + c[1] * st[0] + c[2] * st[1] - c[3] * st[2] - c[4] * st[3]
					else:
						yb = c[0] * nzb + c[2] * st[1] - c[3] * st[2] - c[4] * st[3]
					st[1] = st[0]
					st[0] = nzb
					st[3] = st[2]
					st[2] = yb
					mix += yb * env
				bi += 1
		# ── volumen general y compresor (umbral -14 dB, relación 4) ──
		var x := mix * ms
		var ax := absf(x)
		comp_env = maxf(ax, comp_env * 0.9995)
		if comp_env > 0.2:
			x *= (0.2 + (comp_env - 0.2) * 0.25) / comp_env
		out[s] = clampf(x, -1.0, 1.0)
	np = npos & 0x7fffffff
	samples_done += n
	return out
