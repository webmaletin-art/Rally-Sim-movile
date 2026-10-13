#!/usr/bin/env python3
"""Ramales a los pueblos y ciudades que quedan a unos kilómetros de una ruta principal (parche sobre region_1.bin, sin volver a generar el mapa).

Pedido del dueño: «si voy por una ruta principal y a unos km al lado hay un pueblo, tendría que haber un camino que doble hacia ese pueblo: no tiene sentido ir hasta donde termina la ruta
para volver por otro camino».

Qué hace: para cada pueblo o ciudad que tiene una ruta pasando a menos de MAX_KM sin ninguna forma razonable de llegar desde ahí (por la red hay más de 2,2 veces la distancia en línea recta
más 3 km), prueba varios puntos de la ruta, traza el camino con el mismo A* de pendiente máxima que usó el generador (`network.py`), lo redondea con el mismo radio mínimo de curva, y se queda con el mejor
que no cruce ni roce otra ruta. La ruta se parte en ese punto (nodo nuevo «cruce», con su cartel de destinos) y el ramal llega al nodo del pueblo.
Después de correrlo hay que rehacer las alturas (fix_heights.py): `run()` ya lo hace.
Uso: python3 tools/world_gen/add_branches.py [--bin ruta.bin] [--out nueva.bin] [--check]"""
import math
import os
import sys
import time

import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import fix_heights as FH  # noqa: E402
import add_connectors as AC  # noqa: E402
import network as N  # noqa: E402
import terrain as T  # noqa: E402

MAX_KM = 10.8  # pueblos a más distancia que esto de la ruta más cercana quedan como están
MIN_KM = 1.2
ATTACH_CLS = {"autopista", "ruta", "provincial", "camino", "montana"}
NODE_CLEAR = 450.0  # el cruce nuevo queda a más de tanto de cualquier otro nodo y de los servicios
CLEAR = 26.0  # el ramal no pasa más cerca que esto de otra ruta (salvo en los extremos)
SEED = 20261014


def terrain_grid(meta, d):
    delta = np.frombuffer(d["delta"], "<i2").reshape(meta["grid"]["h"], meta["grid"]["w"]).astype(np.float64) * 0.1
    X, Z = T.grid_xz()
    return T.city_height(X, Z) + delta, delta


def graph(meta, edges):
    n = len(meta["nodes"])
    rows, cols, vals = [], [], []
    for o in edges:
        L = float(AC.cumlen(o.pts)[-1])
        rows += [o.a, o.b]
        cols += [o.b, o.a]
        vals += [max(L, 1.0)] * 2
    return csr_matrix((vals, (rows, cols)), shape=(n, n))


def find_towns(meta, edges):
    """Pueblos y ciudades con una ruta cerca y mucho desvío por la red → [(índice del nodo, distancia mínima en línea recta)]."""
    G = graph(meta, edges)
    Dn = dijkstra(G, directed=False)
    samp = []
    for ei, o in enumerate(edges):
        if o.cls not in ATTACH_CLS:
            continue
        cl = AC.cumlen(o.pts)
        if cl[-1] < 300.0:
            continue
        ks = np.arange(0.0, cl[-1], 60.0)
        xs = np.interp(ks, cl, o.pts[:, 0])
        zs = np.interp(ks, cl, o.pts[:, 1])
        for s, x, z in zip(ks, xs, zs):
            samp.append((ei, float(s), float(x), float(z)))
    S = np.array([[s[2], s[3]] for s in samp])
    tree = cKDTree(S)
    cl_all = {ei: AC.cumlen(o.pts) for ei, o in enumerate(edges)}
    out = []
    for ti, nd in enumerate(meta["nodes"]):
        if FH.KIND_LIST[int(nd[3])] not in ("pueblo", "ciudad"):
            continue
        tp = np.array([nd[1], nd[2]])
        best = None
        for j in tree.query_ball_point(tp, MAX_KM * 1000.0):
            ei, s, x, z = samp[j]
            de = math.hypot(x - tp[0], z - tp[1])
            if de < 1500.0:
                continue
            o = edges[ei]
            dn = min(s + Dn[o.a, ti], cl_all[ei][-1] - s + Dn[o.b, ti])
            if dn < 2.2 * de + 3000.0:
                continue
            if best is None or de < best:
                best = de
        if best is not None and best >= MIN_KM * 1000.0:
            out.append((ti, best))
    out.sort(key=lambda t: t[1])
    return out, Dn


