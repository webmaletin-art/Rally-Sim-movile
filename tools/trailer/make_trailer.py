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


# ───────────────────────── ayudas para armar la lista ─────────────────────────
def fx_move(i):
    """Movimiento de cámara distinto en cada corte (acercar, alejar, correr a un lado y al otro) para que no se sienta repetido."""
    z = [(1.0, 1.14), (1.14, 1.0), (1.04, 1.18), (1.17, 1.05)][i % 4]
    pan = [((0.44, 0.5), (0.56, 0.5)), ((0.56, 0.5), (0.44, 0.5)), ((0.5, 0.56), (0.5, 0.44)), ((0.5, 0.44), (0.5, 0.56))][(i // 2 + i) % 4]
    return z, pan


def cap(txt, t0=0.0, t1=None, x=0.07, y=0.9, size=86, color=WHITE, **kw):
    """Letrero al pie: corre desde la izquierda."""
    d = dict(font='bebas', size=size, pos=(x, y), color=color, spacing=7, anim='slide', fin=0.16, fout=0.12, anchor='lm')
    d.update(kw)
    return T(txt, t0, t1, **d)


def title_card(txt, sub=None, t0=0.0, t1=None, color=ORANGE, y=0.5, size=300):
    out = [T(txt, t0, t1, font='anton', size=size, pos=(0.5, y), color=color, italic=-0.18, anim='slam', fin=0.26, fout=0.25, glow=22)]
    if sub:
        out.append(T(sub, t0 + 0.35, t1, font='bebas', size=70, pos=(0.5, y + 0.19), color=WHITE, spacing=16, anim='fade', fin=0.3, fout=0.25))
    return out


def montage(add, t0, t1, files, per, cycle_from=0, caps=None, speed=0.0, blur=0.0, flash=0.16, shake_every=4, sound=None, grade=None):
    """Cortes de `per` segundos entre t0 y t1 que van pasando por `files`. caps: lista de letreros (uno por corte, o None)."""
    n = max(1, int(round((t1 - t0) / per)))
    dt = (t1 - t0) / n
    for i in range(n):
        f = files[(cycle_from + i) % len(files)]
        z, pan = fx_move(i + cycle_from)
        txts = []
        if caps:
            c = caps[i % len(caps)]
            if c:
                txts = [cap(c, 0.0, dt)]
        add(Clip(t0 + i * dt, t0 + (i + 1) * dt, 'still', f, z=z, pan=pan, ease='out', punch=0.05, punch_len=0.16, flash=flash if i % 2 == 0 else 0.0,
                 shake=9 if (shake_every and i % shake_every == 0) else 0.0, chroma=4 if i % 3 == 0 else 0.0, speed=speed, blur_in=blur, texts=txts, grade=grade or {}),
            sound if (sound and i % 4 == 0) else None, 0.45)


def files_of(*patterns):
    """Todas las fotos que existen para los patrones (en orden de patrón, sin repetir)."""
    out = []
    for p in patterns:
        for f in pick_all(p):
            if f not in out:
                out.append(f)
    return out or [placeholder()]


def interleave(*lists):
    """Mezcla listas fotos de a una (a, b, c, a, b, c…) para que los cortes seguidos no sean del mismo lugar."""
    out = []
    for i in range(max(len(l) for l in lists)):
        for l in lists:
            if i < len(l):
                out.append(l[i])
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
    L = (lambda a, b: a if es else b)  # texto en español / inglés

    # ── A · amanecer (compases 0 a 2: la intro tranquila) ──
    add(Clip(0.0, bar(2), 'still', pick('world/survey/dream/p03_b.jpg', 'world/survey/dream/p08_a.jpg', 'studio/hyper/hero_hyper.jpg'), z=(1.0, 1.10), pan=((0.5, 0.52), (0.5, 0.48)), ease='io', fade_in=1.2, grade={'sat': 1.05},
             texts=[T('SRGAMESTUDIO', 0.9, bar(2) - 0.1, font='bebas', size=92, pos=(0.5, 0.45), spacing=26, anim='fade', fin=0.9, fout=0.5),
                    T(L('PRESENTA', 'PRESENTS'), 1.5, bar(2) - 0.1, font='bebas', size=44, pos=(0.5, 0.545), spacing=18, color=(255, 190, 120), anim='fade', fin=0.9, fout=0.5)]))
    add(Clip(bar(2), bar(3), 'still', pick('world/survey/anillo/p13_a.jpg', 'world/scout/anillo/a_front.jpg', 'studio/veltor_gtr/hero_veltor_gtr.jpg'), z=(1.0, 1.08), pan=((0.45, 0.5), (0.55, 0.5)), ease='io', fade_in=0.35,
             texts=[T(L('UN MUNDO ENTERO', 'A WHOLE WORLD'), 0.15, BAR - 0.1, font='anton', size=110, pos=(0.5, 0.5), spacing=10, anim='rise', fin=0.5, fout=0.35)]), 'whoosh', 0.6)
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
             texts=logo_texts(0.0, BAR - 0.05, sub=L('RALLY · DRIFT · MUNDO ABIERTO', 'RALLY · DRIFT · OPEN WORLD'))), 'impact', 1.0)
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
    turn = pick_all('studio/turn_hyper/turn_*.jpg') or [pick('studio/hyper/hero_hyper.jpg')]
    add(Clip(t, bar(12), 'seq', turn, seq_flash=0.10, seq_zoom=(1.02, 1.10)))

    # ── D · RALLY (compases 12 a 24) ──
    fs = files_of('world/action/forest_sunset/*front_low.jpg', 'world/survey/forest_sunset/p*_a.jpg')
    fd = files_of('world/action/forest_day/*.jpg', 'world/survey/forest_day/p*_a.jpg')
    fr = files_of('world/action/forest_rain/*.jpg', 'world/scout/forest_rain/*.jpg')
    lk = files_of('world/action/lake_dusk/*.jpg', 'world/survey/lake_dusk/p*_a.jpg')
    qy = files_of('world/action/quarry_day/*.jpg', 'world/survey/quarry_day/p*_a.jpg', 'world/scout/quarry_sunset/*.jpg')
    mt = files_of('world/action/mountain_sunset/*.jpg', 'world/survey/mountain_sunset/p*_a.jpg', 'world/scout/mountain_sunset/*.jpg')
    ds = files_of('world/action/descent_day/*.jpg', 'world/scout/descent_day/*.jpg')
    add(Clip(bar(12), bar(13), 'still', fs[0], z=(1.0, 1.16), pan=((0.5, 0.55), (0.5, 0.5)), ease='out', flash=0.7, shake=18, chroma=10, punch=0.07, punch_len=0.3, speed=0.35,
             texts=title_card('RALLY', L('TIERRA · BARRO · LLUVIA · NOCHE', 'DIRT · MUD · RAIN · NIGHT'), 0.0, BAR - 0.05)), 'impact', 0.8)
    mix1 = interleave(fs, fd, lk, qy, mt, fr, ds)
    montage(add, bar(13), bar(17), mix1, P, speed=0.2, blur=0.5, sound='tick')
    for k, (word, files) in enumerate([(L('TIERRA', 'DIRT'), fd), (L('BARRO', 'MUD'), qy), (L('LLUVIA', 'RAIN'), fr), (L('ATARDECER', 'SUNSET'), interleave(fs, lk))]):
        montage(add, bar(17 + k), bar(18 + k), files, 2 * P, cycle_from=k, caps=[word], speed=0.15, blur=0.4)
    montage(add, bar(21), bar(24) - 0.45, interleave(mt, ds, fs, fr, lk, qy, fd), P / 2, speed=0.25, blur=0.6, flash=0.2)
    add(Clip(bar(24) - 0.45, bar(24), 'black'), 'riser', 0.5)

    # ── E · AVENTURA (compases 24 a 36) ──
    adv = {k: files_of('world/extra/adv_%s/*.jpg' % k) for k in ['girasoles', 'rio_bosque', 'tunel', 'cantera', 'lluvia', 'nieve', 'cumbre']}
    adv_all = interleave(*[adv[k] for k in ['girasoles', 'rio_bosque', 'tunel', 'cantera', 'lluvia', 'nieve', 'cumbre']])
    add(Clip(bar(24), bar(25), 'still', adv['girasoles'][0], z=(1.0, 1.14), pan=((0.5, 0.55), (0.5, 0.5)), ease='out', flash=0.7, shake=16, chroma=8, punch=0.07, punch_len=0.3, speed=0.2,
             texts=title_card(L('AVENTURA', 'ADVENTURE'), L('LA RUTA DE LOS SUEÑOS · 12 ETAPAS', 'THE ROAD OF DREAMS · 12 STAGES'), 0.0, BAR - 0.05, size=250)), 'impact', 0.8)
    stage_caps = [(L('CAMPOS DE GIRASOL', 'SUNFLOWER FIELDS'), 'girasoles'), (L('RÍO Y BOSQUE', 'RIVER AND FOREST'), 'rio_bosque'), (L('TÚNEL DEL CÓNDOR', 'CONDOR TUNNEL'), 'tunel'),
                  (L('CANTERA Y MINA', 'QUARRY AND MINE'), 'cantera'), (L('BOSQUE BAJO LA LLUVIA', 'FOREST IN THE RAIN'), 'lluvia'), (L('PASO NEVADO', 'SNOWY PASS'), 'nieve'), (L('LA CUMBRE', 'THE SUMMIT'), 'cumbre')]
    t = bar(25)
    seg = (bar(30) - bar(25)) / len(stage_caps)
    for k, (word, key) in enumerate(stage_caps):
        montage(add, t, t + seg, adv[key], seg / 3.0, cycle_from=0, caps=[word], speed=0.15, blur=0.4, sound='whoosh' if k == 0 else None)
        t += seg
    # rivales y jefes: pilotos con sus gestos
    pil_s = files_of('world/extra/pilots_hyper/*.jpg', 'world/extra/pilots_rally80/*.jpg', 'world/extra/pilots_gt3/*.jpg')
    pil_w = files_of('world/extra/pilots_world_forest_sunset/*.jpg', 'world/extra/pilots_world_lake_dusk/*.jpg', 'world/extra/pilots_world_dream/*.jpg')
    montage(add, bar(30), bar(33), interleave(adv_all, pil_w, pil_s), P, caps=[L('RIVALES', 'RIVALS'), None, L('JEFES', 'BOSSES'), None, L('EL LOBO BLANCO', 'THE WHITE WOLF'), None, L('LA SOMBRA', 'THE SHADOW'), None],
            speed=0.1, blur=0.4)
    ui_a = files_of('ui/adventure.png', 'ui/adv_stages.png', 'ui/adv_skills.png')
    montage(add, bar(33), bar(36), interleave(ui_a, adv_all), 1.5 * P, caps=[L('HABILIDADES', 'SKILLS'), None, L('TALLERES Y ESTACIONES', 'WORKSHOPS AND STATIONS'), None, L('TU RITMO', 'YOUR PACE'), None], flash=0.2)

    # ── F · DREAM CITY (compases 36 a 55) ──
    city = files_of('world/scoutw/plaza_sunset/*.jpg', 'world/scoutw/avenida3_golden/*.jpg', 'world/scoutw/casco_viejo/*.jpg', 'world/scoutw/costanera/*.jpg', 'world/scoutw/parque/*.jpg')
    night = files_of('world/scoutw/night_plaza/*.jpg')
    aer = files_of('world/aerial/city_plaza/*.jpg', 'world/aerial/city_costanera/*.jpg')
    # la región: lugares sobre las rutas (tools/trailer/make_region_spots.py) y las estaciones de servicio nuevas; si no están esas fotos, las de reconocimiento de antes
    spots = sorted(glob.glob(S('world/spots/*')))
    angles = ['a_front', 'c_rear', 'e_side', 'f_wide']  # (la cámara baja b_low mete el paragolpes en el cuadro y deja ver la parte de abajo del auto)
    spot_ground = []
    for k in range(len(angles)):
        for i, d_ in enumerate(spots):
            f = os.path.join(d_, angles[(i + k) % len(angles)] + '.jpg')
            if os.path.exists(f) and f not in spot_ground:
                spot_ground.append(f)
    stations = [f for f in [S('world/scoutw/puerto_alba/a_front.jpg'), S('world/scoutw/quebrada_roja/c_rear.jpg'), S('world/scoutw/cuesta_alta/a_front.jpg'), S('world/scoutw/bahia_ambar/c_rear.jpg')] if os.path.exists(f)]
    reg = interleave(spot_ground, stations) if spot_ground else files_of('world/scoutw/ruta_este/*.jpg', 'world/scoutw/circunv_ring/*.jpg', 'world/scoutw/puerto_alba/*.jpg', 'world/scoutw/bahia_ambar/*.jpg', 'world/scoutw/quebrada_roja/*.jpg', 'world/scoutw/cerro_verde/*.jpg', 'world/scoutw/cuesta_alta/*.jpg')
    # vistas de dron: sólo de lugares llanos (en la montaña, vistos desde arriba, los cortes de la ladera se ven como dientes oscuros)
    flat = [d_ for d_ in spots if not os.path.basename(d_).startswith(('montana', 'ramal'))]
    aer_r = [os.path.join(d_, n_ + '.jpg') for n_ in ('d1_alto_atras', 'd3_lateral') for d_ in flat if os.path.exists(os.path.join(d_, n_ + '.jpg'))] or files_of('world/aerial/puerto_alba/*.jpg', 'world/aerial/cuesta_alta/*.jpg', 'world/aerial/laguna_blanca/*.jpg', 'world/aerial/quebrada_roja/*.jpg', 'world/aerial/monte_sol/*.jpg', 'world/aerial/paso_condor/*.jpg')
    add(Clip(bar(36), bar(38), 'still', aer[0], z=(1.0, 1.22), pan=((0.5, 0.5), (0.5, 0.42)), ease='io', flash=0.7, shake=14, chroma=8, punch=0.06, punch_len=0.3,
             texts=title_card('DREAM CITY', L('UN MUNDO ABIERTO ENORME', 'A HUGE OPEN WORLD'), 0.0, 2 * BAR - 0.05, size=230, y=0.46)), 'impact', 0.8)
    montage(add, bar(38), bar(44), interleave(city, night, aer), 2 * P, caps=[L('ATARDECER', 'SUNSET'), L('TRÁNSITO Y PEATONES', 'TRAFFIC AND PEDESTRIANS'), L('CLIMA Y TORMENTAS', 'WEATHER AND STORMS'), L('DE NOCHE', 'AT NIGHT')], speed=0.1, blur=0.3, sound='whoosh')
    montage(add, bar(44), bar(48), interleave(aer_r, reg), 2 * P, caps=[L('~2.700 KM DE RUTAS', '~2,700 KM OF ROADS'), None, L('8 CIUDADES · 25 PUEBLOS', '8 CITIES · 25 TOWNS'), None, L('AUTOPISTAS Y MONTAÑA', 'HIGHWAYS AND MOUNTAINS'), None], speed=0.2, blur=0.4)
    ui_map = files_of('ui/spawn.png')
    # (la pantalla tiene un botón «DIAGNÓSTICO» de las compilaciones de desarrollo: se encuadra sólo el mapa, que es lo que importa, y queda afuera)
    add(Clip(bar(48), bar(50), 'still', ui_map[0], z=(1.34, 1.48), pan=((0.35, 0.50), (0.37, 0.52)), ease='io', flash=0.3, chroma=5,
             texts=[cap(L('ELEGÍ DÓNDE APARECER', 'CHOOSE WHERE TO SPAWN'), 0.2, 2 * BAR, x=0.5, y=0.12, anchor='mm', size=88, anim='fade', fin=0.3)]), 'whoosh', 0.7)
    tv = files_of('world/action/travesia/*.jpg', 'world/survey/travesia/p*_a.jpg', 'world/scout/travesia/*.jpg')
    montage(add, bar(50), bar(54), interleave(tv, reg), P, caps=[L('TRAVESÍA X', 'TRAVESÍA X'), L('44 KM EN CONVOY', '44 KM CONVOY'), L('BARRO · VADOS · CUEVA', 'MUD · FORDS · CAVE'), None], speed=0.25, blur=0.5, sound='tick')
    add(Clip(bar(54), bar(55) - 0.1, 'still', night[0], z=(1.0, 1.1), ease='in', dim=0.9), 'riser', 0.9)
    add(Clip(bar(55) - 0.1, bar(56), 'black'))  # el silencio de la canción (95,85 s)

    # ── H · FANTASÍA, DRIFT Y PICADA (compases 56 a 68) ──
    fan = {k: files_of('world/action/%s/*.jpg' % k, 'world/survey/%s/p*_a.jpg' % k, 'world/scout/%s/*.jpg' % k) for k in ['dream', 'anillo', 'marte', 'luna', 'paper']}
    fan_mix = interleave(*[fan[k] for k in ['dream', 'anillo', 'marte', 'luna', 'paper']])
    add(Clip(bar(56), bar(57), 'still', fan['dream'][0], z=(1.0, 1.16), pan=((0.5, 0.55), (0.5, 0.5)), ease='out', flash=1.0, shake=26, chroma=14, punch=0.08, punch_len=0.3, speed=0.3,
             texts=title_card(L('FANTASÍA', 'FANTASY'), L('MAPAS DE OTRO MUNDO', 'MAPS FROM ANOTHER WORLD'), 0.0, BAR - 0.05, size=290)), 'impact', 1.0)
    montage(add, bar(57), bar(61), fan_mix, P, caps=[L('SUEÑO', 'DREAM'), L('ANILLO', 'RING'), L('MARTE', 'MARS'), L('LUNA', 'MOON'), L('PAPEL', 'PAPER')], speed=0.25, blur=0.6, sound='tick')
    dr = files_of('world/extra/drift/*.jpg', 'world/scout/drift_plaza/*.jpg')
    pc = files_of('world/scout/picada/*.jpg')
    add(Clip(bar(61), bar(62), 'still', dr[0], z=(1.0, 1.14), flash=0.8, shake=18, chroma=10, punch=0.07, punch_len=0.3, speed=0.3,
             texts=title_card(L('DRIFT', 'DRIFT'), L('Y PICADAS', 'AND DRAG RACES'), 0.0, BAR - 0.05, size=290, color=WHITE)), 'impact', 0.8)
    montage(add, bar(62), bar(65), interleave(dr, pc), P / 2 * 1.0, caps=None, speed=0.3, blur=0.6, flash=0.22)
    montage(add, bar(65), bar(67), interleave(mix1[::2], fan_mix, dr), P / 2, speed=0.35, blur=0.7, flash=0.25)
    add(Clip(bar(67), bar(68), 'still', pick('studio/gt3/hero_gt3.jpg'), z=(1.0, 1.22), ease='out', flash=0.9, shake=24, chroma=14, punch=0.09, punch_len=0.35), 'impact', 1.0)

    # ── I · respiro: los pilotos (compases 68 a 70) ──
    pw = files_of('world/extra/pilots_world_forest_sunset/w0_*.jpg', 'world/extra/pilots_world_forest_sunset/*.jpg', 'poses/Waving_2.jpg')
    add(Clip(bar(68), bar(69), 'still', pw[0], z=(1.0, 1.10), ease='io', fade_in=0.2,
             texts=[T(L('TU HISTORIA.', 'YOUR STORY.'), 0.2, BAR, font='bebas', size=96, pos=(0.5, 0.18), spacing=14, anim='fade', fin=0.5, fout=0.3)]))
    add(Clip(bar(69), bar(70), 'still', (pw[1] if len(pw) > 1 else pw[0]), z=(1.1, 1.0), ease='io',
             texts=[T(L('TU AUTO.', 'YOUR CAR.'), 0.2, BAR, font='bebas', size=96, pos=(0.5, 0.18), spacing=14, anim='fade', fin=0.5, fout=0.3)]))

    # ── J · PERSONALIZÁ (compases 70 a 82) ──
    paint = pick_all('studio/paint_moust/paint_*.jpg') + pick_all('studio/paint_rally80/paint_*.jpg')
    add(Clip(bar(70), bar(71), 'still', pick('studio/moust/hero_moust.jpg'), z=(1.0, 1.12), flash=0.6, shake=14, chroma=8, punch=0.06, punch_len=0.3,
             texts=title_card(L('PERSONALIZÁ', 'CUSTOMIZE'), L('PINTURA · LLANTAS · MEJORAS · REGLAJES', 'PAINT · TIRES · UPGRADES · TUNING'), 0.0, BAR - 0.05, size=200, color=WHITE)), 'impact', 0.7)
    pm = pick_all('studio/paint_moust/paint_*.jpg') or [placeholder()]
    add(Clip(bar(71), bar(71) + len(pm) * (P / 2), 'seq', pm, seq_flash=0.12, seq_zoom=(1.0, 1.06),
             texts=[cap(L('24 ESTILOS DE PINTURA', '24 PAINT STYLES'), 0.1, len(pm) * (P / 2), x=0.5, y=0.12, anchor='mm', size=84, anim='fade', fin=0.2)]))
    t = bar(71) + len(pm) * (P / 2)
    pr = pick_all('studio/paint_rally80/paint_*.jpg') or pm
    add(Clip(t, t + len(pr) * (P / 2), 'seq', pr, seq_flash=0.12, seq_zoom=(1.0, 1.06)))
    t += len(pr) * (P / 2)
    ph = pick_all('studio/paint_hyper/paint_*.jpg') or pm
    ui_c = files_of('ui/garage.png', 'ui/paint.png', 'ui/tune.png', 'ui/workshop.png', 'ui/dealer.png')
    tend = bar(82)
    detail2 = [pick('studio/%s/wheel_%s.jpg' % (c, c)) for c in ['veltor_gtr', 'moust', 'torito', 'pro_gt', 'trilux_gt', 'camo', 'suv', 'buggy']]
    montage(add, t, tend, interleave(ui_c, detail2, ph[::3]), P, caps=[L('GARAJE', 'GARAGE'), None, L('TALLER', 'WORKSHOP'), None, L('REGLAJES', 'TUNING'), None, L('LLANTAS', 'TIRES'), None], flash=0.18)

    # ── K · ONLINE, adelanto (compases 82 a 94) ──
    ui_o = files_of('ui/online.png')  # (sólo la pantalla del online «próximamente»; la de compras no tiene nada que ver con el mercado entre jugadores)
    add(Clip(bar(82), bar(84), 'still', night[min(1, len(night) - 1)], z=(1.0, 1.20), pan=((0.5, 0.5), (0.5, 0.45)), ease='io', flash=0.5, shake=10, chroma=6, punch=0.05, punch_len=0.3,
             texts=title_card('ONLINE', L('PRÓXIMAMENTE', 'COMING SOON'), 0.0, 2 * BAR - 0.05, size=300, color=GOLD)), 'impact', 0.8)
    montage(add, bar(84), bar(88), interleave(night, ui_o, city[::2]), 2 * P, caps=[L('MERCADO ENTRE JUGADORES', 'PLAYER MARKET'), L('TALLER Y REGALO DIARIO', 'WORKSHOP AND DAILY GIFT'), L('UN MUNDO COMPARTIDO', 'A SHARED WORLD'), L('SUMÁ TUS AMIGOS', 'JOIN YOUR FRIENDS')], speed=0.1, blur=0.3, sound='whoosh')
    montage(add, bar(88), bar(92), interleave(mix1[1::2], aer_r, fan_mix, dr, tv), P, speed=0.25, blur=0.5, sound='tick')
    montage(add, bar(92), bar(94) - 0.1, interleave(fan_mix, mix1, dr), P / 2, speed=0.3, blur=0.6, flash=0.22)
    add(Clip(bar(94) - 0.1, bar(94), 'black'), 'riser', 0.6)

    # ── L · FINAL (compases 94 a 106) ──
    add(Clip(bar(94), bar(95), 'still', pick('studio/hyper/hero_hyper.jpg'), z=(1.15, 1.0), flash=1.0, shake=28, chroma=16, punch=0.1, punch_len=0.35,
             texts=title_card(L('26 AUTOS', '26 CARS'), None, 0.0, BAR - 0.05, size=300, color=WHITE)), 'impact', 1.0)
    fin_cars = [pick('studio/%s/side_%s.jpg' % (c, c), 'studio/%s/front_%s.jpg' % (c, c)) for c in ids]
    montage(add, bar(95), bar(101), fin_cars, P, speed=0.1, blur=0.3, flash=0.18, caps=None)
    montage(add, bar(101), bar(103), interleave(mix1[::3], fan_mix, aer_r, dr), P / 2, speed=0.3, blur=0.6, flash=0.25)
    add(Clip(bar(103), bar(104), 'still', pick('studio/hyper/hero_hyper.jpg'), z=(1.25, 1.1), ease='out', flash=0.6, shake=12), 'whoosh', 0.7)
    turn2 = pick_all('studio/turn_veltor_gtr/turn_*.jpg') or [pick('studio/veltor_gtr/hero_veltor_gtr.jpg')]
    add(Clip(bar(104), bar(106) - 0.1, 'seq', turn2, seq_flash=0.0, seq_zoom=(1.04, 1.0), fade_out=0.5,
             texts=logo_texts(0.3, 2 * BAR - 0.2, sub=L('PRÓXIMAMENTE EN GOOGLE PLAY', 'COMING SOON TO GOOGLE PLAY'), big=0.8, y=0.46)), 'impact', 0.9)
    add(Clip(bar(106) - 0.1, DUR, 'black', texts=[T('SRGAMESTUDIO', 0.3, DUR - bar(106) - 0.4, font='bebas', size=70, pos=(0.5, 0.5), spacing=22, anim='fade', fin=0.6, fout=0.6)]))
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
