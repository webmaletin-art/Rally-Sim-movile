#!/usr/bin/env python3
"""Genera la ruta «Travesía X» y la escribe en godot/game/data/routes.json (ruta `travesia` + mapa `travesia`).
Un circuito cerrado de ~20 km: bosque rápido, barro, pedregal, valle, VADO de un lago, subida en zigzag a una colina, cresta, bajada suelta y barro final.
Uso: python3 tools/travesia/gen_route.py [--check]   (--check no escribe: solo imprime largo, radios mínimos y cruces)
"""
import json, math, random, sys, os

SEED = 23
HW = 3.0          # semiancho del camino: 6 m, dos autos van muy justos
SHOULDER = 2.4
SAMPLES = 11600   # ~4,4 m entre muestras

# Tramos, en el orden de la vuelta: (nombre, rótulo para el cartel, largo real en km, amplitud del meandro m, onda m, altura al final m, superficie, agarre IA, tope de velocidad del convoy m/s)
# superficie: 1 tierra · 5 barro. El tope es lo máximo que va el primero del convoy con el grupo junto (el camino bueno es rápido, el feo lento).
SECTIONS = [
    ("largada", "🏁 LARGADA", 0.8, 30, 700, 60, 1, 0.9, 24.0),
    ("bosque", "🌲 BOSQUE RÁPIDO", 2.4, 150, 520, 95, 1, 0.9, 32.0),
    ("barro1", "🟤 BARRIAL", 1.6, 90, 380, 78, 5, 0.62, 12.0),
    ("pedregal", "🪨 PEDREGAL", 1.5, 80, 330, 58, 1, 0.78, 11.0),
    ("valle", "🌾 VALLE ABIERTO", 2.2, 170, 760, 44, 1, 0.9, 33.0),
    ("vado", "🌊 EL VADO DEL LAGO", 1.4, 60, 560, 33, 5, 0.58, 10.0),
    ("orilla", "🏖 ORILLA", 1.0, 110, 420, 40, 5, 0.7, 13.0),
    ("ascenso", "⛰ ASCENSO EN ZIGZAG", 2.2, 95, 300, 190, 1, 0.8, 12.0),
    ("cresta", "🌄 LA CRESTA", 2.0, 140, 500, 215, 1, 0.9, 28.0),
    ("bajada_cueva", "💨 BAJADA A LA CUEVA", 1.0, 80, 330, 130, 1, 0.75, 15.0),
    ("cueva", "🕳 LA CUEVA", 1.0, 70, 260, 78, 1, 0.7, 12.0),
    ("arroyo", "🪨 EL ARROYO SECO", 1.3, 85, 340, 72, 1, 0.65, 11.0),
    ("escalones", "🧗 LOS ESCALONES", 1.4, 70, 380, 110, 1, 0.7, 9.5),
    ("bosque2", "🌲 BOSQUE CERRADO", 2.6, 115, 250, 120, 1, 0.85, 18.0),
    ("llanura", "🏁 LLANURA RÁPIDA", 2.4, 210, 950, 100, 1, 0.92, 34.0),
    ("medanos", "🌊 LOS MÉDANOS", 1.5, 100, 420, 95, 1, 0.8, 19.0),
    ("muro", "🧗 EL MURO", 0.5, 45, 300, 165, 1, 0.7, 10.0),
    ("cornisa", "🏔 LA CORNISA", 2.0, 95, 300, 250, 1, 0.8, 18.0),
    ("pico", "⛰ EL PICO", 2.2, 92, 290, 350, 1, 0.78, 12.0),
    ("techo", "🌄 EL TECHO", 0.8, 120, 450, 355, 1, 0.88, 25.0),
    ("gran_bajada", "💨 LA GRAN BAJADA", 2.8, 125, 380, 150, 1, 0.82, 27.0),
    ("barranca", "🪨 LA BARRANCA", 1.2, 90, 300, 75, 1, 0.68, 13.0),
    ("vado2", "🌊 EL LAGO GRANDE", 1.2, 60, 560, 60, 5, 0.58, 10.0),
    ("barro2", "🟤 BARRO PROFUNDO", 1.5, 100, 400, 72, 5, 0.58, 11.0),
    ("pedregal2", "🪨 PEDREGAL DE LA SIERRA", 1.2, 80, 330, 60, 1, 0.78, 11.0),
    ("pista", "🏁 PISTA DE TIERRA", 2.2, 190, 880, 60, 1, 0.92, 33.0),
    ("final", "🏁 RECTA FINAL", 1.0, 45, 700, 60, 1, 0.9, 26.0),
]
NAMES = [x[0] for x in SECTIONS]
TOTAL_KM = sum(x[2] for x in SECTIONS)
# baches / ondulaciones sobre el camino: (tramo, amplitud m, onda m, parte del tramo (desde, hasta))
DIP_DEFS = [("pedregal", 0.30, 18, (0.03, 0.97)), ("pedregal2", 0.30, 18, (0.03, 0.97)), ("vado", 1.6, 950, (0.1, 0.9)), ("vado2", 1.9, 1100, (0.1, 0.9)),
            ("bosque", 0.35, 38, (0.30, 0.42)), ("valle", 0.5, 60, (0.15, 0.40)), ("cresta", 0.5, 60, (0.20, 0.80)), ("arroyo", 0.45, 14, (0.04, 0.96)),
            ("medanos", 1.0, 46, (0.06, 0.94)), ("barranca", 0.5, 20, (0.05, 0.95)), ("gran_bajada", 0.4, 55, (0.55, 0.80)), ("pista", 0.45, 50, (0.45, 0.60))]
