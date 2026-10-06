shader_type spatial;
// BOSQUE LEJANO: una tira de imágenes (siluetas de árboles con el borde de arriba irregular) enrollada en un anillo alrededor de la cámara. Es un solo cuadro por vuelta, sin árboles sueltos.
// Sin luz (la luz va pintada) y con la niebla del juego, que la funde con la distancia. Más allá de la costa el anillo se «hunde» en el piso para que no haya árboles sobre el mar.
render_mode unshaded, cull_disabled;

uniform sampler2D strip : source_color, filter_linear_mipmap, repeat_enable;
uniform float scissor : hint_range(0.0, 1.0) = 0.5;
uniform vec3 tone = vec3(1.0);
uniform float base_y = -6.5;
uniform float sea_from = 1180.0; // z desde la que los árboles empiezan a bajar
uniform float sea_to = 1400.0;   // z desde la que ya no hay (mar abierto)

varying vec2 v_uv;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = clamp((sea_to - wp.z) / (sea_to - sea_from), 0.0, 1.0);
	VERTEX.y = mix(base_y, VERTEX.y, f);
	v_uv = UV;
}

void fragment() {
	vec4 c = texture(strip, v_uv);
	ALBEDO = c.rgb * tone;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
