"""Arma la carrocería de un auto del juego a partir de un GLB de una sola malla (carrocería sin ruedas):
  1. escala a las medidas reales y centra (z = 0 en el centro de masa; y = 0 en el piso con las ruedas apoyadas),
  2. mide los pasos de rueda (ajuste de un círculo al borde) → distancia entre ejes, trocha, radio de rueda,
  3. simplifica (carrocería ~20 mil triángulos y versión «lo» ~4 mil), con normales que respetan los filos,
  4. separa los vidrios (zona de cabina sobre la cintura) y oscurece los bajos y el interior de los pasos (color de vértice),
  5. escribe <id>.glb, <id>_lo.glb y <id>.json (medidas para la física, las ruedas, la cabina y las cámaras).
Uso: python3 build_car.py <id> [<id> …]   (lee tools/cars/src/<fuente>.glb; configuración en CARS)"""
import sys, json, struct, os
import numpy as np, trimesh, fast_simplification
from scipy import ndimage
from skimage import measure
from analyze import load
from fit import arch_fit

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'godot', 'game', 'models', 'cars')

# L: largo real (m) · wscale: corrección de ancho · ground: altura de la base de la carrocería sobre el piso (m) · gap: luz entre la parte
# de arriba de la rueda y el paso · wf: reparto de peso adelante · glass: [base del parabrisas, borde superior del parabrisas, borde
# superior de la luneta, base de la luneta] como (z, y sobre la base de la carrocería) en el auto ya centrado; None = sin vidrios
CARS = {
    'pickup': dict(src='car0', L=6.033, Lref=5.45, wscale=0.9, R=0.44, gap=0.05, wf=0.54, wf_ref=0.52, glass=[(1.05, 0.93), (0.50, 1.47), (-1.00, 1.47), (-1.05, 0.93)]),
    'camo':   dict(src='car9', L=6.033, Lref=5.45, wscale=0.9, R=0.46, gap=0.05, wf=0.54, wf_ref=0.52, glass=[(1.05, 0.93), (0.50, 1.47), (-1.00, 1.47), (-1.05, 0.93)]),
    'truck':  dict(src='car1', L=7.057, Lref=6.60, wscale=0.86, R=0.55, gap=0.06, wf=0.50, wf_ref=0.46, glass=[(3.25, 1.32), (2.95, 2.40), (1.85, 2.40), (1.85, 1.32)]),
    'muscle': dict(src='car2', L=4.85, wscale=1.0, ground=0.10, gap=0.05, wf=0.54, glass=[(0.85, 0.82), (0.45, 1.23), (-0.75, 1.20), (-1.45, 0.90)]),
    'gt':     dict(src='car3', L=4.55, wscale=1.0, ground=0.09, gap=0.05, wf=0.50, glass=[(0.90, 0.82), (0.42, 1.17), (-0.55, 1.15), (-1.35, 0.84)]),
    'gt3':    dict(src='car4', L=4.70, wscale=0.92, ground=0.09, gap=0.04, wf=0.46, glass=[(1.15, 0.80), (0.55, 1.23), (-0.60, 1.26), (-1.45, 0.95)]),
    'hyper':  dict(src='car5', L=4.75, wscale=0.88, ground=0.09, gap=0.04, wf=0.44, glass=[(1.30, 0.81), (0.60, 1.17), (-0.35, 1.15), (-0.90, 0.95)]),
    'buggy':  dict(src='car6', L=3.95, wscale=1.0, ground=0.14, gap=0.05, wf=0.48, glass=None),
    'suv':    dict(src='car7', L=4.25, wscale=0.92, ground=0.18, gap=0.05, wf=0.52, glass=[(0.95, 0.92), (0.40, 1.42), (-1.75, 1.42), (-1.80, 0.92)]),
    'hatch':  dict(src='car8', L=4.30, wscale=0.95, ground=0.10, gap=0.04, wf=0.57, glass=[(1.15, 0.93), (0.40, 1.50), (-1.00, 1.50), (-1.55, 1.00)]),
}


