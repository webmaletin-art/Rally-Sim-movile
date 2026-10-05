shader_type spatial;
render_mode cull_back;
// Lámparas de los semáforos de Dream City (Etapa 7): una sola malla por cuadra y el color activo se calcula acá con la hora del mundo,
// con la MISMA cuenta que world/traffic_signals.gd (ciclo, verde y amarillo). Por vértice: COLOR.rgb = color de la lámpara, COLOR.a = qué lámpara es (0 roja, 0.5 amarilla, 1 verde),
// UV = (desfase del cruce en segundos, grupo 0|1).
uniform float world_time = 0.0;
uniform float cycle = 40.0;
uniform float green = 16.0;
uniform float yellow = 3.0;

varying flat float lit;
varying vec3 lamp;

void vertex() {
	float idx = floor(COLOR.a * 2.0 + 0.5);
	float ph = mod(world_time + UV.x + UV.y * cycle * 0.5, cycle);
	float st = ph < green ? 2.0 : (ph < green + yellow ? 1.0 : 0.0);
	lit = abs(idx - st) < 0.5 ? 1.0 : 0.0;
	lamp = COLOR.rgb;
}

void fragment() {
	ALBEDO = lamp * (0.18 + 0.5 * lit);
	EMISSION = lamp * lit * 2.2;
	ROUGHNESS = 0.5;
}
