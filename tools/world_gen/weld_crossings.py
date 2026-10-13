#!/usr/bin/env python3
"""Cruces de calles sin nodo → cruces de verdad (parche sobre region_1.bin, sin volver a generar el mapa).

En los pueblos había 56 lugares donde una calle cruza (o termina justo sobre) otra sin que haya un nodo ahí: las dos calles se pisaban, cada una con su altura (hasta 0,7 m de escalón: el auto
saltaba), y las rayas del centro de las dos pasaban por el medio del cruce. Con un nodo en el cruce la plazoleta queda plana, las esquinas redondeadas y las rayas se cortan.

Qué hace con cada cruce `A × B` (X = punto donde se cortan):
 · si el extremo de A (o de B) cae a menos de SNAP de X, ese nodo es el del cruce: se le mete un vértice en ese lugar a la otra calle y se la parte ahí (sin nodo nuevo);
 · si los dos extremos están cerca de X y son nodos distintos, se sueldan en uno solo (el de A);
 · si ninguno está cerca, nodo nuevo en X y se parten las dos.
Las piezas que quedan miden al menos MIN_PIECE. Después hay que rehacer las alturas (fix_heights.py): `run()` ya lo hace.
Uso: python3 tools/world_gen/weld_crossings.py [--bin ruta.bin] [--out nueva.bin] [--check]"""
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import fix_heights as FH  # noqa: E402
import add_connectors as AC  # noqa: E402

SNAP = 8.0  # un extremo de calle a menos de tanto del cruce hace de nodo del cruce (la calle se corta en el cruce y el nodo se mueve ahí)
SNAP_BUSY = 5.5  # …y si ese nodo tiene otras calles (3 o más en total), sólo se lo mueve hasta tanto
MIN_PIECE = 10.0  # ninguna pieza de calle queda más corta que esto
NEAR_NODE = 45.0  # un nodo común a menos de tanto del cruce ya cuenta como cruce con nodo (igual que check_planar.py)
TOUCH = 1.5  # la punta de una calle (un nodo) a menos de tanto de otra calle sin nodo ahí es un «T sin nodo»


