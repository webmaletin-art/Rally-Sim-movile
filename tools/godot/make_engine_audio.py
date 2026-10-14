#!/usr/bin/env python3
"""Capas del motor «como en los simuladores» (pedido del dueño, 14/10/2026: «los sonidos son muy finos, muy robóticos; quiero oír motor real, caja, turbo…»).

Antes el motor era UN ciclo de 1050 muestras que se repetía idéntico (5 osciladores + saturación): un zumbido perfecto = sonido de robot.
Un motor de verdad son EXPLOSIONES sueltas, cada una distinta (fuerza y momento varían ciclo a ciclo), que hacen sonar los tubos del escape.
Los juegos de simulación usan grabaciones del motor a varias vueltas, con carga (acelerando) y sin carga (soltando: freno motor), y las mezclan.
Acá se fabrican esas grabaciones con física simple:
  · tren de pulsos de presión a la frecuencia de encendido F (Hz = rpm/60 × cilindros/2), con fluctuación de tiempo y de fuerza en cada explosión;
  · el escape: resonancias de los tubos (picos en 110–1700 Hz) + silenciador (pasabajos), aplicado en el dominio de la frecuencia (el bucle no tiene costura);
  · admisión (ruido que respira con cada explosión) y ruido mecánico (válvulas, cadena) sólo con carga;
  · sin carga (soltando): pulsos más débiles y desparejos, alguna explosión que falla y el sonido más apagado.
Salen 7 bucles por capa (F = 32, 55, 95, 160, 270, 450, 750 Hz) de 2,5 s: el juego toma los dos más cercanos y los acelera o frena (±30 %) mezclándolos.
Además: «overrun» (crepitar del escape al soltar con vueltas: el freno motor), «gearwhine» (engranajes rectos: zumbido con armónicos y temblor, no un seno)
y «backfire» (estampido de una explosión en el escape, para pisar y soltar seguido).
Las capas quedan a RMS 0,10 (como los ruidos de fondo): volumen 1,0 = −20 dBFS.
Uso: python3 tools/godot/make_engine_audio.py   (después de make_audio.py: agrega sus datos a consts.json)
"""
import json
import os
import wave
import numpy as np
from scipy.signal import freqz

FS = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "game", "audio", "samples")
REFS = [32.0, 55.0, 95.0, 160.0, 270.0, 450.0, 750.0]  # frecuencias de encendido de cada bucle (Hz): de un V8 en ralentí a un V12 al corte
SECS = 2.5
REF = 0.10
consts = json.load(open(os.path.join(OUT, "consts.json")))


def save(name, x, fs=FS, peak=0.95):
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


def rms(x):
    return float(np.sqrt(np.mean(x ** 2)))


