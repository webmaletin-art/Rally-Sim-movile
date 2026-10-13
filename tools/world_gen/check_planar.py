#!/usr/bin/env python3
"""Revisa que ninguna ruta cruce a otra sin tener un nodo en el cruce (dos tramos que se cortan lejos de un nodo común) y que ningún par de rutas que no se tocan pase a menos de `--min` m.
Uso: python3 tools/world_gen/check_planar.py [ruta.bin] [--min 12]"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402


def seg_inter(p, q, r, s):
    """Intersección CERRADA de dos tramos: devuelve (t, u) o None. Los extremos cuentan: dos calles con un vértice justo en el mismo punto se cruzan ahí."""
    d1 = q - p
    d2 = s - r
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) < 1e-9:
        return None
    t = ((r[0] - p[0]) * d2[1] - (r[1] - p[1]) * d2[0]) / den
    u = ((r[0] - p[0]) * d1[1] - (r[1] - p[1]) * d1[0]) / den
    if -1e-9 <= t <= 1 + 1e-9 and -1e-9 <= u <= 1 + 1e-9:
        return t, u
    return None


def check(path, min_gap=12.0, verbose=True):
    d = binio.read_all(path)
    meta = d["meta"]
    P = d["P"] / 10.0
    nodes = np.array([[n[1], n[2]] for n in meta["nodes"]])
    edges = meta["edges"]
    by_cell = {}
    for ei, e in enumerate(edges):
        p0, n = int(e[6]), int(e[7])
        for k in range(p0, p0 + n - 1):
            a, b = P[k], P[k + 1]
            if np.linalg.norm(b - a) < 1e-3:
                continue
            for cx in range(int(np.floor(min(a[0], b[0]) / 64.0)), int(np.floor(max(a[0], b[0]) / 64.0)) + 1):
                for cz in range(int(np.floor(min(a[1], b[1]) / 64.0)), int(np.floor(max(a[1], b[1]) / 64.0)) + 1):
                    by_cell.setdefault((cx, cz), []).append((ei, k))
    shared = {}
    for ei, e in enumerate(edges):
        shared[ei] = {int(e[0]), int(e[1])}
    bad = []
    seen = set()
    dedup = set()
    for key, lst in by_cell.items():
        for i in range(len(lst)):
            ei, ki = lst[i]
            for j in range(i + 1, len(lst)):
                ej, kj = lst[j]
                if ei == ej or (ki, kj) in seen and False:
                    continue
                pair = (min(ki, kj), max(ki, kj))
                if pair in seen:
                    continue
                seen.add(pair)
                a, b = P[ki], P[ki + 1]
                c, e2 = P[kj], P[kj + 1]
                r = seg_inter(a, b, c, e2)
                if r is not None:
                    # ¿hay un nodo común en el cruce? (a menos de 1 m, o a menos de 45 m si el cruce es «propio», no en los extremos de los tramos)
                    x = a + (b - a) * min(max(r[0], 0.0), 1.0)
                    proper = 1e-6 < r[0] < 1 - 1e-6 and 1e-6 < r[1] < 1 - 1e-6
                    ok = False
                    for nd in shared[ei] & shared[ej]:
                        dn = float(np.linalg.norm(nodes[nd] - x))
                        if dn < 1.0 or (proper and dn < 45.0):
                            ok = True
                    if not ok:
                        key = (min(ei, ej), max(ei, ej), int(x[0] // 6), int(x[1] // 6))
                        if key in dedup:
                            continue
                        dedup.add(key)
                        bad.append((edges[ei][3] or "calle", ei, edges[ej][3] or "calle", ej, float(x[0]), float(x[1])))
    # «T sin nodo»: el nodo del extremo de una calle apoyado (a menos de 1,5 m) sobre otra calle que no tiene nodo ahí
    inc = {}
    for ei, e in enumerate(edges):
        inc.setdefault(int(e[0]), set()).add(ei)
        inc.setdefault(int(e[1]), set()).add(ei)
    for ni, lst in inc.items():
        px = nodes[ni]
        cx, cz = int(np.floor(px[0] / 64.0)), int(np.floor(px[1] / 64.0))
        found = False
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for (ej, kj) in by_cell.get((cx + dx, cz + dz), []):
                    if ej in lst or found:
                        continue
                    a, b = P[kj], P[kj + 1]
                    ab = b - a
                    t = float(np.dot(px - a, ab) / max(float(np.dot(ab, ab)), 1e-9))
                    if t <= 1e-3 or t >= 1 - 1e-3:
                        continue
                    if float(np.linalg.norm(a + ab * t - px)) < 1.5:
                        bad.append((edges[ej][3] or "calle", ej, "T con el nodo %d" % ni, ni, float(px[0]), float(px[1])))
                        found = True
    if verbose:
        print("cruces sin nodo: %d" % len(bad))
        for b in bad[:15]:
            print("  %s (%d) × %s (%s) en (%.0f, %.0f)" % b)
    return bad


if __name__ == "__main__":
    path = os.path.join(HERE, "..", "..", "godot", "game", "data", "region", "region_1.bin")
    mg = 12.0
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == "--min":
            mg = float(a[i + 1])
            i += 2
        else:
            path = a[i]
            i += 1
    bad = check(path, mg)
    sys.exit(1 if bad else 0)
