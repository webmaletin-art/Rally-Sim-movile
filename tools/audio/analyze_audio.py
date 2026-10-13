#!/usr/bin/env python3
"""Mide una grabación del audio del juego (la que hace godot/tests/audio_render.gd) para saber, sin oídos, QUÉ suena:

  · niveles: pico y RMS (dBFS) de todo y por tramos de 4 s, y cuánta energía hay por banda (grave, medios, agudos, «siseo»)
  · TONOS QUE SE QUEDAN: líneas finas del espectro (silbidos, chillidos, zumbidos de la caja) que duran varios segundos → el «silbido en loop»
  · REPETICIÓN: si el sonido se repite exacto cada tantos segundos (un bucle corto de ruido se oye como «olas» que vuelven)
  · silencio: lo que queda sonando cuando nada debería sonar (parado, pausado)
Uso: python3 tools/audio/analyze_audio.py a.wav [b.wav …] [--from 2.0] [--to 20] [--json]
"""
import argparse
import json
import sys
import wave

import numpy as np


def load(path):
    w = wave.open(path)
    n, ch, sw, fs = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    if sw != 2:
        raise SystemExit("sólo 16 bits: " + path)
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return x, fs


def db(v, floor=-120.0):
    return float(20 * np.log10(max(v, 1e-6))) if v > 0 else floor


def a_weight(f):
    """Ponderación A (aproximada): cuánto «pesa» cada frecuencia para el oído, en veces."""
    f2 = np.asarray(f, dtype=float) ** 2
    ra = (12194.0 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194.0 ** 2))
    return ra / 0.7943  # 1.0 a 1 kHz


BANDS = [("<150", 0, 150), ("150-400", 150, 400), ("400-1k", 400, 1000), ("1-2k", 1000, 2000), ("2-4k", 2000, 4000), ("4-8k", 4000, 8000), (">8k", 8000, 22050)]


def band_levels(x, fs):
    """RMS (dBFS) por banda y total ponderado A (dBA relativo a plena escala)"""
    n = len(x)
    X = np.fft.rfft(x * np.hanning(n)) / (n * 0.375)  # amplitud pico por bin
    f = np.fft.rfftfreq(n, 1 / fs)
    p = np.abs(X) ** 2 / 2.0
    out = {}
    for name, lo, hi in BANDS:
        m = (f >= lo) & (f < hi)
        out[name] = db(np.sqrt(p[m].sum()))
    pa = (p * a_weight(f) ** 2).sum()
    out["dBA"] = db(np.sqrt(pa))
    return out


