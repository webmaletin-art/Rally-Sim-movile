#!/usr/bin/env python3
"""Arma la página del informe de optimización (autos, árboles y autos civiles) con las imágenes y números que generaron los otros scripts de tools/report.
Uso: python3 build_report.py <salida.html>   (espera /tmp/claude-0/{cars,civil,trees,car_stats.json})"""
import base64, io, json, os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
G = os.path.join(ROOT, 'godot', 'game')
OUT = sys.argv[1]
T = '/tmp/claude-0'
BG = (122, 148, 172)

def b64(path, size, q=70):
    im = Image.open(path).convert('RGBA')
    bg = Image.new('RGBA', im.size, BG + (255,))
    bg.alpha_composite(im)
    im = bg.convert('RGB').resize(size, Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=q, optimize=True)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()

veh = json.load(open(os.path.join(G, 'data', 'vehicles.json')))
cat = json.load(open(os.path.join(G, 'data', 'catalog.json')))['cars']
stats = json.load(open(T + '/car_stats.json'))
var = json.load(open(T + '/cars/variants.json'))
civ = json.load(open(T + '/civil/variants.json'))
bench = {'heavy': 834.0, 'pap': 118.0, 'cross': 28.4, 'photo': 18.6, 'blur': 15.3}

def kb(p):
    return os.path.getsize(p) / 1024.0

def glb_info(vid):
    vt = veh[vid]['visualType']
    if vt in ('genesis', 't1plus'):
        return os.path.join(G, 'models', 'volt_body.glb'), os.path.join(G, 'models', 'volt_body_lo.glb'), os.path.join(G, 'models', 'volt_wheel.glb'), os.path.join(G, 'models', 'volt_wheel_lo.glb')
    return os.path.join(G, 'models', 'cars', vt + '.glb'), os.path.join(G, 'models', 'cars', vt + '_lo.glb'), None, None

def car_name(vid):
    if vid == 'genesis_glb':
        return 'Genesis (modelo propio)'
    c = cat.get(vid, {})
    return ('%s %s' % (c.get('brand', ''), c.get('model', vid))).strip()

STYLES = [('hi', 'Alta (hoy, jugador)'), ('lo', 'Baja (hoy, rivales)'), ('cajas', 'Cajas apiladas'), ('rampas', 'Cajas con rampas'), ('lowpoly', 'Low-poly'), ('papel', 'Papercraft')]
car_ids = ['genesis_glb'] + [k for k in veh]

def tris_of(vid, sty):
    if sty in ('hi', 'lo'):
        key = 'genesis' if vid == 'genesis_glb' else vid
        if vid == 'genesis_glb':
            return 30000 + 4 * 5964 if sty == 'hi' else 9000 + 4 * 1497
        return stats[key][sty]['tris']
    return var[vid][sty]

def fmt(n):
    return '{:,}'.format(int(n)).replace(',', ' ')

# ---------- tabla de autos con imágenes ----------
rows = []
for vid in car_ids:
    cells = []
    for s, _ in STYLES:
        im = b64('%s/cars/img/%s_%s.png' % (T, vid, s), (240, 150), 66)
        cells.append('<td><img alt="%s %s" src="%s" width="120" height="75"><span class="n">%s</span></td>' % (car_name(vid), s, im, fmt(tris_of(vid, s))))
    rows.append('<tr><th scope="row">%s</th>%s</tr>' % (car_name(vid), ''.join(cells)))
cars_table = '\n'.join(rows)

