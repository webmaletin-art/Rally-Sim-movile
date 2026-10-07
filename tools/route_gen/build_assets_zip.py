#!/usr/bin/env python3
"""Arma tools/route_gen/dreamracing_route_assets.zip (lo que importa el generador HTML). Uso: python3 tools/route_gen/build_assets_zip.py"""
import json, os, zipfile
R = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"
G = R + "godot/game/"
T = R + "tools/route_gen/"
out = T + "dreamracing_route_assets.zip"
sp = ["pino", "cipres", "alamo", "hoja_ancha", "roble", "abedul", "sasafras", "palmera", "coco"]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for s in sp:
        for a in (0, 45, 90, 135, 180, 225, 270, 315):
            z.write(f"{G}city/trees/{s}_{a}.png", f"arboles/{s}_{a}.png")
    z.write(G + "city/trees/trees.json", "arboles/trees.json")
    for h in ("horizon_a", "horizon_b"):
        z.write(f"{G}city/trees/{h}.png", f"horizonte/{h}.png")
    for t in ("asphalt", "dirt", "grass"):
        z.write(f"{G}models/paper/tex/{t}.png", f"suelo/{t}.png")
    z.write(T + "FORMATO.md", "FORMATO.md")
    z.write(T + "referencias_mapas.json", "referencias/mapas_del_juego.json")
    for f in ("ejemplo_circuit_asphalt", "ejemplo_circuit_dirt", "ejemplo_point_to_point_dirt"):
        z.write(T + f + ".json", f"ejemplos/{f}.json")
    d = json.load(open(G + "data/routes.json", encoding="utf-8"))
    for k, surf, name in [("forest", "dirt", "Bosque de Tierra"), ("lake", "asphalt", "Circuito del Lago"), ("quarry", "dirt", "Cantera Roja"), ("asphaltLong", "asphalt", "Montaña Asfalto")]:
        r = d["routes"][k]
        doc = {"format": "dreamracing-route", "version": 2, "id": k.lower(), "name": name, "icon": "🏁", "type": "circuit", "surface": surf,
               "route": {"halfWidth": r["halfWidth"], "shoulder": r["shoulder"], "points": r["points"]},
               "sections": [{"from": 0.0, "to": 1.0, "surface": surf, "label": name, "density": 0.6}],
               "scenery": {"trees": "mixed", "density": 0.6, "ground": "grass"}, "race": {"laps": 2}, "rivals": {"count": 3, "difficulty": 0.5}}
        z.writestr(f"rutas_del_juego/{k.lower()}.json", json.dumps(doc, ensure_ascii=False, indent=1))
    z.writestr("LEEME.txt", """PAQUETE PARA EL GENERADOR DE MAPAS DE DREAM RACING
arboles/      9 especies de árbol en 8 vistas (cada 45°: _0, _45 … _315), PNG 192x192 con transparencia. trees.json: tamaño real en metros ('h' = alto, 'S' = ancho del cuadro).
              Se dibujan como carteles que giran hacia la cámara (billboards de 8 vistas). Pinos: pino, cipres. Hojas anchas: roble, hoja_ancha, abedul, alamo, sasafras. Tropicales: palmera, coco.
horizonte/    dos franjas de bosque lejano (2048x64, transparentes, se repiten en el horizonte)
suelo/        texturas de asfalto, tierra y pasto (128x128, se repiten)
referencias/  mapas_del_juego.json: 5 mapas reales medidos (km por vuelta, árboles, draw calls, índice de costo; la Bajada de los Badenes = 5,13 km por vuelta),
              presupuesto de árboles por teléfono, modelo de costo, escala de dificultad por copa y la lista de eventos de la carrera (para elegir cuál reemplaza un mapa)
ejemplos/     tres mapas de ejemplo en el formato de exportación v2
rutas_del_juego/  cuatro circuitos reales del juego (Bosque, Lago, Cantera, Montaña) en el mismo formato: sirven para ver cómo son las curvas y alturas buenas
FORMATO.md    el formato exacto del JSON y las reglas que tiene que cumplir cada mapa
NO hay modelos 3D de banquina ni de cartel de salida: el juego los dibuja con código. En el HTML dibujalos simples (cordón rojo/blanco, cartel con arco).
""")
print(os.path.getsize(out) // 1024, "KB")
