import sys, json
import numpy as np
from analyze import load, arch_spans

def fit_circle(pts):
    x, y = pts[:, 0], pts[:, 1]
    A = np.c_[2 * x, 2 * y, np.ones(len(x))]
    b = x * x + y * y
    c, *_ = np.linalg.lstsq(A, b, rcond=None)
    xc, yc = c[0], c[1]
    r = np.sqrt(c[2] + xc * xc + yc * yc)
    return xc, yc, r

def arch_fit(V, hx, xo=0.72, bins=240):
    z0, z1 = V[:, 2].min(), V[:, 2].max()
    sel = np.abs(V[:, 0]) > xo * hx
    P = V[sel]
    zb = np.clip(((P[:, 2] - z0) / (z1 - z0) * bins).astype(int), 0, bins - 1)
    low = np.full(bins, np.inf)
    for b, y in zip(zb, P[:, 1]):
        low[b] = min(low[b], y)
    zc = z0 + (np.arange(bins) + 0.5) * (z1 - z0) / bins
    sp, _, _, _ = arch_spans(V, hx, bins=160)
    res = []
    for a in sp:
        # puntos del borde del arco: dentro de la franja (algo ampliada) y por encima del 25 % de la altura del arco
        m = (zc > a['z0'] - 0.02) & (zc < a['z1'] + 0.02) & np.isfinite(low) & (low > 0.3 * a['top'])
        pts = np.c_[zc[m], low[m]]
        if len(pts) < 8:
            continue
        xc, yc, r = fit_circle(pts)
        res.append(dict(z=float(xc), y=float(yc), r=float(r), top=float(a['top']), z0=float(a['z0']), z1=float(a['z1'])))
    return res

if __name__ == '__main__':
    for p in sys.argv[1:]:
        m = load(p)
        V = m.vertices
        hx = np.abs(V[:, 0]).max()
        print(p.split('/')[-1], 'hx=%.3f' % hx)
        for a in arch_fit(V, hx):
            print('   z=%.3f y=%.3f r=%.3f (techo %.3f)' % (a['z'], a['y'], a['r'], a['top']))
