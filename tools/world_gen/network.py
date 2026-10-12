"""Red de rutas de la región de Dream City: ciudades, pueblos y villas unidos por autopistas, rutas, caminos de ruta, de tierra y de montaña.
Todo determinista (semilla fija). Pasos: terreno → lugares → esqueleto (Delaunay) → trazado por A* con pendiente máxima → curvas con radio mínimo →
cruces → pueblos sobre las rutas → perfil de alturas → servicios, peajes, carteles → archivo."""
import heapq
import math
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
from scipy.spatial import Delaunay
import terrain as T
import names as NM

STEP = 12.0  # separación de los puntos de una ruta (m)

# clase de camino: (ancho de calzada m, radio mínimo de curva m, pendiente máxima, velocidad de diseño km/h)
CLS = {
    "anillo": (18.0, 700.0, 0.05, 130),
    "autopista": (16.0, 600.0, 0.055, 130),
    "ruta": (9.5, 280.0, 0.07, 110),
    "provincial": (8.5, 170.0, 0.085, 95),
    "camino": (7.0, 70.0, 0.10, 75),
    "tierra": (6.0, 45.0, 0.11, 60),
    "montana": (7.0, 22.0, 0.115, 55),
    "calle": (7.0, 12.0, 0.08, 40),
    "conector": (9.5, 120.0, 0.07, 80),
}
SURF_ASPH, SURF_DIRT, SURF_GRAVEL = 0, 1, 2


class Grid:
    def __init__(self, Hm):
        self.H = Hm
        self.hs = gaussian_filter(Hm, 1.0)

    def idx(self, x, z):
        return (x - T.X0) / T.CELL - 0.5, (z - T.Z0) / T.CELL - 0.5

    def h(self, x, z, smooth=False):
        c, r = self.idx(np.asarray(x, dtype=np.float64), np.asarray(z, dtype=np.float64))
        return map_coordinates(self.hs if smooth else self.H, [np.atleast_1d(r), np.atleast_1d(c)], order=1, mode="nearest")


def dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2


# ───────────────────────── A* sobre la grilla ─────────────────────────
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1), (2, 1), (2, -1), (-2, 1), (-2, -1), (1, 2), (1, -2), (-1, 2), (-1, -2)]
DD = [math.hypot(a, b) * T.CELL for a, b in DIRS]


