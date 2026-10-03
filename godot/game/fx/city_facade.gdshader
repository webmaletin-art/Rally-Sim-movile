shader_type spatial;
// Fachadas de papel de la ciudad: las ventanas, los postigos, los balcones y las persianas de los negocios no son geometría ni imágenes grandes: las dibuja este shader
// a partir de las medidas de la pared. Cada edificio es una caja de pocas caras. COLOR = color de la pared (rgb) y una semilla (a) · UV = metros sobre la pared
// (u a lo ancho, v hacia arriba desde la planta baja) · UV2 = (ancho, alto) de esa pared (alto 0 = techo, sin ventanas).

varying vec3 wcol;
varying float seed;

float h11(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float box(vec2 f, vec2 lo, vec2 hi) {
	return step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
}

void vertex() {
	wcol = COLOR.rgb;
	seed = COLOR.a;
}

void fragment() {
	vec3 col = wcol;
	vec2 sz = UV2;
	vec2 uv = UV;
	if (sz.y > 0.5 && uv.y > 0.0) {
		float sx = mix(3.0, 4.0, fract(seed * 7.0));
		float sy = 3.2;
		float cols = max(1.0, floor(sz.x / sx));
		float margin = (sz.x - cols * sx) * 0.5;
		float ux = uv.x - margin;
		float rows = floor(sz.y / sy + 0.5);
		float shade = 0.97 + 0.06 * h21(floor(uv * vec2(5.0, 4.0)) + seed * 40.0);
		col *= shade;
		// zócalo y cornisa
		if (uv.y < 0.5) {
			col *= 0.82;
		}
		if (uv.y > sz.y - 0.55) {
			col = mix(col * 1.08, col * 0.88, step(sz.y - 0.22, uv.y));
		} else if (ux > 0.0 && ux < cols * sx) {
			vec2 cell = vec2(floor(ux / sx), floor(uv.y / sy));
			vec2 f = vec2(fract(ux / sx), fract(uv.y / sy));
			float hv = h21(cell + seed * 91.0);
			float hv2 = h21(cell * 1.7 + seed * 13.0);
			bool ground = cell.y < 0.5;
			bool top = cell.y > rows - 1.5 && rows > 2.0;
			if (ground) {
				// planta baja: vidriera ancha (o puerta de madera en una de las celdas) y marquesina
				float door = step(0.82, hv);
				float shop = box(f, vec2(0.12, 0.10), vec2(0.88, 0.76)) * (1.0 - door);
				float dr = box(f, vec2(0.30, 0.0), vec2(0.70, 0.74)) * door;
				col = mix(col, vec3(0.20, 0.27, 0.34) * (0.8 + 0.4 * hv2), shop);
				col = mix(col, vec3(0.42, 0.26, 0.15), dr);
				float awn = box(f, vec2(0.05, 0.78), vec2(0.95, 0.92)) * step(0.45, hv2);
				col = mix(col, mix(vec3(0.85, 0.28, 0.20), vec3(0.20, 0.45, 0.30), step(0.5, fract(hv * 7.0))), awn);
			} else {
				float win = box(f, vec2(0.30, 0.28), vec2(0.70, 0.80));
				// marco más claro alrededor del vidrio
				float frame = box(f, vec2(0.25, 0.23), vec2(0.75, 0.85)) - win;
				vec3 glass = vec3(0.34, 0.44, 0.56) * (0.75 + 0.5 * hv2);
				col = mix(col, col * 1.15, frame);
				col = mix(col, glass, win);
				// postigos de color a los costados
				float shut = box(f, vec2(0.12, 0.26), vec2(0.28, 0.82)) + box(f, vec2(0.72, 0.26), vec2(0.88, 0.82));
				vec3 sc = mix(vec3(0.28, 0.45, 0.30), vec3(0.45, 0.30, 0.20), step(0.5, fract(seed * 3.0)));
				col = mix(col, sc, shut * step(0.50, hv));
				// balcón: baranda oscura bajo la ventana en algunos pisos
				float bal = box(f, vec2(0.14, 0.18), vec2(0.86, 0.26)) * step(0.78, hv2) * (top ? 0.0 : 1.0);
				col = mix(col, vec3(0.16, 0.16, 0.18), bal);
			}
			// los bordes de la pared quedan lisos (pilastras)
		}
	} else if (sz.y > 0.5) {
		col *= 0.80; // el faldón bajo la planta baja
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
