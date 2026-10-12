"""Terreno de la región de Dream City (mapa grande del mundo abierto). Función pura y determinista: sale igual siempre (semilla fija).
Cuadrícula de 100 m. Eje x al este, z al sur (el norte es −z); Dream City está en (0, 0) y el mar queda al sur (z > 1260).
Cerca de la ciudad (r < 3 km) la altura es EXACTAMENTE la de CityLayout.height (se porta acá); más lejos suma sierras, cordillera, quebrada, litoral…"""
import numpy as np
from scipy.ndimage import zoom, gaussian_filter

CELL = 100.0
X0, X1 = -60000.0, 60000.0
Z0, Z1 = -90000.0, 3000.0
W = int(round((X1 - X0) / CELL))
H = int(round((Z1 - Z0) / CELL))
SEA_Z = 1260.0
HILL_C = (-1086.0, -1086.0)
HILL_R = 430.0
HILL_H = 72.0
MT_A = (1950.0, 880.0, 1050.0, 72.0)
MT_B = (2790.0, 1190.0, 520.0, 40.0)

BIOMES = ["pampa", "estepa", "sierra", "roca", "nieve", "selva", "quebrada", "arena", "humedal"]
B = {n: i for i, n in enumerate(BIOMES)}


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def grid_xz():
    xs = X0 + (np.arange(W) + 0.5) * CELL
    zs = Z0 + (np.arange(H) + 0.5) * CELL
    return np.meshgrid(xs, zs)  # X[row=z, col=x]


def _mount(X, Z, m):
    d = np.hypot(X - m[0], Z - m[1])
    return np.where(d >= m[2], 0.0, m[3] * (1.0 - sstep(0.0, m[2], d)))


def city_parts(X, Z):
    """Misma fórmula que CityLayout.height (sin el bolsillo x > 3000 ni la plaza de drift), separada en (todo, lomas)."""
    r = np.hypot(X, Z)
    h = 9.0 * sstep(SEA_Z, SEA_Z - 220.0, Z)
    h = h + 1.4 * np.sin(X * 0.0021 + 1.0) * np.cos(Z * 0.0017)
    d = np.hypot(X - HILL_C[0], Z - HILL_C[1])
    out = sstep(1100.0, 1500.0, r) * sstep(HILL_R, HILL_R + 300.0, d)
    lomas = out * (11.0 * np.sin(X * 0.0031 + Z * 0.0023) + 6.0 * np.sin(X * 0.0057 - Z * 0.0049 + 2.0))
    h = h + lomas
    h = h - 12.0 * sstep(SEA_Z + 40.0, SEA_Z + 260.0, Z)
    h = h + np.where(d < HILL_R, HILL_H * (1.0 - d / HILL_R), 0.0)
    h = h + np.maximum(_mount(X, Z, MT_A), _mount(X, Z, MT_B))
    return h, lomas


def city_height(X, Z):
    return city_parts(X, Z)[0]


def fbm(shape, cell_m, octaves, seed, gain=0.5):
    """Ruido fractal suave: suma de grillas aleatorias interpoladas (cúbico). cell_m = tamaño de la celda de la octava más grande (m)."""
    rng = np.random.RandomState(seed)
    out = np.zeros(shape, dtype=np.float32)
    amp = 1.0
    tot = 0.0
    size = cell_m
    for o in range(octaves):
        gh = max(2, int(np.ceil(shape[0] * CELL / size)) + 2)
        gw = max(2, int(np.ceil(shape[1] * CELL / size)) + 2)
        g = rng.randn(gh, gw).astype(np.float32)
        z = zoom(g, (shape[0] / (gh - 2) * (gh / gh), shape[1] / (gw - 2)), order=3)[: shape[0], : shape[1]]
        if z.shape != tuple(shape):
            z = np.pad(z, ((0, shape[0] - z.shape[0]), (0, shape[1] - z.shape[1])), mode="edge")
        out += amp * z
        tot += amp
        amp *= gain
        size *= 0.5
    return out / tot


