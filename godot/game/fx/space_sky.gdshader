shader_type sky;
// Cielo de los mapas fantasía planetarios (Marte, la Luna y el anillo de Júpiter). Todo procedural: degradé de horizonte, estrellas, un planeta
// grande (gigante de gas con bandas y tormenta, o la Tierra con nubes), lunas chicas y el sol con su halo. Cada mapa lo ajusta con parámetros.

uniform vec3 sun_dir = vec3(0.35, 0.62, 0.70);
uniform vec3 sun_col : source_color = vec3(1.0, 0.96, 0.85);
uniform float sun_size = 1.0;
uniform vec3 hor_col : source_color = vec3(0.95, 0.65, 0.45);
uniform vec3 mid_col : source_color = vec3(0.60, 0.35, 0.40);
uniform vec3 top_col : source_color = vec3(0.12, 0.08, 0.16);
uniform vec3 below_col : source_color = vec3(0.30, 0.18, 0.18);
uniform float stars = 0.9965;        // umbral: más bajo = más estrellas
uniform float star_floor = 0.25;     // desde qué altura aparecen (0 = desde el horizonte)
uniform float stars_below = 0.0;     // 1 = también debajo del horizonte
uniform float haze_amt = 0.5;        // bancos de polvo cerca del horizonte
uniform vec3 haze_col : source_color = vec3(1.0, 0.75, 0.55);
uniform float nebula = 0.0;          // nubes de color en el espacio
uniform vec3 neb_a : source_color = vec3(0.45, 0.25, 0.75);
uniform vec3 neb_b : source_color = vec3(0.15, 0.55, 0.85);

uniform int planet_type = 0;         // 0 ninguno · 1 gigante de gas · 2 Tierra
uniform vec3 planet_dir = vec3(-0.88, 0.36, 0.10);
uniform float planet_r = 0.30;
uniform vec3 pal0 : source_color = vec3(0.98, 0.84, 0.66);
uniform vec3 pal1 : source_color = vec3(0.93, 0.55, 0.45);
uniform vec3 pal2 : source_color = vec3(0.99, 0.93, 0.82);
uniform vec3 pal3 : source_color = vec3(0.72, 0.42, 0.62);
uniform vec3 pal4 : source_color = vec3(0.55, 0.52, 0.80);
uniform vec3 storm_col : source_color = vec3(0.86, 0.22, 0.28);
uniform vec3 glow_col : source_color = vec3(0.95, 0.55, 0.75);

uniform vec3 moon1_dir = vec3(0.6, 0.5, -0.6);
uniform float moon1_r = 0.0;
uniform vec3 moon1_col : source_color = vec3(0.8, 0.7, 0.6);
uniform vec3 moon2_dir = vec3(-0.3, 0.7, -0.6);
uniform float moon2_r = 0.0;
uniform vec3 moon2_col : source_color = vec3(0.7, 0.65, 0.6);

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

vec3 gas_pal(float t) {
	t = fract(t) * 5.0;
	if (t < 1.0) return mix(pal0, pal1, t);
	if (t < 2.0) return mix(pal1, pal2, t - 1.0);
	if (t < 3.0) return mix(pal2, pal3, t - 2.0);
	if (t < 4.0) return mix(pal3, pal4, t - 3.0);
	return mix(pal4, pal0, t - 4.0);
}

