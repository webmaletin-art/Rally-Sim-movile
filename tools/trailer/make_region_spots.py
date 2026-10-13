#!/usr/bin/env python3
"""Lugares lindos de la REGIÓN de Dream City para el tráiler: elige sobre las rutas de `region_1.bin` curvas de montaña con subida, autopistas, la circunvalación junto al mar, un cruce con plazoleta, un pueblo, un peaje y los ramales nuevos,
y arma un trabajo del director por lugar (el auto puesto sobre el eje de la ruta mirando hacia donde sigue, cinco cámaras a ras y dos vistas de dron).
Uso: python3 tools/trailer/make_region_spots.py /carpeta_de_trabajos /carpeta_de_fotos [--list]
`--list` sólo muestra los lugares elegidos (sin escribir trabajos)."""
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'world_gen'))
import binio  # noqa: E402
import add_connectors as AC  # noqa: E402

BIN = os.path.join(ROOT, 'godot', 'game', 'data', 'region', 'region_1.bin')

# cámaras a ras (relativas al auto): nombre, cámara, fov, near
GROUND = [
    ('a_front', {'orbit': {'a': 28, 'r': 6.5, 'h': 0.8, 'lh': 0.7}}, 38, 2.0),
    ('b_low', {'orbit': {'a': 18, 'r': 4.2, 'h': 0.45, 'lh': 0.8}}, 66, 2.0),
    ('c_rear', {'orbit': {'a': 165, 'r': 9.0, 'h': 2.4, 'lh': 0.9}}, 46, 2.0),
    ('e_side', {'orbit': {'a': 80, 'r': 9.0, 'h': 1.1, 'lh': 0.8}}, 32, 3.0),
    ('f_wide', {'orbit': {'a': 150, 'r': 17.0, 'h': 5.0, 'lh': 1.0}}, 50, 3.0),
]
# vistas de dron (cámara relativa: der, alto, adelante)
DRONE = [
    ('d1_alto_atras', {'rel': [0, 110, -90], 'look': [0, 0, 220]}, 58, 3.0),
    ('d3_lateral', {'rel': [160, 70, -40], 'look': [0, 5, 80]}, 50, 3.0),
]


def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


class Road:
    def __init__(self, i, o):
        self.i = i
        self.o = o
        self.cl = AC.cumlen(o.pts)
        self.L = float(self.cl[-1])

    def at(self, s):
        s = min(max(s, 0.0), self.L)
        x = float(np.interp(s, self.cl, self.o.pts[:, 0]))
        z = float(np.interp(s, self.cl, self.o.pts[:, 1]))
        h = float(np.interp(s, self.cl, self.o.h))
        return x, z, h

    def heading(self, s, w=25.0):
        x0, z0, _ = self.at(s - w)
        x1, z1, _ = self.at(s + w)
        return math.atan2(x1 - x0, z1 - z0)


def pose(r, s, reverse=False):
    """Punto del eje y rumbo en grados (hacia donde sigue la ruta; con reverse, al revés)."""
    x, z, h = r.at(s)
    hd = r.heading(s)
    if reverse:
        hd = wrap(hd + math.pi)
    return x, z, math.degrees(hd), h


def best_bend(r, lo, hi, climb=None, margin=300.0, step=30.0, want=None):
    """s donde el rumbo cambia entre lo y hi grados en ±150 m (la curva más cercana a `want`, grados) y (con climb) sube al menos tantos metros hacia adelante."""
    best = None
    s = margin
    while s < r.L - margin:
        d = abs(math.degrees(wrap(r.heading(s + 150) - r.heading(s - 150))))
        sgn = 1.0
        _, _, h0 = r.at(s - 150)
        _, _, h1 = r.at(s + 150)
        dh = h1 - h0
        ok = lo <= d <= hi
        rev = False
        if climb is not None:
            if abs(dh) < climb:
                ok = False
            rev = dh < 0  # subiendo hacia atrás: se da vuelta para mirar hacia arriba
        if ok:
            score = abs(d - (want if want is not None else (lo + hi) / 2))
            if best is None or score < best[0]:
                best = (score, s, rev, d, abs(dh))
        s += step
    return best


