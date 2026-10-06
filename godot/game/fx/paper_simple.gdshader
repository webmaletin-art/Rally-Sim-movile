shader_type spatial;
// EXPERIMENTO DE DIAGNÓSTICO (menú 📊 → PAPER SHADER → SIMPLE). NO es el shader final: sirve para medir cuánto cuesta paper.gdshader.
// Mismo aspecto básico que paper.gdshader (color liso por cara, iluminación Lambert, grano y textura impresa) pero sin lo caro por fragmento:
//  · sin la normal por derivadas (dFdx/dFdy + cross + normalize): usa la normal plana que ya trae la malla (el modo cull_disabled da vuelta la normal de las caras traseras);
//  · sin las líneas de borde de los dobleces (fwidth + 2 smoothstep + la mezcla con edge_col);
//  · sin la variación de tono por lote (floor + dot + sin + fract);
//  · los pow() de la conversión a lineal y las coordenadas de las texturas se calculan en el vértice (el color es liso por cara: da el mismo resultado);
//  · sin el bloque de destellos (glint, que la ciudad no usa).
// Los uniforms se declaran igual que en paper.gdshader para que los materiales conserven sus parámetros (los de borde y tono quedan sin uso).
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail : source_color, repeat_enable, filter_linear_mipmap; // textura impresa (asfalto, tierra, pasto)
uniform float detail_amt : hint_range(0.0, 1.0) = 0.0;
uniform float detail_scale = 0.18;
uniform vec3 edge_col : source_color = vec3(0.96, 0.93, 0.85);
uniform float edge_amt : hint_range(0.0, 1.0) = 0.42;
uniform float edge_px = 0.9;
uniform float grain_amt : hint_range(0.0, 0.5) = 0.16;
uniform float tint_var : hint_range(0.0, 0.3) = 0.10;
uniform float bright = 1.35;
uniform float glint = 0.0;
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.7);
uniform vec3 glint_col : source_color = vec3(1.0, 0.93, 0.78);

varying vec3 v_col;
varying vec2 v_guv;
varying vec2 v_duv;

vec3 to_lin(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_col = to_lin(COLOR.rgb) * bright;
	v_guv = wp.xz * 0.45 + wp.y * 0.31;
	v_duv = wp.xz * detail_scale;
}

void fragment() {
	float g = texture(grain, v_guv).r;
	vec3 base = v_col * (1.0 + (g - 0.5) * grain_amt * 2.0);
	if (detail_amt > 0.0) {
		vec3 d = texture(detail, v_duv).rgb;
		base = mix(base, base * (d * 1.9), detail_amt);
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