# Ruedas: style = diseño de la llanta · rim = radio de la llanta (m) · tw/tw_r = ancho de goma adelante/atrás · tread = dibujo de la goma
WHEELS = {
    'pickup': dict(spring_col='#e11d2a', caliper_col='#1b1d22', style='dish8', rim=0.229, tw=0.325, tw_r=0.325, tread='offroad', spring='coil', susp='truck'),
    'camo':   dict(spring_col='#d9a21c', caliper_col='#d9a21c', style='beadlock', rim=0.235, tw=0.345, tw_r=0.345, tread='offroad', spring='coil', susp='truck'),
    'truck':  dict(spring_col='#ff6a08', caliper_col='#ffc300', style='steel10', rim=0.254, tw=0.32, tw_r=0.46, tread='offroad', spring='coil', susp='truck'),
    'muscle': dict(spring_col='#e11d2a', caliper_col='#e6c619', style='star5', rim=0.245, tw=0.27, tw_r=0.33, tread='road', spring='coil', susp='car'),
    'gt':     dict(spring_col='#1a4fe0', caliper_col='#1a4fe0', style='multi10', rim=0.235, tw=0.26, tw_r=0.28, tread='road', spring='coil', susp='car'),
    'gt3':    dict(spring_col='#e11d2a', caliper_col='#e6c619', style='centerlock', rim=0.25, tw=0.30, tw_r=0.34, tread='slick', spring='coil', susp='car'),
    'hyper':  dict(spring_col='#c0c5cc', caliper_col='#00b4d8', style='turbine', rim=0.26, tw=0.285, tw_r=0.33, tread='road', spring='coil', susp='car'),
    'buggy':  dict(spring_col='#ffc300', caliper_col='#ff6a08', style='beadlock', rim=0.20, tw=0.31, tw_r=0.34, tread='offroad', spring='coil', susp='buggy'),
    'suv':    dict(spring_col='#ff6a08', caliper_col='#d9141c', style='dish6', rim=0.23, tw=0.275, tw_r=0.275, tread='offroad', spring='coil', susp='truck'),
    'hatch':  dict(spring_col='#e11d2a', caliper_col='#e11d2a', style='multi5', rim=0.205, tw=0.225, tw_r=0.225, tread='road', spring='coil', susp='car'),
}

def vertex_normals(V, F, crease_deg=42.0):
    """Normales por esquina de triángulo, promediando solo los vecinos dentro del ángulo de filo. Devuelve (V2, F2, N2)."""
    tri = V[F]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    area = np.linalg.norm(fn, axis=1)
    fn = fn / np.maximum(area[:, None], 1e-12)
    cosc = np.cos(np.radians(crease_deg))
    nv = len(V)
    # CSR de caras por vértice
    corner_v = F.reshape(-1)
    order = np.argsort(corner_v, kind='stable')
    cf = (np.arange(len(F) * 3) // 3)[order]
    starts = np.searchsorted(corner_v[order], np.arange(nv + 1))
    N_corner = np.zeros((len(F) * 3, 3))
    for v in range(nv):
        fs = cf[starts[v]:starts[v + 1]]
        if len(fs) == 0:
            continue
        nn = fn[fs]
        w = area[fs]
        d = nn @ nn.T  # coseno entre las caras vecinas
        m = (d > cosc).astype(float) * w[None, :]
        avg = m @ nn
        avg /= np.maximum(np.linalg.norm(avg, axis=1, keepdims=True), 1e-12)
        # a cada esquina (cara fs[k], vértice v) le toca avg[k]
        for k, f in enumerate(fs):
            c = np.where(F[f] == v)[0][0]
            N_corner[f * 3 + c] = avg[k]
    # soldar esquinas iguales (misma posición y normal)
    P = V[F.reshape(-1)]
    key = np.c_[np.round(P * 1e5).astype(np.int64), np.round(N_corner * 200).astype(np.int64)]
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    V2 = P[first]
    N2 = N_corner[first]
    F2 = inv.reshape(-1, 3)
    return V2, F2, N2

def write_glb(path, prims):
    """prims: lista de (nombre_material, V, N, C, F)  → GLB mínimo con un mesh de varias primitivas."""
    bin_data = bytearray()
    views, accs, primitives, mats = [], [], [], []
    def add(arr, comp, typ, target, mn=None, mx=None):
        off = len(bin_data)
        raw = arr.tobytes()
        bin_data.extend(raw)
        while len(bin_data) % 4:
            bin_data.append(0)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(raw), 'target': target})
        a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': typ}
        if mn is not None:
            a['min'], a['max'] = mn, mx
        accs.append(a)
        return len(accs) - 1
    for name, V, N, C, F in prims:
        V = V.astype(np.float32); N = N.astype(np.float32); C = C.astype(np.float32); F = F.astype(np.uint32)
        ip = add(V, 5126, 'VEC3', 34962, V.min(0).tolist(), V.max(0).tolist())
        inn = add(N, 5126, 'VEC3', 34962)
        ic = add(C, 5126, 'VEC3', 34962)
        ii = add(F.reshape(-1), 5125, 'SCALAR', 34963)
        mats.append({'name': name, 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.3, 'roughnessFactor': 0.5}, 'doubleSided': True})
        primitives.append({'attributes': {'POSITION': ip, 'NORMAL': inn, 'COLOR_0': ic}, 'indices': ii, 'material': len(mats) - 1})
    gj = {'asset': {'version': '2.0', 'generator': 'dream-racing build_car'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'body'}],
          'meshes': [{'name': 'body', 'primitives': primitives}], 'materials': mats, 'buffers': [{'byteLength': len(bin_data)}], 'bufferViews': views, 'accessors': accs}
    js = json.dumps(gj, separators=(',', ':')).encode()
    while len(js) % 4:
        js += b' '
    total = 12 + 8 + len(js) + 8 + len(bin_data)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(bin_data), 0x004E4942)); f.write(bytes(bin_data))

