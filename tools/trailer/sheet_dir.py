#!/usr/bin/env python3
"""Hoja de contactos de las fotos que coinciden con uno o varios patrones (con comodines, relativos a la carpeta de fotos), con el número de cada una, para elegir cuáles van al tráiler.
Uso: python3 tools/trailer/sheet_dir.py salida.jpg [--cols 5] [--rows 4] [--page 0] 'world/action/forest_day/*.jpg' …
Escribe también salida.txt con la lista (número → archivo) de la página."""
import glob
import os
import sys

from PIL import Image, ImageDraw

STILLS = os.environ.get('TRAILER_STILLS', '/tmp/trailer/stills')


def main():
    a = sys.argv[1:]
    out = a[0]
    cols, rows, page = 5, 4, 0
    pats = []
    i = 1
    while i < len(a):
        if a[i] == '--cols':
            cols = int(a[i + 1]); i += 2
        elif a[i] == '--rows':
            rows = int(a[i + 1]); i += 2
        elif a[i] == '--page':
            page = int(a[i + 1]); i += 2
        else:
            pats.append(a[i]); i += 1
    files = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(STILLS, p))):
            if f not in files:
                files.append(f)
    per = cols * rows
    sel = files[page * per:(page + 1) * per]
    tw = 1920 // cols
    th = int(tw * 9 / 16)
    sheet = Image.new('RGB', (cols * tw, rows * th), (10, 10, 12))
    d = ImageDraw.Draw(sheet)
    lines = []
    for k, f in enumerate(sel):
        try:
            im = Image.open(f).convert('RGB').resize((tw - 4, th - 4), Image.BILINEAR)
        except Exception:
            continue
        x, y = (k % cols) * tw, (k // cols) * th
        sheet.paste(im, (x + 2, y + 2))
        n = page * per + k
        label = '%d  %s' % (n, os.path.relpath(f, STILLS).replace('world/', ''))
        d.rectangle([x + 2, y + 2, x + 2 + 7 * len(label) + 6, y + 18], fill=(0, 0, 0))
        d.text((x + 5, y + 4), label, fill=(255, 235, 80))
        lines.append('%d\t%s' % (n, os.path.relpath(f, STILLS)))
    sheet.save(out, quality=88)
    open(os.path.splitext(out)[0] + '.txt', 'w').write('\n'.join(lines) + '\n')
    print('%d fotos en total · página %d de %d · %s' % (len(files), page, max(0, (len(files) - 1) // per), out))


if __name__ == '__main__':
    main()
