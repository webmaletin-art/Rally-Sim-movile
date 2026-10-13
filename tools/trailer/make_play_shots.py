#!/usr/bin/env python3
"""Capturas para la ficha de Google Play (horizontales, 1920×1080) a partir de las fotos del tráiler: elige la mejor foto de cada tema, la deja en JPG y arma la hoja de contactos para revisarlas.
Uso: python3 tools/trailer/make_play_shots.py [carpeta_de_salida]      (por defecto store_listing/capturas)
Las fotos salen del juego tal cual (sin letreros). Se evitan las pantallas de menú con herramientas de desarrollo (la versión de Play no las tiene)."""
import glob
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
STILLS = os.environ.get('TRAILER_STILLS', '/tmp/trailer/stills')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'store_listing', 'capturas')

# (nombre del archivo, patrones de fotos en orden de preferencia)
SHOTS = [
    ('01_rally_atardecer', ['world/action/forest_sunset/a0_front_low.jpg', 'world/action/forest_sunset/*front_low.jpg']),
    ('02_aventura', ['world/extra/adv_girasoles/girasoles_front_low.jpg', 'world/extra/adv_*/*front_low.jpg']),
    ('03_dream_city', ['world/scoutw/plaza_sunset/a_front.jpg', 'world/scoutw/avenida3_golden/a_front.jpg']),
    ('04_region', ['world/aerial/puerto_alba/d1_alto_atras.jpg', 'world/scoutw/ruta_este/b_low.jpg']),
    ('05_garaje', ['ui/garage.png']),
    ('06_pintura', ['ui/paint.png']),
    ('07_lago', ['world/action/lake_dusk/a0_front_low.jpg', 'world/action/lake_dusk/*front_low.jpg']),
    ('08_travesia', ['ui/travesia.png', 'world/action/travesia/*front_low.jpg']),
]


def pick(patterns):
    for p in patterns:
        fs = sorted(glob.glob(os.path.join(STILLS, p)))
        if fs:
            return fs[0]
    return None


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, pats in SHOTS:
        src = pick(pats)
        if src is None:
            print('falta', name, pats)
            continue
        im = Image.open(src).convert('RGB')
        if im.size != (1920, 1080):
            im = im.resize((1920, 1080), Image.LANCZOS)
        dst = os.path.join(OUT, name + '.jpg')
        im.save(dst, quality=90, optimize=True)
        made.append(dst)
        print('%-22s %7d bytes  ← %s' % (os.path.basename(dst), os.path.getsize(dst), os.path.relpath(src, STILLS)))
    if made:
        cols = 4
        w, h = 480, 270
        rows = (len(made) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * w, rows * h), (12, 14, 20))
        for i, f in enumerate(made):
            sheet.paste(Image.open(f).resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
        sheet.save('/tmp/trailer/play_sheet.jpg', quality=85)
        print('hoja de contactos: /tmp/trailer/play_sheet.jpg')


if __name__ == '__main__':
    main()