// disco de un cuerpo en el cielo: devuelve las coordenadas locales (-1..1) o rr > 1 si no está
vec3 disk(vec3 d, vec3 pd, float r) {
	float cosang = dot(d, pd);
	vec3 upv = normalize(vec3(0.0, 1.0, 0.0) - pd * pd.y + vec3(0.0001, 0.0, 0.0));
	vec3 rt = cross(upv, pd);
	vec2 q = vec2(dot(d, rt), dot(d, upv)) / sin(r);
	return vec3(q, cosang > 0.0 ? length(q) : 9.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	float az = atan(d.z, d.x);
	vec3 col = mix(hor_col, mid_col, smoothstep(0.0, 0.32, h));
	col = mix(col, top_col, smoothstep(0.28, 0.95, h));
	col = mix(col, below_col, smoothstep(0.0, -0.35, h));
	// nubes de color en el espacio
	if (nebula > 0.0) {
		float nb = fbm(vec2(az * 1.7, h * 3.0) + 3.0);
		float nb2 = fbm(vec2(az * 2.4 + 9.0, h * 4.5));
		col += (neb_a * smoothstep(0.42, 0.85, nb) + neb_b * smoothstep(0.45, 0.9, nb2)) * nebula * (0.35 + 0.65 * smoothstep(-0.4, 0.5, h));
	}
	// bancos de polvo
	float band = smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.12, 0.34, h));
	float cl = fbm(vec2(az * 2.6, h * 14.0));
	col = mix(col, haze_col, smoothstep(0.45, 0.8, cl) * band * haze_amt);
	// estrellas: puntitos redondos repartidos por toda la esfera (celdas 3D con un corrimiento al azar)
	vec3 sp3 = d * 150.0;
	vec3 cell = floor(sp3);
	vec3 fr = fract(sp3) - 0.5;
	float rnd = hash(cell.xy + cell.z * 17.0);
	vec3 off = vec3(hash(cell.yz + 1.7), hash(cell.zx + 3.1), hash(cell.xy + 5.3)) - 0.5;
	float st = step(stars, rnd) * smoothstep(0.20, 0.04, length(fr - off * 0.6)) * mix(smoothstep(star_floor, star_floor + 0.4, h), 1.0, stars_below);
	col += vec3(1.0, 0.97, 0.92) * st * (0.6 + 0.8 * hash(cell.xy + 3.0));
	// planeta grande
	if (planet_type > 0) {
		vec3 pd = normalize(planet_dir);
		vec3 dk = disk(d, pd, planet_r);
		vec2 q = dk.xy;
		float rr = dk.z;
		if (rr < 1.0) {
			float z = sqrt(1.0 - rr * rr);
			vec3 n = vec3(q, z);
			vec3 upv = normalize(vec3(0.0, 1.0, 0.0) - pd * pd.y + vec3(0.0001, 0.0, 0.0));
			vec3 rt = cross(upv, pd);
			vec3 sl = normalize(vec3(dot(sun_dir, rt), dot(sun_dir, upv), dot(sun_dir, pd)));
			float diff = clamp(dot(n, sl), 0.0, 1.0);
			vec3 pc;
			if (planet_type == 1) {
				float wob = fbm(vec2(q.x * 2.4 + TIME * 0.012, q.y * 6.0)) - 0.5;
				float bnd = n.y * 3.2 + wob * 0.55 + 0.1 * sin(n.y * 17.0 + wob * 3.0);
				pc = gas_pal(bnd);
				vec2 sc = (q - vec2(0.28, -0.30)) * vec2(1.0, 1.9);
				pc = mix(pc, storm_col, smoothstep(0.30, 0.08, length(sc)) * 0.85);
				pc *= 0.16 + 0.95 * diff;
				pc += glow_col * pow(1.0 - z, 3.0) * 0.35;
			} else {
				float c1 = fbm(n.xy * 3.0 + vec2(n.z * 2.0, 1.0));
				float land = smoothstep(0.52, 0.58, c1);
				vec3 ocean = vec3(0.10, 0.32, 0.78);
				vec3 ground = mix(vec3(0.28, 0.58, 0.28), vec3(0.62, 0.52, 0.34), smoothstep(0.55, 0.75, fbm(n.xy * 6.0)));
				pc = mix(ocean, ground, land);
				float cloud = smoothstep(0.50, 0.70, fbm(n.xy * 4.5 + vec2(TIME * 0.01, 5.0) + n.z));
				pc = mix(pc, vec3(0.97), cloud * 0.85);
				pc *= 0.08 + 1.05 * diff;
				pc += vec3(0.35, 0.6, 1.0) * pow(1.0 - z, 3.0) * 0.55;
			}
			col = pc;
		} else if (rr < 1.55 && dk.z < 9.0) {
			float g = smoothstep(1.55, 1.0, rr);
			col += glow_col * g * g * 0.35;
		}
	}
	// lunas chicas
	if (moon1_r > 0.0) {
		vec3 dk = disk(d, normalize(moon1_dir), moon1_r);
		if (dk.z < 1.0) {
			float z = sqrt(1.0 - dk.z * dk.z);
			col = moon1_col * (0.25 + 0.85 * clamp(dot(vec3(dk.xy, z), vec3(0.5, 0.5, 0.7)), 0.0, 1.0)) * (0.9 + 0.2 * fbm(dk.xy * 4.0));
		}
	}
	if (moon2_r > 0.0) {
		vec3 dk = disk(d, normalize(moon2_dir), moon2_r);
		if (dk.z < 1.0) {
			float z = sqrt(1.0 - dk.z * dk.z);
			col = moon2_col * (0.25 + 0.85 * clamp(dot(vec3(dk.xy, z), vec3(-0.4, 0.5, 0.7)), 0.0, 1.0)) * (0.9 + 0.2 * fbm(dk.xy * 5.0));
		}
	}
	// sol
	float sd = dot(d, normalize(sun_dir));
	col += sun_col * (smoothstep(0.9993 - 0.0004 * sun_size, 0.99975 - 0.0004 * sun_size, sd) * 4.0);
	col += sun_col * pow(max(sd, 0.0), 90.0) * 0.7;
	col += mix(sun_col, hor_col, 0.5) * pow(max(sd, 0.0), 10.0) * 0.22;
	COLOR = col;
}
