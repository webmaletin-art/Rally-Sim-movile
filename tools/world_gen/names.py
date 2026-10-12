"""Nombres de ciudades, pueblos y villas de la región (inventados, con sabor argentino) y de las rutas."""
import random

CITIES = ["Puerto Alba", "Bahía Ámbar", "Santa Aurora", "Villa Cóndor", "Monte Sol", "Quebrada Roja", "Paso del Cóndor", "Río Hondo"]

TOWNS = ["San Telmo del Valle", "La Esperanza", "Mar Chiquita", "Valle Hondo", "Cerro Verde", "Las Tres Cruces", "Villa Ámbar", "El Algarrobal", "San Ramiro", "Puerto Chico",
         "Laguna Blanca", "Cuesta Alta", "Pampa Seca", "Los Molles", "Punta Aguada", "San Isidro Sur", "Colonia Libertad", "El Chañar", "Paso Real", "Monte Viejo",
         "Santa Lucía", "La Candelaria", "Piedra Blanca", "Arroyo Claro", "Tres Lomas"]

VILLAS = ["El Cardal", "Las Palmitas", "La Aguada", "Los Sauces", "San Gregorio", "El Mirador", "Villa Tulumba", "La Cañada", "Piedras Moras", "El Retiro",
          "Los Nogales", "Agua Buena", "San Benito", "La Estancia", "Campo Alegre", "El Duraznillo", "Cruz del Eje Chico", "Las Rosas", "La Cumbre Chica", "San Pedrito",
          "Los Quebrachos", "Tala Huasi", "El Churqui", "La Florida", "Ojo de Agua", "San Fermín", "Casa Vieja", "Los Álamos", "El Palmar", "Santa Rita",
          "La Quebrada", "Cuchilla Alta", "Tierra Colorada", "Rincón Hondo", "Bajo Verde", "El Fortín", "La Posta", "Pozo del Tigre", "Las Lajas", "San Cayetano",
          "El Zanjón", "La Toma", "Mojón Rojo", "Los Médanos", "Cabo Blanco", "Punta Brava", "Playa Dorada", "El Faro", "Mata Mora", "Loma Negra",
          "Sol de Mayo", "Capilla del Monte Chico", "Cañadón Seco", "La Carolina", "El Peral", "Vista Linda", "Aguas Claras", "Monte Hermoso Chico", "Valle Fértil Chico", "San Marcos"]

def pool(kind, rng):
    p = {"ciudad": CITIES, "pueblo": TOWNS, "villa": VILLAS}[kind][:]
    rng.shuffle(p)
    return p
