#!/usr/bin/env python3
"""Agrega empalmes entre rutas que corren paralelas y cerca una de la otra sin ninguna conexión (había que ir hasta el final de la ruta para pasar a la paralela).
Es un parche sobre region_1.bin (no vuelve a generar el mapa): detecta los tramos paralelos, parte las dos rutas en un punto de cada una (nodo nuevo) y las une con una calle recta de clase «conector».
Después de correrlo hay que rehacer las alturas (fix_heights.py): este script ya lo hace al final.
Uso: python3 tools/world_gen/add_connectors.py [--bin ruta.bin] [--out nueva.bin] [--check]"""
import math
import os
import sys

import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import fix_heights as FH  # noqa: E402

CLS = FH.CLS_LIST
SEARCH = 260.0  # dos rutas se consideran paralelas si van a menos de tanto una de la otra
MIN_RUN = 450.0  # …durante al menos tanto
MIN_SEP = 38.0  # el empalme más corto que se arma
MAX_DH = 3.5  # diferencia de altura máxima entre las dos rutas en el empalme (m)
EDGE_MARGIN = 70.0  # los nodos nuevos quedan a más de tanto de los extremos de cada ruta
TOWN_CLEAR = 700.0  # lejos de ciudades, pueblos y villas
GAP = 1800.0  # entre dos empalmes de la misma pareja de rutas, al menos tanto
STEP = 12.0


class E:
    pass


def load(d):
    meta = d["meta"]
    P = d["P"].astype(np.float64) / 10.0
    edges = []
    for i, e in enumerate(meta["edges"]):
        o = E()
        o.a, o.b = int(e[0]), int(e[1])
        o.cls = CLS[int(e[2])]
        o.name = e[3]
        o.w = float(e[4])
        o.surf = int(e[5])
        o.pts = P[int(e[6]):int(e[6]) + int(e[7])].copy()
        o.h = d["H"][int(e[6]):int(e[6]) + int(e[7])].astype(np.float64).copy()
        o.dest = [e[9], float(e[10]), e[11], float(e[12])]
        edges.append(o)
    return edges


def cumlen(pts):
    return np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]


def node_graph(meta, edges):
    n = len(meta["nodes"])
    rows, cols, vals = [], [], []
    for o in edges:
        L = float(cumlen(o.pts)[-1])
        rows += [o.a, o.b]
        cols += [o.b, o.a]
        vals += [max(L, 1.0)] * 2
    return csr_matrix((vals, (rows, cols)), shape=(n, n))


