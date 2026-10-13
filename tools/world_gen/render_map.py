#!/usr/bin/env python3
"""Vuelve a dibujar region_map.png (el mapa grande del juego) a partir de region_1.bin: el relieve sale del terreno de la ciudad más la diferencia guardada, el bioma del archivo y las rutas de las calles
(sin las de los pueblos). Hace falta cada vez que se agregan o se mueven rutas (empalmes, ramales, curvas).
Uso: python3 tools/world_gen/render_map.py [region_1.bin] [region_map.png]"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binio  # noqa: E402
import terrain as T  # noqa: E402
import viz  # noqa: E402

CLS = ["anillo", "autopista", "ruta", "provincial", "camino", "tierra", "montana", "calle", "conector"]


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    base = os.path.join(HERE, "..", "..", "godot", "game", "data", "region")
    src = argv[0] if len(argv) > 0 else os.path.join(base, "region_1.bin")
    dst = argv[1] if len(argv) > 1 else os.path.join(base, "region_map.png")
    d = binio.read_all(src)
    meta = d["meta"]
    W, H = meta["grid"]["w"], meta["grid"]["h"]
    delta = np.frombuffer(d["delta"], "<i2").reshape(H, W).astype(np.float64) * 0.1
    X, Z = T.grid_xz()
    Hm = T.city_height(X, Z) + delta
    bio = np.frombuffer(d["bio"], dtype=np.uint8)[:W * H].reshape(H, W)
    P = d["P"] / 10.0
    roads = []
    for e in meta["edges"]:
        cls = CLS[int(e[2])]
        if cls == "calle":
            continue
        roads.append(dict(cls=cls, pts=P[int(e[6]):int(e[6]) + int(e[7])]))
    viz.render_map(Hm, bio, dst, roads)
    print("escrito", dst, "con", len(roads), "rutas")


if __name__ == "__main__":
    main()
