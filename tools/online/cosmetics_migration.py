#!/usr/bin/env python3
"""Rearma supabase/migrations/20261015000000_catalog_28_cosmetics.sql a partir de godot/game/data/catalog.json (autos police y strix) y cosmetics.json
(los cosméticos pagos van a online_cat_parts como piezas de la categoría «cosmetic»: la cuenta los valida con buy_part). Si cambia un precio, correrlo y aplicar la migración."""
import json, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
cat = json.load(open(os.path.join(ROOT, 'godot/game/data/catalog.json')))
cos = json.load(open(os.path.join(ROOT, 'godot/game/data/cosmetics.json')))
out = os.path.join(ROOT, 'supabase/migrations/20261015000000_catalog_28_cosmetics.sql')
L = ["-- Dream Racing · 14/10/2026: los dos autos nuevos del catálogo (DRP Interceptor y STRIX Vandal RS) y los cosméticos que se compran por auto",
     "-- (diseños de pintura, interiores y volantes: game/data/cosmetics.json, generado con tools/online/cosmetics_migration.py).",
     "-- El monoplaza (f1) es un vehículo ESPECIAL bloqueado: NO va al catálogo del servidor, así no se puede comprar.",
     "-- Aditivo y repetible: sólo inserta o actualiza semillas. Los cosméticos se validan como piezas («buy_part»): mismo id y mismo precio que el juego.",
     "insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values"]
L.append(",\n".join("  ('%s', %d, false, true, true, '%s'::jsonb)" % (c, cat['cars'][c]['price'], json.dumps(cat['cars'][c]['paint'], sort_keys=True)) for c in ['police', 'strix']))
L.append("on conflict (id) do update set price = excluded.price, starter = excluded.starter, modular = excluded.modular, buyable = excluded.buyable, paint = excluded.paint;\n")
L.append("insert into public.online_cat_parts (id, category, price, shop, vehicles) values")
rows = []
for k in ['styles', 'interiors', 'wheels']:
    for it in cos[k]:
        if int(it.get('price', 0)) <= 0:
            continue
        cars = it.get('cars', [])
        arr = "'{}'::text[]" if not cars else "array[%s]::text[]" % ", ".join("'%s'" % c for c in cars)
        rows.append("  ('%s', 'cosmetic', %d, 'paint', %s)" % (it['id'], it['price'], arr))
L.append(",\n".join(rows))
L.append("on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;")
open(out, 'w').write("\n".join(L) + "\n")
print('escrito', out)
