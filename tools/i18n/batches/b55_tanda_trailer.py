# Tanda del tráiler: dónde aparecer (un solo selector con mapa), secretos de la región, música, copas y online
# orden: en, pt, fr, it, de
def e(a, b, c, d, f):
    return (a, b, c, d, f)
T = {
"Tocá un lugar en el mapa o usá las flechas. Todos tienen estación de servicio o estacionamiento: se sale manejando.": e("Tap a place on the map or use the arrows. Every place has a service station or a car park: you drive straight out.", "Toque em um lugar no mapa ou use as setas. Todos têm posto de serviço ou estacionamento: você sai dirigindo.", "Touche un lieu sur la carte ou utilise les flèches. Chaque lieu a une station-service ou un parking : tu repars en conduisant.", "Tocca un luogo sulla mappa o usa le frecce. Ogni luogo ha una stazione di servizio o un parcheggio: si parte guidando.", "Tippe auf der Karte auf einen Ort oder nutze die Pfeile. Jeder Ort hat eine Tankstelle oder ein Parkhaus: Du fährst direkt los."),
"toca un lugar · arrastrá para mover · dos dedos para el zoom": e("tap a place · drag to move · two fingers to zoom", "toque num lugar · arraste para mover · dois dedos para o zoom", "touche un lieu · glisse pour déplacer · deux doigts pour zoomer", "tocca un luogo · trascina per spostare · due dita per lo zoom", "Ort antippen · ziehen zum Verschieben · zwei Finger zum Zoomen"),
"LUGAR": e("PLACE", "LUGAR", "LIEU", "LUOGO", "ORT"),
"APARECER AQUÍ": e("SPAWN HERE", "APARECER AQUI", "APPARAÎTRE ICI", "PARTI DA QUI", "HIER STARTEN"),
"Central · Nivel calle": e("Central · Street level", "Central · Nível da rua", "Central · Niveau rue", "Centrale · Livello strada", "Zentral · Straßenebene"),
"Central · Planta alta": e("Central · Upper level", "Central · Andar de cima", "Central · Étage", "Centrale · Piano alto", "Zentral · Obergeschoss"),
"Central · Subsuelo": e("Central · Underground", "Central · Subsolo", "Central · Sous-sol", "Centrale · Sotterraneo", "Zentral · Untergeschoss"),
"Estacionamiento Central, a nivel de la calle: salís directo a la ruta": e("Central Car Park, at street level: you drive straight onto the road.", "Estacionamento Central, no nível da rua: você sai direto para a estrada.", "Parking Central, au niveau de la rue : tu sors directement sur la route.", "Parcheggio Centrale, a livello strada: esci direttamente sulla strada.", "Zentrales Parkhaus, auf Straßenebene: Du fährst direkt auf die Straße."),
"Estacionamiento Central, un piso arriba: bajás por la rampa": e("Central Car Park, one level up: you go down the ramp.", "Estacionamento Central, um andar acima: você desce pela rampa.", "Parking Central, un étage au-dessus : tu descends par la rampe.", "Parcheggio Centrale, un piano sopra: scendi dalla rampa.", "Zentrales Parkhaus, eine Ebene höher: Du fährst die Rampe hinunter."),
"Estacionamiento Central, un piso abajo: subís por la rampa": e("Central Car Park, one level down: you go up the ramp.", "Estacionamento Central, um andar abaixo: você sobe pela rampa.", "Parking Central, un étage en dessous : tu montes par la rampe.", "Parcheggio Centrale, un piano sotto: sali dalla rampa.", "Zentrales Parkhaus, eine Ebene tiefer: Du fährst die Rampe hinauf."),
"estación de servicio": e("service station", "posto de serviço", "station-service", "stazione di servizio", "Tankstelle"),
"de Dream City": e("from Dream City", "de Dream City", "de Dream City", "da Dream City", "von Dream City"),
"Última ubicación": e("Last location", "Última localização", "Dernière position", "Ultima posizione", "Letzte Position"),
}
