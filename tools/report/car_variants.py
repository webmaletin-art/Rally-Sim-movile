#!/usr/bin/env python3
"""(Herramienta del informe de autos; no toca el juego.) Genera, a partir de las carrocerías en baja de cada auto, cuatro versiones más livianas en formato .pap
(triángulos con un color liso por cara, como el papercraft del juego): cajas apiladas, cajas con rampas, low-poly facetado y papercraft.
Salida: <carpeta>/<auto>_<variante>.pap y <carpeta>/variants.json (triángulos de cada una). Uso: python3 car_variants.py [carpeta de salida]"""
import json, math, os, struct, sys
import numpy as np
import trimesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
G = os.path.join(ROOT, 'godot', 'game')
OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/cars'
os.makedirs(OUT, exist_ok=True)
BODY = tuple(int(x) for x in os.environ.get('BODY', '192,24,28').split(','))
GLASS = (36, 52, 70)
DARK = (28, 28, 32)
RIM = (170, 175, 185)
rng = np.random.default_rng(3)
vehicles = json.load(open(os.path.join(G, 'data', 'vehicles.json')))

def body_path(vid):
    if vid == 'genesis_glb':  # el GLB propio del Genesis (hoy sin usar en el juego)
        return os.path.join(G, 'models', 'genesis_body_lo.glb'), None
    vt = vehicles[vid]['visualType']
    if vt in ('genesis', 't1plus'):  # en el juego los dos usan la carrocería del Volt
        return os.path.join(G, 'models', 'volt_body_lo.glb'), None
    return os.path.join(G, 'models', 'cars', vt + '_lo.glb'), os.path.join(G, 'models', 'cars', vt + '.json')

def wheels_of(vid, mesh):
    v = vehicles['genesis' if vid == 'genesis_glb' else vid]
    R = float(v['wheelRadius'])
    wb = float(v['wheelBase'])
    zc = (mesh.bounds[0][2] + mesh.bounds[1][2]) / 2
    _, jp = body_path(vid)
    if jp and os.path.exists(jp):
        j = json.load(open(jp))
        return [(a['z'], a['yc'] if 'yc' in a else R, a['x_out']) for a in j['arches']], R, float(v['tireWidth'])
    return [(zc + wb / 2, R, float(v['trackF']) / 2), (zc - wb / 2, R, float(v['trackF']) / 2)], R, float(v['tireWidth'])

def box_tris(c, s, col):
    x0, y0, z0 = c[0] - s[0] / 2, c[1] - s[1] / 2, c[2] - s[2] / 2
    x1, y1, z1 = c[0] + s[0] / 2, c[1] + s[1] / 2, c[2] + s[2] / 2
    P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    F = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4), (3, 6, 2), (3, 7, 6), (0, 4, 7), (0, 7, 3), (1, 2, 6), (1, 6, 5)]
    return [([P[a], P[b], P[c2]], col) for a, b, c2 in F]

def cyl_tris(c, R, w, n, col, rim=True):
    """Rueda con el eje en X"""
    t = []
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        p = lambda a, x: (c[0] + x, c[1] + math.sin(a) * R, c[2] + math.cos(a) * R)
        for (x_a, x_b) in [(-w / 2, w / 2)]:
            t.append(([p(a0, x_a), p(a1, x_a), p(a1, x_b)], col))
            t.append(([p(a0, x_a), p(a1, x_b), p(a0, x_b)], col))
        for sgn, cc in ((-1, col), (1, RIM if rim else col)):
            x = sgn * w / 2
            t.append(([(c[0] + x, c[1], c[2]), p(a1, x) if sgn > 0 else p(a0, x), p(a0, x) if sgn > 0 else p(a1, x)], cc))
    return t

def wheel_set(ws, R, tw, n, use_box, hw=None):
    t = []
    for z, y, xo in ws:
        for sx in (-1, 1):
            out = max(xo, (hw or 0.0) - 0.04) + 0.14  # cara de afuera de la goma: sobresale un poco para que se vea la rueda
            c = (sx * (out - tw * 0.5), R, z)
            if use_box:
                t += box_tris(c, (tw, 2 * R * 0.92, 2 * R * 0.92), DARK)
            else:
                t += cyl_tris(c, R, tw, n, DARK)
    return t

def slices(mesh, k):
    """k capas horizontales: (y0, y1, zmin, zmax, semiancho) medidos con los vértices"""
    v = mesh.vertices
    y0, y1 = v[:, 1].min(), v[:, 1].max()
    H = y1 - y0
    cuts = [y0 + H * f for f in ([0.0, 0.34, 0.50, 0.62, 0.74, 0.86, 1.0] if k == 5 else [0.0, 0.5, 0.7, 1.0])]
    out = []
    for a, b in zip(cuts, cuts[1:]):
        m = (v[:, 1] >= a - 1e-6) & (v[:, 1] <= b + 1e-6)
        if m.sum() < 3:
            continue
        p = v[m]
        out.append((a, b, np.percentile(p[:, 2], 1.5), np.percentile(p[:, 2], 98.5), np.percentile(np.abs(p[:, 0]), 97)))
    return out, y0, y1

