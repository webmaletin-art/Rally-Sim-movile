#!/usr/bin/env python3
"""Generador de ejemplo (el mismo tipo de lógica que se le pide al generador HTML): un lazo cerrado con radio ondulado, alturas suaves, y reintenta hasta que pasa la validación.
Uso: python3 make_example.py [--seed N] [--type circuit|point_to_point] [--surface asphalt|dirt] [--out archivo.json]"""
import argparse, json, math, random
import route_spec as S

def make(seed, typ="circuit", surface="asphalt", tries=4000):
    rnd = random.Random(seed)
    for attempt in range(tries):
        n = rnd.randint(18, 28)
        r0 = rnd.uniform(380, 700) if typ == "circuit" else rnd.uniform(700, 1100)
        harm = [(k, rnd.uniform(0.0, 0.28 / (k - 1)), rnd.uniform(0, math.tau)) for k in range(2, 6)]
        sq = rnd.uniform(0.75, 1.3)  # óvalo alargado
        hp = [(k, rnd.uniform(8, 30) / k, rnd.uniform(0, math.tau)) for k in (1, 2, 3)]
        pts = []
        for i in range(n):
            a = math.tau * i / n
            r = r0 * (1 + sum(h * math.cos(k * a + ph) for k, h, ph in harm))
            x, z = r * math.cos(a) * sq, r * math.sin(a)
            y = 45 + sum(h * math.sin(k * a + ph) for k, h, ph in hp)
            pts.append([round(x, 1), round(max(1.0, y), 1), round(z, 1)])
        # largar en el punto de curva más abierta
        best, bi = -1, 0
        for i in range(n):
            a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
            v1, v2 = (b[0] - a[0], b[2] - a[2]), (c[0] - b[0], c[2] - b[2])
            cr = abs(v1[0] * v2[1] - v1[1] * v2[0]) / (math.hypot(*v1) * math.hypot(*v2) + 1e-9)
            sc = 1 - cr
            if sc > best:
                best, bi = sc, i
        pts = pts[bi:] + pts[:bi]
        hw = round(rnd.uniform(*S.HALF_WIDTH[surface]), 1)
        doc = {"format": S.FORMAT, "version": 1, "id": f"ejemplo_{typ}_{seed}", "name": f"Ejemplo {typ} {seed}", "icon": "🏁", "type": typ, "surface": surface,
               "route": {"halfWidth": hw, "shoulder": round(rnd.uniform(*S.SHOULDER), 1), "points": pts},
               "scenery": {"trees": ["pino", "roble"] if surface == "dirt" else ["alamo", "cipres"], "density": 0.5, "ground": "grass"},
               "meta": {"generator": "make_example.py", "seed": seed}}
        if typ == "circuit":
            doc["race"] = {"laps": 2}
        else:
            doc["race"] = {"seg": [0.0, 0.55]}
        e, w, info = S.validate(doc)
        if not e:
            doc["meta"]["lengthM"] = round(info["length"])
            return doc, w, info, attempt + 1
    raise SystemExit("no se pudo generar una ruta válida")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--type", default="circuit")
    ap.add_argument("--surface", default="asphalt")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    doc, w, info, att = make(a.seed, a.type, a.surface)
    print("intentos:", att, {k: round(v, 1) for k, v in info.items()}, w)
    if a.out:
        json.dump(doc, open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
