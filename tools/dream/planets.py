"""Rutas de los mapas fantasía «planetarios»: Marte (Monte Olimpo), la Luna (Mar de la Tranquilidad) y el Anillo de Júpiter.
Cada una es un circuito cerrado (Catmull-Rom, como el Vórtice de Ensueño) con su perfil de altura. Imprime un resumen y, con --write, las suma
a godot/game/data/routes.json (rutas «marte», «luna», «anillo» y sus mapas).
Uso: python3 tools/dream/planets.py [--write]"""
import json, math, os, sys
import numpy as np
from scipy.interpolate import PchipInterpolator

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ROUTES = os.path.join(ROOT, 'godot', 'game', 'data', 'routes.json')

def gauss(x, c, w):
    return math.exp(-((x - c) / w) ** 2)

# ───────────── plantas (polares o libres) ─────────────
def mars_xz(n):
    out = []
    for i in range(n):
        th = 2 * math.pi * i / n
        r = 1420 + 300 * math.cos(th - 0.3) + 170 * math.cos(2 * th + 1.5) - 120 * math.cos(3 * th)
        # el cañón: un tramo sinuoso de curvas anchas
        w = gauss(th, math.radians(255), 0.55)
        r += 75 * w * math.sin(6.0 * th)
        out.append((r * math.cos(th), r * math.sin(th)))
    return out

def moon_xz(n):
    out = []
    for i in range(n):
        th = 2 * math.pi * i / n
        r = 1060 + 260 * math.cos(th - 0.4) + 130 * math.cos(2 * th + 0.8) - 90 * math.cos(3 * th)
        # una chicane cerca del módulo lunar
        r += 55 * gauss(th, math.radians(40), 0.30) * math.sin(9.0 * th)
        out.append((r * math.cos(th), r * math.sin(th)))
    return out

def ring_xz(n):
    out = []
    a, b, e = 1520.0, 760.0, 2.6
    for i in range(n):
        th = 2 * math.pi * i / n
        c, s = math.cos(th), math.sin(th)
        x = a * math.copysign(abs(c) ** (2 / e), c)
        z = b * math.copysign(abs(s) ** (2 / e), s)
        # un par de ondulaciones del trazado (como las ondas de densidad del anillo)
        z += 70 * math.sin(3 * th + 0.5) * (abs(c) ** 0.7)
        out.append((x, z))
    return out

# ───────────── perfiles de altura: (fracción de la vuelta, metros) ─────────────
def prof_mars(L):
    # llanura · subida larga por la ladera del volcán · cresta con la caldera (el camino baja al fondo y vuelve a subir) · bajada · cañón
    P = [(0.00, 4), (0.07, 4), (0.15, 30), (0.24, 104), (0.33, 206), (0.40, 284), (0.44, 318), (0.47, 300), (0.50, 288), (0.53, 304),
         (0.57, 316), (0.62, 288), (0.69, 214), (0.76, 132), (0.83, 48), (0.90, -16), (0.95, -6), (1.0, 4)]
    return P

def prof_moon(L):
    # cráteres: tazones con borde levantado, una pendiente suave por todos lados
    def crater(x, c, w, d):
        u = (x - c) / w
        return -d * (1 - u * u * 1.0) * math.exp(-u * u) * 1.0
    P = []
    for k in range(0, 201):
        x = k / 200.0
        h = 20.0
        h += crater(x, 0.17, 0.075, 24) + crater(x, 0.36, 0.060, 19) + crater(x, 0.55, 0.085, 30) + crater(x, 0.76, 0.065, 21) + crater(x, 0.92, 0.050, 13)
        h += 12 * math.sin(2 * math.pi * x + 1.0) + 3.5 * math.sin(6 * math.pi * x)
        P.append((x, h))
    P[-1] = (1.0, P[0][1])
    return P

def prof_ring(L):
    # casi plano, con ondas largas y un puente de hielo
    P = []
    for k in range(0, 201):
        x = k / 200.0
        h = 8 * math.sin(2 * math.pi * 4 * x + 0.4) + 3.0 * math.sin(2 * math.pi * 9 * x)
        h += 40 * gauss(x, 0.50, 0.085)
        h += 14 * gauss(x, 0.12, 0.040) - 12 * gauss(x, 0.80, 0.050)
        P.append((x, h))
    P[-1] = (1.0, P[0][1])
    return P

MAPS = {
    'marte': dict(xz=mars_xz, prof=prof_mars, n=72, hw=7.0, sho=2.4, samples=2600),
    'luna': dict(xz=moon_xz, prof=prof_moon, n=72, hw=7.0, sho=2.4, samples=2200),
    'anillo': dict(xz=ring_xz, prof=prof_ring, n=72, hw=7.0, sho=2.4, samples=2400),
}