def biquad(kind, f, q, fs=FS):
    w0 = 2 * np.pi * f / fs
    cw, sw = np.cos(w0), np.sin(w0)
    if kind == "bp":
        al = sw / (2 * q)
        b = [al, 0, -al]
    elif kind == "peak":  # (f, q, ganancia en dB) va en q como tupla
        qq, g = q
        A = 10 ** (g / 40)
        al = sw / (2 * qq)
        b = [1 + al * A, -2 * cw, 1 - al * A]
        a = [1 + al / A, -2 * cw, 1 - al / A]
        return b, a
    else:
        al = sw / (2 * 10 ** (q / 20))
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2] if kind == "lp" else [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    a = [1 + al, -2 * cw, 1 - al]
    return b, a


def shape(x, chain, fs=FS):
    """Filtra x circularmente (en frecuencia): resultado exactamente periódico."""
    X = np.fft.rfft(x)
    w = np.linspace(0, np.pi, len(X))
    H = np.ones(len(X), dtype=complex)
    for kind, f, q in chain:
        b, a = biquad(kind, f, q, fs)
        _, h = freqz(b, a, worN=w)
        H = H * h
    return np.fft.irfft(X * H, len(x))


def pulse_train(n, F, r, jitter_t, sigma_a, width_k, miss=0.0, fs=FS, cyl_pat=(1.0, 0.66, 0.9, 0.58)):
    """Pulsos de presión (medio coseno elevado, ancho width_k/F) en posiciones con fluctuación; la suma de los intervalos es exactamente n (bucle sin costura)."""
    k = max(4, int(round(F * n / fs / 4.0)) * 4)  # múltiplo de 4: el patrón de los cilindros cierra justo en el bucle
    iv = 1.0 + r.normal(0.0, jitter_t, k)
    iv = iv / iv.sum() * n
    pos = np.cumsum(iv) - iv[0]
    amp = np.exp(r.normal(0.0, sigma_a, k))
    # cada cilindro empuja un poco distinto (y el cigüeñal da una vuelta cada 2 explosiones): eso da el ronroneo grave por debajo de la frecuencia de encendido
    pat = np.array(cyl_pat)
    amp *= pat[np.arange(k) % len(pat)]
    if miss > 0:
        amp[r.random(k) < miss] *= 0.15  # explosión que falla (sin carga)
    out = np.zeros(n)
    w = max(4, int(width_k * fs / F))
    tt = np.arange(w)
    shp = 0.5 - 0.5 * np.cos(2 * np.pi * tt / w)
    shp = shp - shp.mean() * 0.35  # un poco de succión después del golpe: más «escape», menos zumbido
    for p, a in zip(pos, amp):
        i0 = int(p)
        idx = (i0 + tt) % n
        out[idx] += a * shp
    return out, pos, amp


def env_from(pos, amp, n, tau_s, fs=FS):
    """Envolvente que «respira» con cada explosión (para la admisión): pulsos que se apagan en tau."""
    e = np.zeros(n)
    t = np.arange(int(tau_s * 6 * fs))
    dec = np.exp(-t / (tau_s * fs))
    for p, a in zip(pos, amp):
        idx = (int(p) + t) % n
        e[idx] += a * dec
    return e / (e.max() or 1.0)


def layer(F, on, seed):
    n = int(SECS * FS)
    r = np.random.default_rng(seed)
    if on:
        x, pos, amp = pulse_train(n, F, r, 0.012, 0.14, 0.22)
    else:
        x, pos, amp = pulse_train(n, F, r, 0.03, 0.42, 0.34, miss=0.06, cyl_pat=(1.0, 0.62, 0.86, 0.55))
    # escape: resonancias de los tubos y silenciador (con carga suena más abierto y áspero)
    peaks = [("peak", 115, (1.6, 7)), ("peak", 340, (2.2, 5)), ("peak", 780, (2.5, 3)), ("peak", 1650, (2.0, 2 if on else 0))]
    chain = [("hp", 28, 0.7)] + peaks + [("lp", 2800 if on else 1200, 0.7)]
    y = shape(x, chain)
    y /= rms(y)
    # cuerpo: los primeros armónicos de las explosiones (el «golpe» grave que se siente en el pecho; sin esto suena fino)
    body = shape(x, [("hp", 22, 0.7), ("lp", max(180.0, F * 2.6), 0.9), ("peak", max(45.0, F * 0.5), (1.4, 9)), ("peak", max(70.0, F), (1.0, 3))])
    y = y + (1.7 if on else 1.3) * body / rms(body)
    y /= rms(y)
    if on:
        # admisión: ruido que respira con cada explosión (más con vueltas) y ruido mecánico fino
        e = env_from(pos, amp, n, min(0.004, 0.6 / F))
        intake = shape(r.uniform(-1, 1, n), [("bp", 1500, 0.9), ("lp", 4200, 0.7)]) * (0.35 + 0.65 * e)
        mech = shape(r.uniform(-1, 1, n), [("hp", 2800, 0.7), ("lp", 7000, 0.7)])
        ki = 0.05 + 0.12 * min(1.0, F / 300.0)
        y = y + ki * intake / rms(intake) + 0.03 * mech / rms(mech)
        y = np.tanh(y / 2.4) * 2.4  # saturación suave: el empuje se siente «gordo»
    else:
        y = np.tanh(y / 3.0) * 3.0
    y *= REF / rms(y)
    return y


def overrun():
    """Crepitar del escape soltando con vueltas (freno motor): chasquidos sueltos, graves y agudos, sobre un burbujeo bajo. Bucle de 6 s."""
    n = int(6.0 * FS)
    r = np.random.default_rng(77)
    out = np.zeros(n)
    cnt = r.poisson(9 * 6.0)
    for i in range(cnt):
        p = int(r.integers(0, n))
        ln = int(r.uniform(0.006, 0.03) * FS)
        t = np.arange(ln) / FS
        burst = r.normal(0, 1, ln) * np.exp(-t / r.uniform(0.002, 0.008))
        burst = shape(np.pad(burst, (0, 4096 - ln % 4096)), [("bp", r.uniform(500, 1800), 1.2)])[:ln]
        idx = (p + np.arange(ln)) % n
        out[idx] += burst * np.exp(r.normal(0, 0.6))
    bub = shape(r.uniform(-1, 1, n), [("bp", 180, 1.2), ("lp", 600, 0.7)])
    y = out / rms(out) + 0.6 * bub / rms(bub)
    y = np.tanh(y / 2.5) * 2.5
    y *= REF / rms(y)
    return y


def gearwhine():
    """Engranajes rectos: fundamental + armónicos 2 y 3 + bandas laterales del engrane, con un temblor lento de amplitud (no es un seno quieto). 1,5 s a f = 400 Hz."""
    n = int(1.5 * FS)
    f = 400.0
    t = np.arange(n) / FS
    r = np.random.default_rng(55)
    am = shape(r.normal(0, 1, n), [("lp", 18, 0.7)])
    am = 1.0 + 0.25 * am / (np.max(np.abs(am)) or 1.0)
    y = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * 2 * f * t + 0.6) + 0.18 * np.sin(2 * np.pi * 3 * f * t + 1.1)
         + 0.12 * np.sin(2 * np.pi * (f - 20) * t) + 0.12 * np.sin(2 * np.pi * (f + 20) * t)) * am
    y *= REF / rms(y)
    return y, f


def backfire():
    """Estampido de una explosión en el escape: golpe grave + chasquido, 0,35 s."""
    n = int(0.35 * FS)
    t = np.arange(n) / FS
    r = np.random.default_rng(99)
    boom = np.sin(2 * np.pi * 70 * t * (1 - 0.4 * t)) * np.exp(-t / 0.06)
    crack = r.normal(0, 1, n) * np.exp(-t / 0.012)
    crack = shape(np.pad(crack, (0, 0)), [("bp", 1200, 0.8)])
    y = boom * 1.0 + crack * 0.9
    return np.tanh(y * 1.8)


for i, F in enumerate(REFS):
    save("eng_on%d" % i, layer(F, True, 1000 + i))
    save("eng_off%d" % i, layer(F, False, 2000 + i))
    for nm in ("eng_on%d" % i, "eng_off%d" % i):
        consts[nm]["rms_ref"] = REF
consts["eng_refs"] = REFS
save("overrun", overrun())
consts["overrun"]["rms_ref"] = REF
gw, gwf = gearwhine()
save("gearwhine", gw)
consts["gearwhine"]["rms_ref"] = REF
consts["gearwhine_hz"] = gwf
save("backfire", backfire(), peak=0.9)
json.dump(consts, open(os.path.join(OUT, "consts.json"), "w"), indent=1)
print("listo:", ", ".join(["eng_on/off x%d" % len(REFS), "overrun", "gearwhine", "backfire"]))
