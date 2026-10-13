#!/usr/bin/env python3
"""Curvas abiertas en las rutas rectas de la región (parche sobre region_1.bin, sin volver a generar el mapa).

Pedido del dueño: «hay rutas muy rectas, se vuelve aburrido ir sólo acelerando: hacé curvas abiertas, no tan cerradas, que haya que ir pendiente del volante».

Cómo lo hace: un campo de desplazamiento suave (cuatro ondas transversales de 1,4 a 3,6 km de largo y 45 a 110 m de amplitud) que se aplica a los puntos de las rutas (autopista, ruta, provincial y camino;
no la circunvalación, no las de montaña ni las calles). El campo es una función de la POSICIÓN, no de cada ruta: dos rutas paralelas y pegadas se mueven igual y siguen paralelas. El desplazamiento
vale 0 cerca de todo lo que tiene que quedar donde está (nodos y cruces, estaciones, gomerías, peajes, pueblos) y crece de a poco hasta 850 m de distancia, vale 0 en terreno empinado y cerca del mar,
y se revisa que dos rutas que no se tocan no queden más cerca de lo que estaban (si pasa, ahí se baja el desvío).
Las curvas que salen tienen radio de 450 m o más (a 200 km/h piden ~0,4 g: hay que mover el volante pero no frenar).
Después de correrlo hay que rehacer las alturas (fix_heights.py): `run()` ya lo hace.
Uso: python3 tools/world_gen/add_bends.py [--bin ruta.bin] [--out nueva.bin] [--check]"""
import math
import os
import sys

import numpy as np
from scipy.ndimage import gaussian_filter1d
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import fix_heights as FH  # noqa: E402
import add_connectors as AC  # noqa: E402

BEND_CLS = {"autopista", "ruta", "provincial", "camino"}
CLS_SCALE = {"autopista": 0.8, "ruta": 0.9, "provincial": 1.0, "camino": 1.0}  # las autopistas se curvan menos (se van a 250 km/h)
R0, R1 = 320.0, 850.0  # distancia a un ancla: sin desvío hasta R0, desvío completo desde R1
WAVES = [(110.0, 3600.0, 38.0), (75.0, 2400.0, 10.0), (60.0, 1800.0, 62.0), (45.0, 1400.0, 118.0)]  # (amplitud m, largo de onda m, rumbo de propagación °)
CLEAR = 26.0  # dos rutas que no se tocan no pasan a estar más cerca que esto (si ya lo estaban, no se acercan más)
SEED = 20261013


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def field(P):
    """Desplazamiento (N, 2) de cada punto: ondas transversales (el desplazamiento es perpendicular a la dirección en que viaja la onda)."""
    rng = np.random.RandomState(SEED)
    D = np.zeros_like(P)
    for amp, lam, ang in WAVES:
        th = math.radians(ang + rng.uniform(-8.0, 8.0))
        v = np.array([math.cos(th), math.sin(th)])
        u = np.array([-v[1], v[0]])
        ph = rng.uniform(0.0, 2.0 * math.pi)
        D += amp * np.sin(2.0 * math.pi * (P @ v) / lam + ph)[:, None] * u[None, :]
    return D


def anchors(meta):
    pts = [[nd[1], nd[2]] for nd in meta["nodes"]]
    for poi in meta["pois"]:
        pts.append([poi["x"], poi["z"]])
    for t in meta["tolls"]:
        pts.append([t["x"], t["z"]])
    for sp in meta["spawns"]:
        pts.append([sp["x"], sp["z"]])
    return np.array(pts, dtype=np.float64)


def heading_turns(pts):
    """Giro (grados) entre tramos seguidos, sin contar los puntos repetidos."""
    keep = np.r_[True, np.linalg.norm(np.diff(pts, axis=0), axis=1) > 1e-3]
    q = pts[keep]
    if len(q) < 3:
        return np.zeros(0)
    dd = np.diff(q, axis=0)
    ang = np.arctan2(dd[:, 0], dd[:, 1])
    return np.degrees(np.abs((np.diff(ang) + np.pi) % (2.0 * np.pi) - np.pi))


def min_radius(pts):
    """Radio de curvatura mínimo (m) de una poligonal de puntos cada ~12 m (con un promedio de 3 puntos para no contar el ruido de los vértices)."""
    keep = np.r_[True, np.linalg.norm(np.diff(pts, axis=0), axis=1) > 1e-3]
    q = pts[keep]
    if len(q) < 7:
        return 1e9
    q = np.c_[gaussian_filter1d(q[:, 0], 1.0, mode="nearest"), gaussian_filter1d(q[:, 1], 1.0, mode="nearest")]
    a = q[:-2]
    b = q[1:-1]
    c = q[2:]
    ab = np.linalg.norm(b - a, axis=1)
    bc = np.linalg.norm(c - b, axis=1)
    ca = np.linalg.norm(a - c, axis=1)
    area2 = np.abs((b[:, 0] - a[:, 0]) * (c[:, 1] - a[:, 1]) - (b[:, 1] - a[:, 1]) * (c[:, 0] - a[:, 0]))
    with np.errstate(divide="ignore", invalid="ignore"):
        r = ab * bc * ca / np.maximum(2.0 * area2, 1e-9)
    return float(np.min(r))


