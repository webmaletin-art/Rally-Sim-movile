extends RefCounted
## Lo que se vende dentro del juego (Google Play Billing). Los IDs tienen que ser EXACTAMENTE los que se crean en Play Console →
## «Monetizar → Productos → Productos integrados» (todos «no consumibles»: se compran una sola vez y se recuperan con «Restaurar»).
## Los precios los pone Play Console (el juego muestra el que devuelve Google). No se venden créditos.

const PRODUCTS := {
	"dr_full": {"kind": "unlock", "name": "Juego completo", "icon": "💎", "best": true,
		"desc": "TODO: la aventura completa (12 etapas), todas las copas, el camión Mamut, el GT3 RS y el Aerion. El mejor precio."},
	"dr_adventure": {"kind": "unlock", "name": "Aventura completa", "icon": "🌄",
		"desc": "Las 12 etapas de la Ruta de los Sueños (tenés 3 gratis) y las copas Nacional, Continental y Leyenda."},
	"dr_garage": {"kind": "unlock", "name": "Garaje premium", "icon": "🏎",
		"desc": "Los 3 autos premium: Mamut 6x6 (camión), GT3 RS y Aerion. Quedan en tu garaje."},
	"car_truck": {"kind": "unlock", "name": "Colossus Mamut 6x6", "icon": "🚛", "desc": "El camión de rally: diez toneladas imparables fuera del camino."},
	"car_gt3": {"kind": "unlock", "name": "Altair GT3 RS", "icon": "🏁", "desc": "Auto de carreras con matrícula: 9.000 vueltas de pura emoción."},
	"car_hyper": {"kind": "unlock", "name": "Vortex Aerion", "icon": "🚀", "desc": "Hypercar híbrido de 1.000 cv con tracción integral."},
}

## Orden en la pantalla de compras
const ORDER := ["dr_full", "dr_adventure", "dr_garage", "car_truck", "car_gt3", "car_hyper"]

static func ids() -> Array:
	return ORDER.duplicate()