def anchor_tree(meta):
    pts = [[nd[1], nd[2]] for nd in meta["nodes"]]
    for poi in meta["pois"]:
        pts.append([poi["x"], poi["z"]])
    for t in meta["tolls"]:
        pts.append([t["x"], t["z"]])
    return cKDTree(np.array(pts))


def attach_candidates(meta, edges, ti, Dn, atree, k_max=8):
    """Puntos de las rutas (vértices) desde donde sale un ramal hacia el pueblo ti: cerca, lejos de nodos y servicios, con un ángulo razonable y sin forma corta de llegar al pueblo."""
    nd = meta["nodes"][ti]
    tp = np.array([nd[1], nd[2]])
    cl_all = {}
    cands = []
    for ei, o in enumerate(edges):
        if o.cls not in ATTACH_CLS or len(o.pts) < 8:
            continue
        cl = cl_all.setdefault(ei, AC.cumlen(o.pts))
        if cl[-1] < 2.0 * AC.EDGE_MARGIN + 60.0:
            continue
        near = np.linalg.norm(o.pts - tp, axis=1)
        for k in np.where(near < MAX_KM * 1000.0)[0]:
            if cl[k] < AC.EDGE_MARGIN or cl[k] > cl[-1] - AC.EDGE_MARGIN or k % 3:
                continue
            de = float(near[k])
            if de < 1200.0:
                continue
            dn = min(cl[k] + Dn[o.a, ti], cl[-1] - cl[k] + Dn[o.b, ti])
            if dn < 2.2 * de + 3000.0:
                continue
            if atree.query(o.pts[k])[0] < NODE_CLEAR:
                continue
            t = o.pts[min(k + 2, len(o.pts) - 1)] - o.pts[max(k - 2, 0)]
            t = t / max(float(np.linalg.norm(t)), 1e-6)
            v = (tp - o.pts[k]) / max(de, 1e-6)
            if abs(float(np.dot(t, v))) > 0.82:
                continue  # el ramal saldría casi paralelo a la ruta
            cands.append((de, ei, int(k)))
    cands.sort()
    chosen = []
    for de, ei, k in cands:
        p = edges[ei].pts[k]
        if all(np.linalg.norm(p - edges[ej].pts[kj]) > 700.0 for _, ej, kj in chosen):
            chosen.append((de, ei, k))
        if len(chosen) >= k_max:
            break
    return chosen


def dest_candidates(meta, edges, ti, dists=(900.0, 1500.0, 2300.0)):
    """Puntos de las rutas que llegan al pueblo ti, a `dists` metros de su centro siguiendo la ruta (las rutas están partidas en los cruces: se sigue por el mismo nombre de nodo en nodo): ahí se une el ramal,
    así no atraviesa las calles del pueblo. [(índice de la ruta, vértice)]."""
    adj = {}
    for i, o in enumerate(edges):
        adj.setdefault(o.a, []).append(i)
        adj.setdefault(o.b, []).append(i)
    out = []
    for e0 in adj.get(ti, []):
        o0 = edges[e0]
        if o0.cls in ("calle", "anillo"):
            continue
        for dd in dists:
            e, node, acc = e0, ti, 0.0
            found = None
            for _hop in range(40):
                o = edges[e]
                cl = AC.cumlen(o.pts)
                L = float(cl[-1])
                if acc + L >= dd:
                    s = dd - acc if o.a == node else L - (dd - acc)
                    k = int(np.argmin(np.abs(cl - s)))
                    if 120.0 < cl[k] < L - 120.0:
                        found = (e, k)
                    break
                acc += L
                node = o.b if o.a == node else o.a
                nxt = [x for x in adj.get(node, []) if x != e and edges[x].name == o.name and edges[x].cls != "calle"]
                if not nxt:
                    break
                e = nxt[0]
            if found:
                out.append(found)
    return out


