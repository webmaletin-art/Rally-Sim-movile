#!/usr/bin/env python3
"""Reglas y validador del formato «dreamracing-route» v3 (editor de trazados en grilla: el camino se dibuja a mano, puede cruzarse a nivel consigo mismo,
y el juego pone árboles, vegetación y borde del camino). route_spec.validate() manda acá los archivos con "version": 3.
Las mismas reglas están en FORMATO_V3.md y en PROMPT_EDITOR_V3.md: si se cambia un número acá, cambiarlo ahí.
Uso: python3 route_spec3.py archivo.json   → imprime errores (❌) y avisos (⚠) y sale con 1 si hay errores."""
import json, math, re, sys

FORMAT = "dreamracing-route"
VERSION = 3
TYPES = ("circuit", "point_to_point")
SURFACES = ("asphalt", "dirt", "gravel", "mud", "sand")
TREE_KINDS = ("none", "pine", "broadleaf", "mixed")
EDGES = ("auto", "guardrail", "wood", "fence")
SKIES = ("day", "overcast", "sunset", "dusk", "rain")
STYLES = ("race", "timetrial", "adventure", "chase", "elimination")
SLOPE_MODES = ("free", "descent", "ascent")
MAX_DEG = 6.9                    # 12 % de pendiente = 6,84°
TIERS = ("debut", "nacional", "continental", "leyenda", "camiones")

MAX_POINTS = 3000
MIN_POINTS = {"circuit": 8, "point_to_point": 4}
SPACING = (30.0, 300.0)          # entre puntos de control consecutivos (el editor resamplea el trazo solo)
MAX_COORD = 20000.0
Y_RANGE = (0.0, 600.0)
HALF_WIDTH = (3.0, 5.6)
SHOULDER = (1.6, 2.6)
MIN_RADIUS = {"asphalt": 22.0, "other": 18.0}
MAX_SLOPE = 0.12                 # pendiente máxima promediada en 20 m
MIN_LENGTH = {"circuit": 1000.0, "point_to_point": 800.0}   # circuito: el lazo · A→B: lo que se corre
WARN_LENGTH = 15000.0
MAX_SECTIONS = 200
MIN_SECTION_M = 60.0
CROSS_FAR = 160.0                # recorrido mínimo entre dos partes para que sea un cruce y no la misma curva
CROSS_ANGLE = 35.0               # un cruce necesita al menos este ángulo entre los dos caminos (menos = se pisan en paralelo)
CROSS_DY_ERR = 8.0               # diferencia de altura en un cruce: el juego los iguala; más que esto no se puede
CROSS_DY_WARN = 2.0
START_STRAIGHT = 150.0
RUNOUT = 200.0                   # lo que sigue el camino antes de A y pasando B (lo agrega el juego)

def catmull(points, per_seg=24):
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

def open_ctrl(pts):
    """Igual que MapData.open_ctrl del juego: A→B (camino ABIERTO) lleva dos puntos «fantasma» antes de A y dos después de B. Devuelve la lista de puntos de control;
    A es el índice 2 y B el índice len(pts)+1. El juego sólo muestrea de A − 200 m a B + 200 m (puntos 1 y len−2)."""
    n = len(pts)
    a, a2, b, b2 = pts[0], pts[1], pts[n - 1], pts[n - 2]
    def unit(dx, dz):
        l = math.hypot(dx, dz) or 1.0
        return dx / l, dz / l
    la = math.hypot(a2[0] - a[0], a2[2] - a[2])
    lb = math.hypot(b[0] - b2[0], b[2] - b2[2])
    sa = max(-0.12, min(0.12, (a2[1] - a[1]) / max(la, 1.0)))
    sb = max(-0.12, min(0.12, (b[1] - b2[1]) / max(lb, 1.0)))
    ta = unit(a2[0] - a[0], a2[2] - a[2])
    tb = unit(b[0] - b2[0], b[2] - b2[2])
    out = [[a[0] - ta[0] * 2 * RUNOUT, a[1] - sa * 2 * RUNOUT, a[2] - ta[1] * 2 * RUNOUT],
           [a[0] - ta[0] * RUNOUT, a[1] - sa * RUNOUT, a[2] - ta[1] * RUNOUT]]
    out += [list(p) for p in pts]
    out += [[b[0] + tb[0] * RUNOUT, b[1] + sb * RUNOUT, b[2] + tb[1] * RUNOUT],
            [b[0] + tb[0] * 2 * RUNOUT, b[1] + sb * 2 * RUNOUT, b[2] + tb[1] * 2 * RUNOUT]]
    return out

