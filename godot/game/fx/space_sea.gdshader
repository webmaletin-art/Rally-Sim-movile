shader_type spatial;
// Mar de polvo o de gas debajo de la ruta (Marte): bandas que giran despacio. Es un plano enorme muy por debajo del camino.
render_mode unshaded, cull_disabled;

uniform vec3 c0 : source_color = vec3(0.80, 0.45, 0.28);
uniform vec3 c1 : source_color = vec3(0.92, 0.65, 0.42);
uniform vec3 c2 : source_color = vec3(0.60, 0.30, 0.25);
uniform vec3 c3 : source_color = vec3(0.96, 0.80, 0.60);
uniform float tm = 0.0;
uniform float scale = 0.0011;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.02 + 5.3;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 p = wp.xz * scale;
	float t = tm * 0.012;
	float w = fbm(p * 2.0 + vec2(t, 0.0));
	float bands = fbm(vec2(p.x * 0.6 + w * 1.4, p.y * 1.1 + t)) * 3.0;
	vec3 col = mix(c0, c1, smoothstep(0.0, 1.0, fract(bands)));
	col = mix(col, c2, smoothstep(0.55, 0.9, w) * 0.7);
	col = mix(col, c3, smoothstep(0.62, 0.95, fbm(p * 5.0 + 3.0)) * 0.45);
	ALBEDO = col;
}