def find_crossings(meta, edges):
    """[(ei, ki, ti, ej, kj, tj, X)] de los cruces que no tienen nodo común a menos de NEAR_NODE."""
    nodes = np.array([[n[1], n[2]] for n in meta["nodes"]])
    A, B, E, K = [], [], [], []
    for ei, o in enumerate(edges):
        p = o.pts
        if len(p) < 2:
            continue
        a, b = p[:-1], p[1:]
        keep = np.linalg.norm(b - a, axis=1) > 1e-3
        A.append(a[keep])
        B.append(b[keep])
        E.append(np.full(int(keep.sum()), ei))
        K.append(np.arange(len(a))[keep])
    A = np.concatenate(A)
    B = np.concatenate(B)
    E = np.concatenate(E)
    K = np.concatenate(K)
    mid = (A + B) * 0.5
    half = np.linalg.norm(B - A, axis=1) * 0.5
    tree = cKDTree(mid)
    pr = tree.query_pairs(r=float(half.max()) * 2.0 + 0.5, output_type="ndarray")
    i, j = pr[:, 0], pr[:, 1]
    m = (E[i] != E[j]) & (np.linalg.norm(mid[i] - mid[j], axis=1) <= half[i] + half[j] + 0.5)
    i, j = i[m], j[m]
    p, q, r, s_ = A[i], B[i], A[j], B[j]
    d1 = q - p
    d2 = s_ - r
    den = d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]
    with np.errstate(divide="ignore", invalid="ignore"):
        t = ((r[:, 0] - p[:, 0]) * d2[:, 1] - (r[:, 1] - p[:, 1]) * d2[:, 0]) / den
        u = ((r[:, 0] - p[:, 0]) * d1[:, 1] - (r[:, 1] - p[:, 1]) * d1[:, 0]) / den
    # intersección CERRADA (los extremos también cuentan): dos calles con un vértice justo en el mismo punto se cruzan ahí aunque no haya «cruce propio» en ninguno de los dos tramos
    eps = 1e-9
    hit = (np.abs(den) > 1e-9) & (t > -eps) & (t < 1 + eps) & (u > -eps) & (u < 1 + eps)
    out = []
    seen = set()
    for n in np.where(hit)[0]:
        ei, ej = int(E[i[n]]), int(E[j[n]])
        X = p[n] + d1[n] * min(max(float(t[n]), 0.0), 1.0)
        ok = False
        for nd in {edges[ei].a, edges[ei].b} & {edges[ej].a, edges[ej].b}:
            # un nodo común a menos de 1 m del cruce es el cruce normal; a menos de NEAR_NODE sólo vale si el cruce es «propio» (no en los extremos)
            dnode = float(np.linalg.norm(nodes[nd] - X))
            if dnode < 1.0 or (dnode < NEAR_NODE and 1e-6 < t[n] < 1 - 1e-6 and 1e-6 < u[n] < 1 - 1e-6):
                ok = True
        if ok:
            continue
        key = (min(ei, ej), max(ei, ej), int(X[0] // 6), int(X[1] // 6))
        if key in seen:
            continue
        seen.add(key)
        out.append((ei, int(K[i[n]]), float(t[n]), ej, int(K[j[n]]), float(u[n]), X))
    # «T sin nodo»: la punta de una calle (un nodo) apoyada sobre otra calle que no tiene nodo ahí (a menos de TOUCH m)
    inc = {}
    for ei, o in enumerate(edges):
        inc.setdefault(o.a, []).append(ei)
        inc.setdefault(o.b, []).append(ei)
    rr = float(half.max()) + TOUCH + 1.0
    for ni, lst in inc.items():
        P0 = nodes[ni]
        for j in tree.query_ball_point(P0, rr):
            ej = int(E[j])
            if ej in lst:
                continue
            ab = B[j] - A[j]
            tt = float(np.dot(P0 - A[j], ab) / max(float(np.dot(ab, ab)), 1e-9))
            if tt <= 1e-3 or tt >= 1.0 - 1e-3:
                continue
            X = A[j] + ab * tt
            if float(np.linalg.norm(X - P0)) >= TOUCH:
                continue
            # la calle del nodo que se usa de «A»: la más larga (que sobrevive entera a la poda del extremo)
            best = max(lst, key=lambda q: AC.cumlen(edges[q].pts)[-1])
            oa = edges[best]
            if oa.a == ni:
                ki, ti = 0, 0.0
            else:
                ki, ti = len(oa.pts) - 2, 1.0
            key = (min(best, ej), max(best, ej), int(X[0] // 6), int(X[1] // 6))
            if key in seen:
                continue
            seen.add(key)
            out.append((best, ki, ti, ej, int(K[j]), tt, X))
    return out


def arc_at(o, k, t):
    cl = AC.cumlen(o.pts)
    seg = float(cl[k + 1] - cl[k])
    return float(cl[k] + seg * t), float(cl[-1])


def insert_vertex(o, k, p):
    """Mete un vértice en la posición p dentro del tramo k→k+1 (si ya hay uno a menos de 1,2 m, se mueve ese a p). Devuelve su índice."""
    a, b = o.pts[k], o.pts[k + 1]
    l = float(np.linalg.norm(b - a))
    t = float(np.clip(np.dot(p - a, b - a) / max(l * l, 1e-9), 0.0, 1.0))
    for kk in (k, k + 1):
        if np.linalg.norm(o.pts[kk] - p) < 1.2 and 0 < kk < len(o.pts) - 1:
            o.pts[kk] = p
            return kk
    h = float(o.h[k] + (o.h[k + 1] - o.h[k]) * t)
    o.pts = np.insert(o.pts, k + 1, p, axis=0)
    o.h = np.insert(o.h, k + 1, h)
    return k + 1


def split_vertex(edges, meta, ei, kv, node=None):
    """Parte la ruta ei en el vértice kv. Con `node` la unión usa ese nodo (existente); si no, crea uno nuevo. Devuelve (índice de la segunda parte, nodo)."""
    o = edges[ei]
    cl = AC.cumlen(o.pts)
    L1 = float(cl[kv])
    L2 = float(cl[-1] - cl[kv])
    x, z = float(o.pts[kv, 0]), float(o.pts[kv, 1])
    if node is None:
        nid = len(meta["nodes"])
        meta["nodes"].append(["cn%d" % nid, round(x, 1), round(z, 1), FH.KIND_LIST.index("cruce"), "", round(float(o.h[kv]), 2), []])
    else:
        nid = node
        o.pts[kv] = (float(meta["nodes"][nid][1]), float(meta["nodes"][nid][2]))
    o2 = AC.E()
    o2.a, o2.b = nid, o.b
    o2.cls, o2.name, o2.w, o2.surf = o.cls, o.name, o.w, o.surf
    o2.pts = o.pts[kv:].copy()
    o2.h = o.h[kv:].copy()
    nf, df, nb, db = o.dest
    o2.dest = [nf, max(df - L1, 0.0), nb, db]
    o.dest = [nf, df, nb, max(db - L2, 0.0)]
    o.pts = o.pts[:kv + 1].copy()
    o.h = o.h[:kv + 1].copy()
    old_b = o.b
    o.b = nid
    edges.append(o2)
    e2i = len(edges) - 1
    sg = meta["signs"].get(meta["nodes"][old_b][0])
    if sg:
        for ent in sg:
            if int(ent["e"]) == ei:
                ent["e"] = e2i
    for t in meta["tolls"]:
        if int(t.get("edge", -1)) == ei and float(t.get("s", 0.0)) > L1:
            t["edge"] = e2i
            t["s"] = float(t["s"]) - L1
    return e2i, nid


def node_pos(meta, n):
    return np.array([float(meta["nodes"][n][1]), float(meta["nodes"][n][2])])


def move_node(edges, meta, n, pos):
    """Lleva el nodo n a pos y los extremos de todas las calles que llegan a él."""
    meta["nodes"][n][1] = round(float(pos[0]), 1)
    meta["nodes"][n][2] = round(float(pos[1]), 1)
    q = node_pos(meta, n)
    for o in edges:
        if o.a == n:
            o.pts[0] = q
        if o.b == n:
            o.pts[-1] = q


def weld(edges, meta, keep, drop):
    """Pasa todo lo del nodo `drop` al nodo `keep` (las calles que llegaban a `drop` terminan en `keep`)."""
    q = node_pos(meta, keep)
    for o in edges:
        if o.a == drop:
            o.a = keep
            o.pts[0] = q
        if o.b == drop:
            o.b = keep
            o.pts[-1] = q
    kn = meta["nodes"][keep][0]
    dn = meta["nodes"][drop][0]
    if dn in meta["signs"]:
        meta["signs"].setdefault(kn, []).extend(meta["signs"].pop(dn))


def deg(edges, n):
    return sum(1 for o in edges if o.a == n) + sum(1 for o in edges if o.b == n)


def end_node(edges, meta, e, s, L, X):
    """Nodo en el que termina la calle e si queda a menos de SNAP de X: (nodo, 'a' o 'b', distancia); si no, None."""
    o = edges[e]
    if s < SNAP:
        n, side = o.a, "a"
    elif L - s < SNAP:
        n, side = o.b, "b"
    else:
        return None
    return n, side, float(np.linalg.norm(node_pos(meta, n) - X))


def movable(edges, meta, cand):
    """¿Se puede llevar ese nodo hasta el cruce? (no los de pueblo; los muy ocupados sólo un poco)."""
    n, _, dist = cand
    if FH.KIND_LIST[int(meta["nodes"][n][3])] in FH.LOCKED_KINDS:
        return False
    return deg(edges, n) < 3 or dist <= SNAP_BUSY


def truncate_at(o, side, k, X):
    """Corta la calle en X (la parte entre X y el extremo se descarta) y deja X como punto final."""
    a, b = o.pts[k], o.pts[k + 1]
    l = float(np.linalg.norm(b - a))
    t = float(np.clip(np.dot(X - a, b - a) / max(l * l, 1e-9), 0.0, 1.0))
    h = float(o.h[k] + (o.h[k + 1] - o.h[k]) * t)
    if side == "b":
        o.pts = np.vstack([o.pts[:k + 1], X[None, :]])
        o.h = np.r_[o.h[:k + 1], h]
    else:
        o.pts = np.vstack([X[None, :], o.pts[k + 1:]])
        o.h = np.r_[h, o.h[k + 1:]]


def fix_one(edges, meta, ei, ki, ti, ej, kj, tj, X, log):
    A, B = edges[ei], edges[ej]
    sa, la = arc_at(A, ki, ti)
    sb, lb = arc_at(B, kj, tj)
    ca = end_node(edges, meta, ei, sa, la, X)
    cb = end_node(edges, meta, ej, sb, lb, X)
    # la pieza que queda del otro lado del cruce no puede ser corta
    for (c, s_, l_) in ((ca, sa, la), (cb, sb, lb)):
        if c is not None and c[2] > TOUCH:  # (un «T» ya apoyado, a menos de TOUCH, no recorta la calle: no importa cuánto mida)
            far = (l_ - s_) if c[1] == "a" else s_
            if far < MIN_PIECE:
                log.append("sin arreglar: calle de menos de %.0f m" % MIN_PIECE)
                return False
    if ca is not None and cb is not None:
        if ca[0] == cb[0]:
            return True
        da, db = deg(edges, ca[0]), deg(edges, cb[0])
        # el nodo con más calles se queda donde está y el otro se suelda a él; si los dos son puntas, se juntan en X
        keep, drop = (ca, cb) if da >= db else (cb, ca)
        if FH.KIND_LIST[int(meta["nodes"][drop[0]][3])] in FH.LOCKED_KINDS or (min(da, db) >= 3):
            log.append("sin arreglar: dos nodos con calles (%d y %d)" % (da, db))
            return False
        if FH.KIND_LIST[int(meta["nodes"][keep[0]][3])] in FH.LOCKED_KINDS and max(da, db) < 3:
            log.append("sin arreglar: nodo de pueblo")
            return False
        if max(da, db) < 3:
            truncate_at(A, ca[1], ki, X)
            truncate_at(B, cb[1], kj, X)
            move_node(edges, meta, keep[0], X)
        weld(edges, meta, keep[0], drop[0])
        return True
    cand, other, o_k, o_t, o_s, o_l, own = (ca, ej, kj, tj, sb, lb, ei) if ca is not None else ((cb, ei, ki, ti, sa, la, ej) if cb is not None else (None, None, None, None, None, None, None))
    if cand is not None:
        if not movable(edges, meta, cand):
            log.append("sin arreglar: el extremo de una calle es un nodo de pueblo o está muy ocupado (a %.1f m)" % cand[2])
            return False
        if o_s < MIN_PIECE or o_l - o_s < MIN_PIECE:
            log.append("sin arreglar: la otra calle quedaría con una pieza de menos de %.0f m" % MIN_PIECE)
            return False
        truncate_at(edges[own], cand[1], ki if own == ei else kj, X)
        move_node(edges, meta, cand[0], X)
        kv = insert_vertex(edges[other], o_k, X)
        split_vertex(edges, meta, other, kv, node=cand[0])
        return True
    # cruce de verdad: nodo nuevo en X, se parten las dos
    if sa < MIN_PIECE or la - sa < MIN_PIECE or sb < MIN_PIECE or lb - sb < MIN_PIECE:
        log.append("sin arreglar: pieza corta (%.0f/%.0f, %.0f/%.0f)" % (sa, la - sa, sb, lb - sb))
        return False
    kva = insert_vertex(A, ki, X)
    e2a, nid = split_vertex(edges, meta, ei, kva)
    kvb = insert_vertex(B, kj, X)
    split_vertex(edges, meta, ej, kvb, node=nid)
    return True


def run(path, out=None, check=False, heights=True):
    d = binio.read_all(path)
    meta = d["meta"]
    edges = AC.load(d)
    todo = find_crossings(meta, edges)
    print("cruces de calles sin nodo: %d" % len(todo))
    if check:
        return len(todo)
    total_fixed = 0
    failed = set()
    for rnd in range(6):
        if rnd:
            todo = find_crossings(meta, edges)
            todo = [t for t in todo if (round(float(t[6][0])), round(float(t[6][1]))) not in failed]
            if not todo:
                break
        touched = set()
        n_ok = 0
        for (ei, ki, ti, ej, kj, tj, X) in todo:
            if ei in touched or ej in touched:
                continue
            log = []
            ok = fix_one(edges, meta, ei, ki, ti, ej, kj, tj, X, log)
            if ok:
                touched.add(ei)
                touched.add(ej)
                n_ok += 1
            else:
                failed.add((round(float(X[0])), round(float(X[1]))))
                print("  (%.0f, %.0f) %s × %s: %s" % (X[0], X[1], edges[ei].name or "calle", edges[ej].name or "calle", "; ".join(log)))
        total_fixed += n_ok
        print("vuelta %d: %d arreglados" % (rnd + 1, n_ok))
        if n_ok == 0:
            break
    dest = out or path
    AC.write(d, meta, edges, dest)
    print("cruces arreglados: %d · sin arreglar: %d · escrito %s" % (total_fixed, len(failed), dest))
    if heights:
        FH.patch(dest)
    return total_fixed


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
