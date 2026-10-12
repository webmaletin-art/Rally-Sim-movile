#!/usr/bin/env python3
"""Arma los autos definitivos a partir de los modelos con textura (ver final_cars.py).
Uso: python3 tools/cars/build_final.py <id> [<id> …]   (sin ids: todos)
Escribe en godot/game/models/cars/: <id>.glb (carrocería COMPLETA, sin reducir, con su textura de color), <id>_lo.glb (~6 mil triángulos con la misma textura, para los rivales) y <id>.json."""
import sys, os, json, time
import numpy as np, trimesh
from scipy.spatial import cKDTree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_car as bc            # funciones de medición (piel, vidrio, perfil, normales)
from fit import arch_fit
import final_cars as FC
import final_wheels as FW

OUT = os.path.join(HERE, '..', '..', 'godot', 'game', 'models', 'cars')
LO_FACES = 6000

def load_raw(path, rot):
    sc = trimesh.load(path, force='scene', process=False)
    m = sc.to_geometry() if isinstance(sc, trimesh.Scene) else sc
    V = np.asarray(m.vertices, dtype=np.float64).copy()
    F = np.asarray(m.faces, dtype=np.int64).copy()
    N = np.asarray(m.vertex_normals, dtype=np.float64).copy()
    UV = np.asarray(m.visual.uv, dtype=np.float64).copy()
    img = m.visual.material.baseColorTexture
    a = np.radians(rot)
    R = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    V = V @ R.T
    N = N @ R.T
    V[:, 0] -= (V[:, 0].min() + V[:, 0].max()) / 2
    V[:, 2] -= (V[:, 2].min() + V[:, 2].max()) / 2
    V[:, 1] -= V[:, 1].min()
    return V, F, N, UV, img

def export_glb(path, V, F, N, UV, img):
    mat = trimesh.visual.material.PBRMaterial(baseColorTexture=img, metallicFactor=0.3, roughnessFactor=0.5)
    m = trimesh.Trimesh(V, F, visual=trimesh.visual.TextureVisuals(uv=UV, material=mat), vertex_normals=N, process=False)
    data = m.export(file_type='glb', include_normals=True)
    open(path, 'wb').write(data)
    return len(data)

def project_uv(Vraw, Fraw, UVraw, P):
    """UV de puntos P (la versión liviana) tomados del triángulo más cercano del modelo completo."""
    tri = Vraw[Fraw]
    cen = tri.mean(1)
    tree = cKDTree(cen)
    _, idx = tree.query(P, k=1)
    t = tri[idx]
    # proyección al plano del triángulo y coordenadas baricéntricas
    bary = trimesh.triangles.points_to_barycentric(t, P)
    bary = np.clip(bary, 0, 1)
    bary /= np.maximum(bary.sum(1, keepdims=True), 1e-9)
    uv = UVraw[Fraw[idx]]            # (n, 3, 2)
    return (bary[:, :, None] * uv).sum(1)

