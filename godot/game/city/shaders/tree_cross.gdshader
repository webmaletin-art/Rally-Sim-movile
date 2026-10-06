shader_type spatial;
// ÁRBOL FALSO DE CRUZ (mundo abierto, de media distancia): dos cuadros verticales cruzados a 90° (4 triángulos) con las vistas de 0° y 90° de la misma textura de capas que usa tree_bill.
// Quedan fijos en el mundo con el giro de cada instancia, así que no hace falta calcular nada por vértice. INSTANCE_CUSTOM igual que en tree_bill: x = primera capa · yzw = tinte.
render_mode unshaded, cull_disabled;

uniform sampler2DArray views : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor : hint_range(0.0, 1.0) = 0.45;
uniform vec3 tone = vec3(1.0);

varying flat float v_layer;
varying vec3 v_tint;
varying vec2 v_uv;

void vertex() {
	v_layer = INSTANCE_CUSTOM.x + (UV2.x > 0.5 ? 2.0 : 0.0); // plano 0 = vista de 0° · plano 1 = vista de 90°
	v_tint = INSTANCE_CUSTOM.yzw;
	v_uv = UV;
}

void fragment() {
	vec4 c = texture(views, vec3(v_uv, v_layer));
	ALBEDO = c.rgb * v_tint * tone;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
