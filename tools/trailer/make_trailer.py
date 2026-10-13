#!/usr/bin/env python3
"""Arma el tráiler de Dream Racing: lista de tomas cortada a ritmo con la canción (mapa de music_map.py), render en paralelo con compositor.py, sonidos (sfx.py) y mezcla final con ffmpeg.
Uso:
  python3 tools/trailer/make_trailer.py sheet  [--lang es] [--times 0,5,10,...] salida.png   → fotogramas sueltos en una hoja (para mirar el montaje sin renderizar todo)
  python3 tools/trailer/make_trailer.py render [--lang es] [--workers 4] [--t0 0 --t1 30] salida.mp4
  python3 tools/trailer/make_trailer.py edl                                                    → lista de tomas (qué foto en qué segundo)
Las fotos las saca godot/tests/trailer/director.gd (ver docs/TRAILER.md); acá sólo se eligen y se cortan."""
import glob
import json
import math
import os
import subprocess
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compositor as C  # noqa: E402
import cars_info  # noqa: E402
from compositor import Clip, W, H  # noqa: E402

STILLS = os.environ.get('TRAILER_STILLS', '/tmp/trailer/stills')
MUSIC_MAP = os.environ.get('TRAILER_MAP', '/tmp/music/motor_map.json')
MUSIC_SRC = os.environ.get('TRAILER_MUSIC', '/tmp/music/src/Motor_de_Suenos.mp3')
FPS = 30
P = 0.43396  # un golpe (s)
PH = 0.12  # fase de la grilla (s)
BAR = 4 * P
DUR = 186.3  # la canción dura 187,2 s pero termina a los 185,3: los últimos segundos son silencio

ORANGE = (255, 122, 26)
WHITE = (245, 246, 250)
GOLD = (255, 205, 90)


def bar(b):
    return PH + b * BAR


def beat(k):
    return PH + k * P


def S(*parts):
    return os.path.join(STILLS, *parts)


_PLACEHOLDER = '/tmp/trailer/placeholder.jpg'


def placeholder():
    if not os.path.exists(_PLACEHOLDER):
        os.makedirs(os.path.dirname(_PLACEHOLDER), exist_ok=True)
        yy, xx = np.mgrid[0:H, 0:W]
        a = np.stack([20 + 30 * xx / W, 24 + 20 * yy / H, 40 + 40 * (1 - yy / H)], axis=2).astype(np.uint8)
        C.Image.fromarray(a).save(_PLACEHOLDER)
    return _PLACEHOLDER


def pick(*patterns):
    """Primera foto que exista entre los patrones (con comodines); si no hay ninguna, una imagen de relleno."""
    for p in patterns:
        fs = sorted(glob.glob(S(p)))
        if fs:
            return fs[0]
    return placeholder()


def pick_all(pattern):
    return sorted(glob.glob(S(pattern)))


def T(txt, t0=0.0, t1=None, **kw):
    d = {'txt': txt, 't0': t0}
    if t1 is not None:
        d['t1'] = t1
    d.update(kw)
    return d


def logo_texts(t0=0.0, t1=None, sub=None, big=1.0, y=0.5, anim='slam'):
    """El logo DREAM / RACING (cursiva, blanco y naranja) con subtítulo opcional."""
    out = [T('DREAM', t0, t1, font='anton', size=250 * big, pos=(0.5, y - 0.105), italic=-0.18, anim=anim, fin=0.28, fout=0.3, glow=8, glow_color=(255, 255, 255)),
           T('RACING', t0 + 0.06, t1, font='anton', size=250 * big, pos=(0.5, y + 0.105), color=ORANGE, italic=-0.18, anim=anim, fin=0.28, fout=0.3, glow=26)]
    if sub:
        out.append(T(sub, t0 + 0.5, t1, font='bebas', size=64 * big, pos=(0.5, y + 0.27), color=WHITE, spacing=14, anim='fade', fin=0.3, fout=0.3))
    return out


