"""Convierte el pack de vegetación y suelo (GLB) a «papercraft»: mallas de pocos triángulos con una cara = un color liso (como papel
doblado), listas para dibujarse con el shader de papel (godot/game/fx/paper.gdshader).
Salida: godot/game/models/paper/<id>.pap  (+ catalog.json con alto, triángulos y categoría de cada pieza)
Uso:  python3 tools/paper/paperize.py <carpeta con el pack descomprimido>

Formato .pap:  'PAP1' · u32 nv · f32[nv*3] posiciones · u8[nv*4] colores RGBA (sRGB; una cara = tres vértices del mismo color).
Los modelos con hojas «de cartón con transparencia» (los 11 procedurales) se rehacen a mano en papel (conos, esferas facetadas,
tiras) porque la transparencia no sirve para recortes de papel."""
import colorsys, glob, json, math, os, re, struct, sys
import numpy as np
import trimesh
from scipy.spatial import cKDTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'game', 'models', 'paper')
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)

DROP = re.compile(r'(?i)pot|ground|soil|box|glass|wood|stand|dirt|mutt|stone|tray|kasten|erde|material\.016|material\.006')
# id: (categoría, alto en m, triángulos objetivo, peso para plantar)
SPEC = {
    'sc_acacia': ('arbol', 7.5, 320, 1.0), 'sc_coconut_tree': ('palmera', 10, 300, 0.8), 'sc_cypress': ('arbol', 9, 220, 1.2),
    'sc_palm_tree': ('palmera', 10, 300, 0.8), 'sc_pine': ('arbol', 10, 380, 1.6), 'tree_birch': ('arbol', 8, 260, 1.0),
    'tree_black_tupelo': ('arbol', 12, 380, 1.4), 'tree_christmas_tree': ('arbol', 6, 200, 0.5), 'tree_fan_palm_tree': ('arbusto', 4, 220, 1.2),
    'tree_lombardy_poplar': ('arbol', 12, 260, 0.9), 'tree_palm_tree': ('palmera', 9, 300, 0.9), 'tree_quaking_aspen': ('arbol', 9, 300, 1.0),
    'tree_sassafras': ('arbol', 11, 360, 1.3), 'tree_tree': ('arbol', 10, 340, 1.5), 'tree_weeping_willow': ('arbol', 8, 360, 0.8),
    'bush_decorative_plant': ('planta', 0.9, 90, 1.0), 'bush_decorative_plant_2': ('planta', 0.8, 90, 1.0), 'bush_flower_box': ('flor', 0.6, 90, 1.5),
    'bush_flowers': ('flor', 0.8, 110, 2.5), 'bush_indoor_plant': ('planta', 1.0, 100, 1.0), 'bush_little_plant': ('planta', 0.6, 80, 1.0),
    'bush_plant': ('planta', 1.1, 140, 1.5), 'bush_plant_2': ('planta', 0.7, 80, 1.2), 'bush_plant_3': ('planta', 1.2, 100, 1.2),
    'bush_plant_box': ('planta', 0.7, 90, 1.0), 'bush_spider_plant': ('planta', 0.8, 90, 1.2), 'sc_bamboo': ('bambu', 6.5, 260, 1.4),
    'sc_hydrangea': ('flor', 1.2, 150, 2.0), 'sc_lavender_bush': ('flor', 0.9, 150, 2.5),
    'rock_rock': ('roca', 0.9, 60, 1.0), 'rock_rock_2': ('roca', 0.8, 60, 1.0), 'rock_rock_3': ('roca', 1.0, 60, 1.0),
    'sc_parking_slot': ('calle', 0.02, 150, 0.0), 'sc_pedestrian_crossing': ('calle', 0.02, 96, 0.0), 'sc_sandpit': ('calle', 0.3, 160, 0.0),
    'sc_traffic_lane_separator': ('calle', 0.75, 120, 0.0), 'sidewalk_bump': ('calle', 0.11, 100, 0.0), 'sidewalk_concrete_sidewalk': ('calle', 0.16, 100, 0.0),
}

