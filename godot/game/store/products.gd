extends RefCounted
## Lo que se vende dentro del juego (Google Play Billing). Los IDs tienen que ser EXACTAMENTE los que se crean en Play Console →
## «Monetizar → Productos → Productos integrados». Los precios los pone Play Console (el juego muestra el que devuelve Google).
##
## kind "unlock": compra única (no se consume): se guarda en el perfil y se recupera sola al reinstalar («Restaurar»).
## kind "credits": se puede comprar varias veces (se «consume» al acreditar).

const PRODUCTS := {
	"dr_full": {"kind": "unlock", "name": "Dream Racing completo", "icon": "💎",
		"desc": "Desbloquea toda la Ruta de los Sueños (las 12 etapas) y todas las copas de la Carrera. Una sola vez, para siempre."},
	"dr_credits_s": {"kind": "credits", "amount": 25000, "name": "Bolsa de créditos", "icon": "💰", "desc": "$ 25.000 para tu garaje."},
	"dr_credits_m": {"kind": "credits", "amount": 100000, "name": "Valija de créditos", "icon": "💰", "desc": "$ 100.000 para tu garaje."},
	"dr_credits_l": {"kind": "credits", "amount": 300000, "name": "Baúl de créditos", "icon": "💰", "desc": "$ 300.000 para tu garaje."},
}

## Orden en la pantalla de compras
const ORDER := ["dr_full", "dr_credits_s", "dr_credits_m", "dr_credits_l"]

static func ids() -> Array:
	return ORDER.duplicate()
