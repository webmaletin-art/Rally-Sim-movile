"""Genera la región del mundo abierto de Dream City: terreno + red de rutas + pueblos. Uso: python3 build_region.py [--viz]
Salida: godot/game/data/region/region_1.bin (+ región JSON de depuración en /tmp)."""
import json
import math
import os
import sys
import time
import numpy as np
from scipy.ndimage import gaussian_filter, map_coordinates
from scipy.spatial import Delaunay
import terrain as T
import network as N
import names as NM
import rand_util as R

HERE = os.path.dirname(os.path.abspath(__file__))
CITY = json.load(open(os.path.join(HERE, "city_data.json")))
SEED = 20261004


def log(*a):
    print("[%6.1fs]" % (time.time() - T0), *a, flush=True)


T0 = time.time()


class World:
    pass


def flat_site(grid, x, z, radius=4000.0, rejects=(), min_dist=0.0, allow_steep=0.03):
    """Lugar llano cerca de (x, z): el de menor pendiente (a 400 m) dentro del radio, sobre tierra firme y lejos de los `rejects` (x, z, distancia)."""
    best = None
    bs = 1e9
    for dx in np.arange(-radius, radius + 1, 400.0):
        for dz in np.arange(-radius, radius + 1, 400.0):
            px, pz = x + dx, z + dz
            if not (T.X0 + 3000 < px < T.X1 - 3000 and T.Z0 + 3000 < pz < 400.0):
                continue
            hh = grid.h(np.array([px, px + 400, px - 400, px, px]), np.array([pz, pz, pz, pz + 400, pz - 400]), smooth=True)
            if hh[0] < 5.0:
                continue
            if any(math.hypot(px - rx, pz - rz) < rd for rx, rz, rd in rejects):
                continue
            slope = max(abs(hh[1] - hh[2]), abs(hh[3] - hh[4])) / 800.0
            sc = slope + 0.00002 * math.hypot(dx, dz) + 0.002 * max(0.0, hh[0] - 400.0) / 100.0
            if sc < bs:
                bs = sc
                best = (px, pz)
    return best


def flatten(Hm, x, z, rad, blend, h=None):
    """Aplana el terreno en un disco (para pueblos y ciudades), mezclando hacia el terreno de alrededor."""
    cx = (x - T.X0) / T.CELL - 0.5
    cz = (z - T.Z0) / T.CELL - 0.5
    reach = int((rad + blend) / T.CELL) + 2
    c0, c1 = max(0, int(cx) - reach), min(T.W, int(cx) + reach + 1)
    r0, r1 = max(0, int(cz) - reach), min(T.H, int(cz) + reach + 1)
    sub = Hm[r0:r1, c0:c1]
    ys, xs = np.mgrid[r0:r1, c0:c1]
    d = np.hypot((xs + 0.5) * T.CELL + T.X0 - x, (ys + 0.5) * T.CELL + T.Z0 - z)
    if h is None:
        h = float(sub[int(cz) - r0, int(cx) - c0])
    k = 1.0 - T.sstep(rad, rad + blend, d)
    Hm[r0:r1, c0:c1] = sub * (1 - k) + h * k
    return h


