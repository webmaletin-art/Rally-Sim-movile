"""Piezas de papel de los mapas fantasía planetarios: Marte (m_*), la Luna (l_*) y el Anillo de Júpiter (r_*), más los pórticos (x_*).
Todo es papercraft: mallas de pocos triángulos con una cara = un color liso (caras iluminadas según hacia dónde miran, como papel doblado).
Salida: godot/game/models/paper/<id>.pap  y se suman a catalog.json (correr primero paperize.py).
Uso:  python3 tools/paper/spacepieces.py
"""
import json, math, os, sys
import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(__file__))
import paperize as P  # noqa: E402

RNG = np.random.default_rng(2077)

def rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])

# ───────────── ayudantes ─────────────
def shade(m, base, k=0.42, jit=0.08, cool=None):
    """Colorea cada cara según hacia dónde mira (más clara arriba, más oscura abajo y de costado), con variación de cara en cara"""
    base = np.asarray(base, dtype=float)
    n = m.face_normals
    lit = np.clip(0.5 + 0.5 * n[:, 1], 0, 1)
    side = 0.5 + 0.5 * n[:, 0]
    f = 0.84 + 0.50 * k * (0.6 * lit + 0.4 * side) + 0.10 * k
    cols = np.clip(base[None, :] * f[:, None], 0, 1)
    if cool is not None:
        cols = np.clip(cols + (np.asarray(cool) * (1.0 - lit))[:, None].T * 0.0, 0, 1)
    return (m, P.stylize(cols * 255.0, jit))

def flat(m, c, jit=0.06):
    return P.paint(m, c, jit)

def box(sx, sy, sz, pos=(0, 0, 0), jit=0.0, rot=None):
    m = trimesh.creation.box(extents=(sx, sy, sz))
    if jit > 0:
        v = m.vertices + RNG.uniform(-jit, jit, m.vertices.shape)
        m.vertices = v
    if rot is not None:
        m.apply_transform(trimesh.transformations.rotation_matrix(rot[0], rot[1]))
    m.apply_translation(pos)
    return m

def cyl(r, h, pos=(0, 0, 0), sections=8, r_top=None):
    """Cilindro vertical (eje y) con base en pos; r_top < r lo vuelve un cono truncado"""
    m = trimesh.creation.cylinder(radius=r, height=h, sections=sections)
    m = P.to_y_up(m)
    if r_top is not None:
        v = m.vertices.copy()
        top = v[:, 1] > 0
        v[top, 0] *= r_top / r
        v[top, 2] *= r_top / r
        m.vertices = v
    m.apply_translation((pos[0], pos[1] + h / 2, pos[2]))
    return m

def pyramid(r, h, pos=(0, 0, 0), sections=6):
    m = trimesh.creation.cone(radius=r, height=h, sections=sections)
    m = P.to_y_up(m)
    m.apply_translation((pos[0], pos[1] + h / 2, pos[2]))
    return m

def lump(r, pos=(0, 0, 0), scale=(1, 1, 1), sub=1, noise=0.22, cut_base=True):
    m = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    v = m.vertices * np.array(scale)
    v = v * (1.0 + RNG.uniform(-noise, noise, (len(v), 1)))
    if cut_base:
        v[:, 1] = np.maximum(v[:, 1], -0.15 * r * scale[1])
    m.vertices = v + np.array(pos)
    return m

def tilt(m, ax, ang, about=(0, 0, 0)):
    m = m.copy()
    m.apply_transform(trimesh.transformations.rotation_matrix(ang, ax, about))
    return m

def moved(m, d):
    m = m.copy()
    m.apply_translation(d)
    return m

def spire(h, r, sections=5, bend=0.0, taper=0.12):
    m = cyl(r, h, (0, 0, 0), sections, r * taper)
    v = m.vertices.copy()
    v[:, 0] += bend * (v[:, 1] / h) ** 2 * h * 0.25
    v += RNG.uniform(-r * 0.12, r * 0.12, v.shape)
    m.vertices = v
    return m

# ───────────── rocas generales ─────────────
def boulder(col, h=1.0, wide=1.2, noise=0.24, sub=1, seed_flat=0.6):
    m = lump(1.0, (0, 0.45, 0), (wide, seed_flat, wide * 0.85), sub, noise)
    return [shade(m, col, 0.5, 0.07)]

def slab(col, w=2.4, d=1.6, h=0.5, n=2):
    parts = []
    for i in range(n):
        m = box(w * (1 - 0.18 * i), h, d * (1 - 0.15 * i), (RNG.uniform(-0.2, 0.2), h / 2 + i * h * 0.9, RNG.uniform(-0.2, 0.2)), 0.07)
        m = tilt(m, [0, 1, 0], RNG.uniform(-0.5, 0.5))
        parts.append(shade(m, col, 0.45, 0.07))
    return parts

