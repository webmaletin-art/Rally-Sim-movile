#!/usr/bin/env python3
"""Motor de montaje del tráiler: arma cada cuadro del video a partir de las fotos Full HD que saca el director (godot/tests/trailer/director.gd).
Todo es en código (PIL + numpy), sin editor de video: movimientos de cámara sobre las fotos (zoom, paneo, giro), golpes de zoom a ritmo, destellos, sacudida,
aberración cromática, estela de velocidad, corrección de color de cine, brillo (bloom), viñeta, grano y textos animados.

Una «toma» (Clip) dice: desde qué segundo hasta cuál, qué foto(s) muestra y con qué movimiento. El tiempo del cuadro lo decide quien arma la lista (make_trailer.py),
que corta a ritmo con el mapa de la canción (music_map.py)."""
import math
import os
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fonts')


# ───────────────────────── utilidades ─────────────────────────
def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def smooth(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ease_out(x, p=3.0):
    return 1.0 - (1.0 - clamp(x)) ** p


def ease_in(x, p=3.0):
    return clamp(x) ** p


def ease_io(x):
    x = clamp(x)
    return 0.5 - 0.5 * math.cos(math.pi * x)


EASES = {'lin': lambda x: clamp(x), 'io': ease_io, 'out': ease_out, 'in': ease_in, 'smooth': smooth}


@lru_cache(maxsize=64)
def font(name, size):
    path = os.path.join(FONTS, {'anton': 'anton-latin-400-normal.woff', 'bebas': 'bebas-neue-latin-400-normal.woff', 'russo': 'russo-one-latin-400-normal.woff'}[name])
    return ImageFont.truetype(path, int(size))


_IMG_CACHE = {}


def load_img(path, size=(W, H)):
    """Foto en el tamaño del video, con caché chico (las tomas largas la piden en cada cuadro)."""
    key = (path, size)
    im = _IMG_CACHE.get(key)
    if im is None:
        im = Image.open(path).convert('RGB')
        if im.size != size:
            im = im.resize(size, Image.LANCZOS)
        if len(_IMG_CACHE) > 48:
            _IMG_CACHE.pop(next(iter(_IMG_CACHE)))
        _IMG_CACHE[key] = im
    return im


# ───────────────────────── movimiento de cámara sobre una foto ─────────────────────────
def camera_move(im, z, cx, cy, rot=0.0, out=(W, H), resample=Image.BICUBIC):
    """Recorte de la foto con zoom z (1 = entera), centro (cx, cy) en fracciones 0..1 y giro rot (grados), devuelto en el tamaño de salida."""
    w, h = im.size
    ow, oh = out
    sw = w / z
    sh = h / z
    # esquina del recorte; se mantiene dentro de la foto salvo que gire
    x0 = cx * w - sw / 2
    y0 = cy * h - sh / 2
    if abs(rot) < 1e-4:
        x0 = clamp(x0, 0, w - sw)
        y0 = clamp(y0, 0, h - sh)
        return im.transform(out, Image.EXTENT, (x0, y0, x0 + sw, y0 + sh), resample)
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    k = sw / ow
    # mapa de salida → entrada: gira alrededor del centro del recorte
    ccx, ccy = cx * w, cy * h
    data = (ca * k, -sa * k, ccx - (ca * k * ow / 2 - sa * k * oh / 2) * 1.0 - 0.0, sa * k, ca * k, ccy - (sa * k * ow / 2 + ca * k * oh / 2))
    return im.transform(out, Image.AFFINE, data, resample)


# ───────────────────────── efectos de imagen (sobre arreglos float32 0..1) ─────────────────────────
def to_arr(im):
    return np.asarray(im, dtype=np.float32) / 255.0


def to_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8))


