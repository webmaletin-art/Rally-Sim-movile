"""Flora del mapa de ensueño («Vórtice de Ensueño»), hecha en papel a mano a partir de las 21 familias del pack de renders
(papercraft_batch_110modelos): sakura, rosa, tulipán, loto, hibisco, lirio, orquídea, girasol, tropical, margarita, flor simple,
bambú, alga, helecho, hongo, arbusto, árbol, pasto alto… El pack trae solo imágenes (no los GLB), así que cada familia se rehízo con
pétalos y hojas de papel (caras lisas de un solo color) con la forma y la paleta de los renders, pero más grandes y vistosas.

Salida: godot/game/models/paper/<id>.pap  y se suman a catalog.json (correr primero paperize.py).
Uso:  python3 tools/paper/dreamflora.py
"""
import json, math, os, sys
import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(__file__))
import paperize as P  # noqa: E402  (reutiliza el formato .pap, los colores de papel y los ayudantes)

RNG = P.RNG

def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

# ───────────── ayudantes ─────────────
def ribbon(path, widths, yaw=0.0, origin=(0.0, 0.0, 0.0)):
    """Tira que sigue 'path' (r, y) en la dirección horizontal yaw, con ancho 'widths' hacia los costados"""
    rad = np.array([math.cos(yaw), 0.0, math.sin(yaw)])
    side = np.array([-math.sin(yaw), 0.0, math.cos(yaw)])
    o = np.array(origin, dtype=float)
    v, f = [], []
    for (r, y), w in zip(path, widths):
        c = o + rad * r + np.array([0.0, y, 0.0])
        v += [c - side * w, c + side * w]
    for k in range(len(path) - 1):
        a = k * 2
        f += [[a, a + 1, a + 2], [a + 1, a + 3, a + 2]]
    return trimesh.Trimesh(np.array(v), np.array(f))

def petal(length, width, tilt, curl, yaw, y0=0.0, r0=0.0, segs=3, shape=0.0, origin=(0.0, 0.0, 0.0)):
    """Pétalo de papel. tilt: ángulo desde la vertical hacia afuera (rad) · curl: cuánto se abre más hacia la punta · shape: 0 ovalado, 1 punta fina"""
    path, widths = [], []
    r, y, th = r0, y0, tilt
    for k in range(segs + 1):
        s = k / segs
        path.append((r, y))
        widths.append(width * 0.5 * (math.sin(math.pi * min(1.0, s * 0.85 + 0.12)) ** (0.7 + shape)) * (1.0 - 0.15 * s))
        r += math.sin(th) * length / segs
        y += math.cos(th) * length / segs
        th += curl / segs
    widths[-1] = 0.0
    return ribbon(path, widths, yaw, origin)

def ring(n, length, width, tilt, curl, y0=0.0, r0=0.0, phase=0.0, segs=3, shape=0.0, jit=0.1, origin=(0.0, 0.0, 0.0)):
    out = []
    for i in range(n):
        a = phase + i * math.tau / n + RNG.uniform(-0.05, 0.05)
        out.append(petal(length * (1 + RNG.uniform(-jit, jit)), width, tilt + RNG.uniform(-0.05, 0.05), curl, a, y0, r0, segs, shape, origin))
    return out

def branch(p0, p1, r0, r1, sections=5):
    """Cilindro de papel entre dos puntos (para ramas)"""
    p0 = np.array(p0, dtype=float)
    p1 = np.array(p1, dtype=float)
    d = p1 - p0
    L = float(np.linalg.norm(d))
    m = trimesh.creation.cylinder(radius=r0, height=L, sections=sections)
    v = m.vertices.copy()
    top = v[:, 2] > 0
    v[top, 0] *= r1 / r0
    v[top, 1] *= r1 / r0
    m.vertices = v
    z = np.array([0.0, 0.0, 1.0])
    ax = np.cross(z, d / L)
    if np.linalg.norm(ax) > 1e-6:
        ang = math.acos(np.clip(np.dot(z, d / L), -1, 1))
        m.apply_transform(trimesh.transformations.rotation_matrix(ang, ax / np.linalg.norm(ax)))
    m.apply_translation((p0 + p1) / 2)
    return m