def main(viz=True):
    global T0
    T0 = time.time()
    rng = np.random.RandomState(SEED)
    log("terreno…")
    X, Z, Hm, bio = T.build(SEED)
    grid = N.Grid(Hm)
    W_ = World()
    W_.places = []  # {id, kind, name, x, z, ...}
    # ── lugares grandes (ciudades)
    big = [("Puerto Alba", 43000, 500), ("Bahía Ámbar", -37000, 500), ("Santa Aurora", 3000, -37000), ("Villa Cóndor", -35000, -52000),
           ("Monte Sol", 31000, -46000), ("Quebrada Roja", 4000, -80000), ("Paso del Cóndor", -50000, -30000), ("Río Hondo", 50000, -22000)]
    rejects = [(0, 0, 4200)]
    for nm, x, z in big:
        site = flat_site(grid, x, z, 3000.0, rejects)
        rejects.append((site[0], site[1], 9000.0))
        W_.places.append({"kind": "ciudad", "name": nm, "x": site[0], "z": site[1]})
    # ── pueblos (poisson aproximado)
    pool = NM.pool("pueblo", rng)
    tries = 0
    towns = []
    while len(towns) < 26 and tries < 4000:
        tries += 1
        x = rng.uniform(T.X0 + 4000, T.X1 - 4000)
        z = rng.uniform(T.Z0 + 4000, 300)
        if any(math.hypot(x - rx, z - rz) < rd for rx, rz, rd in rejects):
            continue
        hh = grid.h(np.array([x, x + 400, x - 400, x, x]), np.array([z, z, z, z + 400, z - 400]), smooth=True)
        if hh[0] < 6.0 or hh[0] > 1100.0:
            continue
        slope = max(abs(hh[1] - hh[2]), abs(hh[3] - hh[4])) / 800.0
        if slope > 0.06:
            continue
        rejects.append((x, z, 12500.0))
        towns.append((x, z))
    for (x, z), nm in zip(towns, pool):
        W_.places.append({"kind": "pueblo", "name": nm, "x": x, "z": z})
    log("lugares:", len(W_.places))
    # aplanado de los lugares
    for p in W_.places:
        rad = 420.0 if p["kind"] == "ciudad" else 210.0
        p["h"] = flatten(Hm, p["x"], p["z"], rad, 380.0 if p["kind"] == "ciudad" else 260.0)
    grid = N.Grid(Hm)
    W_.grid = grid
    W_.Hm = Hm
    W_.bio = bio
    # ── Dream City: la circunvalación y los conectores con las rutas de la ciudad
    nodes = {}   # id -> dict
    edges = []   # dict(a, b, cls, name, pts (Nx2))

    def add_node(nid, x, z, kind, name="", **kw):
        nodes[nid] = dict(id=nid, x=float(x), z=float(z), kind=kind, name=name, **kw)
        return nid

    RING_R = 3300.0
    ex = {e["num"]: e for e in CITY["exits"]}
    def bearing_deg(e):
        return math.degrees(math.atan2(e["z"], e["x"]))
    ring_degs = [14.0, bearing_deg(ex[20]), -22.0, bearing_deg(ex[80]), -68.0, -90.0, -113.0, -135.0, -158.0, bearing_deg(ex[40]) - 360.0, -194.0]
    ring_degs.sort(reverse=True)
    ring_ids = []
    def ring_pt(deg):
        a = math.radians(deg)
        r = RING_R + 45.0 * math.sin(a * 3.0 + 0.7) + 25.0 * math.sin(a * 7.0)
        return r * math.cos(a), r * math.sin(a)
    for dg in ring_degs:
        x, z = ring_pt(dg)
        nid = "ring%d" % round(dg * 10)
        add_node(nid, x, z, "anillo", "AU-1")
        ring_ids.append(nid)
    # arco del anillo entre cada par de nodos consecutivos (una sola poligonal por tramo)
    for i in range(len(ring_degs) - 1):
        d0, d1 = ring_degs[i], ring_degs[i + 1]
        n = max(4, int(abs(math.radians(d0 - d1)) * RING_R / N.STEP))
        pts = np.array([ring_pt(d0 + (d1 - d0) * k / n) for k in range(n + 1)])
        edges.append(dict(a=ring_ids[i], b=ring_ids[i + 1], cls="anillo", name="AU-1", pts=pts))
    # conectores: la punta de cada ruta de la ciudad (20, 40, 80) sigue hasta el anillo
    for num in (20, 40, 80):
        e = ex[num]
        nid = "exit%d" % num
        add_node(nid, e["x"], e["z"], "ciudad_salida", "Ruta %d" % num, y=e["y"], yaw=e["yaw"], hw=e["hw"], sw=e["sw"])
        deg = bearing_deg(e)
        if num == 40:
            deg -= 360.0
        rid = min(ring_ids, key=lambda i: abs(math.degrees(math.atan2(nodes[i]["z"], nodes[i]["x"])) - (deg + (360.0 if deg < -180.0 else 0.0))) if True else 0)
        a_, b_ = np.array([e["x"], e["z"]]), np.array([nodes[rid]["x"], nodes[rid]["z"]])
        L = np.linalg.norm(b_ - a_)
        n = int(L / N.STEP)
        t = np.linspace(0, 1, n + 1)[:, None]
        base = a_ + (b_ - a_) * t
        nrm = np.array([-(b_ - a_)[1], (b_ - a_)[0]]) / L
        wob = (12.0 * np.sin(t[:, 0] * math.pi * 3.0) * np.sin(t[:, 0] * math.pi))[:, None] * nrm
        edges.append(dict(a=nid, b=rid, cls="conector", name="Ruta %d" % num, pts=base + wob))
    # el desvío a la Aventura: un camino corto que sale de la Ruta 20 (la entrada a la Aventura ya no cierra la ruta)
    c20 = [e for e in edges if e["name"] == "Ruta 20"][0]["pts"]
    k20 = int(len(c20) * 0.38)
    p20 = c20[k20]
    t20 = c20[k20 + 3] - c20[k20 - 3]
    t20 = t20 / np.linalg.norm(t20)
    n20 = np.array([t20[1], -t20[0]])  # hacia el norte (−z) si la ruta va al este
    if n20[1] > 0:
        n20 = -n20
    end20 = p20 + n20 * 330.0 + t20 * 90.0
    ns = max(4, int(330.0 / N.STEP))
    spur = np.array([p20 + n20 * (330.0 * (i / ns)) + t20 * (90.0 * (i / ns) ** 2) for i in range(ns + 1)])
    add_node("aventura_ini", p20[0], p20[1], "cruce", "")
    add_node("aventura", spur[-1][0], spur[-1][1], "paraje", "Aventura")
    # la Ruta 20 se parte en el nacimiento del desvío
    ei20 = [i for i, e in enumerate(edges) if e["name"] == "Ruta 20"][0]
    e20 = edges[ei20]
    a_part = np.vstack([e20["pts"][:k20], p20[None, :]])
    b_part = np.vstack([p20[None, :], e20["pts"][k20:]])
    edges[ei20] = dict(a=e20["a"], b="aventura_ini", cls="conector", name="Ruta 20", pts=a_part)
    edges.append(dict(a="aventura_ini", b=e20["b"], cls="conector", name="Ruta 20", pts=b_part))
    edges.append(dict(a="aventura_ini", b="aventura", cls="camino", name="Camino a la Aventura", pts=spur))
    # la Ruta Panorámica llega al extremo este del anillo
    pe = CITY["pan_end"]
    add_node("pan_end", pe[0], pe[2], "ciudad_salida", "Ruta Panorámica", y=pe[1], hw=pe[5], sw=pe[6])
    a_, b_ = np.array([pe[0], pe[2]]), np.array([nodes[ring_ids[0]]["x"], nodes[ring_ids[0]]["z"]])
    n = max(3, int(np.linalg.norm(b_ - a_) / N.STEP))
    edges.append(dict(a="pan_end", b=ring_ids[0], cls="conector", name="Ruta Panorámica", pts=a_ + (b_ - a_) * np.linspace(0, 1, n + 1)[:, None]))
    W_.nodes, W_.edges, W_.ring_ids = nodes, edges, ring_ids
    # ── esqueleto: ciudades y pueblos (cada uno con su nodo) + Dream City (que sale por los nodos del anillo)
    sk = []
    for p in W_.places:
        nid = "%s_%d" % (p["kind"], len([k for k in nodes if k.startswith(p["kind"])]))
        add_node(nid, p["x"], p["z"], p["kind"], p["name"], h=p["h"])
        p["id"] = nid
        sk.append(nid)
    def sea_between(ia, ib):
        xs = np.linspace(nodes[ia]["x"], nodes[ib]["x"], 60)
        zs = np.linspace(nodes[ia]["z"], nodes[ib]["z"], 60)
        hh = grid.h(xs, zs, smooth=True)
        return bool(np.any((hh < 0.3) & (zs > 900.0)))
    def dist_ab(ia, ib):
        return math.hypot(nodes[ia]["x"] - nodes[ib]["x"], nodes[ia]["z"] - nodes[ib]["z"])
    ring_used = {}
    def ring_for(nid, avoid=()):
        """el nodo del anillo que mira hacia ese lugar (cada uno sirve a un solo camino hacia afuera)"""
        ang = math.degrees(math.atan2(nodes[nid]["z"], nodes[nid]["x"]))
        best = None
        for rid in ring_ids:
            if rid in ring_used or rid in avoid:
                continue
            ra = math.degrees(math.atan2(nodes[rid]["z"], nodes[rid]["x"]))
            d = abs((ra - ang + 180.0) % 360.0 - 180.0)
            if best is None or d < best[0]:
                best = (d, rid)
        return best
    sk_edges = []
    pairs = set()
    def add_sk(ia, ib, cls):
        key = (min(ia, ib), max(ia, ib))
        if key in pairs:
            return
        pairs.add(key)
        sk_edges.append((ia, ib, dist_ab(ia, ib), cls))
    # troncales: Delaunay entre ciudades (y Dream City en el centro)
    cities = [p["id"] for p in W_.places if p["kind"] == "ciudad"]
    DREAM = "dream"
    add_node(DREAM, 0.0, 0.0, "dream", "Dream City")
    tri = Delaunay(np.array([[nodes[i]["x"], nodes[i]["z"]] for i in cities + [DREAM]]))
    cu = cities + [DREAM]
    cand = set()
    for simp in tri.simplices:
        for i in range(3):
            a, b = int(simp[i]), int(simp[(i + 1) % 3])
            cand.add((min(a, b), max(a, b)))
    for a, b in sorted(cand, key=lambda ab: dist_ab(cu[ab[0]], cu[ab[1]])):
        ia, ib = cu[a], cu[b]
        if dist_ab(ia, ib) > 98000.0 or sea_between(ia, ib):
            continue
        if DREAM in (ia, ib):
            other = ib if ia == DREAM else ia
            if nodes[other]["name"] in ("Puerto Alba", "Bahía Ámbar"):
                continue  # esas dos salen por la autopista costera del anillo
            best = ring_for(other)
            if best is None:
                continue
            ring_used[best[1]] = other
            add_sk(best[1], other, "autopista")
        else:
            add_sk(ia, ib, "ruta" if dist_ab(ia, ib) < 55000.0 else "autopista")
    log("troncales:", len(sk_edges))
    # pueblos: Delaunay entre todos los lugares (sin repetir las troncales)
    allp = [p["id"] for p in W_.places]
    tri = Delaunay(np.array([[nodes[i]["x"], nodes[i]["z"]] for i in allp]))
    cand = set()
    for simp in tri.simplices:
        for i in range(3):
            a, b = int(simp[i]), int(simp[(i + 1) % 3])
            cand.add((min(a, b), max(a, b)))
    for a, b in sorted(cand, key=lambda ab: dist_ab(allp[ab[0]], allp[ab[1]])):
        ia, ib = allp[a], allp[b]
        ka, kb = nodes[ia]["kind"], nodes[ib]["kind"]
        L = dist_ab(ia, ib)
        if ka == "ciudad" and kb == "ciudad":
            continue
        maxlen = 46000.0 if (ka == "ciudad" or kb == "ciudad") else 31000.0
        if L > maxlen or L < 800.0 or sea_between(ia, ib):
            continue
        add_sk(ia, ib, "provincial" if (ka == "ciudad" or kb == "ciudad" or rng.rand() < 0.7) else "camino")
    # pueblos cercanos al anillo se enganchan con un camino a su nodo más cercano (uno por pueblo)
    for p in W_.places:
        d = math.hypot(p["x"], p["z"])
        if p["kind"] == "pueblo" and d < 16000.0:
            best = ring_for(p["id"])
            if best is not None:
                ring_used[best[1]] = p["id"]
                add_sk(best[1], p["id"], "provincial")
    # los extremos del anillo salen por la costa hacia las dos ciudades de los costados
    for rid, cname in ((ring_ids[0], "Puerto Alba"), (ring_ids[-1], "Bahía Ámbar")):
        cid = [p["id"] for p in W_.places if p["name"] == cname][0]
        add_sk(rid, cid, "autopista")
    log("aristas del esqueleto:", len(sk_edges))
    W_.sk_edges = sk_edges
    return W_