def equal_arc(xz_fn, n):
    """n puntos a igual distancia a lo largo de la curva (así la Catmull-Rom no se pasa de largo donde los puntos están más separados)"""
    dense = xz_fn(4000)
    seg = [math.dist(dense[i], dense[(i + 1) % len(dense)]) for i in range(len(dense))]
    L = sum(seg)
    out, acc, k = [], 0.0, 0
    for i in range(n):
        target = L * i / n
        while acc + seg[k] < target:
            acc += seg[k]
            k += 1
        f = (target - acc) / seg[k]
        a, b = dense[k], dense[(k + 1) % len(dense)]
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out

def points(spec):
    n = spec['n']
    xz = equal_arc(spec['xz'], n)
    seg = [math.dist(xz[i], xz[(i + 1) % n]) for i in range(n)]
    L = sum(seg)
    P = spec['prof'](L)
    xs = [p[0] for p in P]
    ys = [p[1] for p in P]
    if xs[-1] < 1.0:
        xs.append(1.0)
        ys.append(ys[0])
    hs = PchipInterpolator(xs, ys)
    pts, acc = [], 0.0
    for i in range(n):
        pts.append([round(xz[i][0]), round(float(hs(min(1.0, acc / L))), 1), round(xz[i][1])])
        acc += seg[i]
    return pts

def analyze(name, pts):
    p = np.array(pts, dtype=float)
    n = len(p)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = p[(i - 1) % n], p[i], p[(i + 1) % n], p[(i + 2) % n]
        for w in np.linspace(0, 1, 40, endpoint=False):
            t1 = (p2 - p0) * 0.5; t2 = (p3 - p1) * 0.5
            c2 = -3 * p1 + 3 * p2 - 2 * t1 - t2; c3 = 2 * p1 - 2 * p2 + t1 + t2
            out.append(p1 + t1 * w + c2 * w * w + c3 * w ** 3)
    q = np.array(out)
    d = np.linalg.norm(np.diff(np.vstack([q, q[:1]]), axis=0), axis=1)
    L = d.sum()
    xz = q[:, [0, 2]]
    tg = np.diff(np.vstack([xz, xz[:1]]), axis=0)
    ang = np.unwrap(np.arctan2(tg[:, 1], tg[:, 0]))
    k = np.gradient(ang) / np.maximum(d, 1e-6)
    slope = np.diff(np.append(q[:, 1], q[0, 1])) / np.maximum(d, 1e-6)
    rad = 1.0 / np.maximum(np.abs(k), 1e-6)
    sm = np.convolve(rad, np.ones(9) / 9, mode='same')
    # separación mínima entre tramos lejanos de la vuelta (para que las mesetas no se pisen)
    cum = np.cumsum(d)
    step = 8
    idx = np.arange(0, len(q), step)
    sep = 1e9
    for a in idx:
        da = np.abs(cum[idx] - cum[a])
        da = np.minimum(da, L - da)
        far = idx[da > 500]
        if len(far):
            sep = min(sep, float(np.min(np.linalg.norm(xz[far] - xz[a], axis=1))))
    print('%s: largo %.0f m · alto %.0f..%.0f m · pendiente +%.1f%% / %.1f%% · radio mín %.0f m (p5 %.0f) · separación mín %.0f m' % (
        name, L, q[:, 1].min(), q[:, 1].max(), slope.max() * 100, slope.min() * 100, rad.min(), np.percentile(sm, 5), sep))
    return L, slope, sm, sep

if __name__ == '__main__':
    out = {}
    for name, spec in MAPS.items():
        pts = points(spec)
        L, slope, sm, sep = analyze(name, pts)
        out[name] = (pts, L)
    if '--write' in sys.argv:
        d = json.load(open(ROUTES, encoding='utf-8'))
        for name, spec in MAPS.items():
            d['routes'][name] = {'flat': True, 'samples': spec['samples'], 'halfWidth': spec['hw'], 'shoulder': spec['sho'], 'points': out[name][0]}
        names = {'marte': ('Marte · Monte Olimpo', '🔴', 'mars', 'Un volcán rojo: subida de 300 m, la caldera y un cañón.'),
                 'luna': ('La Luna · Mar de la Tranquilidad', '🌙', 'moon', 'Cráteres, la Tierra en el cielo y un módulo lunar.'),
                 'anillo': ('Anillo de Júpiter', '🪐', 'ring', 'Cristales de hielo flotando frente a un Júpiter gigante.')}
        for name, (nm, ic, world, tag) in names.items():
            ys = [p[1] for p in out[name][0]]
            d['maps'][name] = {'name': nm, 'icon': ic, 'kind': 'dream', 'world': world, 'route': name, 'mode': 'asphalt', 'hills': 0, 'tagline': tag,
                               'km': round(out[name][1] / 1000.0, 1), 'dz': int(round((max(ys) - min(ys)) / 10.0) * 10)}
        dm = d['maps']['dream']
        dm.update({'world': 'dream', 'tagline': 'Flores gigantes, un planeta enorme y un agujero negro debajo.', 'km': 9.7, 'dz': 300})
        json.dump(d, open(ROUTES, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
        print('routes.json actualizado')
