#!/usr/bin/env python3
"""Reglas y validador del formato «dreamracing-route» v2 (el que exporta el generador HTML de rutas; la v1 se acepta y se convierte).
Las mismas reglas están escritas en FORMATO.md y en PROMPT_DEEPSEEK.md: si se cambia un número acá, cambiarlo ahí.
Uso: python3 route_spec.py archivo.json   → imprime errores (❌) y avisos (⚠) y sale con 1 si hay errores."""
import json, math, re, sys

FORMAT = "dreamracing-route"
VERSION = 2
SECTION_SURFACES = ("asphalt", "dirt", "gravel", "mud", "sand")
TREE_KINDS = ("none", "pine", "broadleaf", "mixed")
MAX_SECTIONS = 24
MIN_SECTION_M = 80.0      # un tramo de superficie no puede medir menos de esto
TIERS = ("debut", "nacional", "continental", "leyenda", "camiones")
SKIES = ("day", "overcast", "sunset", "dusk", "rain")
TYPES = ("circuit", "point_to_point", "drag")
SURFACES = ("asphalt", "dirt")
TREES = ("pino", "cipres", "alamo", "hoja_ancha", "roble", "abedul", "sasafras", "palmera", "coco")
GROUNDS = ("grass", "dirt", "sand")

# --- límites (metros) ---
MAX_COORD = 1500.0          # |x|, |z|
Y_RANGE = (0.0, 250.0)      # altura del centro del camino
N_POINTS = (12, 48)         # puntos de control del circuito cerrado
SPACING = (40.0, 260.0)     # distancia entre puntos de control consecutivos (incluido el último → el primero)
LENGTH_CIRCUIT = (1800.0, 7000.0)
LENGTH_P2P_LOOP = (4000.0, 12000.0)   # largo del lazo completo del punto a punto
LENGTH_P2P_RACE = (1800.0, 6000.0)    # largo de la parte que se corre (A → B)
HALF_WIDTH = {"asphalt": (4.2, 5.6), "dirt": (3.0, 4.4)}
SHOULDER = (1.6, 2.6)
MIN_RADIUS = {"asphalt": 22.0, "dirt": 18.0}
MAX_SLOPE = 0.12            # pendiente máxima (|dy/ds|) promediada en 20 m
CLEARANCE_EXTRA = 12.0      # dos tramos lejanos (> 60 m de recorrido) deben estar a ≥ 2*(halfWidth+shoulder)+12 m
START_STRAIGHT = 150.0      # los primeros 150 m desde el punto A son casi rectos (radio ≥ 90 m) para la parrilla
DRAG_LENGTHS = (201, 402, 804)

def catmull(points, per_seg=24):
    """Muestras del lazo cerrado Catmull-Rom uniforme (el mismo que usa el juego). Devuelve lista de (x,y,z) y el índice de muestra de cada punto de control."""
    n = len(points)
    out, idx = [], []
    for i in range(n):
        p0, p1, p2, p3 = (points[(i - 1) % n], points[i], points[(i + 1) % n], points[(i + 2) % n])
        idx.append(len(out))
        for k in range(per_seg):
            t = k / per_seg
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3) for c in range(3)))
    return out, idx

def _d2(a, b):
    return math.hypot(a[0] - b[0], a[2] - b[2])

def analyze(points):
    s, idx = catmull(points)
    n = len(s)
    cum = [0.0]
    for i in range(1, n + 1):
        cum.append(cum[-1] + math.dist(s[i % n], s[i - 1]))
    length = cum[-1]
    # radio mínimo (en planta) con tres muestras separadas ~10 m
    step = max(1, int(round(10.0 / (length / n))))
    min_r, min_i = 1e9, 0
    for i in range(n):
        a, b, c = s[(i - step) % n], s[i], s[(i + step) % n]
        ab, bc, ca = _d2(a, b), _d2(b, c), _d2(c, a)
        area2 = abs((b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0]))
        r = (ab * bc * ca) / area2 if area2 > 1e-6 else 1e9
        if r < min_r:
            min_r, min_i = r, i
    # pendiente máxima en ventanas de 20 m
    win = max(1, int(round(20.0 / (length / n))))
    max_slope = 0.0
    for i in range(n):
        j = (i + win) % n
        ds = (cum[(i + win)] - cum[i]) if i + win <= n else (length - cum[i] + cum[(i + win) - n])
        if ds > 1e-6:
            max_slope = max(max_slope, abs(s[j][1] - s[i][1]) / ds)
    return {"samples": s, "cum": cum, "length": length, "min_radius": min_r, "min_radius_i": min_i, "max_slope": max_slope, "ctrl_idx": idx}