def route_skeleton(W_):
    grid, nodes, edges = W_.grid, W_.nodes, W_.edges
    pen = np.ones(grid.H.shape, dtype=np.float32)
    def mark(poly, endpoints, rad=1, val=3.0):
        for (x, z) in poly[::2]:
            c, r = grid.idx(x, z)
            c, r = int(round(c)), int(round(r))
            for dr in range(-rad, rad + 1):
                for dc in range(-rad, rad + 1):
                    rr, cc = r + dr, c + dc
                    if 0 <= rr < T.H and 0 <= cc < T.W:
                        pen[rr, cc] = max(pen[rr, cc], val)
    # los caminos que ya existen (anillo, conectores)
    for e in edges:
        mark(e["pts"], [], 1, 2.5)
    rank = {"autopista": 0, "ruta": 1, "provincial": 2, "camino": 3}
    order = sorted(W_.sk_edges, key=lambda e: (rank[e[3]], e[2]))
    done = 0
    counters = {"autopista": 2, "ruta": 3, "provincial": 10, "camino": 40, "montana": 60}
    for ia, ib, L, cls in order:
        gmax = N.CLS[cls][2]
        a, b = (nodes[ia]["x"], nodes[ia]["z"]), (nodes[ib]["x"], nodes[ib]["z"])
        t0 = time.time()
        # penalidad local: alrededor de los extremos no se aplica
        p2 = pen.copy()
        for (x, z) in (a, b):
            c, r = grid.idx(x, z)
            c, r = int(round(c)), int(round(r))
            p2[max(0, r - 30):r + 31, max(0, c - 30):c + 31] = 1.0
        path = N.astar(grid, a, b, gmax * 1.25, p2)
        if path is None:
            log("sin camino", ia, ib)
            continue
        poly = N.pull_strings(grid, path, gmax * 1.25)
        # ¿es de montaña? (por la pendiente del camino)
        pts0 = N.resample(poly)
        hh = grid.h(pts0[:, 0], pts0[:, 1], smooth=True)
        gr = np.abs(np.diff(hh)) / N.STEP
        rng_h = float(hh.max() - hh.min())
        if cls in ("provincial", "camino", "ruta", "autopista") and (np.percentile(gr, 90) > 0.07 or rng_h > 350.0):
            cls = "montana"
        rmin = N.CLS[cls][1]
        poly, caracter = N.meander(grid, poly, cls, np.random.RandomState(SEED + int(abs(nodes[ia]["x"] * 3 + nodes[ia]["z"] * 7 + nodes[ib]["x"] * 11 + nodes[ib]["z"])) % 100003), gmax * 1.25)
        pts = N.fillet(poly, rmin)
        pts = N.smooth_poly(pts, max(25.0, rmin * 0.12))
        pre = {"autopista": "AU-", "ruta": "RN-"}.get(cls, "RP-")
        counters[cls] += 1
        import topo as _topo
        _topo.add_with_overlap(W_, ia, ib, cls, pre + str(counters[cls]), pts)
        mark(pts, [], 1, 3.0)
        done += 1
        log("%-9s %-8s %-24s → %-24s %5.1f km (%d pts) %.1fs" % (cls, caracter, nodes[ia]["name"], nodes[ib]["name"], L / 1000.0, len(pts), time.time() - t0))
    return edges