def tonal_tracks(x, fs, win=1.0, hop=0.5, prom_db=14.0, floor_db=-85.0):
    """Líneas finas del espectro que se repiten de un cuadro al siguiente. Devuelve [{f0, f1, t0, t1, dur, prom, lvl}]"""
    n = int(win * fs)
    nfft = 1 << int(np.ceil(np.log2(n)))
    w = np.hanning(n)
    f = np.fft.rfftfreq(nfft, 1 / fs)
    df = f[1]
    frames = []
    t = 0.0
    while int((t + win) * fs) <= len(x):
        seg = x[int(t * fs):int(t * fs) + n] * w
        S = np.abs(np.fft.rfft(seg, nfft)) / (n * 0.5)  # amplitud pico
        L = 20 * np.log10(np.maximum(S, 1e-9))
        # mediana móvil (±300 Hz) del espectro: el «piso» al lado de cada línea
        k = max(3, int(300 / df)) | 1
        pad = np.pad(L, (k // 2, k // 2), mode="edge")
        win_s = np.lib.stride_tricks.sliding_window_view(pad, k)
        med = np.median(win_s[::1], axis=1) if len(L) < 40000 else np.array([np.median(win_s[i]) for i in range(len(L))])
        peaks = []
        for i in range(2, len(L) - 2):
            if f[i] < 80 or L[i] < floor_db:
                continue
            if L[i] > L[i - 1] and L[i] >= L[i + 1] and L[i] - med[i] >= prom_db:
                # nivel de la línea: potencia en ±3 bins
                lv = db(np.sqrt((S[i - 3:i + 4] ** 2).sum() / 2.0) if i >= 3 else S[i] / np.sqrt(2))
                peaks.append((f[i], L[i] - med[i], lv))
        frames.append((t, peaks))
        t += hop
    # seguir las líneas entre cuadros (±4 % de frecuencia)
    tracks = []
    for t, peaks in frames:
        for (fr, pr, lv) in peaks:
            best = None
            for tr in tracks:
                if tr["t1"] >= t - hop - 1e-6 and tr["t1"] < t + 1e-6 and abs(fr - tr["f1"]) <= 0.04 * tr["f1"] + 2 * df:
                    best = tr
                    break
            if best is None:
                tracks.append({"f0": fr, "f1": fr, "t0": t, "t1": t, "n": 1, "prom": pr, "lvl": lv, "lmax": lv})
            else:
                best["f1"] = fr
                best["t1"] = t
                best["n"] += 1
                best["prom"] += pr
                best["lvl"] += lv
                best["lmax"] = max(best["lmax"], lv)
    out = []
    for tr in tracks:
        dur = tr["t1"] - tr["t0"] + win
        out.append({"f0": round(tr["f0"]), "f1": round(tr["f1"]), "t0": round(tr["t0"], 1), "t1": round(tr["t1"] + win, 1), "dur": round(dur, 1),
                    "prom": round(tr["prom"] / tr["n"], 1), "lvl": round(tr["lvl"] / tr["n"], 1), "lmax": round(tr["lmax"], 1)})
    out.sort(key=lambda r: (-r["dur"], -r["lvl"]))
    return out


def repetition(x, fs, lo=0.4, hi=9.0, hp=250.0):
    """Autocorrelación normalizada (sin lo grave, que es el motor) para lags de lo a hi s. Devuelve los 3 picos más altos [(lag s, valor)]"""
    n = len(x)
    X = np.fft.rfft(x - x.mean())
    f = np.fft.rfftfreq(n, 1 / fs)
    X[f < hp] = 0
    X[f > 12000] = 0
    # se blanquea un poco (raíz) para que no mande una sola línea fuerte
    mag = np.abs(X)
    Xw = X / np.maximum(mag, 1e-9) ** 0.5
    ac = np.fft.irfft(np.abs(Xw) ** 2, n)
    ac /= ac[0] if ac[0] > 0 else 1.0
    a, b = int(lo * fs), min(int(hi * fs), n // 2)
    seg = ac[a:b]
    out = []
    used = np.zeros(len(seg), bool)
    for _ in range(3):
        m = np.where(used, -9, seg)
        if len(m) == 0:
            break
        i = int(np.argmax(m))
        out.append((round((a + i) / fs, 3), round(float(seg[i]), 3)))
        used[max(0, i - int(0.05 * fs)):i + int(0.05 * fs)] = True
    return out


def analyze(path, t0=0.0, t1=None):
    x, fs = load(path)
    a = int(t0 * fs)
    b = len(x) if t1 is None else min(len(x), int(t1 * fs))
    x = x[a:b]
    r = {"file": path, "secs": round(len(x) / fs, 1), "peak": round(db(float(np.max(np.abs(x)))), 1), "rms": round(db(float(np.sqrt(np.mean(x ** 2)))), 1)}
    seg = int(4 * fs)
    r["rms_4s"] = [round(db(float(np.sqrt(np.mean(x[i:i + seg] ** 2)))), 1) for i in range(0, max(len(x) - seg + 1, 1), seg)]
    bl = band_levels(x, fs)
    r["bands"] = {k: round(v, 1) for k, v in bl.items()}
    r["tones"] = [t for t in tonal_tracks(x, fs) if t["dur"] >= 2.0][:8]
    r["repeat"] = repetition(x, fs)
    return r


def show(r):
    print("== %s  (%.1f s)  pico %.1f dBFS · RMS %.1f dBFS · %.1f dBA" % (r["file"], r["secs"], r["peak"], r["rms"], r["bands"]["dBA"]))
    print("   RMS cada 4 s: " + " ".join("%.0f" % v for v in r["rms_4s"]))
    print("   bandas (dBFS): " + "  ".join("%s %.0f" % (k, v) for k, v in r["bands"].items() if k != "dBA"))
    if r["tones"]:
        print("   tonos que duran (≥2 s):")
        for t in r["tones"]:
            print("     %5d→%5d Hz  %4.1f s (%.1f–%.1f)  sobresale %.0f dB  nivel %.0f dBFS (máx %.0f)" % (t["f0"], t["f1"], t["dur"], t["t0"], t["t1"], t["prom"], t["lvl"], t["lmax"]))
    else:
        print("   tonos que duran: ninguno")
    print("   repetición (lag s, correlación): " + "  ".join("%.2f s → %.2f" % lv for lv in r["repeat"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--from", dest="t0", type=float, default=0.0)
    ap.add_argument("--to", dest="t1", type=float, default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    res = [analyze(f, a.t0, a.t1) for f in a.files]
    if a.json:
        json.dump(res, sys.stdout, indent=1)
    else:
        for r in res:
            show(r)


if __name__ == "__main__":
    main()
