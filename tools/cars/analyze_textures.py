#!/usr/bin/env python3
"""Analiza la textura de color de cada auto (tonos dominantes, blancos y grises) para elegir los canales de color que el juego puede cambiar (final_wheels.TEX).
Uso: python3 tools/cars/analyze_textures.py [id …]"""
import sys, os, glob
import numpy as np, trimesh
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import final_cars as FC

def hsv(a):
    mx = a.max(2); mn = a.min(2); d = np.maximum(mx - mn, 1e-6)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return h, s, mx

def analyze(cid):
    sc = trimesh.load(os.path.join(FC.SRC_DIR, FC.MODEL[cid]['src']), force='scene', process=False)
    g = list(sc.geometry.values())[0]
    img = np.asarray(g.visual.material.baseColorTexture.convert('RGB')).astype(float) / 255
    # solo lo que se VE: puntos al azar sobre la superficie del auto (ponderados por el área), con el color de la textura en ese punto
    V = np.asarray(g.vertices); F = np.asarray(g.faces); UV = np.asarray(g.visual.uv)
    tri = V[F]
    area = 0.5 * np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)
    rng = np.random.default_rng(1)
    n = 300000
    fi = rng.choice(len(F), n, p=area / area.sum())
    r1 = rng.random((n, 2)); fl = r1.sum(1) > 1; r1[fl] = 1 - r1[fl]
    uv = UV[F[fi, 0]] * (1 - r1[:, :1] - r1[:, 1:]) + UV[F[fi, 1]] * r1[:, :1] + UV[F[fi, 2]] * r1[:, 1:]
    px = np.clip((uv[:, 0] * img.shape[1]).astype(int), 0, img.shape[1] - 1)
    py = np.clip(((1 - uv[:, 1]) * img.shape[0]).astype(int), 0, img.shape[0] - 1)
    a = img[py, px].reshape(1, n, 3)
    h, s, v = hsv(a)
    tot = n
    out = {}
    sel = (s > 0.4) & (v > 0.25)
    hist = np.histogram(h[sel], bins=36, range=(0, 1))[0]
    # tonos dominantes (máximos locales del histograma suavizado)
    hs = np.convolve(np.r_[hist[-2:], hist, hist[:2]], np.ones(5) / 5, mode='valid')
    top = []
    hh = hs.copy()
    for _ in range(3):
        i = int(hh.argmax())
        if hh[i] < 0.004 * tot:
            break
        top.append((round((i + 0.5) / 36, 3), round(float(hh[i]) * 5 / tot * 100, 1)))
        for j in range(-3, 4):
            hh[(i + j) % 36] = 0
    bright = ((v > 0.6) & (s < 0.18)).mean() * 100
    mid = ((v > 0.28) & (v <= 0.6) & (s < 0.15)).mean() * 100
    dark = (v <= 0.28).mean() * 100
    print('%-10s tonos %-40s blanco %.0f%%  gris %.0f%%  oscuro %.0f%%  color %.0f%%' % (cid, top, bright, mid, dark, sel.mean() * 100))

if __name__ == '__main__':
    for cid in (sys.argv[1:] or FC.IDS):
        analyze(cid)