def blur_arr(a, radius):
    """Desenfoque gaussiano rápido (por PIL, en baja resolución cuando el radio es grande)."""
    im = to_img(a)
    if radius > 8:
        s = max(2, int(radius / 4))
        small = im.resize((im.width // s, im.height // s), Image.BILINEAR).filter(ImageFilter.GaussianBlur(radius / s))
        return to_arr(small.resize(im.size, Image.BILINEAR))
    return to_arr(im.filter(ImageFilter.GaussianBlur(radius)))


_VIG = {}


def vignette_mask(strength=0.35):
    key = round(strength, 2)
    if key not in _VIG:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / 1.41
        _VIG[key] = (1.0 - strength * np.clip(r, 0, 1) ** 2.2)[:, :, None].astype(np.float32)
    return _VIG[key]


_RNG = np.random.default_rng(1234)


def grade(a, contrast=1.10, sat=1.12, warm=0.0, teal=0.0, gamma=1.0, lift=0.0):
    """Corrección de color de cine: curva S, saturación y tinte (cálido en luces, verdoso-azulado en sombras)."""
    a = np.clip(a, 0, 1)
    if gamma != 1.0:
        a = a ** gamma
    # curva S suave
    a = a + (a - 0.5) * (contrast - 1.0) * (1.0 - np.abs(a - 0.5) * 1.6)
    lum = (a[:, :, 0] * 0.299 + a[:, :, 1] * 0.587 + a[:, :, 2] * 0.114)[:, :, None]
    a = lum + (a - lum) * sat
    if warm or teal:
        hi = np.clip(lum[:, :, 0] * 1.4 - 0.4, 0, 1)
        lo = np.clip(0.6 - lum[:, :, 0] * 1.4, 0, 1)
        a[:, :, 0] += warm * hi * 0.10 - teal * lo * 0.04
        a[:, :, 1] += warm * hi * 0.02 + teal * lo * 0.03
        a[:, :, 2] += -warm * hi * 0.07 + teal * lo * 0.08
    if lift:
        a = a * (1.0 - lift) + lift
    return np.clip(a, 0, 1)


def bloom(a, amount=0.35, threshold=0.72, radius=36):
    if amount <= 0:
        return a
    hi = np.clip((a - threshold) / (1.0 - threshold), 0, 1)
    return a + blur_arr(hi, radius) * amount + blur_arr(hi, radius * 0.35) * amount * 0.5


def chroma(a, shift):
    """Aberración cromática: separa el rojo y el azul en horizontal (shift en píxeles)."""
    s = int(round(shift))
    if s == 0:
        return a
    out = a.copy()
    out[:, :, 0] = np.roll(a[:, :, 0], s, axis=1)
    out[:, :, 2] = np.roll(a[:, :, 2], -s, axis=1)
    return out


def radial_blur(im, amount, center=(0.5, 0.5), steps=10):
    """Desenfoque «de velocidad» desde el centro: promedio de copias ampliadas."""
    if amount <= 0.002:
        return im
    acc = np.zeros((H, W, 3), np.float32)
    cx, cy = center
    for i in range(steps):
        z = 1.0 + amount * i / (steps - 1)
        acc += to_arr(camera_move(im, z, cx, cy, 0.0, resample=Image.BILINEAR))
    return to_img(acc / steps)


def motion_blur_h(im, px, steps=9):
    """Desenfoque de paneo horizontal (promedio de copias corridas)."""
    if px < 1.5:
        return im
    acc = np.zeros((H, W, 3), np.float32)
    base = to_arr(im)
    for i in range(steps):
        o = int(round((i / (steps - 1) - 0.5) * px))
        acc += np.roll(base, o, axis=1)
    return to_img(acc / steps)


def grain(a, amount=0.035):
    n = _RNG.normal(0.0, amount, (H // 2, W // 2, 1)).astype(np.float32)
    n = np.repeat(np.repeat(n, 2, axis=0), 2, axis=1)
    return a + n


def additive_flash(a, v, color=(1.0, 1.0, 1.0)):
    if v <= 0.001:
        return a
    return a * (1 - v) + np.array(color, np.float32)[None, None, :] * v


# ───────────────────────── textos ─────────────────────────
def text_size(txt, f, spacing=0):
    d = ImageDraw.Draw(Image.new('L', (4, 4)))
    b = d.textbbox((0, 0), txt, font=f)
    return b[2] - b[0] + spacing * max(0, len(txt) - 1), b[3] - b[1]


def draw_text_spaced(d, xy, txt, f, fill, spacing=0, anchor='la'):
    if spacing == 0:
        d.text(xy, txt, font=f, fill=fill, anchor=anchor)
        return
    x, y = xy
    total, _ = text_size(txt, f, spacing)
    if anchor[0] == 'm':
        x -= total / 2
    elif anchor[0] == 'r':
        x -= total
    for ch in txt:
        d.text((x, y), ch, font=f, fill=fill, anchor='l' + anchor[1])
        x += d.textlength(ch, font=f) + spacing


def shear_layer(layer, shear, cy):
    """Inclina una capa RGBA (cursiva) alrededor de la altura cy."""
    if abs(shear) < 1e-4:
        return layer
    return layer.transform(layer.size, Image.AFFINE, (1, shear, -shear * cy, 0, 1, 0), Image.BICUBIC)


def _blur_local(layer, radius):
    """Desenfoque gaussiano de una capa RGBA, sólo en la zona donde hay algo (el texto ocupa poco: sobre el cuadro entero era lo más lento del montaje)."""
    bb = layer.getbbox()
    if bb is None:
        return layer
    m = int(radius * 3) + 2
    x0, y0 = max(0, bb[0] - m), max(0, bb[1] - m)
    x1, y1 = min(layer.width, bb[2] + m), min(layer.height, bb[3] + m)
    out = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    out.paste(layer.crop((x0, y0, x1, y1)).filter(ImageFilter.GaussianBlur(radius)), (x0, y0))
    return out


def _union_composite(dst, src):
    """alpha_composite de src sobre dst, sólo en el rectángulo donde src tiene algo."""
    bb = src.getbbox()
    if bb is None:
        return dst
    dst.alpha_composite(src.crop(bb), (bb[0], bb[1]))
    return dst


def text_layer(lines, size=(W, H)):
    """lines: [{txt, font, size, pos (fracción x,y del centro), color, spacing, alpha, scale, shadow, glow, anchor, italic}] → imagen RGBA para mezclar encima."""
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    glow_total = Image.new('RGBA', size, (0, 0, 0, 0))
    for ln in lines:
        f = font(ln.get('font', 'anton'), ln.get('size', 120) * ln.get('scale', 1.0))
        col = ln.get('color', (255, 255, 255))
        al = int(255 * clamp(ln.get('alpha', 1.0)))
        if al <= 0:
            continue
        px, py = ln.get('pos', (0.5, 0.5))
        pos = (px * size[0], py * size[1])
        anchor = ln.get('anchor', 'mm')
        sp = ln.get('spacing', 0) * ln.get('scale', 1.0)
        sh_k = ln.get('italic', 0.0)
        one = Image.new('RGBA', size, (0, 0, 0, 0))
        if ln.get('shadow', True):
            shd = Image.new('RGBA', size, (0, 0, 0, 0))
            draw_text_spaced(ImageDraw.Draw(shd), (pos[0] + 4, pos[1] + 6), ln['txt'], f, (0, 0, 0, int(al * 0.55)), sp, anchor)
            _union_composite(one, _blur_local(shear_layer(shd, sh_k, pos[1]), 8))
        top = Image.new('RGBA', size, (0, 0, 0, 0))
        draw_text_spaced(ImageDraw.Draw(top), pos, ln['txt'], f, tuple(col) + (al,), sp, anchor)
        top = shear_layer(top, sh_k, pos[1])
        if ln.get('glow'):
            gc = ln.get('glow_color', (255, 130, 30))
            gl = Image.new('RGBA', size, (0, 0, 0, 0))
            draw_text_spaced(ImageDraw.Draw(gl), pos, ln['txt'], f, tuple(gc) + (int(al * 0.9),), sp, anchor)
            _union_composite(glow_total, _blur_local(shear_layer(gl, sh_k, pos[1]), ln.get('glow', 18)))
        _union_composite(one, top)
        _union_composite(out, one)
    return _union_composite(glow_total, out)


def stripes_layer(k, size=(W, H), angle=-18.0, bands=((0.0, 150, (255, 122, 26)), (210, 54, (235, 238, 244)), (330, 110, (255, 122, 26)))):
    """Franjas diagonales de carrera (como el gráfico de la tienda) que entran deslizando; k = 0..1 (progreso de la entrada)."""
    lay = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    t = math.tan(math.radians(angle))
    slide = (1.0 - ease_out(k, 3.0)) * size[0] * 1.2
    for off, width, col in bands:
        x0 = size[0] * 0.18 + off - slide
        # paralelogramo de borde a borde (diagonal)
        pts = [(x0 + (0 - size[1] / 2) * t, 0), (x0 + width + (0 - size[1] / 2) * t, 0), (x0 + width + (size[1] - size[1] / 2) * t, size[1]), (x0 + (size[1] - size[1] / 2) * t, size[1])]
        d.polygon(pts, fill=tuple(col) + (int(235 * clamp(k * 4.0)),))
    return lay


def overlay(a, layer):
    """Mezcla una capa RGBA (PIL) sobre un arreglo float, sólo donde la capa tiene algo."""
    bb = layer.getbbox()
    if bb is None:
        return a
    x0, y0, x1, y1 = bb
    la = np.asarray(layer.crop(bb), dtype=np.float32) / 255.0
    al = la[:, :, 3:4]
    a = a.copy() if not a.flags.writeable else a
    a[y0:y1, x0:x1] = a[y0:y1, x0:x1] * (1 - al) + la[:, :, :3] * al
    return a


# ───────────────────────── tomas ─────────────────────────
class Clip:
    """Una toma de t0 a t1 (segundos del video). kind: 'still' (una foto con movimiento), 'seq' (varias fotos una tras otra), 'color' (fondo liso), 'black'."""

    def __init__(self, t0, t1, kind='still', src=None, **kw):
        self.t0, self.t1, self.kind, self.src = t0, t1, kind, src
        self.z = kw.get('z', (1.0, 1.08))  # zoom inicial → final
        self.pan = kw.get('pan', ((0.5, 0.5), (0.5, 0.5)))  # centro inicial → final
        self.rot = kw.get('rot', (0.0, 0.0))
        self.ease = kw.get('ease', 'io')
        self.punch = kw.get('punch', 0.0)  # golpe de zoom al empezar (fracción)
        self.punch_len = kw.get('punch_len', 0.25)
        self.shake = kw.get('shake', 0.0)  # píxeles al empezar, decae
        self.flash = kw.get('flash', 0.0)  # destello blanco al empezar
        self.flash_color = kw.get('flash_color', (1.0, 1.0, 1.0))
        self.chroma = kw.get('chroma', 0.0)  # aberración al empezar (decae)
        self.blur_in = kw.get('blur_in', 0.0)  # desenfoque de velocidad al empezar (decae)
        self.blur_dir = kw.get('blur_dir', 'radial')
        self.fade_in = kw.get('fade_in', 0.0)
        self.fade_out = kw.get('fade_out', 0.0)
        self.dim = kw.get('dim', 1.0)
        self.texts = kw.get('texts', [])  # [{...text_layer..., t0, t1, anim}]
        self.grade = kw.get('grade', {})
        self.seq_times = kw.get('seq_times')  # para 'seq': instante (relativo) de cada foto; si no, parejo
        self.bg = kw.get('bg', (0.0, 0.0, 0.0))
        self.speed = kw.get('speed', 0.0)  # estela de velocidad continua (0..1)
        self.pulse = kw.get('pulse', 0.0)  # latido de zoom a ritmo (fracción) — usa beats globales
        self.stamp = kw.get('stamp')  # nombre para el registro
        self.mirror = kw.get('mirror', False)
        self.seq_zoom = kw.get('seq_zoom', (1.0, 1.0))  # en 'seq': zoom de cada foto (inicio → fin de su tiempo en pantalla)
        self.seq_flash = kw.get('seq_flash', 0.0)  # en 'seq': destello al aparecer cada foto

    def active(self, t):
        return self.t0 <= t < self.t1

    def source_at(self, u):
        """Para 'seq': (cuál foto toca en el instante relativo u, su avance 0..1 dentro de su tiempo en pantalla, segundos desde que apareció)."""
        n = len(self.src)
        dur = self.t1 - self.t0
        if self.seq_times:
            ts = list(self.seq_times) + [dur]
            for i in range(n):
                if u < ts[i + 1] or i == n - 1:
                    d = max(1e-6, ts[i + 1] - ts[i])
                    return i, clamp((u - ts[i]) / d), max(0.0, u - ts[i])
        i = min(n - 1, int(u / dur * n))
        d = dur / n
        return i, clamp((u - i * d) / d), max(0.0, u - i * d)


class Renderer:
    def __init__(self, clips, beats, fps=30, global_grade=None, grain_amt=0.03, vignette=0.32, bloom_amt=0.28, bloom_thr=0.72, cache_dir=None, overlays=None):
        self.clips = sorted(clips, key=lambda c: (c.t0, c.t1))
        self.beats = np.asarray(beats, dtype=np.float64)
        self.fps = fps
        self.gg = dict(contrast=1.12, sat=1.12, warm=0.5, teal=0.5)
        if global_grade:
            self.gg.update(global_grade)
        self.grain_amt = grain_amt
        self.vig = vignette
        self.bloom_amt = bloom_amt
        self.bloom_thr = bloom_thr
        self.overlays = overlays or []  # funciones f(arreglo, t) → arreglo (por ejemplo la barra de progreso)

    def beat_phase(self, t):
        """Distancia (en golpes, 0..1) desde el último golpe, y cuánto pasó en segundos."""
        i = int(np.searchsorted(self.beats, t, side='right')) - 1
        if i < 0 or i >= len(self.beats) - 1:
            return 1.0, 9.0
        d = t - self.beats[i]
        return d / (self.beats[i + 1] - self.beats[i]), d

    def clips_at(self, t):
        return [c for c in self.clips if c.active(t)]

    def render_clip(self, c, t):
        u = t - c.t0
        dur = max(1e-6, c.t1 - c.t0)
        k = u / dur
        if c.kind == 'black':
            return Image.new('RGB', (W, H), (0, 0, 0))
        if c.kind == 'color':
            return Image.new('RGB', (W, H), tuple(int(v * 255) for v in c.bg))
        if c.kind == 'seq':
            i, kk, _iu = c.source_at(u)
            path = c.src[i]
            e = kk
            z = lerp(c.seq_zoom[0], c.seq_zoom[1], e)
            base = load_img(path)
            im = camera_move(base, z * (1.0 + (c.punch * ease_out(1 - clamp(kk / max(1e-3, c.punch_len))) if c.punch else 0.0)), 0.5, 0.5)
            if c.mirror and (i % 2):
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            return im
        e = EASES[c.ease](k)
        z = lerp(c.z[0], c.z[1], e)
        cx = lerp(c.pan[0][0], c.pan[1][0], e)
        cy = lerp(c.pan[0][1], c.pan[1][1], e)
        rot = lerp(c.rot[0], c.rot[1], e)
        if c.punch:
            z *= 1.0 + c.punch * ease_out(1.0 - clamp(u / c.punch_len))
        if c.pulse:
            ph, _ = self.beat_phase(t)
            z *= 1.0 + c.pulse * ease_out(1.0 - clamp(ph / 0.6), 2.0)
        im = load_img(c.src if isinstance(c.src, str) else c.src[0])
        return camera_move(im, z, cx, cy, rot)

    def frame(self, t):
        cl = self.clips_at(t)
        if not cl:
            return np.zeros((H, W, 3), np.float32)
        arr = None
        first = True
        for c in cl:
            im = self.render_clip(c, t)
            u = t - c.t0
            # efectos de la toma sobre la imagen
            if c.blur_in > 0:
                amt = c.blur_in * ease_out(1.0 - clamp(u / 0.28), 2.0)
                if c.blur_dir == 'radial':
                    im = radial_blur(im, amt * 0.22)
                else:
                    im = motion_blur_h(im, amt * 120)
            if c.speed > 0:
                im = radial_blur(im, c.speed * 0.10, steps=8)
            a = to_arr(im)
            g = dict(self.gg)
            g.update(c.grade)
            a = grade(a, **g)
            if c.dim != 1.0:
                a = a * c.dim
            # entrada/salida en fundido (con la toma de abajo)
            alpha = 1.0
            if c.fade_in > 0:
                alpha *= smooth(u / c.fade_in)
            if c.fade_out > 0:
                alpha *= smooth((c.t1 - t) / c.fade_out)
            if arr is None:
                arr = a * alpha if (c.fade_in > 0 or c.fade_out > 0) else a
            else:
                arr = arr * (1 - alpha) + a * alpha
            first = False
        c0 = cl[-1]
        u = t - c0.t0
        # destello y aberración al empezar la toma (y en cada foto de una secuencia)
        if c0.kind == 'seq' and c0.seq_flash > 0:
            _i, _k, iu = c0.source_at(u)
            arr = additive_flash(arr, c0.seq_flash * ease_out(1.0 - clamp(iu / 0.09), 2.0), c0.flash_color)
        if c0.flash > 0:
            arr = additive_flash(arr, c0.flash * ease_out(1.0 - clamp(u / 0.22), 2.0), c0.flash_color)
        if c0.chroma > 0:
            arr = chroma(arr, c0.chroma * ease_out(1.0 - clamp(u / 0.3), 2.0))
        if c0.shake > 0:
            s = c0.shake * ease_out(1.0 - clamp(u / 0.35), 2.0)
            dx = int(round(math.sin(u * 83.0) * s))
            dy = int(round(math.cos(u * 71.0) * s * 0.7))
            arr = np.roll(np.roll(arr, dx, axis=1), dy, axis=0)
        # brillo, viñeta, grano
        arr = bloom(arr, self.bloom_amt, self.bloom_thr)
        arr = arr * vignette_mask(self.vig)
        for f in self.overlays:
            arr = f(arr, t)
        # textos de todas las tomas activas
        for c in cl:
            lines = text_lines_at(c, t)
            if lines:
                arr = overlay(arr, text_layer(lines))
        arr = grain(arr, self.grain_amt)
        return np.clip(arr, 0, 1)


def lerp(a, b, k):
    return a + (b - a) * k


def text_lines_at(c, t):
    """Resuelve la animación de cada texto de la toma en el instante t."""
    out = []
    for tx in c.texts:
        a0 = c.t0 + tx.get('t0', 0.0)
        a1 = c.t0 + tx.get('t1', c.t1 - c.t0)
        if not (a0 <= t <= a1):
            continue
        u = t - a0
        d = a1 - a0
        ln = dict(tx)
        anim = tx.get('anim', 'fade')
        al = 1.0
        sc = 1.0
        pos = list(tx.get('pos', (0.5, 0.5)))
        fin = tx.get('fin', 0.25)
        fout = tx.get('fout', 0.25)
        if anim == 'fade':
            al = smooth(u / max(1e-3, fin)) * smooth((d - u) / max(1e-3, fout))
        elif anim == 'slam':  # entra grande y se asienta (golpe de título)
            k = clamp(u / max(1e-3, fin))
            sc = 1.0 + 0.55 * (1.0 - ease_out(k, 4.0))
            al = clamp(k * 3.0) * smooth((d - u) / max(1e-3, fout))
        elif anim == 'rise':
            k = clamp(u / max(1e-3, fin))
            pos[1] += 0.04 * (1.0 - ease_out(k))
            al = k * smooth((d - u) / max(1e-3, fout))
        elif anim == 'slide':
            k = clamp(u / max(1e-3, fin))
            pos[0] -= 0.06 * (1.0 - ease_out(k, 4.0))
            al = k * smooth((d - u) / max(1e-3, fout))
        elif anim == 'cut':
            al = 1.0
        elif anim == 'type':  # se escribe letra por letra
            n = int(len(tx['txt']) * clamp(u / max(1e-3, fin)))
            ln['txt'] = tx['txt'][:n]
            al = smooth((d - u) / max(1e-3, fout))
        ln['alpha'] = al * tx.get('alpha', 1.0)
        ln['scale'] = sc * tx.get('scale', 1.0)
        ln['pos'] = tuple(pos)
        out.append(ln)
    return out
