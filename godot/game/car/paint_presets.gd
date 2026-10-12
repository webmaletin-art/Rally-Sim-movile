extends RefCounted
## Estilos de pintura listos (garaje → Pintura → Estilos). Cada uno fija el color de la carrocería, el de los detalles, el de las letras de las puertas, el rotulado y el acabado.
## «sólido»: detalles = carrocería (un solo color liso, con el relieve de la textura) + letras en las puertas (rotulados 7 a 10).
## «textura»: la textura del auto con dos colores (carrocería y detalles) que reemplazan los de fábrica. El 11 es la textura original sin tocar.
## livery: 0 Liso · 7 Dream Racing · 8 SRGamestudios · 9 Sport · 10 Nombre del auto · 11 Textura original
const LIST := [
	{"n": "De fábrica", "kind": "original", "body": "#f5f5f2", "accent": "#1b1d22", "text": "#f5f5f2", "livery": 11, "finish": "gloss"},
	{"n": "Blanco Nieve", "kind": "solid", "body": "#f2f3f5", "accent": "#f2f3f5", "text": "#1b1d22", "livery": 7, "finish": "gloss"},
	{"n": "Negro Mate", "kind": "solid", "body": "#15161a", "accent": "#15161a", "text": "#c9a24b", "livery": 9, "finish": "matte"},
	{"n": "Rojo Rally", "kind": "solid", "body": "#d3162b", "accent": "#d3162b", "text": "#f5f5f2", "livery": 7, "finish": "gloss"},
	{"n": "Azul Eléctrico", "kind": "solid", "body": "#1a4fe0", "accent": "#1a4fe0", "text": "#ffffff", "livery": 8, "finish": "gloss"},
	{"n": "Verde Bosque", "kind": "solid", "body": "#0f7a43", "accent": "#0f7a43", "text": "#e8e6e1", "livery": 7, "finish": "metal"},
	{"n": "Naranja Dakar", "kind": "solid", "body": "#ff6a08", "accent": "#ff6a08", "text": "#15161a", "livery": 9, "finish": "gloss"},
	{"n": "Amarillo Taxi", "kind": "solid", "body": "#ffc300", "accent": "#ffc300", "text": "#15161a", "livery": 7, "finish": "gloss"},
	{"n": "Gris Titanio", "kind": "solid", "body": "#6b7078", "accent": "#6b7078", "text": "#00b4d8", "livery": 9, "finish": "metal"},
	{"n": "Violeta Neón", "kind": "solid", "body": "#6a1fd1", "accent": "#6a1fd1", "text": "#00e5ff", "livery": 8, "finish": "gloss"},
	{"n": "Turquesa", "kind": "solid", "body": "#00b4d8", "accent": "#00b4d8", "text": "#0b2a35", "livery": 7, "finish": "gloss"},
	{"n": "Bordó", "kind": "solid", "body": "#7a1021", "accent": "#7a1021", "text": "#c9a24b", "livery": 10, "finish": "gloss"},
	{"n": "Arena", "kind": "solid", "body": "#d8c39a", "accent": "#d8c39a", "text": "#5a3f2a", "livery": 7, "finish": "matte"},
	{"n": "Plata", "kind": "solid", "body": "#c9ccd2", "accent": "#c9ccd2", "text": "#d3162b", "livery": 10, "finish": "metal"},
	{"n": "Rosa Pop", "kind": "solid", "body": "#ff4fa3", "accent": "#ff4fa3", "text": "#ffffff", "livery": 8, "finish": "gloss"},
	{"n": "Lima", "kind": "solid", "body": "#a6e22e", "accent": "#a6e22e", "text": "#15161a", "livery": 9, "finish": "gloss"},
	{"n": "Fuego", "kind": "texture", "body": "#ff6a08", "accent": "#d3162b", "text": "#f5f5f2", "livery": 0, "finish": "gloss"},
	{"n": "Hielo", "kind": "texture", "body": "#00b4d8", "accent": "#f2f3f5", "text": "#f5f5f2", "livery": 0, "finish": "gloss"},
	{"n": "Selva", "kind": "texture", "body": "#0f7a43", "accent": "#ffc300", "text": "#f5f5f2", "livery": 0, "finish": "metal"},
	{"n": "Noche", "kind": "texture", "body": "#15161a", "accent": "#6a1fd1", "text": "#f5f5f2", "livery": 0, "finish": "gloss"},
	{"n": "Oro y Negro", "kind": "texture", "body": "#c9a24b", "accent": "#15161a", "text": "#15161a", "livery": 0, "finish": "metal"},
	{"n": "Sangre", "kind": "texture", "body": "#7a1021", "accent": "#15161a", "text": "#f5f5f2", "livery": 0, "finish": "gloss"},
	{"n": "Cielo", "kind": "texture", "body": "#1a4fe0", "accent": "#f2f3f5", "text": "#f5f5f2", "livery": 0, "finish": "gloss"},
	{"n": "Lava", "kind": "texture", "body": "#15161a", "accent": "#ff6a08", "text": "#f5f5f2", "livery": 0, "finish": "matte"},
]

static func apply(paint: Dictionary, p: Dictionary) -> void:
	for k in ["body", "accent", "text", "livery", "finish"]:
		paint[k] = p[k]
