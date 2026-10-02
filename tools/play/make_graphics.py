"""Genera los gráficos de la app para Google Play con Pillow (sin archivos externos):
  godot/store/icons/*.png        → íconos del lanzador (los usa el preset «Google Play (AAB)»)
  store_listing/icono_512.png    → ícono de la ficha de Play Store (512×512)
  store_listing/grafico_funciones_1024x500.png → gráfico de funciones de la ficha
Uso: python3 tools/play/make_graphics.py   (si querés otro diseño, reemplazá los PNG a mano: tienen que mantener los nombres y tamaños)"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ICONS = os.path.join(ROOT, 'godot', 'store', 'icons')
LISTING = os.path.join(ROOT, 'store_listing')
os.makedirs(ICONS, exist_ok=True)
os.makedirs(LISTING, exist_ok=True)
FONT = '/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf'
ORANGE = (255, 122, 26)
NAVY1 = (9, 14, 24)
NAVY2 = (22, 36, 58)

def gradient(w, h, c1, c2):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x * 0.35 + y * 0.65) / (w * 0.35 + h * 0.65)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return img

def stripes(size, alpha=255):
    """Rayas de velocidad naranjas en diagonal (capa RGBA transparente)"""
    w, h = size
    lay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for i, (off, wd, col) in enumerate([(0.10, 0.07, ORANGE), (0.22, 0.03, (255, 255, 255)), (0.30, 0.10, ORANGE)]):
        x0 = int(w * off)
        d.polygon([(x0 + wd * w, 0), (x0 + wd * w * 2.2, 0), (x0 - w * 0.25 + wd * w * 2.2, h), (x0 - w * 0.25 + wd * w, h)], fill=col + (alpha,))
    return lay

def monogram(size, color=(255, 255, 255, 255), text='DR', scale=0.62):
    w, h = size
    lay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT, int(h * scale))
    d = ImageDraw.Draw(lay)
    bb = d.textbbox((0, 0), text, font=f)
    d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], (h - (bb[3] - bb[1])) / 2 - bb[1] - h * 0.03), text, font=f, fill=color)
    return lay

def icon(size=512, round_mask=False):
    img = gradient(size, size, NAVY1, NAVY2).convert('RGBA')
    img.alpha_composite(stripes((size, size), 235))
    sh = monogram((size, size), (0, 0, 0, 140))
    sh = sh.filter(ImageFilter.GaussianBlur(size * 0.012))
    img.alpha_composite(sh, (int(size * 0.012), int(size * 0.02)))
    img.alpha_composite(monogram((size, size)))
    # banda de cuadros abajo
    d = ImageDraw.Draw(img)
    n = 12
    cw = size / n
    y0 = int(size * 0.86)
    for r in range(2):
        for c in range(n):
            if (r + c) % 2 == 0:
                d.rectangle([c * cw, y0 + r * cw * 0.5, (c + 1) * cw, y0 + (r + 1) * cw * 0.5], fill=(255, 255, 255, 235))
    return img

def adaptive(size=432):
    """Primer plano (el logo dentro del 66 % central, zona segura) y fondo"""
    bg = gradient(size, size, NAVY1, NAVY2).convert('RGBA')
    bg.alpha_composite(stripes((size, size), 235))
    fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    inner = int(size * 0.62)
    m = monogram((inner, inner), scale=0.72)
    sh = m.copy()
    sh = Image.new('RGBA', sh.size, (0, 0, 0, 0))
    fg.alpha_composite(m, ((size - inner) // 2, (size - inner) // 2))
    mono = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    mono.alpha_composite(monogram((inner, inner), (255, 255, 255, 255), scale=0.72), ((size - inner) // 2, (size - inner) // 2))
    return bg, fg, mono

def feature(w=1024, h=500):
    img = gradient(w, h, NAVY1, NAVY2).convert('RGBA')
    img.alpha_composite(stripes((w, h), 200))
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(FONT, 118)
    f2 = ImageFont.truetype(FONT, 38)
    for dx, dy, col in [(5, 6, (0, 0, 0, 170)), (0, 0, (255, 255, 255, 255))]:
        d.text((190 + dx, 110 + dy), 'DREAM', font=f1, fill=col)
        d.text((190 + dx, 225 + dy), 'RACING', font=f1, fill=(255, 122, 26, 255) if col[0] else col)
    d.text((196, 372), 'Rally · Drift · Aventura', font=f2, fill=(220, 230, 245, 255))
    return img.convert('RGB')

if __name__ == '__main__':
    icon(512).save(os.path.join(LISTING, 'icono_512.png'))
    icon(192).save(os.path.join(ICONS, 'icon_192.png'))
    bg, fg, mono = adaptive(432)
    bg.save(os.path.join(ICONS, 'adaptive_background_432.png'))
    fg.save(os.path.join(ICONS, 'adaptive_foreground_432.png'))
    mono.save(os.path.join(ICONS, 'adaptive_monochrome_432.png'))
    feature().save(os.path.join(LISTING, 'grafico_funciones_1024x500.png'))
    print('listo')
