## Lápida de Android (game/diag/tombstone.gd): arma una lápida con el formato de AOSP (tombstone.proto) y comprueba que se lean
## la señal, la dirección, el hilo que se rompió, sus cuadros (biblioteca + dirección + función) y las últimas líneas de logcat.
## Uso: godot --headless --path godot --script res://tests/tombstone_test.gd
extends SceneTree

const Tombstone := preload("res://game/diag/tombstone.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _vi(v: int) -> PackedByteArray:
	var o := PackedByteArray()
	var first := true
	while first or v != 0:
		first = false
		var c := v & 0x7f
		v = (v >> 7) & 0x01ffffffffffffff # (sin signo)
		if v != 0:
			c |= 0x80
		o.append(c)
	return o

func _int(f: int, v: int) -> PackedByteArray:
	return _vi(f << 3) + _vi(v)

func _len(f: int, b: PackedByteArray) -> PackedByteArray:
	return _vi((f << 3) | 2) + _vi(b.size()) + b

func _str(f: int, s: String) -> PackedByteArray:
	return _len(f, s.to_utf8_buffer())

func _frame(rel: int, file: String, fn: String, off: int, bid := "") -> PackedByteArray:
	var b := _int(1, rel) + _int(2, rel + 0x7000000000) + _str(6, file)
	if fn != "":
		b += _str(4, fn) + _int(5, off)
	if bid != "":
		b += _str(8, bid)
	return b

func _initialize() -> void:
	# Tombstone: 6 tid, 10 Signal, 15 Cause, 16 threads (map), 18 log_buffers
	var sig := _int(1, 11) + _str(2, "SIGSEGV") + _int(3, 1) + _str(4, "SEGV_MAPERR") + _int(8, 1) + _int(9, 0x18)
	var th_bad := _int(1, 4242) + _str(2, "GLThread 12") \
		+ _len(4, _frame(0x2a1b4, "/vendor/lib64/egl/libGLES_mali.so", "", 0, "abcdef0123456789abcdef")) \
		+ _len(4, _frame(0x1d2c3e0, "/data/app/~~x/com.dream/lib/arm64/libgodot_android.so", "", 0, "1234567890abcdef1234"))
	var th_ok := _int(1, 4200) + _str(2, "main") + _len(4, _frame(0x10, "/system/lib64/libc.so", "__epoll_pwait", 8))
	var lm := _str(1, "10-14 21:25:07.123") + _int(3, 4242) + _int(4, 6) + _str(5, "Mali") + _str(6, "gles_texture: out of memory")
	var t := _int(6, 4242) + _len(10, sig) + _len(15, _str(1, "null pointer dereference")) \
		+ _len(16, _int(1, 4200) + _len(2, th_ok)) + _len(16, _int(1, 4242) + _len(2, th_bad)) \
		+ _len(18, _str(1, "main") + _len(2, lm)) + _str(2, "Infinix/Z2356/x:13/abc")
	var s := Tombstone.summary(t)
	_check(str(s["signal"]) == "SIGSEGV (11)", "señal: %s" % s["signal"])
	_check(str(s["code"]) == "SEGV_MAPERR (1)", "código: %s" % s["code"])
	_check(str(s["fault"]) == "0x18", "dirección: %s" % s["fault"])
	_check(str(s["thread"]) == "GLThread 12", "hilo que se rompió (no el principal): %s" % s["thread"])
	var fr: Array = s["frames"]
	_check(fr.size() == 2 and str(fr[0]).contains("libGLES_mali.so +2a1b4") and str(fr[1]).contains("libgodot_android.so +1d2c3e0") and str(fr[1]).contains("[id 1234567890abcdef]"),
		"cuadros con biblioteca y dirección: %s" % str(fr))
	_check((s["logs"] as Array).size() == 1 and str(s["logs"][0]).contains("E Mali: gles_texture: out of memory") and str(s["logs"][0]).begins_with("21:25:07"), "logcat: %s" % str(s["logs"]))
	_check((s["causes"] as Array) == ["null pointer dereference"], "causa: %s" % str(s["causes"]))
	var ls := Tombstone.lines(t)
	_check(ls.size() == 1 + 1 + 2 + 1 and ls[0].begins_with("[lápida] señal SIGSEGV"), "líneas del registro: %d" % ls.size())
	for l in ls:
		print("     " + l)
	# basura / cortada: no se cuelga ni rompe
	var cut := t.slice(0, t.size() / 2)
	Tombstone.summary(cut)
	Tombstone.summary(PackedByteArray([0xff, 0xff, 0xff]))
	_check(true, "una lápida cortada o basura no rompe la lectura")
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