def build(cid):
    t0 = time.time()
    cfg = FC.MODEL[cid]
    W = FW.WHEEL[cid]
    V, F, N, UV, img = load_raw(os.path.join(FC.SRC_DIR, cfg['src']), cfg['rot'])
    Lunit = V[:, 2].max() - V[:, 2].min()
    hxu = np.abs(V[:, 0]).max()
    # largo: por la cfg o por la distancia entre ejes de la física que ya tenía el auto
    Vu = V / Lunit
    if 'arches' in cfg:
        arch_u = [dict(z=float(z), y=float(yc), r=float(r), top=float(yc + r)) for z, yc, r in cfg['arches']]
    else:
        arch_u = [a for a in arch_fit(Vu, hxu / Lunit) if a['r'] < 0.14]
    assert len(arch_u) == 2, (cid, arch_u)
    rear_u, front_u = sorted(arch_u, key=lambda a: a['z'])
    span_u = front_u['z'] - rear_u['z']
    phys = cfg.get('phys')
    L = phys['wb'] / span_u if phys else cfg['L']
    s = L / Lunit
    V *= s
    # alto real del auto: los modelos de IA salen más altos de lo que corresponde (se aprieta en y, sin tocar el largo ni el ancho)
    g0 = float(cfg.get('ground', 0.12))
    ysc = 1.0
    if 'H' in cfg:
        ysc = (cfg['H'] - g0) / V[:, 1].max()
        V[:, 1] *= ysc
        N[:, 1] /= ysc
    # pasos de rueda en el auto ya escalado
    if 'arches' in cfg:
        arch_m = [dict(z=a['z'] * L, y=a['y'] * L * ysc, r=a['r'] * L, top=(a['y'] + a['r']) * L * ysc) for a in arch_u]
    else:
        arch_m = [a for a in arch_fit(V, np.abs(V[:, 0]).max()) if a['r'] < 0.14 * L]
    assert len(arch_m) == 2, (cid, arch_m)
    rear_m, front_m = sorted(arch_m, key=lambda a: a['z'])
    wheelbase = float(front_m['z'] - rear_m['z'])
    r_m = (rear_m['r'] + front_m['r']) / 2
    top = (rear_m['top'] + front_m['top']) / 2
    W = FW.WHEEL[cid]
    wscale = cfg['wscale']
    gap = cfg['gap']
    if 'R' in cfg or phys:
        R = float(cfg['R'] if 'R' in cfg else phys['R'])
        ground = float(2 * R + gap - top)          # radio de rueda fijo: la carrocería se levanta lo que haga falta
    else:
        ground = g0                                # luz al piso fija: la rueda llena el paso hasta una luz «gap»
        R = float((top + ground - gap) / 2)
    if phys:      # la trocha de la física fija el ancho
        tw = float(W['tw'])
        sel = (np.abs(V[:, 2] - front_m['z']) < r_m * 0.9) & (V[:, 1] > top * 0.35) & (V[:, 1] < top)
        xo = np.abs(V[sel, 0]).max() if sel.any() else np.abs(V[:, 0]).max()
        wscale = (phys['trackF'] / 2 + tw / 2 - 0.02) / xo
    V[:, 0] *= wscale
    N[:, 0] /= wscale
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    a_f = wheelbase * (1 - cfg['wf'])
    b_r = wheelbase * cfg['wf']
    dz = a_f - front_m['z']
    V[:, 1] += ground
    V[:, 2] += dz
    if 'ymap' in cfg:      # deformación vertical por tramos (y de entrada → y de salida, en el auto ya apoyado): baja el techo y el zócalo sin tocar los pasos de rueda
        xp, fp = zip(*cfg['ymap'])
        xp, fp = np.array(xp), np.array(fp)
        slope = np.interp(V[:, 1], (xp[1:] + xp[:-1]) / 2, np.diff(fp) / np.diff(xp))
        V[:, 1] = np.interp(V[:, 1], xp, fp)
        N[:, 1] /= slope
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    arches = []
    for a in (rear_m, front_m):
        arches.append(dict(z=float(a['z'] + dz), y=float(R), yc=float(a['y'] + ground), r=float(a['r']), x_out=0.0))
    H = float(V[:, 1].max())
    hw = float(np.abs(V[:, 0]).max())
    for a in arches:
        sel = (np.abs(V[:, 2] - a['z']) < a['r'] * 0.9) & (V[:, 1] > R * 0.4) & (V[:, 1] < 2 * R)
        a['x_out'] = float(np.abs(V[sel, 0]).max()) if sel.any() else hw
    print('  %-10s L=%.2f R=%.3f suelo=%.3f entre ejes=%.3f ancho=%.2f alto=%.2f  [%.0fs]' % (cid, L, R, ground, wheelbase, 2 * hw, H, time.time() - t0), flush=True)
    # piel cerrada y lisa (solo para MEDIR el perfil del techo y para la versión liviana)
    skinV, skinF = bc.remesh_skin(V, F, cfg.get('voxel', 0.02), close=cfg.get('close', 4))
    glass_meta = None
    if cfg['glass'] is not None:
        if cfg['glass'] == 'auto':
            gp = bc.auto_glass(skinV, skinF, L, ground, cfg.get('belt_k', 0.64), cfg.get('ws_len'), cfg.get('rg_len'))
            glass = [(float(z), float(y)) for z, y in gp]
        else:                                          # polígono a mano (z, y) en el auto ya armado: base del parabrisas, borde de arriba, borde del techo atrás, base de la luneta
            glass = [(float(z), float(y)) for z, y in cfg['glass']]
        seg = bc.glass_segments(skinV, skinF, glass, {})
        ytop = max(p[1] for p in glass[1:3])
        zlo, zhi = min(p[0] for p in glass[1:3]), max(p[0] for p in glass[1:3])
        selr = (skinV[:, 1] > ytop - 0.07) & (skinV[:, 2] > zlo) & (skinV[:, 2] < zhi)
        hw_cab = float(np.abs(skinV[selr, 0]).max()) if selr.any() else 0.8 * hw
        glass_meta = dict(poly=glass, cab_hw=hw_cab, **seg)
    meta = dict(id=cid, L=float(L), H=H, hw=hw, scale=float(s), wheelbase=float(wheelbase), a=float(a_f), b=float(b_r), R=float(R), lift=float(ground),
                weightFront=cfg['wf'], arch_top=float(top + ground), arches=arches, glass=glass_meta, wheel=W, textured=True,
                tex=FW.TEX.get(cid, {}))
    # carrocería completa
    os.makedirs(OUT, exist_ok=True)
    nbytes = export_glb(os.path.join(OUT, cid + '.glb'), V, F, N, UV, img)
    # versión liviana: la piel simplificada con la textura proyectada
    pv, pf = bc.simplify(skinV, skinF, LO_FACES, 6)
    V2, F2, N2 = bc.vertex_normals(pv, pf, 50.0)
    UV2 = project_uv(V, F, UV, V2)
    nlo = export_glb(os.path.join(OUT, cid + '_lo.glb'), V2, F2, N2, UV2, img)
    meta['tris'] = [int(len(F)), 0]
    meta['tris_lo'] = int(len(F2))
    json.dump(meta, open(os.path.join(OUT, cid + '.json'), 'w'), indent=1)
    print('     %s: %d triángulos, %.1f MB · lo %d triángulos, %.0f KB  [%.0fs]' % (cid, len(F), nbytes / 1e6, len(F2), nlo / 1e3, time.time() - t0), flush=True)

def refresh_meta(cid):
    """Solo actualiza en el json las ruedas y los canales de color de la textura (sin rehacer el modelo)."""
    f = os.path.join(OUT, cid + '.json')
    m = json.load(open(f))
    m['wheel'] = FW.WHEEL[cid]
    m['tex'] = FW.TEX.get(cid, {})
    json.dump(m, open(f, 'w'), indent=1)

if __name__ == '__main__':
    if sys.argv[1:2] == ['--meta']:
        for cid in (sys.argv[2:] or FC.IDS):
            refresh_meta(cid)
        sys.exit(0)
    ids = sys.argv[1:] or FC.IDS
    for cid in ids:
        build(cid)
