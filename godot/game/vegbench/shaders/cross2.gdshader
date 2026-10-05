shader_type spatial;
// CROSS DE 2 PLANOS: dos cuadros verticales cruzados a 90° (frente y costado del árbol), fijos en el mundo y con la orientación de cada instancia.
// La capa de la textura (0 = frente, 1 = costado) viene en el color del vértice. Sin luz.
render_mode unshaded, cull_disabled;

uniform sampler2DArray views : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor : hint_range(0.0, 1.0) = 0.4;
uniform float brightness = 1.0;

varying flat float v_layer;
varying vec2 v_uv;

void vertex() {
	v_layer = COLOR.r > 0.5 ? 1.0 : 0.0;
	v_uv = UV;
}

void fragment() {
	vec4 c = texture(views, vec3(v_uv, v_layer));
	ALBEDO = c.rgb * brightness;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
