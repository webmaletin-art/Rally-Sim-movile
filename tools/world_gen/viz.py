import numpy as np
from PIL import Image, ImageDraw
import terrain as T

PAL = {"pampa": (150, 190, 110), "estepa": (205, 185, 130), "sierra": (110, 150, 95), "roca": (150, 140, 130), "nieve": (245, 247, 250),
       "selva": (50, 120, 70), "quebrada": (200, 120, 80), "arena": (232, 214, 160), "humedal": (120, 175, 150)}

def render(Hm, bio, path, scale=0.5, roads=None, towns=None):
    img = np.zeros(Hm.shape + (3,), dtype=np.float32)
    for n, i in T.B.items():
        img[bio == i] = PAL[n]
    gy, gx = np.gradient(Hm, T.CELL)
    shade = np.clip(0.75 + (-gx * 0.7 + gy * 0.7) * 1.2, 0.35, 1.25)
    img = img * shade[..., None]
    sea = (Hm < 0.0) & (T.grid_xz()[1] > 1000.0)
    img[sea] = (60, 130, 175)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    sx = lambda x: (x - T.X0) / T.CELL
    sz = lambda z: (z - T.Z0) / T.CELL
    d = ImageDraw.Draw(im)
    if roads:
        cols = {"autopista": (220, 30, 30), "ruta": (255, 255, 255), "provincial": (250, 220, 60), "camino": (255, 140, 40), "tierra": (140, 90, 40), "montana": (170, 60, 200), "anillo": (255, 0, 0)}
        for r in roads:
            pts = [(sx(x), sz(z)) for x, z in r["pts"][::4]]
            if len(pts) > 1:
                d.line(pts, fill=cols.get(r["cls"], (255, 255, 255)), width=2 if r["cls"] in ("autopista", "anillo") else 1)
    if towns:
        for t in towns:
            x, z = sx(t["x"]), sz(t["z"])
            rad = {"ciudad": 7, "pueblo": 4, "villa": 2, "dream": 9}.get(t["kind"], 3)
            d.ellipse([x - rad, z - rad, x + rad, z + rad], fill=(0, 0, 0), outline=(255, 255, 0))
    if scale != 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    im.save(path)

def render_map(Hm, bio, path, roads):
    """Mapa liso para el mapa grande del juego (1 píxel = 100 m): relieve sombreado, mar, y las rutas por clase (sin nombres: los dibuja el juego)."""
    img = np.zeros(Hm.shape + (3,), dtype=np.float32)
    PAL2 = {"pampa": (176, 200, 140), "estepa": (206, 192, 150), "sierra": (140, 170, 120), "roca": (170, 160, 150), "nieve": (248, 249, 251),
            "selva": (96, 140, 100), "quebrada": (208, 140, 104), "arena": (234, 220, 176), "humedal": (150, 188, 168)}
    for n, i in T.B.items():
        img[bio == i] = PAL2[n]
    gy, gx = np.gradient(Hm, T.CELL)
    shade = np.clip(0.80 + (-gx * 0.9 + gy * 0.9) * 1.1, 0.5, 1.2)
    img = img * shade[..., None]
    X, Z = T.grid_xz()
    sea = (Hm < 0.0) & (Z > 1000.0)
    img[sea] = (70, 120, 160)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    col = {"autopista": ((255, 255, 255), 3), "anillo": ((255, 255, 255), 3), "ruta": ((250, 250, 250), 2), "conector": ((250, 250, 250), 2), "provincial": ((255, 230, 140), 1), "camino": ((255, 210, 120), 1), "tierra": ((200, 150, 100), 1), "montana": ((255, 200, 220), 1)}
    sx = lambda x: (x - T.X0) / T.CELL
    sz = lambda z: (z - T.Z0) / T.CELL
    for pass_ in (0, 1):
        for r in roads:
            c, w = col.get(r["cls"], ((255, 255, 255), 1))
            pts = [(sx(x), sz(z)) for x, z in r["pts"][::5]]
            if len(pts) > 1:
                if pass_ == 0:
                    d.line(pts, fill=(40, 40, 50), width=w + 2)
                else:
                    d.line(pts, fill=c, width=w)
    im.save(path, optimize=True)


if __name__ == "__main__":
    X, Z, Hm, bio = T.build()
    render(Hm, bio, "/tmp/claude-0/shots/region_terrain.png", 0.8)
