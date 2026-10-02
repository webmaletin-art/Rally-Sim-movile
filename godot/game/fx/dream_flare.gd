extends CanvasLayer
## Reflejos de sol del Vórtice de Ensueño: cuando mirás hacia el sol aparece su halo, un destello alargado y los fantasmas del lente
## (círculos de colores que cruzan la pantalla). Se dibuja dentro de la imagen del mundo 3D, con mezcla aditiva, y no cuesta casi nada.

var cam: Camera3D
var sun_dir := Vector3(0.35, 0.62, 0.70)
var strength := 1.0
var _ctl: Control

class FlareDraw extends Control:
	var owner_flare: Node
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	func _draw() -> void:
		var f = owner_flare
		if f == null or f.cam == null:
			return
		var cam: Camera3D = f.cam
		var sd: Vector3 = f.sun_dir.normalized()
		var fwd := -cam.global_transform.basis.z
		var facing := fwd.dot(sd)
		if facing < 0.25:
			return
		var far_pt := cam.global_position + sd * 800.0
		if cam.is_position_behind(far_pt):
			return
		var vs := get_viewport_rect().size
		var sp := cam.unproject_position(far_pt)
		var k := smoothstep(0.25, 0.9, facing) * float(f.strength)
		var h := vs.y
		var ctr := vs * 0.5
		# halo
		for i in 9:
			var t := float(i) / 8.0
			draw_circle(sp, h * lerpf(0.42, 0.03, t), Color(1.0, 0.78 + 0.16 * t, 0.55 + 0.3 * t, 0.030 * k * (0.5 + t)))
		# destello alargado (horizontal) y uno finito en cruz
		draw_polygon(PackedVector2Array([sp + Vector2(-h * 0.75, 0), sp + Vector2(0, -h * 0.012), sp + Vector2(h * 0.75, 0), sp + Vector2(0, h * 0.012)]),
			PackedColorArray([Color(1, 0.7, 0.9, 0), Color(1, 0.95, 0.85, 0.55 * k), Color(0.7, 0.8, 1, 0), Color(1, 0.95, 0.85, 0.55 * k)]))
		draw_polygon(PackedVector2Array([sp + Vector2(0, -h * 0.22), sp + Vector2(-h * 0.006, 0), sp + Vector2(0, h * 0.22), sp + Vector2(h * 0.006, 0)]),
			PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.95, 0.85, 0.3 * k), Color(1, 1, 1, 0), Color(1, 0.95, 0.85, 0.3 * k)]))
		# fantasmas del lente sobre la línea del sol al centro
		var cols := [Color(1.0, 0.5, 0.7), Color(0.5, 0.8, 1.0), Color(1.0, 0.85, 0.4), Color(0.7, 0.55, 1.0), Color(0.5, 1.0, 0.8)]
		var ts := [0.45, 0.8, 1.35, 1.75, 2.2]
		var rs := [0.05, 0.085, 0.045, 0.12, 0.07]
		for g in 5:
			var gp := sp + (ctr - sp) * float(ts[g])
			var c: Color = cols[g]
			c.a = 0.07 * k
			draw_circle(gp, h * float(rs[g]), c)
			c.a = 0.07 * k
			draw_arc(gp, h * float(rs[g]), 0.0, TAU, 28, c, maxf(1.5, h * 0.004), true)

func _ready() -> void:
	layer = 5
	_ctl = FlareDraw.new()
	(_ctl as FlareDraw).owner_flare = self
	add_child(_ctl)

func _process(_dt: float) -> void:
	if _ctl != null:
		_ctl.queue_redraw()
