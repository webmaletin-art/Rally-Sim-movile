#!/usr/bin/env python3
"""Mapa de una canción para cortar el tráiler a ritmo: golpes (beats), compases, cortes de energía («stops»), secciones y la curva de energía a 30 cuadros por segundo.
No «escucha»: mide. Uso: python3 tools/trailer/music_map.py cancion.mp3 salida.json"""
import json
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit('/', 1)[0])
import analyze_music as am  # noqa: E402

SR = am.SR
HOP = 256


def spec(x, n=1024):
    w = np.hanning(n).astype(np.float32)
    frames = 1 + (len(x) - n) // HOP
    idx = np.arange(n)[None, :] + HOP * np.arange(frames)[:, None]
    return np.abs(np.fft.rfft(x[idx] * w, axis=1)).astype(np.float32)


def main(path, out):
    x = am.decode(path)
    dur = len(x) / SR
    S = spec(x)
    fr = SR / HOP
    f = np.fft.rfftfreq(1024, 1 / SR)
    low = (f >= 30) & (f < 150)
    mid = (f >= 150) & (f < 3500)
    hi = f >= 3500
    L = np.log1p(S * 20.0)
    flux_all = np.concatenate([[0], np.maximum(0, np.diff(L, axis=0)).sum(axis=1)])
    flux_low = np.concatenate([[0], np.maximum(0, np.diff(L[:, low], axis=0)).sum(axis=1)])
    flux_all = (flux_all - flux_all.mean()) / (flux_all.std() + 1e-9)
    flux_low = (flux_low - flux_low.mean()) / (flux_low.std() + 1e-9)
    # tempo: autocorrelación de la novedad
    ac = np.correlate(flux_all, flux_all, mode='full')[len(flux_all) - 1:]
    lo, hi_l = int(fr * 60 / 200), int(fr * 60 / 70)
    lag = lo + int(np.argmax(ac[lo:hi_l]))
    # afinar el período con una parábola
    y0, y1, y2 = ac[lag - 1], ac[lag], ac[lag + 1]
    lag_f = lag + 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2 + 1e-9)
    period = lag_f / fr
    bpm = 60.0 / period
    # fase por tramos de 20 s (la música generada no siempre tiene el tempo clavado)
    def best_phase(t0, t1, per):
        best = (-1e9, 0.0)
        for ph in np.arange(0, per, 0.004):
            ts = np.arange(t0 + ph, t1, per)
            ix = np.clip((ts * fr).astype(int), 0, len(flux_all) - 1)
            sc = (flux_all[ix] + 0.7 * flux_low[ix]).sum()
            if sc > best[0]:
                best = (sc, ph)
        return best[1]
    phases = []
    for t0 in np.arange(0, dur, 20.0):
        phases.append((float(t0), float(best_phase(t0, min(dur, t0 + 20.0), period))))
    # grilla global: fase del primer tramo con buena energía
    ph0 = best_phase(10.0, dur - 5.0, period)
    beats = np.arange(ph0 % period, dur, period)
    # envolvente de energía a 30 cuadros/s (RMS en dB, normalizada 0..1) y de graves
    n30 = int(dur * 30)
    seg = len(x) / n30
    rms = np.array([np.sqrt((x[int(i * seg):int((i + 1) * seg)] ** 2).mean() + 1e-12) for i in range(n30)])
    db = 20 * np.log10(rms + 1e-9)
    env = np.clip((db - np.percentile(db, 2)) / (np.percentile(db, 98) - np.percentile(db, 2) + 1e-9), 0, 1)
    lowE = np.array([np.sqrt((S[int(i / 30 * fr):max(int(i / 30 * fr) + 1, int((i + 1) / 30 * fr)), :][:, low] ** 2).mean() + 1e-12) for i in range(n30)])
    lowE = np.clip((20 * np.log10(lowE + 1e-9) - np.percentile(20 * np.log10(lowE + 1e-9), 2)) / (np.percentile(20 * np.log10(lowE + 1e-9), 98) - np.percentile(20 * np.log10(lowE + 1e-9), 2) + 1e-9), 0, 1)
    # picos de novedad (golpes fuertes): momentos para flashes y cortes
    thr = np.percentile(flux_all, 93)
    peaks = []
    for i in range(2, len(flux_all) - 2):
        if flux_all[i] > thr and flux_all[i] == flux_all[i - 2:i + 3].max():
            t = i / fr
            if not peaks or t - peaks[-1][0] > 0.12:
                peaks.append((t, float(flux_all[i])))
    # cortes de energía («stops»)
    win = int(0.05 * SR)
    m = len(x) // win
    r50 = np.sqrt((x[:m * win].reshape(m, win) ** 2).mean(axis=1) + 1e-12)
    db50 = 20 * np.log10(r50 + 1e-9)
    loc = np.array([np.median(db50[max(0, i - 60):i + 60]) for i in range(m)])
    stops = []
    i = 0
    while i < m:
        if db50[i] < loc[i] - 9:
            j = i
            while j < m and db50[j] < loc[j] - 6:
                j += 1
            if (j - i) * 0.05 >= 0.12 and i * 0.05 > 2:
                stops.append({'t': round(i * 0.05, 2), 'len': round((j - i) * 0.05, 2), 'depth': round(float(loc[i] - db50[i:j].min()), 1)})
            i = j
        else:
            i += 1
    # secciones: promedio de energía por compás y salto entre compases
    bar = 4 * period
    nb = int(dur / bar)
    bar_e = np.array([env[int((ph0 + k * bar) * 30):int((ph0 + (k + 1) * bar) * 30)].mean() if int((ph0 + k * bar) * 30) < n30 else 0 for k in range(nb)])
    res = {'file': path.rsplit('/', 1)[-1], 'dur': round(dur, 2), 'bpm': round(bpm, 2), 'period': round(period, 4), 'phase': round(float(ph0 % period), 3),
           'beats': [round(float(b), 3) for b in beats], 'phases20': phases, 'stops': stops, 'peaks': [[round(t, 3), round(v, 2)] for t, v in peaks],
           'env30': [round(float(v), 3) for v in env], 'low30': [round(float(v), 3) for v in lowE], 'bar_energy': [round(float(v), 3) for v in bar_e]}
    json.dump(res, open(out, 'w'))
    print('BPM %.2f · período %.4f s · fase %.3f · %d golpes · %d compases · %d picos · stops: %s' % (bpm, period, ph0 % period, len(beats), nb, len(peaks), stops))
    print('fase por tramos de 20 s:', [round(p[1], 3) for p in phases])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