def _arc_to(an, i, frac):
    """Índice de muestra a `frac` (0..1) del lazo desde la muestra i."""
    return int(round(i + frac * len(an["samples"]))) % len(an["samples"])

def normalize(d):
    """v1 → v2 (una sola superficie, árboles «mixed», 3 rivales de dificultad media). Devuelve una copia."""
    d = json.loads(json.dumps(d))
    # Los generadores en JS pueden escribir 2.0 en vez de 2: los enteros «con coma» se aceptan como enteros.
    for blk, key in (("race", "laps"), ("rivals", "count")):
        b = d.get(blk)
        if isinstance(b, dict) and isinstance(b.get(key), float) and b[key].is_integer():
            b[key] = int(b[key])
    if d.get("version") == 1:
        d["version"] = 2
        if d.get("type") != "drag":
            d["sections"] = [{"from": 0.0, "to": 1.0, "surface": d.get("surface", "asphalt")}]
        sc = d.get("scenery", {}) or {}
        d["scenery"] = {"trees": "mixed" if sc.get("trees") else "pine", "density": sc.get("density", 0.6), "ground": sc.get("ground", "grass")}
        d.setdefault("rivals", {"count": 3, "difficulty": 0.5})
    return d

def validate(d):
    if isinstance(d, dict) and d.get("version") == 3:
        import route_spec3
        return route_spec3.validate(d)
    d = normalize(d)
    errs, warns = [], []
    def E(m): errs.append(m)
    def W(m): warns.append(m)
    if d.get("format") != FORMAT or d.get("version") != VERSION:
        E(f"format/version: tiene que ser «{FORMAT}» y {VERSION} (o 1)")
    rid = str(d.get("id", ""))
    if not re.fullmatch(r"[a-z0-9_]{3,24}", rid):
        E("id: sólo minúsculas, números y _ (3 a 24 caracteres)")
    if not str(d.get("name", "")).strip():
        E("name: falta el nombre")
    t = d.get("type")
    if t not in TYPES:
        E(f"type: uno de {TYPES}")
        return errs, warns, {}
    surf = d.get("surface")
    if surf not in SURFACES:
        E(f"surface: uno de {SURFACES}")
        surf = "asphalt"
    sc = d.get("scenery", {}) or {}
    if sc.get("trees", "mixed") not in TREE_KINDS:
        E(f"scenery.trees: uno de {TREE_KINDS}")
    if sc.get("ground", "grass") not in GROUNDS:
        E(f"scenery.ground: uno de {GROUNDS}")
    dens = sc.get("density", 0.5)
    if not isinstance(dens, (int, float)) or not (0 <= dens <= 1):
        E("scenery.density: entre 0 y 1")
    info = {}
    if t == "drag":
        dg = d.get("drag", {})
        if dg.get("lengthM") not in DRAG_LENGTHS:
            E(f"drag.lengthM: uno de {DRAG_LENGTHS}")
        return errs, warns, info
    r = d.get("route", {})
    pts = r.get("points", [])
    if not (N_POINTS[0] <= len(pts) <= N_POINTS[1]):
        E(f"route.points: entre {N_POINTS[0]} y {N_POINTS[1]} puntos (tiene {len(pts)})")
        return errs, warns, info
    ok = True
    for i, p in enumerate(pts):
        if not (isinstance(p, list) and len(p) == 3 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in p)):
            E(f"route.points[{i}]: tiene que ser [x, y, z] con números")
            ok = False
    if not ok:
        return errs, warns, info
    hw, sh = r.get("halfWidth", 0), r.get("shoulder", 0)
    if not (HALF_WIDTH[surf][0] <= hw <= HALF_WIDTH[surf][1]):
        E(f"route.halfWidth: {HALF_WIDTH[surf][0]}–{HALF_WIDTH[surf][1]} m para {surf} (tiene {hw})")
    if not (SHOULDER[0] <= sh <= SHOULDER[1]):
        E(f"route.shoulder: {SHOULDER[0]}–{SHOULDER[1]} m (tiene {sh})")
    for i, p in enumerate(pts):
        if abs(p[0]) > MAX_COORD or abs(p[2]) > MAX_COORD:
            E(f"route.points[{i}]: x y z tienen que estar entre ±{MAX_COORD:.0f} m")
        if not (Y_RANGE[0] <= p[1] <= Y_RANGE[1]):
            E(f"route.points[{i}]: la altura y tiene que estar entre {Y_RANGE[0]:.0f} y {Y_RANGE[1]:.0f} m")
        q = pts[(i + 1) % len(pts)]
        dd = math.dist(p, q)
        if not (SPACING[0] <= dd <= SPACING[1]):
            E(f"route.points[{i}]→[{(i + 1) % len(pts)}]: {dd:.0f} m entre puntos; tiene que ser {SPACING[0]:.0f}–{SPACING[1]:.0f}")
    if errs:
        return errs, warns, info
    an = analyze(pts)
    L = an["length"]
    info = {"length": L, "min_radius": an["min_radius"], "max_slope": an["max_slope"]}
    lim = LENGTH_CIRCUIT if t == "circuit" else LENGTH_P2P_LOOP
    if not (lim[0] <= L <= lim[1]):
        E(f"largo del lazo: {L:.0f} m; tiene que ser {lim[0]:.0f}–{lim[1]:.0f}")
    if an["min_radius"] < MIN_RADIUS[surf]:
        E(f"curva demasiado cerrada: radio {an['min_radius']:.1f} m cerca del punto de control {an['min_radius_i'] // 24}; mínimo {MIN_RADIUS[surf]:.0f} m")
    if an["max_slope"] > MAX_SLOPE:
        E(f"pendiente de {an['max_slope'] * 100:.1f} % (máximo {MAX_SLOPE * 100:.0f} %)")
    # separación entre tramos lejanos
    s, cum = an["samples"], an["cum"]
    need = 2 * (hw + sh) + CLEARANCE_EXTRA
    n = len(s)
    stepc = max(1, n // 700)
    worst = 1e9
    wi = (0, 0)
    for i in range(0, n, stepc):
        for j in range(i + 1, n, stepc):
            arc = min(cum[j] - cum[i], L - (cum[j] - cum[i]))
            if arc < 60.0:
                continue
            dd = _d2(s[i], s[j])
            if dd < worst:
                worst, wi = dd, (i, j)
    if worst < need:
        E(f"el camino se acerca o se cruza consigo mismo (a {worst:.0f} m cerca de {s[wi[0]][0]:.0f},{s[wi[0]][2]:.0f}); tiene que haber ≥ {need:.0f} m")
    info["min_clearance"] = worst
    # recta de largada
    sa = int(round(START_STRAIGHT / (L / n)))
    step10 = max(1, int(round(10.0 / (L / n))))
    r_start = 1e9
    for i in range(0, sa):
        a, b, c = s[(i - step10) % n], s[i], s[(i + step10) % n]
        ab, bc, ca = _d2(a, b), _d2(b, c), _d2(c, a)
        area2 = abs((b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0]))
        r_start = min(r_start, (ab * bc * ca) / area2 if area2 > 1e-6 else 1e9)
    if r_start < 90.0:
        E(f"los primeros {START_STRAIGHT:.0f} m desde el punto A tienen que ser casi rectos (radio ≥ 90 m; tiene {r_start:.0f})")
    race = d.get("race", {})
    if t == "circuit":
        lp = race.get("laps")
        if not isinstance(lp, int) or not (1 <= lp <= 5):
            E("race.laps: entero entre 1 y 5")
        else:
            tot = L * lp
            if not (3000 <= tot <= 16000):
                W(f"carrera de {tot:.0f} m en total ({lp} vueltas): lo normal es 3000–16000 m")
    else:
        sg = race.get("seg")
        if not (isinstance(sg, list) and len(sg) == 2 and 0 <= sg[0] < sg[1] <= 1):
            E("race.seg: [desde, hasta] como fracciones 0–1 del lazo, desde < hasta")
        else:
            rl = (sg[1] - sg[0]) * L
            info["race_length"] = rl
            if not (LENGTH_P2P_RACE[0] <= rl <= LENGTH_P2P_RACE[1]):
                E(f"la parte que se corre mide {rl:.0f} m; tiene que ser {LENGTH_P2P_RACE[0]:.0f}–{LENGTH_P2P_RACE[1]:.0f}")
            if sg[0] != 0:
                W("race.seg: lo normal es largar en el punto A (desde = 0)")
    # --- tramos de superficie (fracciones del lazo, seguidos, de 0 a 1) ---
    secs = d.get("sections")
    if not isinstance(secs, list) or not secs:
        E("sections: falta la lista de tramos (al menos uno que cubra de 0 a 1)")
    else:
        if len(secs) > MAX_SECTIONS:
            E(f"sections: máximo {MAX_SECTIONS} tramos")
        pos = 0.0
        for i, sc2 in enumerate(secs):
            if not isinstance(sc2, dict) or sc2.get("surface") not in SECTION_SURFACES:
                E(f"sections[{i}].surface: uno de {SECTION_SURFACES}")
                continue
            a, b = sc2.get("from"), sc2.get("to")
            if not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
                E(f"sections[{i}]: from/to numéricos (fracciones 0–1)")
                continue
            if abs(a - pos) > 1e-4:
                E(f"sections[{i}]: empieza en {a} pero el tramo anterior terminó en {pos} (tienen que ser seguidos, sin huecos)")
            if b <= a:
                E(f"sections[{i}]: to tiene que ser mayor que from")
            elif (b - a) * L < MIN_SECTION_M:
                E(f"sections[{i}] «{sc2.get('label', sc2['surface'])}»: mide {(b - a) * L:.0f} m; mínimo {MIN_SECTION_M:.0f} m")
            dn = sc2.get("density", sc.get("density", 0.6))
            if not (isinstance(dn, (int, float)) and 0 <= dn <= 1):
                E(f"sections[{i}].density: entre 0 y 1")
            pos = b
        if abs(pos - 1.0) > 1e-3:
            E(f"sections: los tramos terminan en {pos}; tienen que llegar a 1")
    rv = d.get("rivals", {})
    if not (isinstance(rv.get("count"), int) and 0 <= rv["count"] <= 7):
        E("rivals.count: entero de 0 a 7")
    if not (isinstance(rv.get("difficulty"), (int, float)) and 0 <= rv["difficulty"] <= 1):
        E("rivals.difficulty: entre 0 y 1 (0.01 = 1 % … 1 = 100 %)")
    cr = d.get("career")
    if cr is not None:
        if cr.get("tier") not in TIERS:
            E(f"career.tier: uno de {TIERS}")
        if not str(cr.get("event", "")):
            E("career.event: falta el id del evento que reemplaza (por ejemplo c1)")
        if cr.get("sky", "day") not in SKIES:
            E(f"career.sky: uno de {SKIES}")
    return errs, warns, info

def main():
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    e, w, info = validate(d)
    for m in e:
        print("❌", m)
    for m in w:
        print("⚠", m)
    if info:
        print("ℹ", {k: round(v, 1) for k, v in info.items()})
    print("RESULTADO:", "NO sirve todavía" if e else "VÁLIDA")
    sys.exit(1 if e else 0)

if __name__ == "__main__":
    main()
