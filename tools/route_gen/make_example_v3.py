#!/usr/bin/env python3
"""Ejemplos del formato v3 (sirven para probar el juego y el validador sin el editor HTML): un OCHO (circuito que se cruza a nivel) y un recorrido A→B de montaña.
Uso: python3 make_example_v3.py ocho|ab [salida.json]"""
import json, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_spec3 as S3

def resample(poly, step=90.0, closed=True):
    out = [poly[0]]
    acc = 0.0
    n = len(poly)
    last = n if closed else n - 1
    for i in range(last):
        a, b = poly[i], poly[(i + 1) % n]
        d = math.dist(a, b)
        acc += d
        if acc >= step:
            out.append(b)
            acc = 0.0
    if not closed and out[-1] != poly[-1]:
        out.append(poly[-1])
    return [[round(p[0], 1), round(p[1], 1), round(p[2], 1)] for p in out]

def ocho(a=420.0, dy=3.0):
    """Lemniscata de Bernoulli (se cruza en el centro a 90°). Altura distinta en cada pasada por el cruce (dy) para probar que el juego las iguala."""
    poly = []
    N = 720
    for k in range(N):
        t = 2 * math.pi * k / N
        den = 1 + math.sin(t) ** 2
        x = a * math.cos(t) / den
        z = a * math.sin(t) * math.cos(t) / den
        y = 40.0 + 6.0 * math.sin(2 * t + 0.6) + dy * math.cos(t)
        poly.append([x, y, z])
    # arranca en el tramo recto cerca del cruce pero lejos de él: elegimos t≈pi/2+0.35
    k0 = int(N * 0.31)
    poly = poly[k0:] + poly[:k0]
    return resample(poly, 70.0)

def ab():
    pts = []
    for i in range(0, 60):
        t = i / 59.0
        x = -900 + 1800 * t
        z = 220 * math.sin(t * math.pi * 3.0) + 60 * math.sin(t * 17.0)
        y = 20 + 40 * math.sin(t * math.pi) + 2 * math.sin(t * 20.0)
        pts.append([x, y, z])
    return resample(pts, 80.0, closed=False)

def bajada(deg=4.0, alt0=320.0, km=4.6):
    """Descenso continuo A→B: serpentea en planta y baja con pendiente constante (deg grados) desde alt0."""
    pts = []
    N = 400
    x = -1800.0
    for i in range(N):
        t = i / (N - 1)
        x = -1800.0 + 3600.0 * t
        z = 330.0 * math.sin(t * math.pi * 4.0) * (0.35 + 0.65 * math.sin(t * math.pi))
        pts.append([x, 0.0, z])
    out = [pts[0]]
    acc = 0.0
    for i in range(1, N):
        acc += math.dist((pts[i][0], pts[i][2]), (pts[i - 1][0], pts[i - 1][2]))
        pts[i][1] = 0.0
    # altura por recorrido acumulado
    cum = [0.0]
    for i in range(1, N):
        cum.append(cum[-1] + math.dist((pts[i][0], pts[i][2]), (pts[i - 1][0], pts[i - 1][2])))
    for i in range(N):
        pts[i][1] = alt0 - cum[i] * math.tan(math.radians(deg))
    return resample(pts, 90.0, closed=False)

def doc(kind):
    if kind == "bajada":
        return {"format": "dreamracing-route", "version": 3, "id": "ej_bajada", "name": "Descenso 4° (ejemplo)", "icon": "🏔️", "type": "point_to_point",
                "route": {"halfWidth": 4.8, "shoulder": 2.0, "points": bajada()},
                "sections": [{"from": 0.0, "to": 0.6, "surface": "asphalt", "density": 0.6}, {"from": 0.6, "to": 1.0, "surface": "dirt", "label": "Piso suelto", "density": 0.8}],
                "weather": {"sky": "overcast"}, "scenery": {"trees": "pine", "density": 0.7}, "decor": {"edge": "auto", "vegetation": 0.8},
                "race": {"style": "timetrial"}, "rivals": {"count": 3, "difficulty": 0.5}, "slope": {"mode": "descent", "deg": 4.0}}
    if kind == "ocho":
        return {"format": "dreamracing-route", "version": 3, "id": "ejemplo_ocho", "name": "Ocho (ejemplo)", "icon": "♾️", "type": "circuit",
                "route": {"halfWidth": 4.6, "shoulder": 2.0, "points": ocho()},
                "sections": [{"from": 0.0, "to": 0.5, "surface": "asphalt", "label": "Asfalto", "density": 0.6}, {"from": 0.5, "to": 0.8, "surface": "dirt", "label": "Tierra", "density": 1.0}, {"from": 0.8, "to": 1.0, "surface": "asphalt", "density": 0.5}],
                "weather": {"sky": "day"}, "scenery": {"trees": "mixed", "density": 0.6}, "decor": {"edge": "auto", "vegetation": 1.0},
                "race": {"style": "chase", "laps": 2, "chase": {"maxGapM": 150}, "elimination": {"everySec": 30}},
                "rivals": {"count": 1, "difficulty": 0.6}, "reverse": True}
    return {"format": "dreamracing-route", "version": 3, "id": "ejemplo_ab", "name": "Montaña A→B (ejemplo)", "icon": "⛰️", "type": "point_to_point",
            "route": {"halfWidth": 4.2, "shoulder": 2.0, "points": ab()},
            "sections": [{"from": 0.0, "to": 0.4, "surface": "asphalt", "density": 0.5}, {"from": 0.4, "to": 0.7, "surface": "mud", "label": "Barrial", "density": 0.8}, {"from": 0.7, "to": 1.0, "surface": "dirt", "density": 1.0}],
            "weather": {"sky": "rain"}, "scenery": {"trees": "pine", "density": 0.7}, "decor": {"edge": "auto", "vegetation": 0.8},
            "race": {"style": "adventure"}, "rivals": {"count": 3, "difficulty": 0.5}}

if __name__ == "__main__":
    kind = sys.argv[1] if len(sys.argv) > 1 else "ocho"
    d = doc(kind)
    e, w, info = S3.validate(d)
    for m in e:
        print("❌", m)
    for m in w:
        print("⚠", m)
    print("ℹ", {k: round(v, 1) for k, v in info.items()})
    if len(sys.argv) > 2:
        json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), indent=1, ensure_ascii=False)