def pen_grid(edges):
    pen = np.ones((T.H, T.W), dtype=np.float32)
    for o in edges:
        for (x, z) in o.pts[::2]:
            c = int(round((x - T.X0) / T.CELL - 0.5))
            r = int(round((z - T.Z0) / T.CELL - 0.5))
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    rr, cc = r + dr, c + dc
                    if 0 <= rr < T.H and 0 <= cc < T.W:
                        pen[rr, cc] = max(pen[rr, cc], 2.5)
    return pen


def trace(grid, pen, a, b, cls, rng, tangent=None):
    """A* de pendiente máxima + curvas con radio mínimo, como en el generador. Devuelve (puntos, clase). Con `tangent` (la dirección de la ruta en el punto de salida) el ramal sale casi perpendicular a la ruta,
    hacia el lado del pueblo: un primer tramo recto de 150 m y recién ahí el A*."""
    gmax = N.CLS[cls][2]
    a = np.array(a, dtype=np.float64)
    start = a
    stub = None
    if tangent is not None:
        n = np.array([-tangent[1], tangent[0]])
        if float(np.dot(n, np.array(b) - a)) < 0.0:
            n = -n
        stub = a + n * 150.0
        start = stub
    p2 = pen.copy()
    for (x, z) in (a, b):
        c, r = grid.idx(x, z)
        c, r = int(round(c)), int(round(r))
        p2[max(0, r - 15):r + 16, max(0, c - 15):c + 16] = 1.0
    path = N.astar(grid, tuple(start), tuple(b), gmax * 1.25, p2)
    if path is None:
        return None, cls
    poly = N.pull_strings(grid, path, gmax * 1.25)
    if stub is not None:
        poly = [tuple(a)] + list(poly)
    pts0 = N.resample(poly)
    hh = grid.h(pts0[:, 0], pts0[:, 1], smooth=True)
    gr = np.abs(np.diff(hh)) / N.STEP
    if np.percentile(gr, 90) > 0.07 or float(hh.max() - hh.min()) > 350.0:
        cls = "montana"
    rmin = N.CLS[cls][1]
    poly, _ = N.meander(grid, poly, cls, rng, N.CLS[cls][2] * 1.25)
    pts = N.fillet(poly, rmin)
    pts = N.smooth_poly(pts, max(25.0, rmin * 0.12))
    pts[0] = np.array(a)
    pts[-1] = np.array(b)
    return pts, cls


def _seg_inter(p, q, r, s_):
    """Intersección de los tramos pq y rs: (t sobre pq, u sobre rs) o None."""
    d1 = q - p
    d2 = s_ - r
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) < 1e-9:
        return None
    t = ((r[0] - p[0]) * d2[1] - (r[1] - p[1]) * d2[0]) / den
    u = ((r[0] - p[0]) * d1[1] - (r[1] - p[1]) * d1[0]) / den
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return float(t), float(u)
    return None