def _metrics(s, cum, closed):
    n = len(s)
    length = cum[-1] if closed else cum[n - 1]
    step = max(1, int(round(10.0 / (length / n))))
    radii = []
    for i in range(n):
        ia, ic = (i - step) % n, (i + step) % n
        if not closed:
            ia, ic = max(0, i - step), min(n - 1, i + step)
        a, b, c = s[ia], s[i], s[ic]
        ab, bc, ca = math.hypot(a[0] - b[0], a[2] - b[2]), math.hypot(b[0] - c[0], b[2] - c[2]), math.hypot(c[0] - a[0], c[2] - a[2])
        area2 = abs((b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0]))
        radii.append((ab * bc * ca) / area2 if area2 > 1e-6 else 1e9)
    win = max(1, int(round(20.0 / (length / n))))
    slopes = []
    for i in range(n):
        j = i + win
        if closed:
            ds = (cum[i + win] - cum[i]) if i + win <= n else (length - cum[i] + cum[(i + win) - n])
            j %= n
        else:
            j = min(j, n - 1)
            ds = cum[j] - cum[i]
        slopes.append(abs(s[j][1] - s[i][1]) / ds if ds > 1e-6 else 0.0)
    return radii, slopes

def analyze_open(ctrl):
    """Camino abierto: sólo la parte que muestrea el juego (de A − 200 m a B + 200 m). ctrl_idx[k] = índice de muestra (dentro de esa parte) del punto de control k."""
    s_all, idx = catmull(ctrl)
    m = len(ctrl)
    i0, i1 = idx[1], idx[m - 2]
    s = s_all[i0:i1 + 1]
    n = len(s)
    cum = [0.0]
    for i in range(1, n):
        cum.append(cum[-1] + math.dist(s[i], s[i - 1]))
    radii, slopes = _metrics(s, cum, False)
    return {"samples": s, "cum": cum, "length": cum[-1], "radii": radii, "slopes": slopes, "ctrl_idx": [k - i0 for k in idx], "open": True}

def analyze(points):
    s, idx = catmull(points)
    n = len(s)
    cum = [0.0]
    for i in range(1, n + 1):
        cum.append(cum[-1] + math.dist(s[i % n], s[i - 1]))
    radii, slopes = _metrics(s, cum, True)
    return {"samples": s, "cum": cum, "length": cum[-1], "radii": radii, "slopes": slopes, "ctrl_idx": idx, "open": False}