def paint_all(meshes, c, jit=0.07):
    return [P.paint(m, c, jit) for m in meshes]

def stem(h, r0=0.05, r1=0.035, lean=(0.0, 0.0), col=(0.20, 0.52, 0.17)):
    return P.paint(P.trunk(r0, r1, h, 5, 0.0, lean), col, 0.05)

def leaf_pair(y, size, col=(0.18, 0.55, 0.20), n=2, curl=0.5):
    out = []
    for i in range(n):
        a = i * math.tau / n + RNG.uniform(-0.4, 0.4) + 0.6
        out.append(P.paint(petal(size, size * 0.38, 1.05, curl, a, y, 0.0, 3, 0.2), col, 0.1))
    return out

def disc(r, y, col, ny=0.0, sections=8, thick=0.0):
    m = trimesh.creation.cylinder(radius=r, height=0.02 + thick, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, [1, 0, 0]))
    m.apply_translation([0, y, 0])
    return m

def bulb(r, pos, scale=(1, 1, 1), sub=0):
    return P.blob(r, pos, scale, sub, 0.0)

GREEN = (0.20, 0.55, 0.18)
DGREEN = (0.13, 0.42, 0.16)

# ───────────── flores ─────────────
def rosa(c1, c2):
    h = 1.1
    parts = [stem(h, 0.04, 0.03, (0.05, 0.0))] + leaf_pair(0.35, 0.34) + leaf_pair(0.62, 0.28)
    for layer, (n, ln, wd, tilt) in enumerate([(5, 0.29, 0.25, 0.70), (5, 0.24, 0.21, 0.45), (4, 0.19, 0.17, 0.2), (3, 0.13, 0.13, 0.05)]):
        col = c2 if layer in (2, 3) else c1
        parts += paint_all(ring(n, ln, wd, tilt, -0.35 + layer * 0.12, h + layer * 0.01, 0.02, layer * 0.6, 3, 0.1, 0.05), col, 0.06)
    parts.append(P.paint(bulb(0.045, (0, h + 0.05, 0)), (0.98, 0.78, 0.18)))
    return parts

def tulipan(c1, c2=None):
    h = 1.15
    c2 = c2 or c1
    parts = [stem(h, 0.035, 0.028, (0.0, 0.04))] + leaf_pair(0.28, 0.5, GREEN, 2, 0.45)
    parts += paint_all(ring(3, 0.42, 0.21, 0.30, -0.45, h, 0.0, 0.0, 3, 0.8, 0.03), c1, 0.06)
    parts += paint_all(ring(3, 0.42, 0.21, 0.30, -0.45, h, 0.0, math.pi / 3, 3, 0.8, 0.03), c2, 0.06)
    return parts

def loto(c1, c2):
    h = 1.0
    parts = [stem(h * 0.8, 0.045, 0.035)] + leaf_pair(0.3, 0.45, GREEN, 1, 0.3)
    # hoja plana flotante
    pad = disc(0.55, 0.04, DGREEN, sections=9)
    parts.append(P.paint(pad, (0.15, 0.48, 0.28), 0.05))
    parts += paint_all(ring(8, 0.34, 0.15, 0.75, -0.6, h * 0.8, 0.02, 0.0, 3, 0.7, 0.05), c1, 0.06)
    parts += paint_all(ring(6, 0.30, 0.15, 0.40, -0.45, h * 0.8 + 0.02, 0.0, 0.3, 3, 0.7, 0.05), c2, 0.06)
    parts += paint_all(ring(5, 0.22, 0.12, 0.10, -0.30, h * 0.8 + 0.04, 0.0, 0.6, 2, 0.5, 0.05), (1.0, 0.92, 0.65), 0.04)
    return parts

