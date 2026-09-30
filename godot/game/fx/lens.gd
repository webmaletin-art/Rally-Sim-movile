extends Node
## «Lente Rally»: acabado de cámara que se aplica a la imagen del mundo 3D al estirarla a pantalla completa (un solo pasaje, barato).
## Es lo que hace que un modelo simple parezca de más calidad: mira la ruta con el ojo de una cámara real.
##  · viñeta suave y contraste/color de cine (verdes más profundos, cielo más limpio, sombras con tono frío);
##  · desenfoque radial y aberración de color en los bordes que crecen con la velocidad (no se nota si el árbol es feo);
##  · grano fino que cambia cada cuadro y un leve temblor de la lente al ir rápido.
## Nivel: 0 apagado · 1 suave · 2 fuerte.
## Además, hasta 3 «Efectos 2.0» a la vez (los 22 de la guía: negativo, blanco y negro, sepia, rojo, acua, solarizado, bleach bypass,
## póster, semitonos, visión nocturna, glitch, cel shading, infrarrojo, bodycam, boceto, pizarra, graphic black, 1-bit, sin city,
## borderlands, tiza y XIII). Van en el mismo pasaje: primero los que deforman la imagen (glitch, bodycam), después los de color
## en el orden elegido. Los que miran vecinos (bordes, bloom) leen la imagen original.

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
uniform int fx0 = 0;
uniform int fx1 = 0;
uniform int fx2 = 0;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float lum_at(sampler2D tex, vec2 uv) { return lum(texture(tex, uv).rgb); }

float sobel(sampler2D tex, vec2 uv, vec2 texel) {
	float tl = lum_at(tex, uv + texel * vec2(-1.0, -1.0));
	float tt = lum_at(tex, uv + texel * vec2(0.0, -1.0));
	float tr = lum_at(tex, uv + texel * vec2(1.0, -1.0));
	float ml = lum_at(tex, uv + texel * vec2(-1.0, 0.0));
	float mr = lum_at(tex, uv + texel * vec2(1.0, 0.0));
	float bl = lum_at(tex, uv + texel * vec2(-1.0, 1.0));
	float bb = lum_at(tex, uv + texel * vec2(0.0, 1.0));
	float br = lum_at(tex, uv + texel * vec2(1.0, 1.0));
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tt - tr + bl + 2.0 * bb + br;
	return sqrt(gx * gx + gy * gy);
}

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
float bayer8(vec2 a) { return bayer4(0.5 * a) * 0.25 + bayer2(a); }
float hash1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

// deformaciones de la imagen (glitch = 11, bodycam = 14)
vec2 warp(int id, vec2 uv, float tm, vec2 res) {
	if (id == 11) {
		float band = floor(uv.y * 60.0);
		float rnd = fract(sin(band * 12.9898 + floor(tm * 12.0) * 78.233) * 43758.5453);
		if (rnd > 0.95) uv.x += (rnd - 0.95) * 0.8;
	} else if (id == 14) {
		vec2 d = uv - 0.5;
		float r2 = dot(d, d);
		uv = 0.5 + d * (1.0 + r2 * 0.35 + r2 * r2 * 0.15);
	}
	return uv;
}