# ───────────────────────── la lista de tomas ─────────────────────────
def build(lang='es'):
    clips = []
    sfx = []  # (t, nombre, ganancia)
    overlays = []
    es = lang == 'es'

    def add(c, sound=None, gain=1.0):
        clips.append(c)
        if sound:
            sfx.append((c.t0, sound, gain))
        return c

    ids = cars_info.ORDER

    # ── A · amanecer (compases 0 a 2: la intro tranquila) ──
    add(Clip(0.0, bar(2), 'still', pick('world/dream_a*', 'studio/hyper/hero_hyper.jpg'), z=(1.0, 1.10), pan=((0.5, 0.52), (0.5, 0.48)), ease='io', fade_in=1.2, grade={'sat': 1.05},
             texts=[T('SRGAMESTUDIO', 0.9, bar(2) - 0.1, font='bebas', size=92, pos=(0.5, 0.45), spacing=26, anim='fade', fin=0.9, fout=0.5),
                    T('PRESENTA' if es else 'PRESENTS', 1.5, bar(2) - 0.1, font='bebas', size=44, pos=(0.5, 0.545), spacing=18, color=(255, 190, 120), anim='fade', fin=0.9, fout=0.5)]))
    add(Clip(bar(2), bar(3), 'still', pick('world/anillo_a*', 'studio/veltor_gtr/hero_veltor_gtr.jpg'), z=(1.0, 1.08), pan=((0.45, 0.5), (0.55, 0.5)), ease='io', fade_in=0.35,
             texts=[T('UN MUNDO ENTERO' if es else 'A WHOLE WORLD', 0.15, BAR - 0.1, font='anton', size=110, pos=(0.5, 0.5), spacing=10, anim='rise', fin=0.5, fout=0.35)]), 'whoosh', 0.6)
    # ── B · subida (compases 3 a 5): cortes cada vez más rápidos ──
    detail = [pick('studio/%s/%s_%s.jpg' % (c, k, c)) for c, k in [('gt3', 'wheel'), ('kodiak', 'wheel'), ('hyper', 'wheel'), ('rally80', 'wheel')]]
    for i, f in enumerate(detail):
        add(Clip(bar(3) + i * P, bar(3) + (i + 1) * P, 'still', f, z=(1.0, 1.18), pan=((0.5, 0.55), (0.5, 0.5)), punch=0.06, punch_len=0.22, flash=0.25, shake=10, grade={'contrast': 1.2}), 'tick' if i else 'riser', 0.8)
    nose = [pick('studio/%s/nose_%s.jpg' % (c, c)) for c in ['gt3', 'hyper', 'veltor_gtr', 'moust', 'muscle', 'rally80', 'kodiak', 'genesis']]
    for i, f in enumerate(nose):
        add(Clip(bar(4) + i * P / 2, bar(4) + (i + 1) * P / 2, 'still', f, z=(1.0, 1.12), pan=((0.5, 0.5), (0.5, 0.5)), punch=0.05, punch_len=0.15, flash=0.2, chroma=6))
    add(Clip(bar(5), bar(5) + 0.35, 'still', pick('studio/hyper/front_hyper.jpg'), z=(1.0, 1.1), flash=0.3))
    add(Clip(bar(5) + 0.35, 9.15, 'still', pick('studio/hyper/hero_hyper.jpg'), z=(1.1, 1.2), ease='out'))
    add(Clip(9.15, bar(6), 'black'))  # el silencio de la canción
    # ── C · el golpe: título y los 26 autos ──
    add(Clip(bar(6), bar(7), 'still', pick('studio/hyper/hero_hyper.jpg'), z=(1.12, 1.0), flash=1.0, shake=26, chroma=16, punch=0.08, punch_len=0.35,
             texts=logo_texts(0.0, BAR - 0.05, sub='RALLY · DRIFT · MUNDO ABIERTO' if es else 'RALLY · DRIFT · OPEN WORLD')), 'impact', 1.0)
    t = bar(7)
    step = P / 2
    for n, cid in enumerate(ids):
        f = pick('studio/%s/line_%s.jpg' % (cid, cid))
        info = cars_info.ALL[cid]
        add(Clip(t, t + step, 'still', f, z=(1.02, 1.08), punch=0.04, punch_len=0.12, flash=0.18, chroma=4,
                 texts=[T('%02d' % (n + 1), 0.0, step, font='russo', size=120, pos=(0.09, 0.88), color=ORANGE, anim='cut', shadow=True),
                        T('/ 26', 0.0, step, font='bebas', size=52, pos=(0.165, 0.905), color=WHITE, anim='cut'),
                        T(info['name'].upper(), 0.0, step, font='bebas', size=70, pos=(0.5, 0.92), color=WHITE, spacing=8, anim='cut')]))
        t += step
    # (el tramo de abajo se completa con la vuelta de 36 cuadros)
    turn = pick_all('studio/turn_hyper/turn_*.jpg') or [pick('studio/hyper/hero_hyper.jpg')]
    add(Clip(t, bar(12), 'seq', turn, seq_flash=0.10, seq_zoom=(1.02, 1.10)))
    return {'clips': clips, 'sfx': sfx, 'overlays': overlays, 'duration': DUR}