# ---------- tabla de peso y consumo ----------
rows = []
sum_hi = sum_lo = 0
for vid in car_ids:
    if vid == 'genesis_glb':
        mass = veh['genesis']['mass']
        hi_kb, lo_kb = 901 + 4 * 139, 272 + 4 * 35
        hi_t, lo_t = tris_of(vid, 'hi'), tris_of(vid, 'lo')
        draws_hi, draws_lo = '–', '–'
        note = 'sin usar hoy'
    else:
        mass = veh[vid]['mass']
        b_hi, b_lo, w_hi, w_lo = glb_info(vid)
        hi_kb = kb(b_hi) + (4 * kb(w_hi) if w_hi else 0)
        lo_kb = kb(b_lo) + (4 * kb(w_lo) if w_lo else 0)
        hi_t, lo_t = tris_of(vid, 'hi'), tris_of(vid, 'lo')
        draws_hi, draws_lo = stats[vid]['hi']['surfaces'], stats[vid]['lo']['surfaces']
        note = ''
        sum_hi += hi_t
        sum_lo += lo_t
    rows.append('<tr><th scope="row">%s</th><td class="r">%s</td><td class="r">%s</td><td class="r">%s</td><td class="r">%s</td><td class="r">%s</td><td class="r">%s</td><td class="r">%d</td><td class="r">%d</td></tr>' % (
        car_name(vid) + (' <small>(%s)</small>' % note if note else ''), fmt(mass), fmt(round(hi_kb)), fmt(hi_t), draws_hi, fmt(round(lo_kb)), fmt(lo_t), var[vid]['cajas'] + 0, var[vid]['papel']))
n_real = len([v for v in car_ids if v != 'genesis_glb'])
avg_hi, avg_lo = sum_hi / n_real, sum_lo / n_real
weights_table = '\n'.join(rows)

# ---------- árboles ----------
tr = json.load(open(T + '/trees/report.json'))
pap_cat = {c['id']: c for c in json.load(open(os.path.join(G, 'models', 'paper', 'catalog.json')))}
LIB = os.path.join(ROOT, 'biblioteca', 'vegetacion_y_suelo')
NAMES = {'sc_acacia': 'Acacia', 'sc_coconut_tree': 'Cocotero', 'sc_cypress': 'Ciprés', 'sc_palm_tree': 'Palmera (SC)', 'sc_pine': 'Pino (SC)', 'tree_birch': 'Abedul',
         'tree_black_tupelo': 'Tupelo negro', 'tree_christmas_tree': 'Árbol de Navidad', 'tree_lombardy_poplar': 'Álamo de Lombardía', 'tree_palm_tree': 'Palmera',
         'tree_quaking_aspen': 'Álamo temblón', 'tree_sassafras': 'Sasafrás', 'tree_tree': 'Árbol de hoja ancha (pack)', 'tree_weeping_willow': 'Sauce llorón', 'sc_bamboo': 'Bambú',
         'pino': 'Pino (procedural)', 'pino_nevado': 'Pino nevado', 'abedul': 'Abedul (procedural)', 'alamo': 'Álamo (procedural)', 'arbol_hoja_ancha': 'Hoja ancha (procedural)',
         'arbol_seco': 'Árbol seco', 'palmera': 'Palmera (procedural)', 'arbusto': 'Arbusto', 'cactus': 'Cactus',
         'd_bambu_verde': 'Bambú verde (Dream)', 'd_bambu_dorado': 'Bambú dorado (Dream)', 'd_bambu_rosado': 'Bambú rosado (Dream)', 'd_sakura_rosa': 'Sakura rosa (Dream)',
         'd_sakura_blanco': 'Sakura blanco (Dream)', 'd_sakura_intenso': 'Sakura intenso (Dream)', 'd_jacaranda': 'Jacarandá (Dream)', 'd_arce_dorado': 'Arce dorado (Dream)',
         'd_arbol_coral': 'Árbol coral (Dream)', 'd_arbol_turquesa': 'Árbol turquesa (Dream)', 'd_arbol_burbujas': 'Árbol de burbujas (Dream)', 'd_arbol_burbujas2': 'Árbol de burbujas 2 (Dream)'}
groups = [('Pack de árboles (modelo pesado de unos 3 000 triángulos)', [r['id'] for r in tr if r['id'].startswith(('sc_', 'tree_'))]),
          ('Procedurales del juego (ya livianos)', [r['id'] for r in tr if r['id'] in ('pino', 'pino_nevado', 'abedul', 'alamo', 'arbol_hoja_ancha', 'arbol_seco', 'palmera', 'arbusto', 'cactus')]),
          ('Flora del mapa Dream (sólo existe en papel)', [r['id'] for r in tr if r['id'].startswith('d_')])]
