#!/usr/bin/env python3
"""Guía hablada del Modo de prueba: qué audios faltan grabar y el guion completo.

El juego muestra cada línea del guion (godot/game/data/guide_script.json) como subtítulo y, si existe su audio, lo reproduce con la voz:
    godot/game/audio/guide/<idioma>/<id>.ogg   (también .mp3 o .wav)
Si falta el audio en un idioma se usa el de es/; si falta también, queda sólo el subtítulo (el juego anda igual).

Uso:
    python3 tools/audio/guide_voice_todo.py                 # qué audios faltan (es) y cuántos hay en cada idioma
    python3 tools/audio/guide_voice_todo.py --lang en       # qué faltan en inglés (también pt, fr, it, de)
    python3 tools/audio/guide_voice_todo.py --txt es        # todas las líneas «id | texto» listas para pegar en un programa de voz (o --txt en, pt…)
    python3 tools/audio/guide_voice_todo.py --md            # vuelve a armar docs/GUION_VOZ_GUIA.md con el guion y las traducciones
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SCRIPT = os.path.join(ROOT, 'godot', 'game', 'data', 'guide_script.json')
CLIPS = os.path.join(ROOT, 'godot', 'game', 'audio', 'guide')
I18N = os.path.join(ROOT, 'godot', 'game', 'i18n')
EXTS = ('.ogg', '.mp3', '.wav')
LANGS = ['es', 'en', 'pt', 'fr', 'it', 'de']
NAMES = {'es': 'Español (rioplatense)', 'en': 'English', 'pt': 'Português', 'fr': 'Français', 'it': 'Italiano', 'de': 'Deutsch'}


def lines():
    return json.load(open(SCRIPT, encoding='utf-8'))['lines']


def text_of(line, lang):
    if lang == 'es':
        return line['es']
    p = os.path.join(I18N, lang + '.json')
    tr = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
    return tr.get(line['es']) or line['es']


def clip_of(lid, lang):
    for ext in EXTS:
        p = os.path.join(CLIPS, lang, lid + ext)
        if os.path.exists(p):
            return p
    return None


def report(lang):
    ls = lines()
    missing = [l for l in ls if not clip_of(l['id'], lang)]
    print('%s: %d de %d audios grabados · faltan %d' % (NAMES[lang], len(ls) - len(missing), len(ls), len(missing)))
    for l in missing:
        print('  %-18s %s.ogg   «%s»' % (l['id'], l['id'], text_of(l, lang)[:90]))
    if lang != 'es':
        print('  (lo que falta acá se escucha con la voz de es/ si existe; si no, queda sólo el subtítulo)')


def txt(lang):
    for l in lines():
        print('%s | %s' % (l['id'], text_of(l, lang)))


def md():
    ls = lines()
    out = []
    out.append('# Guion de la voz del Modo de prueba (guía de Claudio)\n')
    out.append('Generado por `python3 tools/audio/guide_voice_todo.py --md` desde `godot/game/data/guide_script.json`: **si cambiás un texto, cambialo en el JSON** y volvé a generar este archivo.\n')
    out.append('## Cómo funciona\n')
    out.append('- Cada línea de abajo se muestra como **subtítulo** (abajo en el medio jugando; a la derecha en los menús y la pausa) con el nombre «🎓 CLAUDIO».')
    out.append('- Si existe su **audio** en `godot/game/audio/guide/<idioma>/<id>.ogg` (también `.mp3` o `.wav`), se escucha con la voz mientras se ve el subtítulo. El subtítulo dura lo que dura el audio.')
    out.append('- **Sin audio no pasa nada malo:** se ve sólo el texto. Se pueden ir sumando grabaciones de a poco, sin tocar código.')
    out.append('- Si falta el audio en un idioma (en, pt, fr, it, de) se usa el de `es/`; si no hay tampoco, queda el subtítulo (traducido).')
    out.append('- Cada línea se dice **una sola vez por sesión** (salvo que el jugador la vuelva a provocar, p. ej. elegir otra vez un auto en el armado). Si el jugador toca algo mientras Claudio habla, la línea nueva corta la vieja.')
    out.append('- El jugador elige cómo escucharla con el botón **GUÍA** (🔊 voz y texto · 💬 sólo texto · 🔇 apagada); se guarda en el perfil (`guideMode`).\n')
    out.append('## Cómo grabar\n')
    out.append('1. Un archivo por línea, con **exactamente** el nombre de la columna «archivo» (`welcome.ogg`, `car_gt.ogg`…). Formato recomendado: **OGG Vorbis, mono, 44,1 kHz, calidad 4–5** (unos 20–60 KB por línea; todas pesan ~2 MB). Sirve también MP3 o WAV.')
    out.append('2. Poné los archivos en `godot/game/audio/guide/es/` (español). Para otro idioma, en `godot/game/audio/guide/en/`, `pt/`, `fr/`, `it/` o `de/` con los mismos nombres.')
    out.append('3. Verificá qué falta: `python3 tools/audio/guide_voice_todo.py` (o `--lang en`). Para pegar todos los textos en un programa de voz: `python3 tools/audio/guide_voice_todo.py --txt es`.')
    out.append('4. Subí los archivos al repositorio (commit y push). No hay que cambiar nada más: el APK nuevo los trae y la voz suena sola.')
    out.append('5. Tono: cercano y tranquilo, como un instructor que acompaña; frases cortas; no hace falta leer los símbolos ni los emojis. Que el volumen de todas las líneas sea parecido.\n')
    out.append('## Líneas del guion (español)\n')
    out.append('| archivo | cuándo se dice | texto |')
    out.append('|---|---|---|')
    for l in ls:
        out.append('| `%s.ogg` | %s | %s |' % (l['id'], l['ctx'], l['es'].replace('|', '\\|')))
    out.append('')
    for lang in LANGS[1:]:
        out.append('## %s (subtítulos y guion para grabar en ese idioma)\n' % NAMES[lang])
        out.append('| archivo | texto |')
        out.append('|---|---|')
        for l in ls:
            out.append('| `%s.ogg` | %s |' % (l['id'], text_of(l, lang).replace('|', '\\|')))
        out.append('')
    open(os.path.join(ROOT, 'docs', 'GUION_VOZ_GUIA.md'), 'w', encoding='utf-8').write('\n'.join(out))
    print('docs/GUION_VOZ_GUIA.md armado con %d líneas en %d idiomas' % (len(ls), len(LANGS)))


def main(argv):
    if '--md' in argv:
        md()
    elif '--txt' in argv:
        i = argv.index('--txt')
        txt(argv[i + 1] if i + 1 < len(argv) else 'es')
    elif '--lang' in argv:
        i = argv.index('--lang')
        report(argv[i + 1] if i + 1 < len(argv) else 'es')
    else:
        for lang in LANGS:
            if lang == 'es':
                report('es')
            else:
                have = sum(1 for l in lines() if clip_of(l['id'], lang))
                print('%s: %d de %d audios propios (el resto usa la voz de es/)' % (NAMES[lang], have, len(lines())))


if __name__ == '__main__':
    main(sys.argv[1:])
