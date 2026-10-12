"""Trompa completa (capó, guardabarros, frente, faros y paragolpes) para el Torito '67.
El modelo crudo viene con el frente SIN carrocería (se ve el motor y el chasis). Esto arma la trompa con geometría propia, ya en el sistema final del auto
(frente en +z, piso en y = 0), y le pone a cada pieza las coordenadas UV de un pixel de la textura del propio auto (pintura, negro, cromo, lámpara),
así la pintura se recolorea igual que el resto de la carrocería.
Uso: clip(V, F, UV, img, arches) -> (V2, F2, N2, UV2) de la trompa para pegar al modelo."""
import numpy as np
from PIL import Image

ZC = 0.50          # donde empieza el capó (base del parabrisas)
ZN = 2.30          # punta de la trompa
YS = 0.34          # borde de abajo de los guardabarros
W_SIDE = 0.86      # semiancho de la trompa a la altura de las puertas

def texel(img, target, near=None, r=3):
    """UV (origen abajo-izquierda) del bloque de la textura más parecido a `target` (RGB 0-255) y más liso; si hay `near`, solo cerca de ese UV."""
    a = np.asarray(img.convert('RGB'), dtype=np.float32)
    H, W, _ = a.shape
    n = 64
    bh, bw = H // n, W // n
    blk = a[:bh * n, :bw * n].reshape(n, bh, n, bw, 3)
    mean = blk.mean((1, 3))
    std = blk.std((1, 3)).mean(-1)
    cost = np.linalg.norm(mean - np.array(target, dtype=np.float32), axis=-1) + 3.0 * std
    if near is not None:
        bx = int(near[0] * n)
        by = int((1.0 - near[1]) * n)
        m = np.full((n, n), 1e9, dtype=np.float32)
        y0, y1, x0, x1 = max(by - r, 0), min(by + r + 1, n), max(bx - r, 0), min(bx + r + 1, n)
        m[y0:y1, x0:x1] = 0
        cost = cost + m
    j, i = np.unravel_index(np.argmin(cost), cost.shape)
    return np.array([(i + 0.5) / n, 1.0 - (j + 0.5) / n]), mean[j, i]

class Mesh:
    def __init__(self, uv):
        self.v = []
        self.f = []
        self.uv = np.asarray(uv, dtype=np.float64)

    def vert(self, p):
        self.v.append(p)
        return len(self.v) - 1

    def tri(self, a, b, c, inside):
        """triángulo (índices) orientado para que la normal mire hacia AFUERA de `inside` (punto interior)"""
        pa, pb, pc = (np.array(self.v[i]) for i in (a, b, c))
        n = np.cross(pb - pa, pc - pa)
        if np.dot(n, (pa + pb + pc) / 3 - np.asarray(inside)) < 0:
            b, c = c, b
        self.f.append((a, b, c))

    def strip(self, rows, inside):
        """malla entre filas de puntos consecutivas (lista de listas del mismo largo)"""
        idx = [[self.vert(p) for p in r] for r in rows]
        for r in range(len(rows) - 1):
            for k in range(len(rows[r]) - 1):
                a, b, c, d = idx[r][k], idx[r][k + 1], idx[r + 1][k + 1], idx[r + 1][k]
                self.tri(a, b, c, inside)
                self.tri(a, c, d, inside)

def build_part(uv, make):
    m = Mesh(uv)
    make(m)
    V = np.array(m.v, dtype=np.float64)
    F = np.array(m.f, dtype=np.int64)
    return V, F, np.tile(m.uv, (len(V), 1))