def analyze(pts, edges, ctx, skip_start, skip_end):
    """Mira el ramal contra las demás rutas. Devuelve (ok, cruces, motivo, roces): ok es falso si la cruza con un ángulo malo o a menos de 100 m de un nodo, la cruza dos veces o dos cruces quedan muy juntos.
    cruces = [(metros desde el comienzo del ramal, ruta, vértice de esa ruta más cercano al cruce)]. roces = [(índice del punto del ramal, vector unitario que lo aleja de la ruta, cuánto falta para CLEAR)]
    de los puntos que pasan a menos de CLEAR de una ruta SIN cruzarla (se los empuja afuera con `repel`). `skip_start` son las rutas de la salida (no cuentan en los primeros 300 m) y `skip_end` las del pueblo
    (no cuentan en los últimos 450 m, y las calles del pueblo tampoco en los últimos 800 m)."""
    tree, allp, owner, first = ctx
    cl = AC.cumlen(pts)
    L = float(cl[-1])
    crossings = {}
    grazes = {}
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if cl[i] < 60.0 or cl[i] > L - 60.0:
            continue
        mid = 0.5 * (a + b)
        seen = set()
        for j in tree.query_ball_point(mid, 40.0):
            e = int(owner[j])
            if cl[i] < 300.0 and e in skip_start:
                continue
            if cl[i] > L - 450.0 and e in skip_end:
                continue
            if cl[i] > L - 800.0 and edges[e].cls == "calle":
                continue
            if (e, j) in seen:
                continue
            seen.add((e, j))
            k = j - int(first[e])
            hit = False
            for kk in (k - 1, k):
                if 0 <= kk < len(edges[e].pts) - 1:
                    h = _seg_inter(a, b, edges[e].pts[kk], edges[e].pts[kk + 1])
                    if h:
                        t, u = h
                        x = edges[e].pts[kk] + (edges[e].pts[kk + 1] - edges[e].pts[kk]) * u
                        d1 = (b - a) / max(float(np.linalg.norm(b - a)), 1e-9)
                        d2 = edges[e].pts[kk + 1] - edges[e].pts[kk]
                        d2 = d2 / max(float(np.linalg.norm(d2)), 1e-9)
                        arc = float(cl[i] + t * np.linalg.norm(b - a))
                        if abs(d1[0] * d2[1] - d1[1] * d2[0]) < 0.55:
                            return False, [], "cruza con mal ángulo %s a %.0f m" % (edges[e].name, arc), []
                        if e in crossings and abs(crossings[e][0] - arc) > 80.0:
                            return False, [], "cruza dos veces %s" % edges[e].name, []
                        vv = kk if np.linalg.norm(edges[e].pts[kk] - x) <= np.linalg.norm(edges[e].pts[kk + 1] - x) else kk + 1
                        crossings.setdefault(e, (arc, e, int(vv)))
                        hit = True
                        break
            if hit:
                continue
            # sin cruce: distancia al tramo vecino más cercano
            q = allp[j]
            dmin = float(np.linalg.norm(q - mid))
            qn = q
            for jj in (j - 1, j + 1):
                if 0 <= jj < len(allp) and owner[jj] == owner[j]:
                    ab = allp[jj] - allp[j]
                    tt = float(np.clip(np.dot(mid - allp[j], ab) / max(float(np.dot(ab, ab)), 1e-9), 0.0, 1.0))
                    cand = allp[j] + ab * tt
                    if float(np.linalg.norm(cand - mid)) < dmin:
                        dmin = float(np.linalg.norm(cand - mid))
                        qn = cand
            if dmin < CLEAR + 8.0:
                v = mid - qn
                v = v / max(float(np.linalg.norm(v)), 1e-6)
                grazes.setdefault(i, (i, v, CLEAR + 8.0 - dmin, int(e)))
    out = sorted(crossings.values())
    # los roces cerca de un cruce (a menos de 90 m) son el propio cruce
    gl = []
    for i, v, need, e in grazes.values():
        if any(c[1] == e and abs(c[0] - cl[i]) < 90.0 for c in out):
            continue
        gl.append((i, v, need))
    # los cruces no pueden estar a menos de 100 m de un nodo de la ruta cruzada ni entre sí a menos de 250 m
    for n_, (arc, e, v) in enumerate(out):
        cle = AC.cumlen(edges[e].pts)
        if cle[v] < 100.0 or cle[v] > cle[-1] - 100.0:
            return False, [], "cruce %s muy cerca de un nodo" % edges[e].name, []
        if n_ and arc - out[n_ - 1][0] < 250.0:
            return False, [], "dos cruces muy juntos", []
    return True, out, "", gl


def repel(pts, grazes):
    """Empuja afuera los puntos que rozan una ruta y vuelve a suavizar (sin mover los extremos)."""
    from scipy.ndimage import gaussian_filter1d
    q = pts.copy()
    for i, v, need in grazes:
        for dd in (-1, 0, 1, 2):
            if 0 < i + dd < len(q) - 1:
                q[i + dd] = q[i + dd] + v * min(need + 2.0, 16.0)
    for ax in (0, 1):
        sm = gaussian_filter1d(q[:, ax], 1.5, mode="nearest")
        q[1:-1, ax] = sm[1:-1]
    return q


def next_rp_number(edges):
    top = 0
    for o in edges:
        if o.name.startswith("RP-"):
            try:
                top = max(top, int(o.name[3:]))
            except ValueError:
                pass
    return top + 1


def typical_surf(edges, cls):
    c = {}
    for o in edges:
        if o.cls == cls:
            c[o.surf] = c.get(o.surf, 0) + 1
    return max(c, key=c.get) if c else 0


