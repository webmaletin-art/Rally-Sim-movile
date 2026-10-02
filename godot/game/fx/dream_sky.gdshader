shader_type sky;
// Cielo del Vórtice de Ensueño: degradé durazno → lila → índigo, estrellas, un Júpiter gigante con sus bandas, su tormenta y su
// terminador, y el sol con su halo. Todo procedural (sin texturas).

uniform vec3 sun_dir = vec3(0.35, 0.62, 0.70);
uniform vec3 planet_dir = vec3(-0.88, 0.36, 0.10);
uniform float planet_r = 0.30;
uniform vec3 hor_col : source_color = vec3(1.0, 0.70, 0.66);
uniform vec3 mid_col : source_color = vec3(0.72, 0.58, 0.96);
uniform vec3 top_col : source_color = vec3(0.12, 0.08, 0.36);

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
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

vec3 planet_pal(float t) {
	vec3 c0 = vec3(0.98, 0.84, 0.66);
	vec3 c1 = vec3(0.93, 0.55, 0.45);
	vec3 c2 = vec3(0.99, 0.93, 0.82);
	vec3 c3 = vec3(0.72, 0.42, 0.62);
	vec3 c4 = vec3(0.55, 0.52, 0.80);
	t = fract(t) * 5.0;
	if (t < 1.0) return mix(c0, c1, t);
	if (t < 2.0) return mix(c1, c2, t - 1.0);
	if (t < 3.0) return mix(c2, c3, t - 2.0);
	if (t < 4.0) return mix(c3, c4, t - 3.0);
	return mix(c4, c0, t - 4.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(hor_col, mid_col, smoothstep(0.0, 0.32, h));
	col = mix(col, top_col, smoothstep(0.28, 0.95, h));
	// bruma lila debajo del horizonte
	col = mix(col, mix(hor_col, mid_col, 0.55), smoothstep(0.0, -0.25, h) * 0.8);
	// bancos de nubes largos y finos cerca del horizonte
	float az = atan(d.z, d.x);
	float cl = fbm(vec2(az * 2.6, h * 14.0) + vec2(TIME * 0.004, 0.0));
	float band = smoothstep(0.02, 0.10, h) * (1.0 - smoothstep(0.16, 0.36, h));
	col = mix(col, vec3(1.0, 0.86, 0.84), smoothstep(0.5, 0.78, cl) * band * 0.55);
	// estrellas arriba
	vec2 sp = vec2(az * 60.0, h * 60.0);
	float st = step(0.9965, hash(floor(sp))) * smoothstep(0.25, 0.7, h);
	col += vec3(1.0, 0.95, 0.9) * st * (0.5 + 0.5 * hash(floor(sp) + 3.0));
	// planeta
	vec3 pd = normalize(planet_dir);
	float cosang = dot(d, pd);
	float ang = acos(clamp(cosang, -1.0, 1.0));
	vec3 upv = normalize(vec3(0.0, 1.0, 0.0) - pd * pd.y);
	vec3 rt = cross(upv, pd);
	vec2 q = vec2(dot(d, rt), dot(d, upv)) / sin(planet_r);
	float rr = length(q);
	if (cosang > 0.0 && rr < 1.0) {
		float z = sqrt(1.0 - rr * rr);
		vec3 n = vec3(q, z);
		float wob = fbm(vec2(q.x * 2.4 + TIME * 0.012, q.y * 6.0)) - 0.5;
		float bnd = n.y * 3.2 + wob * 0.55 + 0.1 * sin(n.y * 17.0 + wob * 3.0);
		vec3 pc = planet_pal(bnd);
		// gran tormenta
		vec2 sc = (q - vec2(0.28, -0.30)) * vec2(1.0, 1.9);
		float storm = smoothstep(0.30, 0.08, length(sc));
		pc = mix(pc, vec3(0.86, 0.22, 0.28), storm * 0.85);
		vec3 sl = normalize(vec3(dot(sun_dir, rt), dot(sun_dir, upv), dot(sun_dir, pd)));
		float diff = clamp(dot(n, sl), 0.0, 1.0);
		pc *= 0.16 + 0.95 * diff;
		pc += vec3(0.5, 0.3, 0.6) * pow(1.0 - z, 3.0) * 0.35; // borde atmosférico
		col = pc;
	} else if (cosang > 0.0 && rr < 1.55) {
		float g = smoothstep(1.55, 1.0, rr);
		col += vec3(0.95, 0.55, 0.75) * g * g * 0.35; // resplandor alrededor del planeta
	}
	// sol
	float sd = dot(d, normalize(sun_dir));
	col += vec3(1.0, 0.96, 0.82) * (smoothstep(0.9993, 0.99975, sd) * 4.0);
	col += vec3(1.0, 0.80, 0.55) * pow(max(sd, 0.0), 90.0) * 0.8;
	col += vec3(1.0, 0.62, 0.55) * pow(max(sd, 0.0), 10.0) * 0.30;
	COLOR = col;
}
