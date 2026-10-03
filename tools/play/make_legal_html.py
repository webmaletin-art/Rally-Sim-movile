"""Convierte docs/PRIVACIDAD.md y docs/TERMINOS.md en páginas web (docs/privacidad.html y docs/terminos.html) para pegar la URL en Play Console.
GitHub Pages las publica en https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html
Uso: python3 tools/play/make_legal_html.py   (correrlo cada vez que se cambien los .md)"""
import html, os, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

def inline(t):
    t = html.escape(t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', t)
    t = re.sub(r'`(.+?)`', r'<code>\1</code>', t)
    t = re.sub(r'\*(.+?)\*', r'<i>\1</i>', t)
    return t

def convert(md):
    out, in_ul = [], False
    for line in md.splitlines():
        if line.startswith('- '):
            if not in_ul:
                out.append('<ul>'); in_ul = True
            out.append('<li>%s</li>' % inline(line[2:]))
            continue
        if in_ul:
            out.append('</ul>'); in_ul = False
        m = re.match(r'^(#{1,3}) (.*)', line)
        if m:
            n = len(m.group(1)); out.append('<h%d>%s</h%d>' % (n, inline(m.group(2)), n))
        elif line.startswith('> '):
            continue  # notas internas para el equipo: no se publican
        elif line.strip() == '---':
            out.append('<hr>')
        elif re.match(r'^\d+\. ', line):
            out.append('<p>%s</p>' % inline(line))
        elif line.strip():
            out.append('<p>%s</p>' % inline(line.strip()))
    if in_ul:
        out.append('</ul>')
    return '\n'.join(out)

PAGE = '''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>%s · Dream Racing</title>
<style>body{font:16px/1.55 system-ui,sans-serif;max-width:760px;margin:0 auto;padding:20px 16px 60px;color:#1c2330;background:#fff}
h1{color:#d9560a}h2{margin-top:2em;border-bottom:2px solid #f2f2f2;padding-bottom:.2em}h3{margin-bottom:.2em}code{background:#f2f2f2;padding:0 4px;border-radius:4px}
@media(prefers-color-scheme:dark){body{background:#0e1420;color:#e6ebf3}h2{border-color:#243049}code{background:#1b2638}}</style></head>
<body>%s</body></html>'''

for src, dst, title in [('PRIVACIDAD.md', 'privacidad.html', 'Política de privacidad'), ('TERMINOS.md', 'terminos.html', 'Términos de uso'), ('ELIMINAR_CUENTA.md', 'eliminar-cuenta.html', 'Eliminar la cuenta y los datos')]:
    md = open(os.path.join(ROOT, 'docs', src), encoding='utf-8').read()
    open(os.path.join(ROOT, 'docs', dst), 'w', encoding='utf-8').write(PAGE % (title, convert(md)))
    print('docs/' + dst)
