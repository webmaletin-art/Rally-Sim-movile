shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
// Fachadas de papel de la ciudad: las ventanas, los postigos, los balcones y las persianas de los negocios no son geometría ni imágenes grandes: las dibuja este shader
// a partir de las medidas de la pared. Cada edificio es una caja de pocas caras. COLOR = color de la pared (rgb) y una semilla (a) · UV = metros sobre la pared
// (u a lo ancho, v hacia arriba desde la planta baja) · UV2 = (ancho, alto) de esa pared (alto 0 = techo, sin ventanas).

// Papercraft: igual que el resto del mundo (paper.gdshader): sombreado plano, grano de papel, hojas de distinto lote y los dobleces marcados con un borde claro.
uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 edge_col : source_color = vec3(0.96, 0.93, 0.85);
uniform float grain_amt : hint_range(0.0, 0.5) = 0.10;
uniform float tint_var : hint_range(0.0, 0.3) = 0.10;
uniform float night : hint_range(0.0, 1.0) = 0.0; // 0 = de día · 1 = de noche: se prenden las luces de las ventanas y de los negocios

varying vec3 v_wpos;
varying vec3 wcol;
varying flat float seed; // sin interpolar: un error de 1 bit en la semilla cambiaría el hash en cada píxel

float h11(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// rectángulo con borde suave del ancho de un píxel (w = cuánto cambia f de un píxel al vecino): sin dientes de sierra ni centelleo
float box(vec2 f, vec2 lo, vec2 hi, vec2 pw) {
	vec2 w = pw * 0.8 + vec2(0.0005);
	vec2 a = smoothstep(lo - w, lo + w, f) * (vec2(1.0) - smoothstep(hi - w, hi + w, f));
	return a.x * a.y;
}

vec3 to_lin(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wcol = COLOR.rgb;
	seed = floor(COLOR.a * 255.0 + 0.5) / 255.0;
}

void fragment() {
	// normal de la propia malla (plana por cara): calcularla con derivadas de pantalla (dFdx/dFdy) tiembla en las GPU de celular con las paredes de costado y hace que el edificio
	// cambie de claro a oscuro al mover un poco la cámara
	vec3 fn = normalize(NORMAL);
	if (dot(fn, VIEW) < 0.0) fn = -fn;
	NORMAL = fn;
	vec3 col = wcol;
	float crease = 0.0; // 1 = hay un doblez o un borde de papel en este píxel
	vec3 glow = vec3(0.0); // luz propia (ventanas prendidas de noche)
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
			vec2 pw = min(fwidth(vec2(ux / sx, uv.y / sy)), vec2(0.5));
			float hv = h21(cell + seed * 91.0);
			float hv2 = h21(cell * 1.7 + seed * 13.0);
			bool ground = cell.y < 0.5;
			bool top = cell.y > rows - 1.5 && rows > 2.0;
			if (ground) {
				// planta baja: vidriera ancha (o puerta de madera en una de las celdas) y marquesina
				float door = step(0.82, hv);
				float shop = box(f, vec2(0.12, 0.10), vec2(0.88, 0.76), pw) * (1.0 - door);
				float dr = box(f, vec2(0.30, 0.0), vec2(0.70, 0.74), pw) * door;
				col = mix(col, vec3(0.20, 0.27, 0.34) * (0.8 + 0.4 * hv2), shop);
				col = mix(col, vec3(0.42, 0.26, 0.15), dr);
				glow = vec3(1.0, 0.82, 0.48) * shop * step(0.30, hv2) * (0.75 + 0.35 * hv);
				crease = max(crease, clamp(box(f, vec2(0.10, 0.08), vec2(0.90, 0.78), pw) - shop - dr, 0.0, 1.0) * 0.5);
				float awn = box(f, vec2(0.05, 0.78), vec2(0.95, 0.92), pw) * step(0.45, hv2);
				col = mix(col, mix(vec3(0.85, 0.28, 0.20), vec3(0.20, 0.45, 0.30), step(0.5, fract(hv * 7.0))), awn);
			} else {
				float win = box(f, vec2(0.30, 0.28), vec2(0.70, 0.80), pw);
				// marco más claro alrededor del vidrio
				float frame = box(f, vec2(0.25, 0.23), vec2(0.75, 0.85), pw) - win;
				vec3 glass = vec3(0.34, 0.44, 0.56) * (0.75 + 0.5 * hv2);
				col = mix(col, col * 1.15, frame);
				col = mix(col, glass * (0.88 + 0.24 * f.y), win);
				// de noche, algunas ventanas están prendidas (cálidas, a veces azuladas de tele)
				float lit = step(0.42, hv) * win;
				glow = mix(vec3(1.0, 0.78, 0.42), vec3(0.62, 0.78, 1.0), step(0.86, hv2)) * lit * (0.65 + 0.5 * hv2);
				// el hueco es un recorte: sombra del papel en el borde de arriba y de la izquierda, y un filo claro alrededor
				float shadow = win - box(f, vec2(0.34, 0.28), vec2(0.70, 0.76), pw);
				col = mix(col, col * 0.72, clamp(shadow, 0.0, 1.0));
				crease = max(crease, clamp(frame, 0.0, 1.0) * 0.55);
				// postigos de color a los costados
				float shut = box(f, vec2(0.12, 0.26), vec2(0.28, 0.82), pw) + box(f, vec2(0.72, 0.26), vec2(0.88, 0.82), pw);
				vec3 sc = mix(vec3(0.28, 0.45, 0.30), vec3(0.45, 0.30, 0.20), step(0.5, fract(seed * 3.0)));
				col = mix(col, sc, shut * step(0.50, hv));
				// balcón: baranda oscura bajo la ventana en algunos pisos
				float bal = box(f, vec2(0.14, 0.18), vec2(0.86, 0.26), pw) * step(0.78, hv2) * (top ? 0.0 : 1.0);
				col = mix(col, vec3(0.16, 0.16, 0.18), bal);
			}
			// los bordes de la pared quedan lisos (pilastras)
		}
	} else if (sz.y > 0.5) {
		col *= 0.80; // el faldón bajo la planta baja
	}
	if (sz.y > 0.5) {
		// bordes de la hoja de pared (costados, cornisa) y un doblez suave en cada piso
		vec2 px = max(fwidth(uv), vec2(0.0001));
		float dl = min(uv.x, sz.x - uv.x) / px.x;
		float dt = (sz.y - uv.y) / px.y;
		float edge = 1.0 - smoothstep(0.6, 1.6, min(dl, dt));
		float fl = abs(fract(uv.y / 3.2 + 0.0) - 0.0) * 3.2 / px.y;
		float fold = (1.0 - smoothstep(0.4, 1.2, fl)) * step(0.5, uv.y) * 0.25;
		crease = max(crease, max(edge * (1.0 - smoothstep(0.1, 0.4, max(px.x, px.y))), fold));
	}
	vec3 base = col * 0.96; // los colores ya están pensados para este brillo (no pasan por to_lin)
	float t = fract(sin(dot(floor(v_wpos.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	base *= 1.0 + (t - 0.5) * tint_var;
	float g = texture(grain, v_wpos.xz * 0.45 + v_wpos.y * 0.31).r;
	base *= 1.0 + (g - 0.5) * grain_amt * 2.0;
	ALBEDO = mix(base, edge_col, clamp(crease, 0.0, 1.0) * 0.5);
	EMISSION = glow * night * 1.25;
	ROUGHNESS = 1.0;
}