def clip(V, F, UV, img, arches):
    rear, front = sorted(arches, key=lambda a: a['z'])
    zw, rw = front['z'], front['r'] + 0.10          # centro y radio de la boca del paso de rueda delantero
    yw = front['y'] if 'y' in front else 0.34
    inside = (0.0, 0.62, 1.5)

    def ytop(z):
        t = (z - ZC) / (ZN - ZC)
        return 1.02 - 0.15 * t ** 1.4

    def wid(z):
        t = np.clip((z - 1.85) / (ZN - 1.85), 0, 1)
        return W_SIDE - 0.17 * (1 - np.cos(t * np.pi / 2)) ** 1.0

    def ybot(z):
        d = abs(z - zw)
        return max(YS, yw + np.sqrt(rw * rw - d * d)) if d < rw else YS

    # pintura: un pixel de la puerta del propio auto
    sel = (np.abs(V[:, 0]) > 0.78) & (V[:, 2] > -0.6) & (V[:, 2] < 0.2) & (V[:, 1] > 0.5) & (V[:, 1] < 0.85)
    uv0 = np.median(UV[F[np.isin(F, np.where(sel)[0]).any(1)]].reshape(-1, 2), 0) if sel.any() else np.array([0.5, 0.5])
    uv_paint, _ = texel(img, (150, 20, 20), near=uv0, r=2)
    uv_black, _ = texel(img, (12, 12, 14))
    uv_chrome, _ = texel(img, (190, 195, 200))
    uv_lamp, _ = texel(img, (245, 245, 235))

    zs = np.concatenate([np.arange(ZC, ZN - 0.001, 0.05), [ZN]])

    def loop(z, side=None):
        """sección transversal (de izquierda a derecha por arriba) a la altura z"""
        w = wid(z)
        yt = ytop(z)
        yb = ybot(z)
        pts = []
        top0 = yt - 0.10
        for k in range(5):                                  # lado izquierdo, de abajo a arriba
            pts.append((-w, yb + (top0 - yb) * k / 5.0))
        for ang in np.linspace(0, np.pi / 2, 5):            # esquina redondeada
            pts.append((-w + 0.10 * (1 - np.cos(ang)), top0 + 0.10 * np.sin(ang) - 0.0 * ang))
        for x in np.linspace(-w + 0.10, w - 0.10, 11)[1:-1]:
            pts.append((x, yt + 0.05 * (1 - (x / w) ** 2)))
        for ang in np.linspace(np.pi / 2, 0, 5):
            pts.append((w - 0.10 * (1 - np.cos(ang)), top0 + 0.10 * np.sin(ang)))
        for k in range(1, 6):
            pts.append((w, top0 + (yb - top0) * k / 5.0))
        return pts

    def top(m):
        rows = [[(x, y, z) for x, y in loop(z)] for z in zs]
        m.strip(rows, inside)
        # tubo del paso de rueda (cara interior), a cada lado
        for sgn in (-1, 1):
            rows2 = []
            for z in np.linspace(zw - rw, zw + rw, 21):
                yb = ybot(z)
                rows2.append([(sgn * W_SIDE, yb, z), (sgn * (W_SIDE - 0.34), yb, z)])
            m.strip(rows2, (sgn * (W_SIDE - 0.2), yw - 0.2, zw))
            rows3 = []
            for z in np.linspace(zw - rw, zw + rw, 21):
                yb = ybot(z)
                rows3.append([(sgn * (W_SIDE - 0.34), yb, z), (sgn * (W_SIDE - 0.34), ytop(z) - 0.12, z)])
            m.strip(rows3, (0.0, 0.6, z))
        # tapa de atrás (base del capó contra el parabrisas): para que no se vea hueco
        zz = ZC
        w = wid(zz)
        m.strip([[(x, ytop(zz) - 0.10, zz) for x in np.linspace(-w, w, 7)], [(x, 0.5, zz) for x in np.linspace(-w, w, 7)]], (0.0, 0.7, 1.5))
        # frente (parte de abajo de la trompa, bajo la parrilla): panel liso
        w = wid(ZN)
        rows4 = [[(x, y, ZN) for x in np.linspace(-w, w, 9)] for y in np.linspace(YS, ytop(ZN) - 0.04, 5)]
        m.strip(rows4, inside)
    parts = [build_part(uv_paint, top)]

    def grille(m):
        w = wid(ZN) - 0.12
        rows = [[(x, y, ZN + 0.012) for x in np.linspace(-w, w, 7)] for y in np.linspace(0.60, 0.80, 3)]
        m.strip(rows, inside)
    parts.append(build_part(uv_black, grille))

    def lamps(m):
        for sgn in (-1, 1):
            cx, cy = sgn * 0.52, 0.80
            c = m.vert((cx, cy, ZN + 0.025))
            ring = [m.vert((cx + 0.105 * np.cos(a), cy + 0.105 * np.sin(a), ZN + 0.02)) for a in np.linspace(0, 2 * np.pi, 13)]
            for k in range(12):
                m.tri(c, ring[k], ring[k + 1], (0, cy, ZN - 1.0))
    parts.append(build_part(uv_lamp, lamps))

    def bumper(m):
        w = wid(ZN) + 0.06
        for y0, y1 in ((0.44, 0.58),):
            rows = [[(x, y, z) for x in np.linspace(-w, w, 9)] for y, z in ((y0, ZN + 0.02), (y0 + 0.03, ZN + 0.09), (y1 - 0.03, ZN + 0.09), (y1, ZN + 0.02))]
            m.strip(rows, (0.0, 0.5, ZN - 0.5))
    def rings(m):
        for sgn in (-1, 1):
            cx, cy = sgn * 0.52, 0.80
            c = m.vert((cx, cy, ZN + 0.012))
            ring = [m.vert((cx + 0.135 * np.cos(a), cy + 0.135 * np.sin(a), ZN + 0.012)) for a in np.linspace(0, 2 * np.pi, 13)]
            for k in range(12):
                m.tri(c, ring[k], ring[k + 1], (0, cy, ZN - 1.0))
    parts.append(build_part(uv_chrome, bumper))
    parts.append(build_part(uv_chrome, rings))

    Vs, Fs, UVs = [], [], []
    off = 0
    for v, f, uv in parts:
        Vs.append(v)
        Fs.append(f + off)
        UVs.append(uv)
        off += len(v)
    Vc, Fc, UVc = np.concatenate(Vs), np.concatenate(Fs), np.concatenate(UVs)
    import trimesh
    m = trimesh.Trimesh(Vc, Fc, process=False)
    Nc = np.asarray(m.vertex_normals)
    return Vc, Fc, Nc, UVc