def stacked(mesh, ws, R, tw):
    sl, y0, y1 = slices(mesh, 5)
    t = []
    H = y1 - y0
    for i, (a, b, z0, z1, hw) in enumerate(sl):
        col = GLASS if (a > y0 + 0.57 * H and b < y0 + 0.9 * H) else BODY
        t += box_tris(((0), (a + b) / 2, (z0 + z1) / 2), (2 * hw, b - a, z1 - z0), col)
    return t + wheel_set(ws, R, tw, 8, True, sl[0][4])

def lofted(mesh, ws, R, tw):
    """Entre cada capa y la siguiente, un tronco de pirámide (rampa): parabrisas, capó y luneta inclinados"""
    sl, y0, y1 = slices(mesh, 5)
    H = y1 - y0
    t = []
    def rect(y, z0, z1, hw):
        return [(-hw, y, z0), (hw, y, z0), (hw, y, z1), (-hw, y, z1)]
    for i, (a, b, z0, z1, hw) in enumerate(sl):
        top_scale = 0.94
        if i + 1 < len(sl):
            na = sl[i + 1]
            zt0, zt1, hwt = (z0 + na[2]) / 2, (z1 + na[3]) / 2, (hw + na[4]) / 2
        else:
            zt0, zt1, hwt = z0 + (z1 - z0) * 0.12, z1 - (z1 - z0) * 0.12, hw * 0.8
        bot = rect(a, z0, z1, hw)
        top = rect(b, zt0, zt1, hwt)
        col = GLASS if (a > y0 + 0.57 * H and b < y0 + 0.92 * H) else BODY
        for j in range(4):
            k = (j + 1) % 4
            t.append(([bot[j], bot[k], top[k]], col))
            t.append(([bot[j], top[k], top[j]], col))
        t.append(([top[0], top[1], top[2]], BODY))
        t.append(([top[0], top[2], top[3]], BODY))
    return t + wheel_set(ws, R, tw, 8, False, sl[0][4])

def solid(mesh, pitch):
    """Malla cerrada: se voxeliza la carrocería (rellena) y se vuelve a sacar la superficie; así la simplificación no deja agujeros"""
    vox = mesh.voxelized(pitch).fill()
    m = vox.marching_cubes
    m.apply_transform(vox.transform)  # marching_cubes devuelve índices de voxel: se llevan a metros
    return m

def decimated(mesh, ws, R, tw, faces, jitter, wn):
    mesh = solid(mesh, 0.09)
    mesh = trimesh.smoothing.filter_taubin(mesh, iterations=6) or mesh
    d = mesh.simplify_quadric_decimation(face_count=faces)
    v = d.vertices
    y0, y1 = v[:, 1].min(), v[:, 1].max()
    H = y1 - y0
    t = []
    for f in d.faces:
        p = v[f]
        c = p.mean(axis=0)
        n = np.cross(p[1] - p[0], p[2] - p[0])
        nl = np.linalg.norm(n)
        if nl < 1e-9:
            continue
        n = n / nl
        # si la cara mira hacia adentro (malla invertida) se da vuelta
        if np.dot(n, c - np.array([0, (y0 + y1) / 2, c[2]])) < 0 and abs(n[1]) < 0.9:
            p = p[::-1]
            n = -n
        glass = c[1] > y0 + 0.57 * H and c[1] < y0 + 0.92 * H and abs(n[1]) < 0.75
        col = np.array(GLASS if glass else BODY, dtype=float)
        if jitter:
            col = np.clip(col * (1.0 + rng.uniform(-jitter, jitter)), 0, 255)
        t.append(([tuple(q) for q in p], tuple(col.astype(int))))
    return t + wheel_set(ws, R, tw, wn, False, float(np.abs(v[:, 0]).max()) * 0.97)

def write_pap(path, tris):
    pos = np.array([q for (p, c) in tris for q in p], dtype='<f4')
    col = np.array([list(c) + [255] for (p, c) in tris for _ in range(3)], dtype='u1')
    with open(path, 'wb') as f:
        f.write(b'PAP1')
        f.write(struct.pack('<I', len(pos)))
        f.write(pos.tobytes())
        f.write(col.tobytes())

def main():
    stats = {}
    only = os.environ.get('ONLY')
    for vid in (only.split(',') if only else list(vehicles) + ['genesis_glb']):
        bp, _ = body_path(vid)
        sc = trimesh.load(bp, force='scene')
        mesh = trimesh.util.concatenate([g for g in sc.geometry.values()])
        mesh.merge_vertices()
        ws, R, tw = wheels_of(vid, mesh)
        if len(ws) == 2 and not os.path.exists(body_path(vid)[1] or ''):
            pass
        # los GLB con json traen 2 ejes (z, y, x_out): cada eje son 2 ruedas
        variants = {
            'cajas': stacked(mesh, ws, R, tw),
            'rampas': lofted(mesh, ws, R, tw),
            'lowpoly': decimated(mesh, ws, R, tw, 380, 0.0, 10),
            'papel': decimated(mesh, ws, R, tw, 1100, 0.07, 12),
        }
        stats[vid] = {'body_lo_tris': int(len(mesh.faces))}
        for k, tris in variants.items():
            write_pap(os.path.join(OUT, '%s_%s.pap' % (vid, k)), tris)
            stats[vid][k] = len(tris)
        print(vid, stats[vid])
    json.dump(stats, open(os.path.join(OUT, 'variants.json'), 'w'))

main()