def rock_cluster(cols, n=4, spread=1.4, size=(0.5, 1.1)):
    parts = []
    for i in range(n):
        a = RNG.uniform(0, math.tau)
        rr = RNG.uniform(0, spread)
        s = RNG.uniform(*size)
        parts.append(shade(lump(s, (math.cos(a) * rr, s * 0.3, math.sin(a) * rr), (1.2, 0.75, 1.0), 1, 0.25), cols[i % len(cols)], 0.5, 0.07))
    return parts

def spires(cols, n=3, h=(4.0, 7.0), r=(0.7, 1.1), spread=1.1):
    parts = []
    for i in range(n):
        a = i * math.tau / n + RNG.uniform(-0.4, 0.4)
        rr = 0.0 if i == 0 else spread * RNG.uniform(0.7, 1.1)
        hh = RNG.uniform(*h) * (1.0 if i == 0 else 0.75)
        m = spire(hh, RNG.uniform(*r), 5, RNG.uniform(-0.5, 0.5))
        m.apply_translation((math.cos(a) * rr, 0, math.sin(a) * rr))
        parts.append(shade(m, cols[i % len(cols)], 0.5, 0.07))
    parts += rock_cluster(cols, 3, spread * 1.3, (0.4, 0.7))
    return parts

def mesa(cols, w=5.0, h=6.0, layers=6, narrow=0.9):
    """Meseta de capas de colores (sedimentos): prismas hexagonales apilados, cada capa un poco distinta"""
    parts = []
    y = 0.0
    for i in range(layers):
        lh = h / layers * RNG.uniform(0.8, 1.2)
        r = w * (1 - 0.05 * i) * RNG.uniform(0.9, 1.0)
        r *= narrow if i == layers - 1 else 1.0
        m = cyl(r, lh, (RNG.uniform(-0.15, 0.15), y, RNG.uniform(-0.15, 0.15)), 7, r * 0.97)
        v = m.vertices + RNG.uniform(-0.12, 0.12, m.vertices.shape) * w * 0.08
        m.vertices = v
        parts.append(shade(m, cols[i % len(cols)], 0.35, 0.05))
        y += lh
    return parts

def rock_arch(col, span=6.0, h=5.0, thick=1.1, n=9):
    parts = []
    for side in (-1, 1):
        parts.append(shade(moved(spire(h * 0.55, thick * 0.9, 6, 0.0, 0.8), (side * span / 2, 0, 0)), col, 0.5, 0.06))
    for i in range(n):
        a = math.pi * i / (n - 1)
        c = (math.cos(a) * span / 2, h * 0.5 + math.sin(a) * h * 0.5, 0)
        b = box(thick * 1.3, thick * 1.1, thick * 1.3, c, 0.12)
        b = tilt(b, [0, 0, 1], a - math.pi / 2, c)
        parts.append(shade(b, col, 0.5, 0.07))
    return parts

def crystal_cluster(cols, n=6, h=(1.4, 3.2), r=(0.16, 0.30), spread=0.7, glow=False):
    parts = []
    for i in range(n):
        a = i * math.tau / n + RNG.uniform(-0.4, 0.4)
        rr = 0.0 if i == 0 else spread * RNG.uniform(0.5, 1.0)
        hh = RNG.uniform(*h) * (1.0 if i == 0 else 0.7)
        rad = RNG.uniform(*r)
        body = cyl(rad, hh * 0.72, (0, 0, 0), 6)
        tip = pyramid(rad, hh * 0.28, (0, hh * 0.72, 0), 6)
        c = cols[i % len(cols)]
        lean = RNG.uniform(-0.35, 0.35)
        lean2 = RNG.uniform(-0.3, 0.3)
        pos = (math.cos(a) * rr, 0, math.sin(a) * rr)
        for mm in (body, tip):
            mm = tilt(mm, [1, 0, 0], lean)
            mm = tilt(mm, [0, 0, 1], lean2)
            mm = moved(mm, pos)
            parts.append(shade(mm, c, 0.55 if not glow else 0.3, 0.05))
    return parts

# ───────────── construcciones y cosas hechas por humanos ─────────────
WHITE = rgb('#f4f1ec'); GREY = rgb('#9a9aa2'); DARK = rgb('#46464e'); GOLD = rgb('#e6b73c'); ORANGE = rgb('#f2742b'); RED = rgb('#d6342c'); BLUE = rgb('#3f7fd9')

