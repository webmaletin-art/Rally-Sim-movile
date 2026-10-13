#!/usr/bin/env python3
"""Genera las muestras del sonido del auto (godot/game/audio/samples/*.wav + consts.json).

El sonido del HTML se armaba con osciladores y filtros de Web Audio en tiempo real. En el teléfono, calcularlo muestra a muestra
en GDScript no llega (se corta). Acá se calcula UNA vez, con las mismas fórmulas, y el juego solo reproduce y cambia
volumen y velocidad de cada muestra (lo hace el motor de audio, en C++):
  · ruidos filtrados (rodado, chillido, grava, viento, soplido del turbo, lluvia, ruido del motor): bucles sin cortes
  · motor: UN ciclo que ya lleva los 5 osciladores + la modulación + la saturación (tanh) del HTML; el pasabajos va aparte
  · seno y triángulo de tablas cortas (silbido del turbo, caja de engranajes)
  · flutter del turbo, petardeos y golpe: muestras de un disparo

Ruidos de fondo (rodado, tierra, viento, lluvia, soplido del turbo, chillido): son bucles LARGOS (12–24 s, de ruido que ya es exactamente periódico, sin costura) y de
nivel parejo (RMS de referencia 0,10 → volumen 1,0 = −20 dBFS), formas más suaves que las del HTML (sin siseo agudo) y la tierra/lluvia con «crujidos» sueltos
en vez de ruido blanco. Antes eran de 2 s EXACTOS: a velocidad de ruta el rodado se repetía cada 2 s y sonaba como un viento fuerte que vuelve («loop»).
Se mide con godot/tests/audio_render.gd + tools/audio/analyze_audio.py (docs/AUDIO.md).
Uso: python3 tools/godot/make_audio.py
"""
import json
import os
import wave
import numpy as np
from scipy.signal import freqz

FS = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "game", "audio", "samples")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(20260930)
consts = {}


