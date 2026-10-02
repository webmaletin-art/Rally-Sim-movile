"""Ruta del «Vórtice de Ensueño»: un circuito enorme alrededor de un agujero negro central.
Sale de un valle plano, trepa 300 m en una subida larguísima, cruza una cresta con una curva peraltada, baja de golpe por una bajada
brutal y vuelve por una vuelta inmensa de curvas larguísimas.  Genera los puntos de control para godot/game/data/routes.json.
Uso: python3 tools/dream/route.py   (imprime el JSON de la ruta y un resumen de pendientes y curvas)"""
import json, math
import numpy as np
from scipy.interpolate import PchipInterpolator

def R(th):
    r = 1480 + 330 * math.cos(th - 0.6) + 150 * math.cos(2 * th + 1.0) - 110 * math.cos(3 * th - 0.3)
    # un recodo más cerrado en la cresta (curva peraltada de ~190 m de radio)
    r -= 340 * math.exp(-((th - math.radians(150)) / 0.30) ** 2)
    # y un ensanche suave al final de la bajada
    r += 120 * math.exp(-((th - math.radians(262)) / 0.35) ** 2)
    return r

def planar(n=72):
    return [(R(2 * math.pi * i / n) * math.cos(2 * math.pi * i / n), R(2 * math.pi * i / n) * math.sin(2 * math.pi * i / n)) for i in range(n)]

# perfil de altura por distancia recorrida (km, m): valle plano · subida altísima · cresta · bajada brutal · vuelta larga y suave
PROFILE = [(0.0, 6), (0.7, 6), (1.7, 52), (2.8, 140), (3.8, 262), (4.5, 303), (5.0, 306), (5.6, 295), (6.5, 205), (7.3, 95), (8.0, 26), (8.6, 9), (9.3, 12), (1.0, 0)]

def points(n=72):
    xz = planar(n)
    seg = [math.dist(xz[i], xz[(i + 1) % n]) for i in range(n)]
    L = sum(seg)
    prof = sorted(PROFILE[:-1])
    prof = [(k * 1000.0 / 9689.0 * 1.0, h) for k, h in prof]  # km del perfil -> fracción de una vuelta de ~9,7 km
    hs = PchipInterpolator([p[0] for p in prof] + [1.0], [p[1] for p in prof] + [6])
    pts, acc = [], 0.0
    for i in range(n):
        pts.append([round(xz[i][0]), round(float(hs(acc / L)), 1), round(xz[i][1])])
        acc += seg[i]
    return pts

def analyze(pts):
    p = np.array(pts, dtype=float)
    # Catmull-Rom cerrada, muestreada fina
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
    ds = d
    k = np.gradient(ang) / np.maximum(ds, 1e-6)
    slope = np.diff(np.append(q[:, 1], q[0, 1])) / np.maximum(ds, 1e-6)
    rad = 1.0 / np.maximum(np.abs(k), 1e-6)
    print('largo %.0f m · alto %.0f..%.0f m · pendiente máx +%.1f%% / %.1f%% · radio mínimo %.0f m' % (L, q[:, 1].min(), q[:, 1].max(), slope.max() * 100, slope.min() * 100, rad.min()))
    sm = np.convolve(rad, np.ones(9) / 9, mode='same')
    print('radios de curva: p5 %.0f · mediana %.0f' % (np.percentile(sm, 5), np.median(sm)))
    return L

if __name__ == '__main__':
    pts = points()
    analyze(pts)
    print(json.dumps(pts, separators=(',', ':')))