def finish(W_, rng):
    import topo
    import export
    n1 = topo.planarize(W_)
    log("cruces:", n1)
    pool = NM.pool("villa", rng)
    nv = topo.place_villages(W_, rng, pool)
    log("villas sobre las rutas:", nv)
    for n in list(W_.nodes.values()):
        if n["kind"] == "villa":
            n["h"] = flatten(W_.Hm, n["x"], n["z"], 140.0, 200.0)
    W_.grid = N.Grid(W_.Hm)
    ns = topo.add_streets(W_)
    log("calles de pueblos:", ns)
    n2 = topo.planarize(W_, near_node=20.0)
    log("cruces con calles:", n2)
    topo.prune_islands(W_)
    topo.exact_terrain(W_)
    topo.compute_heights(W_)
    topo.build_graph(W_)
    topo.make_pois(W_, rng)
    topo.make_signs(W_)
    topo.make_edge_dest(W_)
    km = sum(topo.seg_len(e["pts"]) for e in W_.edges) / 1000.0
    kinds = {}
    for e in W_.edges:
        kinds[e["cls"]] = kinds.get(e["cls"], 0) + topo.seg_len(e["pts"]) / 1000.0
    stats = {"km": round(km, 1), "edges": len(W_.edges), "nodes": len(W_.nodes), "km_por_clase": {k: round(v, 1) for k, v in kinds.items()}}
    log("km totales:", round(km, 1), "| aristas:", len(W_.edges), "| nodos:", len(W_.nodes), "|", stats["km_por_clase"])
    out = os.path.join(HERE, "..", "..", "godot", "game", "data", "region")
    os.makedirs(out, exist_ok=True)
    sizes = export.write(W_, os.path.join(out, "region_1.bin"), stats)
    log("escrito:", sizes)
    # alturas de las rutas parejas en los cruces y con la pendiente de su clase (fix_heights.py, reemplaza a topo.compute_heights) y después los empalmes entre rutas paralelas sin conexión (add_connectors.py)
    import fix_heights
    import add_connectors
    fix_heights.patch(os.path.join(out, "region_1.bin"))
    n_conn = add_connectors.run(os.path.join(out, "region_1.bin"))
    log("alturas rehechas · empalmes:", n_conn)


if __name__ == "__main__":
    W_ = main()
    route_skeleton(W_)
    rng = np.random.RandomState(SEED + 77)
    finish(W_, rng)
    if "--viz" in sys.argv or True:
        import viz
        roads = [dict(cls=e["cls"], pts=[tuple(p) for p in e["pts"]]) for e in W_.edges if e["cls"] != "calle"]
        pl = [dict(kind=n["kind"] if n["kind"] != "pueblo" else "pueblo", x=n["x"], z=n["z"]) for n in W_.nodes.values() if n["kind"] in ("ciudad", "pueblo", "villa")]
        viz.render(W_.Hm, W_.bio, "/tmp/claude-0/shots/region_roads.png", 0.8, roads, pl)
        viz.render_map(W_.Hm, W_.bio, os.path.join(HERE, "..", "..", "godot", "game", "data", "region", "region_map.png"), [dict(cls=e["cls"], pts=e["pts"]) for e in W_.edges if e["cls"] != "calle"])
    log("listo")
