shader_type spatial;
// IMPOSTOR 8 VISTAS: un solo cuadro (2 triángulos) que siempre mira a la cámara (gira sólo en Y) y muestra la vista de las 8 PNG (0°, 45°… 315°) más cercana
// al ángulo desde el que se mira el árbol. Las 8 imágenes están en UNA textura de capas compartida por todas las instancias. Sin luz (la luz ya está en las imágenes).
render_mode unshaded, cull_disabled;

uniform sampler2DArray views : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor : hint_range(0.0, 1.0) = 0.4;
uniform float brightness = 1.0;

varying flat float v_layer;
varying vec2 v_uv;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
	to_cam.y = 0.0;
	float l = length(to_cam);
	vec3 f = l > 0.001 ? to_cam / l : vec3(0.0, 0.0, 1.0);
	vec3 right = vec3(f.z, 0.0, -f.x);
	// ángulo de la cámara alrededor del árbol (0° = cámara hacia +Z del árbol) → vista más cercana de las 8
	float ang = atan(f.x, f.z);
	v_layer = floor(mod(ang / (PI * 0.25) + 8.5, 8.0));
	v_uv = UV;
	// VERTEX.x/y ya vienen en metros (el cuadro mide lo mismo que en las imágenes): se escala con la instancia
	vec3 world = origin + right * (VERTEX.x * sc) + vec3(0.0, VERTEX.y * sc, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec4 c = texture(views, vec3(v_uv, v_layer));
	ALBEDO = c.rgb * brightness;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