def hibisco(c1, c2):
    h = 1.2
    parts = [stem(h, 0.045, 0.035, (0.1, 0.0))] + leaf_pair(0.4, 0.4) + leaf_pair(0.7, 0.34)
    parts += paint_all(ring(5, 0.46, 0.34, 1.0, -0.15, h, 0.0, 0.0, 3, 0.0, 0.04), c1, 0.06)
    parts += paint_all(ring(5, 0.18, 0.16, 0.4, 0.2, h + 0.02, 0.0, 0.3, 2, 0.0, 0.02), c2, 0.06)
    # estambre largo
    parts.append(P.paint(P.trunk(0.012, 0.012, 0.4, 3, h, (0.18, 0.0)), (0.98, 0.78, 0.15), 0.03))
    parts.append(P.paint(bulb(0.04, (0.18, h + 0.4, 0)), (0.95, 0.30, 0.18)))
    return parts

def lirio(c1, c2):
    h = 1.2
    parts = [stem(h, 0.04, 0.03, (0.0, -0.06))] + leaf_pair(0.4, 0.55, GREEN, 3, 0.6)
    parts += paint_all(ring(6, 0.52, 0.17, 1.2, -0.75, h, 0.0, 0.0, 3, 0.7, 0.05), c1, 0.06)
    parts += paint_all(ring(3, 0.30, 0.07, 0.35, 0.2, h + 0.02, 0.0, 0.0, 2, 0.8, 0.05), c2, 0.05)
    for k in range(5):
        a = k * math.tau / 5
        parts.append(P.paint(bulb(0.03, (math.cos(a) * 0.16, h + 0.22, math.sin(a) * 0.16)), (0.55, 0.12, 0.30)))
    return parts

def orquidea(c1, c2):
    h = 1.3
    parts = [stem(h, 0.03, 0.02, (0.3, 0.0), (0.22, 0.50, 0.20))] + leaf_pair(0.25, 0.5, GREEN, 2, 0.5)
    for k in range(4):
        y = 0.75 + k * 0.17
        x = 0.05 + (y / h) * 0.3 * 0.0
        o = (0.3 * (y / h) - 0.0, 0.0, 0.0)
        a = k * 1.9
        parts += paint_all(ring(3, 0.22, 0.12, 0.8, -0.2, y, 0.0, a, 3, 0.4, 0.05, origin=o), c1, 0.06)
        parts += paint_all(ring(2, 0.14, 0.12, 1.2, 0.0, y - 0.02, 0.0, a + 0.9, 2, 0.1, 0.05, origin=o), c2, 0.06)
    return parts

def girasol(c1, c2):
    h = 1.8
    parts = [stem(h, 0.06, 0.04, (0.2, 0.0))] + leaf_pair(0.5, 0.6, GREEN, 2, 0.5) + leaf_pair(1.0, 0.5, GREEN, 2, 0.5)
    o = (0.2, 0.0, 0.0)
    parts += paint_all(ring(13, 0.42, 0.17, 1.2, 0.0, h, 0.25, 0.0, 2, 0.6, 0.05, origin=o), c1, 0.06)
    parts += paint_all(ring(13, 0.34, 0.15, 1.35, 0.1, h + 0.02, 0.22, 0.24, 2, 0.6, 0.05, origin=o), c1, 0.08)
    d = disc(0.3, h + 0.03, c2, sections=10, thick=0.06)
    d.apply_translation([0.2, 0, 0])
    parts.append(P.paint(d, c2, 0.1))
    return parts

def tropical(c1, c2, c3):
    h = 1.5
    parts = [stem(h, 0.05, 0.035, (0.0, 0.0))] + leaf_pair(0.3, 0.9, GREEN, 3, 0.5)
    # bráctea en forma de barquito y abanico de pétalos
    parts += paint_all(ring(3, 0.40, 0.20, 1.3, 0.0, h, 0.0, 0.0, 3, 0.7, 0.05), c1, 0.06)
    parts += paint_all(ring(3, 0.42, 0.11, 0.35, 0.1, h + 0.05, 0.0, 0.1, 3, 0.9, 0.05), c2, 0.06)
    parts += paint_all(ring(2, 0.30, 0.10, 0.9, 0.0, h + 0.02, 0.0, 2.0, 3, 0.9, 0.05), c3, 0.06)
    return parts

