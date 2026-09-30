extends Node
## «Lente Rally»: acabado de cámara que se aplica a la imagen del mundo 3D al estirarla a pantalla completa (un solo pasaje, barato).
## Es lo que hace que un modelo simple parezca de más calidad: mira la ruta con el ojo de una cámara real.
##  · viñeta suave y contraste/color de cine (verdes más profundos, cielo más limpio, sombras con tono frío);
##  · desenfoque radial y aberración de color en los bordes que crecen con la velocidad (no se nota si el árbol es feo);
##  · grano fino que cambia cada cuadro y un leve temblor de la lente al ir rápido.
## Nivel: 0 apagado · 1 suave · 2 fuerte.

const SHADER := """
shader_type canvas_item;
uniform float speed = 0.0;   // 0..1
uniform float grain = 0.03;
uniform float vig = 0.32;
uniform float sat = 1.10;
uniform float contrast = 1.08;
uniform float ca = 0.004;
uniform float t = 0.0;
uniform vec2 shake = vec2(0.0);
uniform vec3 tint_dark = vec3(0.96, 1.0, 1.05);
uniform vec3 tint_light = vec3(1.04, 1.0, 0.94);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV + shake;
	vec2 d = uv - vec2(0.5);
	float r2 = dot(d, d);
	vec3 col;
	if (speed > 0.02) {
		float k = speed * r2 * 0.16;
		col = texture(TEXTURE, uv).rgb;
		col += texture(TEXTURE, uv - d * k).rgb;
		col += texture(TEXTURE, uv - d * k * 2.0).rgb;
		col += texture(TEXTURE, uv - d * k * 3.0).rgb;
		col *= 0.25;
		float c = ca * (0.4 + speed) * r2 * 4.0;
		col.r = mix(col.r, texture(TEXTURE, uv + d * c * 1.4).r, 0.6);
		col.b = mix(col.b, texture(TEXTURE, uv - d * c * 1.4).b, 0.6);
	} else {
		col = texture(TEXTURE, uv).rgb;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = (col - 0.5) * contrast + 0.5;
	col *= mix(tint_dark, tint_light, smoothstep(0.15, 0.85, l));
	col *= 1.0 - vig * smoothstep(0.10, 0.62, r2 * 2.2);
	col += (hash(FRAGCOORD.xy + vec2(t * 61.0, t * 37.0)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""

var mat: ShaderMaterial
var target: CanvasItem
var level := 1:
	set(v):
		level = v
		_refresh()
var enabled := true:
	set(v):
		enabled = v
		_refresh()

var _t := 0.0
var _shake_seed := 0.0

func attach(item: CanvasItem) -> void:
	target = item
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	_refresh()

func _refresh() -> void:
	if target == null:
		return
	if not enabled or level <= 0:
		target.material = null
		return
	target.material = mat
	if level >= 2:
		mat.set_shader_parameter("grain", 0.055)
		mat.set_shader_parameter("vig", 0.5)
		mat.set_shader_parameter("sat", 1.18)
		mat.set_shader_parameter("contrast", 1.14)
		mat.set_shader_parameter("ca", 0.007)
	else:
		mat.set_shader_parameter("grain", 0.03)
		mat.set_shader_parameter("vig", 0.32)
		mat.set_shader_parameter("sat", 1.10)
		mat.set_shader_parameter("contrast", 1.08)
		mat.set_shader_parameter("ca", 0.004)

## kmh: velocidad del auto; boost: 0..1 (nitro) suma efecto
func update(dt: float, kmh: float, boost := 0.0) -> void:
	if mat == null or target == null or target.material == null:
		return
	_t += dt
	var sp := clampf((kmh - 55.0) / 150.0 + boost * 0.5, 0.0, 1.0)
	mat.set_shader_parameter("speed", sp)
	mat.set_shader_parameter("t", fmod(_t, 50.0))
	# temblor muy leve de la lente, más con la velocidad
	var a := sp * 0.0012
	mat.set_shader_parameter("shake", Vector2(sin(_t * 47.0) + sin(_t * 31.0 + 1.3), sin(_t * 53.0 + 0.7) + sin(_t * 29.0)) * a)
