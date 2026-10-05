extends RefCounted
## Animaciones de Mixamo para los pilotos del menú, horneadas por tools/mixamo/bake.gd en un solo archivo (game/anim/menu_clips.txt, ~3 MB):
## rotaciones locales por hueso a 15 cuadros por segundo (int16) + posición de la cadera. Se leen a demanda (sólo las que se usan) y se aplican directo al
## esqueleto del piloto (mismos nombres de hueso «mixamorig»). Si el archivo no está, available() es false y el menú usa las poses procedurales de siempre.

const PATH := "res://game/anim/menu_clips.txt"
const FPS := 15.0 # cuadros por segundo del archivo horneado
const FADE := 0.45 # segundos de mezcla entre un clip y el siguiente
const HIPS_REF := 0.99 # altura de la cadera del Y Bot de Mixamo (para escalar al piloto)

static var _index: Dictionary = {} # nombre → {off, len, frames, bones}
static var _cache: Dictionary = {} # nombre → clip decodificado
static var _tried := false

static func _open() -> void:
	if _tried:
		return
	_tried = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ) # sólo se lee el índice (no los 3 MB enteros en memoria: en el teléfono es tiempo y RAM)
	if f == null or f.get_length() < 12 or f.get_buffer(4).get_string_from_ascii() != "MXA1":
		return
	var n := f.get_32()
	f.get_float()
	for i in n:
		var nm := f.get_pascal_string()
		var ln := f.get_float()
		var frames := f.get_32()
		var nb := f.get_16()
		var bones := PackedStringArray()
		for b in nb:
			bones.append(f.get_pascal_string())
		var has_hips := f.get_8() == 1
		var off := f.get_position()
		for b in nb:
			var c := f.get_8()
			f.seek(f.get_position() + 8 * (1 if c == 1 else frames))
		if has_hips:
			f.seek(f.get_position() + 12 * frames)
		_index[nm] = {"off": off, "len": ln, "frames": frames, "bones": bones, "hips": has_hips}

static func available() -> bool:
	_open()
	return not _index.is_empty()

static func has_clip(name: String) -> bool:
	_open()
	return _index.has(name)

## Un clip decodificado: {len, frames, bones: PackedStringArray, rots: Array[PackedFloat32Array] (4 floats por cuadro, o 4 si es constante), hips: PackedVector3Array}
static func clip(name: String) -> Dictionary:
	_open()
	if _cache.has(name):
		return _cache[name]
	if not _index.has(name):
		return {}
	var ix: Dictionary = _index[name]
	var f := FileAccess.open(PATH, FileAccess.READ)
	f.seek(int(ix["off"]))
	var frames := int(ix["frames"])
	var bones: PackedStringArray = ix["bones"]
	var rots: Array = []
	for b in bones.size():
		var const_ := f.get_8() == 1
		var cnt := 4 if const_ else frames * 4
		var arr := PackedFloat32Array()
		arr.resize(cnt)
		for k in cnt:
			arr[k] = float(_s16(f.get_16())) / 32767.0
		rots.append(arr)
	var hips := PackedVector3Array()
	if bool(ix["hips"]):
		hips.resize(frames)
		for k in frames:
			hips[k] = Vector3(f.get_float(), f.get_float(), f.get_float())
	var c := {"name": name, "len": float(ix["len"]), "frames": frames, "bones": bones, "rots": rots, "hips": hips}
	_cache[name] = c
	return c

static func _s16(v: int) -> int:
	return v - 65536 if v >= 32768 else v

## Reproduce clips sobre un esqueleto con mezcla suave entre uno y otro (y entre un clip y la pose procedural)
class Player extends RefCounted:
	var skel: Skeleton3D
	var idx: Dictionary = {} # nombre sin prefijo → índice de hueso
	var hips_i := -1
	var hips_k := 1.0
	var cur: Dictionary = {}
	var t := 0.0
	var blend := 1.0
	var _snap: Dictionary = {} # índice de hueso → Quaternion al empezar la mezcla
	var _snap_hips := Vector3.ZERO
	var _last: Dictionary = {}
	var _last_hips := Vector3.ZERO
	var _has_last := false

	func _init(p_skel: Skeleton3D, bone_index: Dictionary) -> void:
		skel = p_skel
		idx = bone_index
		hips_i = int(idx.get("Hips", -1))
		if hips_i >= 0:
			hips_k = skel.get_bone_rest(hips_i).origin.y / HIPS_REF

	## Empieza un clip (mezclando desde lo último que se mostró)
	func play(c: Dictionary) -> void:
		mark_transition()
		cur = c
		t = 0.0

	## Marca que lo que viene se mezcla desde la pose actual (por ejemplo al volver a la pose procedural)
	func mark_transition() -> void:
		if _has_last:
			_snap = _last.duplicate()
			_snap_hips = _last_hips
			blend = 0.0

	func ended() -> bool:
		return cur.is_empty() or t >= float(cur["len"])

	func step(dt: float) -> void:
		t += dt

	## Pone la pose del clip en el esqueleto
	func apply_clip() -> void:
		if cur.is_empty():
			return
		var frames := int(cur["frames"])
		var fpos := clampf(t * FPS, 0.0, float(frames - 1))
		var k0 := int(floor(fpos))
		var k1 := mini(k0 + 1, frames - 1)
		var w := fpos - float(k0)
		var bones: PackedStringArray = cur["bones"]
		var rots: Array = cur["rots"]
		for b in bones.size():
			var bi: int = int(idx.get(bones[b], -1))
			if bi < 0:
				continue
			var arr: PackedFloat32Array = rots[b]
			var q: Quaternion
			if arr.size() == 4:
				q = Quaternion(arr[0], arr[1], arr[2], arr[3])
			else:
				var a := Quaternion(arr[k0 * 4], arr[k0 * 4 + 1], arr[k0 * 4 + 2], arr[k0 * 4 + 3])
				var c := Quaternion(arr[k1 * 4], arr[k1 * 4 + 1], arr[k1 * 4 + 2], arr[k1 * 4 + 3])
				q = a.slerp(c, w)
			skel.set_bone_pose_rotation(bi, q.normalized())
		var hp: PackedVector3Array = cur["hips"]
		if hips_i >= 0 and hp.size() == frames:
			skel.set_bone_pose_position(hips_i, hp[k0].lerp(hp[k1], w) * hips_k)

	## Al final de cada cuadro: mezcla con la pose anterior si hace falta y recuerda la pose mostrada
	func post(dt: float) -> void:
		if blend < 1.0 and not _snap.is_empty():
			blend = minf(1.0, blend + dt / FADE)
			var e := smoothstep(0.0, 1.0, blend)
			for bi in _snap:
				var q: Quaternion = (_snap[bi] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), e)
				skel.set_bone_pose_rotation(bi, q)
			if hips_i >= 0:
				skel.set_bone_pose_position(hips_i, _snap_hips.lerp(skel.get_bone_pose_position(hips_i), e))
		for bi in idx.values():
			_last[bi] = skel.get_bone_pose_rotation(bi)
		if hips_i >= 0:
			_last_hips = skel.get_bone_pose_position(hips_i)
		_has_last = true