def margarita(c1, c2):
    h = 0.8
    parts = [stem(h, 0.025, 0.02)] + leaf_pair(0.3, 0.3)
    parts += paint_all(ring(12, 0.28, 0.08, 1.35, 0.05, h, 0.04, 0.0, 2, 0.5, 0.05), c1, 0.05)
    parts.append(P.paint(bulb(0.07, (0, h + 0.03, 0), (1, 0.6, 1)), c2, 0.03))
    return parts

def flor_simple(c1, c2):
    h = 0.7
    parts = [stem(h, 0.022, 0.018, (0.04, 0.0))] + leaf_pair(0.25, 0.28)
    parts += paint_all(ring(5, 0.26, 0.22, 1.25, 0.1, h, 0.03, 0.0, 2, 0.0, 0.05), c1, 0.05)
    parts.append(P.paint(bulb(0.06, (0, h + 0.03, 0), (1, 0.7, 1)), c2, 0.03))
    return parts

# ───────────── plantas y arbustos ─────────────
def alga(c1, c2):
    parts = []
    for i in range(8):
        a = RNG.uniform(0, math.tau)
        hh = 1.0 + RNG.uniform(0, 1.0)
        parts.append(P.paint(P.blade(hh, 0.09, RNG.uniform(0.3, 0.9), a, RNG.uniform(-0.1, 0.1), RNG.uniform(-0.1, 0.1), 4), c1 if i % 2 else c2, 0.1))
    return parts

def helecho_dream(c1, c2):
    parts = []
    for i in range(11):
        a = i * math.tau / 11 + RNG.uniform(-0.15, 0.15)
        parts.append(P.paint(P.blade(1.0 + RNG.uniform(0, 0.5), 0.18, 1.0, a, segs=4), c1 if i % 2 else c2, 0.1))
    return parts

def nenufar(c1, c2):
    parts = [P.paint(disc(0.9, 0.05, c1, sections=11), c1, 0.07)]
    parts += [P.paint(disc(0.45, 0.08, c2, sections=9), c2, 0.07)]
    parts += paint_all(ring(5, 0.28, 0.14, 0.9, -0.4, 0.09, 0.0, 0.0, 2, 0.5, 0.05), (1.0, 0.82, 0.90), 0.05)
    return parts

def hongo(cap, spot, h=1.0, stalk=(0.93, 0.88, 0.80), wide=1.0):
    parts = [P.paint(P.trunk(0.09 * wide, 0.07 * wide, h * 0.55, 6), stalk, 0.04)]
    capm = trimesh.creation.icosphere(subdivisions=1, radius=0.42 * wide)
    v = capm.vertices * np.array([1, 0.62, 1])
    v[:, 1] = np.maximum(v[:, 1], 0.0)
    capm.vertices = v + np.array([0, h * 0.52, 0])
    parts.append(P.paint(capm, cap, 0.06))
    for k in range(6):
        a = k * math.tau / 6 + RNG.uniform(-0.2, 0.2)
        rr = RNG.uniform(0.14, 0.28) * wide
        parts.append(P.paint(P.blob(0.055 * wide, (math.cos(a) * rr, h * 0.52 + 0.20 * wide - rr * 0.25, math.sin(a) * rr), sub=0, noise=0.0), spot, 0.02))
    return parts

def arbusto_color(c1, c2, c3):
    """Arbusto florido: una cúpula de facetas de colores sobre unas pocas hojas verdes"""
    parts = []
    for k in range(4):
        a = k * math.tau / 4 + RNG.uniform(-0.3, 0.3)
        parts.append(P.paint(P.blob(0.42, (math.cos(a) * 0.35, 0.3, math.sin(a) * 0.35), (1.0, 0.7, 1.0), sub=0, noise=0.1), (0.16, 0.45, 0.20), 0.08))
    for k in range(9):
        a = RNG.uniform(0, math.tau)
        r = RNG.uniform(0.0, 0.8)
        y = 0.55 + (1.0 - r) * 0.5 + RNG.uniform(0, 0.15)
        parts.append(P.paint(P.blob(RNG.uniform(0.32, 0.46), (math.cos(a) * r, y, math.sin(a) * r), sub=0, noise=0.14), (c1, c2, c3)[k % 3], 0.07))
    return parts

