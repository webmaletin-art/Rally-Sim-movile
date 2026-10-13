#!/usr/bin/env python3
"""Rehace las alturas de las rutas de la región (parche sobre region_1.bin, sin volver a generar el mapa).

Qué arregla: `topo.compute_heights` pegaba cada ruta a la altura del nodo sólo en el ÚLTIMO punto y después limitaba la pendiente; en terreno escarpado quedaban escalones de hasta
18 m a 1 m del cruce (en 242 cruces de 1.421 las rutas llegaban a alturas distintas: el auto saltaba al cruzar) y subidas de más del 30 % pegadas a los nodos.

Cómo lo hace:
 1. Altura de cada nodo = promedio, ponderado por la jerarquía de la ruta, de lo que tiene cada ruta que llega ahí (la autopista manda sobre el camino). Los nodos que están pegados a la ciudad
    (salidas) o adentro de pueblos y ciudades (terreno aplanado) no se mueven.
 2. Se relajan las alturas de los nodos hasta que ninguna ruta necesite más pendiente de la permitida entre sus dos extremos.
 3. Cada ruta sigue el terreno suavizado, se lleva a las alturas de sus nodos con una transición larga (proporcional a la diferencia), se limita la pendiente DENTRO de la franja alcanzable desde
    los dos extremos (así no se rompe en el nodo), y se suaviza (curvas verticales).
 4. En cada nodo hay una PLAZOLETA plana (todas las rutas a la misma altura, el auto no salta) y de ahí sale una rampa suave.
Uso: python3 tools/world_gen/fix_heights.py [--bin ruta.bin] [--out ruta_nueva.bin] [--check]   (sin --out pisa el archivo; --check sólo mide)
"""
import json
import math
import os
import struct
import sys

import numpy as np
from scipy.ndimage import gaussian_filter1d, map_coordinates
from scipy.sparse import csc_matrix, diags
from scipy.sparse.linalg import splu

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import terrain as T  # noqa: E402

STEP = 12.0
CLS_LIST = ["anillo", "autopista", "ruta", "provincial", "camino", "tierra", "montana", "calle", "conector"]
# (ancho, radio mínimo, pendiente máxima) como network.CLS
GRADE = {"anillo": 0.05, "autopista": 0.055, "ruta": 0.07, "provincial": 0.085, "camino": 0.10, "tierra": 0.11, "montana": 0.115, "calle": 0.08, "conector": 0.07}
SIG = {"autopista": 200.0, "anillo": 180.0, "ruta": 150.0, "provincial": 110.0, "camino": 70.0, "montana": 38.0, "tierra": 45.0, "calle": 14.0, "conector": 110.0}
IMPORTANCE = {"anillo": 8.0, "autopista": 8.0, "conector": 6.0, "ruta": 6.0, "provincial": 4.0, "camino": 3.0, "montana": 3.0, "tierra": 2.0, "calle": 1.0}
KIND_LIST = ["dream", "anillo", "ciudad_salida", "ciudad", "pueblo", "villa", "cruce", "calle_fin", "paraje"]
LOCKED_KINDS = {"dream", "ciudad_salida", "ciudad", "pueblo", "villa"}  # pegados a la ciudad o sobre terreno aplanado: no se mueven
USE_GRADE = 0.70  # de la pendiente máxima se usa hasta el 70 % entre nodos (el resto queda para redondear las curvas verticales)


def read_bin(path):
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[8:12])[0]
    meta = json.loads(b[12:12 + jl].decode("utf-8"))
    off = 12 + jl
    W, H = meta["grid"]["w"], meta["grid"]["h"]
    delta = np.frombuffer(b, "<i2", W * H, off).reshape(H, W).astype(np.float64) * 0.1
    off_delta = off
    off += W * H * 2
    ng = W * H
    off_bio = off
    off += ng + ((4 - ng % 4) % 4)
    n = meta["n_pts"]
    off_P = off
    P = np.frombuffer(b, "<i4", n * 2, off).reshape(-1, 2).astype(np.float64) / 10.0
    off += n * 8
    off_H = off
    Hh = np.frombuffer(b, "<f4", n, off).astype(np.float64)
    off += n * 4
    return b, jl, meta, delta, P, Hh, off_H


