#!/usr/bin/env python3
"""Genera la ruta «Travesía X» y la escribe en godot/game/data/routes.json (ruta `travesia` + mapa `travesia`).
Un circuito cerrado de ~20 km: bosque rápido, barro, pedregal, valle, VADO de un lago, subida en zigzag a una colina, cresta, bajada suelta y barro final.
Uso: python3 tools/travesia/gen_route.py [--check]   (--check no escribe: solo imprime largo, radios mínimos y cruces)
"""
import json, math, random, sys, os

SEED = 17
HW = 3.0          # semiancho del camino: 6 m, dos autos van muy justos
SHOULDER = 2.4
SAMPLES = 4600    # ~3,7 m entre muestras

# secciones: (desde, hasta, nombre) en fracción del recorrido
SECTIONS = [
    (0.000, 0.060, "largada"), (0.060, 0.200, "bosque"), (0.200, 0.265, "barro1"), (0.265, 0.335, "pedregal"),
    (0.335, 0.415, "valle"), (0.415, 0.470, "vado"), (0.470, 0.540, "orilla"), (0.540, 0.700, "ascenso"),
    (0.700, 0.775, "cresta"), (0.775, 0.895, "descenso"), (0.895, 0.960, "barro2"), (0.960, 1.000, "final"),
]
# alturas de control (u, y)
HEIGHTS = [(0.0, 60), (0.06, 58), (0.13, 76), (0.20, 70), (0.265, 44), (0.335, 40), (0.405, 33), (0.428, 30), (0.465, 30), (0.49, 32), (0.54, 36),
           (0.60, 82), (0.66, 150), (0.70, 188), (0.74, 204), (0.775, 198), (0.84, 124), (0.895, 52), (0.93, 44), (0.96, 48), (1.0, 60)]
# meandro (amplitud m, onda m) por sección
STYLE = {"largada": (40, 700), "bosque": (150, 520), "barro1": (95, 380), "pedregal": (80, 330), "valle": (170, 760), "vado": (60, 560),
         "orilla": (110, 420), "ascenso": (105, 285), "cresta": (140, 500), "descenso": (115, 300), "barro2": (100, 400), "final": (45, 700)}
# superficie (u0, u1, codigo, agarre IA) — 1 tierra, 5 barro
SURF = [(0.200, 0.265, 5, 0.62), (0.265, 0.335, 1, 0.78), (0.425, 0.465, 5, 0.58), (0.470, 0.500, 5, 0.70), (0.895, 0.960, 5, 0.64), (0.775, 0.895, 1, 0.82)]
DIPS = [{"from": 0.267, "to": 0.333, "amp": 0.30, "wave": 18}, {"from": 0.418, "to": 0.468, "amp": 1.6, "wave": 950},
        {"from": 0.075, "to": 0.095, "amp": 0.35, "wave": 38}, {"from": 0.345, "to": 0.37, "amp": 0.5, "wave": 60}]
WATER = [{"from": 0.425, "to": 0.465, "above": 0.8, "half": 46}]


def lerp_h(u):
    for (a, ya), (b, yb) in zip(HEIGHTS, HEIGHTS[1:]):
        if a <= u <= b:
            t = (u - a) / (b - a)
            t = t * t * (3 - 2 * t)
            return ya + (yb - ya) * t
    return HEIGHTS[-1][1]


def style_at(u):
    for a, b, n in SECTIONS:
        if a <= u < b:
            return STYLE[n]
    return STYLE["final"]


def base_curve(th):
    r = 1 + 0.20 * math.sin(2 * th + 0.6) + 0.10 * math.sin(3 * th + 1.9) + 0.05 * math.sin(5 * th + 0.4)
    return (1790 * 1.18 * r * math.cos(th), 1790 * 0.92 * r * math.sin(th))


def build(pmap=None):
    rnd = random.Random(SEED)
    # curva base densa y su longitud
    N = 40000
    base = [base_curve(2 * math.pi * i / N) for i in range(N + 1)]
    cum = [0.0]
    for i in range(1, N + 1):
        cum.append(cum[-1] + math.dist(base[i], base[i - 1]))
    BL = cum[-1]
    # fases del meandro: se integra 1/onda para que el cambio de onda no tenga saltos
    pts = []
    d = 0.0
    phase = rnd.random() * 6.28
    amp_s = 40.0
    j = 0
    # el paso entre puntos es chico donde la curva es cerrada
    step = BL / round(BL / 24.0)
    while d < BL - 1e-6:
        u = d / BL
        up = pmap(u) if pmap else u  # fracción del recorrido real (no de la curva base): así los tramos coinciden con las zonas
        A, lam = style_at(up)
        amp_s += (A - amp_s) * 0.02
        # posición sobre la base
        while j < N and cum[j + 1] < d:
            j += 1
        t = (d - cum[j]) / max(1e-6, cum[j + 1] - cum[j])
        bx = base[j][0] + (base[j + 1][0] - base[j][0]) * t
        bz = base[j][1] + (base[j + 1][1] - base[j][1]) * t
        tx = base[j + 1][0] - base[j][0]
        tz = base[j + 1][1] - base[j][1]
        tl = math.hypot(tx, tz)
        nx, nz = -tz / tl, tx / tl
        phase += 2 * math.pi * 1.0 / lam * step
        off = amp_s * (math.sin(phase) + 0.28 * math.sin(phase * 2.3 + 1.1))
        # el cierre: la amplitud baja a 0 cerca del principio/fin para que empalme
        edge = min(1.0, min(u, 1 - u) / 0.012)
        off *= edge
        pts.append([bx + nx * off, bz + nz * off, up, u])
        d += step
    return pts