def bambu(c1, c2, n=4, h=6.0):
    parts = []
    for i in range(n):
        a = RNG.uniform(0, math.tau)
        rr = RNG.uniform(0.0, 0.45)
        hh = h * (0.7 + RNG.uniform(0, 0.3))
        lean = (RNG.uniform(-0.3, 0.3), RNG.uniform(-0.3, 0.3))
        m = P.trunk(0.12, 0.08, hh, 4, 0.0, lean)
        m.apply_translation([math.cos(a) * rr, 0, math.sin(a) * rr])
        parts.append(P.paint(m, c1, 0.06))
        for j in (2, 4):  # nudos
            ring_m = trimesh.creation.cylinder(radius=0.135, height=0.05, sections=4)
            ring_m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, [1, 0, 0]))
            t = j / 5.0
            ring_m.apply_translation([math.cos(a) * rr + lean[0] * t, hh * t, math.sin(a) * rr + lean[1] * t])
            parts.append(P.paint(ring_m, c2, 0.04))
        for j in range(2):  # hojas
            t = 0.8 + 0.1 * j
            lf = P.blade(1.0, 0.12, 0.8, RNG.uniform(0, math.tau), 0.0, 0.0, 3)
            lf.apply_translation([math.cos(a) * rr + lean[0] * t, hh * t, math.sin(a) * rr + lean[1] * t])
            parts.append(P.paint(lf, c2, 0.1))
    return parts

def pasto_color(c1, c2, tipc, n=16):
    parts = []
    for i in range(n):
        a = RNG.uniform(0, math.tau)
        hh = 0.9 + RNG.uniform(0, 0.9)
        parts.append(P.paint(P.blade(hh, 0.05, RNG.uniform(0.2, 0.8), a, RNG.uniform(-0.18, 0.18), RNG.uniform(-0.18, 0.18), 3), c1 if i % 3 else c2, 0.12))
        if i % 3 == 0:  # penacho de color en la punta
            parts.append(P.paint(P.blob(0.05, (RNG.uniform(-0.15, 0.15), hh * 0.95, RNG.uniform(-0.15, 0.15)), sub=0, noise=0.0), tipc, 0.05))
    return parts

# ───────────── árboles ─────────────
def tree_flowering(canopy, canopy2, canopy3, trunk_col=(0.38, 0.26, 0.20), h=9.0, lean=0.0, spread=1.0, blobs=10):
    top = np.array([lean, h * 0.62, 0.0])
    parts = [P.paint(branch([0, 0, 0], top, 0.45, 0.2, 5), trunk_col, 0.06)]
    # ramas que salen del tronco hacia la copa
    for k in range(4):
        a = k * math.tau / 4 + RNG.uniform(-0.4, 0.4)
        base = np.array([lean * 0.55, h * 0.36, 0.0])
        tip = base + np.array([math.cos(a) * h * 0.26 * spread, h * 0.30, math.sin(a) * h * 0.26 * spread])
        parts.append(P.paint(branch(base, tip, 0.17, 0.07, 3), trunk_col, 0.06))
    cols = [canopy, canopy2, canopy3]
    for k in range(blobs):
        a = RNG.uniform(0, math.tau)
        r = RNG.uniform(0.0, h * 0.28 * spread) * (1.0 if k else 0.0)
        y = h * (0.62 + RNG.uniform(0, 0.32)) - r * 0.18
        rr = h * RNG.uniform(0.17, 0.26)
        parts.append(P.paint(P.blob(rr * 1.05, (math.cos(a) * r + lean * 1.2, y, math.sin(a) * r), (1.0, 0.8, 1.0), sub=0, noise=0.16), cols[k % 3], 0.07))
    # florecitas / pétalos sueltos alrededor de la copa
    for k in range(3):
        a = RNG.uniform(0, math.tau)
        r = RNG.uniform(h * 0.15, h * 0.4)
        parts.append(P.paint(P.blob(h * 0.035, (math.cos(a) * r + lean * 1.2, h * RNG.uniform(0.55, 0.95), math.sin(a) * r), sub=0, noise=0.0), canopy3, 0.05))
    return parts