def add_signs(meta, edges, nid, e_first, e_second, e_branch, town, L_branch):
    """Cartel del cruce nuevo: a dónde va cada salida (la ruta hacia los dos lados y el ramal)."""
    rows = []
    node = meta["nodes"][nid]
    for ei in (e_first, e_second, e_branch):
        o = edges[ei]
        at_start = o.a == nid
        pts = o.pts if at_start else o.pts[::-1]
        j = min(3, len(pts) - 1)
        dd = pts[j] - pts[0]
        ang = round(math.degrees(math.atan2(dd[1], dd[0])), 1)
        if ei == e_branch:
            to, km = town, L_branch / 1000.0
        else:
            nf, df, nb, db = o.dest
            to, km = (nf, df / 1000.0) if at_start else (nb, db / 1000.0)
        if not to:
            continue
        rows.append(dict(e=ei, to=to, km=round(km, 1), route=o.name, ang=ang))
    if rows:
        meta["signs"][node[0]] = rows


def run(path, out=None, check=False, heights=True):
    t0 = time.time()
    d = binio.read_all(path)
    meta = d["meta"]
    edges = AC.load(d)
    Hm, delta = terrain_grid(meta, d)
    grid = N.Grid(Hm)
    towns, Dn = find_towns(meta, edges)
    print("pueblos/ciudades que necesitan un ramal: %d" % len(towns))
    for ti, de in towns:
        print("  %-22s ruta más cercana a %.1f km" % (meta["nodes"][ti][4], de / 1000.0))
    if check:
        return 0
    atree = anchor_tree(meta)
    rng = np.random.RandomState(SEED)
    pen = pen_grid(edges)
    added = []
    rp = next_rp_number(edges)
    for ti, de0 in towns:
        nd = meta["nodes"][ti]
        tp = (float(nd[1]), float(nd[2]))
        cands = attach_candidates(meta, edges, ti, Dn, atree)
        if not cands:
            print("  (se saltea %s: no hay un punto de la ruta que sirva)" % nd[4])
            continue
        # puntos de todas las rutas para revisar que el ramal no las roce
        allp = np.concatenate([o.pts for o in edges])
        owner = np.concatenate([np.full(len(o.pts), i) for i, o in enumerate(edges)])
        first = np.cumsum([0] + [len(o.pts) for o in edges])[:-1]
        ctx = (cKDTree(allp), allp, owner, first)
        town_edges = {x for x in range(len(edges)) if edges[x].a == ti or edges[x].b == ti}
        dests = dest_candidates(meta, edges, ti)
        best = None
        for de, ei, k in cands:
            a = edges[ei].pts[k]
            t = edges[ei].pts[min(k + 2, len(edges[ei].pts) - 1)] - edges[ei].pts[max(k - 2, 0)]
            t = t / max(float(np.linalg.norm(t)), 1e-6)
            near_dests = sorted(dests, key=lambda c: float(np.linalg.norm(edges[c[0]].pts[c[1]] - a)))[:4]
            for ed, kd in near_dests:
                goal = edges[ed].pts[kd]
                if float(np.linalg.norm(goal - a)) < 600.0:
                    continue
                pts, cls = trace(grid, pen, a, goal, "provincial", rng, t)
                if pts is None:
                    continue
                L = float(AC.cumlen(pts)[-1])
                # el ramal sale con un ángulo razonable de la ruta y llega con otro razonable a la ruta del pueblo
                v = pts[min(3, len(pts) - 1)] - pts[0]
                v = v / max(float(np.linalg.norm(v)), 1e-6)
                if abs(float(np.dot(t, v))) > 0.84:
                    continue
                td = edges[ed].pts[min(kd + 2, len(edges[ed].pts) - 1)] - edges[ed].pts[max(kd - 2, 0)]
                td = td / max(float(np.linalg.norm(td)), 1e-6)
                vd = pts[-1] - pts[max(len(pts) - 4, 0)]
                vd = vd / max(float(np.linalg.norm(vd)), 1e-6)
                if abs(float(np.dot(td, vd))) > 0.85:
                    continue
                ok, crossings, why, grazes = analyze(pts, edges, ctx, {ei}, {ed})
                for _ in range(8):
                    if not ok or not grazes:
                        break
                    pts = repel(pts, grazes)
                    ok, crossings, why, grazes = analyze(pts, edges, ctx, {ei}, {ed})
                if ok and grazes:
                    ok, why = False, "sigue rozando una ruta"
                if not ok:
                    if os.environ.get("BR_DEBUG"):
                        print("     descartado %s k=%d → %s: %s" % (edges[ei].name, k, edges[ed].name, why))
                    continue
                L = float(AC.cumlen(pts)[-1])
                score = L * (1.35 if cls == "montana" else 1.0) + 600.0 * len(crossings)
                if best is None or score < best[0]:
                    best = (score, ei, k, pts, cls, L, crossings, ed, kd)
        if best is None:
            print("  (se saltea %s: ningún trazado cumple)" % nd[4])
            continue
        score, ei, k, pts, cls, L, crossings, ed, kd = best
        o = edges[ei]
        name_main = o.name
        r1 = AC.split(edges, meta, ei, float(AC.cumlen(o.pts)[k]))
        if r1 is None:
            print("  (se saltea %s: no se pudo partir la ruta)" % nd[4])
            continue
        e2, nid, pos = r1
        pts = pts.copy()
        pts[0] = pos
        # los cruces: la ruta cruzada se parte en el vértice más cercano y el ramal pasa justo por ahí
        node_list = [(0, nid)]
        cl = AC.cumlen(pts)
        for arc, ec, vc in crossings:
            piece = AC._closest_piece(edges, edges[ec].name, edges[ec].pts[vc])
            if piece is None:
                continue
            r2 = AC.split(edges, meta, piece, AC._arc_of(edges[piece], edges[piece].pts[vc]))
            if r2 is None:
                continue
            e3, nx, posx = r2
            m = int(np.argmin(np.abs(cl - arc)))
            shift = posx - pts[m]
            for dd in range(-5, 6):
                if 0 < m + dd < len(pts) - 1:
                    w = (1.0 - abs(dd) / 6.0) ** 2
                    pts[m + dd] = pts[m + dd] + shift * w
            pts[m] = posx
            node_list.append((m, nx))
        piece_d = AC._closest_piece(edges, edges[ed].name, edges[ed].pts[kd])
        join = AC.split(edges, meta, piece_d, AC._arc_of(edges[piece_d], edges[ed].pts[kd])) if piece_d is not None else None
        if join is None:
            print("  (se saltea %s: no se pudo partir la ruta del pueblo)" % nd[4])
            continue
        e_join2, n_join, pos_join = join
        pts[-1] = pos_join
        node_list.append((len(pts) - 1, n_join))
        node_list.sort()
        first_edge = len(edges)
        for (m0, n0), (m1, n1) in zip(node_list[:-1], node_list[1:]):
            seg = pts[m0:m1 + 1]
            if len(seg) < 2:
                continue
            br = AC.E()
            br.a, br.b = n0, n1
            br.cls = cls
            br.name = "RP-%d" % rp
            br.w = N.CLS[cls][0]
            br.surf = typical_surf(edges, cls)
            br.pts = seg
            ha = float(meta["nodes"][n0][5])
            hb = float(meta["nodes"][n1][5])
            br.h = np.linspace(ha, hb, len(seg))
            rest = float(AC.cumlen(pts)[-1] - AC.cumlen(pts)[m0])
            br.dest = [nd[4], rest, "", 0.0]
            edges.append(br)
        rp += 1
        add_signs(meta, edges, nid, ei, e2, first_edge, nd[4], L)
        for (x, z) in pts[::2]:
            c = int(round((x - T.X0) / T.CELL - 0.5))
            r = int(round((z - T.Z0) / T.CELL - 0.5))
            if 0 <= r < T.H and 0 <= c < T.W:
                pen[r, c] = max(pen[r, c], 2.5)
        added.append((nd[4], "RP-%d" % (rp - 1), cls, L, name_main, len(crossings)))
        print("  %-22s ← RP-%d (%s) %.1f km, sale de %s%s" % (nd[4], rp - 1, cls, L / 1000.0, name_main, (", cruza %d ruta(s)" % len(crossings)) if crossings else ""))
    print("ramales armados: %d de %d (%.0f s)" % (len(added), len(towns), time.time() - t0))
    dest = out or path
    AC.write(d, meta, edges, dest)
    print("escrito", dest)
    if heights:
        FH.patch(dest)
    return len(added)


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
