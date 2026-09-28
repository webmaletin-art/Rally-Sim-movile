"""Genera audio/copilot.wav (sprite) + audio/copilot.json con las frases del copiloto.
Uso: python3 tools/gen_copilot.py <ruta/piper> <voz.onnx> [copilot|story]
Voz: piper voice-es-carlfm-x-low (release v0.0.2 de rhasspy/piper)."""
import sys, subprocess, wave, json, tempfile, os
import numpy as np
piper, model = sys.argv[1], sys.argv[2]
SET = sys.argv[3] if len(sys.argv) > 3 else 'copilot'
NUM = ['horquilla', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis']
clips = {}
for i, n in enumerate(NUM):
    for d, w in (('izq', 'izquierda'), ('der', 'derecha')):
        clips[f'{i}{d}'] = f'{n} {w}'
clips.update({'larga': 'larga', 'cierra': 'cierra', 'abre': 'abre', 'y': 'i',
              'cresta': 'cresta', 'vamos': 'vamos, vamos', 'meta': 'meta, buen tramo'})
if SET == 'story':
    clips = {
        'intro': 'Nos encontraron. Arrancá ya, vamos, vamos.',
        'rapido': '¡Más rápido, más rápido!',
        'cerca': '¡Se acercan, los tenemos pegados atrás!',
        'frena': '¡Frená, frená, te pasás de largo!',
        'choque': '¡Nos chocaron! Aguantá.',
        'cuidado': '¡Cuidado, nos quieren encerrar!',
        'rampa': '¡Agarrate, viene la rampa!',
        'salto': '¡Qué salto! Seguí, seguí.',
        'derrape': '¡Cruzalo, cruzalo! Así.',
        'tierra': 'Tierra suelta, abrí las manos.',
        'tunel': '¡A la mina, metete al túnel!',
        'control': 'Ahora manejás vos. Sacanos de acá.',
        'izq': '¡Por la izquierda!',
        'der': '¡Por la derecha!',
        'aguanta': 'No los dejes pasar, tapales el camino.',
        'dano': '¡El auto no aguanta mucho más!',
        'salida': 'Ya se ve la salida, dale.',
        'lolograste': '¡Salimos! Lo logramos, los perdimos.',
        'fallo': 'Se acabó. Nos atraparon.',
        'proximamente': 'Siguiente misión, próximamente.',
    }
SR = 16000
out, meta = [], {}
pos = 0
for key, text in clips.items():
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        path = f.name
    subprocess.run([piper, '-m', model, '-f', path, '--length_scale', '0.9', '--sentence_silence', '0'],
                   input=text.encode(), check=True, capture_output=True)
    with wave.open(path) as w:
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    os.unlink(path)
    thr = 0.05 * np.abs(a).max()
    idx = np.where(np.abs(a) > thr)[0]
    a = a[max(0, idx[0] - 160):min(len(a), idx[-1] + 480)]
    a = a / max(1, np.abs(a).max()) * 30000
    fade = min(160, len(a) // 4)
    a[:fade] *= np.linspace(0, 1, fade); a[-fade:] *= np.linspace(1, 0, fade)
    meta[key] = [round(pos / SR, 4), round(len(a) / SR, 4)]
    out.append(a.astype(np.int16)); out.append(np.zeros(800, np.int16))
    pos += len(a) + 800
root = os.path.join(os.path.dirname(__file__), '..', 'audio')
with wave.open(os.path.join(root, SET + '.wav'), 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(np.concatenate(out).tobytes())
json.dump(meta, open(os.path.join(root, SET + '.json'), 'w'))
print(len(meta), 'clips', round(pos / SR, 1), 's')