def save(name, x, peak=0.9, fs=FS):
    """Guarda en 16 bits normalizando al pico; devuelve el factor (1/escala) que hay que aplicarle al volumen para recuperar el nivel."""
    m = float(np.max(np.abs(x))) or 1.0
    s = peak / m
    y = np.clip(np.round(x * s * 32767), -32768, 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(y.tobytes())
    consts[name] = {"unit": 1.0 / s, "n": int(len(x)), "rate": fs}
    return 1.0 / s


def biquad(kind, f, q, fs=FS):
    """Coeficientes de Web Audio (pasabajos/pasaaltos con Q en dB, pasabanda con Q lineal)."""
    w0 = 2 * np.pi * f / fs
    cw, sw = np.cos(w0), np.sin(w0)
    if kind == "bp":
        al = sw / (2 * q)
        b = [al, 0, -al]
    else:
        al = sw / (2 * 10 ** (q / 20))
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2] if kind == "lp" else [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    a = [1 + al, -2 * cw, 1 - al]
    return b, a


REF = 0.10  # RMS de todos los ruidos de fondo: volumen 1,0 en el juego = −20 dBFS


def _rms(x):
    return float(np.sqrt(np.mean(x ** 2)))


def shaped_noise(n, chain, fs, r):
    """Ruido blanco (uniforme [-1,1]) pasado por la cadena de filtros EN EL DOMINIO DE LA FRECUENCIA: el resultado es exactamente periódico (el bucle no tiene costura)."""
    X = np.fft.rfft(r.uniform(-1, 1, n))
    w = np.linspace(0, np.pi, len(X))
    H = np.ones(len(X), dtype=complex)
    for kind, f, q in chain:
        b, a = biquad(kind, f, q, fs)
        _, h = freqz(b, a, worN=w)
        H = H * h
    return np.fft.irfft(X * H, n)


def crackle(n, fs, r, rate, f_lo, f_hi, tau_lo, tau_hi, sigma=0.8):
    """Crujidos sueltos (piedritas, gotas): impulsos al azar (Poisson, `rate` por segundo) que son un seno que se apaga en `tau` s, de frecuencia al azar y de golpe
    desparejo (lognormal). Dan «textura» sin el siseo del ruido blanco. Circular: lo que pasa del final vuelve al principio (el bucle no tiene costura)."""
    tail = int(0.03 * fs)
    out = np.zeros(n + tail)
    cnt = r.poisson(rate * n / fs)
    pos = r.integers(0, n, cnt)
    amp = np.minimum(np.exp(r.normal(0.0, sigma, cnt)), 2.5)  # sin golpes enormes: tienen que ser textura, no chasquidos
    fr = r.uniform(f_lo, f_hi, cnt)
    ta = r.uniform(tau_lo, tau_hi, cnt)
    ph = r.uniform(0, 2 * np.pi, cnt)
    for i in range(cnt):
        ln = min(int(ta[i] * fs * 6), tail)
        t = np.arange(ln) / fs
        out[pos[i]:pos[i] + ln] += amp[i] * np.sin(2 * np.pi * fr[i] * t + ph[i]) * np.exp(-t / ta[i])
    out[:tail] += out[n:n + tail]
    out = out[:n]
    out = out / _rms(out)
    return np.tanh(out / 2.2) * 2.2  # pico suave: el golpe más fuerte no pasa de ~4 veces el nivel medio


def noise_loop(name, chain, secs, seed, fs=FS, extra=None, mix_extra=0.0):
    """Bucle de ruido filtrado de `secs` segundos, a RMS REF. `extra(n, fs, r)`: crujidos que se mezclan (mix_extra = su parte de la potencia, 0..1)."""
    n = int(fs * secs)
    r = np.random.default_rng(seed)
    y = shaped_noise(n, chain, fs, r)
    y = y / _rms(y)
    if extra is not None and mix_extra > 0:
        c = extra(n, fs, r)
        y = np.sqrt(1.0 - mix_extra) * y + np.sqrt(mix_extra) * c / _rms(c)
    y *= REF / _rms(y)
    save(name, y, fs=fs)
    consts[name]["rms_ref"] = REF


# ── ruidos de fondo ──
# Se consumen las mismas tiradas del generador general que antes gastaban los 7 ruidos de 2 s, para que las muestras de un disparo de más abajo (flutter, petardeo, golpe)
# queden IGUALES a las de siempre: este arreglo sólo toca lo que se repetía.
for _ in range(7):
    rng.uniform(-1, 1, 88200)

# rodado de las gomas en asfalto: retumbo grave y parejo (antes un pasabanda ancho en 380 Hz que dejaba pasar siseo hasta los 3 kHz)
noise_loop("roll", [("hp", 80, 0.7), ("bp", 330, 0.8), ("lp", 950, 0.7)], 24.0, 101, fs=22050)
# chillido de gomas: pasabanda angosto (menos que antes: Q 5 en vez de 7, para que no sea un silbido fino)
noise_loop("squeal", [("bp", 1150, 5.0)], 12.0, 102)
# tierra / ripio / pasto: crujidos de piedritas sobre un colchón de ruido medio (sin el siseo de 2–5 kHz del ruido blanco filtrado)
noise_loop("gravel", [("hp", 450, 0.7), ("lp", 2400, 0.7), ("lp", 3200, 0.7)], 24.0, 103,
           extra=lambda n, fs, r: crackle(n, fs, r, 340.0, 800.0, 3000.0, 0.0012, 0.0035), mix_extra=0.45)
# viento: soplido de aire parejo y grave, sin silbido (casi todo entre 120 y 900 Hz: lo que un parlante de teléfono sí reproduce, sin el retumbo que no sale)
noise_loop("wind", [("hp", 120, 0.7), ("lp", 800, 0.7), ("lp", 1000, 0.7)], 24.0, 104, fs=22050)
# soplido del turbo: banda ancha en 2,6 kHz (antes Q 4 en 3,6 kHz: un «ssss» fino que parecía silbido)
noise_loop("turbo", [("bp", 2600, 1.0), ("lp", 5200, 0.7)], 12.0, 105)
# lluvia: mucho menos siseo (nada por encima de 7 kHz) y gotas sueltas encima
noise_loop("rain", [("hp", 1200, 0.7), ("lp", 5600, 0.7), ("lp", 7000, 0.7)], 24.0, 106,
           extra=lambda n, fs, r: crackle(n, fs, r, 260.0, 2500.0, 6500.0, 0.0003, 0.0009, 0.7), mix_extra=0.25)
noise_loop("engnoise", [("bp", 200, 1.5)], 12.0, 107, fs=22050)  # base 200 Hz: en el juego se sube/baja con la velocidad de reproducción hasta f0

# ── motor: un ciclo de 42 Hz (1050 muestras) ──
# frecuencias relativas a f0: 1, 0.5, 2, 0.25, 1.5 y la modulación a 0.125 → todas son múltiplos de f0/8 = el ciclo de la tabla
N = 1050
p = np.arange(N) / N
K = 260  # armónicos que se conservan (a 42 Hz = 11 kHz): sin reflejos al subir el tono


def saw(ph, kmax=K * 8):
    return 2 * (ph % 1.0) - 1.0


def series(kind, mult, kmax):
    """Onda con armónicos limitados (serie de Fourier) de frecuencia mult·(ciclo)."""
    out = np.zeros(N)
    for m in range(1, kmax // mult + 1):
        if kind == "saw":
            out += (-1) ** (m + 1) * (2 / np.pi) * np.sin(2 * np.pi * m * mult * p) / m
        elif kind == "sqr":
            if m % 2:
                out += (4 / np.pi) * np.sin(2 * np.pi * m * mult * p) / m
        elif kind == "tri":
            if m % 2:
                out += (8 / np.pi ** 2) * (-1) ** ((m - 1) // 2) * np.sin(2 * np.pi * m * mult * p) / m ** 2
    return out


mix = (0.45 * series("saw", 8, K) + 0.35 * series("saw", 4, K) + 0.08 * series("sqr", 16, K)
       + 0.45 * np.sin(2 * np.pi * 2 * p) + 0.10 * series("tri", 12, K))
mix *= 0.75 + 0.25 * np.sin(2 * np.pi * p)  # modulación (LFO a f0/8)
eng = np.tanh(2.2 * np.clip(mix, -1, 1))  # saturación
E = np.fft.rfft(eng)
E[K + 1:] = 0  # sin armónicos por encima de K
eng = np.fft.irfft(E, N)
consts["engine_base_hz"] = 42.0
save("engine", np.tile(eng, 1), peak=0.95)
# motor de un rival: dos serruchos (f y f/2) → ciclo de f/2
ai = series("saw", 2, K) + series("saw", 1, K)
save("engine_ai", ai, peak=0.95)

# ── tonos: tablas de 64 muestras (689,06 Hz): seno y triángulo ──
M = 64
q = np.arange(M) / M
save("sine", np.sin(2 * np.pi * q), peak=0.95)
tri = np.zeros(M)
for m in range(1, 40, 2):
    tri += (8 / np.pi ** 2) * (-1) ** ((m - 1) // 2) * np.sin(2 * np.pi * m * q) / m ** 2
save("tri", tri, peak=0.95)
consts["tone_base_hz"] = FS / M


# ── ráfagas (un disparo) ──
def bp_filter(x, f, qv):
    from scipy.signal import lfilter
    b, a = biquad("bp", f, qv)
    return lfilter(b, a, x)


def lp_filter(x, f, qv):
    from scipy.signal import lfilter
    b, a = biquad("lp", f, qv)
    return lfilter(b, a, x)


def burst(dur, f, qv, amp, kind="bp"):
    """Ruido filtrado con ataque de 4 ms y caída exponencial hasta 0,0008 (como burst() del HTML)."""
    n = int(dur * FS) + 1
    nz = rng.uniform(-1, 1, n)
    y = bp_filter(nz, f, qv) if kind == "bp" else lp_filter(nz, f, qv)
    t = np.arange(n) / FS
    env = np.where(t < 0.004, amp * t / 0.004, amp * (0.0008 / max(amp, 0.0008)) ** ((t - 0.004) / max(dur - 0.004, 1e-3)))
    return y * env


def flutter(b, T_f=1.0):
    """Tren de ráfagas que se apaga: 'tu-tu-tu-tu' (flutter del compresor del turbo), b = carga 0..1"""
    n = int(round(5 + b * 9))
    f = (850 + 350 * b) * T_f
    total = 0.9
    out = np.zeros(int(total * FS))
    tt = 0.015
    step = 0.027 / np.sqrt(T_f)
    for i in range(n):
        k = 1 - i / n
        seg = burst(0.016 + 0.012 * k, f * (1 - 0.018 * i), 2.6, k ** 1.2 * (0.75 + 0.5 * rng.random()))
        s0 = int(tt * FS)
        out[s0:s0 + len(seg)] += seg[: len(out) - s0]
        tt += step * (1 + 0.07 * i)
    seg = burst(0.16 + 0.2 * b, 2300 * T_f, 0.8, 0.22)
    s0 = int(0.015 * FS)
    out[s0:s0 + len(seg)] += seg[: len(out) - s0]
    return out


for nm, b in [("flutter_lo", 0.35), ("flutter_mid", 0.65), ("flutter_hi", 1.0)]:
    save(nm, flutter(b), peak=0.9)
save("pop", burst(0.06, 1000, 1.2, 1.0), peak=0.9)
# golpe: seno que baja de 75 a 38 Hz con caída exponencial + ráfaga grave
n = int(0.3 * FS)
t = np.arange(n) / FS
fq = 75 * (38 / 75) ** np.minimum(t / 0.22, 1)
ph = np.cumsum(fq) / FS
env = 0.9 * (0.001 / 0.9) ** np.minimum(t / 0.28, 1)
th = np.sin(2 * np.pi * ph) * env
th[: int(0.12 * FS) + 1] += burst(0.12, 180, 0.7, 0.6, kind="lp")
save("thump", th, peak=0.9)

# ── sonidos de interfaz (sfxPlay del HTML): oscilador con caída exponencial hasta 0,0005 ──
def sfx(name, f0, dur, kind, vol, f_end=None, steps=None):
    n = int((dur + 0.05) * FS)
    t = np.arange(n) / FS
    if steps:
        f = np.full(n, steps[0][1], dtype=float)
        for ts, fv in steps:
            f[t >= ts] = fv
    elif f_end:
        f = f0 * (f_end / f0) ** np.minimum(t / dur, 1)
    else:
        f = np.full(n, f0, dtype=float)
    ph = np.cumsum(f) / FS
    if kind == "sine":
        w = np.sin(2 * np.pi * ph)
    elif kind == "triangle":
        w = 2 * np.abs(2 * (ph % 1.0) - 1) - 1
    else:
        w = np.where((ph % 1.0) < 0.5, 1.0, -1.0)
    env = np.where(t < dur, vol * (0.0005 / vol) ** (t / dur), 0.0)
    save("sfx_" + name, w * env, peak=0.9)
    consts["sfx_" + name]["vol"] = vol


sfx("click", 880, 0.04, "triangle", 0.12)
sfx("buy", 660, 0.18, "sine", 0.2, f_end=1320)
sfx("error", 160, 0.2, "square", 0.12)
sfx("beep", 660, 0.16, "sine", 0.35)
sfx("go", 1320, 0.5, "sine", 0.35)
sfx("coin", 1500, 0.12, "sine", 0.2, f_end=3000)
sfx("finish", 523, 0.6, "triangle", 0.3, steps=[(0, 523), (0.15, 659), (0.3, 784)])

with open(os.path.join(OUT, "consts.json"), "w") as f:
    json.dump(consts, f, indent=1)
print("listo:", ", ".join(sorted(k for k in consts if isinstance(consts[k], dict))))
tot = sum(os.path.getsize(os.path.join(OUT, x)) for x in os.listdir(OUT))
print("total %.0f KB" % (tot / 1024))
