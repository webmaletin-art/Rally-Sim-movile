"""Extrae los textos en español del juego (GDScript y JSON de datos) y los vuelca a game/i18n/<código>.json.
Cada idioma es {"texto en español": "traducción"}; lo que no está traducido queda con "" (el juego muestra el español).
Uso:  python3 tools/i18n/extract.py            # agrega las claves nuevas a todos los idiomas, sin tocar lo traducido
      python3 tools/i18n/extract.py --report   # solo cuenta lo que falta"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
GAME = os.path.join(ROOT, 'godot', 'game')
I18N = os.path.join(GAME, 'i18n')
LANGS = ['en', 'pt', 'fr', 'it', 'de']
SKIP_DIRS = {'i18n', 'models', 'audio_data'}
# archivos de diagnóstico, esqueletos y nombres propios: no se traducen
SKIP_FILES = {'ui/debug_panel.gd', 'car/rig_pilot.gd', 'car/pilot.gd', 'data/ai_cars.gd', 'session.gd', 'ui/ui_selector.gd'}
SKIP_EXACT = {'Head', 'Hips', 'Left', 'Right', 'Index', 'Middle', 'Ring', 'Pinky', 'Thumb', 'Spine', 'Neck', 'Shoulder', 'Hand', 'Foot', 'Body', 'Crew', 'Processor', 'model name', 'Hardware'}
# claves de los JSON de datos que llevan texto para mostrar
JSON_TEXT_KEYS = {'lo', 'hi', 'name', 'n', 'info', 'desc', 'tagline', 'kind', 'engine', 'brand', 'model', 'title', 'text', 'sub', 'label', 'tip', 'bio', 'req'}

SPANISH_MARK = re.compile(r'[áéíóúñÁÉÍÓÚÑ¿¡]')

def is_text(s: str) -> bool:
    s = s.strip()
    if s in SKIP_EXACT or 'shader_type' in s or 'render_mode' in s or 'uniform ' in s or 'vec2' in s:
        return False
    if len(s) < 3 or '://' in s or s.startswith('res:') or s.startswith('#') or s.startswith('user:'):
        return False
    if re.fullmatch(r'[a-z0-9_.\-/:]+', s):          # identificadores, rutas, ids
        return False
    if re.fullmatch(r'[%0-9a-z .:/\-+*_()\[\]\']*', s) and not SPANISH_MARK.search(s) and ' ' not in s.strip():
        return False
    if not re.search(r'[A-Za-záéíóúñÁÉÍÓÚÑ]{3,}', s):
        return False
    # texto «de verdad»: espacios, signos, acentos o una palabra con mayúscula inicial
    return (' ' in s) or bool(SPANISH_MARK.search(s)) or bool(re.fullmatch(r'[A-ZÁÉÍÓÚÑ][a-záéíóúñ]{3,}', s)) or bool(re.fullmatch(r'[A-ZÁÉÍÓÚÑ ]{4,}', s))

def gd_strings(src: str):
    """Literales de cadena del GDScript (sin comentarios). Devuelve (texto, línea)."""
    out = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1; i += 1
        elif c == '#':
            while i < n and src[i] != '\n':
                i += 1
        elif src.startswith('"""', i) or src.startswith("'''", i):
            q = src[i:i + 3]
            j = src.find(q, i + 3)
            j = n if j < 0 else j
            out.append((src[i + 3:j], line))
            line += src[i:j].count('\n')
            i = j + 3
        elif c in '"\'':
            j = i + 1
            buf = []
            while j < n and src[j] != c and src[j] != '\n':
                if src[j] == '\\' and j + 1 < n:
                    e = src[j + 1]
                    buf.append({'n': '\n', 't': '\t', '"': '"', "'": "'", '\\': '\\'}.get(e, '\\' + e))
                    j += 2
                else:
                    buf.append(src[j]); j += 1
            out.append((''.join(buf), line))
            i = j + 1
        else:
            i += 1
    return out

def collect():
    found = {}
    for dp, dns, fns in os.walk(GAME):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for fn in fns:
            p = os.path.join(dp, fn)
            rel = os.path.relpath(p, GAME)
            if fn.endswith('.gd') and rel.replace(os.sep, '/') not in SKIP_FILES:
                for s, ln in gd_strings(open(p, encoding='utf-8').read()):
                    if is_text(s):
                        found.setdefault(s, []).append('%s:%d' % (rel, ln))
            elif fn.endswith('.json') and 'data' in rel.split(os.sep)[:1]:
                def walk(o, key=''):
                    if isinstance(o, dict):
                        for k, v in o.items():
                            walk(v, k)
                    elif isinstance(o, list):
                        for v in o:
                            walk(v, key)
                    elif isinstance(o, str) and key in JSON_TEXT_KEYS and is_text(o):
                        found.setdefault(o, []).append(rel)
                walk(json.load(open(p, encoding='utf-8')))
    return found

def main():
    found = collect()
    report = '--report' in sys.argv
    os.makedirs(I18N, exist_ok=True)
    for lg in LANGS:
        p = os.path.join(I18N, lg + '.json')
        cur = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
        new = [k for k in found if k not in cur]
        done = sum(1 for k in found if cur.get(k))
        print('%s: %d textos · %d traducidos · %d nuevos' % (lg, len(found), done, len(new)))
        if not report:
            for k in new:
                cur[k] = ''
            keep = {k: cur[k] for k in sorted(cur, key=lambda s: (s not in found, s))}
            json.dump(keep, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    json.dump({k: found[k][:3] for k in sorted(found)}, open(os.path.join(ROOT, 'tools', 'i18n', 'refs.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)

if __name__ == '__main__':
    main()