def face_colors(mesh):
    """Color original de cada cara (textura en el centro de la cara × color base, o el color liso del material)"""
    vis = mesh.visual
    n = len(mesh.faces)
    mat = getattr(vis, 'material', None)
    img = getattr(mat, 'baseColorTexture', None) if mat is not None else None
    fac = np.array(getattr(mat, 'baseColorFactor', None) if mat is not None and getattr(mat, 'baseColorFactor', None) is not None else [255, 255, 255, 255], dtype=float)
    if fac.max() <= 1.0:
        fac = fac * 255.0
    if img is not None and getattr(vis, 'uv', None) is not None:
        im = np.asarray(img.convert('RGB'), dtype=float)
        uv = np.asarray(vis.uv)[mesh.faces].mean(axis=1)
        h, w = im.shape[:2]
        px = np.clip(((uv[:, 0] % 1.0) * (w - 1)).astype(int), 0, w - 1)
        py = np.clip(((1.0 - (uv[:, 1] % 1.0)) * (h - 1)).astype(int), 0, h - 1)
        c = im[py, px] * (fac[:3] / 255.0)
        return np.clip(c, 0, 255)
    if vis.kind == 'vertex' or (mat is None and hasattr(vis, 'face_colors')):
        try:
            return np.asarray(vis.face_colors, dtype=float)[:, :3]
        except Exception:
            pass
    return np.tile(fac[:3], (n, 1))

def stylize(c, jitter=0.07):
    """Color de papel: un poco menos saturado y con variación de cara en cara"""
    out = []
    for r, g, b in c / 255.0:
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        s *= 0.92
        l = min(0.96, max(0.04, l * (1.0 + RNG.uniform(-jitter, jitter))))
        out.append([int(x * 255) for x in colorsys.hls_to_rgb(h, l, s)])
    return np.array(out, dtype=np.uint8)

def write_pap(name, tris, cols):
    """tris: (n,3,3) float · cols: (n,3) uint8"""
    n = len(tris)
    pos = np.asarray(tris, dtype='<f4').reshape(-1)
    rgba = np.zeros((n, 3, 4), dtype=np.uint8)
    rgba[:, :, :3] = cols[:, None, :]
    rgba[:, :, 3] = 255
    with open(os.path.join(OUT, name + '.pap'), 'wb') as f:
        f.write(b'PAP1' + struct.pack('<I', n * 3) + pos.tobytes() + rgba.tobytes())

def finish(name, parts, cat, h, w, source):
    """parts: lista de (trimesh, colores por cara). Normaliza (alto h, centrado, apoyado en y=0) y guarda"""
    tris = np.concatenate([m.triangles for m, _ in parts])
    cols = np.concatenate([c for _, c in parts])
    lo = tris.reshape(-1, 3).min(axis=0)
    hi = tris.reshape(-1, 3).max(axis=0)
    sc = h / max(1e-6, hi[1] - lo[1])
    ctr = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    tris = (tris - ctr) * sc
    write_pap(name, tris, cols)
    ext = (hi - lo) * sc
    return {'id': name, 'cat': cat, 'h': round(float(h), 2), 'w': round(float(max(ext[0], ext[2])), 2), 'tris': int(len(tris)), 'weight': w, 'source': source}

def cluster(mesh, cell):
    """Decimación por celdas: los vértices de una misma celda se funden en uno. Junta las hojas sueltas en volúmenes facetados."""
    v = mesh.vertices
    key = np.floor((v - v.min(axis=0)) / cell).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    nv = inv.max() + 1
    cen = np.zeros((nv, 3))
    cnt = np.bincount(inv, minlength=nv)
    for k in range(3):
        cen[:, k] = np.bincount(inv, weights=v[:, k], minlength=nv) / cnt
    f = inv[mesh.faces]
    ok = (f[:, 0] != f[:, 1]) & (f[:, 1] != f[:, 2]) & (f[:, 0] != f[:, 2])
    f = f[ok]
    srt = np.sort(f, axis=1)
    _, first = np.unique(srt, axis=0, return_index=True)
    return trimesh.Trimesh(cen, f[np.sort(first)], process=False)