def point_in_poly(pts, poly):
    """pts (n,2) en (z, y); poly lista de (z, y). Regla de par-impar."""
    x, y = pts[:, 0], pts[:, 1]
    inside = np.zeros(len(pts), bool)
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]; xj, yj = poly[j]
        cond = ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi)
        inside ^= cond
        j = i
    return inside

def slice_by_polygon(m, poly):
    """Corta la malla con los planos de los lados del polígono (z, y) para que el borde de los vidrios quede recto."""
    for i in range(len(poly)):
        (z0, y0), (z1, y1) = poly[i], poly[(i + 1) % len(poly)]
        d = np.array([0.0, y1 - y0, z1 - z0])
        d /= np.linalg.norm(d)
        n = np.array([0.0, d[2], -d[1]])          # normal en el plano (y, z), perpendicular al lado
        o = np.array([0.0, y0, z0])
        pos = trimesh.intersections.slice_mesh_plane(m, n, o, cap=False)
        neg = trimesh.intersections.slice_mesh_plane(m, -n, o, cap=False)
        parts = [p for p in (pos, neg) if p is not None and len(p.faces)]
        m = trimesh.util.concatenate(parts)
        m.merge_vertices(merge_tex=True, merge_norm=True)
    return m

def top_profile(mesh, z0, z1, dz=0.02):
    """Altura de la carrocería sobre el eje central (rayos desde arriba) entre z0 y z1 (z0 > z1: de adelante hacia atrás)."""
    n = int(abs(z0 - z1) / dz) + 1
    zs = np.linspace(z0, z1, n)
    org = np.array([[x, 8.0, z] for z in zs for x in (0.0, 0.05)])
    dr = np.tile([0.0, -1.0, 0.0], (len(org), 1))
    loc, ri, _ = mesh.ray.intersects_location(org, dr, multiple_hits=True)
    y = np.full(len(org), np.nan)
    for p, i in zip(loc, ri):
        if np.isnan(y[i]) or p[1] > y[i]:
            y[i] = p[1]
    y = np.fmax(y[0::2], y[1::2])
    ok = ~np.isnan(y)
    return zs[ok], y[ok]

