"""Analiza los GLB de los autos: medidas, pasos de rueda, cabina. Uso: python3 analyze.py car0.glb ..."""
import sys, json
import numpy as np, trimesh

def load(path):
    sc = trimesh.load(path, force='scene')
    m = trimesh.util.concatenate([g for g in sc.geometry.values()])
    m.merge_vertices()
    m.update_faces(m.nondegenerate_faces())
    return m

def arch_spans(V, hx, bins=160):
    """Pasos de rueda: franjas en z donde el borde inferior de la zona exterior (|x| > 0.7 hx) está alto."""
    z0, z1 = V[:, 2].min(), V[:, 2].max()
    low = np.full(bins, np.inf)
    sel = np.abs(V[:, 0]) > 0.72 * hx
    zb = np.clip(((V[sel, 2] - z0) / (z1 - z0) * bins).astype(int), 0, bins - 1)
    for b, y in zip(zb, V[sel, 1]):
        if y < low[b]:
            low[b] = y
    ymax = np.nanmax(low[np.isfinite(low)])
    thr = 0.45 * ymax
    spans = []
    s = -1
    zc = lambda i: z0 + (i + 0.5) * (z1 - z0) / bins
    for i in range(bins):
        inA = np.isfinite(low[i]) and low[i] > thr
        if inA and s < 0:
            s = i
        if (not inA or i == bins - 1) and s >= 0:
            e = i if inA else i - 1
            spans.append(dict(z0=zc(s), z1=zc(e), top=float(np.max(low[s:e + 1][np.isfinite(low[s:e + 1])]))))
            s = -1
    return [dict(a, center=(a['z0'] + a['z1']) / 2, width=a['z1'] - a['z0']) for a in spans if a['z1'] - a['z0'] > 0.06 * (z1 - z0)], low, z0, z1

if __name__ == '__main__':
    for p in sys.argv[1:]:
        m = load(p)
        V = m.vertices
        hx = np.abs(V[:, 0]).max()
        sp, low, z0, z1 = arch_spans(V, hx)
        print(p, 'verts', len(V), 'faces', len(m.faces), 'size', np.round(V.max(0) - V.min(0), 3), 'watertight', m.is_watertight)
        for a in sp:
            print('   arco z=%.3f ancho=%.3f techo=%.3f' % (a['center'], a['width'], a['top']))