def reduce_to(g, want):
    if len(g.faces) <= want:
        return g
    d = g
    try:
        d = g.simplify_quadric_decimation(face_count=want)
    except Exception:
        pass
    if len(d.faces) <= want * 1.3:
        return d
    ext = float(np.max(g.bounds[1] - g.bounds[0]))
    lo, hi = ext / 400.0, ext / 2.0
    best = d
    for _ in range(14):
        mid = (lo * hi) ** 0.5
        c = cluster(g, mid)
        if len(c.faces) > want * 1.15:
            lo = mid
        else:
            hi = mid
            best = c
    return best if len(best.faces) < len(d.faces) else d

def is_green(c):
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    mx = c.max(axis=1)
    mn = c.min(axis=1)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    return (g >= r * 0.92) & (g >= b * 1.02) & (sat > 0.12)

def blobs_from_leaves(pts, cols, k):
    """Copas de papel: agrupa las hojas en k volúmenes facetados (icosferas estiradas) con el color medio de cada grupo"""
    from scipy.cluster.vq import kmeans2
    k = max(2, min(k, len(pts) // 4))
    _, lab = kmeans2(pts, k, minit='++', seed=3)
    out = []
    for i in range(k):
        sel = lab == i
        if sel.sum() < 3:
            continue
        q = pts[sel]
        mu = q.mean(axis=0)
        cov = np.cov((q - mu).T) + np.eye(3) * 1e-4
        ev, evec = np.linalg.eigh(cov)
        rad = np.maximum(1.55 * np.sqrt(np.maximum(ev, 1e-5)), 0.22)
        ico = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
        v = (ico.vertices * rad) @ evec.T
        v = v * (1.0 + RNG.uniform(-0.1, 0.1, (len(v), 1))) + mu
        ico.vertices = v
        c = cols[sel].mean(axis=0)
        out.append((ico, stylize(np.tile(c, (len(ico.faces), 1)), 0.10)))
    return out

def flakes(mesh, fc, n):
    """Pocas hojas grandes: elige n caras y las agranda (el área total se conserva): papel recortado"""
    area = mesh.area_faces
    if len(mesh.faces) <= n:
        idx = np.arange(len(mesh.faces))
    else:
        pr = area / area.sum()
        idx = RNG.choice(len(mesh.faces), size=n, replace=False, p=pr)
    f = mesh.faces[idx]
    tri = mesh.vertices[f]
    ctr = tri.mean(axis=1, keepdims=True)
    k = float(np.clip(np.sqrt(area.sum() / max(area[idx].sum(), 1e-9)), 1.0, 7.0)) * 0.85
    tri = ctr + (tri - ctr) * k
    verts = tri.reshape(-1, 3)
    m = trimesh.Trimesh(verts, np.arange(len(verts)).reshape(-1, 3), process=False)
    return m, stylize(fc[idx], 0.08)

def solid_part(mesh, fc, mask, want):
    """Parte maciza (tronco, tallos, rocas): se reduce con decimación normal y los colores se toman de la cara original más cercana"""
    if mask.sum() < 4:
        return None
    sub = trimesh.Trimesh(mesh.vertices, mesh.faces[mask], process=False)
    sub.remove_unreferenced_vertices()
    d = reduce_to(sub, max(8, want))
    d = trimesh.Trimesh(d.vertices, d.faces, process=False)
    tree = cKDTree(mesh.triangles_center[mask])
    _, idx = tree.query(d.triangles_center)
    return d, stylize(fc[mask][idx], 0.06)

def solid(mesh, rgb):
    return np.tile(np.array(rgb) * 255.0, (len(mesh.faces), 1))

def fix_colors(name, meshes, cols):
    """Algunas piezas del pack (las «sc_») vienen sin colores ni materiales: se pintan por parte, como las vería un dibujante."""
    W, L, F = (0.40, 0.28, 0.18), (0.18, 0.46, 0.22), (0.9, 0.9, 0.9)
    if name == 'sc_acacia':
        allv = np.concatenate([m.vertices for m in meshes])
        H = allv[:, 1].max() - allv[:, 1].min()
        y0 = allv[:, 1].min()
        for i, m in enumerate(meshes):
            c = m.triangles_center
            low = ((c[:, 1] - y0) < 0.32 * H) & (np.hypot(c[:, 0], c[:, 2]) < 0.6)
            cols[i] = np.where(low[:, None], np.array(W) * 255.0, np.array((0.50, 0.58, 0.20)) * 255.0)
    elif name == 'sc_cypress':
        cols[0], cols[1] = solid(meshes[0], (0.10, 0.34, 0.20)), solid(meshes[1], W)
    elif name == 'sc_pine':
        cols[0], cols[1] = solid(meshes[0], W), solid(meshes[1], (0.12, 0.40, 0.22))
    elif name == 'sc_bamboo':
        cols[0], cols[1] = solid(meshes[0], (0.62, 0.68, 0.28)), solid(meshes[1], (0.38, 0.62, 0.22))
    elif name == 'sc_hydrangea':
        cols[0], cols[1], cols[2], cols[3] = solid(meshes[0], (0.45, 0.55, 0.92)), solid(meshes[1], (0.30, 0.45, 0.18)), solid(meshes[2], (0.30, 0.45, 0.18)), solid(meshes[3], (0.20, 0.50, 0.20))
    elif name == 'sc_lavender_bush':
        cols[0], cols[1], cols[2] = solid(meshes[0], (0.35, 0.52, 0.30)), solid(meshes[1], (0.62, 0.42, 0.88)), solid(meshes[2], (0.30, 0.48, 0.25))
    elif name == 'sc_pedestrian_crossing':
        cols[0] = solid(meshes[0], (0.30, 0.30, 0.33))
        for i in range(1, len(meshes)):
            cols[i] = solid(meshes[i], F)
    elif name == 'sc_parking_slot':
        for i in range(len(meshes)):
            cols[i] = solid(meshes[i], F)
    elif name == 'tree_christmas_tree':
        for i, m in enumerate(meshes):
            c = cols[i]
            mx, mn = c.max(axis=1), c.min(axis=1)
            grey = (mx - mn) < 25
            cols[i] = np.where(grey[:, None], np.array((0.10, 0.45, 0.22)) * 255.0, c)

def from_glb(path):
    name = os.path.splitext(os.path.basename(path))[0]
    cat, h, budget, w = SPEC[name]
    sc = trimesh.load(path, force='scene')
    meshes, cols = [], []
    for g in sc.dump():
        if not isinstance(g, trimesh.Trimesh) or len(g.faces) == 0:
            continue
        mname = str(getattr(getattr(g.visual, 'material', None), 'name', '') or '')
        if DROP.search(mname) and cat != 'calle':
            continue
        meshes.append(g)
        cols.append(face_colors(g))
    if not meshes:  # todo se parecía a «maceta»: se queda con lo que no es tierra ni vidrio
        for g in sc.dump():
            if isinstance(g, trimesh.Trimesh) and len(g.faces) > 0 and not re.search(r'(?i)ground|soil|glass|dirt|mutt|_3$', str(getattr(getattr(g.visual, 'material', None), 'name', '') or '')):
                meshes.append(g)
                cols.append(face_colors(g))
    if not meshes:
        raise RuntimeError(name + ': sin geometría')
    fix_colors(name, meshes, cols)
    mesh = trimesh.util.concatenate(meshes)
    fc = np.concatenate(cols)
    src = os.path.basename(os.path.dirname(path)) + '/' + os.path.basename(path)
    if name in PALMS:
        parts = palm(PALMS[name])
        return finish(name, parts, cat, h, w, src + ' (palmera en papel)')
    green = is_green(fc)
    out = []
    if cat == 'arbol' and green.sum() > 8:
        wood = solid_part(mesh, fc, ~green, int(budget * 0.35))
        if wood:
            out.append(wood)
        pts = mesh.triangles_center[green]
        out += blobs_from_leaves(pts, fc[green], int(budget * 0.65 / 80))
    elif cat == 'arbol':
        top = mesh.triangles_center[:, 1] > mesh.bounds[0][1] + 0.4 * (mesh.bounds[1][1] - mesh.bounds[0][1])
        wood = solid_part(mesh, fc, ~top, int(budget * 0.3))
        if wood:
            out.append(wood)
        out += blobs_from_leaves(mesh.triangles_center[top], fc[top], int(budget * 0.7 / 80))
    elif cat in ('planta', 'flor', 'arbusto', 'bambu'):
        lf = flakes(trimesh.Trimesh(mesh.vertices, mesh.faces, process=False), fc, int(budget * 1.5))
        out.append(lf)
    else:  # roca, calle
        d = reduce_to(mesh, budget)
        d = trimesh.Trimesh(d.vertices, d.faces, process=False)
        _, idx = cKDTree(mesh.triangles_center).query(d.triangles_center)
        out.append((d, stylize(fc[idx], 0.05 if cat == 'calle' else 0.08)))
    return finish(name, out, cat, h, w, src)

# ───────────── especies procedurales hechas en papel ─────────────
def col(rgb):
    return np.array(rgb, dtype=float)

def paint(mesh, c, jit=0.09):
    return (mesh, stylize(np.tile(col(c) * 255.0, (len(mesh.faces), 1)), jit))

def cone(r, h, y, sections=8, rot=0.0):
    m = trimesh.creation.cone(radius=r, height=h, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(rot, [0, 0, 1]))
    m.apply_translation([0, 0, y])
    return m

def to_y_up(m):
    m = m.copy()
    m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, [1, 0, 0]))
    return m

