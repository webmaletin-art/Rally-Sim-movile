extends RefCounted
## «Lápida» (tombstone) de un cierre nativo de Android, leída desde el juego (docs/REGISTRO_TECNICO.md → 15/10/2026).
## Cuando el juego se cierra por un error nativo (señal 11 = SIGSEGV), Android guarda un informe del instante del cierre: qué hilo se rompió,
## en qué biblioteca (el motor libgodot_android.so, el driver de video libGLES_mali.so, el audio…), la dirección que no se pudo leer y las
## últimas líneas de logcat del proceso. Desde Android 12 se puede pedir con ApplicationExitInfo.getTraceInputStream() (formato protobuf);
## acá se lee con readAllBytes() (Android 13+) y se decodifica a mano lo justo (sin dependencias): sin adb ni PC.
## Campos según system/core/debuggerd/proto/tombstone.proto (AOSP).

const MAX_FRAMES := 16
const MAX_LOGS := 14

## Lee un varint desde b[i]; devuelve [valor, índice siguiente]
static func _varint(b: PackedByteArray, i: int) -> Array:
	var v := 0
	var sh := 0
	while i < b.size():
		var c := b[i]
		i += 1
		if sh < 64:
			v |= (c & 0x7f) << sh
		sh += 7
		if c & 0x80 == 0:
			break
	return [v, i]

## Decodifica un mensaje: {campo: [valores]} (varint → int, largo → PackedByteArray; los fijos de 32/64 bits → int)
static func fields(b: PackedByteArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < b.size():
		var r := _varint(b, i)
		var key: int = r[0]
		i = r[1]
		var f := key >> 3
		var wt := key & 7
		var val: Variant = null
		match wt:
			0:
				r = _varint(b, i)
				val = r[0]
				i = r[1]
			1:
				if i + 8 > b.size():
					break
				val = b.decode_s64(i)
				i += 8
			2:
				r = _varint(b, i)
				var n: int = r[0]
				i = r[1]
				if n < 0 or i + n > b.size():
					break
				val = b.slice(i, i + n)
				i += n
			5:
				if i + 4 > b.size():
					break
				val = b.decode_u32(i)
				i += 4
			_:
				break # (tipo desconocido: lo que sigue no se puede leer)
		if not out.has(f):
			out[f] = []
		(out[f] as Array).append(val)
	return out

static func _s(d: Dictionary, f: int) -> String:
	if not d.has(f):
		return ""
	var v: Variant = (d[f] as Array)[0]
	return (v as PackedByteArray).get_string_from_utf8() if v is PackedByteArray else str(v)

static func _i(d: Dictionary, f: int) -> int:
	if not d.has(f):
		return 0
	var v: Variant = (d[f] as Array)[0]
	return int(v) if (v is int) else 0

static func _hex(v: int) -> String:
	return "0x" + String.num_uint64(v, 16)

## Resumen legible: {signal, code, fault, tid, thread, frames: [String], logs: [String], abort, causes: [String]}
static func summary(b: PackedByteArray) -> Dictionary:
	var t := fields(b)
	var res := {"signal": "", "code": "", "fault": "", "tid": _i(t, 6), "thread": "", "frames": [], "logs": [], "abort": _s(t, 14), "causes": [], "fingerprint": _s(t, 2)}
	if t.has(10):
		var sg := fields((t[10] as Array)[0])
		res["signal"] = "%s (%d)" % [_s(sg, 2), _i(sg, 1)]
		res["code"] = "%s (%d)" % [_s(sg, 4), _i(sg, 3)]
		if _i(sg, 8) != 0:
			res["fault"] = _hex(_i(sg, 9))
	for c in t.get(15, []):
		res["causes"].append(_s(fields(c), 1))
	# hilos: map<uint32, Thread> → entradas {1: id, 2: Thread}; el que se rompió es el de tid
	for e in t.get(16, []):
		var en := fields(e)
		if not en.has(2):
			continue
		var th := fields((en[2] as Array)[0])
		if _i(th, 1) != int(res["tid"]):
			continue
		res["thread"] = _s(th, 2)
		var k := 0
		for fr in th.get(4, []):
			if k >= MAX_FRAMES:
				break
			var f := fields(fr)
			var fn := _s(f, 4)
			var line := "#%02d %s +%s" % [k, _s(f, 6).get_file(), String.num_uint64(_i(f, 1), 16)]
			if fn != "":
				line += " (%s+%d)" % [fn.left(80), _i(f, 5)]
			var bid := _s(f, 8)
			if bid != "" and (_s(f, 6).contains("godot") or k == 0):
				line += " [id %s]" % bid.left(16)
			res["frames"].append(line)
			k += 1
	# las últimas líneas de logcat del proceso (LogBuffer {1 nombre, 2 LogMessage {1 hora, 3 tid, 4 prioridad, 5 etiqueta, 6 mensaje}})
	var logs: Array = []
	for lb in t.get(18, []):
		var bf := fields(lb)
		for m in bf.get(2, []):
			var lm := fields(m)
			var pr := _i(lm, 4)
			var ts := _s(lm, 1)
			logs.append("%s %s %s: %s" % [ts.get_slice(" ", 1) if ts.contains(" ") else ts, "VDIWEF".substr(clampi(pr - 2, 0, 5), 1), _s(lm, 5), _s(lm, 6).strip_edges().left(160)])
	res["logs"] = logs.slice(maxi(0, logs.size() - MAX_LOGS))
	return res

## Líneas para el registro (todas empiezan con «[lápida]»)
static func lines(b: PackedByteArray) -> PackedStringArray:
	var s := summary(b)
	var out := PackedStringArray()
	out.append("[lápida] señal %s · %s · dirección %s · hilo «%s» (%d) · %d bytes" % [s["signal"], s["code"], s["fault"] if s["fault"] != "" else "-", s["thread"], s["tid"], b.size()])
	if str(s["abort"]) != "":
		out.append("[lápida] aborto: " + str(s["abort"]).left(200))
	for c in s["causes"]:
		out.append("[lápida] causa: " + str(c).left(200))
	for f in s["frames"]:
		out.append("[lápida] " + str(f))
	for l in s["logs"]:
		out.append("[lápida] log " + str(l))
	return out