def astar(grid, start, goal, gmax, penalty=None, pad_cells=130, slope_w=14.0, g0=0.015):
    """Camino de menor costo entre dos puntos (x, z) sin pasar de la pendiente `gmax` ni entrar al mar. penalty: grilla (>=1) que encarece zonas (cerca de otras rutas)."""
    hs = grid.hs
    sc, sr = grid.idx(*start)
    gc, gr = grid.idx(*goal)
    sc, sr, gc, gr = int(round(sc)), int(round(sr)), int(round(gc)), int(round(gr))
    c0 = max(0, min(sc, gc) - pad_cells)
    c1 = min(T.W - 1, max(sc, gc) + pad_cells)
    r0 = max(0, min(sr, gr) - pad_cells)
    r1 = min(T.H - 1, max(sr, gr) + pad_cells)
    w = c1 - c0 + 1
    sub_h = hs[r0:r1 + 1, c0:c1 + 1]
    zz = T.Z0 + (np.arange(r0, r1 + 1) + 0.5) * T.CELL
    sea = (sub_h < 0.3) & (zz[:, None] > 900.0)
    pen = penalty[r0:r1 + 1, c0:c1 + 1] if penalty is not None else None
    n = sub_h.shape[0] * w
    g = np.full(n, np.inf, dtype=np.float64)
    prev = np.full(n, -1, dtype=np.int64)
    s = (sr - r0) * w + (sc - c0)
    t = (gr - r0) * w + (gc - c0)
    g[s] = 0.0
    hflat = sub_h.ravel()
    seaf = sea.ravel()
    penf = pen.ravel() if pen is not None else None
    pq = [(math.hypot(sc - gc, sr - gr) * T.CELL, s)]
    H_ = sub_h.shape[0]
    while pq:
        f, u = heapq.heappop(pq)
        if u == t:
            break
        gu = g[u]
        if f - 0.0 > gu + math.hypot((u % w) - (t % w), (u // w) - (t // w)) * T.CELL + 1e-6:
            continue
        ur, uc = divmod(u, w)
        hu = hflat[u]
        for k in range(16):
            dc, dr = DIRS[k]
            vr = ur + dr
            vc = uc + dc
            if vr < 0 or vr >= H_ or vc < 0 or vc >= w:
                continue
            v = vr * w + vc
            if seaf[v]:
                continue
            d = DD[k]
            gr_ = abs(hflat[v] - hu) / d
            if gr_ > gmax:
                continue
            cost = d * (1.0 + slope_w * (max(0.0, gr_ - g0) / gmax) ** 2)
            if penf is not None:
                cost *= penf[v]
            ng = gu + cost
            if ng < g[v]:
                g[v] = ng
                prev[v] = u
                heapq.heappush(pq, (ng + math.hypot(vc - (t % w), vr - (t // w)) * T.CELL, v))
    if not np.isfinite(g[t]):
        return None
    path = []
    cur = t
    while cur >= 0:
        r, c = divmod(cur, w)
        path.append((T.X0 + (c0 + c + 0.5) * T.CELL, T.Z0 + (r0 + r + 0.5) * T.CELL))
        cur = prev[cur]
    path.reverse()
    path[0] = tuple(start)
    path[-1] = tuple(goal)
    return path


# ───────────────────────── curvas ─────────────────────────
def pull_strings(grid, pts, gmax, tol=1.12):
    """Atajos en línea recta entre puntos lejanos del camino si la pendiente se sostiene (largas rectas en la llanura)."""
    out = [pts[0]]
    i = 0
    n = len(pts)
    while i < n - 1:
        best = i + 1
        for j in range(n - 1, i, -1):
            a, b = np.array(pts[i]), np.array(pts[j])
            L = np.linalg.norm(b - a)
            if L < 1.0:
                continue
            m = max(2, int(L / 60.0))
            xs = np.linspace(a[0], b[0], m + 1)
            zs = np.linspace(a[1], b[1], m + 1)
            hh = grid.h(xs, zs, smooth=True)
            sea = np.any((hh < 0.3) & (zs > 900.0))
            if sea:
                continue
            gg = np.abs(np.diff(hh)) / (L / m)
            if gg.max() > gmax * 0.92:
                continue
            # no se aparta mucho del camino original
            seg = pts[i:j + 1]
            L0 = sum(math.dist(seg[k], seg[k + 1]) for k in range(len(seg) - 1))
            if L > L0 * 1.001 + 1.0:
                continue
            if L0 > L * tol + 200.0:
                # el camino original rodeaba algo: hay que ver que la recta no corte una zona prohibida (ya lo comprobó la pendiente)
                pass
            best = j
            break
        out.append(pts[best])
        i = best
    return out


# carácter del trazado: (fracción lateral de cada tramo, largo mínimo, largo máximo, chance de que un tramo quede recto)
CARACTER = {"recto": (0.0, 0, 0, 1.0), "suave": (0.085, 1100.0, 2300.0, 0.15), "curva": (0.14, 600.0, 1400.0, 0.1), "sinuosa": (0.24, 320.0, 850.0, 0.04)}
CARACTER_PESOS = {
    "anillo": (("suave", 1.0),),
    "autopista": (("recto", 0.12), ("suave", 0.58), ("curva", 0.3)),
    "conector": (("suave", 0.6), ("curva", 0.4)),
    "ruta": (("recto", 0.06), ("suave", 0.34), ("curva", 0.45), ("sinuosa", 0.15)),
    "provincial": (("recto", 0.04), ("suave", 0.12), ("curva", 0.44), ("sinuosa", 0.4)),
    "camino": (("recto", 0.03), ("curva", 0.37), ("sinuosa", 0.6)),
    "tierra": (("curva", 0.4), ("sinuosa", 0.6)),
    "montana": (("curva", 0.35), ("sinuosa", 0.65)),
}


def meander(grid, poly, cls, rng, gmax):
    """Rompe las rectas largas: agrega puntos de paso corridos a los costados (curvas anchas en las autopistas, eses en los caminos chicos).
    Cada punto nuevo se acepta sólo si la pendiente aguanta y no toca el mar; el redondeo con radio mínimo lo hace después `fillet`."""
    pesos = CARACTER_PESOS.get(cls, (("curva", 1.0),))
    r = rng.rand() * sum(w for _, w in pesos)
    nombre = pesos[-1][0]
    for n_, w in pesos:
        if r < w:
            nombre = n_
            break
        r -= w
    frac, lmin, lmax, p_recto = CARACTER[nombre]
    if frac <= 0.0:
        return poly, nombre
    out = [np.array(poly[0], dtype=np.float64)]
    sign = 1.0 if rng.rand() < 0.5 else -1.0
    for k in range(len(poly) - 1):
        a = np.array(poly[k], dtype=np.float64)
        b = np.array(poly[k + 1], dtype=np.float64)
        L = float(np.linalg.norm(b - a))
        if L < lmin * 1.6 or rng.rand() < p_recto:
            out.append(b)
            continue
        d = (b - a) / L
        nrm = np.array([-d[1], d[0]])
        s = rng.uniform(lmin, lmax) * 0.6  # el primer punto no pega en el extremo
        while s < L - lmin * 0.6:
            piece = rng.uniform(lmin, lmax)
            amp = piece * frac * rng.uniform(0.6, 1.25)
            if rng.rand() < 0.65:
                sign = -sign
            if min(s, L - s) < lmin:  # cerca de los extremos (cruces): menos desvío
                amp *= 0.4
            prev = out[-1]
            for tr in range(4):
                q = a + d * s + nrm * sign * amp
                m = max(2, int(np.linalg.norm(q - prev) / 60.0))
                xs = np.linspace(prev[0], q[0], m + 1)
                zs = np.linspace(prev[1], q[1], m + 1)
                hh = grid.h(xs, zs, smooth=True)
                gg = np.abs(np.diff(hh)) / (np.linalg.norm(q - prev) / m)
                if not (np.any((hh < 0.3) & (zs > 900.0)) or gg.max() > gmax * 0.92):
                    out.append(q)
                    break
                amp *= 0.5
            s += piece
        out.append(b)
    return out, nombre


def fillet(pts, rmin):
    """Redondea las esquinas de una poligonal con arcos de radio ≥ rmin (si los tramos son cortos el radio baja). Devuelve puntos cada STEP."""
    P = [np.array(p, dtype=np.float64) for p in pts]
    if len(P) < 3:
        return resample(P)
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        u = b - a
        v = c - b
        lu, lv = np.linalg.norm(u), np.linalg.norm(v)
        if lu < 1e-6 or lv < 1e-6:
            continue
        u = u / lu
        v = v / lv
        ang = math.acos(float(np.clip(np.dot(u, v), -1, 1)))  # giro
        if ang < 0.005:
            out.append(b)
            continue
        t = min(rmin * math.tan(ang / 2.0), 0.5 * lu, 0.5 * lv)
        r = t / math.tan(ang / 2.0)
        p1 = b - u * t
        sgn = 1.0 if (u[0] * v[1] - u[1] * v[0]) > 0 else -1.0
        center = p1 + np.array([-u[1], u[0]]) * sgn * r
        a1 = math.atan2(p1[1] - center[1], p1[0] - center[0])
        steps = max(2, int(r * ang / STEP) + 1)
        for k in range(steps + 1):
            aa = a1 + sgn * ang * k / steps
            out.append(center + r * np.array([math.cos(aa), math.sin(aa)]))
    out.append(P[-1])
    return resample(out)


def resample(P, step=STEP):
    P = [np.array(p, dtype=np.float64) for p in P]
    cum = [0.0]
    for i in range(1, len(P)):
        cum.append(cum[-1] + np.linalg.norm(P[i] - P[i - 1]))
    L = cum[-1]
    if L < 1e-6:
        return np.array([P[0], P[-1]])
    n = max(1, int(round(L / step)))
    s = np.linspace(0, L, n + 1)
    arr = np.array(P)
    xs = np.interp(s, cum, arr[:, 0])
    zs = np.interp(s, cum, arr[:, 1])
    return np.stack([xs, zs], axis=1)


def smooth_poly(pts, sigma_m, fix_ends=True):
    """Suaviza una poligonal (promedio gaussiano de las coordenadas) sin mover los extremos."""
    if len(pts) < 5:
        return pts
    s = sigma_m / STEP
    x = gaussian_filter(pts[:, 0], s, mode="nearest")
    z = gaussian_filter(pts[:, 1], s, mode="nearest")
    out = np.stack([x, z], axis=1)
    if fix_ends:
        k = min(len(pts) // 2, int(3 * s) + 1)
        for i in range(k):
            w = (i / k) ** 1.5
            out[i] = pts[i] * (1 - w) + out[i] * w
            out[-1 - i] = pts[-1 - i] * (1 - w) + out[-1 - i] * w
    return out


def seg_inter(p, q, r, s):
    d1 = q - p
    d2 = s - r
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) < 1e-9:
        return None
    t = ((r[0] - p[0]) * d2[1] - (r[1] - p[1]) * d2[0]) / den
    u = ((r[0] - p[0]) * d1[1] - (r[1] - p[1]) * d1[0]) / den
    if 0.0 < t < 1.0 and 0.0 < u < 1.0:
        return t, u
    return None