def blob(r, pos, scale=(1, 1, 1), sub=1, noise=0.12):
    m = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    v = m.vertices * np.array(scale)
    v = v * (1.0 + RNG.uniform(-noise, noise, (len(v), 1)))
    m.vertices = v + np.array(pos)
    return m

def trunk(r0, r1, h, sections=6, y=0.0, lean=(0, 0)):
    m = trimesh.creation.cylinder(radius=r0, height=h, sections=sections)
    v = m.vertices.copy()
    top = v[:, 2] > 0
    v[top, 0] *= r1 / r0
    v[top, 1] *= r1 / r0
    m.vertices = v
    m.apply_translation([0, 0, h / 2 + y])
    m = to_y_up(m)
    v = m.vertices.copy()
    v[:, 0] += lean[0] * v[:, 1] / max(h, 1e-6)
    v[:, 2] += lean[1] * v[:, 1] / max(h, 1e-6)
    m.vertices = v
    return m

def pine(snow=False):
    parts = [paint(trunk(0.28, 0.18, 2.4), (0.36, 0.25, 0.16))]
    greens = [(0.10, 0.34, 0.20), (0.12, 0.38, 0.22), (0.15, 0.42, 0.24), (0.18, 0.46, 0.27)]
    y = 1.6
    for i, (r, h) in enumerate([(2.4, 3.2), (1.9, 2.8), (1.4, 2.5), (0.9, 2.2)]):
        c = (0.92, 0.95, 0.98) if snow and i >= 2 else greens[i]
        parts.append(paint(to_y_up(cone(r, h, y, 8, 0)), c, 0.1))
        y += h * 0.55
    return parts