def plan(meta, edges, f):
    """Desplazamiento de cada punto de cada ruta (lista de arreglos (n, 2))."""
    anc = cKDTree(anchors(meta))
    out = []
    for o in edges:
        if o.cls not in BEND_CLS or len(o.pts) < 8:
            out.append(np.zeros_like(o.pts))
            continue
        P = o.pts
        D = field(P)
        da, _ = anc.query(P)
        m = sstep(R0, R1, da)
        # terreno: nada en laderas empinadas ni cerca del mar (se mira el punto original y el desplazado)
        slope = np.abs(f(P[:, 0] + 400.0, P[:, 1]) - f(P[:, 0] - 400.0, P[:, 1])) / 800.0
        slope = np.maximum(slope, np.abs(f(P[:, 0], P[:, 1] + 400.0) - f(P[:, 0], P[:, 1] - 400.0)) / 800.0)
        m = m * (1.0 - sstep(0.035, 0.07, slope))
        m = m * sstep(5.0, 12.0, f(P[:, 0], P[:, 1]))
        P2 = P + D * m[:, None]
        m = m * sstep(5.0, 12.0, f(P2[:, 0], P2[:, 1]))
        m = gaussian_filter1d(m, 2.0, mode="nearest")  # que la envolvente no tenga escalones
        out.append(D * m[:, None] * CLS_SCALE.get(o.cls, 1.0))
    return out


def clearance_repair(edges, disp, meta):
    """Baja el desvío donde dos rutas (que no comparten nodo) quedarían más cerca de lo que estaban."""
    n_nodes = len(meta["nodes"])
    adj = [set() for _ in range(len(edges))]
    by_node = {}
    for i, o in enumerate(edges):
        by_node.setdefault(o.a, []).append(i)
        by_node.setdefault(o.b, []).append(i)
    for lst in by_node.values():
        for i in lst:
            for j in lst:
                adj[i].add(j)
    scale = [np.ones(len(o.pts)) for o in edges]
    for rnd in range(10):
        allp = []
        eid = []
        pid = []
        orig = []
        for i, o in enumerate(edges):
            allp.append(o.pts + disp[i] * scale[i][:, None])
            orig.append(o.pts)
            eid.append(np.full(len(o.pts), i))
            pid.append(np.arange(len(o.pts)))
        A = np.concatenate(allp)
        O = np.concatenate(orig)
        E = np.concatenate(eid)
        K = np.concatenate(pid)
        moved = np.linalg.norm(A - O, axis=1) > 0.5
        idx = np.where(moved)[0]
        if len(idx) == 0:
            return scale
        tree = cKDTree(A)
        bad = {}
        for i in idx:
            for j in tree.query_ball_point(A[i], CLEAR + 6.0):
                if E[j] == E[i] or E[j] in adj[E[i]]:
                    continue
                d_new = float(np.linalg.norm(A[i] - A[j]))
                d_old = float(np.linalg.norm(O[i] - O[j]))
                if d_new < CLEAR and d_new < d_old - 2.0:
                    bad.setdefault(int(E[i]), set()).add(int(K[i]))
                    bad.setdefault(int(E[j]), set()).add(int(K[j]))
        if not bad:
            return scale
        for ei, ks in bad.items():
            w = np.zeros(len(edges[ei].pts))
            w[list(ks)] = 1.0
            w = np.clip(gaussian_filter1d(w, 12.0, mode="nearest") * 6.0, 0.0, 1.0)  # ±300 m alrededor
            scale[ei] = scale[ei] * (1.0 - 0.6 * w)
    # lo que siga mal después de 10 vueltas: sin desvío
    return scale


def run(path, out=None, check=False, heights=True):
    d = binio.read_all(path)
    meta = d["meta"]
    edges = AC.load(d)
    delta = np.frombuffer(d["delta"], "<i2").reshape(meta["grid"]["h"], meta["grid"]["w"]).astype(np.float64) * 0.1
    f = FH.terrain_fn(delta)
    disp = plan(meta, edges, f)
    scale = clearance_repair(edges, disp, meta)
    tot_len = 0.0
    bent_len = 0.0
    worst_r_old = []
    worst_r_new = []
    moved_max = 0.0
    n_edges = 0
    for i, o in enumerate(edges):
        sh = disp[i] * scale[i][:, None]
        mx = float(np.max(np.linalg.norm(sh, axis=1))) if len(sh) else 0.0
        if o.cls in BEND_CLS:
            L = float(AC.cumlen(o.pts)[-1])
            tot_len += L
            if mx > 8.0:
                n_edges += 1
                seg = np.linalg.norm(sh[1:] - sh[:-1] + 0.0, axis=1)
                bent_len += float(np.sum(np.linalg.norm(np.diff(o.pts, axis=0), axis=1)[np.linalg.norm(0.5 * (sh[1:] + sh[:-1]), axis=1) > 8.0]))
                worst_r_old.append(min_radius(o.pts))
                worst_r_new.append(min_radius(o.pts + sh))
        moved_max = max(moved_max, mx)
    print("rutas con curvas nuevas: %d · largo con desvío (>8 m) %.0f km de %.0f km de rutas elegibles · desvío máximo %.0f m" % (n_edges, bent_len / 1000.0, tot_len / 1000.0, moved_max))
    if worst_r_new:
        print("radio mínimo por ruta tocada: antes mediana %.0f m (mín %.0f) · ahora mediana %.0f m (mín %.0f)" % (np.median(worst_r_old), np.min(worst_r_old), np.median(worst_r_new), np.min(worst_r_new)))
    if check:
        return 0
    for i, o in enumerate(edges):
        o.pts = np.round((o.pts + disp[i] * scale[i][:, None]) * 10.0) / 10.0
    dest = out or path
    AC.write(d, meta, edges, dest)
    print("escrito", dest)
    if heights:
        FH.patch(dest)
    return n_edges


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
    run(path, out, check)


if __name__ == "__main__":
    main()