def tree_bubble(cols, h=8.0):
    parts = [P.paint(branch([0, 0, 0], [0.3, h * 0.7, 0], 0.35, 0.18, 5), (0.55, 0.40, 0.55), 0.06)]
    for k in range(7):
        a = RNG.uniform(0, math.tau)
        r = RNG.uniform(0.3, h * 0.28)
        parts.append(P.paint(P.blob(h * RNG.uniform(0.14, 0.22), (math.cos(a) * r, h * (0.6 + RNG.uniform(0, 0.4)), math.sin(a) * r), sub=0, noise=0.1), cols[k % len(cols)], 0.06))
    return parts

# ───────────── catálogo ─────────────
S = lambda *a: tuple(float(x) for x in a)

PINK = rgb('#f06fa6'); HOT = rgb('#d6246e'); WHITE = rgb('#fbf3f0'); CORAL = rgb('#ff7f68'); BLUSH = rgb('#f7b6cf')
VIOLET = rgb('#8a3fd1'); LILAC = rgb('#b99cf0'); ORANGE = rgb('#ff8a1f'); YELLOW = rgb('#ffcf2a'); RED = rgb('#e3262f')
TEAL = rgb('#25c7b8'); SKY = rgb('#5fb7ff'); MINT = rgb('#8fe3c0'); GOLD = rgb('#f4b73a'); MAGENTA = rgb('#c2186b'); PEACH = rgb('#ffb48a')

CAT = []
def add(name, cat, h, weight, fn):
    parts = [(m, c) for m, c in fn()]
    CAT.append(P.finish(name, parts, cat, h, weight, 'dream (hecho en papel)'))
    print(name, CAT[-1]['tris'])