WATER_DEFS = [("vado", 0.8, 46), ("vado2", 0.9, 60)]  # (tramo, altura del agua sobre el punto más bajo, semiancho)
LEDGES_DEFS = [("escalones", 0.45, 42.0, 6.0, (0.05, 0.95))]  # (tramo, alto del escalón m, largo de cada escalón m, largo de la rampa m, parte del tramo)
CAVES_DEFS = [("cueva", (0.06, 0.94))]


HEIGHTS = []  # [(fracción real, altura)] — se llena en main()


def lerp_h(u):
    for (a, ya), (b, yb) in zip(HEIGHTS, HEIGHTS[1:]):
        if a <= u <= b:
            t = (u - a) / max(1e-9, b - a)
            t = t * t * (3 - 2 * t)
            return ya + (yb - ya) * t
    return HEIGHTS[-1][1]


def meander_factor(amp, lam):
    """Cuánto más largo es el camino que la curva base con ese meandro (promedio numérico)."""
    tot = 0.0
    n = 400
    for i in range(n):
        ph = 2 * math.pi * i / n
        d = amp * 2 * math.pi / lam * (math.cos(ph) + 0.28 * 2.3 * math.cos(ph * 2.3 + 1.1))
        tot += math.sqrt(1 + d * d)
    return tot / n


# largo de curva base que le toca a cada tramo (largo real / factor del meandro) y sus límites en fracción de la base
BASE_LEN = [x[2] * 1000.0 / meander_factor(x[3], x[4]) for x in SECTIONS]
BASE_TOTAL = sum(BASE_LEN)
BASE_BOUNDS = [0.0]
for _b in BASE_LEN:
    BASE_BOUNDS.append(BASE_BOUNDS[-1] + _b / BASE_TOTAL)


def section_at(ub):
    for i in range(len(SECTIONS)):
        if BASE_BOUNDS[i] <= ub < BASE_BOUNDS[i + 1]:
            return i
    return len(SECTIONS) - 1


def base_unit(th):
    # óvalo con tres ondulaciones (una península y dos bahías): más largo para la misma caja que un óvalo liso
    r = 1 + 0.25 * math.sin(3 * th + 1.9) + 0.14 * math.sin(2 * th + 0.6) + 0.07 * math.sin(5 * th + 0.4)
    return (1.18 * r * math.cos(th), 0.92 * r * math.sin(th))


def build():
    rnd = random.Random(SEED)
    N = 60000
    unit = [base_unit(2 * math.pi * i / N) for i in range(N + 1)]
    ulen = sum(math.dist(unit[i], unit[i - 1]) for i in range(1, N + 1))
    scale = BASE_TOTAL / ulen  # la curva base mide justo lo que suman los tramos (sin el meandro)
    base = [(x * scale, z * scale) for x, z in unit]
    cum = [0.0]
    for i in range(1, N + 1):
        cum.append(cum[-1] + math.dist(base[i], base[i - 1]))
    BL = cum[-1]
    pts = []
    d = 0.0
    phase = rnd.random() * 6.28
    amp_s = 30.0
    j = 0
    step = BL / round(BL / 22.0)
    while d < BL - 1e-6:
        u = d / BL
        sec = SECTIONS[section_at(u)]
        A, lam = float(sec[3]), float(sec[4])
        amp_s += (A - amp_s) * 0.03
        while j < N and cum[j + 1] < d:
            j += 1
        t = (d - cum[j]) / max(1e-6, cum[j + 1] - cum[j])
        bx = base[j][0] + (base[j + 1][0] - base[j][0]) * t
        bz = base[j][1] + (base[j + 1][1] - base[j][1]) * t
        tx = base[j + 1][0] - base[j][0]
        tz = base[j + 1][1] - base[j][1]
        tl = math.hypot(tx, tz)
        nx, nz = -tz / tl, tx / tl
        phase += 2 * math.pi / lam * step
        off = amp_s * (math.sin(phase) + 0.28 * math.sin(phase * 2.3 + 1.1))
        edge = min(1.0, min(u, 1 - u) / 0.006)  # el cierre: la amplitud baja a 0 cerca del principio/fin para que empalme
        off *= edge
        pts.append([bx + nx * off, bz + nz * off, u])
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
    return out  # cada punto lleva [x, z, u de la curva base]