// efecto de color número id sobre la imagen ya procesada c; src = imagen original
vec3 fx_apply(sampler2D src, int id, vec3 c, vec2 uv, vec2 uv0, float tm, vec2 res, vec2 px) {
	float l = lum(c);
	if (id == 1) {
		return 1.0 - c;
	} else if (id == 2) {
		return vec3(l);
	} else if (id == 3) {
		return clamp(vec3(dot(c, vec3(0.393, 0.769, 0.189)), dot(c, vec3(0.349, 0.686, 0.168)), dot(c, vec3(0.272, 0.534, 0.131))), 0.0, 1.0);
	} else if (id == 4) {
		return c * vec3(1.2, 0.52, 0.46);
	} else if (id == 5) {
		return c * vec3(0.52, 0.95, 1.25);
	} else if (id == 6) {
		if (l > 0.40 && l < 0.90) c = 1.0 - c;
		return c;
	} else if (id == 7) {
		vec3 desat = mix(vec3(l), c, 0.55);
		vec3 ov = desat * (1.0 - desat) * 2.0;
		c = mix(desat, ov, 0.55);
		return clamp((c - 0.5) * 1.45 + 0.5, 0.0, 1.0);
	} else if (id == 8) {
		return floor(c * 6.0 + 0.5) / 6.0;
	} else if (id == 9) {
		vec2 ruv = vec2(uv.x * cos(0.45) - uv.y * sin(0.45), uv.x * sin(0.45) + uv.y * cos(0.45));
		vec2 cell = fract(ruv * res / 5.0) - 0.5;
		float radius = (1.0 - l) * 0.60;
		return vec3(1.0 - smoothstep(radius, radius - 0.10, length(cell)));
	} else if (id == 10) {
		vec3 g = vec3(l * 0.10, l * 1.05, l * 0.30);
		g += (hash1(uv * 500.0 + tm) - 0.5) * 0.15;
		g *= 0.86 + 0.14 * sin(uv.y * res.y * 2.2);
		return g;
	} else if (id == 11) {
		float cab = 0.0012 + 0.008 * length(uv0 - 0.5);
		return vec3(texture(src, uv + vec2(cab, 0.0)).r, c.g, texture(src, uv - vec2(cab, 0.0)).b);
	} else if (id == 12) {
		float q = (l < 0.26) ? 0.30 : ((l < 0.58) ? 0.66 : 1.06);
		return c * q;
	} else if (id == 13) {
		vec3 bl = vec3(0.0);
		for (int i = 1; i <= 6; i++) {
			float fi = float(i);
			float a = fi * 2.39996;
			vec2 off = vec2(cos(a), sin(a)) * fi * px * 4.0;
			bl += vec3(smoothstep(0.55, 0.95, lum_at(src, uv + off))) / fi;
		}
		return vec3(0.35, 0.55, 0.85) * c + bl / 6.0 * 2.5;
	} else if (id == 14) {
		vec2 d = uv0 - 0.5;
		float r2 = dot(d, d);
		float cab = 0.002 + 0.012 * r2;
		vec3 o = vec3(texture(src, uv + vec2(cab, 0.0)).r, c.g, texture(src, uv - vec2(cab, 0.0)).b);
		o *= mix(0.35, 1.0, smoothstep(0.95, 0.35, length(d * vec2(1.1, 1.0))));
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) o = vec3(0.02, 0.02, 0.03);
		return o;
	} else if (id == 15) {
		float ed = sobel(src, uv, px) + sobel(src, uv, px * 2.0) * 0.5;
		return vec3(1.0 - smoothstep(0.07, 0.30, ed));
	} else if (id == 16) {
		float ed = sobel(src, uv, px) + sobel(src, uv, px * 2.0) * 0.6;
		float line = smoothstep(0.05, 0.26, ed);
		float n = fract(sin(dot(uv * 400.0, vec2(12.98, 78.23))) * 43758.5);
		return vec3(0.86, 0.93, 1.0) * (0.72 + 0.55 * n) * line;
	} else if (id == 17) {
		float ed = sobel(src, uv, px * 2.0);
		float v = smoothstep(0.32, 0.46, l);
		v = floor(v * 3.0) / 3.0;
		vec3 o = vec3(v);
		o = mix(o, vec3(0.0), (1.0 - smoothstep(0.10, 0.42, l)) * 0.85);
		return mix(o, vec3(0.0), smoothstep(0.16, 0.36, ed));
	} else if (id == 18) {
		float b = bayer8(uv * res);
		float v = l * 1.22 + (b - 0.5) * 0.30;
		vec3 dark = vec3(0.192, 0.133, 0.106);
		vec3 o = (v > 0.5) ? vec3(0.886, 0.824, 0.710) : dark;
		float ed = sobel(src, uv, px);
		return mix(o, dark, smoothstep(0.30, 0.55, ed));
	} else if (id == 19) {
		float redness = c.r - max(c.g, c.b);
		float is_red = smoothstep(0.10, 0.28, redness) * smoothstep(0.18, 0.40, c.r);
		vec3 o = vec3(step(0.44, l));
		return mix(o, vec3(1.0, 0.02, 0.02) * (0.45 + 0.75 * c.r), is_red);
	} else if (id == 20) {
		float ed = sobel(src, uv, px * 1.7);
		c *= 1.08;
		float shadow = 1.0 - smoothstep(0.10, 0.55, l);
		float l1 = step(0.5, fract((uv.x + uv.y) * 90.0));
		float l2 = step(0.5, fract((uv.x - uv.y) * 90.0));
		c *= 1.0 - shadow * 0.50 * l1;
		c *= 1.0 - max(shadow - 0.45, 0.0) * 1.30 * l2;
		return mix(c, vec3(0.0), smoothstep(0.14, 0.32, ed));
	} else if (id == 21) {
		float n1 = fract(sin(dot(uv * 500.0, vec2(12.98, 78.23))) * 43758.5);
		c = mix(c, vec3(0.97, 0.95, 0.88), 0.20);
		float shadow = 1.0 - smoothstep(0.14, 0.75, l);
		float l1 = step(0.5, fract((uv.x + uv.y * 1.25) * 130.0));
		float l2 = step(0.5, fract((uv.x * 1.30 - uv.y) * 130.0));
		c *= 1.0 - shadow * 0.42 * l1;
		c *= 1.0 - shadow * 0.30 * l2;
		return c * (0.90 + 0.20 * n1);
	} else if (id == 22) {
		// historieta: cel saturado + semitono en las sombras + bordes negros
		float q = (l < 0.26) ? 0.45 : ((l < 0.58) ? 0.78 : 1.08);
		vec3 o = mix(vec3(l), c, 1.35) * q;
		vec2 cell = fract(uv * res / 6.0) - 0.5;
		float dots = smoothstep(0.30, 0.22, length(cell)) * (1.0 - smoothstep(0.10, 0.45, l));
		o *= 1.0 - dots * 0.45;
		float ed = sobel(src, uv, px * 1.5);
		return mix(o, vec3(0.0), smoothstep(0.18, 0.36, ed));
	}
	return c;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv0 = UV + shake;
	vec2 uv = uv0;
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	uv = warp(fx0, uv, t, res);
	uv = warp(fx1, uv, t, res);
	uv = warp(fx2, uv, t, res);
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
	col = clamp(col, 0.0, 1.0);
	if (fx0 > 0) col = fx_apply(TEXTURE, fx0, col, uv, uv0, t, res, TEXTURE_PIXEL_SIZE);
	if (fx1 > 0) col = fx_apply(TEXTURE, fx1, col, uv, uv0, t, res, TEXTURE_PIXEL_SIZE);
	if (fx2 > 0) col = fx_apply(TEXTURE, fx2, col, uv, uv0, t, res, TEXTURE_PIXEL_SIZE);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""

