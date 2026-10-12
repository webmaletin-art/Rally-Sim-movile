#!/usr/bin/env python3
"""Prepara la música del juego: convierte los mp3 de MusicGPT a ogg, les iguala el volumen (-16 LUFS) y arma godot/game/audio/music/tracks.json.
Los mp3 repetidos (mismo contenido) se descartan. Uso: python3 tools/trailer/prepare_music.py carpeta_con_los_mp3"""
import hashlib
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import analyze_music as AM  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'godot', 'game', 'audio', 'music')
TARGET_LUFS = -16.0
TITLES = {
    'Motor_de_Suenos': ('motor_suenos', 'Motor de Sueños'),
    'Nacidos_Para_Correr': ('nacidos', 'Nacidos Para Correr'),
    'Rally_en_el_Suelo_Digital': ('suelo_digital', 'Rally en el Suelo Digital'),
    'Rally_Thunder': ('thunder', 'Rally Thunder'),
    'Rally_Horizon': ('horizon', 'Rally Horizon'),
    'Rally_Ready': ('ready', 'Rally Ready'),
}


def main(argv):
    src = argv[1]
    os.makedirs(OUT, exist_ok=True)
    seen = {}
    tracks = []
    for f in sorted(os.listdir(src)):
        if not f.lower().endswith('.mp3'):
            continue
        p = os.path.join(src, f)
        h = hashlib.md5(open(p, 'rb').read()).hexdigest()
        if h in seen:
            print('repetido, se descarta:', f, '=', seen[h])
            continue
        seen[h] = f
        base = f[:-4]
        variant = 'a'
        if base.endswith('_1'):
            base = base[:-2]
            variant = 'b'
        slug, title = TITLES.get(base, (base.lower(), base.replace('_', ' ')))
        # si el tema sólo tiene una versión, sin sufijo
        tid = slug + ('_' + variant if any(k.startswith(base + '_1') for k in os.listdir(src)) and base in TITLES and len([x for x in os.listdir(src) if x.startswith(base)]) > 1 and variant else '')
        lu = AM.loudness(p).get('lufs', -14.0)
        gain = TARGET_LUFS - lu
        dst = os.path.join(OUT, tid + '.ogg')
        subprocess.run([AM.ffmpeg_path(), '-y', '-v', 'error', '-i', p, '-af', 'volume=%.2fdB' % gain, '-c:a', 'libvorbis', '-q:a', '3', '-ac', '2', '-ar', '44100', dst], check=True)
        x = AM.decode(dst)
        tracks.append({'id': tid, 'title': title + (' (versión B)' if variant == 'b' and tid.endswith('_b') else ''), 'file': tid + '.ogg', 'dur': round(len(x) / AM.SR, 1), 'src_lufs': lu, 'gain_db': round(gain, 2)})
        print('%-22s %6.1f s  %5.1f LUFS → %+5.2f dB  %4.1f MB' % (tid, tracks[-1]['dur'], lu, gain, os.path.getsize(dst) / 1e6))
    json.dump({'tracks': tracks}, open(os.path.join(OUT, 'tracks.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('%d temas, %.1f MB' % (len(tracks), sum(os.path.getsize(os.path.join(OUT, t['file'])) for t in tracks) / 1e6))


if __name__ == '__main__':
    main(sys.argv)