def cr(p0, p1, p2, p3, w):
    t1 = [(p2[k] - p0[k]) * 0.5 for k in range(2)]
    t2 = [(p3[k] - p1[k]) * 0.5 for k in range(2)]
    out = []
    for k in range(2):
        c2 = -3 * p1[k] + 3 * p2[k] - 2 * t1[k] - t2[k]
        c3 = 2 * p1[k] - 2 * p2[k] + t1[k] + t2[k]
        out.append(p1[k] + t1[k] * w + c2 * w * w + c3 * w ** 3)
    return out


def spline(ctrl, sub=8):
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
    cum = [0.0]
    for sl in seglen:
        cum.append(cum[-1] + sl)
    minr = 1e9
    minr_at = 0
    k = max(1, int(round(25.0 / (total / n))))
    for i in range(n):
        a, b, c = pl[(i - k) % n], pl[i], pl[(i + k) % n]
        ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
        area2 = abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1]))
        r = ab * bc * ca / (2 * area2) if area2 > 1e-6 else 1e9
        if r < minr:
            minr, minr_at = r, cum[i] / total
    # cercanía entre tramos lejanos (por distancia recorrida), con una grilla para no revisar todos contra todos
    close = 1e9
    close_at = (0, 0)
    cell = 120.0
    grid = {}
    for i in range(0, n, 3):
        grid.setdefault((int(pl[i][0] // cell), int(pl[i][1] // cell)), []).append(i)
    for (gx, gz), lst in grid.items():
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for i in lst:
                    for j in grid.get((gx + dx, gz + dz), []):
                        if j <= i:
                            continue
                        arc = min(cum[j] - cum[i], total - (cum[j] - cum[i]))
                        if arc < 250:
                            continue
                        dd = math.dist(pl[i], pl[j])
                        if dd < close:
                            close, close_at = dd, (cum[i] / total, cum[j] / total)
    xs = [p[0] for p in pl]
    zs = [p[1] for p in pl]
    return total, minr, minr_at, close, close_at, (max(xs) - min(xs), max(zs) - min(zs))


def main():
    pts = resample(build(), 28.0)
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + math.dist(a[:2], b[:2]))
    tot = cum[-1] + math.dist(pts[-1][:2], pts[0][:2])
    ys = [c / tot for c in cum]
    bu = [p[2] for p in pts]

    def real_of_base(u):
        lo, hi = 0, len(bu) - 1
        if u >= bu[-1]:
            return 1.0
        while lo < hi - 1:
            mid = (lo + hi) // 2
            if bu[mid] <= u:
                lo = mid
            else:
                hi = mid
        t = (u - bu[lo]) / max(1e-12, bu[hi] - bu[lo])
        return ys[lo] + (ys[hi] - ys[lo]) * t

    sec_real = [(real_of_base(BASE_BOUNDS[i]), real_of_base(BASE_BOUNDS[i + 1]) if i + 1 < len(SECTIONS) else 1.0) for i in range(len(SECTIONS))]
    sec_real[0] = (0.0, sec_real[0][1])
    HEIGHTS.clear()
    HEIGHTS.append((0.0, float(SECTIONS[-1][5])))
    for i, sec in enumerate(SECTIONS):
        HEIGHTS.append((sec_real[i][1], float(sec[5])))
    ctrl = [[p[0], p[1], ys[i]] for i, p in enumerate(pts)]
    total, minr, minr_at, close, close_at, ext = analyse([[p[0], p[1]] for p in ctrl])
    # pendiente máxima por tramo (con la altura interpolada, antes de dips y escalones)
    worst = []
    for i, sec in enumerate(SECTIONS):
        g = 0.0
        for k in range(len(ctrl) - 1):
            if sec_real[i][0] <= ctrl[k][2] < sec_real[i][1]:
                dist = math.dist(ctrl[k][:2], ctrl[k + 1][:2])
                g = max(g, abs(lerp_h(ctrl[k + 1][2]) - lerp_h(ctrl[k][2])) / max(1.0, dist))
        worst.append(g)
    print("largo %.1f km (diseño %.1f) · radio mínimo %.1f m en u=%.3f · mínima cercanía %.1f m (u=%.3f/%.3f) · caja %.0f x %.0f m · %d puntos" % (total / 1000.0, TOTAL_KM, minr, minr_at, close, close_at[0], close_at[1], ext[0], ext[1], len(ctrl)))
    print("pendiente máxima por tramo: " + ", ".join("%s %.0f%%" % (SECTIONS[i][0], worst[i] * 100) for i in range(len(SECTIONS))))
    if "--plot" in sys.argv:
        from PIL import Image, ImageDraw
        xs = [c[0] for c in ctrl]
        zs = [c[1] for c in ctrl]
        W = 1400
        k = (W - 40) / max(max(xs) - min(xs), max(zs) - min(zs))
        im = Image.new("RGB", (W, int((max(zs) - min(zs)) * k) + 40), (30, 30, 40))
        dr = ImageDraw.Draw(im)
        palette = [(230, 80, 80), (90, 200, 90), (110, 150, 240), (230, 200, 80), (200, 110, 220), (90, 210, 210)]
        for i in range(len(ctrl) - 1):
            si = 0
            for q, (a0, a1) in enumerate(sec_real):
                if a0 <= ctrl[i][2] < a1:
                    si = q
            c = palette[si % len(palette)]
            dr.line([(20 + (ctrl[i][0] - min(xs)) * k, 20 + (ctrl[i][1] - min(zs)) * k), (20 + (ctrl[i + 1][0] - min(xs)) * k, 20 + (ctrl[i + 1][1] - min(zs)) * k)], fill=c, width=3)
        im.save("/tmp/claude-0/travesia_plot.png")
    if "--check" in sys.argv:
        return
    path = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "game", "data", "routes.json")
    data = json.load(open(path))
    points = [[round(p[0]), round(lerp_h(p[2])), round(p[1])] for p in ctrl]

    def zone(name, part):
        i = NAMES.index(name)
        a, b = sec_real[i]
        return round(a + (b - a) * part[0], 5), round(a + (b - a) * part[1], 5)

    dips = []
    for name, amp, wave, part in DIP_DEFS:
        f, t = zone(name, part)
        dips.append({"from": f, "to": t, "amp": amp, "wave": wave})
    water = []
    for name, above, half in WATER_DEFS:
        f, t = zone(name, (0.15, 0.85))
        water.append({"from": f, "to": t, "above": above, "half": half})
    ledges = []
    for name, rise, step, ramp, part in LEDGES_DEFS:
        f, t = zone(name, part)
        ledges.append({"from": f, "to": t, "rise": rise, "step": step, "len": ramp})
    caves = []
    for name, part in CAVES_DEFS:
        f, t = zone(name, part)
        caves.append({"from": f, "to": t})
    surf = [{"from": round(sec_real[i][0], 5), "to": round(sec_real[i][1], 5), "s": sec[6], "mu": sec[7]} for i, sec in enumerate(SECTIONS)]
    sections = [{"from": round(sec_real[i][0], 5), "to": round(sec_real[i][1], 5), "name": sec[0], "label": sec[1], "cap": sec[8]} for i, sec in enumerate(SECTIONS)]
    route = {"halfWidth": HW, "shoulder": SHOULDER, "samples": SAMPLES, "points": points, "dips": dips, "water": water, "ledges": ledges, "caves": caves, "surf": surf, "sections": sections}
    data["routes"]["travesia"] = route
    km = round(total / 1000.0)
    data["maps"]["travesia"] = {"name": "Travesía X", "icon": "🚙", "kind": "route", "route": "travesia", "mode": "dirt", "hills": 0, "convoy": True,
                                 "tagline": "Travesía extrema de %d km: barro, pedregal, dos lagos para vadear, escalones de roca, una cueva, el pico y la gran bajada. Se llega todos juntos." % km, "km": round(total / 1000.0, 1)}
    json.dump(data, open(path, "w"), ensure_ascii=False, separators=(",", ":"))
    print("escrito", path)


if __name__ == "__main__":
    main()
