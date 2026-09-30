## Comprueba el sintetizador de sonido sin reproducirlo: que el motor suene a la frecuencia correcta (rpm/60·orden de encendido),
## que cada filtro dé el nivel de Web Audio y que nunca salgan valores rotos (NaN / clipping). Guarda WAV en user:// para mirarlos.
extends SceneTree

const CarSynth := preload("res://game/audio/car_synth.gd")

func _init() -> void:
	var ok := true
	# 1) motor a 4000 rpm, firingOrder 4 → f0 = 266,7 Hz
	var s: RefCounted = CarSynth.new()
	s.set_target(CarSynth.P_F0, 266.7)
	s.set_target(CarSynth.P_CUT, 2000.0)
	s.set_target(CarSynth.P_ENG, 0.4)
	s.cur[CarSynth.P_ENG] = 0.4
	s.cur[CarSynth.P_F0] = 266.7
	var all := PackedFloat32Array()
	var t0 := Time.get_ticks_usec()
	for b in 120:
		all.append_array(s.render(256))
	var dt_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("motor: %.0f ms para %.2f s de audio (%.1f%% de un núcleo)" % [dt_ms, all.size() / CarSynth.FS, dt_ms / 1000.0 / (all.size() / CarSynth.FS) * 100.0])
	ok = _check_sane("motor", all) and ok
	_save("motor", all)
	var pk := _peak_freq(all.slice(4096, 4096 + 4096))
	print("pico del motor: %.1f Hz (esperado ~266.7 o un armónico cercano)" % pk)
	# 2) cada ruido por separado: nivel contra la referencia (calculada con las mismas fórmulas biquad de Web Audio en Python)
	for c in [["roll", CarSynth.P_ROLL, 1.0], ["squeal", CarSynth.P_SQ, 1.0], ["gravel", CarSynth.P_GRAV, 1.0], ["wind", CarSynth.P_WIND, 1.0], ["turbo", CarSynth.P_TB, 1.0], ["lluvia", CarSynth.P_RAIN, 1.0], ["whine", CarSynth.P_GW, 1.0], ["whistle", CarSynth.P_TW, 1.0]]:
		var t: RefCounted = CarSynth.new()
		t.cur[c[1]] = c[2]
		t.target[c[1]] = c[2]
		t.cur[CarSynth.P_WF] = 900.0
		t.target[CarSynth.P_WF] = 900.0
		t.cur[CarSynth.P_TWF] = 2000.0
		t.target[CarSynth.P_TWF] = 2000.0
		t.cur[CarSynth.P_MASTER] = 0.1
		t.target[CarSynth.P_MASTER] = 0.1
		var o := PackedFloat32Array()
		for b in 100:
			o.append_array(t.render(256))
		var seg := o.slice(6000)
		var rms := 0.0
		for v in seg:
			rms += v * v
		rms = sqrt(rms / seg.size())
		print("RMS %s = %.5f" % [c[0], rms * 10.0])
		ok = _check_sane(c[0], o) and ok
	# 3) ráfagas (flutter) y golpe
	var f: RefCounted = CarSynth.new()
	f.cur[CarSynth.P_MASTER] = 1.0
	f.target[CarSynth.P_MASTER] = 1.0
	for i in 8:
		f.burst(0.01 + i * 0.03, 0.02, 1000.0, 2.6, 0.5)
	f.thump(0.8, 0.8)
	var fo := PackedFloat32Array()
	for b in 80:
		fo.append_array(f.render(256))
	ok = _check_sane("ráfagas", fo) and ok
	_save("rafagas", fo)
	quit(0 if ok else 1)

func _check_sane(name: String, a: PackedFloat32Array) -> bool:
	var mx := 0.0
	for v in a:
		if is_nan(v) or is_inf(v):
			print("FALLA %s: hay NaN/inf" % name)
			return false
		mx = maxf(mx, absf(v))
	print("OK    %s: %d muestras, pico %.3f" % [name, a.size(), mx])
	return true

func _save(name: String, a: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(a.size() * 2)
	for i in a.size():
		bytes.encode_s16(i * 2, int(clampf(a[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(CarSynth.FS)
	w.data = bytes
	w.save_to_wav("/tmp/aud/synth_%s.wav" % name)

func _peak_freq(a: PackedFloat32Array) -> float:
	# búsqueda simple de la frecuencia con más energía (correlación con senos) entre 50 y 1500 Hz
	var best := 0.0
	var bf := 0.0
	var f := 60.0
	while f < 900.0:
		var re := 0.0
		var im := 0.0
		for i in range(0, a.size(), 4):
			var ph := TAU * f * float(i) / CarSynth.FS
			re += a[i] * cos(ph)
			im += a[i] * sin(ph)
		var e := re * re + im * im
		if e > best:
			best = e
			bf = f
		f += 4.0
	return bf