def antenna(h=7.0, col=WHITE):
    parts = [shade(cyl(0.18, h, (0, 0, 0), 6, 0.1), col, 0.4, 0.04)]
    dish = trimesh.creation.cone(radius=1.0, height=0.45, sections=10)
    dish = P.to_y_up(dish)
    dish = tilt(dish, [1, 0, 0], math.pi)  # boca hacia arriba
    dish = tilt(dish, [1, 0, 0], -0.7)
    dish.apply_translation((0, h * 0.82, 0.25))
    parts.append(shade(dish, rgb('#e8e6e0'), 0.4, 0.04))
    parts.append(flat(lump(0.16, (0, h + 0.1, 0), sub=0, noise=0.0, cut_base=False), RED, 0.0))
    parts.append(shade(box(1.6, 0.14, 1.6, (0, 0.07, 0)), GREY, 0.4, 0.05))
    return parts

def solar_panels(col=BLUE, n=2):
    parts = [shade(cyl(0.12, 1.0, (0, 0, 0), 6), GREY, 0.4)]
    for i in range(n):
        for side in (-1, 1):
            p = box(2.2, 0.06, 1.3, (side * 1.3, 1.5 + i * 0.1, i * 1.5 - 0.5 * (n - 1) * 0.75), 0.0)
            p = tilt(p, [0, 0, 1], side * -0.25, (0, 1.2, 0))
            parts.append(shade(p, col, 0.5, 0.04))
            parts.append(flat(box(2.3, 0.03, 0.06, (side * 1.3, 1.55 + i * 0.1, i * 1.5 - 0.5 * (n - 1) * 0.75)), WHITE, 0.0))
    return parts

def dome(col=WHITE, r=3.0, ring=ORANGE):
    m = trimesh.creation.icosphere(subdivisions=1, radius=r)
    v = m.vertices.copy()
    keep = np.unique(m.faces[(v[m.faces][:, :, 1] > -0.05).all(axis=1)])
    v[:, 1] = np.maximum(v[:, 1], 0.0)
    m.vertices = v
    mm = trimesh.Trimesh(vertices=v, faces=m.faces[(v[m.faces][:, :, 1] > 1e-6).any(axis=1)], process=False)
    parts = [shade(mm, col, 0.45, 0.04)]
    parts.append(flat(cyl(r * 1.04, 0.35, (0, 0, 0), 12), ring, 0.03))
    parts.append(flat(box(r * 0.5, r * 0.7, 0.2, (0, r * 0.35, r * 0.92)), DARK, 0.0))
    parts.append(shade(cyl(0.1, r * 1.1, (r * 0.4, r * 0.7, 0), 5), WHITE, 0.3))
    return parts

def lander():
    parts = []
    parts.append(shade(cyl(2.2, 1.7, (0, 1.9, 0), 8, 1.9), GOLD, 0.4, 0.06))
    parts.append(shade(cyl(1.6, 1.0, (0, 3.5, 0), 8, 1.2), rgb('#cfcfd6'), 0.4, 0.04))
    parts.append(flat(lump(0.6, (0, 4.5, 0.2), (1.0, 0.8, 1.0), 0, 0.0, False), rgb('#2a2f4a'), 0.03))
    parts.append(shade(cyl(0.12, 0.8, (0, 4.4, 0), 5), GREY, 0.3))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        top = np.array([math.cos(a) * 1.7, 1.9, math.sin(a) * 1.7])
        foot = np.array([math.cos(a) * 3.4, 0.2, math.sin(a) * 3.4])
        parts.append(shade(_strut(top, foot, 0.1), GOLD if k % 2 else rgb('#d8d8de'), 0.4, 0.05))
        parts.append(shade(cyl(0.65, 0.18, (foot[0], 0.0, foot[2]), 8), rgb('#cfcfd6'), 0.4, 0.04))
    parts.append(shade(box(0.5, 1.8, 0.1, (0, 1.2, 2.4), 0.0), GREY, 0.3))
    return parts

def _strut(a, b, r):
    d = b - a
    L = float(np.linalg.norm(d))
    m = trimesh.creation.cylinder(radius=r, height=L, sections=5)
    z = np.array([0.0, 0.0, 1.0])
    ax = np.cross(z, d / L)
    if np.linalg.norm(ax) > 1e-6:
        m.apply_transform(trimesh.transformations.rotation_matrix(math.acos(np.clip(np.dot(z, d / L), -1, 1)), ax / np.linalg.norm(ax)))
    m.apply_translation((a + b) / 2)
    return m