def glass_segments(V, F, poly, cfg):
    """Parabrisas y luneta sobre el eje central, medidos sobre la malla: tramo inclinado del perfil entre el capó y el techo."""
    mesh = trimesh.Trimesh(V, F, process=False)
    P0, P1, P2, P3 = poly
    zs, ys = top_profile(mesh, P0[0] + 0.5, P3[0] - 0.5)
    # techo: el nivel más alto que se mantiene en la cabina
    cab = (zs < P1[0] + 0.1) & (zs > P2[0] - 0.1)
    y_roof = float(np.percentile(ys[cab], 60)) if cab.any() else max(P1[1], P2[1])
    def runs(sl, thr, lo_z, hi_z, y_min=-9.0):
        """tramos continuos donde la pendiente supera thr dentro de [lo_z, hi_z]; devuelve el de mayor altura recorrida (i0, i1)"""
        best = None
        i = 0
        n = len(zs)
        while i < n:
            if lo_z <= zs[i] <= hi_z and sl[i] > thr and ys[i] >= y_min:
                j = i
                while j + 1 < n and sl[j + 1] > thr and zs[j + 1] >= lo_z and ys[j + 1] >= y_min:
                    j += 1
                rise = abs(ys[j] - ys[i])
                if best is None or rise > best[2]:
                    best = (i, j, rise)
                i = j + 1
            else:
                i += 1
        return best
    # pendiente hacia atrás (y sube al ir hacia atrás) y hacia adelante
    dy = np.gradient(ys, zs)    # zs decrece: dy/dz < 0 donde sube hacia atrás
    sl_front = -dy
    sl_rear = dy
    out = {'roof_y': y_roof}
    bw = runs(sl_front, 0.28, P1[0] - 0.35, P0[0] + 0.45, P0[1] - 0.12)
    if bw is not None:
        i0, j0, _ = bw
        sel = slice(i0, j0 + 1)
        A = np.polyfit(zs[sel], ys[sel], 1)
        zb = zs[i0]
        zt = (y_roof - 0.03 - A[1]) / A[0]
        out['ws'] = [[float(zb), float(np.polyval(A, zb))], [float(zt), float(y_roof - 0.03)]]
    else:
        out['ws'] = [list(map(float, P0)), list(map(float, P1))]
    rw = runs(sl_rear, 0.1, P3[0] - 0.4, P2[0] + 0.35, P3[1] - 0.12)
    if rw is not None:
        i0, j0, _ = rw
        sel = slice(i0, j0 + 1)
        A = np.polyfit(zs[sel], ys[sel], 1)
        zt = (y_roof - 0.03 - A[1]) / A[0]
        zb = zs[j0]
        out['rg'] = [[float(zt), float(y_roof - 0.03)], [float(zb), float(np.polyval(A, zb))]]
    else:
        out['rg'] = [list(map(float, P2)), list(map(float, P3))]
    # luneta vertical (hatch, SUV, camión): el perfil cae de golpe; se detecta como un salto de altura
    jumps = np.where((ys[:-1] - ys[1:]) > 0.12)[0]
    for jx in jumps:
        z = float(zs[jx])
        if P3[0] - 0.4 < z < P2[0] + 0.35 and ys[jx] > y_roof - 0.2:
            out['rg'] = [[z, float(y_roof - 0.03)], [z - 0.01, float(max(ys[jx + 1], P3[1]))]]
            break
    for k in ('ws', 'rg'):
        if k in cfg.get('glass_override', {}):
            out[k] = cfg['glass_override'][k]
    out['profile'] = [[float(a), float(b)] for a, b in zip(zs[::5], ys[::5])]
    return out

def classify(V, F, N, meta, cfg):
    """Colores de vértice (oscuros: bajos, interior de pasos de rueda) y triángulos de vidrio (dentro del polígono del vidrio)."""
    H = meta['H']; hw = meta['hw']
    G = 0.04
    key = lambda u, v: (np.round(u / G).astype(int) * 100003 + np.round(v / G).astype(int))
    envx = {}; envy = {}
    kx = key(V[:, 1], V[:, 2]); ky = key(V[:, 0], V[:, 2])
    for k, ax in zip(kx, np.abs(V[:, 0])):
        if ax > envx.get(k, -1): envx[k] = ax
    for k, y in zip(ky, V[:, 1]):
        if y > envy.get(k, -1): envy[k] = y
    tol = 0.05
    outx = np.abs(V[:, 0]) >= np.array([envx[k] for k in kx]) - tol
    outy = V[:, 1] >= np.array([envy[k] for k in ky]) - tol
    ny = N[:, 1]
    base = meta['lift']
    sst = lambda a, b, x: np.clip((x - a) / (b - a), 0, 1) ** 2 * (3 - 2 * np.clip((x - a) / (b - a), 0, 1))
    k = 1 - sst(base, base + 0.07 * H, V[:, 1])
    k = np.where((ny < -0.4) & (V[:, 1] < base + 0.30 * H), 1.0, k)   # bajos del auto (no los reversos de los calados del capó)
    for a in meta['arches']:
        d = np.hypot(V[:, 2] - a['z'], V[:, 1] - a['yc'])
        # solo el interior del paso (techo y paredes de adentro): la piel exterior (capó, guardabarros) mira hacia arriba o hacia afuera
        k = np.where((d < a['r'] * 1.03) & (np.abs(V[:, 0]) < 0.90 * a['x_out']) & (ny < 0.30), 1.0, k)
    col = np.repeat((1 - k * 0.94)[:, None], 3, axis=1)
    gface = np.zeros(len(F), bool)
    return col, gface