rec = {r['id']: r for r in tr}
tree_sections = []
for title, ids in groups:
    rows = []
    for tid in ids:
        r = rec[tid]
        pap_kb = kb(os.path.join(G, 'models', 'paper', tid + '.pap'))
        has3d = os.path.exists('%s/trees/%s_3d.png' % (T, tid))
        heavy_kb = ''
        if has3d:
            src = pap_cat[tid]['source'].split(' ')[0]
            gp = os.path.join(LIB, src) if not src.startswith('procedural') else os.path.join(LIB, 'procedural_arboles_y_plantas', tid + '.glb')
            if os.path.exists(gp):
                heavy_kb = '%d KB' % round(kb(gp))
        def im(kind, ok=True):
            p = '%s/trees/%s_%s.png' % (T, tid, kind)
            if not os.path.exists(p):
                return '<td class="none">sin modelo pesado</td>'
            return '<td><img alt="%s %s" src="%s" width="76" height="76"></td>' % (NAMES.get(tid, tid), kind, b64(p, (152, 152), 70))
        c3d = im('3d')
        cells = [
            c3d.replace('</td>', '<span class="n">%s tri · %s</span></td>' % (fmt(r['heavy_tris']), heavy_kb)) if has3d else c3d,
            im('pap').replace('</td>', '<span class="n">%s tri · %d KB</span></td>' % (fmt(r['paper_tris']), round(pap_kb))),
            (im('3d') if has3d else im('pap')).replace('</td>', '<span class="n">2 tri</span></td>'),
            im('ilus').replace('</td>', '<span class="n">2 tri</span></td>'),
            im('blur').replace('</td>', '<span class="n">2 tri</span></td>'),
        ]
        rows.append('<tr><th scope="row">%s</th>%s</tr>' % (NAMES.get(tid, tid), ''.join(cells)))
    tree_sections.append('<h3>%s</h3><div class="scroll"><table class="gal"><thead><tr><th>Árbol</th><th>3D pesado</th><th>Papercraft</th><th>Foto recortada</th><th>2D ilustrado</th><th>Difuminado</th></tr></thead><tbody>%s</tbody></table></div>' % (title, '\n'.join(rows)))
trees_html = '\n'.join(tree_sections)

# ---------- autos civiles ----------
civ_rows = []
for vid, nm in (('hatch', 'Compacto'), ('muscle', 'Sedán'), ('suv', 'Camioneta')):
    cells = []
    for s in ('actual', 'cajas', 'rampas', 'lowpoly', 'papel'):
        n = 84 if s == 'actual' else civ[vid][s]
        cells.append('<td><img alt="%s %s" src="%s" width="120" height="75"><span class="n">%s tri</span></td>' % (nm, s, b64('%s/civil/img/%s_%s.png' % (T, vid, s), (240, 150), 66), n))
    civ_rows.append('<tr><th scope="row">%s</th>%s</tr>' % (nm, ''.join(cells)))
civil_table = '\n'.join(civ_rows)

def bar(label, ms, pct, note, cls=''):
    return '<div class="bar %s"><div class="bl"><b>%s</b><span>%s</span></div><div class="track"><i style="width:%.1f%%"></i></div><div class="bn">%s</div></div>' % (cls, label, ms, max(pct, 1.2), note)

bars = ''.join([
    bar('3D pesado (modelo original)', '%d ms' % bench['heavy'], 100, '6,7 millones de triángulos · 13 llamadas de dibujo'),
    bar('Papercraft (el actual)', '%d ms' % bench['pap'], bench['pap'] / bench['heavy'] * 100, '434 mil triángulos · 6 llamadas'),
    bar('Cruz de 2 cartas', '%.0f ms' % bench['cross'], bench['cross'] / bench['heavy'] * 100, '6 mil triángulos · 6 llamadas'),
    bar('Foto recortada (carta que mira a la cámara)', '%.0f ms' % bench['photo'], bench['photo'] / bench['heavy'] * 100, '3 mil triángulos · 6 llamadas'),
    bar('Difuminado (con transparencia suave)', '%.0f ms' % bench['blur'], bench['blur'] / bench['heavy'] * 100, '3 mil triángulos · 6 llamadas'),
])

