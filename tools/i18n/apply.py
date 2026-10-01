"""Aplica las traducciones de tools/i18n/batches/*.py (cada una define T = {español: (en, pt[, fr, it, de])}) a godot/game/i18n/<código>.json.
Uso: python3 tools/i18n/apply.py   (después de extract.py)"""
import glob, importlib.util, json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
I18N = os.path.join(ROOT, 'godot', 'game', 'i18n')
LANGS = ['en', 'pt', 'fr', 'it', 'de']

def main():
    tr = {}
    for f in sorted(glob.glob(os.path.join(os.path.dirname(__file__), 'batches', '*.py'))):
        spec = importlib.util.spec_from_file_location(os.path.basename(f)[:-3], f)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        for k, v in m.T.items():
            tr.setdefault(k, {}).update({LANGS[i]: s for i, s in enumerate(v) if s})
    for lg in LANGS:
        p = os.path.join(I18N, lg + '.json')
        cur = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
        n = 0
        for k, v in tr.items():
            if lg in v and cur.get(k) != v[lg]:
                cur[k] = v[lg]
                n += 1
        json.dump(cur, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
        print(lg, 'actualizadas', n, '· total con traducción', sum(1 for v in cur.values() if v), 'de', len(cur))

if __name__ == '__main__':
    main()