def remesh_skin(V, F, voxel=0.008, sigma=1.0, relax=8):
    """Piel nueva y limpia: voxeliza la malla, descarta todo lo que no se ve desde afuera (interiores, piezas dobladas, calados con
    doble pared) y saca una superficie lisa con marching cubes. Los modelos originales son de IA y traen capas internas y triángulos
    retorcidos que, al reducirlos, se ven como rajaduras negras y paragolpes arrugados."""
    lo = V.min(0) - 6 * voxel
    hi = V.max(0) + 6 * voxel
    shape = np.ceil((hi - lo) / voxel).astype(int) + 1
    tri = V[F]
    area = 0.5 * np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)
    n = np.maximum(1, np.ceil(area / (0.35 * voxel) ** 2 * 0.5).astype(int))      # muestras por triángulo (separación < media celda)
    idx = np.repeat(np.arange(len(F)), n)
    r1 = np.random.default_rng(1).random((len(idx), 2))
    flip = r1.sum(1) > 1
    r1[flip] = 1 - r1[flip]
    P = tri[idx, 0] + r1[:, :1] * (tri[idx, 1] - tri[idx, 0]) + r1[:, 1:] * (tri[idx, 2] - tri[idx, 0])
    P = np.vstack([P, V])
    ijk = np.floor((P - lo) / voxel).astype(int)
    surf = np.zeros(shape, bool)
    surf[ijk[:, 0], ijk[:, 1], ijk[:, 2]] = True
    wall = ndimage.binary_dilation(surf, iterations=1)                 # cierra las rendijas entre piezas
    lab, nl = ndimage.label(~wall)
    outside = lab == lab[0, 0, 0]                                      # el aire de afuera (toca el borde de la caja)
    solid = ~outside
    solid = ndimage.binary_erosion(solid, iterations=1)                # devuelve lo que sumó la dilatación
    # el piso del auto queda abierto hacia abajo: se cierra con una tapa en y mínimo para que no se llene al revés
    fld = ndimage.gaussian_filter(solid.astype(np.float32), sigma)
    vv, ff, _, _ = measure.marching_cubes(fld, 0.5, spacing=(voxel, voxel, voxel))
    vv = vv + lo
    m = trimesh.Trimesh(vv, ff, process=True)
    m.update_faces(m.nondegenerate_faces())
    # normales hacia afuera
    trimesh.repair.fix_normals(m)
    if relax:
        trimesh.smoothing.filter_taubin(m, lamb=0.5, nu=-0.53, iterations=relax)   # alisa los escalones de los voxeles sin encoger
    return np.asarray(m.vertices), np.asarray(m.faces)

def simplify(V, F, faces, agg):
    """Reducción por colapso de aristas (error cuadrático) sobre la malla ya soldada."""
    red = 1.0 - faces / len(F)
    return fast_simplification.simplify(V.astype(np.float64), F.astype(np.int32), target_reduction=red, agg=agg)

