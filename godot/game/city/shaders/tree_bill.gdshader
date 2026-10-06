shader_type spatial;
// ÁRBOL FALSO DE 8 VISTAS (mundo abierto): un cuadro (2 triángulos) que siempre mira a la cámara (gira sólo en Y) y muestra la vista (de las 8 imágenes de su especie) más cercana al ángulo
// desde el que se lo mira. Todas las especies están en UNA textura de capas (8 por especie) compartida por todas las instancias: una sola llamada de dibujo por cuadra.
// Por instancia (INSTANCE_CUSTOM): x = primera capa de la especie · yzw = tinte (variación de verde y de brillo). La luz ya está pintada en las imágenes: `tone` la sigue de noche.
render_mode unshaded, cull_disabled;

uniform sampler2DArray views : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor : hint_range(0.0, 1.0) = 0.45;
uniform vec3 tone = vec3(1.0);

varying flat float v_layer;
varying vec3 v_tint;
varying vec2 v_uv;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	to_cam.y = 0.0;
	float l = length(to_cam);
	vec3 f = l > 0.001 ? to_cam / l : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(f.z, 0.0, -f.x);
	float ang = atan(f.x, f.z); // 0° = la cámara está hacia +Z del árbol
	v_layer = INSTANCE_CUSTOM.x + floor(mod(ang / (PI * 0.25) + 8.5, 8.0));
	v_tint = INSTANCE_CUSTOM.yzw;
	v_uv = UV;
	vec3 world = origin + right * (VERTEX.x * sc) + vec3(0.0, VERTEX.y * sc, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec4 c = texture(views, vec3(v_uv, v_layer));
	ALBEDO = c.rgb * v_tint * tone;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
