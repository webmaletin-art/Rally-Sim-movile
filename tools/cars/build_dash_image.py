#!/usr/bin/env python3
"""Tablero de IMAGEN de la cabina (pedido del dueño, 15/10/2026: «te paso un tablero PNG sin fondo… probamos los 3»).
De las 3 fotos que mandó se usa la de fondo gris (tablero + consola, sin jaula ni parantes): las otras dos traen la jaula, las puertas y el
techo (no encajan en cada auto) y una tiene el fondo «transparente» dibujado como cuadriculado (no es transparencia de verdad).
Quita el fondo con GrabCut (OpenCV), borra los restos de los parantes de las esquinas de arriba, recorta, la deja en 1024 de ancho
(memoria de video chica) y extiende el color debajo del alfa (sin bordes claros al filtrar).
Salida: godot/game/models/cabin/tablero_imagen.png (la usa game/car/cockpit.gd → _b_dash_image).
Uso: python3 tools/cars/build_dash_image.py FOTO.png   (necesita: pip install opencv-python-headless)"""
import os
import sys

import cv2
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "game", "models", "cabin", "tablero_imagen.png")
img = cv2.imread(sys.argv[1])
h, w = img.shape[:2]
# zonas (en la foto de 1870 × 841): probable tablero / fondo seguro / tablero seguro
mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
mask[40:560, 40:w - 40] = cv2.GC_PR_FGD
mask[540:h, 760:1110] = cv2.GC_PR_FGD
mask[0:30, 150:w - 150] = cv2.GC_BGD
mask[600:h, 0:700] = cv2.GC_BGD
mask[600:h, 1170:w] = cv2.GC_BGD
mask[:, :40] = cv2.GC_BGD
mask[:, w - 40:] = cv2.GC_BGD
mask[130:520, 120:w - 120] = cv2.GC_FGD
mask[570:820, 800:1060] = cv2.GC_FGD
bg = np.zeros((1, 65), np.float64)
fg = np.zeros((1, 65), np.float64)
cv2.grabCut(img, mask, None, bg, fg, 6, cv2.GC_INIT_WITH_MASK)
m = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
# la pieza más grande, sin agujeros
n, lab, st, _ = cv2.connectedComponentsWithStats(m)
m = np.where(lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA]), 255, 0).astype(np.uint8)
n2, lab2, st2, _ = cv2.connectedComponentsWithStats(255 - m)
for i in range(1, n2):
    x, y, ww, hh, _a = st2[i]
    if x > 0 and y > 0 and x + ww < w and y + hh < h:
        m[lab2 == i] = 255
m = cv2.GaussianBlur(m, (3, 3), 0)
a = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
a[:, :, 3] = m
ys, xs = np.where(m > 128)
a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
ah, aw = a.shape[:2]
a[0:110, 0:170, 3] = 0  # restos de los parantes
a[0:110, aw - 170:aw, 3] = 0
ys, xs = np.where(a[:, :, 3] > 128)
a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
H = int(round(a.shape[0] * 1024 / a.shape[1]))
b = cv2.resize(a, (1024, H), interpolation=cv2.INTER_AREA)
rgb = b[:, :, :3].copy()
dil = cv2.dilate(rgb, np.ones((5, 5), np.uint8))
rgb[b[:, :, 3] < 10] = dil[b[:, :, 3] < 10]
b[:, :, :3] = rgb
cv2.imwrite(OUT, b, [cv2.IMWRITE_PNG_COMPRESSION, 9])
print("listo:", OUT, b.shape)
