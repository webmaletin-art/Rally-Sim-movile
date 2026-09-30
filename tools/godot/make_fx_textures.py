#!/usr/bin/env python3
"""Genera las texturas de los efectos de Godot (humo, lluvia, salpicaduras, brillo). Se corre una vez; los PNG quedan en godot/game/fx/tex.
Humo: 16 bocanadas distintas (atlas 4x4) hechas con ruido fractal deformado, con sombreado de volumen (más claro arriba a la izquierda),
bordes que se disuelven y nada en el borde de cada casilla (sin costuras)."""
import numpy as np, os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'game', 'fx', 'tex')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(20260930)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def noise(n, size, rng):
    """ruido suave: grilla aleatoria n×n llevada a size×size con interpolación bicúbica (envuelve)"""
    g = rng.random((n, n)).astype(np.float32)
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0

def fbm(size, rng, octaves=6, base=3):
    out = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * noise(base * 2 ** o, size, rng)
        tot += amp
        amp *= 0.5
    return out / tot

def warp(field, size, rng, strength):
    """deforma un campo con otro ruido (aspecto de humo que se enrolla)"""
    dx = (fbm(size, rng, 4, 2) - 0.5) * strength
    dy = (fbm(size, rng, 4, 2) - 0.5) * strength
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    x2 = np.clip((xx + dx).astype(int), 0, size - 1)
    y2 = np.clip((yy + dy).astype(int), 0, size - 1)
    return field[y2, x2]

def puff(size, rng):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2
    r = np.hypot(xx - cx, yy - cy) / (size / 2)               # 0 en el centro, 1 en el borde de la casilla
    n1 = warp(fbm(size, rng, 7, 4), size, rng, size * 0.30)   # detalle fino, muy enrollado
    n2 = warp(fbm(size, rng, 4, 2), size, rng, size * 0.35)   # masas grandes
    base = np.exp(-(r * 1.55) ** 2)                            # caída suave desde el centro (no un disco)
    # densidad con huecos: el ruido "talla" la nube; el centro es más denso pero nunca uniforme
    dens = base * 1.25 + (n1 - 0.5) * 1.15 * (0.35 + base) + (n2 - 0.5) * 0.7 - 0.28
    dens = np.clip(dens, 0, 1) ** 1.25
    dens *= 1.0 - smoothstep(0.80, 1.0, r)                     # nada en el borde de la casilla
    # volumen: luz desde arriba a la izquierda; el gradiente de la densidad hace de "normal"
    gy, gx = np.gradient(dens)
    shade = np.clip(0.78 - 9.0 * (gx * 0.6 + gy * 0.8), 0.40, 1.0)
    shade = 0.55 + 0.45 * shade
    a = np.clip(dens * 0.78, 0, 0.8)
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = (shade * 255).astype(np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    return rgba

def atlas(tile=256, grid=4):
    im = np.zeros((tile * grid, tile * grid, 4), np.uint8)
    for j in range(grid):
        for i in range(grid):
            im[j * tile:(j + 1) * tile, i * tile:(i + 1) * tile] = puff(tile, rng)
    Image.fromarray(im, 'RGBA').save(os.path.join(OUT, 'smoke_atlas.png'), optimize=True)

def rain_streak(w=16, h=128):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ax = 1.0 - np.abs((xx - (w - 1) / 2) / (w / 2))
    ay = np.maximum(np.sin(np.clip(yy / (h - 1), 0, 1) * np.pi), 0) ** 0.8    # más fuerte en el medio, se desvanece en las puntas
    a = np.clip(ax ** 1.6 * ay, 0, 1)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 235
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, 'rain_streak.png'), optimize=True)

def splash(size=128):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.hypot(xx - c, yy - c) / (size / 2)
    ring = np.exp(-((r - 0.62) / 0.09) ** 2) * (0.6 + 0.4 * fbm(size, rng, 3, 4))
    core = np.exp(-(r / 0.16) ** 2) * 0.5
    drops = np.zeros_like(r)
    for _ in range(9):
        a = rng.random() * 6.283
        d = 0.35 + rng.random() * 0.45
        px, py = c + np.cos(a) * d * c, c + np.sin(a) * d * c
        drops += np.exp(-(np.hypot(xx - px, yy - py) / 3.2) ** 2)
    a = np.clip((ring + core + drops * 0.8) * (1 - smoothstep(0.85, 1.0, r)), 0, 1)
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., :3] = 240
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, 'splash.png'), optimize=True)

def glow(size=64):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.hypot(xx - c, yy - c) / (size / 2)
    a = np.clip(np.exp(-(r * 2.6) ** 2) + 0.25 * np.exp(-(r * 1.2) ** 2), 0, 1) * (1 - smoothstep(0.85, 1.0, r))
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, 'glow.png'), optimize=True)

def chunk(size=32):
    """piedrita/terrón irregular"""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = np.hypot(xx - c, yy - c) / (size / 2)
    n = fbm(size, rng, 3, 3)
    a = 1 - smoothstep(0.55 + 0.25 * n, 0.85 + 0.1 * n, r)
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., :3] = (140 + 90 * n)[..., None].astype(np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, 'chunk.png'), optimize=True)

atlas(); rain_streak(); splash(); glow(); chunk()
print('texturas listas en', os.path.abspath(OUT), os.listdir(OUT))
