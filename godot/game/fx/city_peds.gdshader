shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Peatones de papel 2.5D: una tarjeta que siempre mira a la cámara (sólo gira sobre el eje vertical) con la figura dibujada en el fragmento (sin textura):
// cabeza, torso, brazos y piernas que se balancean al caminar, contorno oscuro, paraguas si llueve. Todo por instancia (MultiMesh):
//   COLOR = remera · INSTANCE_CUSTOM = (fase del paso, —, tirado 0/1, tamaño 0..1 al aparecer) · el eje Z de la instancia es el rumbo
// La variante (pantalón, piel, accesorio) viaja en el alfa del color (0..1 → 8 variantes).
uniform float light = 1.0; // 1 de día … 0,35 de noche
uniform float rainy = 0.0; // 0..1: paraguas
varying vec4 ic;
varying float fl;

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 f = vec3(cam.x - pos.x, 0.0, cam.z - pos.z);
	f = normalize(f + vec3(0.0001, 0.0, 0.0));
	vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float g = clamp(INSTANCE_CUSTOM.w, 0.0, 1.0);
	mat4 m = mat4(vec4(r * sx * g, 0.0), vec4(0.0, sy * g, 0.0, 0.0), vec4(f * sx, 0.0), vec4(pos, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
	ic = INSTANCE_CUSTOM;
	vec3 dirw = normalize(MODEL_MATRIX[2].xyz);
	fl = dot(dirw, r) >= 0.0 ? 1.0 : -1.0; // mira hacia donde camina, visto desde la cámara
}

float sd_box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sd_circle(vec2 p, vec2 c, float r) {
	return length(p - c) - r;
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 0.9, (1.0 - UV.y) * 1.75);
	p.x *= fl;
	if (ic.z > 0.5) { // tirado: la figura acostada (más chica) sobre el piso
		p = vec2((p.y - 0.2) * 1.94, (p.x + 0.45) / 0.9 * 1.75);
	}
	float ph = ic.x;
	float walk = ph;
	float sw = sin(walk * 6.2832) * (ic.z > 0.5 ? 0.0 : 1.0);
	// piel / pantalón / accesorio a partir de la variante
	float vk = floor(abs(COLOR.a) * 7.99);
	vec3 skin = mix(vec3(0.96, 0.78, 0.62), vec3(0.45, 0.30, 0.20), fract(vk * 0.37 + 0.1));
	vec3 pants = mix(vec3(0.16, 0.18, 0.26), vec3(0.30, 0.26, 0.20), fract(vk * 0.61));
	if (mod(vk, 3.0) == 2.0) pants = vec3(0.12, 0.12, 0.13);
	vec3 shirt = COLOR.rgb;
	// partes (distancia con signo y color)
	float best = 1.0;
	vec3 col = vec3(0.0);
	// piernas
	for (int i = 0; i < 2; i++) {
		float s = (i == 0 ? 1.0 : -1.0) * sw;
		float k = clamp(1.0 - p.y / 0.88, 0.0, 1.0);
		float d = sd_box(p, vec2((i == 0 ? -0.09 : 0.09) + s * 0.13 * k, 0.45), vec2(0.075, 0.45));
		if (d < best) { best = d; col = pants; }
	}
	// torso
	float dt = sd_box(p, vec2(0.0, 1.2), vec2(0.19, 0.34)) - 0.05;
	if (dt < best) { best = dt; col = shirt; }
	// brazos
	for (int i = 0; i < 2; i++) {
		float s = (i == 0 ? -1.0 : 1.0) * sw;
		float k = clamp((1.5 - p.y) / 0.55, 0.0, 1.0);
		float d = sd_box(p, vec2((i == 0 ? -0.255 : 0.255) + s * 0.10 * k, 1.22), vec2(0.04, 0.27));
		if (d < best) { best = d; col = mix(shirt, skin, 0.35); }
	}
	// cabeza
	float dh = sd_circle(p, vec2(0.0, 1.63), 0.13);
	if (dh < best) { best = dh; col = skin; }
	// accesorios: 0 mochila, 1 bolsa, 2 gorro
	float acc = mod(vk, 4.0);
	if (acc == 0.0) { float d = sd_box(p, vec2(-0.2, 1.18), vec2(0.07, 0.18)); if (d < best) { best = d; col = shirt * 0.55; } }
	if (acc == 1.0) { float d = sd_box(p, vec2(0.28 + sw * 0.05, 0.95), vec2(0.07, 0.09)); if (d < best) { best = d; col = vec3(0.65, 0.45, 0.25); } }
	if (acc == 2.0) { float d = sd_box(p, vec2(0.0, 1.76), vec2(0.14, 0.04)); if (d < best) { best = d; col = shirt * 0.7; } }
	// paraguas con lluvia
	if (rainy > 0.35 && ic.z < 0.5) {
		float du = max(sd_circle(p, vec2(0.0, 1.78), 0.46), -(p.y - 1.78));
		float dm = sd_box(p, vec2(0.0, 1.8), vec2(0.012, 0.18));
		if (dm < best) { best = dm; col = vec3(0.2); }
		if (du < best) { best = du; col = mix(vec3(0.85, 0.2, 0.25), vec3(0.2, 0.35, 0.85), fract(vk * 0.5)); }
	}
	if (best > 0.03) discard;
	vec3 c = best > 0.0 ? vec3(0.05, 0.05, 0.07) : col;
	ALBEDO = c * light;
}