def crossings(an, hw, sh):
    """Cruces del lazo: lista de {i, j, angle, dy} (una por grupo de muestras). También devuelve el conjunto de muestras marcadas (zona de cruce) y los pares 'paralelos' (error)."""
    s, cum, L = an["samples"], an["cum"], an["length"]
    n = len(s)
    r = 2.0 * (hw + sh) + 3.0
    cell = 32.0
    if an.get("open"):
        L = cum[-1]
    grid = {}
    for i, p in enumerate(s):
        grid.setdefault((int(p[0] // cell), int(p[2] // cell)), []).append(i)
    marked = set()
    pairs = []
    for i in range(n):
        p = s[i]
        kx, kz = int(p[0] // cell), int(p[2] // cell)
        best, bj = r * r, -1
        for gx in range(kx - 1, kx + 2):
            for gz in range(kz - 1, kz + 2):
                for j in grid.get((gx, gz), ()):
                    arc = abs(cum[j] - cum[i])
                    if not an.get("open"):
                        arc = min(arc, L - arc)
                    if arc <= CROSS_FAR:
                        continue
                    q = s[j]
                    d2 = (q[0] - p[0]) ** 2 + (q[2] - p[2]) ** 2
                    if d2 < best:
                        best, bj = d2, j
        if bj >= 0:
            marked.add(i)
            pairs.append((i, bj))
    pair_of = dict(pairs)
    groups, parallel = [], []
    seen = set()
    for i, _j in pairs:
        if i in seen:
            continue
        k = i
        run = [i]
        while (k + 1) % n in marked and (k + 1) % n not in seen and len(run) < n:
            k = (k + 1) % n
            run.append(k)
        seen.update(run)
        c = run[len(run) // 2]
        cj = pair_of[c]
        # la otra mitad del mismo cruce (el otro camino) no cuenta como un cruce más
        for q in range(-len(run) - 4, len(run) + 5):
            seen.add((cj + q) % n)
        ti = (s[(c + 1) % n][0] - s[c - 1][0], s[(c + 1) % n][2] - s[c - 1][2])
        tj = (s[(cj + 1) % n][0] - s[cj - 1][0], s[(cj + 1) % n][2] - s[cj - 1][2])
        li, lj = math.hypot(*ti) or 1.0, math.hypot(*tj) or 1.0
        cosang = abs((ti[0] * tj[0] + ti[1] * tj[1]) / (li * lj))
        ang = math.degrees(math.acos(min(1.0, cosang)))
        info = {"i": c, "j": cj, "angle": ang, "dy": abs(s[c][1] - s[cj][1]), "x": s[c][0], "z": s[c][2], "len": len(run) * L / n}
        groups.append(info)
        if ang < CROSS_ANGLE:
            parallel.append(info)
    return groups, marked, parallel

def groups_n_ok(an, hw, sh):
    """True si el camino tiene algún cruce."""
    return len(crossings(an, hw, sh)[0]) > 0

def validate(d):
    errs, warns, info = [], [], {}
    E, W = errs.append, warns.append
    if d.get("format") != FORMAT or d.get("version") != VERSION:
        E(f"format/version: tiene que ser «{FORMAT}» y {VERSION}")
        return errs, warns, info
    rid = str(d.get("id", ""))
    if not re.fullmatch(r"[a-z0-9_]{3,24}", rid):
        E("id: sólo minúsculas, números y _ (3 a 24 caracteres)")
    if not str(d.get("name", "")).strip():
        E("name: falta el nombre")
    t = d.get("type")
    if t not in TYPES:
        E(f"type: uno de {TYPES}")
        return errs, warns, info
    r = d.get("route", {}) or {}
    pts = r.get("points", [])
    if not isinstance(pts, list) or not (MIN_POINTS[t] <= len(pts) <= MAX_POINTS):
        E(f"route.points: entre {MIN_POINTS[t]} y {MAX_POINTS} puntos (tiene {len(pts) if isinstance(pts, list) else '?'})")
        return errs, warns, info
    for i, p in enumerate(pts):
        if not (isinstance(p, list) and len(p) == 3 and all(isinstance(v, (int, float)) and math.isfinite(v) for v in p)):
            E(f"route.points[{i}]: tiene que ser [x, y, z] con números")
            return errs, warns, info
    hw, sh = r.get("halfWidth", 0), r.get("shoulder", 0)
    if not (HALF_WIDTH[0] <= hw <= HALF_WIDTH[1]):
        E(f"route.halfWidth: {HALF_WIDTH[0]}–{HALF_WIDTH[1]} m (tiene {hw})")
    if not (SHOULDER[0] <= sh <= SHOULDER[1]):
        E(f"route.shoulder: {SHOULDER[0]}–{SHOULDER[1]} m (tiene {sh})")
    last = len(pts) if t == "circuit" else len(pts) - 1
    for i in range(last):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        if abs(p[0]) > MAX_COORD or abs(p[2]) > MAX_COORD:
            E(f"route.points[{i}]: x y z tienen que estar entre ±{MAX_COORD:.0f} m")
        if not (Y_RANGE[0] <= p[1] <= Y_RANGE[1]):
            E(f"route.points[{i}]: la altura y tiene que estar entre {Y_RANGE[0]:.0f} y {Y_RANGE[1]:.0f} m")
        dd = math.dist(p, q)
        if not (SPACING[0] <= dd <= SPACING[1]):
            E(f"route.points[{i}]→[{(i + 1) % len(pts)}]: {dd:.0f} m entre puntos; tiene que ser {SPACING[0]:.0f}–{SPACING[1]:.0f}")
    if errs:
        return errs, warns, info
    secs = d.get("sections")
    surfs = set()
    if not isinstance(secs, list) or not secs:
        E("sections: falta la lista de tramos (al menos uno que cubra de 0 a 1)")
        secs = []
    # largo de A→B (o del lazo)
    nb = len(pts)
    if t == "circuit":
        an = analyze([list(p) for p in pts])
        a_i, b_i = 0, 0
    else:
        an = analyze_open(open_ctrl(pts))
        a_i, b_i = an["ctrl_idx"][2], an["ctrl_idx"][nb + 1]
    L = an["length"]
    s, cum = an["samples"], an["cum"]
    n = len(s)
    ctrl_idx = an["ctrl_idx"]
    race_len = L if t == "circuit" else cum[b_i] - cum[a_i]
    info = {"length": L, "race_length": race_len}
    # tramos de superficie: fracciones 0–1 del circuito (o de A→B)
    pos = 0.0
    if len(secs) > MAX_SECTIONS:
        E(f"sections: máximo {MAX_SECTIONS} tramos")
    for i, sc2 in enumerate(secs):
        if not isinstance(sc2, dict) or sc2.get("surface") not in SURFACES:
            E(f"sections[{i}].surface: uno de {SURFACES}")
            continue
        surfs.add(sc2["surface"])
        a, b = sc2.get("from"), sc2.get("to")
        if not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
            E(f"sections[{i}]: from/to numéricos (fracciones 0–1)")
            continue
        if abs(a - pos) > 1e-4:
            E(f"sections[{i}]: empieza en {a} pero el tramo anterior terminó en {pos} (tienen que ser seguidos, sin huecos)")
        if b <= a:
            E(f"sections[{i}]: to tiene que ser mayor que from")
        elif (b - a) * race_len < MIN_SECTION_M:
            E(f"sections[{i}] «{sc2.get('label', sc2['surface'])}»: mide {(b - a) * race_len:.0f} m; mínimo {MIN_SECTION_M:.0f} m")
        dn = sc2.get("density", 0.6)
        if not (isinstance(dn, (int, float)) and 0 <= dn <= 1):
            E(f"sections[{i}].density: entre 0 y 1")
        pos = b
    if secs and abs(pos - 1.0) > 1e-3:
        E(f"sections: los tramos terminan en {pos}; tienen que llegar a 1")
    # largo
    if race_len < MIN_LENGTH[t]:
        E(f"{'el circuito' if t == 'circuit' else 'el recorrido A→B'} mide {race_len:.0f} m; mínimo {MIN_LENGTH[t]:.0f}")
    if race_len > WARN_LENGTH:
        W(f"mapa largo ({race_len / 1000:.1f} km): carga más lenta en los teléfonos flojos")
    # curvas y pendientes
    rmin = MIN_RADIUS["asphalt"] if surfs <= {"asphalt"} else MIN_RADIUS["other"]
    bad_r = [i for i in range(n) if an["radii"][i] < rmin]
    info["min_radius"] = min(an["radii"])
    if bad_r:
        i = bad_r[0]
        where = f"cerca del punto de control {max(0, min(range(len(ctrl_idx)), key=lambda k: abs(ctrl_idx[k] - i)) - (2 if t == 'point_to_point' else 0))}"
        E(f"curva demasiado cerrada: radio {min(an['radii']):.1f} m {where}; mínimo {rmin:.0f} m")
    slopes = an["slopes"]
    info["max_slope"] = max(slopes)
    if t == "point_to_point":
        info["drop_m"] = s[a_i][1] - s[b_i][1] # desnivel de A a B (positivo = bajada)
        info["avg_deg"] = math.degrees(math.atan(abs(s[a_i][1] - s[b_i][1]) / max(race_len, 1.0)))
    if max(slopes) > MAX_SLOPE:
        i = slopes.index(max(slopes))
        E(f"pendiente de {max(slopes) * 100:.1f} % ({math.degrees(math.atan(max(slopes))):.1f}°) cerca del punto de control {max(0, min(range(len(ctrl_idx)), key=lambda k: abs(ctrl_idx[k] - i)) - (2 if t == 'point_to_point' else 0))} (máximo {MAX_SLOPE * 100:.0f} % = {math.degrees(math.atan(MAX_SLOPE)):.1f}°)")
    sl = d.get("slope")
    if sl is not None:
        if not isinstance(sl, dict) or sl.get("mode") not in SLOPE_MODES:
            E(f"slope.mode: uno de {SLOPE_MODES}")
        else:
            dg = sl.get("deg", 0)
            if not isinstance(dg, (int, float)) or not (0 <= dg <= MAX_DEG):
                E(f"slope.deg: entre 0 y {MAX_DEG:.1f} grados")
            if sl["mode"] != "free" and t != "point_to_point":
                E("slope: el descenso / ascenso continuo sólo vale para un recorrido A→B (un circuito cerrado vuelve a la misma altura)")
            if sl["mode"] != "free" and groups_n_ok(an, hw, sh):
                E("slope: con descenso o ascenso continuo el camino no puede cruzarse (en el cruce las dos pasadas tendrían alturas distintas)")
    # cruces
    groups, marked, parallel = crossings(an, hw, sh)
    info["crossings"] = len(groups)
    for g in parallel:
        E(f"dos partes del camino se pisan casi en paralelo ({g['angle']:.0f}°) cerca de {g['x']:.0f},{g['z']:.0f}; un cruce necesita al menos {CROSS_ANGLE:.0f}° (alejalas o cruzalas de frente)")
    for g in groups:
        if g["angle"] >= CROSS_ANGLE:
            if g["dy"] > CROSS_DY_ERR:
                E(f"cruce en {g['x']:.0f},{g['z']:.0f}: los dos caminos tienen {g['dy']:.1f} m de diferencia de altura; en un cruce a nivel tienen que estar a la misma (máximo {CROSS_DY_ERR:.0f} m, el editor los iguala)")
            elif g["dy"] > CROSS_DY_WARN:
                W(f"cruce en {g['x']:.0f},{g['z']:.0f}: {g['dy']:.1f} m de diferencia de altura; el juego los iguala suavemente")
    # largada (A): casi recta y fuera de un cruce; meta (B): fuera de un cruce
    sa = int(round(START_STRAIGHT / (L / n)))
    if t == "circuit":
        in_start = any(i in marked for i in range(0, sa)) or any(i in marked for i in range(n - sa // 3, n))
    else:
        in_start = any(i in marked for i in range(max(0, a_i - int(60 / (L / n))), min(n, a_i + sa)))
    if in_start:
        E("el punto A (largada) no puede estar en un cruce ni a menos de 150 m de uno")
    if t == "point_to_point":
        if any(0 <= b_i + k < n and (b_i + k) in marked for k in range(-int(100 / (L / n)), int(100 / (L / n)))):
            E("el punto B (meta) no puede estar en un cruce ni a menos de 100 m de uno")
    r_start = min(an["radii"][i] for i in range(a_i, min(n, a_i + sa)))
    if r_start < 90.0:
        E(f"los primeros {START_STRAIGHT:.0f} m desde el punto A tienen que ser casi rectos (radio ≥ 90 m; tiene {r_start:.0f})")
    # escenografía, decoración, clima
    sc = d.get("scenery", {}) or {}
    if sc.get("trees", "mixed") not in TREE_KINDS:
        E(f"scenery.trees: uno de {TREE_KINDS}")
    dens = sc.get("density", 0.6)
    if not isinstance(dens, (int, float)) or not (0 <= dens <= 1):
        E("scenery.density: entre 0 y 1")
    dec = d.get("decor", {}) or {}
    if dec.get("edge", "auto") not in EDGES:
        E(f"decor.edge: uno de {EDGES}")
    vg = dec.get("vegetation", 1.0)
    if not isinstance(vg, (int, float)) or not (0 <= vg <= 1):
        E("decor.vegetation: entre 0 y 1")
    wth = d.get("weather", {}) or {}
    if wth.get("sky", "day") not in SKIES:
        E(f"weather.sky: uno de {SKIES}")
    # carrera
    race = d.get("race", {}) or {}
    style = race.get("style", "race")
    if style not in STYLES:
        E(f"race.style: uno de {STYLES}")
    if t == "circuit":
        lp = race.get("laps", 2)
        if not isinstance(lp, int) or not (1 <= lp <= 5):
            E("race.laps: entero entre 1 y 5")
    if style == "chase":
        g = (race.get("chase") or {}).get("maxGapM", 150)
        if not isinstance(g, (int, float)) or not (60 <= g <= 1000):
            E("race.chase.maxGapM: entre 60 y 1000 metros")
    if style == "elimination":
        e = (race.get("elimination") or {}).get("everySec", 30)
        if not isinstance(e, (int, float)) or not (15 <= e <= 120):
            E("race.elimination.everySec: entre 15 y 120 segundos")
    rv = d.get("rivals", {}) or {}
    if not (isinstance(rv.get("count"), int) and 0 <= rv["count"] <= 7):
        E("rivals.count: entero de 0 a 7")
    if not (isinstance(rv.get("difficulty"), (int, float)) and 0 <= rv["difficulty"] <= 1):
        E("rivals.difficulty: entre 0 y 1 (0.01 = 1 % … 1 = 100 %)")
    if style == "chase" and rv.get("count") != 1:
        W("persecución: se corre contra UN rival (el juego usa 1 aunque pongas otro número)")
    if style == "elimination" and isinstance(rv.get("count"), int) and rv["count"] < 3:
        W("eliminación: con menos de 3 rivales dura muy poco (el juego pide 3, 5 o 7)")
    if d.get("reverse") and t != "circuit":
        E("reverse: sólo los circuitos tienen versión inversa")
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