var mat: ShaderMaterial
var target: CanvasItem
## Nombres de los efectos 2.0 (el índice es el número que usa el shader; 0 = ninguno) y su costo (1 liviano … 5 pesado)
const FX_NAMES := ["Ninguno", "Negativo", "Blanco y negro", "Sepia", "Rojo carmesí", "Acua (azulado)", "Solarizado", "Bleach bypass (cine)", "Póster",
	"Semitonos (manga)", "Visión nocturna", "Glitch", "Cel shading (toon)", "Infrarrojo con brillo", "Bodycam (ojo de pez)", "Boceto (contorno negro)",
	"Pizarra (contorno blanco)", "Graphic Black", "1-Bit tramado", "Sin City (rojo sangre)", "Borderlands (cómic)", "Lienzo de tiza", "XIII (historieta)"]
const FX_COST := [0, 1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 3, 3, 4, 3, 5, 5, 5, 5, 5, 5, 5, 5]
var fx: Array = [0, 0, 0]:
	set(v):
		fx = v
		_refresh()

var level := 0:
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
	var any_fx: bool = int(fx[0]) > 0 or int(fx[1]) > 0 or int(fx[2]) > 0
	if not enabled or (level <= 0 and not any_fx):
		target.material = null
		return
	target.material = mat
	mat.set_shader_parameter("fx0", int(fx[0]))
	mat.set_shader_parameter("fx1", int(fx[1]))
	mat.set_shader_parameter("fx2", int(fx[2]))
	if level <= 0:
		# solo efectos 2.0: el acabado del lente queda neutro
		mat.set_shader_parameter("grain", 0.0)
		mat.set_shader_parameter("vig", 0.0)
		mat.set_shader_parameter("sat", 1.0)
		mat.set_shader_parameter("contrast", 1.0)
		mat.set_shader_parameter("ca", 0.0)
		mat.set_shader_parameter("tint_dark", Vector3.ONE)
		mat.set_shader_parameter("tint_light", Vector3.ONE)
		return
	mat.set_shader_parameter("tint_dark", Vector3(0.96, 1.0, 1.05))
	mat.set_shader_parameter("tint_light", Vector3(1.04, 1.0, 0.94))
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
	var sp := clampf((kmh - 55.0) / 150.0 + boost * 0.5, 0.0, 1.0) if level > 0 else 0.0
	mat.set_shader_parameter("speed", sp)
	mat.set_shader_parameter("t", fmod(_t, 50.0))
	# temblor muy leve de la lente, más con la velocidad
	var a := sp * 0.0012
	mat.set_shader_parameter("shake", Vector2(sin(_t * 47.0) + sin(_t * 31.0 + 1.3), sin(_t * 53.0 + 0.7) + sin(_t * 29.0)) * a)
