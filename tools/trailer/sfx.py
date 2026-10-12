#!/usr/bin/env python3
"""Efectos de sonido del tráiler, sintetizados con numpy (sin archivos externos): golpe grave (impact), barrido (whoosh), subida (riser), obturador de cámara (shutter),
caída de graves (drop) y un «tick». Se mezclan debajo de la canción en los puntos que marca la lista de tomas (make_trailer.py)."""
import numpy as np

SR = 48000
RNG = np.random.default_rng(7)


def env_exp(n, tau):
    t = np.arange(n) / SR
    return np.exp(-t / tau)


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s
        y[i] = s
    return y


def lp_fast(x, fc):
    """Pasabajos por FFT (rápido para señales largas)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= 1.0 / (1.0 + (f / fc) ** 4)
    return np.fft.irfft(X, n)


def hp_fast(x, fc):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= (f / fc) ** 4 / (1.0 + (f / fc) ** 4)
    return np.fft.irfft(X, n)


def bandpass_sweep(x, f0, f1, q=3.0):
    """Barrido de banda pasante por bloques en el dominio de la frecuencia (centro f0 → f1)."""
    n = len(x)
    blk = 2048
    out = np.zeros(n + blk)
    win = np.hanning(blk)
    hop = blk // 2
    k = 0
    for s in range(0, n - blk, hop):
        fc = f0 * (f1 / f0) ** (s / max(1, n))
        seg = x[s:s + blk] * win
        X = np.fft.rfft(seg)
        f = np.fft.rfftfreq(blk, 1 / SR)
        X *= np.exp(-0.5 * ((np.log2(np.maximum(f, 20) / fc)) * q) ** 2)
        out[s:s + blk] += np.fft.irfft(X, blk) * win
        k += 1
    return out[:n] * 2.0


def reverb_tail(x, dur=1.2, mix=0.25):
    n = int(SR * dur)
    ir = RNG.normal(0, 1, n) * np.exp(-np.arange(n) / SR / (dur / 5))
    ir = lp_fast(ir, 4500)
    L = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    y /= max(1e-6, np.abs(y).max())
    out = np.zeros(L)
    out[:len(x)] += x
    out += y * mix * np.abs(x).max()
    return out


def impact(dur=1.8, gain=1.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 38 + 120 * np.exp(-t * 14)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.55)
    click = lp_fast(RNG.normal(0, 1, n), 2500) * np.exp(-t / 0.06) * 0.9
    sub = np.sin(2 * np.pi * 52 * t) * np.exp(-t / 0.9) * 0.6
    y = body + click + sub
    y = reverb_tail(y, 1.4, 0.30)[:n]
    y = np.tanh(y * 1.4) * gain
    return y / max(1e-6, np.abs(y).max()) * 0.9 * gain


def whoosh(dur=0.55, up=True, gain=1.0):
    n = int(SR * dur)
    x = RNG.normal(0, 1, n)
    y = bandpass_sweep(x, 350 if up else 5000, 5200 if up else 400, q=2.2)
    t = np.arange(n) / SR
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2.0
    y = y * e
    return y / max(1e-6, np.abs(y).max()) * 0.6 * gain


def riser(dur=3.0, gain=1.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = RNG.normal(0, 1, n)
    y = bandpass_sweep(x, 250, 7000, q=1.6) * (t / dur) ** 2.2
    f = 180 * (6.0 ** (t / dur))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / dur) ** 3 * 0.35
    y = y / max(1e-6, np.abs(y).max()) * 0.8 + tone
    return y / max(1e-6, np.abs(y).max()) * 0.6 * gain


def shutter(gain=1.0):
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for t0, w, a in [(0.0, 0.006, 1.0), (0.05, 0.014, 0.8)]:
        i0 = int(t0 * SR)
        m = int(w * SR * 4)
        burst = hp_fast(RNG.normal(0, 1, m), 1800) * np.exp(-np.arange(m) / SR / w)
        y[i0:i0 + m] += burst[:n - i0] * a
    thump = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.025) * 0.5
    y = y + thump
    return y / max(1e-6, np.abs(y).max()) * 0.5 * gain


def drop(dur=1.2, gain=1.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 90 * np.exp(-t * 2.2) + 28
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.7)
    return y / max(1e-6, np.abs(y).max()) * 0.8 * gain


def tick(gain=1.0):
    n = int(SR * 0.05)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.008) + RNG.normal(0, 0.15, n) * np.exp(-t / 0.004)
    return y / max(1e-6, np.abs(y).max()) * 0.3 * gain


def place(track, snd, t, gain=1.0):
    """Suma un sonido (mono) en la pista (estéreo, arreglo [n, 2]) en el segundo t."""
    i0 = int(t * SR)
    if i0 >= len(track):
        return
    n = min(len(snd), len(track) - i0)
    track[i0:i0 + n, 0] += snd[:n] * gain
    track[i0:i0 + n, 1] += snd[:n] * gain