def build(seed=20261004):
    X, Z = grid_xz()
    R = np.hypot(X, Z)
    shape = X.shape
    base, lomas = city_parts(X, Z)
    mask = sstep(3400.0, 5200.0, R)  # los rasgos grandes empiezan más allá de la ronda de la ciudad
    n1 = fbm(shape, 12000.0, 5, seed + 1)   # relieve de fondo
    n2 = fbm(shape, 5000.0, 4, seed + 2)
    ridge = np.clip(1.0 - np.abs(fbm(shape, 9000.0, 5, seed + 3)) * 2.4, 0.0, 1.0) ** 1.6
    # coordenadas alabeadas: las zonas grandes no salen redondas ni rectas
    Xw = X + 12000.0 * fbm(shape, 30000.0, 3, seed + 4)
    Zw = Z + 12000.0 * fbm(shape, 30000.0, 3, seed + 5)
    moist = fbm(shape, 40000.0, 3, seed + 6) * 1.6 + (Xw / 90000.0) + 0.1  # más húmedo al este
    ter = np.zeros(shape, dtype=np.float32)
    # pampa ondulada: lomas largas y suaves (reemplazan las ondas diagonales de la ciudad cuando uno se aleja)
    ter += 16.0 * n1 + 7.0 * n2 - 0.85 * lomas
    cw_all = np.zeros(shape, dtype=np.float32)
    sierra_m = np.zeros(shape, dtype=np.float32)
    # sierras centrales (redondeadas y verdes)
    for cx, cz, rad, amp in [(-9000, -42000, 17000, 430), (15000, -50000, 12000, 320), (27000, -22000, 9000, 150), (-23000, -22000, 7500, 130), (-4000, -16000, 5000, 90)]:
        d = np.hypot(Xw - cx, Zw - cz)
        bump = 1.0 - sstep(0.0, rad, d)
        ter += amp * bump * (0.5 + 0.5 * np.clip(0.5 + n2 * 1.3, 0, 1)) + 0.4 * amp * bump * ridge
        sierra_m = np.maximum(sierra_m, bump)
    # cordillera al oeste: crece hacia el borde, con picos nevados
    cw = sstep(-28000.0, -56000.0, Xw) * sstep(-2000.0, -16000.0, Zw) * sstep(-92000.0, -64000.0, Zw)
    ter += cw * (980.0 * (0.4 + 0.6 * ridge) + 260.0 * np.clip(n2 + 0.5, 0, 1))
    # quebrada del norte: mesetas y barrancas coloradas
    qz = sstep(-62000.0, -76000.0, Zw)
    terr = np.round((n1 * 0.9 + n2 * 0.6 + 0.2) * 5.0) / 5.0
    ter += qz * (330.0 + 240.0 * terr + 170.0 * ridge)
    # litoral del este: bajo y llano
    le = sstep(30000.0, 44000.0, Xw)
    ter = ter * (1.0 - 0.9 * le * sstep(-44000.0, -12000.0, Zw))
    H0 = base + mask * ter
    # costa con ondas más allá de la ciudad (bahías y cabos)
    ax = np.abs(X)
    coast_z = SEA_Z + sstep(3500.0, 7000.0, ax) * (480.0 + 420.0 * np.sin(X / 7000.0 + 0.6) + 220.0 * np.sin(X / 2600.0))
    sea_c = 9.0 * sstep(coast_z, coast_z - 220.0, Z) - 12.0 * sstep(coast_z + 40.0, coast_z + 260.0, Z)
    sea_0 = 9.0 * sstep(SEA_Z, SEA_Z - 220.0, Z) - 12.0 * sstep(SEA_Z + 40.0, SEA_Z + 260.0, Z)
    H0 += (sea_c - sea_0) * sstep(3500.0, 7000.0, ax)
    # biomas: por altura, humedad y zona
    biome = np.full(shape, B["pampa"], dtype=np.uint8)
    biome = np.where(moist < -0.8, B["estepa"], biome)
    biome = np.where(sierra_m > 0.22, B["sierra"], biome)
    biome = np.where((moist > 0.45) & (H0 < 70.0) & (Z < 200.0), B["humedal"], biome)
    biome = np.where((moist > 0.30) & (Zw < -30000.0) & (Zw > -62000.0) & (H0 < 260.0), B["selva"], biome)
    biome = np.where(qz > 0.25, B["quebrada"], biome)
    biome = np.where(cw > 0.14, B["roca"], biome)
    biome = np.where(H0 > 520.0, B["roca"], biome)
    biome = np.where(H0 > 880.0, B["nieve"], biome)
    biome = np.where((Z > coast_z - 350.0) & (H0 < 6.0), B["arena"], biome)
    biome = np.where((X < -24000.0) & (Z > -9000.0) & (cw < 0.1) & (fbm(shape, 8000.0, 3, seed + 9) > 0.1), B["estepa"], biome)
    return X, Z, H0.astype(np.float32), biome


if __name__ == "__main__":
    X, Z, Hm, bio = build()
    print(Hm.shape, Hm.min(), Hm.max())
