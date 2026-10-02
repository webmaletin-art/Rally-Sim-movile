shader_type spatial;
// Papercraft: cada cara es un papel liso de un solo color (el color va en el vértice), con sombreado plano, los dobleces
// marcados como un borde claro (coordenadas baricéntricas en UV2) y grano de papel. Estático: no se mueve con el viento.
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

varying vec3 v_bary;
varying vec3 v_col;
varying vec3 v_wpos;

vec3 to_lin(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	v_bary = vec3(UV2.x, UV2.y, 1.0 - UV2.x - UV2.y);
	v_col = COLOR.rgb;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (fn.z < 0.0) fn = -fn;
	NORMAL = fn;
	float e = min(min(v_bary.x, v_bary.y), v_bary.z);
	float w = fwidth(e);
	float line = (1.0 - smoothstep(w * edge_px * 0.5, w * edge_px * 1.5, e)) * (1.0 - smoothstep(0.12, 0.35, w));
	float g = texture(grain, v_wpos.xz * 0.45 + v_wpos.y * 0.31).r;
	vec3 base = to_lin(v_col);
	// variación de papel de un lugar a otro (no todas las hojas son del mismo lote)
	float t = fract(sin(dot(floor(v_wpos.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	base *= 1.0 + (t - 0.5) * tint_var;
	base *= bright;
	base *= 1.0 + (g - 0.5) * grain_amt * 2.0;
	if (detail_amt > 0.0) {
		vec3 d = texture(detail, v_wpos.xz * detail_scale).rgb;
		base = mix(base, base * (d * 1.9), detail_amt);
	}
	ALBEDO = mix(base, to_lin(edge_col), line * edge_amt);
	ROUGHNESS = 1.0;
}
