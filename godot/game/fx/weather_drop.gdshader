shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Gotas de lluvia y copos de nieve (partículas). Igual que un material común sin luz, pero NO se dibuja lo que cae adentro del habitáculo del auto del jugador:
// con las cámaras interiores se veía llover dentro del auto. El volumen del habitáculo (piso, techo, pared de atrás, ventanillas y parabrisas inclinado) llega por uniforms.

uniform sampler2D tex : source_color, filter_linear;
uniform bool billboard = false; // copos: siempre de frente a la cámara (la lluvia ya se orienta sola con la velocidad)
uniform mat4 cab_inv = mat4(1.0); // mundo → habitáculo (el origen del habitáculo está a la altura del piso, z hacia adelante)
uniform vec4 cab_a = vec4(0.0); // semiancho, y del piso, y del techo, z de la pared de atrás
uniform vec4 cab_b = vec4(0.0); // z de la base del parabrisas, y de la base, z del borde de arriba, y del borde de arriba
uniform float cab_on = 0.0; // 1 = hay habitáculo cerrado (los autos sin techo, como el buggy, se mojan)
// Techos del mundo (15/10/2026: «llueve adentro del estacionamiento»): hasta 16 lugares cubiertos cerca de la cámara (salas del estacionamiento, rampas, túneles,
// techos de las gasolineras). Por techo: c0 = (x, z, y del techo, y del piso) y c1 = (eje x local en el plano: ux, uz, medio ancho, medio fondo; medio fondo < 0 = círculo
// de radio «medio ancho»). La gota (o la salpicadura) entera se descarta en el vértice si cae debajo de un techo: es barato (4 vértices por gota).
uniform vec4 cov0[16];
uniform vec4 cov1[16];
uniform int cov_n = 0;
uniform float fade_near = 0.0; // > 0: se desvanece con la distancia (las salpicaduras: enteras hasta fade_near, nada desde fade_far)
uniform float fade_far = 0.0;

varying vec3 wp;

bool covered(vec3 q) {
	for (int i = 0; i < cov_n; i++) {
		vec4 a = cov0[i];
		if (q.y > a.z || q.y < a.w) {
			continue;
		}
		vec4 b = cov1[i];
		vec2 d = q.xz - a.xy;
		if (b.w < 0.0) {
			if (dot(d, d) < b.z * b.z) {
				return true;
			}
		} else if (abs(dot(d, b.xy)) < b.z && abs(dot(d, vec2(-b.y, b.x))) < b.w) {
			return true;
		}
	}
	return false;
}

void vertex() {
	if (cov_n > 0 && covered(MODEL_MATRIX[3].xyz)) {
		VERTEX = vec3(0.0); // triángulos sin área: no se dibuja
	}
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (billboard) {
		// el copo se dibuja de frente: su posición en el mundo es la del centro de la partícula (más el tamaño, que es chico)
		wp = MODEL_MATRIX[3].xyz;
	}
}

void fragment() {
	if (cab_on > 0.5) {
		vec3 p = (cab_inv * vec4(wp, 1.0)).xyz;
		float k = clamp((p.y - cab_b.y) / max(cab_b.w - cab_b.y, 0.05), 0.0, 1.0);
		float zf = mix(cab_b.x, cab_b.z, k); // el parabrisas está inclinado: hacia arriba su borde se corre hacia atrás
		if (abs(p.x) < cab_a.x + 0.04 && p.y > cab_a.y && p.y < cab_a.z + 0.06 && p.z > cab_a.w && p.z < zf) {
			discard;
		}
	}
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a * COLOR.a;
	if (fade_far > 0.0) {
		ALPHA *= 1.0 - smoothstep(fade_near, fade_far, length(VERTEX));
	}
}
