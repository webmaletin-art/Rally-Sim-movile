#!/usr/bin/env python3
"""Arma supabase/migrations/20261007010000_online_economy.sql a partir de economy_template.sql + online_catalog.json (que sale de export_catalog.gd).
Uso: python3 tools/online/gen_economy_sql.py   (desde la raíz del repo). Las semillas usan «on conflict do update»: si el catálogo cambia, se genera una migración nueva con las mismas semillas."""
import json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
cat = json.load(open(os.path.join(ROOT, 'tools', 'online', 'online_catalog.json'), encoding='utf-8'))
tpl = open(os.path.join(ROOT, 'tools', 'online', 'economy_template.sql'), encoding='utf-8').read()
def q(s): return "'" + str(s).replace("'", "''") + "'"
L = []
L.append("insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values")
L.append(",\n".join("  (%s, %d, %s, %s, %s, %s::jsonb)" % (q(v['id']), v['price'], str(v['starter']).lower(), str(v['modular']).lower(), str(v.get('buyable', True)).lower(), q(json.dumps(v.get('paint'))) if v.get('paint') else 'null') for v in cat['vehicles']))
L.append("on conflict (id) do update set price = excluded.price, starter = excluded.starter, modular = excluded.modular, buyable = excluded.buyable, paint = excluded.paint;\n")
L.append("insert into public.online_cat_upgrades (category, level, price, shop) values")
L.append(",\n".join("  (%s, %d, %d, %s)" % (q(u['category']), u['level'], u['price'], q(u['shop'])) for u in cat['upgrades']))
L.append("on conflict (category, level) do update set price = excluded.price, shop = excluded.shop;\n")
L.append("insert into public.online_cat_tires (id, price) values")
L.append(",\n".join("  (%s, %d)" % (q(t['id']), t['price']) for t in cat['tires']))
L.append("on conflict (id) do update set price = excluded.price;\n")
L.append("insert into public.online_cat_parts (id, category, price, shop, vehicles) values")
L.append(",\n".join("  (%s, %s, %d, %s, array[%s]::text[])" % (q(p['id']), q(p['category']), p['price'], q(p['shop']), ", ".join(q(x) for x in p['vehicles'])) for p in cat['parts']))
L.append("on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;\n")
L.append("insert into public.online_cat_shops (id, name, x, z) values")
L.append(",\n".join("  (%s, %s, %s, %s)" % (q(s['id']), q(s['name']), s['x'], s['z']) for s in cat['shops']))
L.append("on conflict (id) do update set name = excluded.name, x = excluded.x, z = excluded.z;\n")
L.append("insert into public.online_cat_finishes (id) values " + ", ".join("(%s)" % q(f) for f in cat['finishes']) + " on conflict do nothing;")
if len(sys.argv) > 2 and sys.argv[1] == '--seeds-only':
    # migración incremental: sólo las semillas del catálogo (autos nuevos, compatibilidad de piezas); la migración base ya aplicada no se toca
    out = "-- Catálogo online: autos y piezas nuevos (generado con tools/online/gen_economy_sql.py --seeds-only). Aditivo: sólo inserta o actualiza semillas.\n" + "\n".join(L) + "\n"
    open(sys.argv[2], 'w', encoding='utf-8').write(out)
    print("semillas escritas:", sys.argv[2], len(out), "bytes")
    sys.exit(0)
out = tpl.replace("-- @@SEEDS@@", "\n".join(L))
p = os.path.join(ROOT, 'supabase', 'migrations', '20261007010000_online_economy.sql')
open(p, 'w', encoding='utf-8').write(out)
print("migración escrita:", p, len(out), "bytes;", len(cat['vehicles']), "autos,", len(cat['upgrades']), "mejoras,", len(cat['parts']), "piezas,", len(cat['shops']), "locales")
