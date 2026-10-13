"""Lee y escribe region_1.bin completo (formato 'DRRG' v1, ver export.py): sirve para retocar el mapa sin volver a generarlo (agregar empalmes, rehacer alturas).
Todo lo que viene después del JSON se guarda como arreglos de numpy; `build_index` arma de nuevo el índice espacial (celdas de 128 m) a partir de las rutas."""
import json
import struct

import numpy as np

CH = 128.0


def read_all(path):
    b = open(path, "rb").read()
    assert b[:4] == b"DRRG"
    jl = struct.unpack("<I", b[8:12])[0]
    meta = json.loads(b[12:12 + jl].decode("utf-8"))
    off = 12 + jl
    W, H = meta["grid"]["w"], meta["grid"]["h"]
    ng = W * H
    delta_b = b[off:off + ng * 2]
    off += ng * 2
    bio_b = b[off:off + ng + ((4 - ng % 4) % 4)]
    off += ng + ((4 - ng % 4) % 4)
    n = meta["n_pts"]
    P = np.frombuffer(b, "<i4", n * 2, off).reshape(-1, 2).copy()
    off += n * 8
    Hh = np.frombuffer(b, "<f4", n, off).copy()
    off += n * 4
    pe = np.frombuffer(b, "<i4", n, off).copy()
    off += n * 4
    nc = meta["n_cells"]
    cells = np.frombuffer(b, "<i4", nc * 4, off).reshape(-1, 4).copy()
    off += nc * 16
    ns = meta["n_segs"]
    segs = np.frombuffer(b, "<i4", ns, off).copy()
    off += ns * 4
    assert off == len(b), "sobran %d bytes" % (len(b) - off)
    return dict(meta=meta, delta=delta_b, bio=bio_b, P=P, H=Hh, pe=pe, cells=cells, segs=segs, version=struct.unpack("<I", b[4:8])[0])


def build_index(P, edges_meta):
    """Celdas de 128 m con los tramos que las tocan: (cx, cz, inicio, cantidad) y la lista de tramos (índice global del punto donde empieza)."""
    cell = {}
    for em in edges_meta:
        p0, n = int(em[6]), int(em[7])
        for k in range(p0, p0 + n - 1):
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
    return np.array(cells, dtype=np.int32).reshape(-1, 4), np.array(segs, dtype=np.int32)


def write_all(path, d):
    meta = d["meta"]
    meta["n_pts"] = int(d["P"].shape[0])
    meta["n_cells"] = int(d["cells"].shape[0])
    meta["n_segs"] = int(d["segs"].shape[0])
    js = json.dumps(meta, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    with open(path, "wb") as f:
        f.write(b"DRRG")
        f.write(struct.pack("<II", d.get("version", 1), len(js)))
        f.write(js)
        f.write(d["delta"])
        f.write(d["bio"])
        f.write(d["P"].astype("<i4").tobytes())
        f.write(d["H"].astype("<f4").tobytes())
        f.write(d["pe"].astype("<i4").tobytes())
        f.write(d["cells"].astype("<i4").tobytes())
        f.write(d["segs"].astype("<i4").tobytes())


if __name__ == "__main__":
    import sys
    src = sys.argv[1]
    d = read_all(src)
    # prueba de ida y vuelta: reconstruir el índice y escribir tiene que dar el mismo archivo
    cells, segs = build_index(d["P"], d["meta"]["edges"])
    same = np.array_equal(cells, d["cells"]) and np.array_equal(segs, d["segs"])
    print("índice reconstruido igual al guardado:", same)
    write_all("/tmp/roundtrip.bin", d)
    print("archivo igual:", open(src, "rb").read() == open("/tmp/roundtrip.bin", "rb").read())