def broadleaf(kind='ancha'):
    greens = {'ancha': (0.17, 0.42, 0.16), 'abedul': (0.50, 0.62, 0.20), 'alamo': (0.32, 0.50, 0.16)}[kind]
    parts = []
    if kind == 'abedul':
        parts.append(paint(trunk(0.16, 0.10, 4.2, 6, lean=(0.3, 0.1)), (0.93, 0.93, 0.88), 0.03))
        for p, r in [((0, 4.6, 0), 1.7), ((1.0, 3.9, 0.4), 1.3), ((-0.9, 4.0, -0.5), 1.3), ((0.2, 5.6, 0.2), 1.0)]:
            parts.append(paint(blob(r, p, (1, 1.15, 1)), greens, 0.12))
    elif kind == 'alamo':
        parts.append(paint(trunk(0.22, 0.14, 2.6), (0.40, 0.32, 0.22)))
        parts.append(paint(blob(1.7, (0, 5.8, 0), (1, 3.0, 1), sub=1, noise=0.08), greens, 0.12))
    else:
        parts.append(paint(trunk(0.40, 0.25, 3.6, 7, lean=(0.2, 0.0)), (0.38, 0.28, 0.18)))
        for p, r in [((0, 5.2, 0), 2.4), ((1.9, 4.5, 0.6), 1.9), ((-1.8, 4.7, -0.7), 2.0), ((0.3, 6.5, 0.2), 1.6), ((0.2, 4.4, -1.8), 1.7)]:
            parts.append(paint(blob(r, p, (1, 0.9, 1)), greens, 0.12))
    return parts