# ───────────────────────── render ─────────────────────────
def renderer(tl):
    beats = json.load(open(MUSIC_MAP))['beats'] if os.path.exists(MUSIC_MAP) else [beat(k) for k in range(430)]
    return C.Renderer(tl['clips'], beats, fps=FPS, overlays=tl['overlays'], grain_amt=0.022)


def to_bytes(a):
    return (np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8).tobytes()


def render_range(args):
    tl, f0, f1, out, crf = args
    r = renderer(tl)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H), '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium',
           '-crf', str(crf), '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    t0 = time.time()
    for f in range(f0, f1):
        a = r.frame(f / FPS)
        p.stdin.write(to_bytes(a))
        if (f - f0) % 60 == 0:
            print('  %s: cuadro %d/%d (%.1f s)' % (os.path.basename(out), f - f0, f1 - f0, time.time() - t0), flush=True)
    p.stdin.close()
    p.wait()
    return out


def cmd_sheet(argv):
    lang = 'es'
    times = None
    out = None
    i = 0
    while i < len(argv):
        if argv[i] == '--lang':
            lang = argv[i + 1]; i += 2
        elif argv[i] == '--times':
            times = [float(x) for x in argv[i + 1].split(',')]; i += 2
        else:
            out = argv[i]; i += 1
    tl = build(lang)
    r = renderer(tl)
    if times is None:
        times = [k * 0.5 for k in range(int(tl['duration'] / 0.5))]
    cols = 4
    tw, th = 480, 270
    rows = (len(times) + cols - 1) // cols
    sheet = C.Image.new('RGB', (cols * tw, rows * th))
    d = C.ImageDraw.Draw(sheet)
    for i, t in enumerate(times):
        a = r.frame(t)
        im = C.to_img(a).resize((tw, th))
        sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
        d.rectangle([(i % cols) * tw, (i // cols) * th, (i % cols) * tw + 70, (i // cols) * th + 16], fill=(0, 0, 0))
        d.text(((i % cols) * tw + 4, (i // cols) * th + 2), '%.2fs' % t, fill=(255, 255, 0))
    sheet.save(out)
    print('hoja', sheet.size)


def cmd_edl(argv):
    tl = build('es')
    for c in sorted(tl['clips'], key=lambda c: c.t0):
        src = c.src if isinstance(c.src, str) else ('%d fotos' % len(c.src) if c.src else '')
        print('%7.2f–%7.2f  %-5s  %s' % (c.t0, c.t1, c.kind, os.path.relpath(src, STILLS) if isinstance(src, str) and src.startswith(STILLS) else src))


_TL = None


def _worker(a):
    f0, f1, out, crf = a
    return render_range((_TL, f0, f1, out, crf))


def cmd_render(argv):
    """Renderiza el video (sin sonido) en tramos en paralelo y los une."""
    global _TL
    lang, workers, t0, t1, crf, out = 'es', 4, 0.0, None, 16, None
    i = 0
    while i < len(argv):
        if argv[i] == '--lang':
            lang = argv[i + 1]; i += 2
        elif argv[i] == '--workers':
            workers = int(argv[i + 1]); i += 2
        elif argv[i] == '--t0':
            t0 = float(argv[i + 1]); i += 2
        elif argv[i] == '--t1':
            t1 = float(argv[i + 1]); i += 2
        elif argv[i] == '--crf':
            crf = int(argv[i + 1]); i += 2
        else:
            out = argv[i]; i += 1
    _TL = build(lang)
    t1 = _TL['duration'] if t1 is None else t1
    f0, f1 = int(round(t0 * FPS)), int(round(t1 * FPS))
    segdir = os.path.join(os.path.dirname(os.path.abspath(out)), 'seg_' + lang)
    os.makedirs(segdir, exist_ok=True)
    n = max(workers * 3, 1)
    bounds = [f0 + (f1 - f0) * k // n for k in range(n + 1)]
    jobs = [(bounds[k], bounds[k + 1], os.path.join(segdir, 'seg_%03d.mp4' % k), crf) for k in range(n) if bounds[k + 1] > bounds[k]]
    import multiprocessing as mp
    t_start = time.time()
    with mp.get_context('fork').Pool(workers) as pool:
        done = pool.map(_worker, jobs, chunksize=1)
    lst = os.path.join(segdir, 'list.txt')
    open(lst, 'w').write(''.join("file '%s'\n" % d for d in done))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', out], check=True)
    print('video listo: %s (%.0f s)' % (out, time.time() - t_start))


def cmd_audio(argv):
    """Canción + efectos de sonido → wav estéreo (con fundido de entrada y de salida), parejo a −14 LUFS."""
    import sfx as SFX
    lang = 'es'
    out = argv[-1]
    tl = build(lang)
    sr = SFX.SR
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', MUSIC_SRC, '-ac', '2', '-ar', str(sr), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    music = np.frombuffer(raw, dtype='<f4').reshape(-1, 2).copy()
    n = int(tl['duration'] * sr)
    mix = np.zeros((n + sr * 4, 2), np.float32)
    mix[:min(len(music), len(mix))] += music[:len(mix)] * 0.8
    gens = {'impact': SFX.impact, 'whoosh': SFX.whoosh, 'riser': SFX.riser, 'shutter': SFX.shutter, 'drop': SFX.drop, 'tick': SFX.tick}
    cache = {}
    for t, name, gain in tl['sfx']:
        key = name
        if key not in cache:
            cache[key] = gens[name]()
        SFX.place(mix, cache[key], t, gain * 0.9)
    mix = mix[:n]
    # fundidos
    fi = int(0.12 * sr)
    mix[:fi] *= np.linspace(0, 1, fi)[:, None]
    fo = int(2.2 * sr)
    mix[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 1.5
    tmp = out + '.raw.wav'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'f32le', '-ar', str(sr), '-ac', '2', '-i', '-', tmp], input=np.clip(mix, -1.5, 1.5).astype('<f4').tobytes(), check=True)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-af', 'loudnorm=I=-14:TP=-1.5:LRA=9', '-ar', '48000', '-ac', '2', out], check=True)
    os.remove(tmp)
    print('audio listo:', out)


def cmd_mux(argv):
    video, audio, out = argv
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', video, '-i', audio, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart', out], check=True)
    print('trailer listo:', out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]
    if cmd == 'sheet':
        cmd_sheet(sys.argv[2:])
    elif cmd == 'edl':
        cmd_edl(sys.argv[2:])
    elif cmd == 'render':
        cmd_render(sys.argv[2:])
    elif cmd == 'audio':
        cmd_audio(sys.argv[2:])
    elif cmd == 'mux':
        cmd_mux(sys.argv[2:])
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
