#!/usr/bin/env python3
"""Analiza los temas de la música del juego: duración, volumen (LUFS), tempo (BPM), grilla de golpes y curva de energía. No «escucha»: mide.
Uso: python3 tools/trailer/analyze_music.py carpeta_o_mp3... [--json salida.json]
Lo usa make_trailer.py para cortar el video a ritmo y tools/trailer/prepare_music.py para igualar el volumen de las pistas del menú."""
import json
import os
import re
import subprocess
import sys

import numpy as np

SR = 22050


def ffmpeg_path():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path):
    cmd = [ffmpeg_path(), '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-']
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype='<f4')


def loudness(path):
    """LUFS integrado, rango de volumen y pico real (ebur128 de ffmpeg)"""
    p = subprocess.run([ffmpeg_path(), '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128=peak=true', '-f', 'null', '-'], capture_output=True, text=True)
    t = p.stderr
    t = t[t.rfind('Summary:'):] if 'Summary:' in t else t # el resumen final (antes hay un renglón por cada 100 ms)
    out = {}
    m = re.search(r'I:\s+(-?[\d.]+) LUFS', t)
    if m:
        out['lufs'] = float(m.group(1))
    m = re.search(r'LRA:\s+([\d.]+) LU', t)
    if m:
        out['lra'] = float(m.group(1))
    m = re.search(r'Peak:\s+(-?[\d.]+) dBFS', t)
    if m:
        out['peak'] = float(m.group(1))
    return out


def stft_mag(x, n=1024, hop=256):
    w = np.hanning(n).astype(np.float32)
    frames = 1 + (len(x) - n) // hop
    idx = np.arange(n)[None, :] + hop * np.arange(frames)[:, None]
    return np.abs(np.fft.rfft(x[idx] * w, axis=1)).astype(np.float32)


def analyze(path):
    x = decode(path)
    dur = len(x) / SR
    hop = 256
    S = stft_mag(x, 1024, hop)
    fr = SR / hop  # cuadros por segundo
    # novedad espectral (flujo positivo) → golpes
    flux = np.maximum(0, np.diff(np.log1p(S * 20.0), axis=0)).sum(axis=1)
    flux = np.concatenate([[0], flux])
    flux = (flux - flux.mean()) / (flux.std() + 1e-9)
    # tempo por autocorrelación de la novedad (60–200 BPM)
    ac = np.correlate(flux, flux, mode='full')[len(flux) - 1:]
    lo, hi = int(fr * 60 / 200), int(fr * 60 / 60)
    seg = ac[lo:hi]
    lag = lo + int(np.argmax(seg))
    bpm = 60.0 * fr / lag
    # llevar el tempo a un rango razonable para cortar video (80–170)
    while bpm < 80:
        bpm *= 2
    while bpm > 170:
        bpm /= 2
    period = 60.0 / bpm
    # fase: el desplazamiento que más novedad junta
    best = (-1e9, 0.0)
    for ph in np.arange(0, period, 0.01):
        ts = np.arange(ph, dur, period)
        ix = np.clip((ts * fr).astype(int), 0, len(flux) - 1)
        sc = flux[ix].sum()
        if sc > best[0]:
            best = (sc, ph)
    phase = best[1]
    beats = np.arange(phase, dur, period)
    # energía (dB RMS) cada 0.5 s
    win = int(SR * 0.5)
    n = len(x) // win
    rms = np.sqrt((x[:n * win].reshape(n, win) ** 2).mean(axis=1) + 1e-12)
    db = 20 * np.log10(rms + 1e-9)
    # brillo medio (centroide) y presencia de voz (300–3400 Hz sobre el total)
    freqs = np.fft.rfftfreq(1024, 1 / SR)
    energy = (S ** 2).sum(axis=0)
    centroid = float((freqs * energy).sum() / energy.sum())
    band = float(energy[(freqs >= 300) & (freqs <= 3400)].sum() / energy.sum())
    info = {'file': os.path.basename(path), 'dur': round(dur, 2), 'bpm': round(bpm, 1), 'phase': round(float(phase), 3), 'centroid_hz': round(centroid), 'voice_band': round(band, 3),
            'energy_db': [round(float(v), 1) for v in db], 'beats': [round(float(b), 3) for b in beats]}
    info.update(loudness(path))
    return info


def main(argv):
    out = None
    args = []
    i = 1
    while i < len(argv):
        if argv[i] == '--json':
            out = argv[i + 1]
            i += 2
            continue
        args.append(argv[i])
        i += 1
    files = []
    for a in args:
        if os.path.isdir(a):
            files += sorted(os.path.join(a, f) for f in os.listdir(a) if f.lower().endswith(('.mp3', '.ogg', '.wav', '.flac')))
        else:
            files.append(a)
    res = []
    for f in files:
        r = analyze(f)
        res.append(r)
        e = np.array(r['energy_db'])
        print('%-52s %5.1f s  %5.1f BPM  %6.1f LUFS  LRA %4.1f  pico %5.1f  centroide %4d Hz  banda de voz %.2f  energía media %.1f dB (p90 %.1f)' % (
            r['file'][:52], r['dur'], r['bpm'], r.get('lufs', 0), r.get('lra', 0), r.get('peak', 0), r['centroid_hz'], r['voice_band'], e.mean(), np.percentile(e, 90)))
    if out:
        json.dump(res, open(out, 'w'))


if __name__ == '__main__':
    main(sys.argv)