s_hi, s_lo = avg_hi, avg_lo
scen = [('Hoy: jugador en alta + 5 rivales en baja', s_hi + 5 * s_lo),
        ('Rivales en papercraft', s_hi + 5 * 1292),
        ('Rivales en cajas con rampas', s_hi + 5 * 188),
        ('Rivales en cajas con rampas y jugador con ruedas simples (−12 000)', s_hi - 12000 + 5 * 188)]
base = scen[0][1]
scen_rows = ''.join('<tr><th scope="row">%s</th><td class="r">%s</td><td class="r">%s</td></tr>' % (n, fmt(round(v, -2)), '–' if i == 0 else '−%d %%' % round((1 - v / base) * 100)) for i, (n, v) in enumerate(scen))

civ_scen = ''.join('<tr><th scope="row">%s</th><td class="r">%s</td><td class="r">%s</td></tr>' % (n, fmt(116 * t), p) for n, t, p in [
    ('Actual (7 cajas)', 84, '–'), ('Cajas apiladas', civ['hatch']['cajas'], '+%d %%' % round((civ['hatch']['cajas'] / 84 - 1) * 100)), ('Cajas con rampas', civ['hatch']['rampas'], '+%d %%' % round((civ['hatch']['rampas'] / 84 - 1) * 100)),
    ('Low-poly', civ['hatch']['lowpoly'], '×%.1f' % (civ['hatch']['lowpoly'] / 84)), ('Papercraft', civ['hatch']['papel'], '×%.1f' % (civ['hatch']['papel'] / 84))])

legend = [
    ('Alta (hoy)', '41 000 – 57 000 triángulos por auto', 'Carrocería de 24 000 + ruedas con goma y llanta (unos 4 600 cada una). La usa el auto del jugador.'),
    ('Baja (hoy)', '10 000 – 13 000', 'Carrocería de 5 000 + ruedas simplificadas. La usan los rivales. Las ruedas son más de la mitad.'),
    ('Cajas apiladas', '120', 'Siete bloques que siguen la silueta (capó, cabina, techo) y cuatro ruedas de caja. Estilo más «cubo».'),
    ('Cajas con rampas', '188', 'Bloques unidos con rampas: parabrisas y luneta inclinados, ruedas de ocho lados.'),
    ('Low-poly', '540', 'La carrocería se rellena y se simplifica a unas 400 caras planas. Se reconoce el modelo.'),
    ('Papercraft', '1 292', 'Unas 1 100 caras con color liso y borde de papel, como el resto del mundo Dream. Es lo más fiel con pocos triángulos.'),
]
legend_html = ''.join('<tr><th scope="row">%s</th><td>%s</td><td>%s</td></tr>' % l for l in legend)

glg = ''.join('<figure><img alt="Genesis %s" src="%s" width="200" height="125"><figcaption><b>%s</b><span>%s tri</span></figcaption></figure>' % (lbl, b64('%s/cars/img/genesis_glb_%s.png' % (T, s), (400, 250), 72), lbl, fmt(tris_of('genesis_glb', s))) for s, lbl in STYLES)

html = open(os.path.join(os.path.dirname(__file__), 'report_template.html'), encoding='utf-8').read()
for k, v in {'{{CARS_TABLE}}': cars_table, '{{WEIGHTS}}': weights_table, '{{TREES}}': trees_html, '{{CIVIL_TABLE}}': civil_table, '{{BARS}}': bars, '{{SCEN}}': scen_rows,
             '{{CIVSCEN}}': civ_scen, '{{LEGEND}}': legend_html, '{{GENESIS}}': glg, '{{AVG_HI}}': fmt(round(avg_hi, -2)), '{{AVG_LO}}': fmt(round(avg_lo, -2))}.items():
    html = html.replace(k, v)
open(OUT, 'w', encoding='utf-8').write(html)
print('listo', OUT, round(len(html) / 1e6, 2), 'MB')
