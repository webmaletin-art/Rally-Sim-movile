#!/usr/bin/env python3
"""Retoques del mapa de la región sobre region_1.bin (sin volver a generarlo), en este orden:
 1. se sacan las «espinas» de la punta de algunas rutas (el primer tramo va y vuelve: quedaba una orejita de asfalto en el nodo);
 2. los cruces de calles sin nodo (53 en los pueblos: las dos calles se pisaban, cada una a su altura) pasan a ser cruces de verdad (weld_crossings.py);
 3. se enderezan los codos de las rutas al llegar a un cruce (el primer tramo, de 3 a 7 m, salía en otra dirección y la ruta doblaba 40–90° a los pocos metros: «cuadrados» en las uniones);
 4. curvas abiertas en las rutas rectas (add_bends.py);
 5. ramales a los pueblos que quedan a unos km de una ruta principal (add_branches.py);
 6. alturas otra vez (fix_heights.py: plazoletas planas en los nodos y subidas sin dobleces).
Los empalmes entre rutas paralelas (add_connectors.py) se arman antes, en build_region.py.
Uso: python3 tools/world_gen/polish_map.py [--bin ruta.bin] [--out nueva.bin]"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import fix_heights as FH  # noqa: E402
import add_connectors as AC  # noqa: E402
import add_bends  # noqa: E402
import add_branches  # noqa: E402
import weld_crossings  # noqa: E402


def clean_spikes(path, out=None):
    """Saca el punto de la punta de una ruta cuando el primer o el último tramo es corto (menos de 8 m) y la ruta da media vuelta ahí (giro de más de 100°)."""
    d = binio.read_all(path)
    meta = d["meta"]
    edges = AC.load(d)
    n_fix = 0
    for o in edges:
        for _ in range(3):
            if len(o.pts) < 6:
                break
            changed = False
            for end in (0, 1):
                pts = o.pts if end == 0 else o.pts[::-1]
                h = o.h if end == 0 else o.h[::-1]
                # puntos repetidos pegados al nodo: se toma el primero distinto
                j = 1
                while j < len(pts) - 2 and np.linalg.norm(pts[j] - pts[0]) < 1e-3:
                    j += 1
                v1 = pts[j] - pts[j - 1] if j > 1 else pts[j] - pts[0]
                v2 = pts[j + 1] - pts[j]
                l1, l2 = float(np.linalg.norm(pts[j] - pts[0])), float(np.linalg.norm(v2))
                if l1 < 1e-3 or l2 < 1e-3 or l1 > 8.0:
                    continue
                v1 = pts[j] - pts[0]
                c = float(np.dot(v1, v2) / (l1 * l2))
                if c < -0.17:  # giro de más de ~100°
                    keep = np.ones(len(pts), dtype=bool)
                    keep[1:j + 1] = False
                    pts, h = pts[keep], h[keep]
                    if end == 0:
                        o.pts, o.h = pts, h
                    else:
                        o.pts, o.h = pts[::-1], h[::-1]
                    changed = True
                    n_fix += 1
            if not changed:
                break
    dest = out or path
    if n_fix:
        AC.write(d, meta, edges, dest)
    elif dest != path:
        AC.write(d, meta, edges, dest)
    print("espinas sacadas: %d" % n_fix)
    return n_fix


def straighten_ends(path, out=None, max_turn=18.0, reach=44.0):
    """En un cruce de 3 o más calles, cada extremo de calle con un codo de más de `max_turn`° en los primeros metros se endereza: los puntos de los primeros `reach` m se llevan hacia la recta entre el nodo y el
    punto de más allá (del todo los dos primeros, de a poco los demás). El nodo no se mueve."""
    d = binio.read_all(path)
    meta = d["meta"]
    edges = AC.load(d)
    deg = {}
    for o in edges:
        deg[o.a] = deg.get(o.a, 0) + 1
        deg[o.b] = deg.get(o.b, 0) + 1
    n_fix = 0
    for o in edges:
        for end in (0, 1):
            node = o.a if end == 0 else o.b
            if deg.get(node, 0) < 3:
                continue
            pts = o.pts if end == 0 else o.pts[::-1].copy()
            uniq = [0]
            for i in range(1, len(pts)):
                if np.linalg.norm(pts[i] - pts[uniq[-1]]) > 1e-3:
                    uniq.append(i)
            if len(uniq) < 9:
                continue
            q = pts[uniq]
            cum = np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(q, axis=0), axis=1))]
            kp = int(np.searchsorted(cum, reach))
            kp = max(4, min(kp, len(q) - 3))
            v = np.diff(q[:kp + 2], axis=0)
            ang = np.arctan2(v[:, 0], v[:, 1])
            turn = np.degrees(np.abs((np.diff(ang) + np.pi) % (2.0 * np.pi) - np.pi))
            if float(turn[:kp].max()) <= max_turn:
                continue
            p0, pk = q[0], q[kp]
            for k in range(1, kp):
                frac = cum[k] / max(cum[kp], 1e-6)
                line = p0 + (pk - p0) * frac
                w = 1.0 if k <= 2 else (1.0 - (k - 2) / float(kp - 2)) ** 1.5
                q[k] = line * w + q[k] * (1.0 - w)
            pts[uniq] = q
            if end == 0:
                o.pts = pts
            else:
                o.pts = pts[::-1].copy()
            n_fix += 1
    dest = out or path
    if n_fix or dest != path:
        AC.write(d, meta, edges, dest)
    print("extremos de calle enderezados en los cruces: %d" % n_fix)
    return n_fix


def run(path, out=None):
    dest = out or path
    clean_spikes(path, dest)
    weld_crossings.run(dest, None, False, heights=False)
    straighten_ends(dest)
    add_bends.run(dest, None, False, heights=False)
    add_branches.run(dest, None, False, heights=False)
    FH.patch(dest)


def main():
    path = os.path.join(HERE, "..", "..", "godot", "game", "data", "region", "region_1.bin")
    out = None
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == "--bin":
            path = a[i + 1]
            i += 2
        elif a[i] == "--out":
            out = a[i + 1]
            i += 2
        else:
            i += 1
    run(path, out)


if __name__ == "__main__":
    main()
