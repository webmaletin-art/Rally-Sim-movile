extends RefCounted
## Los locales de Dream City: el concesionario y los talleres. Cada taller se ocupa de un tipo de trabajo (el menú del taller muestra solo eso).
## tabs: pestañas del taller (0 piezas · 1 gomas · 2 ajuste · 3 pintura) · parts: mejoras que ofrece · tune: grupos de ajuste fino que ofrece.

const SHOPS := {
	"dealer": {"name": "Concesionario Dream City", "short": "Concesionario", "icon": "🚗", "color": Color(0.20, 0.45, 0.85), "kind": "dealer",
		"info": "Autos de calle, familiares y deportivos de todos los días.", "display": ["hatch", "gt", "veltor"],
		# (pedido del dueño, 15/10/2026: «cada concesionario muestra sólo lo suyo»; la TIENDA del menú sigue mostrando todos)
		"cars": ["hatch", "hatch2", "suv", "pickup", "camo", "trilux", "trilux_s", "kl5", "pro_gt", "gt", "muscle", "veltor"]},
	# concesionarios de especialidad: venden sólo su rubro (cars) y muestran 3 autos de verdad en la vidriera (display)
	"dealer_rally": {"name": "Rally & 4x4 del Puerto", "short": "Rally y 4x4", "icon": "🚙", "color": Color(0.85, 0.42, 0.12), "kind": "dealer",
		"info": "Autos de rally, camionetas y camiones para la tierra.", "display": ["hatch2", "kodiak", "buggy"],
		"cars": ["hatch2", "pickup", "suv", "kodiak", "camo", "buggy", "truck", "titan", "rally80", "genesis"]},
	"dealer_classic": {"name": "Clásicos de Colección", "short": "Clásicos", "icon": "🏁", "color": Color(0.62, 0.12, 0.14), "kind": "dealer",
		"info": "Clásicos y muscle cars de colección.", "display": ["clasico60", "torito", "muscle"],
		"cars": ["torito", "clasico60", "muscle", "rally80", "gt"]},
	"dealer_sport": {"name": "Dream Motorsport", "short": "Motorsport", "icon": "🏎", "color": Color(0.10, 0.10, 0.12), "kind": "dealer",
		"info": "Deportivos de pista, superdeportivos e hypercars.", "display": ["gt3", "strix", "hyper"],
		"cars": ["trilux", "pro_gt", "kl5", "trilux_s", "trilux_gt", "gt3", "veltor", "strix", "veltor_s", "moust", "veltor_gtr", "hyper", "police"]},
	"paint": {"name": "Taller de Pintura", "short": "Pintura", "icon": "🎨", "color": Color(0.85, 0.30, 0.65), "kind": "workshop", "tabs": [3, 5],
		"info": "Colores, acabados, llantas, pinzas, discos y estética."},
	"engine": {"name": "Taller de Motor", "short": "Motor", "icon": "⚙️", "color": Color(0.88, 0.25, 0.20), "kind": "workshop", "tabs": [0], "parts": ["engine", "turbo", "weight", "nitro"],
		"info": "Motor, turbo, aligerado y nitro."},
	"gearbox": {"name": "Taller de Transmisión", "short": "Transmisión", "icon": "🕹️", "color": Color(0.22, 0.62, 0.62), "kind": "workshop", "tabs": [0, 2], "parts": ["gearbox", "diff"], "tune": ["Transmisión"],
		"info": "Caja de cambios, diferencial y reparto de tracción."},
	"susp": {"name": "Suspensión y Frenos", "title": "Taller Susp. y Frenos", "short": "Suspensión", "icon": "🔧", "color": Color(0.30, 0.65, 0.35), "kind": "workshop", "tabs": [0, 2], "parts": ["suspension", "brakes", "stance"], "tune": ["Suspensión", "Frenos"],
		"info": "Suspensión, amortiguadores, barras, frenos y estilo."},
	"wheels": {"name": "Taller de Ruedas", "short": "Ruedas", "icon": "⚪", "color": Color(0.95, 0.80, 0.20), "kind": "workshop", "tabs": [1, 4, 2], "tune": ["Neumáticos", "Alineación"],
		"info": "Gomas, llantas, presiones y alineación."},
	"tune_a": {"name": "Reglaje Central", "title": "Reglaje · pista", "short": "Reglaje pista", "icon": "🎚", "color": Color(0.95, 0.50, 0.12), "kind": "workshop", "tabs": [0, 2], "parts": ["aero"], "tune": ["Neumáticos", "Alineación", "Aerodinámica"],
		"info": "Ajuste fino para asfalto y velocidad: aerodinámica, alineación y presiones."},
	"tune_b": {"name": "Reglaje del Puerto", "title": "Reglaje · tierra", "short": "Reglaje tierra", "icon": "🎚", "color": Color(0.95, 0.65, 0.15), "kind": "workshop", "tabs": [2], "tune": ["Suspensión", "Frenos", "Transmisión", "Diversión (gustos raros)"],
		"info": "Ajuste fino para tierra, saltos y derrapes."},
}

static func get_shop(id: String) -> Dictionary:
	return SHOPS.get(id, {})