def terrain_fn(delta):
    def f(x, z):
        x = np.atleast_1d(np.asarray(x, dtype=np.float64))
        z = np.atleast_1d(np.asarray(z, dtype=np.float64))
        c = (x - T.X0) / T.CELL - 0.5
        r = (z - T.Z0) / T.CELL - 0.5
        d = map_coordinates(delta, [r, c], order=1, mode="nearest")
        return T.city_height(x, z) + d
    return f


class Edge:
    pass


def load_edges(meta, P, Hh):
    edges = []
    for i, e in enumerate(meta["edges"]):
        o = Edge()
        o.i = i
        o.a, o.b = int(e[0]), int(e[1])
        o.cls = CLS_LIST[int(e[2])]
        o.name = e[3]
        o.p0, o.n = int(e[6]), int(e[7])
        o.pts = P[o.p0:o.p0 + o.n]
        o.h_old = Hh[o.p0:o.p0 + o.n].copy()
        o.cum = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(o.pts, axis=0), axis=1))]
        o.L = float(o.cum[-1])
        edges.append(o)
    return edges


def ease(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def half_width(meta, ei):
    return float(meta["edges"][ei][4]) * 0.5


def flat_radius(meta, edges):
    """Radio de la plazoleta plana de cada nodo: la mitad de ancho de la ruta más ancha que llega + 6 m."""
    flat = np.zeros(len(meta["nodes"]))
    for o in edges:
        hw = half_width(meta, o.i)
        flat[o.a] = max(flat[o.a], hw + 6.0)
        flat[o.b] = max(flat[o.b], hw + 6.0)
    return flat


def unique_pts(o):
    """Puntos de la ruta sin repetidos (hay puntos repetidos en los nodos): máscara, mapa de vuelta, puntos y distancia acumulada."""
    keep = np.r_[True, np.linalg.norm(np.diff(o.pts, axis=0), axis=1) > 1e-3]
    idx_map = np.cumsum(keep) - 1
    pts = o.pts[keep]
    cl = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    return keep, idx_map, pts, cl


def plateau_counts(cl, flat_a, flat_b, n):
    """Cuántos puntos de cada extremo quedan en la plazoleta plana: los que caen adentro del radio y UNO más (así la altura es pareja de verdad adentro del radio, no sólo en el punto del nodo)."""
    L = float(cl[-1])
    na = int(np.searchsorted(cl, flat_a, side="right")) + 1
    nb = int(np.searchsorted(L - cl[::-1], flat_b, side="right")) + 1
    na = max(1, min(na, n - 1))
    nb = max(1, min(nb, n - na))
    return na, nb


def free_length(o, flat):
    """Largo de la ruta que queda entre las dos plazoletas, contando los puntos reales (a veces el primer punto pasado el radio está lejos del nodo)."""
    _, _, pts, cl = unique_pts(o)
    fa = min(flat[o.a], 0.45 * o.L)
    fb = min(flat[o.b], 0.45 * o.L)
    by_radius = o.L - fa - fb - 2.0 * STEP  # una ruta corta entre dos nodos cercanos (un cruce partido en dos) es toda plazoleta: los dos nodos van a la misma altura
    if len(pts) < 3 or by_radius <= 0.0:
        return 0.0, fa, fb
    na, nb = plateau_counts(cl, fa, fb, len(pts))
    return max(min(float(cl[-1]) - float(cl[na - 1]) - float(cl[-1] - cl[len(cl) - nb]), by_radius + 2.0 * STEP), 0.0), fa, fb


def node_heights(meta, edges, f, smooth, flat):
    nodes = meta["nodes"]
    n = len(nodes)
    H = np.array([float(nd[5]) for nd in nodes])
    locked = np.array([KIND_LIST[int(nd[3])] in LOCKED_KINDS for nd in nodes])
    deg = np.zeros(n, dtype=int)
    for o in edges:
        deg[o.a] += 1
        deg[o.b] += 1
    # 1. objetivo de cada nodo flexible: promedio de lo que ve cada ruta (suavizada) en ese extremo, ponderado por la jerarquía
    num = np.zeros(n)
    den = np.zeros(n)
    for o in edges:
        w = IMPORTANCE[o.cls]
        num[o.a] += w * smooth[o.i][0]
        den[o.a] += w
        num[o.b] += w * smooth[o.i][-1]
        den[o.b] += w
    free = ~locked & (den > 0)
    H[free] = num[free] / den[free]
    imp = np.zeros(n)
    for o in edges:
        imp[o.a] = max(imp[o.a], IMPORTANCE[o.cls])
        imp[o.b] = max(imp[o.b], IMPORTANCE[o.cls])
    # 2. relajación: la diferencia de altura entre los dos extremos de una ruta no pasa de lo que permite su pendiente
    unsolved = 0
    for it in range(600):
        worst = 0.0
        for o in edges:
            lim = USE_GRADE * GRADE[o.cls] * free_length(o, flat)[0]
            d = H[o.b] - H[o.a]
            ex = abs(d) - lim
            if ex <= 1e-3:
                continue
            worst = max(worst, ex)
            sgn = 1.0 if d > 0 else -1.0
            fa, fb = (not locked[o.a]), (not locked[o.b])
            if fa and fb:
                wa, wb = 1.0 / imp[o.a], 1.0 / imp[o.b]
                ta, tb = wa / (wa + wb), wb / (wa + wb)
                H[o.a] += sgn * ex * ta
                H[o.b] -= sgn * ex * tb
            elif fa:
                H[o.a] += sgn * ex
            elif fb:
                H[o.b] -= sgn * ex
            else:
                unsolved += 1
        if worst < 0.02:
            break
    return H, locked, unsolved


def _limit(h, step, g, fixed_lo, fixed_hi, Ha, Hb, passes=3):
    """Limita la pendiente entre puntos vecinos; los primeros `fixed_lo` y últimos `fixed_hi` puntos (la plazoleta) no se tocan."""
    n = len(h)
    for _ in range(passes):
        for i in range(max(1, fixed_lo), n):
            if n - i <= fixed_hi:
                break
            h[i] = min(max(h[i], h[i - 1] - g * step[i - 1]), h[i - 1] + g * step[i - 1])
        for i in range(n - 1 - max(1, fixed_hi), -1, -1):
            if i < fixed_lo:
                break
            h[i] = min(max(h[i], h[i + 1] - g * step[i]), h[i + 1] + g * step[i])
    return h


JERK = {"autopista": 0.02, "anillo": 0.02, "ruta": 0.03, "conector": 0.03, "provincial": 0.04, "camino": 0.045, "tierra": 0.05, "montana": 0.06, "calle": 0.08}  # salto de pendiente máximo entre puntos (curva vertical)


def _round_corners(h, step, g, J, na, nb, Ha, Hb, iters=120):
    """Redondea los quiebres de pendiente más bruscos que J (cumbres y valles hechos con la pendiente máxima): sólo se suaviza donde hace falta, el resto de la ruta queda igual."""
    n = len(h)
    for _ in range(iters):
        sl = np.diff(h) / step
        jk = np.abs(np.diff(sl))
        idx = np.where(jk > J * 1.05)[0] + 1
        if len(idx) == 0:
            break
        bad = np.zeros(n)
        for i in idx:
            bad[max(0, i - 2):i + 3] = 1.0
        w = np.clip(gaussian_filter1d(bad, 1.5) * 1.6, 0.0, 1.0)
        sv = gaussian_filter1d(h, 2.0, mode="nearest")
        h = h * (1.0 - w) + sv * w
        h[:na] = Ha
        h[n - nb:] = Hb
        h = _limit(h, step, g * 1.02, na, nb, Ha, Hb, 1)
    return h


# cuánto puede cambiar la pendiente entre dos tramos seguidos (≈12 m): en la plazoleta de un nodo la ruta pasa de plana a la rampa y ese quiebre se veía como un «doblez» del asfalto
KINK = {"autopista": 0.010, "anillo": 0.010, "ruta": 0.015, "conector": 0.015, "provincial": 0.020, "camino": 0.025, "tierra": 0.025, "montana": 0.030, "calle": 0.040}


def _kink_solve(t, cl, fixed, lam):
    """Mínimos cuadrados con rigidez: min Σ (h − t)² + Σ λ_j (Δpendiente_j)², con los puntos `fixed` (la plazoleta) clavados a su altura. Es un sistema ralo (pentadiagonal)."""
    n = len(t)
    ds = np.diff(cl)
    inv = 1.0 / ds
    # fila j (puntos 1..n-2): Δpendiente = h[j+1]/ds[j] − h[j]·(1/ds[j] + 1/ds[j−1]) + h[j−1]/ds[j−1]
    D = diags([inv[:-1], -(inv[1:] + inv[:-1]), inv[1:]], [0, 1, 2], shape=(n - 2, n)).tocsc()
    A = (diags(np.ones(n)) + D.T @ diags(lam) @ D).tocsc()
    free = np.where(~fixed)[0]
    Aff = A[free][:, free]
    rhs = t[free] - A[free][:, np.where(fixed)[0]] @ t[fixed]
    h = t.copy()
    h[free] = splu(Aff.tocsc()).solve(rhs)
    return h


def smooth_kinks(h0, cl, na, nb, g_cap, J):
    """Redondea los quiebres de pendiente (los que más se ven están donde la plazoleta plana de un nodo se junta con la subida), sin pasarse de la pendiente máxima de la clase.
    A) rigidez local: sube sólo donde el quiebre pasa de J (el resto de la ruta sigue el terreno);
    B) rigidez pareja cada vez mayor (una ruta corta y empinada entre dos nodos necesita una S entera);
    se queda con la mejor que cumpla la pendiente máxima (menor quiebre, y a igual quiebre la que menos se aparta del perfil original)."""
    n = len(h0)
    if n - na - nb < 3 or n < 5:
        return h0
    fixed = np.zeros(n, dtype=bool)
    fixed[:na] = True
    fixed[n - nb:] = True
    ds = np.diff(cl)

    def measure(h):
        return float(np.abs(np.diff(h) / ds).max()), float(np.abs(np.diff(np.diff(h) / ds)).max())

    g0, k0 = measure(h0)
    cands = []
    # A) rigidez local
    lam = np.full(n - 2, 60.0)
    h = h0
    for _it in range(30):
        h = _kink_solve(h0, cl, fixed, lam)
        dg = np.abs(np.diff(np.diff(h) / ds))
        bad = np.where(dg > J)[0]
        if len(bad) == 0:
            break
        for j in bad:
            lam[max(0, j - 3):j + 4] *= 2.5
    cands.append(h)
    # B) rigidez pareja
    for k in range(9):
        cands.append(_kink_solve(h0, cl, fixed, np.full(n - 2, 60.0 * 4.0 ** k)))
    best = None
    best_key = None
    for h in cands:
        gm, km = measure(h)
        if gm > max(g_cap * 1.02, g0 * 1.0):
            continue  # no se pasa de la pendiente máxima (ni de la que ya tenía la ruta si ya se pasaba)
        key = (max(km, J), float(np.sqrt(np.mean((h - h0) ** 2))))  # cumplir J alcanza: de ahí en más, la que menos se aparta
        if best_key is None or key < best_key:
            best, best_key = h, key
    if best is not None and best_key[0] <= J * 1.5:
        return best
    # C) una subida que ya iba a la pendiente máxima apenas sale de la plazoleta no se puede redondear sin quedar por debajo del terreno: se baja el perfil (un corte) con una pendiente que
    #    crece de a poco desde la plazoleta, y se vuelve a la altura del terreno apenas la pendiente máxima deja
    tgt = _envelope(h0, cl, na, nb, g_cap, J)
    for k in range(0, 9, 2):
        h = _kink_solve(tgt, cl, fixed, np.full(n - 2, 60.0 * 4.0 ** k))
        gm, km = measure(h)
        if gm > max(g_cap * 1.02, g0 * 1.0):
            continue
        key = (max(km, J), float(np.sqrt(np.mean((h - h0) ** 2))))
        if best_key is None or key < best_key:
            best, best_key = h, key
    if best is None or best_key[0] >= k0:
        return h0
    return best


def _envelope(h0, cl, na, nb, g_cap, J):
    """Perfil objetivo cuya pendiente nace en 0 en la plazoleta y llega a la máxima de la clase en la distancia que deja el quiebre J (curva vertical); entre los dos extremos fijos recupera el perfil original lo antes posible."""
    n = len(h0)
    ds = np.diff(cl)
    ramp = 12.0 * g_cap / J * 1.2
    mid = 0.5 * (cl[:-1] + cl[1:])
    d_end = np.minimum(mid - cl[na - 1], cl[n - nb] - mid)
    x = np.clip(d_end / ramp, 0.0, 1.0)
    g_env = g_cap * x * x * (3.0 - 2.0 * x)
    h = h0.copy()
    for _ in range(6):
        for i in range(na, n - nb):
            h[i] = min(max(h[i], h[i - 1] - g_env[i - 1] * ds[i - 1]), h[i - 1] + g_env[i - 1] * ds[i - 1])
        for i in range(n - nb - 1, na - 1, -1):
            h[i] = min(max(h[i], h[i + 1] - g_env[i] * ds[i]), h[i + 1] + g_env[i] * ds[i])
    return h


def profile(o, f, Ha, Hb, flat_a, flat_b):
    """Perfil de altura de una ruta: terreno suavizado → hacia las alturas de sus nodos → pendiente limitada dentro de la franja alcanzable → plazoleta plana en cada extremo → curvas verticales."""
    g = GRADE[o.cls]
    # puntos únicos (hay puntos repetidos en los nodos): el perfil se calcula sobre ellos y se copia a los repetidos
    keep, idx_map, pts, cl = unique_pts(o)
    L = float(cl[-1])
    if len(pts) < 3:
        hh = np.array([Ha, Hb])[: len(pts)]
        return hh[idx_map]
    if L - flat_a - flat_b - 2.0 * STEP <= 0.0:
        # ruta corta entre dos nodos cercanos: toda plazoleta (pasa de una altura a la otra de a poco, con las dos casi iguales)
        return (Ha + (Hb - Ha) * (cl / max(L, 1e-6)))[idx_map]
    base = f(pts[:, 0], pts[:, 1])
    sig = SIG.get(o.cls, 100.0) / STEP
    h = gaussian_filter1d(base, sig, mode="nearest")
    d0 = Ha - h[0]
    d1 = Hb - h[-1]
    # transición hacia los nodos: tan larga como haga falta para no pasarse de ~la mitad de la pendiente
    lb0 = max(160.0, 2.5 * abs(d0) / g)
    lb1 = max(160.0, 2.5 * abs(d1) / g)
    h = h + d0 * np.clip(1.0 - cl / lb0, 0.0, 1.0) ** 2 + d1 * np.clip(1.0 - (L - cl) / lb1, 0.0, 1.0) ** 2
    # franja alcanzable desde los dos extremos con la pendiente permitida
    lo = np.maximum(Ha - g * cl, Hb - g * (L - cl))
    hi = np.minimum(Ha + g * cl, Hb + g * (L - cl))
    bad = lo > hi
    if bad.any():  # extremos imposibles de unir (dos nodos fijos muy distintos): se unen en línea recta
        lin = Ha + (Hb - Ha) * (cl / max(L, 1.0))
        lo = np.where(bad, lin, lo)
        hi = np.where(bad, lin, hi)
    h = np.clip(h, lo, hi)
    step = np.maximum(np.diff(cl), 1e-3)
    # puntos de la plazoleta de cada extremo: todos los que caen adentro del radio y UNO más (así la altura es pareja de verdad adentro del radio, no sólo en el punto del nodo)
    na, nb = plateau_counts(cl, flat_a, flat_b, len(h))
    h[:na] = Ha
    h[len(h) - nb:] = Hb
    h = _limit(h, step, g, na, nb, Ha, Hb, 4)
    # curvas verticales: se suaviza de a poco y se vuelve a limitar la pendiente (así los quiebres de la franja se redondean sin pasarse de la pendiente)
    sm = {"autopista": 4.0, "anillo": 4.0, "ruta": 3.0, "conector": 3.0, "provincial": 2.5, "camino": 2.0, "tierra": 2.0, "montana": 2.0, "calle": 1.0}.get(o.cls, 2.0)
    # sólo cerca de los nodos (el resto de la ruta sigue el terreno suavizado como antes): ahí se redondea el paso de la plazoleta plana a la rampa
    near_w = 1.0 - ease((np.minimum(cl, L - cl) - 0.5 * max(flat_a, flat_b) - 8.0) / 60.0)
    for _ in range(12):
        sv = gaussian_filter1d(h, sm, mode="nearest")
        h = h * (1.0 - near_w) + sv * near_w
        h[:na] = Ha
        h[len(h) - nb:] = Hb
        h = _limit(h, step, g * 1.02, na, nb, Ha, Hb, 1)
    h[:na] = Ha
    h[len(h) - nb:] = Hb
    h = _round_corners(h, step, g, JERK.get(o.cls, 0.05), na, nb, Ha, Hb)
    for _ in range(60):  # que la pendiente quede dentro del límite de verdad (con la plazoleta fija)
        before = h.copy()
        h = _limit(h, step, g * 1.02, na, nb, Ha, Hb, 1)
        if np.max(np.abs(h - before)) < 1e-6:
            break
    h = smooth_kinks(h, cl, na, nb, g, KINK.get(o.cls, 0.03))
    return h[idx_map]


def compute(meta, edges, f):
    smooth = {}
    for o in edges:
        base = f(o.pts[:, 0], o.pts[:, 1])
        smooth[o.i] = gaussian_filter1d(base, SIG.get(o.cls, 100.0) / STEP, mode="nearest")
    flat = flat_radius(meta, edges)
    Hn, locked, unsolved = node_heights(meta, edges, f, smooth, flat)
    for o in edges:
        _, fa, fb = free_length(o, flat)
        o.h = profile(o, f, Hn[o.a], Hn[o.b], fa, fb)
    return Hn, locked, unsolved


def report(meta, edges, label, key):
    """Mide: diferencia entre las rutas de un cruce a 8 m del nodo, pendiente máxima por clase y saltos de pendiente."""
    nodes = meta["nodes"]
    inc = {}
    for o in edges:
        inc.setdefault(o.a, []).append((o, True))
        inc.setdefault(o.b, []).append((o, False))
    diffs = []
    for ni, lst in inc.items():
        if len(lst) < 2:
            continue
        hs = []
        for o, at_a in lst:
            d8 = min(8.0, 0.5 * o.L)
            s = d8 if at_a else o.L - d8
            hs.append(float(np.interp(min(max(s, 0), o.L), o.cum, getattr(o, key))))
        diffs.append(max(hs) - min(hs))
    diffs = np.array(diffs)
    print("[%s] cruces: %d · diferencia de altura a 8 m del nodo → máx %.2f m · >5 cm: %d · >20 cm: %d · >50 cm: %d" % (label, len(diffs), diffs.max(), (diffs > 0.05).sum(), (diffs > 0.2).sum(), (diffs > 0.5).sum()))
    worst = {}
    jerk = []
    for o in edges:
        h = getattr(o, key)
        dc = np.diff(o.cum)
        ok = dc > 1e-3  # los puntos repetidos de los nodos no cuentan
        gr = np.abs(np.diff(h))[ok] / dc[ok]
        worst[o.cls] = max(worst.get(o.cls, 0.0), float(gr.max()) if len(gr) else 0.0)
        if len(gr) > 2:
            jerk.append(np.abs(np.diff(np.diff(h)[ok] / dc[ok])).max())
    print("[%s] pendiente máxima por clase: %s" % (label, {k: round(v, 3) for k, v in sorted(worst.items())}))
    print("[%s] salto de pendiente entre puntos (máx %.3f · p99 %.3f)" % (label, np.max(jerk), np.percentile(jerk, 99)))
    return diffs


def patch(path, out=None, check=False):
    """Recalcula las alturas del archivo `path` (el de la región) y lo escribe en `out` (por defecto lo pisa). Se puede correr de nuevo sin problema: da lo mismo."""
    b, jl, meta, delta, P, Hh, off_H = read_bin(path)
    f = terrain_fn(delta)
    edges = load_edges(meta, P, Hh)
    for o in edges:
        o.h = o.h_old.copy()
    report(meta, edges, "antes", "h_old")
    Hn, locked, unsolved = compute(meta, edges, f)
    print("nodos fijos %d de %d · aristas entre dos nodos fijos que no se pueden unir: %d" % (locked.sum(), len(locked), unsolved))
    report(meta, edges, "ahora", "h")
    cut = np.concatenate([np.abs(o.h - f(o.pts[:, 0], o.pts[:, 1])) for o in edges])
    cut_old = np.concatenate([np.abs(o.h_old - f(o.pts[:, 0], o.pts[:, 1])) for o in edges])
    print("corte/relleno contra el terreno: antes p99 %.1f m (máx %.1f) · ahora p99 %.1f m (máx %.1f)" % (np.percentile(cut_old, 99), cut_old.max(), np.percentile(cut, 99), cut.max()))
    if check:
        return
    # escribir: sólo cambian las alturas de los puntos, la de los nodos y la de los servicios
    newH = Hh.copy()
    for o in edges:
        newH[o.p0:o.p0 + o.n] = o.h
    for ni, nd in enumerate(meta["nodes"]):
        nd[5] = round(float(Hn[ni]), 2)
    from scipy.spatial import cKDTree
    tree = cKDTree(P)
    for poi in meta["pois"]:
        d, k = tree.query([poi["x"], poi["z"]])
        poi["h"] = round(float(newH[k]), 2)
    meta["heights"] = "v2"
    js = json.dumps(meta, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = bytearray(b[12 + jl:])
    n = meta["n_pts"]
    off_in_rest = (off_H - (12 + jl))  # la altura va después de delta, bioma y puntos
    rest[off_in_rest:off_in_rest + n * 4] = newH.astype("<f4").tobytes()
    new = b[:8] + struct.pack("<I", len(js)) + js + bytes(rest)
    dest = out or path
    open(dest, "wb").write(new)
    print("escrito", dest, len(new), "bytes")


def main():
    path = os.path.join(HERE, "..", "..", "godot", "game", "data", "region", "region_1.bin")
    out = None
    check = False
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == "--bin":
            path = a[i + 1]
            i += 2
        elif a[i] == "--out":
            out = a[i + 1]
            i += 2
        elif a[i] == "--check":
            check = True
            i += 1
        else:
            i += 1
    patch(path, out, check)


if __name__ == "__main__":
    main()
