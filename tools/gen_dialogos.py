"""Genera las voces de un diccionario de diálogos: {clave: [{"t": texto, "i": intensidad}, ...]}
Cada frase queda en audio/<nombre>/<clave>_<n>.ogg (11 kHz, mono, Vorbis: la radio del intercom corta arriba de 3,6 kHz) + audio/<nombre>.json (índice).
Uso: python3 tools/gen_dialogos.py <piper> <voz.onnx> <dialogos.json> <nombre> [length_scale]
Voz: piper voice-es-carlfm-x-low (release v0.0.2 de rhasspy/piper)."""
import sys, subprocess, wave, json, os, tempfile
import numpy as np, soundfile as sf
piper, model, src, name = sys.argv[1:5]
LS = float(sys.argv[5]) if len(sys.argv) > 5 else 0.9
D = json.load(open(src, encoding='utf-8'))
root = os.path.join(os.path.dirname(__file__), '..', 'audio')
outd = os.path.join(root, name); os.makedirs(outd, exist_ok=True)
for f in os.listdir(outd):
    if f.endswith('.ogg'): os.unlink(os.path.join(outd, f))
tmp = tempfile.mkdtemp()
jobs = []
for k, lst in D.items():
    for n, x in enumerate(lst):
        jobs.append((k, n, x, os.path.join(tmp, f'{k}_{n}.wav')))
# urgentes un poco más rápidas
for ls in sorted(set(LS * (0.9 if x.get('i', 2) >= 3 else 1.0) for _, _, x, _ in jobs)):
    lines = '\n'.join(json.dumps({'text': x['t'], 'output_file': p}, ensure_ascii=False)
                      for _, _, x, p in jobs if abs(LS * (0.9 if x.get('i', 2) >= 3 else 1.0) - ls) < 1e-6)
    subprocess.run([piper, '-m', model, '--json-input', '--length_scale', str(ls), '--sentence_silence', '0'],
                   input=lines.encode('utf-8'), check=True, capture_output=True)
SR = 11025
idx = {}; total = 0; tsec = 0
for k, n, x, p in jobs:
    with wave.open(p) as w:
        sr = w.getframerate(); a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    if sr != SR:
        a = np.interp(np.arange(0, len(a), sr / SR), np.arange(len(a)), a)
    thr = 0.05 * np.abs(a).max(); ii = np.where(np.abs(a) > thr)[0]
    a = a[max(0, ii[0] - 160):min(len(a), ii[-1] + 480)]
    a = a / max(1, np.abs(a).max()) * (0.95 if x.get('i', 2) >= 3 else 0.85)
    fade = min(160, len(a) // 4); a[:fade] *= np.linspace(0, 1, fade); a[-fade:] *= np.linspace(1, 0, fade)
    fn = f'{k}_{n}.ogg'; sf.write(os.path.join(outd, fn), a.astype(np.float32), SR, format='OGG', subtype='VORBIS', compression_level=0.8)
    idx.setdefault(k, []).append([fn, x.get('i', 2), round(len(a) / SR, 3), x['t']])
    total += os.path.getsize(os.path.join(outd, fn)); tsec += len(a) / SR
json.dump(idx, open(os.path.join(root, name + '.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print(len(jobs), 'frases', round(tsec / 60, 1), 'min', round(total / 1e6, 2), 'MB')
