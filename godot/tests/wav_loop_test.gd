## Bucles de sonido seguros (game/audio/wav_loop.gd): CAUSA CONFIRMADA de los cierres nativos del 14–15/10/2026 (lápida del Z2356: SIGSEGV en el
## hilo «AudioTrack», AudioStreamPlaybackWAV::decode_samples). Godot lee hasta loop_end INCLUSIVE; el juego ponía loop_end = muestras y leía una
## muestra fuera de los datos en cada vuelta. Comprueba, para cada sonido en bucle del juego, que el bucle nunca pase del final y que siga siendo
## exacto (la muestra agregada es la primera), y que ningún script vuelva a poner loop_end a mano.
## Uso: godot --headless --path godot --script res://tests/wav_loop_test.gd
extends SceneTree

const WavLoop := preload("res://game/audio/wav_loop.gd")
const DIR := "res://game/audio/samples/"
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)

func _initialize() -> void:
	var consts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "consts.json"))
	var n := 0
	var bad: Array = []
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".wav"):
			continue
		var name := f.get_basename()
		var src: AudioStreamWAV = load(DIR + f) as AudioStreamWAV
		if src == null:
			continue
		var frames := int((consts.get(name, {}) as Dictionary).get("n", src.data.size() / 2)) if consts.get(name) is Dictionary else src.data.size() / 2
		var w := WavLoop.make(src.duplicate() as AudioStreamWAV, frames)
		var bpf := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
		var ok := WavLoop.safe(w) and w.data.slice(w.data.size() - bpf) == w.data.slice(0, bpf) and w.loop_end == frames
		if not ok:
			bad.append("%s (loop_end %d, muestras %d)" % [name, w.loop_end, w.data.size() / bpf])
		# el original sin tocar (no se modifica el recurso compartido)
		if src.data.size() / bpf != frames and consts.get(name) is Dictionary:
			bad.append("%s: el recurso original cambió" % name)
		n += 1
	_check(n >= 20 and bad.is_empty(), "%d sonidos: el bucle termina dentro de los datos y la última muestra es la primera (bucle exacto) %s" % [n, str(bad)])
	# el bucle viejo (loop_end = muestras) es el que leía afuera
	var old: AudioStreamWAV = (load(DIR + "eng_on0.wav") as AudioStreamWAV).duplicate()
	old.loop_mode = AudioStreamWAV.LOOP_FORWARD
	old.loop_end = old.data.size() / 2
	_check(not WavLoop.safe(old), "el bucle de antes (loop_end = muestras) se detecta como inseguro")
	# nadie vuelve a poner loop_end a mano
	var files: Array = []
	_scan("res://game", files)
	var raw: Array = []
	for p in files:
		if str(p).ends_with("wav_loop.gd"):
			continue
		var re := RegEx.create_from_string("\\.loop_end\\s*=")
		if re.search(FileAccess.get_file_as_string(p)) != null:
			raw.append(p)
	_check(raw.is_empty(), "ningún script pone loop_end a mano (todos usan WavLoop.make) %s" % str(raw))
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
