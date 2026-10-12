"""Lee region_1.bin (para pruebas y capturas)."""
import json, struct
import numpy as np
def read(path='/home/user/Rally-Sim-movile/godot/game/data/region/region_1.bin'):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[8:12])[0]
    m = json.loads(b[12:12 + jl])
    off = 12 + jl
    W, H = m['grid']['w'], m['grid']['h']
    delta = np.frombuffer(b, '<i2', W * H, off); off += W * H * 2
    bio = np.frombuffer(b, 'u1', W * H, off); off += W * H + ((4 - (W * H) % 4) % 4)
    n = m['n_pts']
    P = np.frombuffer(b, '<i4', n * 2, off).reshape(-1, 2) / 10.0; off += n * 8
    Hh = np.frombuffer(b, '<f4', n, off); off += n * 4
    return m, delta.reshape(H, W), bio.reshape(H, W), P, Hh