def rover(body=WHITE):
    parts = [shade(box(2.6, 0.6, 1.5, (0, 0.95, 0), 0.03), body, 0.4, 0.04), shade(box(1.2, 0.5, 1.1, (-0.3, 1.5, 0)), GOLD, 0.4, 0.05)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            w = trimesh.creation.cylinder(radius=0.5, height=0.4, sections=8)
            w.apply_translation((sx * 1.0, 0.5, sz * 0.95))
            parts.append(shade(w, DARK, 0.3, 0.05))
    parts.append(shade(cyl(0.07, 1.6, (0.9, 1.2, 0.3), 5), GREY, 0.3))
    d = trimesh.creation.cone(radius=0.5, height=0.2, sections=8)
    d = P.to_y_up(d)
    d.apply_translation((0.9, 2.9, 0.3))
    parts.append(shade(d, WHITE, 0.3))
    return parts

def flagpole(c1, c2, h=4.0, w=2.2):
    parts = [shade(cyl(0.07, h, (0, 0, 0), 5), rgb('#d8d8de'), 0.3, 0.03)]
    for k, c in enumerate((c1, c2, c1)):
        parts.append(flat(box(0.03, w / 3, w, (0.0, h - w / 6 - k * w / 3 * 0.98 + 0.0, w / 2 + 0.07)), c, 0.02))
    parts[1:] = [(moved(tilt(m, [0, 1, 0], 0.0), (0, 0, 0)), c) for m, c in parts[1:]]
    return parts

def astronaut():
    parts = [shade(lump(0.55, (0, 1.2, 0), (0.9, 1.15, 0.7), 1, 0.04, False), WHITE, 0.4, 0.03)]
    parts.append(shade(lump(0.42, (0, 2.15, 0), (1, 1, 1), 1, 0.02, False), WHITE, 0.3, 0.02))
    parts.append(flat(lump(0.30, (0, 2.15, 0.22), (1, 0.95, 0.7), 0, 0.0, False), GOLD, 0.03))
    parts.append(shade(box(0.7, 1.0, 0.45, (0, 1.4, -0.45)), rgb('#d9d9de'), 0.4, 0.04))
    for sx in (-1, 1):
        parts.append(shade(cyl(0.2, 0.9, (sx * 0.3, 0.0, 0), 6), WHITE, 0.4, 0.04))
        parts.append(shade(_strut(np.array([sx * 0.55, 1.5, 0]), np.array([sx * 1.0, 2.5 if sx > 0 else 1.0, 0.1]), 0.15), WHITE, 0.4, 0.04))
    parts.append(flat(box(0.5, 0.2, 0.05, (0, 1.2, 0.38)), ORANGE, 0.0))
    return parts

# ───────────── plantas alienígenas de Marte ─────────────
def cactus_alien(body, tip, nub=3):
    parts = [shade(cyl(0.28, 2.2, (0, 0, 0), 6, 0.2), body, 0.45, 0.06)]
    for i in range(nub):
        a = i * math.tau / nub + RNG.uniform(-0.3, 0.3)
        y = 0.9 + 0.4 * i
        arm = _strut(np.array([0.0, y, 0.0]), np.array([math.cos(a) * 0.9, y + 0.5, math.sin(a) * 0.9]), 0.13)
        parts.append(shade(arm, body, 0.45, 0.06))
        parts.append(shade(cyl(0.12, 0.9, (math.cos(a) * 0.9, y + 0.45, math.sin(a) * 0.9), 5, 0.08), body, 0.45, 0.06))
        parts.append(flat(lump(0.12, (math.cos(a) * 0.9, y + 1.35, math.sin(a) * 0.9), sub=0, noise=0.0, cut_base=False), tip, 0.03))
    parts.append(flat(lump(0.2, (0, 2.3, 0), sub=0, noise=0.0, cut_base=False), tip, 0.03))
    return parts

def liquen(cols, r=1.6, n=5):
    parts = []
    for i in range(n):
        a = RNG.uniform(0, math.tau)
        rr = RNG.uniform(0, r * 0.6)
        m = cyl(RNG.uniform(0.35, 0.7), 0.1, (math.cos(a) * rr, 0, math.sin(a) * rr), 6)
        parts.append(shade(m, cols[i % len(cols)], 0.25, 0.06))
    return parts

def dust_devil(col, h=9.0, r=2.0):
    parts = []
    n = 6
    for i in range(n):
        s = i / (n - 1)
        rad = r * (0.35 + 1.35 * s)
        m = cyl(rad, h / n * 1.05, (math.sin(s * 3.5) * 0.7 * s, h * s * (n - 1) / n, math.cos(s * 3.5) * 0.7 * s), 7, rad * 1.2)
        v = m.vertices + RNG.uniform(-0.1, 0.1, m.vertices.shape) * r * 0.3
        m.vertices = v
        parts.append(shade(m, col * (0.85 + 0.15 * s), 0.25, 0.07))
    return parts

# ───────────── Luna ─────────────
def crater_rim(col, r=4.0, n=9):
    parts = []
    for i in range(n):
        a = i * math.tau / n + RNG.uniform(-0.1, 0.1)
        s = RNG.uniform(0.8, 1.4)
        parts.append(shade(lump(1.0 * s, (math.cos(a) * r, 0.1, math.sin(a) * r), (1.6, 0.6, 1.0), 1 if i % 4 == 0 else 0, 0.2), col, 0.5, 0.07))
    return parts

# ───────────── Anillo ─────────────
def ice_shard(col, tint, h=2.4, w=1.1):
    m = trimesh.creation.icosphere(subdivisions=0, radius=1.0)
    v = m.vertices * np.array([w, h * 0.5, w * 0.8])
    v = v * (1.0 + RNG.uniform(-0.2, 0.2, (len(v), 1)))
    v[:, 1] += h * 0.5
    m.vertices = v
    mm = tilt(m, [1, 0, 1], RNG.uniform(-0.3, 0.3))
    return [shade(mm, col, 0.55, 0.06)]

def ice_field(cols, n=5, spread=1.4):
    parts = []
    for i in range(n):
        a = RNG.uniform(0, math.tau)
        rr = RNG.uniform(0, spread)
        parts += [(moved(m, (math.cos(a) * rr, 0, math.sin(a) * rr)), c) for m, c in ice_shard(cols[i % len(cols)], None, RNG.uniform(0.9, 2.4), RNG.uniform(0.5, 1.0))]
    return parts

def floating_rock(top, under, h=3.0):
    parts = [shade(lump(1.8, (0, 1.4, 0), (1.3, 0.55, 1.0), 1, 0.2, False), top, 0.5, 0.06)]
    cone = P.to_y_up(trimesh.creation.cone(radius=1.5, height=h, sections=6))
    cone = tilt(cone, [1, 0, 0], math.pi)
    cone.vertices = cone.vertices * np.array([1, 1, 1]) + RNG.uniform(-0.15, 0.15, cone.vertices.shape)
    cone.apply_translation((0, 1.0 - 0.0, 0))
    parts.append(shade(cone, under, 0.5, 0.06))
    return parts

def comet(ice, tail, r=1.4):
    parts = [shade(lump(r, (0, r, 0), (1, 1, 1), 1, 0.15, False), ice, 0.5, 0.05)]
    for k in range(3):
        c = P.to_y_up(trimesh.creation.cone(radius=r * (0.9 - 0.2 * k), height=r * 5.0, sections=6))
        c = tilt(c, [0, 0, 1], -math.pi / 2 + 0.15 * (k - 1))
        c = tilt(c, [0, 0, 1], math.pi)
        c.apply_translation((r * 0.4, r, 0.0))
        parts.append(shade(c, tail * (1.0 - 0.1 * k), 0.2, 0.06))
    return parts

def moon_ball(c1, c2, r=3.0, sub=2):
    m = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    cen = m.triangles_center
    n = np.sin(cen[:, 0] * 0.9) * np.cos(cen[:, 1] * 1.1) + np.sin(cen[:, 2] * 1.3)
    cols = np.where((n > 0.2)[:, None], c1[None, :], c2[None, :]) * (0.9 + 0.1 * (cen[:, 1] / r + 1.0)[:, None])
    return [(m, P.stylize(np.clip(cols, 0, 1) * 255.0, 0.06))]

def mini_ring(col, r=3.0, tube=0.18, tilt_a=0.5):
    t = trimesh.creation.torus(major_radius=r, minor_radius=tube, major_sections=14, minor_sections=4)
    t = P.to_y_up(t)
    t = tilt(t, [1, 0, 0], tilt_a)
    t.apply_translation((0, r * 0.7, 0))
    parts = [shade(t, col, 0.4, 0.05)]
    parts.append(shade(lump(r * 0.28, (0, r * 0.7, 0), sub=1, noise=0.05, cut_base=False), rgb('#e8d9c4'), 0.4, 0.04))
    return parts

def station():
    t = trimesh.creation.torus(major_radius=3.4, minor_radius=0.55, major_sections=14, minor_sections=5)
    t = P.to_y_up(t)
    t = tilt(t, [1, 0, 0], 0.35)
    t.apply_translation((0, 4.0, 0))
    parts = [shade(t, WHITE, 0.4, 0.04)]
    parts.append(shade(cyl(0.6, 4.2, (0, 1.8, 0), 8), GREY, 0.4, 0.04))
    for k in range(4):
        a = k * math.pi / 2
        parts.append(shade(_strut(np.array([0.0, 4.0, 0.0]), np.array([math.cos(a) * 3.4, 4.0 + math.sin(a) * 1.0, math.sin(a) * 3.4 * 0.9]), 0.12), GOLD, 0.3, 0.04))
    parts.append(shade(box(5.0, 0.1, 1.2, (0, 4.0, 0.0)), BLUE, 0.5, 0.05))
    return parts

def satellite():
    parts = [shade(box(1.3, 1.3, 1.3, (0, 1.0, 0)), GOLD, 0.4, 0.06)]
    for sx in (-1, 1):
        parts.append(shade(box(2.6, 0.06, 1.2, (sx * 2.2, 1.0, 0)), BLUE, 0.5, 0.04))
    d = P.to_y_up(trimesh.creation.cone(radius=0.7, height=0.3, sections=9))
    d = tilt(d, [1, 0, 0], math.pi)
    d.apply_translation((0, 2.1, 0))
    parts.append(shade(d, WHITE, 0.3))
    return parts

# ───────────── pórticos (arcos sobre la ruta: 24,4 m de ancho entre pilares) ─────────────
SPAN = 24.4

def portico_mars():
    parts = []
    for side in (-1, 1):
        parts.append(shade(moved(spire(8.5, 1.9, 6, 0.0, 0.8), (side * SPAN / 2, 0, 0)), rgb('#b8552f'), 0.5, 0.06))
        parts += [(moved(m, (side * SPAN / 2 + side * 1.6, 0, 0.8)), c) for m, c in rock_cluster([rgb('#9c4528'), rgb('#c96a3c')], 3, 1.0, (0.6, 1.0))]
    for i in range(13):
        a = math.pi * i / 12
        c = (math.cos(a) * SPAN / 2, 7.0 + math.sin(a) * 5.0, 0)
        b = box(2.4, 1.9, 2.4, c, 0.18)
        b = tilt(b, [0, 0, 1], a - math.pi / 2, c)
        parts.append(shade(b, [rgb('#b8552f'), rgb('#d27a45'), rgb('#9c4528')][i % 3], 0.5, 0.07))
    return parts

def portico_moon():
    parts = []
    for side in (-1, 1):
        parts.append(shade(box(1.2, 9.5, 1.2, (side * SPAN / 2, 4.75, 0)), WHITE, 0.4, 0.04))
        for k in range(5):
            parts.append(flat(box(1.3, 0.5, 1.3, (side * SPAN / 2, 1.2 + k * 1.9, 0)), ORANGE if k % 2 == 0 else WHITE, 0.0))
    parts.append(shade(box(SPAN + 1.2, 1.4, 1.4, (0, 9.8, 0)), WHITE, 0.4, 0.04))
    for k in range(12):
        parts.append(flat(box(1.0, 1.42, 1.42, (-SPAN / 2 + 1.0 + k * (SPAN - 2.0) / 11, 9.8, 0)), ORANGE if k % 2 == 0 else rgb('#2a2f4a'), 0.0))
    parts.append(shade(box(SPAN * 0.5, 1.8, 0.2, (0, 11.6, 0)), rgb('#2a2f4a'), 0.3, 0.02))
    return parts

def portico_ring():
    parts = []
    for side in (-1, 1):
        parts += [(moved(m, (side * SPAN / 2, 0, 0)), c) for m, c in crystal_cluster([rgb('#8fe3ff'), rgb('#b9a6ff'), rgb('#ffffff')], 5, (4.0, 9.0), (0.5, 0.9), 1.4, True)]
    for i in range(11):
        a = math.pi * i / 10
        c = (math.cos(a) * SPAN / 2, 7.5 + math.sin(a) * 4.5, 0)
        body = cyl(0.95, 3.8, (0, -1.9, 0), 6, 0.6)
        body = tilt(body, [0, 0, 1], a)  # el eje de cada cristal sigue la curva del arco
        body.apply_translation(c)
        parts.append(shade(body, [rgb('#8fe3ff'), rgb('#ffffff'), rgb('#c8b6ff')][i % 3], 0.4, 0.05))
    return parts

# ───────────── catálogo ─────────────
CAT = []
def add(name, cat, h, fn, w=1.0, src='planetas (hecho en papel)', maxt=420):
    parts = list(fn())
    CAT.append(P.finish(name, parts, cat, h, w, src))
    t = CAT[-1]['tris']
    print(name, t)
    assert t <= maxt, (name, t)

def build():
    # —— Marte ——
    R1, R2, R3, R4 = rgb('#c25a30'), rgb('#dd8550'), rgb('#a24a2c'), rgb('#e8b078')
    for i, c in enumerate([R1, R2, R3, R4]):
        add('m_roca_%d' % (i + 1), 'roca', 1.2 + 0.2 * i, lambda c=c: boulder(c, wide=1.2 + 0.1 * i))
    add('m_roca_grande', 'roca', 3.4, lambda: boulder(R3, wide=1.3, noise=0.28, sub=1))
    add('m_lajas', 'roca', 1.2, lambda: slab(R2, 3.0, 2.0, 0.45, 3))
    add('m_rocas', 'roca', 1.6, lambda: rock_cluster([R1, R2, R3, R4], 5, 1.6))
    add('m_picos', 'roca', 6.5, lambda: spires([R1, R3, R2], 3, (4.5, 7.5), (0.7, 1.1)))
    add('m_picos_altos', 'roca', 12.0, lambda: spires([R3, R1], 2, (9.0, 13.0), (1.0, 1.5), 1.6))
    add('m_mesa', 'roca', 9.0, lambda: mesa([R1, R2, R4, R3, R2, R1], 5.5, 9.0, 6))
    add('m_mesa_baja', 'roca', 4.2, lambda: mesa([R2, R4, R1, R3], 4.0, 4.2, 4, 0.95))
    add('m_arco', 'roca', 8.5, lambda: rock_arch(R1, 7.5, 7.5, 1.3))
    add('m_cristal_rojo', 'roca', 2.6, lambda: crystal_cluster([rgb('#ff6a4d'), rgb('#ff9a6a'), rgb('#c93a3a')], 6, (1.4, 3.2), (0.16, 0.30), 0.7, True))
    add('m_cristal_violeta', 'roca', 2.4, lambda: crystal_cluster([rgb('#b078ff'), rgb('#d9a6ff'), rgb('#7a46d8')], 5, (1.2, 2.8), (0.16, 0.28), 0.6, True))
    add('m_cactus', 'planta', 2.4, lambda: cactus_alien(rgb('#3fa88f'), rgb('#ff6fa8')))
    add('m_cactus2', 'planta', 2.0, lambda: cactus_alien(rgb('#9a6fd8'), rgb('#ffd35a'), 2))
    add('m_liquen', 'planta', 0.2, lambda: liquen([rgb('#e8b04a'), rgb('#d86a3a'), rgb('#9d4a8f'), rgb('#5fb8a0')]))
    add('m_polvo', 'roca', 9.0, lambda: dust_devil(rgb('#e9b98a')))
    add('m_antena', 'obra', 7.0, lambda: antenna(7.0))
    add('m_paneles', 'obra', 2.2, lambda: solar_panels(BLUE, 2))
    add('m_cupula', 'obra', 3.4, lambda: dome(WHITE, 3.0, ORANGE))
    add('m_rover', 'obra', 3.2, lambda: rover(WHITE))
    add('m_bandera', 'obra', 4.0, lambda: flagpole(ORANGE, WHITE))
    # —— Luna ——
    G1, G2, G3, G4 = rgb('#9a9aa0'), rgb('#c4c4c8'), rgb('#74747c'), rgb('#e0e0e2')
    for i, c in enumerate([G1, G2, G3, G4]):
        add('l_roca_%d' % (i + 1), 'roca', 1.0 + 0.2 * i, lambda c=c: boulder(c, wide=1.2 + 0.1 * i, noise=0.27))
    add('l_roca_grande', 'roca', 3.2, lambda: boulder(G3, wide=1.35, noise=0.3))
    add('l_rocas', 'roca', 1.5, lambda: rock_cluster([G1, G2, G3, G4], 5, 1.5))
    add('l_lajas', 'roca', 1.1, lambda: slab(G2, 3.0, 2.0, 0.4, 3))
    add('l_cresta', 'roca', 5.0, lambda: spires([G1, G3, G2], 3, (3.0, 5.2), (0.9, 1.3), 1.3))
    add('l_borde_crater', 'roca', 1.3, lambda: crater_rim(G2, 4.5, 9))
    add('l_cristal', 'roca', 2.2, lambda: crystal_cluster([rgb('#7fe0ff'), rgb('#b0f0ff'), rgb('#4fb4ff')], 5, (1.2, 2.6), (0.14, 0.26), 0.55, True))
    add('l_modulo', 'obra', 5.4, lander)
    add('l_rover', 'obra', 3.2, lambda: rover(rgb('#eeeeee')))
    add('l_bandera', 'obra', 4.0, lambda: flagpole(RED, WHITE))
    add('l_astronauta', 'obra', 2.6, astronaut)
    add('l_antena', 'obra', 8.0, lambda: antenna(8.0))
    add('l_paneles', 'obra', 2.2, lambda: solar_panels(rgb('#2f6fe0'), 2))
    add('l_cupula', 'obra', 3.4, lambda: dome(rgb('#eeeeee'), 3.0, rgb('#4f8dd8')))
    # —— Anillo de Júpiter ——
    I1, I2, I3, I4 = rgb('#d8f2ff'), rgb('#9fd4f2'), rgb('#ffffff'), rgb('#c4b3f2')
    add('r_hielo_1', 'roca', 2.4, lambda: ice_field([I1, I2, I3], 4, 1.2))
    add('r_hielo_2', 'roca', 1.6, lambda: ice_field([I2, I4, I3], 5, 1.5))
    add('r_hielo_3', 'roca', 4.5, lambda: ice_field([I1, I3, I2, I4], 5, 1.8))
    add('r_hielo_bajo', 'roca', 0.8, lambda: ice_field([I1, I3], 6, 1.8))
    add('r_cristal_cian', 'roca', 4.5, lambda: crystal_cluster([rgb('#6fe6ff'), rgb('#b8f4ff'), rgb('#3fb8ef')], 6, (2.2, 4.8), (0.22, 0.4), 0.9, True))
    add('r_cristal_magenta', 'roca', 4.2, lambda: crystal_cluster([rgb('#ff7ad0'), rgb('#ffb0e8'), rgb('#c04ab0')], 5, (2.0, 4.4), (0.22, 0.4), 0.8, True))
    add('r_cristal_dorado', 'roca', 3.6, lambda: crystal_cluster([rgb('#ffd66a'), rgb('#fff0a0'), rgb('#ff9a3a')], 5, (1.8, 3.8), (0.2, 0.35), 0.8, True))
    add('r_cristal_gigante', 'roca', 14.0, lambda: crystal_cluster([rgb('#8fe3ff'), rgb('#c8b6ff'), rgb('#ffffff')], 5, (8.0, 14.0), (0.9, 1.5), 3.0, True))
    add('r_roca_ocre', 'roca', 1.6, lambda: boulder(rgb('#b8895a'), wide=1.3, noise=0.28))
    add('r_roca_gris', 'roca', 1.2, lambda: rock_cluster([rgb('#8a8a96'), rgb('#b0b0ba'), rgb('#6a6a78')], 4, 1.3))
    add('r_roca_flotante', 'roca', 5.0, lambda: floating_rock(rgb('#b8a48a'), rgb('#6a5a4a'), 3.2))
    add('r_roca_flotante2', 'roca', 4.0, lambda: floating_rock(rgb('#c8e0f0'), rgb('#7a9ab8'), 2.6))
    add('r_cometa', 'roca', 3.0, lambda: comet(rgb('#e6f4ff'), rgb('#9ad0f5')))
    add('r_luna_io', 'roca', 6.0, lambda: moon_ball(rgb('#f2c84a'), rgb('#e0762a'), 3.0))
    add('r_luna_europa', 'roca', 5.0, lambda: moon_ball(rgb('#f4efe6'), rgb('#c89a78'), 2.5))
    add('r_luna_ganimedes', 'roca', 7.0, lambda: moon_ball(rgb('#a89c8a'), rgb('#6e6458'), 3.5))
    add('r_mini_anillo', 'roca', 4.4, lambda: mini_ring(rgb('#f2d9a8'), 3.0))
    add('r_estacion', 'obra', 8.0, station)
    add('r_satelite', 'obra', 3.2, satellite)
    # —— pórticos ——
    add('x_portico_marte', 'obra', 12.0, portico_mars, maxt=900)
    add('x_portico_luna', 'obra', 12.5, portico_moon, maxt=900)
    add('x_portico_anillo', 'obra', 12.0, portico_ring, maxt=900)

def main():
    build()
    path = os.path.join(P.OUT, 'catalog.json')
    cat = json.load(open(path)) if os.path.exists(path) else []
    keep = [c for c in cat if not str(c['id']).startswith(('m_', 'l_', 'r_', 'x_'))]
    json.dump(keep + CAT, open(path, 'w'), indent=0, ensure_ascii=False)
    print(len(CAT), 'piezas de planetas ·', len(keep) + len(CAT), 'en el catálogo')

if __name__ == '__main__':
    main()