def build(cid):
    cfg = CARS[cid]
    m = load(os.path.join(HERE, 'src', cfg['src'] + '.glb'))
    V = m.vertices.copy()
    F = m.faces.copy()
    s = cfg['L'] / (V[:, 2].max() - V[:, 2].min())
    V *= s
    V[:, 0] *= cfg['wscale']
    V[:, 1] -= V[:, 1].min()
    hx = np.abs(V[:, 0]).max()
    arch = arch_fit(V, hx)
    assert len(arch) == 2, (cid, arch)
    rear, front = sorted(arch, key=lambda a: a['z'])
    top = (rear['top'] + front['top']) / 2
    if 'R' in cfg:                                 # radio de rueda fijo (el de la física): la carrocería se levanta lo que haga falta
        R = float(cfg['R'])
        ground = float(2 * R + cfg['gap'] - top)
    else:
        ground = cfg['ground']
        R = float((top + ground - cfg['gap']) / 2)   # la rueda llena el paso hasta una luz «gap»
    wheelbase = front['z'] - rear['z']
    a_f = wheelbase * (1 - cfg['wf'])             # centro de masa → eje delantero
    b_r = wheelbase * cfg['wf']
    dz = a_f - front['z']
    V[:, 1] += ground
    V[:, 2] += dz
    arches = []
    for a in (rear, front):
        arches.append(dict(z=float(a['z'] + dz), y=float(R), yc=float(a['y'] + ground), r=float(a['r']), x_out=0.0))
    H = float(V[:, 1].max())
    hw = float(np.abs(V[:, 0]).max())
    for a in arches:     # x del borde externo a la altura de la rueda (para la trocha)
        sel = (np.abs(V[:, 2] - a['z']) < a['r'] * 0.9) & (V[:, 1] > R * 0.4) & (V[:, 1] < 2 * R)
        a['x_out'] = float(np.abs(V[sel, 0]).max()) if sel.any() else hw
    kk = cfg['L'] / cfg.get('Lref', cfg['L'])      # los polígonos del vidrio se midieron con el largo de referencia
    dzw = wheelbase * (cfg.get('wf_ref', cfg['wf']) - cfg['wf'])   # el centro de masa se corrió respecto del de referencia
    glass = None if cfg['glass'] is None else [(float(z * kk + dzw), float(y * kk + ground)) for z, y in cfg['glass']]
    if glass is not None:
        hw_cab = None
        seg = glass_segments(V, F, glass, cfg)
        # ancho de la cabina: lo más ancho de lo que está sobre el borde del techo
        ytop = max(p[1] for p in glass[1:3])
        zlo, zhi = min(p[0] for p in glass[1:3]), max(p[0] for p in glass[1:3])
        selr = (V[:, 1] > ytop - 0.07) & (V[:, 2] > zlo) & (V[:, 2] < zhi)
        hw_cab = float(np.abs(V[selr, 0]).max()) if selr.any() else 0.8 * hw
        glass_meta = dict(poly=glass, cab_hw=hw_cab, **seg)
    else:
        glass_meta = None
    meta = dict(id=cid, L=cfg['L'], H=H, hw=hw, scale=float(s), wheelbase=float(wheelbase), a=float(a_f), b=float(b_r), R=R, lift=float(ground),
                weightFront=cfg['wf'], arch_top=float(top + ground), arches=arches, glass=glass_meta, wheel=WHEELS[cid])
    if cfg.get('remesh', True):
        V, F = remesh_skin(V, F, cfg.get('voxel', 0.012))
    # variantes hi / lo
    outs = {}
    for tag, faces in (('', cfg.get('tris', 24000)), ('_lo', 5000)):
        pv, pf = simplify(V, F, faces, cfg.get('agg', 3) if tag == '' else 6)
        if cfg.get('smooth', 0) and tag == '':   # quita las arrugas que deja la reducción en los paragolpes y guardabarros (Taubin: no encoge)
            tm = trimesh.Trimesh(pv, pf, process=False)
            trimesh.smoothing.filter_taubin(tm, lamb=0.5, nu=-0.53, iterations=int(cfg.get('smooth', 12)))
            pv = np.asarray(tm.vertices)
        V2, F2, N2 = vertex_normals(pv, pf, cfg.get('crease', 50.0))
        col, gface = classify(V2, F2, N2, meta, cfg)
        prims = []
        def sub(Ff):
            used = np.unique(Ff)
            remap = -np.ones(len(V2), int); remap[used] = np.arange(len(used))
            return V2[used], N2[used], col[used], remap[Ff]
        bv, bn, bc, bf = sub(F2[~gface])
        prims.append(('body', bv, bn, bc, bf))
        if gface.any():
            gv, gn, gc, gf = sub(F2[gface])
            gc = np.full_like(gc, 0.06)
            prims.append(('glass', gv, gn, gc, gf))
        os.makedirs(OUT, exist_ok=True)
        write_glb(os.path.join(OUT, '%s%s.glb' % (cid, tag)), prims)
        outs[tag] = (len(F2), int(gface.sum()))
    meta['tris'] = outs['']
    json.dump(meta, open(os.path.join(OUT, cid + '.json'), 'w'), indent=1)
    print(cid, 'escala %.3f' % s, 'entre ejes %.3f' % wheelbase, 'R %.3f' % R, 'piso %.3f' % ground, 'H %.2f hw %.2f' % (H, hw), 'x_out', [round(a['x_out'], 2) for a in arches], 'tris', outs)

if __name__ == '__main__':
    for c in (sys.argv[1:] or list(CARS)):
        build(c)