def build():
    add('d_rosa_rosa', 'flor', 1.1, 2.0, lambda: rosa(PINK, HOT))
    add('d_rosa_roja', 'flor', 1.1, 2.0, lambda: rosa(RED, rgb('#9c1530')))
    add('d_rosa_blanca', 'flor', 1.1, 1.6, lambda: rosa(WHITE, BLUSH))
    add('d_rosa_coral', 'flor', 1.1, 1.8, lambda: rosa(CORAL, PEACH))
    for nm, c1, c2 in [('rosa', PINK, WHITE), ('violeta', VIOLET, LILAC), ('naranja', ORANGE, YELLOW), ('roja', RED, ORANGE), ('amarilla', YELLOW, WHITE)]:
        add('d_tulipan_' + nm, 'flor', 1.2, 2.2, lambda c1=c1, c2=c2: tulipan(c1, c2))
    add('d_loto_magenta', 'flor', 1.0, 1.4, lambda: loto(MAGENTA, PINK))
    add('d_loto_rosa', 'flor', 1.0, 1.4, lambda: loto(PINK, BLUSH))
    add('d_loto_blanco', 'flor', 1.0, 1.0, lambda: loto(WHITE, BLUSH))
    add('d_hibisco_salmon', 'flor', 1.3, 1.6, lambda: hibisco(rgb('#ff8c7a'), RED))
    add('d_hibisco_rojo', 'flor', 1.3, 1.6, lambda: hibisco(RED, rgb('#ff6a3d')))
    add('d_hibisco_magenta', 'flor', 1.3, 1.6, lambda: hibisco(MAGENTA, PINK))
    add('d_lirio_amarillo', 'flor', 1.3, 1.5, lambda: lirio(YELLOW, ORANGE))
    add('d_lirio_naranja', 'flor', 1.3, 1.5, lambda: lirio(ORANGE, RED))
    add('d_lirio_rosa', 'flor', 1.3, 1.5, lambda: lirio(PINK, MAGENTA))
    add('d_orquidea_lila', 'flor', 1.4, 1.4, lambda: orquidea(LILAC, VIOLET))
    add('d_orquidea_magenta', 'flor', 1.4, 1.4, lambda: orquidea(rgb('#d890ff'), MAGENTA))
    add('d_girasol', 'flor', 2.1, 1.8, lambda: girasol(YELLOW, rgb('#6b3a14')))
    add('d_girasol_naranja', 'flor', 2.1, 1.2, lambda: girasol(ORANGE, rgb('#4d2a10')))
    add('d_tropical_roja', 'flor', 1.7, 1.2, lambda: tropical(RED, ORANGE, VIOLET))
    add('d_tropical_azul', 'flor', 1.7, 1.2, lambda: tropical(ORANGE, SKY, VIOLET))
    add('d_margarita_rosa', 'flor', 0.9, 2.2, lambda: margarita(PINK, YELLOW))
    add('d_margarita_amarilla', 'flor', 0.9, 2.2, lambda: margarita(YELLOW, rgb('#e07a1f')))
    add('d_margarita_lila', 'flor', 0.9, 2.2, lambda: margarita(LILAC, YELLOW))
    add('d_flor_celeste', 'flor', 0.8, 2.4, lambda: flor_simple(SKY, YELLOW))
    add('d_flor_durazno', 'flor', 0.8, 2.4, lambda: flor_simple(PEACH, rgb('#c2410c')))
    add('d_flor_lila', 'flor', 0.8, 2.4, lambda: flor_simple(LILAC, WHITE))
    add('d_flor_menta', 'flor', 0.8, 2.0, lambda: flor_simple(MINT, YELLOW))
    # arbustos
    add('d_arbusto_rosa', 'arbusto', 1.5, 2.0, lambda: arbusto_color(PINK, WHITE, HOT))
    add('d_arbusto_lila', 'arbusto', 1.5, 2.0, lambda: arbusto_color(LILAC, VIOLET, WHITE))
    add('d_arbusto_dorado', 'arbusto', 1.5, 1.8, lambda: arbusto_color(GOLD, ORANGE, YELLOW))
    add('d_arbusto_turquesa', 'arbusto', 1.5, 1.6, lambda: arbusto_color(TEAL, MINT, SKY))
    add('d_arbusto_coral', 'arbusto', 1.5, 1.8, lambda: arbusto_color(CORAL, RED, PEACH))
    add('d_bambu_verde', 'bambu', 6.0, 1.4, lambda: bambu((0.55, 0.70, 0.22), (0.30, 0.50, 0.15)))
    add('d_bambu_dorado', 'bambu', 5.0, 1.0, lambda: bambu((0.90, 0.72, 0.25), (0.45, 0.60, 0.20), 4, 5.0))
    add('d_bambu_rosado', 'bambu', 5.5, 0.8, lambda: bambu((0.85, 0.55, 0.62), (0.40, 0.58, 0.28), 4, 5.5))
    # plantas
    add('d_alga_turquesa', 'planta', 1.6, 1.6, lambda: alga((0.10, 0.62, 0.52), (0.15, 0.72, 0.45)))
    add('d_alga_azul', 'planta', 1.6, 1.2, lambda: alga((0.13, 0.50, 0.75), (0.20, 0.65, 0.70)))
    add('d_helecho_azulado', 'planta', 1.1, 1.8, lambda: helecho_dream((0.12, 0.55, 0.55), (0.20, 0.65, 0.40)))
    add('d_helecho_magenta', 'planta', 1.1, 1.2, lambda: helecho_dream((0.55, 0.20, 0.55), (0.75, 0.30, 0.55)))
    add('d_nenufar', 'planta', 0.2, 1.0, lambda: nenufar((0.13, 0.52, 0.32), (0.20, 0.65, 0.35)))
    add('d_hongo_rojo', 'planta', 1.3, 1.4, lambda: hongo(rgb('#e0312e'), WHITE, 1.3))
    add('d_hongo_naranja', 'planta', 1.2, 1.4, lambda: hongo(rgb('#f08a2e'), rgb('#fff2d0'), 1.2))
    add('d_hongo_magenta', 'planta', 1.6, 1.0, lambda: hongo(MAGENTA, rgb('#ffd1ec'), 1.6, (0.95, 0.85, 0.95), 1.2))
    add('d_hongo_celeste', 'planta', 1.6, 0.8, lambda: hongo(rgb('#4aa3ff'), rgb('#eaf6ff'), 1.6, (0.88, 0.93, 0.98), 1.2))
    # pastos con penachos de color
    add('d_pasto_rosado', 'pasto', 1.5, 3.0, lambda: pasto_color((0.40, 0.68, 0.30), (0.55, 0.78, 0.35), PINK))
    add('d_pasto_dorado', 'pasto', 1.5, 3.0, lambda: pasto_color((0.62, 0.72, 0.28), (0.80, 0.76, 0.30), GOLD))
    add('d_pasto_turquesa', 'pasto', 1.5, 2.6, lambda: pasto_color((0.22, 0.65, 0.52), (0.35, 0.75, 0.55), SKY))
    add('d_pasto_lila', 'pasto', 1.5, 2.6, lambda: pasto_color((0.38, 0.62, 0.40), (0.52, 0.70, 0.46), LILAC))
    # árboles
    add('d_sakura_rosa', 'arbol', 9.0, 2.0, lambda: tree_flowering(rgb('#f9a9c8'), rgb('#f67fb0'), rgb('#ffd6e7'), h=9.0, lean=0.5))
    add('d_sakura_blanco', 'arbol', 8.5, 1.4, lambda: tree_flowering(rgb('#fff1f4'), rgb('#ffd3e1'), rgb('#ffffff'), h=8.5, lean=-0.4))
    add('d_sakura_intenso', 'arbol', 9.5, 1.4, lambda: tree_flowering(rgb('#e8458f'), rgb('#f27ab0'), rgb('#ffb0d0'), h=9.5, lean=0.3))
    add('d_jacaranda', 'arbol', 10.0, 1.6, lambda: tree_flowering(rgb('#a98af0'), rgb('#c5b0ff'), rgb('#8a63e0'), h=10.0, lean=-0.3))
    add('d_arce_dorado', 'arbol', 9.5, 1.4, lambda: tree_flowering(rgb('#ffc533'), rgb('#ff9a2a'), rgb('#ffe27a'), h=9.5, lean=0.4))
    add('d_arbol_coral', 'arbol', 8.5, 1.2, lambda: tree_flowering(rgb('#ff7a66'), rgb('#ff9c80'), rgb('#ffb99a'), h=8.5, lean=-0.5))
    add('d_arbol_turquesa', 'arbol', 10.5, 1.2, lambda: tree_flowering(rgb('#2cc7b6'), rgb('#6be0c8'), rgb('#9af2dc'), (0.35, 0.30, 0.45), h=10.5, lean=0.2))
    add('d_arbol_burbujas', 'arbol', 8.0, 1.2, lambda: tree_bubble([rgb('#ff9ad0'), rgb('#9ad7ff'), rgb('#ffe27a'), rgb('#b9f0b0')], 8.0))
    add('d_arbol_burbujas2', 'arbol', 11.0, 1.0, lambda: tree_bubble([rgb('#c79cff'), rgb('#ffb199'), rgb('#8fe3c0')], 11.0))

def main():
    build()
    path = os.path.join(P.OUT, 'catalog.json')
    cat = json.load(open(path)) if os.path.exists(path) else []
    keep = [c for c in cat if not str(c['id']).startswith('d_')]
    json.dump(keep + CAT, open(path, 'w'), indent=0, ensure_ascii=False)
    print(len(CAT), 'piezas de ensueño ·', len(keep) + len(CAT), 'en el catálogo')

if __name__ == '__main__':
    main()