def main():
    a = sys.argv[1:]
    list_only = '--list' in a
    a = [x for x in a if x != '--list']
    jobs_dir, out_dir = (a + ['/tmp/trailer/jobs', '/tmp/trailer/stills/world/spots'])[:2]
    d = binio.read_all(BIN)
    meta = d['meta']
    edges = AC.load(d)
    roads = [Road(i, o) for i, o in enumerate(edges)]
    spots = []  # (nombre, auto, hora, x, z, yaw, comentario)

    def add(name, car, tod, x, z, yaw, note):
        spots.append((name, car, tod, x, z, yaw, note))

    used = set()

    def pick_edge(cls, minL, names=None, skip=()):
        cand = [r for r in roads if r.o.cls == cls and r.L >= minL and r.i not in used and r.i not in skip and (names is None or r.o.name in names)]
        cand.sort(key=lambda r: -r.L)
        return cand

    # 1-3 · curvas de montaña subiendo
    n = 0
    for r in pick_edge('montana', 2500):
        b = best_bend(r, 55, 125, climb=14, want=85)
        if b is None:
            continue
        _, s, rev, dg, dh = b
        x, z, yaw, h = pose(r, s, rev)
        add('montana_%d' % (n + 1), ['rally80', 'kodiak', 'gt3'][n % 3], [17.8, 9.0, 18.3][n % 3], x, z, yaw, '%s curva de %.0f° con %.0f m de subida (h=%.0f m)' % (r.o.name, dg, dh, h))
        used.add(r.i)
        n += 1
        if n >= 3:
            break
    # 4 · los ramales nuevos RP-84..93 (de montaña o provincial)
    n = 0
    for r in sorted([r for r in roads if r.o.name.startswith('RP-') and r.o.name[3:].isdigit() and 84 <= int(r.o.name[3:]) <= 93 and r.L > 1500], key=lambda r: -r.L):
        b = best_bend(r, 30, 110, want=60)
        if b is None:
            continue
        _, s, rev, dg, dh = b
        x, z, yaw, h = pose(r, s, False)
        add('ramal_%s' % r.o.name.lower().replace('-', ''), ['pickup', 'camo'][n % 2], [17.9, 18.4][n % 2], x, z, yaw, '%s ramal nuevo, curva de %.0f° (h=%.0f m)' % (r.o.name, dg, h))
        n += 1
        if n >= 2:
            break
    # 5-6 · autopista: una curva abierta y un tramo largo
    n = 0
    for r in pick_edge('autopista', 6000):
        b = best_bend(r, 12, 40, want=26, margin=900.0)
        if b is None:
            continue
        _, s, rev, dg, dh = b
        x, z, yaw, h = pose(r, s, False)
        add('autopista_%d' % (n + 1), ['veltor_gtr', 'hyper'][n % 2], [18.1, 17.6][n % 2], x, z, yaw, '%s curva abierta de %.0f° (h=%.0f m)' % (r.o.name, dg, h))
        used.add(r.i)
        n += 1
        if n >= 2:
            break
    # 7 · circunvalación: el tramo de menor altura (junto al mar), a la mitad
    ring = [r for r in roads if r.o.cls == 'anillo' and r.L > 700]
    if ring:
        r = min(ring, key=lambda r: float(np.mean(r.o.h)))
        x, z, yaw, h = pose(r, r.L * 0.5, False)
        add('anillo_costa', 'muscle', 18.2, x, z, yaw, '%s circunvalación a %.0f m de altura' % (r.o.name, h))
    # 8 · cruce con plazoleta: un nodo de 4 calles o más entre rutas
    deg = {}
    for r in roads:
        deg.setdefault(r.o.a, []).append(r)
        deg.setdefault(r.o.b, []).append(r)
    cand = []
    for ni, lst in deg.items():
        majors = [r for r in lst if r.o.cls in ('autopista', 'ruta', 'provincial')]
        if len(lst) >= 4 and len(majors) >= 3:
            nd = meta['nodes'][ni]
            cand.append((len(lst), ni, majors))
    cand.sort(key=lambda t: -t[0])
    for _, ni, majors in cand[:1]:
        r = majors[0]
        nd = meta['nodes'][ni]
        if r.o.a == ni:
            s, rev = 45.0, True  # la ruta sale del nodo: el auto está a 45 m del nodo mirando hacia él
        else:
            s, rev = r.L - 45.0, False
        x, z, yaw, h = pose(r, s, rev)
        add('cruce_plazoleta', 'trilux_s', 17.7, x, z, yaw, 'nodo %s con %d calles' % (nd[0], len(deg[ni])))
    # 9 · un pueblo: una calle de acceso a unos 85 m del centro, mirando hacia él
    for ni, nd in enumerate(meta['nodes']):
        if meta['kinds'][nd[3]] != 'pueblo':
            continue
        lst = [r for r in deg.get(ni, []) if r.o.cls in ('calle', 'provincial', 'camino', 'ruta') and r.L > 80]
        if not lst:
            continue
        r = max(lst, key=lambda r: r.L)
        k = min(r.L - 8.0, 85.0)
        if r.o.a == ni:
            s, rev = k, True
        else:
            s, rev = r.L - k, False
        x, z, yaw, h = pose(r, s, rev)
        add('pueblo_%s' % str(nd[4]).lower().replace(' ', '_'), 'hatch2', 17.5, x, z, yaw, 'pueblo %s' % nd[4])
        break
    # 10 · un peaje (el primero que no sea secreto)
    for t in meta['tolls'][:1]:
        yaw = math.degrees(math.atan2(t['tx'], t['tz']))
        # 40 m antes de la cabina
        x = t['x'] - t['tx'] * 40
        z = t['z'] - t['tz'] * 40
        add('peaje', 'pickup', 18.0, x, z, yaw, t['name'])
        break
    # 11 · el conector que sale de la ciudad hacia la región (ciudad_salida): 250 m después del nodo, mirando hacia afuera
    for ni, nd in enumerate(meta['nodes']):
        if meta['kinds'][nd[3]] != 'ciudad_salida':
            continue
        lst = [r for r in deg.get(ni, []) if r.o.cls == 'conector' and r.L > 600]
        if not lst:
            continue
        r = lst[0]
        if r.o.a == ni:
            s, rev = 250.0, False
        else:
            s, rev = r.L - 250.0, True
        x, z, yaw, h = pose(r, s, rev)
        add('salida_ciudad', 'hyper', 18.0, x, z, yaw, 'salida de la ciudad por %s (%s)' % (r.o.name, nd[0]))
        break
    # 12 · una provincial con curva (verde)
    for r in pick_edge('provincial', 4000):
        b = best_bend(r, 25, 70, want=45, margin=500.0)
        if b is None:
            continue
        _, s, rev, dg, dh = b
        x, z, yaw, h = pose(r, s, False)
        add('provincial_curva', 'moust', 17.4, x, z, yaw, '%s curva de %.0f° (h=%.0f m)' % (r.o.name, dg, h))
        break

    for sp in spots:
        print('%-22s %-11s %5.1f h  (%9.1f, %9.1f) %7.1f°  %s' % sp)
    if list_only:
        return
    os.makedirs(jobs_dir, exist_ok=True)
    for name, car, tod, x, z, yaw, note in spots:
        shots = []
        for k, (n_, cam, fov, near) in enumerate(GROUND):
            shots.append({'name': n_, 'cam': cam, 'fov': fov, 'near': near, 'wait': 90 if k == 0 else 6})
        for n_, cam, fov, near in DRONE:
            shots.append({'name': n_, 'cam': cam, 'fov': fov, 'near': near, 'wait': 30})
        cfg = {'type': 'city', 'track': 'aurelia', 'ai': 0, 'sky': 'day', 'seed': 7, 'back': 'home', 'quick': True, 'spawn': 0, 'online': False, 'tod': tod, 'tod_frozen': True}
        j = {'mode': 'world', 'out': os.path.join(out_dir, name), 'car': car, 'cfg': cfg, 'env': {'DR_POS': '%.1f,%.1f,%.1f' % (x, z, yaw)}, 'shots': shots}
        json.dump(j, open(os.path.join(jobs_dir, 'spot_%s.json' % name), 'w'), indent=1)
    print(len(spots), 'lugares →', jobs_dir)


if __name__ == '__main__':
    main()
