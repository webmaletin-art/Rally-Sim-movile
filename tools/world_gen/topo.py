"""Topología de la red: cruces (planarización), pueblos sobre las rutas, calles de los pueblos, perfil de alturas, servicios y carteles."""
import math
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
import terrain as T
import network as N
import names as NM


def seg_len(pts):
    return float(np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1)))


def cum_len(pts):
    d = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    return np.concatenate([[0.0], np.cumsum(d)])


def planarize(W_, label="cruce", near_node=140.0):
    """Parte las rutas donde se cruzan. Crea un nodo `cruce` en cada cruce. Los cruces a menos de 70 m se unen en un solo nodo."""
    edges, nodes = W_.edges, W_.nodes
    CELLH = 96.0
    hsh = {}
    for ei, e in enumerate(edges):
        p = e["pts"]
        for k in range(len(p) - 1):
            x0, z0, x1, z1 = p[k][0], p[k][1], p[k + 1][0], p[k + 1][1]
            for cx in range(int(min(x0, x1) // CELLH), int(max(x0, x1) // CELLH) + 1):
                for cz in range(int(min(z0, z1) // CELLH), int(max(z0, z1) // CELLH) + 1):
                    hsh.setdefault((cx, cz), []).append((ei, k))
    found = {}  # (ei, k, ej, l) -> (x, z, t, u)
    for lst in hsh.values():
        for ia in range(len(lst)):
            ei, k = lst[ia]
            for ib in range(ia + 1, len(lst)):
                ej, l = lst[ib]
                if ei == ej:
                    continue
                if ei > ej:
                    key = (ej, l, ei, k)
                    a_ = (ej, l)
                    b_ = (ei, k)
                else:
                    key = (ei, k, ej, l)
                    a_ = (ei, k)
                    b_ = (ej, l)
                if key in found:
                    continue
                pa, pb = edges[a_[0]]["pts"], edges[b_[0]]["pts"]
                r = N.seg_inter(pa[a_[1]], pa[a_[1] + 1], pb[b_[1]], pb[b_[1] + 1])
                if r is None:
                    continue
                t, u = r
                x = pa[a_[1]][0] + (pa[a_[1] + 1][0] - pa[a_[1]][0]) * t
                z = pa[a_[1]][1] + (pa[a_[1] + 1][1] - pa[a_[1]][1]) * t
                found[key] = (x, z, a_[1] + t, b_[1] + u)
    # nodos de cruce (se unen los cercanos)
    cross = []  # (x, z, ea, sa, eb, sb)
    for key, (x, z, sa, sb) in found.items():
        ea, _, eb, _ = key
        # no cruces cerca de un nodo compartido (dos rutas que salen del mismo lugar)
        shared = {edges[ea]["a"], edges[ea]["b"]} & {edges[eb]["a"], edges[eb]["b"]}
        if shared:
            if any(math.hypot(x - nodes[s]["x"], z - nodes[s]["z"]) < near_node for s in shared):
                continue
        cross.append([x, z, ea, sa, eb, sb])
    # agrupar cruces cercanos
    groups = []
    for c in sorted(cross, key=lambda c: (round(c[0] / 70.0), round(c[1] / 70.0))):
        for g in groups:
            if math.hypot(g["x"] - c[0], g["z"] - c[1]) < 14.0:
                g["items"].append(c)
                g["x"] = (g["x"] * (len(g["items"]) - 1) + c[0]) / len(g["items"])
                g["z"] = (g["z"] * (len(g["items"]) - 1) + c[1]) / len(g["items"])
                break
        else:
            groups.append({"x": c[0], "z": c[1], "items": [c]})
    splits = {}  # ei -> list de (pos, node id)
    nid_n = 0
    for g in groups:
        nid = "x%d" % len([k for k in nodes if k.startswith("x")])
        nodes[nid] = dict(id=nid, x=g["x"], z=g["z"], kind="cruce", name="")
        for (x, z, ea, sa, eb, sb) in g["items"]:
            splits.setdefault(ea, []).append((sa, nid))
            splits.setdefault(eb, []).append((sb, nid))
    out = []
    for ei, e in enumerate(edges):
        sp = splits.get(ei)
        if not sp:
            out.append(e)
            continue
        sp.sort(key=lambda s: s[0])
        # un mismo nodo no puede aparecer dos veces seguidas
        clean = []
        for s_, nid in sp:
            if clean and clean[-1][1] == nid:
                continue
            clean.append((s_, nid))
        pts = e["pts"]
        cut_idx = [0.0] + [s_ for s_, _ in clean] + [float(len(pts) - 1)]
        ids = [e["a"]] + [nid for _, nid in clean] + [e["b"]]
        for q in range(len(ids) - 1):
            s0, s1 = cut_idx[q], cut_idx[q + 1]
            if ids[q] == ids[q + 1]:
                continue
            seg = _slice(pts, s0, s1, nodes[ids[q]], nodes[ids[q + 1]])
            if len(seg) < 2:
                continue
            out.append(dict(a=ids[q], b=ids[q + 1], cls=e["cls"], name=e.get("name", ""), pts=seg))
    W_.edges[:] = out
    return len(groups)


def _slice(pts, s0, s1, na, nb):
    i0, i1 = int(math.floor(s0)), int(math.floor(s1))
    seg = [np.array([na["x"], na["z"]])]
    for i in range(i0 + 1, i1 + 1):
        if i < len(pts):
            seg.append(pts[i])
    seg.append(np.array([nb["x"], nb["z"]]))
    seg = np.array(seg)
    # sacar puntos pegados
    keep = [0]
    for i in range(1, len(seg)):
        if np.linalg.norm(seg[i] - seg[keep[-1]]) > 3.0 or i == len(seg) - 1:
            keep.append(i)
    return seg[keep]


def edge_len_m(e):
    return seg_len(e["pts"])


def split_edge_at(W_, ei, s_m, nid):
    """Parte la ruta ei en la distancia s_m (desde su inicio) con el nodo nid (que ya existe). Devuelve los índices de las dos mitades."""
    e = W_.edges[ei]
    pts = e["pts"]
    cl = cum_len(pts)
    k = int(np.searchsorted(cl, s_m))
    k = min(max(k, 1), len(pts) - 1)
    n = W_.nodes[nid]
    p = np.array([n["x"], n["z"]])
    a = np.vstack([pts[:k], p])
    b = np.vstack([p, pts[k:]])
    e2 = dict(a=nid, b=e["b"], cls=e["cls"], name=e.get("name", ""), pts=b)
    e["b"] = nid
    e["pts"] = a
    W_.edges.append(e2)
    return ei, len(W_.edges) - 1


def tangent_at(pts, s_m, span=60.0):
    cl = cum_len(pts)
    k = int(np.searchsorted(cl, s_m))
    k0 = max(0, k - 3)
    k1 = min(len(pts) - 1, k + 3)
    v = pts[k1] - pts[k0]
    n = np.linalg.norm(v)
    return v / n if n > 1e-6 else np.array([1.0, 0.0])


def place_villages(W_, rng, pool):
    """Una villa cada 5,5–9 km sobre las rutas largas (con el pueblo de 4 o 5 cuadras al borde de la ruta)."""
    grid = W_.grid
    nodes = W_.nodes
    n_new = 0
    ei = 0
    while ei < len(W_.edges):
        e = W_.edges[ei]
        if e["cls"] in ("anillo", "conector", "calle"):
            ei += 1
            continue
        L = seg_len(e["pts"])
        if L < 6500.0:
            ei += 1
            continue
        s = rng.uniform(3200.0, 5200.0)
        cuts = []
        cl = cum_len(e["pts"])
        while s < L - 2200.0:
            # buscar un lugar llano cerca de s
            best = None
            for ds in np.arange(-900.0, 901.0, 150.0):
                ss = s + ds
                if ss < 1800.0 or ss > L - 1800.0:
                    continue
                k = int(np.searchsorted(cl, ss))
                k = min(max(k, 4), len(e["pts"]) - 5)
                span = e["pts"][k - 4:k + 5]
                hh = grid.h(span[:, 0], span[:, 1], smooth=True)
                slope = float(np.max(np.abs(np.diff(hh))) / N.STEP)
                if slope < 0.05 and hh[4] > 4.0:
                    cur = (slope, abs(ds), ss)
                    if best is None or cur < best:
                        best = cur
            if best is not None:
                cuts.append(best[2])
            s += rng.uniform(5500.0, 9000.0)
        if not cuts:
            ei += 1
            continue
        # cortar desde el último hacia el primero (así los índices no cambian)
        cur_ei = ei
        for ss in sorted(cuts, reverse=True):
            if not pool:
                break
            k = int(np.searchsorted(cum_len(W_.edges[cur_ei]["pts"]), ss))
            pt = W_.edges[cur_ei]["pts"][min(max(k, 1), len(W_.edges[cur_ei]["pts"]) - 2)]
            nid = "villa_%d" % n_new
            nodes[nid] = dict(id=nid, x=float(pt[0]), z=float(pt[1]), kind="villa", name=pool.pop(), h=0.0)
            n_new += 1
            split_edge_at(W_, cur_ei, ss, nid)
        ei += 1
    return n_new


def street_set(kind):
    """Calles de cada tipo de lugar en coordenadas locales (u = a lo largo de la ruta principal, v = al costado): lista de ((u0, v0), (u1, v1))."""
    S = []
    if kind == "villa":
        for u in (-135.0, -45.0, 45.0, 135.0):
            S.append(((u, -80.0), (u, 80.0)))
    elif kind == "pueblo":
        for u in (-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0):
            S.append(((u, -150.0), (u, 150.0)))
        for v in (-100.0, 100.0):
            S.append(((-270.0, v), (270.0, v)))
    elif kind == "ciudad":
        for u in range(-330, 331, 110):
            S.append(((float(u), -260.0), (float(u), 260.0)))
        for v in (-220.0, -110.0, 110.0, 220.0):
            S.append(((-330.0, v), (330.0, v)))
    return S


def _covered(W_, tree, pts, tol=7.0, frac=0.6):
    """¿La mayor parte de una calle ya está cubierta por una ruta existente (a menos de tol metros)?"""
    d, _ = tree.query(pts)
    return float(np.mean(d < tol)) > frac


def add_streets(W_):
    """Calles de cada lugar, orientadas con su ruta principal. Quedan como rutas de clase `calle` (se cruzan con la ruta y entre sí en la planarización)."""
    from scipy.spatial import cKDTree
    nodes = W_.nodes
    n_new = 0
    info = []
    base_pts = np.concatenate([e["pts"] for e in W_.edges if e["cls"] != "calle"], axis=0)
    tree = cKDTree(base_pts)
    for nid, n in list(nodes.items()):
        if n["kind"] not in ("villa", "pueblo", "ciudad"):
            continue
        # eje: la dirección de la ruta más larga que toca el lugar
        best = None
        for e in W_.edges:
            if e["a"] == nid or e["b"] == nid or True:
                pass
        axis = None
        bl = -1.0
        for e in W_.edges:
            if e["cls"] in ("calle",):
                continue
            pts = e["pts"]
            d = np.linalg.norm(pts - np.array([n["x"], n["z"]]), axis=1)
            k = int(np.argmin(d))
            if d[k] < 40.0:
                L = seg_len(pts)
                if L > bl:
                    bl = L
                    k0, k1 = max(0, k - 5), min(len(pts) - 1, k + 5)
                    v = pts[k1] - pts[k0]
                    axis = v / max(np.linalg.norm(v), 1e-6)
        if axis is None:
            axis = np.array([1.0, 0.0])
        n["axis"] = [float(axis[0]), float(axis[1])]
        nrm = np.array([-axis[1], axis[0]])
        c = np.array([n["x"], n["z"]])
        streets = list(street_set(n["kind"]))
        h_ = HALF[n["kind"]]
        if n["kind"] != "villa":
            streets.append(((-h_, 0.0), (h_, 0.0)))  # la calle principal: une las rutas que terminan en el centro
        for (u0, v0), (u1, v1) in streets:
            # una calle que pasa por el centro del lugar se parte ahí (así queda unida a las rutas que llegan al nodo)
            pieces = []
            if (abs(u0) < 1e-6 and abs(u1) < 1e-6 and v0 * v1 < 0) or (abs(v0) < 1e-6 and abs(v1) < 1e-6 and u0 * u1 < 0):
                pieces = [((u0, v0), (0.0, 0.0)), ((0.0, 0.0), (u1, v1))]
            else:
                pieces = [((u0, v0), (u1, v1))]
            for (pu0, pv0), (pu1, pv1) in pieces:
                p0 = c + axis * pu0 + nrm * pv0
                p1 = c + axis * pu1 + nrm * pv1
                L = np.linalg.norm(p1 - p0)
                m = max(2, int(L / N.STEP))
                pts = p0 + (p1 - p0) * np.linspace(0, 1, m + 1)[:, None]
                if (abs(pv0) < 1e-6 and abs(pv1) < 1e-6) and _covered(W_, tree, pts):
                    continue  # la calle principal ya es la ruta que llega: no se repite
                ids = []
                for (pp, uu, vv) in ((p0, pu0, pv0), (p1, pu1, pv1)):
                    if abs(uu) < 1e-6 and abs(vv) < 1e-6:
                        ids.append(nid)
                    else:
                        q = "sf%d" % n_new
                        nodes[q] = dict(id=q, x=float(pp[0]), z=float(pp[1]), kind="calle_fin", name="")
                        n_new += 1
                        ids.append(q)
                W_.edges.append(dict(a=ids[0], b=ids[1], cls="calle", name="", pts=pts))
    return n_new


# ───────────────────────── alturas ─────────────────────────
SIG = {"autopista": 200.0, "anillo": 180.0, "ruta": 150.0, "provincial": 110.0, "camino": 70.0, "montana": 38.0, "tierra": 45.0, "calle": 14.0, "conector": 110.0}


def exact_terrain(W_):
    """Altura del terreno tal cual la calcula el juego: CityLayout.height(x, z) + el delta de la grilla (interpolación bilinear)."""
    X, Z = T.grid_xz()
    delta = (W_.Hm - T.city_height(X, Z)).astype(np.float32)
    W_.delta = delta

    def f(x, z):
        x = np.asarray(x, dtype=np.float64)
        z = np.asarray(z, dtype=np.float64)
        c = (x - T.X0) / T.CELL - 0.5
        r = (z - T.Z0) / T.CELL - 0.5
        d = map_coordinates(delta, [np.atleast_1d(r), np.atleast_1d(c)], order=1, mode="nearest")
        return T.city_height(np.atleast_1d(x), np.atleast_1d(z)) + d
    W_.exact = f
    return f


def compute_heights(W_):
    from scipy.ndimage import gaussian_filter1d
    nodes = W_.nodes
    f = W_.exact
    nh = {}
    for nid, n in nodes.items():
        if "y" in n:
            nh[nid] = float(n["y"])
            continue
        xs = n["x"] + np.array([0, 15, -15, 0, 0.0])
        zs = n["z"] + np.array([0, 0, 0, 15, -15.0])
        nh[nid] = float(np.mean(f(xs, zs)))
    W_.node_h = nh
    for e in W_.edges:
        pts = e["pts"]
        h = f(pts[:, 0], pts[:, 1]).astype(np.float64)
        sig = SIG.get(e["cls"], 100.0) / N.STEP
        h = gaussian_filter1d(h, sig, mode="nearest")
        cl = cum_len(pts)
        L = cl[-1]
        d0 = nh[e["a"]] - h[0]
        d1 = nh[e["b"]] - h[-1]
        t0 = np.clip(1.0 - cl / 160.0, 0.0, 1.0) ** 2
        t1 = np.clip(1.0 - (L - cl) / 160.0, 0.0, 1.0) ** 2
        h = h + d0 * t0 + d1 * t1
        g = N.CLS[e["cls"]][2]
        for _ in range(3):
            for i in range(1, len(h)):
                h[i] = min(max(h[i], h[i - 1] - g * N.STEP), h[i - 1] + g * N.STEP)
            for i in range(len(h) - 2, -1, -1):
                h[i] = min(max(h[i], h[i + 1] - g * N.STEP), h[i + 1] + g * N.STEP)
        h[0], h[-1] = nh[e["a"]], nh[e["b"]]
        e["h"] = h.astype(np.float32)


# ───────────────────────── carteles ─────────────────────────
def build_graph(W_):
    adj = {}
    for ei, e in enumerate(W_.edges):
        adj.setdefault(e["a"], []).append((ei, e["b"], False))
        adj.setdefault(e["b"], []).append((ei, e["a"], True))
    W_.adj = adj
    return adj


def _dir_at(W_, ei, node_id, leaving=True):
    e = W_.edges[ei]
    pts = e["pts"]
    at_start = e["a"] == node_id
    if at_start:
        k = min(len(pts) - 1, 5)
        v = pts[k] - pts[0]
    else:
        k = max(0, len(pts) - 1 - 5)
        v = pts[k] - pts[-1]
    n = np.linalg.norm(v)
    return v / n if n > 1e-6 else np.array([1.0, 0.0])


LABEL_KINDS = ("ciudad", "pueblo", "villa")


def label_of(n):
    if n["kind"] in LABEL_KINDS:
        return n["name"]
    if n["kind"] == "ciudad_salida":
        return "Dream City" if n["name"].startswith("Ruta") else n["name"]
    return ""


def dest_along(W_, ei, from_id, hops=12):
    """Primer destino con nombre si se sale de from_id por la ruta ei yendo derecho en los cruces: (nombre, metros)."""
    adj = W_.adj
    dist = 0.0
    cur_e = ei
    cur = from_id
    for _ in range(hops):
        e = W_.edges[cur_e]
        dist += seg_len(e["pts"])
        nxt = e["b"] if e["a"] == cur else e["a"]
        n = W_.nodes[nxt]
        lb = label_of(n)
        if lb:
            return lb, dist
        if n["kind"] == "calle_fin":
            return "", dist
        # seguir derecho
        d_in = -_dir_at(W_, cur_e, nxt)
        best = None
        for (ej, other, rev) in adj.get(nxt, []):
            if ej == cur_e or W_.edges[ej]["cls"] == "calle":
                continue
            d_out = _dir_at(W_, ej, nxt)
            turn = abs(math.degrees(math.atan2(d_in[0] * d_out[1] - d_in[1] * d_out[0], float(np.dot(d_in, d_out)))))
            if best is None or turn < best[0]:
                best = (turn, ej)
        if best is None:
            return "", dist
        cur_e, cur = best[1], nxt
    return "", dist


def make_signs(W_):
    """Para cada nodo con 3 o más rutas (cruces, pueblos, anillo): qué dice el cartel de cada salida. {nodo: [{e, to, km, route, ang}]}"""
    signs = {}
    adj = W_.adj
    for nid, lst in adj.items():
        outs = [(ei, o, rv) for (ei, o, rv) in lst if W_.edges[ei]["cls"] != "calle"]
        if len(outs) < 3 and W_.nodes[nid]["kind"] not in ("pueblo", "ciudad", "villa"):
            continue
        rows = []
        for (ei, o, rv) in outs:
            nm, dist = dest_along(W_, ei, nid)
            if not nm:
                continue
            d = _dir_at(W_, ei, nid)
            rows.append(dict(e=ei, to=nm, km=round(dist / 1000.0, 1), route=W_.edges[ei].get("name", ""), ang=round(math.degrees(math.atan2(d[1], d[0])), 1)))
        if rows:
            signs[nid] = rows
    W_.signs = signs
    return signs


# ───────────────────────── servicios ─────────────────────────
HALF = {"villa": 135.0, "pueblo": 270.0, "ciudad": 330.0}


def _on_road(W_, n, u, lat):
    ax = np.array(n["axis"])
    nrm = np.array([-ax[1], ax[0]])
    c = np.array([n["x"], n["z"]])
    p = c + ax * u + nrm * lat
    yaw = math.atan2(ax[0], ax[1])  # rumbo (sin, cos) del eje
    return p, yaw, ax, nrm


def make_pois(W_, rng):
    pois = []  # {kind, name, x, z, yaw, size, near, side}
    tolls = []
    places = [n for n in W_.nodes.values() if n["kind"] in ("ciudad", "pueblo", "villa")]
    for n in places:
        if "axis" not in n:
            continue
        kind = n["kind"]
        half = HALF[kind]
        side = 1.0 if rng.rand() < 0.5 else -1.0
        has_fuel = kind == "ciudad" or (kind == "pueblo") or rng.rand() < 0.4
        has_shop = kind == "ciudad" or (kind == "pueblo" and rng.rand() < 0.75) or rng.rand() < 0.2
        if has_fuel:
            for k in range(2 if kind == "ciudad" else 1):
                u = half + 70.0 + 160.0 * k if k == 0 else -(half + 70.0)
                p, yaw, ax, nrm = _on_road(W_, n, u, side * (30.0 if kind != "ciudad" else 34.0))
                size = {"ciudad": "big" if k == 0 else "mid", "pueblo": "mid", "villa": "small"}[kind]
                pois.append(dict(kind="fuel", name=("Estación %s" % n["name"]) if k == 0 else ("Surtidor %s Oeste" % n["name"]), x=float(p[0]), z=float(p[1]), yaw=float(yaw), size=size, near=n["id"], side=side))
        if has_shop:
            u = -(half + 60.0) if kind != "ciudad" else (half + 280.0)
            p, yaw, ax, nrm = _on_road(W_, n, u, -side * 24.0)
            pois.append(dict(kind="tires", name="Gomería %s" % n["name"], x=float(p[0]), z=float(p[1]), yaw=float(yaw), size="small", near=n["id"], side=-side))
    # áreas de servicio en las troncales largas
    for ei, e in enumerate(W_.edges):
        if e["cls"] not in ("autopista", "ruta") or e["name"] in ("AU-1",):
            continue
        L = seg_len(e["pts"])
        if L < 16000.0:
            continue
        s = L * (0.45 + 0.1 * rng.rand())
        cl = cum_len(e["pts"])
        k = int(np.searchsorted(cl, s))
        k = min(max(k, 6), len(e["pts"]) - 7)
        v = e["pts"][k + 5] - e["pts"][k - 5]
        v = v / max(np.linalg.norm(v), 1e-6)
        nrm = np.array([-v[1], v[0]])
        sd = 1.0 if rng.rand() < 0.5 else -1.0
        p = e["pts"][k] + nrm * sd * 32.0
        hh = W_.exact(np.array([p[0]]), np.array([p[1]]))[0]
        if hh < 5.0:
            continue
        pois.append(dict(kind="fuel", name="Área de servicio %s" % e["name"], x=float(p[0]), z=float(p[1]), yaw=float(math.atan2(v[0], v[1])), size="mid", near="", side=sd, edge=ei))
    # peajes: a 4,5 km del anillo en las troncales que salen de Dream City; peaje de montaña en los pasos largos
    for ei, e in enumerate(W_.edges):
        if e["cls"] in ("anillo", "conector", "calle"):
            continue
        ring_end = e["a"].startswith("ring") or e["b"].startswith("ring")
        L = seg_len(e["pts"])
        if ring_end and L > 9000.0 and e["cls"] in ("autopista", "ruta", "provincial"):
            s = 4500.0 if e["a"].startswith("ring") else L - 4500.0
            tolls.append(dict(edge=ei, s=s, name="Peaje %s" % e["name"], price_k=1.0))
        elif e["cls"] == "montana" and L > 24000.0 and len(tolls) < 14:
            tolls.append(dict(edge=ei, s=L * 0.5, name="Peaje de Montaña %s" % e["name"], price_k=2.2, secret=True))
    tl = []
    for t in tolls:
        e = W_.edges[t["edge"]]
        pts = e["pts"]
        cl = cum_len(pts)
        k = int(np.searchsorted(cl, t["s"]))
        k = min(max(k, 6), len(pts) - 7)
        v = pts[k + 4] - pts[k - 4]
        v = v / max(np.linalg.norm(v), 1e-6)
        tl.append(dict(name=t["name"], x=float(pts[k][0]), z=float(pts[k][1]), tx=float(v[0]), tz=float(v[1]), hw=float(N.CLS[e["cls"]][0] * 0.5), edge=t["edge"], s=float(cl[k]), price_k=t["price_k"], secret=bool(t.get("secret", False))))
    # secretos: cuatro villas al azar guardan algo (un auto o una historia): se marcan en los datos
    villas = [n for n in places if n["kind"] == "villa"]
    rng.shuffle(villas)
    secrets = []
    for i, n in enumerate(villas[:5]):
        secrets.append(dict(near=n["id"], name=n["name"], kind=["auto", "historia", "auto", "historia", "auto"][i]))
    W_.pois, W_.tolls, W_.secrets = pois, tl, secrets


def prune_islands(W_):
    """Saca los pedazos de red que no están unidos al resto (calles sueltas): todo tiene que ser alcanzable."""
    nodes = W_.nodes
    par = {k: k for k in nodes}
    def f(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a
    for e in W_.edges:
        par[f(e["a"])] = f(e["b"])
    comps = {}
    for k in nodes:
        comps.setdefault(f(k), []).append(k)
    main = max(comps.values(), key=len)
    keep = set(main)
    W_.edges[:] = [e for e in W_.edges if e["a"] in keep]
    for k in list(nodes):
        if k not in keep:
            del nodes[k]
    return len(comps) - 1


def make_edge_dest(W_):
    """Para cada ruta: el destino con nombre hacia donde va (de a hacia b) y hacia donde vuelve (de b hacia a), con los metros desde ese extremo."""
    W_.edge_dest = {}
    for ei, e in enumerate(W_.edges):
        if e["cls"] == "calle":
            continue
        nf, df = dest_along(W_, ei, e["a"])
        nb, db = dest_along(W_, ei, e["b"])
        W_.edge_dest[ei] = [nf, round(df, 1), nb, round(db, 1)]


RANK = {"autopista": 0, "anillo": 0, "ruta": 1, "conector": 1, "provincial": 2, "montana": 2, "camino": 3, "tierra": 4, "calle": 5}


def merge_parallel(W_, near=38.0):
    """Dos rutas que llegan juntas al mismo pueblo no corren una pegada a la otra: la más chica se une a la más grande (en forma de T) donde empiezan a ir juntas."""
    from scipy.spatial import cKDTree
    nodes = W_.nodes
    merged = 0
    for nid, n in list(nodes.items()):
        if n["kind"] not in ("ciudad", "pueblo", "villa"):
            continue
        inc = [i for i, e in enumerate(W_.edges) if (e["a"] == nid or e["b"] == nid) and e["cls"] not in ("calle", "anillo")]
        if len(inc) < 2:
            continue
        inc.sort(key=lambda i: RANK.get(W_.edges[i]["cls"], 9))
        for bi in range(1, len(inc)):
            b = W_.edges[inc[bi]]
            flip_b = b["b"] == nid
            bpts = b["pts"][::-1] if flip_b else b["pts"]
            for ai in range(bi):
                a = W_.edges[inc[ai]]
                if a is b:
                    continue
                flip_a = a["b"] == nid
                apts = a["pts"][::-1] if flip_a else a["pts"]
                if len(apts) < 20 or len(bpts) < 20:
                    continue
                tree = cKDTree(apts[:80])  # los primeros ~1 km de la ruta mayor
                lim = min(len(bpts), 80)
                d, idx = tree.query(bpts[:lim])
                close = d < near
                # el tramo inicial pegado a la mayor
                k = 0
                while k < lim and close[k]:
                    k += 1
                if k < 8 or k >= lim:
                    continue  # no van pegadas (o van pegadas todo el tramo medido: se deja)
                # sale por la mayor: el punto de unión es el más cercano de la mayor a bpts[k]
                ia = int(idx[k])
                jpos = apts[ia]
                jid = "j%d" % len([q for q in nodes if q.startswith("j") and q[1:].isdigit()])
                nodes[jid] = dict(id=jid, x=float(jpos[0]), z=float(jpos[1]), kind="cruce", name="")
                # partir la mayor en el punto de unión
                aidx = inc[ai]
                a_orig_idx = (len(a["pts"]) - 1 - ia) if flip_a else ia
                s_m = float(cum_len(a["pts"])[a_orig_idx])
                if 20.0 < s_m < seg_len(a["pts"]) - 20.0:
                    split_edge_at(W_, aidx, s_m, jid)
                # la menor ahora arranca en el nodo de unión
                newb = np.vstack([jpos[None, :], bpts[k:]])
                if flip_b:
                    b["pts"] = newb[::-1]
                    b["b"] = jid
                else:
                    b["pts"] = newb
                    b["a"] = jid
                merged += 1
                break
            else:
                continue
            # si se unió a una mayor, no se sigue probando con otras
    return merged


def add_with_overlap(W_, ia, ib, cls, name, pts, near=26.0, min_run=9):
    """Agrega una ruta nueva entre dos nodos pero sin repetir los tramos donde ya corre pegada a otra (a menos de `near` m): ahí se une a la existente con nodos de cruce."""
    from scipy.spatial import cKDTree
    nodes = W_.nodes
    pts = np.asarray(pts, dtype=np.float64)
    edges = [e for e in W_.edges if e["cls"] != "calle"]
    if not edges:
        W_.edges.append(dict(a=ia, b=ib, cls=cls, name=name, pts=pts))
        return 1
    allp = np.concatenate([e["pts"] for e in edges], axis=0)
    own = np.concatenate([np.full(len(e["pts"]), i) for i, e in enumerate(edges)])
    loc = np.concatenate([np.arange(len(e["pts"])) for e in edges])
    tree = cKDTree(allp)
    d, idx = tree.query(pts)
    flag = d < near
    # los extremos que salen de un nodo existente no cuentan como choque en los primeros 90 m
    n = len(pts)
    runs = []
    i = 0
    while i < n:
        if flag[i]:
            j = i
            while j + 1 < n and flag[j + 1]:
                j += 1
            if j - i + 1 >= min_run:
                runs.append((i, j))
            i = j + 1
        else:
            i += 1
    if not runs:
        W_.edges.append(dict(a=ia, b=ib, cls=cls, name=name, pts=pts))
        return 1
    # los puntos de unión: (índice en la ruta nueva, arista y punto de la red más cercano)
    def junction(pi):
        g = int(idx[pi])
        ei = edges[int(own[g])]
        return ei, int(loc[g])
    made = 0
    cur_node, cur_i = ia, 0
    jobs = []  # (arista, índice local, id de nodo)
    for (i0, i1) in runs:
        for pi in (i0, i1):
            jobs.append((pi, *junction(pi)))
    # crear los nodos de unión (de a uno por posición; las aristas se parten de la distancia mayor a la menor)
    node_for = {}
    by_edge = {}
    for (pi, e, li) in jobs:
        by_edge.setdefault(id(e), []).append((pi, e, li))
    for k, lst in by_edge.items():
        e = lst[0][1]
        cl = cum_len(e["pts"])
        L = float(cl[-1])
        for (pi, _, li) in sorted(lst, key=lambda t: -t[2]):
            s = float(cl[li])
            if s < 22.0:
                node_for[pi] = e["a"]
            elif s > L - 22.0:
                node_for[pi] = e["b"]
            else:
                pos = e["pts"][li]
                jid = "j%d" % len([q for q in nodes if q.startswith("j") and q[1:].isdigit()])
                nodes[jid] = dict(id=jid, x=float(pos[0]), z=float(pos[1]), kind="cruce", name="")
                ei_idx = W_.edges.index(e)
                split_edge_at(W_, ei_idx, s, jid)
                node_for[pi] = jid
                # la arista e quedó con [0, s]; los puntos con menor índice siguen valiendo
    for (i0, i1) in runs:
        j0, j1 = node_for[i0], node_for[i1]
        piece = pts[cur_i:i0 + 1].copy()
        if len(piece) >= 2:
            piece[-1] = [nodes[j0]["x"], nodes[j0]["z"]]
            piece[0] = [nodes[cur_node]["x"], nodes[cur_node]["z"]]
            if cur_node != j0 and (seg_len(piece) > 30.0):
                W_.edges.append(dict(a=cur_node, b=j0, cls=cls, name=name, pts=piece))
                made += 1
        cur_node, cur_i = j1, i1
    piece = pts[cur_i:].copy()
    if len(piece) >= 2 and cur_node != ib:
        piece[0] = [nodes[cur_node]["x"], nodes[cur_node]["z"]]
        piece[-1] = [nodes[ib]["x"], nodes[ib]["z"]]
        if seg_len(piece) > 30.0:
            W_.edges.append(dict(a=cur_node, b=ib, cls=cls, name=name, pts=piece))
            made += 1
    return made