def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for i in range(1, len(pts)):
        acc += math.dist(pts[i][:2], pts[i - 1][:2])
        if acc >= step:
            out.append(pts[i])
            acc = 0.0
    return out  # cada punto lleva [x, z, fracción, u base]


def cr(p0, p1, p2, p3, w):
    t1 = [(p2[k] - p0[k]) * 0.5 for k in range(2)]
    t2 = [(p3[k] - p1[k]) * 0.5 for k in range(2)]
    out = []
    for k in range(2):
        c2 = -3 * p1[k] + 3 * p2[k] - 2 * t1[k] - t2[k]
        c3 = 2 * p1[k] - 2 * p2[k] + t1[k] + t2[k]
        out.append(p1[k] + t1[k] * w + c2 * w * w + c3 * w ** 3)
    return out


def spline(ctrl, sub=12):
    n = len(ctrl)
    pl = []
    for i in range(n):
        for s in range(sub):
            pl.append(cr(ctrl[(i - 1) % n], ctrl[i], ctrl[(i + 1) % n], ctrl[(i + 2) % n], s / sub))
    return pl


def analyse(ctrl):
    pl = spline(ctrl)
    n = len(pl)
    seglen = [math.dist(pl[i], pl[(i + 1) % n]) for i in range(n)]
    total = sum(seglen)
    # radio mínimo (circunferencia por tres puntos a ~30 m)
    cum = [0.0]
    for s in seglen:
        cum.append(cum[-1] + s)
    minr = 1e9
    minr_at = 0
    k = max(1, int(round(30.0 / (total / n))))
    for i in range(n):
        a, b, c = pl[(i - k) % n], pl[i], pl[(i + k) % n]
        ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
        area2 = abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1]))
        r = ab * bc * ca / (2 * area2) if area2 > 1e-6 else 1e9
        if r < minr:
            minr, minr_at = r, cum[i] / total
    # cruces / cercanías entre tramos lejanos
    close = 1e9
    close_at = (0, 0)
    step = 6
    for i in range(0, n, step):
        for j in range(i + 1, n, step):
            arc = min(cum[j] - cum[i], total - (cum[j] - cum[i]))
            if arc < 160:
                continue
            dd = math.dist(pl[i], pl[j])
            if dd < close:
                close, close_at = dd, (cum[i] / total, cum[j] / total)
    xs = [p[0] for p in pl]
    zs = [p[1] for p in pl]
    return total, minr, minr_at, close, close_at, (max(xs) - min(xs), max(zs) - min(zs))


def main():
    pmap = None
    for _ in range(5):
        pts = resample(build(pmap), 40.0)
        # fracción real recorrida en cada punto (largo acumulado de la poligonal)
        cum = [0.0]
        for a, b in zip(pts, pts[1:]):
            cum.append(cum[-1] + math.dist(a[:2], b[:2]))
        tot = cum[-1] + math.dist(pts[-1][:2], pts[0][:2])
        # base u (guardada en p[3]) → fracción real
        xs = [p[3] for p in pts]
        ys = [c / tot for c in cum]
        def mk(xs=xs, ys=ys):
            def f(u):
                lo, hi = 0, len(xs) - 1
                while lo < hi - 1:
                    mid = (lo + hi) // 2
                    if xs[mid] <= u:
                        lo = mid
                    else:
                        hi = mid
                t = (u - xs[lo]) / max(1e-9, xs[hi] - xs[lo])
                return ys[lo] + (ys[hi] - ys[lo]) * min(1.0, max(0.0, t))
            return f
        pmap = mk()
    ctrl = [[p[0], p[1], ys[i]] for i, p in enumerate(pts)]
    total, minr, minr_at, close, close_at, ext = analyse([[p[0], p[1]] for p in ctrl])
    print("largo %.0f m · radio mínimo %.1f m en u=%.3f · mínima cercanía %.1f m (u=%.3f/%.3f) · caja %.0f x %.0f m · %d puntos" % (total, minr, minr_at, close, close_at[0], close_at[1], ext[0], ext[1], len(ctrl)))
    if "--check" in sys.argv:
        return
    path = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "game", "data", "routes.json")
    data = json.load(open(path))
    points = [[round(p[0]), round(lerp_h(p[2])), round(p[1])] for p in ctrl]
    # empalme: el primer y el último punto no pueden diferir mucho en altura
    route = {"halfWidth": HW, "shoulder": SHOULDER, "samples": SAMPLES, "points": points, "dips": DIPS, "water": WATER,
             "surf": [{"from": a, "to": b, "s": c, "mu": m} for a, b, c, m in SURF], "sections": [{"from": a, "to": b, "name": n} for a, b, n in SECTIONS]}
    data["routes"]["travesia"] = route
    data["maps"]["travesia"] = {"name": "Travesía X", "icon": "🚙", "kind": "route", "route": "travesia", "mode": "dirt", "hills": 0, "convoy": True,
                                 "tagline": "Convoy off-road de %d km: barro, pedregal, un lago para vadear, zigzag a la colina y bajada suelta. Se llega todos juntos." % round(total / 1000.0), "km": round(total / 1000.0, 1)}
    json.dump(data, open(path, "w"), ensure_ascii=False, indent="\t" if False else None, separators=(",", ":"))
    print("escrito", path)


if __name__ == "__main__":
    main()