def dead_tree():
    parts = [paint(trunk(0.25, 0.08, 4.0, 5, lean=(0.3, 0.1)), (0.34, 0.28, 0.24))]
    for y, ang, ln in [(2.2, 0.4, 1.4), (2.9, 2.5, 1.2), (3.5, 4.4, 1.0), (1.6, 5.4, 1.0)]:
        b = trimesh.creation.cylinder(radius=0.07, height=ln, sections=4)
        b.apply_translation([0, 0, ln / 2])
        b.apply_transform(trimesh.transformations.rotation_matrix(math.radians(55), [1, 0, 0]))
        b.apply_transform(trimesh.transformations.rotation_matrix(ang, [0, 0, 1]))
        b = to_y_up(b)
        b.apply_translation([0, y, 0])
        parts.append(paint(b, (0.32, 0.26, 0.22)))
    return parts

PALMS = {'sc_coconut_tree': (9, 1.4, 0.4), 'sc_palm_tree': (7, 0.6, 0.1), 'tree_palm_tree': (8, 1.0, 0.3), 'tree_fan_palm_tree': (6, 0.2, 0.0)}

def palm(var=(8, 0.9, 0.2)):
    nl, lean, lean2 = var
    parts = [paint(trunk(0.22, 0.14, 7.0, 6, lean=(lean, lean2)), (0.52, 0.40, 0.26))]
    for i in range(nl):
        a = i * math.tau / nl
        L = 3.4
        pts = []
        base = np.array([lean, 7.0, lean2])
        seg = 4
        for s in range(seg + 1):
            t = s / seg
            pts.append(base + np.array([math.cos(a) * L * t, math.sin(t * 2.6) * 0.8 - t * t * 2.4, math.sin(a) * L * t]))
        verts, faces = [], []
        for s in range(seg + 1):
            wd = 0.5 * (1 - s / (seg + 1)) + 0.05
            side = np.array([-math.sin(a), 0, math.cos(a)]) * wd
            verts += [pts[s] - side, pts[s] + side]
        for s in range(seg):
            k = s * 2
            faces += [[k, k + 1, k + 2], [k + 1, k + 3, k + 2]]
        parts.append(paint(trimesh.Trimesh(np.array(verts), np.array(faces)), (0.20, 0.50, 0.18) if i % 2 else (0.26, 0.56, 0.20), 0.1))
    return parts

def shrub():
    return [paint(blob(0.9, (0, 0.5, 0), (1, 0.7, 1)), (0.22, 0.46, 0.20), 0.1), paint(blob(0.7, (0.8, 0.4, 0.3), (1, 0.7, 1)), (0.26, 0.50, 0.22), 0.1),
            paint(blob(0.7, (-0.7, 0.4, -0.4), (1, 0.7, 1)), (0.20, 0.42, 0.18), 0.1)]

def grass():
    parts = []
    for i in range(7):
        a = i * 0.9
        h = 0.5 + 0.2 * (i % 3)
        v = np.array([[-0.05, 0, 0], [0.05, 0, 0], [0.0, h, 0.0]])
        m = trimesh.Trimesh(v, [[0, 1, 2]])
        m.apply_transform(trimesh.transformations.rotation_matrix(a, [0, 1, 0]))
        m.apply_translation([math.cos(a) * 0.08, 0, math.sin(a) * 0.08])
        parts.append(paint(m, (0.30, 0.58, 0.20) if i % 2 else (0.38, 0.64, 0.24), 0.12))
    return parts