def find_sites(meta, edges):
    """Tramos paralelos sin conexión → lista de (índice de A, vértice de A, índice de B, vértice de B, separación)."""
    G = node_graph(meta, edges)
    D = dijkstra(G, directed=False)
    major = [i for i, o in enumerate(edges) if o.cls != "calle" and len(o.pts) > 6]
    cl = {i: cumlen(edges[i].pts) for i in major}
    samp = []
    for i in major:
        o = edges[i]
        ks = np.arange(0.0, cl[i][-1], 24.0)
        xs = np.interp(ks, cl[i], o.pts[:, 0])
        zs = np.interp(ks, cl[i], o.pts[:, 1])
        for s, x, z in zip(ks, xs, zs):
            samp.append((i, float(s), float(x), float(z)))
    S = np.array([[s[2], s[3]] for s in samp])
    Ei = np.array([s[0] for s in samp])
    Ss = np.array([s[1] for s in samp])
    tree = cKDTree(S)
    pairs = {}
    for idx, (ei, s, x, z) in enumerate(samp):
        for j in tree.query_ball_point([x, z], SEARCH):
            ej = int(Ei[j])
            if ej <= ei:
                continue
            d = float(np.hypot(S[j, 0] - x, S[j, 1] - z))
            pairs.setdefault((ei, ej), []).append((idx, int(j), d))

    def gdist(ei, s, ej, t):
        A, B = edges[ei], edges[ej]
        best = 1e18
        for na, da in ((A.a, s), (A.b, cl[ei][-1] - s)):
            for nb, db in ((B.a, t), (B.b, cl[ej][-1] - t)):
                best = min(best, da + D[na, nb] + db)
        return best

    towns = np.array([[nd[1], nd[2]] for nd in meta["nodes"] if FH.KIND_LIST[int(nd[3])] in ("ciudad", "pueblo", "villa", "dream", "ciudad_salida")])
    ttree = cKDTree(towns)
    sites = []
    for (ei, ej), lst0 in pairs.items():
        # para cada punto de A, sólo el punto más cercano de B (el empalme sale perpendicular a las dos rutas)
        nearest = {}
        for (ia, jb, dd) in lst0:
            if ia not in nearest or dd < nearest[ia][2]:
                nearest[ia] = (ia, jb, dd)
        lst = list(nearest.values())
        lst.sort(key=lambda t: Ss[t[0]])
        runs, run = [], [lst[0]]
        for t in lst[1:]:
            if Ss[t[0]] - Ss[run[-1][0]] <= 60:
                run.append(t)
            else:
                runs.append(run)
                run = [t]
        runs.append(run)
        for r in runs:
            L = Ss[r[-1][0]] - Ss[r[0][0]]
            if L < MIN_RUN:
                continue
            if all(gdist(ei, Ss[t[0]], ej, Ss[t[1]]) <= max(2500.0, 6.0 * t[2]) for t in r[::6]):
                continue  # ya hay forma de pasar de una a la otra en todo el tramo
            # candidatos: los mínimos de separación (de a ~24 m) con altura parecida, lejos de pueblos y de los extremos
            cands = []
            for (ia, jb, dd) in r:
                sa, sb = float(Ss[ia]), float(Ss[jb])
                A, B = edges[ei], edges[ej]
                if sa < EDGE_MARGIN or sa > cl[ei][-1] - EDGE_MARGIN or sb < EDGE_MARGIN or sb > cl[ej][-1] - EDGE_MARGIN:
                    continue
                if dd < MIN_SEP:
                    continue
                pa = S[ia]
                pb = S[jb]
                if ttree.query(pa)[0] < TOWN_CLEAR or ttree.query(pb)[0] < TOWN_CLEAR:
                    continue
                dh = abs(float(np.interp(sa, cl[ei], A.h)) - float(np.interp(sb, cl[ej], B.h)))
                if dh > MAX_DH:
                    continue
                vv = (pb - pa) / max(float(np.linalg.norm(pb - pa)), 1e-6)
                ka = int(np.argmin(np.abs(cl[ei] - sa)))
                kb = int(np.argmin(np.abs(cl[ej] - sb)))
                ta = A.pts[min(ka + 2, len(A.pts) - 1)] - A.pts[max(ka - 2, 0)]
                tb = B.pts[min(kb + 2, len(B.pts) - 1)] - B.pts[max(kb - 2, 0)]
                ta = ta / max(float(np.linalg.norm(ta)), 1e-6)
                tb = tb / max(float(np.linalg.norm(tb)), 1e-6)
                if abs(float(np.dot(ta, vv))) > 0.6 or abs(float(np.dot(tb, vv))) > 0.6:
                    continue  # el empalme sale casi perpendicular a las dos rutas
                cands.append((dd + 8.0 * dh, sa, sb, dd))
            if not cands:
                continue
            cands.sort()
            chosen = []
            close = min(c[3] for c in cands) <= 100.0  # dos rutas pegadas (a menos de 100 m) llevan un empalme cada ~1 km; más separadas, uno cada ~2 km
            gap = 900.0 if close else GAP
            want = 1 + int(L // gap)
            for cst, sa, sb, dd in cands:
                if len(chosen) >= want:
                    break
                if gdist(ei, sa, ej, sb) <= max(2500.0, 6.0 * dd):
                    continue  # en este punto ya se puede pasar de una a la otra por la red (un empalme anterior, un cruce)
                if all(abs(sa - c[0]) > gap for c in chosen):
                    chosen.append((sa, sb, dd))
            for sa, sb, dd in chosen:
                A, B = edges[ei], edges[ej]
                pa = np.array([np.interp(sa, cl[ei], A.pts[:, 0]), np.interp(sa, cl[ei], A.pts[:, 1])])
                pb = np.array([np.interp(sb, cl[ej], B.pts[:, 0]), np.interp(sb, cl[ej], B.pts[:, 1])])
                sites.append((ei, pa, ej, pb, dd, L, A.name, B.name, A.cls, B.cls))
    return sites


def split(edges, meta, ei, s):
    """Parte la ruta ei en el vértice más cercano a la distancia s del comienzo. Devuelve (índice de la segunda parte, índice del nodo nuevo, posición del nodo)."""
    o = edges[ei]
    cl = cumlen(o.pts)
    keep = np.r_[True, np.linalg.norm(np.diff(o.pts, axis=0), axis=1) > 1e-3]
    ok = np.where(keep & (cl > EDGE_MARGIN * 0.6) & (cl < cl[-1] - EDGE_MARGIN * 0.6))[0]
    if len(ok) == 0:
        return None
    k = int(ok[np.argmin(np.abs(cl[ok] - s))])
    nid = len(meta["nodes"])
    x, z = float(o.pts[k, 0]), float(o.pts[k, 1])
    h = float(o.h[k])
    meta["nodes"].append(["cn%d" % nid, round(x, 1), round(z, 1), FH.KIND_LIST.index("cruce"), "", round(h, 2), []])
    o2 = E()
    o2.a, o2.b = nid, o.b
    o2.cls, o2.name, o2.w, o2.surf = o.cls, o.name, o.w, o.surf
    o2.pts = o.pts[k:].copy()
    o2.h = o.h[k:].copy()
    L1 = float(cl[k])
    L2 = float(cl[-1] - cl[k])
    nf, df, nb, db = o.dest
    o2.dest = [nf, max(df - L1, 0.0), nb, db]
    o.dest = [nf, df, nb, max(db - L2, 0.0)]
    o.pts = o.pts[:k + 1].copy()
    o.h = o.h[:k + 1].copy()
    old_b = o.b
    o.b = nid
    edges.append(o2)
    e2i = len(edges) - 1
    # carteles y peajes que estaban en el extremo b de la ruta o más allá del corte
    for lst in meta["signs"].values():
        for sg in lst:
            if int(sg["e"]) == ei and False:
                pass
    sg = meta["signs"].get(meta["nodes"][old_b][0])
    if sg:
        for ent in sg:
            if int(ent["e"]) == ei:
                ent["e"] = e2i
    for t in meta["tolls"]:
        if int(t.get("edge", -1)) == ei and float(t.get("s", 0.0)) > L1:
            t["edge"] = e2i
            t["s"] = float(t["s"]) - L1
    return e2i, nid, np.array([x, z])


def segs_near(edges, p, skip, rad):
    """¿Hay alguna ruta (que no sea de las de `skip`) a menos de rad de p?"""
    for i, o in enumerate(edges):
        if i in skip:
            continue
        d = np.min(np.linalg.norm(o.pts - p, axis=1))
        if d < rad + 12.0:  # los puntos están a 12 m: se deja margen
            # distancia a los tramos
            a = o.pts[:-1]
            b = o.pts[1:]
            ab = b - a
            t = np.clip(np.einsum("ij,ij->i", p - a, ab) / np.maximum(np.einsum("ij,ij->i", ab, ab), 1e-9), 0.0, 1.0)
            dd = np.linalg.norm(a + ab * t[:, None] - p, axis=1).min()
            if dd < rad:
                return True
    return False


def apply_sites(meta, edges, sites):
    added = []
    for (ei, pa, ej, pb, dd, L, na_, nb_, ca_, cb_) in sites:
        # las rutas pueden haberse partido en un empalme anterior: se busca la parte (de la misma ruta) que pasa más cerca de cada punto
        ia = _closest_piece(edges, na_, pa)
        ib = _closest_piece(edges, nb_, pb)
        if ia is None or ib is None or ia == ib:
            print("  (se saltea %s ‖ %s: no se encontró la ruta)" % (na_, nb_))
            continue
        d_ab = float(np.linalg.norm(pb - pa))
        if d_ab < MIN_SEP:
            print("  (se saltea %s ‖ %s: muy corto %.0f m)" % (na_, nb_, d_ab))
            continue
        # el empalme en línea recta: que no cruce otra ruta ni se acerque a ninguna (salvo las dos que une)
        skip = {i for i, o in enumerate(edges) if o.name in (na_, nb_)}
        blocked = False
        for t in np.linspace(0.0, 1.0, 14)[2:-2]:
            if segs_near(edges, pa + (pb - pa) * t, skip, 16.0):
                blocked = True
                break
        if blocked:
            print("  (se saltea %s ‖ %s: cruzaría otra ruta, sep %.0f m)" % (na_, nb_, d_ab))
            continue
        r1 = split(edges, meta, ia, _arc_of(edges[ia], pa))
        if r1 is None:
            print("  (se saltea %s ‖ %s: no hay vértice para partir la primera ruta)" % (na_, nb_))
            continue
        e2a, nda, posa = r1
        ib = _closest_piece(edges, nb_, pb)
        r2 = split(edges, meta, ib, _arc_of(edges[ib], pb))
        if r2 is None:
            print("  (se saltea %s ‖ %s: no hay vértice para partir la segunda ruta)" % (na_, nb_))
            continue
        e2b, ndb, posb = r2
        d_real = float(np.linalg.norm(posb - posa))
        n = max(2, int(math.ceil(d_real / STEP)))
        pts = np.array([posa + (posb - posa) * (t / n) for t in range(n + 1)])
        c = E()
        c.a, c.b = nda, ndb
        c.cls = "conector"
        top = na_ if FH.IMPORTANCE[ca_] >= FH.IMPORTANCE[cb_] else nb_
        c.name = "Empalme " + top
        c.w = 9.5
        c.surf = 0
        c.pts = pts
        ha = float(meta["nodes"][nda][5])
        hb = float(meta["nodes"][ndb][5])
        c.h = np.linspace(ha, hb, len(pts))
        c.dest = ["", 0.0, "", 0.0]
        edges.append(c)
        added.append((na_, nb_, d_real, posa, posb))
    return added


def _closest_piece(edges, name, p):
    best, bi = 1e18, None
    for i, o in enumerate(edges):
        if o.name != name:
            continue
        d = float(np.min(np.linalg.norm(o.pts - p, axis=1)))
        if d < best:
            best, bi = d, i
    return bi if best < 40.0 else None


def _arc_of(o, p):
    cl = cumlen(o.pts)
    k = int(np.argmin(np.linalg.norm(o.pts - p, axis=1)))
    return float(cl[k])


def write(d, meta, edges, out):
    # arreglos nuevos a partir de las rutas
    Pl, Hl, pel = [], [], []
    em = []
    p0 = 0
    for i, o in enumerate(edges):
        n = len(o.pts)
        Pl.append(np.round(o.pts * 10.0).astype(np.int32))
        Hl.append(o.h.astype(np.float32))
        pel.append(np.full(n, i, dtype=np.int32))
        L = float(cumlen(o.pts)[-1])
        em.append([o.a, o.b, CLS.index(o.cls), o.name, o.w, o.surf, p0, n, round(L, 1), o.dest[0], round(o.dest[1], 1), o.dest[2], round(o.dest[3], 1)])
        p0 += n
    meta["edges"] = em
    P = np.concatenate(Pl, axis=0)
    cells, segs = binio.build_index(P, em)
    d2 = dict(d)
    d2.update(meta=meta, P=P, H=np.concatenate(Hl), pe=np.concatenate(pel), cells=cells, segs=segs)
    km = {}
    for o in edges:
        km[o.cls] = km.get(o.cls, 0.0) + float(cumlen(o.pts)[-1]) / 1000.0
    meta["stats"] = {"km": round(sum(km.values()), 1), "edges": len(edges), "nodes": len(meta["nodes"]), "km_por_clase": {k: round(v, 1) for k, v in km.items()}}
    binio.write_all(out, d2)


def run(path, out=None, check=False):
    """Agrega los empalmes a `path` (o a `out`) y rehace las alturas. Devuelve la cantidad de empalmes armados."""
    d = binio.read_all(path)
    meta = d["meta"]
    edges = load(d)
    sites = find_sites(meta, edges)
    print("tramos paralelos sin conexión → empalmes a armar: %d" % len(sites))
    if check:
        for st in sites[:40]:
            print("  %s ‖ %s  sep %.0f m  tramo de %.0f m" % (st[6], st[7], st[4], st[5]))
        return 0
    added = apply_sites(meta, edges, sites)
    print("empalmes armados: %d de %d" % (len(added), len(sites)))
    for x in added[:60]:
        print("  %s ‖ %s  largo %.0f m  en (%.0f, %.0f)" % (x[0], x[1], x[2], x[3][0], x[3][1]))
    dest = out or path
    write(d, meta, edges, dest)
    print("escrito", dest)
    # alturas de las rutas nuevas y de los nodos nuevos
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
