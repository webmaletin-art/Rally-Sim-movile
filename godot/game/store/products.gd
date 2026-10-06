extends RefCounted
## Lo que se vende dentro del juego (Google Play Billing). Los IDs tienen que ser EXACTAMENTE los que se crean en Play Console →
## «Monetizar → Productos → Productos integrados». Dos clases:
##  · «unlock» = NO consumible: se compra una sola vez y se recupera con «Restaurar compras».
##  · «credits» = CONSUMIBLE: bolsas de monedas del juego (se pueden comprar las veces que se quiera; el juego acredita y consume la compra).
## Los precios los pone Play Console (el juego muestra el que devuelve Google).

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
	# Bolsas de monedas (consumibles). Precio sugerido en USD (a confirmar en Play Console): cada bolsa rinde más que la anterior.
	# Las monedas NO compran los autos premium ni el DR Bisonte XR (esos van aparte), así que nada de esto rompe el juego:
	# sólo acelera lo que igual se consigue corriendo (autos de la tienda de $18.000 a $120.000, piezas, pintura, nafta).
	"dr_coins_s": {"kind": "credits", "amount": 5000, "name": "Puñado de monedas", "icon": "🪙",
		"desc": "$ 5.000 para el garaje y el taller. Alcanza para un buen par de piezas."},
	"dr_coins_m": {"kind": "credits", "amount": 12000, "name": "Bolsa de monedas", "icon": "💰",
		"desc": "$ 12.000: un 20 % más por moneda. Un auto chico o un taller completo."},
	"dr_coins_l": {"kind": "credits", "amount": 30000, "name": "Cofre de monedas", "icon": "🧰",
		"desc": "$ 30.000: un 50 % más por moneda. Un auto de la tienda o varias mejoras."},
	"dr_coins_xl": {"kind": "credits", "amount": 80000, "name": "Baúl de monedas", "icon": "🏆",
		"desc": "$ 80.000: el mejor precio por moneda. Para armar el auto de tus sueños."},
}

## Orden en la pantalla de compras
const ORDER := ["dr_full", "dr_adventure", "dr_garage", "car_truck", "car_gt3", "car_hyper", "dr_coins_s", "dr_coins_m", "dr_coins_l", "dr_coins_xl"]

static func ids() -> Array:
	return ORDER.duplicate()
