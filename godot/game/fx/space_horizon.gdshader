shader_type spatial;
// Horizonte de los mapas fantasía «pintado»: un anillo de una sola pieza alrededor de la cámara con la silueta de lo que hay lejos (mesetas de Marte,
// lomas de cráteres de la Luna, cristales del anillo de Júpiter). Reemplaza al relieve lejano: no hay nada que dibujar ni ordenar, solo una imagen.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform int mode = 0; // 0 mesetas y picos · 1 lomas suaves · 2 cristales
uniform vec3 far_col : source_color = vec3(0.8, 0.5, 0.42);
uniform vec3 near_col : source_color = vec3(0.62, 0.34, 0.28);
uniform vec3 haze_col : source_color = vec3(0.97, 0.66, 0.48);
uniform float h_far = 110.0;
uniform float h_near = 70.0;
uniform float seed = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash(float n) { return fract(sin(n * 127.1 + seed * 17.3) * 43758.5453); }
// ruido que cierra la vuelta: el último valor es el primero (no hay costura donde el ángulo da la vuelta)
float pnoise(float x, float period) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(mod(i, period)), hash(mod(i + 1.0, period)), f);
}

// silueta de una capa: 0..1 según el ángulo (az en vueltas, 0..1); k = cantidad de elementos en toda la vuelta (entero)
float shape(float az, float k, float salt) {
	float x = az * k;
	float id = mod(floor(x), k);
	if (mode == 0) {
		float b = hash(id + salt);
		float plateau = mix(0.18, 0.75, b * b) * step(0.35, hash(id + salt + 3.0)); // mesetas de tapa plana
		float x2 = az * k * 3.0;
		float spire = pow(1.0 - abs(fract(x2) - 0.5) * 2.0, 3.0) * step(0.72, hash(mod(floor(x2), k * 3.0) + salt + 9.0)) * 0.9;
		return max(plateau, spire) * (0.85 + 0.15 * pnoise(az * k * 4.0, k * 4.0));
	} else if (mode == 1) {
		return 0.20 + 0.45 * pnoise(az * 6.0 + salt, 6.0 + salt * 0.0) * 0.0 + 0.45 * pnoise(az * 8.0, 8.0) + 0.25 * pnoise(az * 24.0, 24.0) + 0.1 * pnoise(az * 88.0, 88.0);
	}
	float tri = 1.0 - abs(fract(x) - 0.5) * 2.0;
	return pow(tri, 0.9) * (0.25 + 0.75 * hash(id + salt + 5.0));
}

void fragment() {
	float az = atan(lp.z, lp.x) / 6.2831853 + 0.5;
	float hf = shape(az, 22.0, 0.0) * h_far;
	float hn = shape(az, 31.0, 7.3) * h_near;
	float y = lp.y;
	vec3 col = far_col;
	float a = 0.0;
	if (y < hf) {
		a = 1.0;
		col = mix(far_col, haze_col, smoothstep(0.0, hf, hf - y) * 0.0 + (1.0 - smoothstep(-20.0, hf, y)) * 0.55);
	}
	if (y < hn) {
		a = 1.0;
		col = mix(near_col, haze_col, (1.0 - smoothstep(-20.0, hn, y)) * 0.35);
	}
	// borde suave arriba y desvanecido abajo (la franja nunca corta en seco)
	a *= smoothstep(-60.0, -8.0, y);
	ALBEDO = col;
	ALPHA = a;
}
