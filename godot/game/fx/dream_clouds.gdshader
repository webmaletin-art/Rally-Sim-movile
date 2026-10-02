shader_type spatial;
// Mar de gas del Vórtice de Ensueño: bandas de planeta gigante que giran en espiral hacia un agujero negro con su anillo brillante.
// Es un plano enorme muy por debajo de la ruta: se ve desde la subida y desde los bordes de la meseta de flores.
render_mode unshaded, cull_disabled;

uniform vec2 center = vec2(0.0);
uniform float hole_r = 340.0;
uniform float tm = 0.0;

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

vec3 pal(float t) {
	vec3 c0 = vec3(1.00, 0.84, 0.70); // durazno
	vec3 c1 = vec3(1.00, 0.55, 0.72); // rosa
	vec3 c2 = vec3(0.78, 0.52, 1.00); // violeta
	vec3 c3 = vec3(0.45, 0.82, 1.00); // celeste
	vec3 c4 = vec3(1.00, 0.88, 0.55); // dorado
	vec3 c5 = vec3(0.98, 0.42, 0.62); // frambuesa
	t = fract(t) * 6.0;
	if (t < 1.0) return mix(c0, c1, smoothstep(0.0, 1.0, t));
	if (t < 2.0) return mix(c1, c2, smoothstep(0.0, 1.0, t - 1.0));
	if (t < 3.0) return mix(c2, c3, smoothstep(0.0, 1.0, t - 2.0));
	if (t < 4.0) return mix(c3, c4, smoothstep(0.0, 1.0, t - 3.0));
	if (t < 5.0) return mix(c4, c5, smoothstep(0.0, 1.0, t - 4.0));
	return mix(c5, c0, smoothstep(0.0, 1.0, t - 5.0));
}

void fragment() {
	vec2 p = wp.xz - center;
	float r = length(p);
	float a = atan(p.y, p.x);
	// espiral: el giro crece hacia el centro (como un remolino) y todo rota despacio
	float twist = 5.5 / (1.0 + r * 0.00085);
	float ang = a + twist * 1.2 - tm * 0.015 * (1.0 + 600.0 / (r + 200.0));
	vec2 s = vec2(cos(ang), sin(ang)) * r * 0.0012;
	float turb = fbm(s * 3.2 + vec2(tm * 0.01, 0.0));
	float bands = log(r + 80.0) * 3.1 + turb * 1.7 + sin(ang * 3.0 + r * 0.0017) * 0.25;
	vec3 col = pal(bands * 0.42);
	col *= 0.80 + 0.35 * fbm(s * 9.0 + 3.0);
	// brillo cálido en las crestas de las nubes
	col += vec3(1.0, 0.85, 0.7) * smoothstep(0.62, 0.9, turb) * 0.18;
	// el agujero: negro con un anillo brillante (disco de acreción) alrededor
	float ring = exp(-pow((r - hole_r * 1.22) / (hole_r * 0.20), 2.0));
	float ring2 = exp(-pow((r - hole_r * 1.55) / (hole_r * 0.42), 2.0));
	vec3 glow = mix(vec3(1.0, 0.62, 0.25), vec3(1.0, 0.35, 0.65), 0.5 + 0.5 * sin(ang * 2.0 + tm * 0.2));
	col = mix(col, glow * 1.6, ring * (0.85 + 0.15 * sin(ang * 5.0 - tm * 0.6)));
	col += glow * exp(-pow((r - hole_r * 1.06) / (hole_r * 0.06), 2.0)) * 1.2; // aro finísimo muy brillante en el borde
	col = mix(col, vec3(0.95, 0.45, 0.70), ring2 * 0.25);
	float hole = smoothstep(hole_r * 1.05, hole_r * 0.80, r);
	col = mix(col, vec3(0.0, 0.0, 0.01), hole);
	// lejos se funde con la niebla del horizonte (lo hace la niebla de la escena)
	ALBEDO = col;
}
