"""Escribe la región en un solo archivo binario que lee el juego (godot/game/region/region_data.gd).
Formato 'DRRG' v1: magia(4) | versión u32 | largo del JSON u32 | JSON (utf-8, relleno a 4) | delta int16[H*W] (decímetros: terreno − CityLayout.height) |
bioma uint8[H*W] (relleno a 4) | puntos int32[2*N] (x, z en decímetros) | alturas float32[N] (m) | arista de cada punto int32[N] |
celdas int32[4*C] (cx, cz, inicio, cantidad: grilla de 128 m) | segmentos int32[S] (índice global del punto donde empieza cada tramo)."""
import json
import math
import struct
import numpy as np
import terrain as T
import network as N
import topo

CLS_LIST = ["anillo", "autopista", "ruta", "provincial", "camino", "tierra", "montana", "calle", "conector"]
KIND_LIST = ["dream", "anillo", "ciudad_salida", "ciudad", "pueblo", "villa", "cruce", "calle_fin", "paraje"]


def write(W_, path, stats=None):
    nodes = list(W_.nodes.values())
    idx = {n["id"]: i for i, n in enumerate(nodes)}
    all_pts = []
    all_h = []
    edges_meta = []
    p0 = 0
    for ei, e in enumerate(W_.edges):
        pts = e["pts"]
        n = len(pts)
        all_pts.append(np.round(pts * 10.0).astype(np.int32))
        all_h.append(np.round(e["h"] * 10.0).astype(np.int32))
        cls = e["cls"]
        surf = 0
        if cls == "tierra":
            surf = 1 if (ei * 7919) % 5 < 3 else 2
        elif cls == "camino":
            surf = 0 if (ei * 104729) % 100 < 55 else 2
        w = N.CLS[cls][0]
        df = W_.edge_dest.get(ei, ["", 0.0, "", 0.0])
        edges_meta.append([idx[e["a"]], idx[e["b"]], CLS_LIST.index(cls), e.get("name", ""), w, surf, p0, n, round(topo.seg_len(pts), 1), df[0], df[1], df[2], df[3]])
        p0 += n
    P = np.concatenate(all_pts, axis=0)
    Hh = np.concatenate([h.astype(np.float32) / 10.0 for h in all_h], axis=0).astype(np.float32)
    pe = np.concatenate([np.full(len(p), i, dtype=np.int32) for i, p in enumerate(all_pts)])
    # índice espacial: celdas de 128 m con los tramos que las tocan
    CH = 128.0
    cell = {}
    for ei, em in enumerate(edges_meta):
        p0_, n_ = em[6], em[7]
        for k in range(p0_, p0_ + n_ - 1):
            x0, z0 = P[k] / 10.0
            x1, z1 = P[k + 1] / 10.0
            for cx in range(int(np.floor(min(x0, x1) / CH)), int(np.floor(max(x0, x1) / CH)) + 1):
                for cz in range(int(np.floor(min(z0, z1) / CH)), int(np.floor(max(z0, z1) / CH)) + 1):
                    cell.setdefault((cx, cz), []).append(k)
    keys = sorted(cell.keys())
    cells = []
    segs = []
    for (cx, cz) in keys:
        cells.append([cx, cz, len(segs), len(cell[(cx, cz)])])
        segs.extend(cell[(cx, cz)])
    cells = np.array(cells, dtype=np.int32)
    segs = np.array(segs, dtype=np.int32)
    nodes_meta = []
    for n in nodes:
        nodes_meta.append([n["id"], round(n["x"], 1), round(n["z"], 1), KIND_LIST.index(n["kind"]), n.get("name", ""), round(W_.node_h[n["id"]], 2), [round(v, 4) for v in n.get("axis", [])]])
    # altura de cada servicio: la del camino más cercano (el playón queda a la altura de la ruta)
    from scipy.spatial import cKDTree
    tree = cKDTree(P / 10.0)
    for poi in W_.pois:
        d, k = tree.query([poi["x"], poi["z"]])
        poi["h"] = round(float(Hh[k]), 2)
    # lugares para aparecer (menú «¿Dónde aparecer?»): la estación principal de cada ciudad, más unos puntos especiales
    spawns = []
    node_by_id = {n["id"]: n for n in nodes}
    for n in nodes:
        if n["kind"] != "ciudad":
            continue
        for poi in W_.pois:
            if poi["kind"] == "fuel" and poi.get("near") == n["id"]:
                tn = (math.sin(poi["yaw"]), math.cos(poi["yaw"]))
                nr = (-tn[1] * poi["side"], tn[0] * poi["side"])
                spawns.append({"name": n["name"], "sub": "estación de servicio", "x": round(poi["x"] - nr[0] * 3.0, 1), "z": round(poi["z"] - nr[1] * 3.0, 1), "yaw": round(poi["yaw"], 4), "kind": "ciudad"})
                break
    spawns.sort(key=lambda s_: (-s_["x"] ** 0 * 0, s_["name"]))
    W_.spawns = spawns
    meta = {
        "version": 1,
        "grid": {"x0": T.X0, "z0": T.Z0, "w": T.W, "h": T.H, "cell": T.CELL},
        "n_pts": int(P.shape[0]), "n_cells": int(cells.shape[0]), "n_segs": int(segs.shape[0]), "cell": CH,
        "cls": CLS_LIST, "kinds": KIND_LIST, "biomes": T.BIOMES,
        "nodes": nodes_meta, "edges": edges_meta,
        "pois": W_.pois, "tolls": W_.tolls, "secrets": W_.secrets, "spawns": spawns,
        "signs": {k: v for k, v in W_.signs.items()},
        "stats": stats or {},
    }
    js = json.dumps(meta, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    delta = np.round(W_.delta * 10.0).clip(-32760, 32760).astype(np.int16)
    bio = W_.bio.astype(np.uint8).ravel()
    bio = np.concatenate([bio, np.zeros((4 - len(bio) % 4) % 4, dtype=np.uint8)])
    with open(path, "wb") as f:
        f.write(b"DRRG")
        f.write(struct.pack("<II", 1, len(js)))
        f.write(js)
        f.write(delta.tobytes())
        f.write(bio.tobytes())
        f.write(P.astype("<i4").tobytes())
        f.write(Hh.astype("<f4").tobytes())
        f.write(pe.astype("<i4").tobytes())
        f.write(cells.astype("<i4").tobytes())
        f.write(segs.astype("<i4").tobytes())
    base = path.rsplit("/", 1)[0]
    json.dump(spawns, open(base + "/spawns.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return len(js), delta.nbytes, len(bio), P.nbytes, Hh.nbytes, pe.nbytes, cells.nbytes, segs.nbytes