def cactus():
    parts = [paint(to_y_up(trimesh.creation.cylinder(radius=0.28, height=2.6, sections=6)).copy(), (0.22, 0.46, 0.26))]
    parts[0][0].apply_translation([0, 1.3, 0])
    for sgn, y in [(1, 1.3), (-1, 1.7)]:
        arm = trimesh.creation.cylinder(radius=0.16, height=0.9, sections=5)
        arm = to_y_up(arm)
        arm.apply_translation([sgn * 0.55, y + 0.5, 0])
        elbow = trimesh.creation.cylinder(radius=0.16, height=0.5, sections=5)
        elbow.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 1, 0]))
        elbow = to_y_up(elbow)
        elbow.apply_translation([sgn * 0.3, y, 0])
        parts += [paint(arm, (0.24, 0.50, 0.28)), paint(elbow, (0.24, 0.50, 0.28))]
    return parts

def rock():
    return [paint(blob(1.0, (0, 0.55, 0), (1.2, 0.7, 1.0), sub=1, noise=0.22), (0.50, 0.50, 0.52), 0.1)]

def flower(color):
    parts = [paint(trunk(0.03, 0.02, 0.55, 4), (0.20, 0.50, 0.16), 0.05)]
    for i in range(6):
        a = i * math.tau / 6
        v = np.array([[0, 0, 0], [0.16, 0.04, 0.05], [0.16, 0.04, -0.05]])
        m = trimesh.Trimesh(v, [[0, 1, 2]])
        m.apply_transform(trimesh.transformations.rotation_matrix(a, [0, 1, 0]))
        m.apply_translation([0, 0.56, 0])
        parts.append(paint(m, color, 0.06))
    parts.append(paint(blob(0.05, (0, 0.58, 0), sub=0, noise=0.0), (0.95, 0.80, 0.15), 0.02))
    return parts

GEN = {
    'pino': ('arbol', 12, 1.8, lambda: pine(False)), 'pino_nevado': ('arbol', 12, 0.0, lambda: pine(True)),
    'abedul': ('arbol', 9, 1.0, lambda: broadleaf('abedul')), 'alamo': ('arbol', 13, 1.0, lambda: broadleaf('alamo')),
    'arbol_hoja_ancha': ('arbol', 11, 1.6, lambda: broadleaf('ancha')), 'arbol_seco': ('arbol', 5, 0.4, dead_tree), 'palmera': ('palmera', 10, 0.8, palm),
    'arbusto': ('arbusto', 1.3, 2.0, shrub), 'pasto': ('pasto', 0.6, 4.0, grass), 'cactus': ('arbusto', 2.4, 0.0, cactus), 'roca': ('roca', 1.2, 1.5, rock),
    'flor_roja': ('flor', 0.62, 2.0, lambda: flower((0.85, 0.12, 0.14))), 'flor_amarilla': ('flor', 0.62, 2.0, lambda: flower((0.98, 0.80, 0.12))),
    'flor_violeta': ('flor', 0.62, 2.0, lambda: flower((0.55, 0.30, 0.80))), 'flor_blanca': ('flor', 0.62, 2.0, lambda: flower((0.96, 0.95, 0.92))),
    'flor_naranja': ('flor', 0.62, 2.0, lambda: flower((0.98, 0.50, 0.12))),
}

def main(src):
    cat = []
    for f in sorted(glob.glob(os.path.join(src, '*', '*.glb'))):
        name = os.path.splitext(os.path.basename(f))[0]
        if name in SPEC:
            cat.append(from_glb(f))
            print(name, cat[-1]['tris'])
    for name, (c, h, w, fn) in GEN.items():
        parts = [(m, cols) for m, cols in fn()]
        cat.append(finish(name, parts, c, h, w, 'procedural (hecho en papel)'))
        print(name, cat[-1]['tris'])
    json.dump(cat, open(os.path.join(OUT, 'catalog.json'), 'w'), indent=0, ensure_ascii=False)
    print(len(cat), 'piezas')

if __name__ == '__main__':
    main(sys.argv[1])
