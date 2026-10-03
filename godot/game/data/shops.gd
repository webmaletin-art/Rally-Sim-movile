extends RefCounted
## Los locales de Dream City: el concesionario y los talleres. Cada taller se ocupa de un tipo de trabajo (el menú del taller muestra solo eso).
## tabs: pestañas del taller (0 piezas · 1 gomas · 2 ajuste · 3 pintura) · parts: mejoras que ofrece · tune: grupos de ajuste fino que ofrece.

const SHOPS := {
	"dealer": {"name": "Concesionario Dream City", "short": "Concesionario", "icon": "🚗", "color": Color(0.20, 0.45, 0.85), "kind": "dealer",
		"info": "Autos nuevos y tu garaje."},
	"paint": {"name": "Taller de Pintura", "short": "Pintura", "icon": "🎨", "color": Color(0.85, 0.30, 0.65), "kind": "workshop", "tabs": [3],
		"info": "Colores, acabados, llantas, pinzas y discos."},
	"engine": {"name": "Taller de Motor", "short": "Motor", "icon": "⚙️", "color": Color(0.88, 0.25, 0.20), "kind": "workshop", "tabs": [0], "parts": ["engine", "turbo", "weight", "nitro"],
		"info": "Motor, turbo, aligerado y nitro."},
	"gearbox": {"name": "Taller de Transmisión", "short": "Transmisión", "icon": "🕹️", "color": Color(0.22, 0.62, 0.62), "kind": "workshop", "tabs": [0, 2], "parts": ["gearbox", "diff"], "tune": ["Transmisión"],
		"info": "Caja de cambios, diferencial y reparto de tracción."},
	"susp": {"name": "Suspensión y Frenos", "title": "Taller Susp. y Frenos", "short": "Suspensión", "icon": "🔧", "color": Color(0.30, 0.65, 0.35), "kind": "workshop", "tabs": [0, 2], "parts": ["suspension", "brakes", "stance"], "tune": ["Suspensión", "Frenos"],
		"info": "Suspensión, amortiguadores, barras, frenos y estilo."},
	"wheels": {"name": "Taller de Ruedas", "short": "Ruedas", "icon": "⚪", "color": Color(0.95, 0.80, 0.20), "kind": "workshop", "tabs": [1, 2], "tune": ["Neumáticos", "Alineación"],
		"info": "Gomas, presiones y alineación."},
	"tune_a": {"name": "Reglaje Central", "title": "Reglaje · pista", "short": "Reglaje pista", "icon": "🎚", "color": Color(0.95, 0.50, 0.12), "kind": "workshop", "tabs": [0, 2], "parts": ["aero"], "tune": ["Neumáticos", "Alineación", "Aerodinámica"],
		"info": "Ajuste fino para asfalto y velocidad: aerodinámica, alineación y presiones."},
	"tune_b": {"name": "Reglaje del Puerto", "title": "Reglaje · tierra", "short": "Reglaje tierra", "icon": "🎚", "color": Color(0.95, 0.65, 0.15), "kind": "workshop", "tabs": [2], "tune": ["Suspensión", "Frenos", "Transmisión", "Diversión (gustos raros)"],
		"info": "Ajuste fino para tierra, saltos y derrapes."},
}

static func get_shop(id: String) -> Dictionary:
	return SHOPS.get(id, {})
