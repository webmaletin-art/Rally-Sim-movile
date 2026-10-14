-- Dream Racing · 14/10/2026: los dos autos nuevos del catálogo (DRP Interceptor y STRIX Vandal RS) y los cosméticos que se compran por auto
-- (diseños de pintura, interiores y volantes: game/data/cosmetics.json, generado con tools/online/cosmetics_migration.py).
-- El monoplaza (f1) es un vehículo ESPECIAL bloqueado: NO va al catálogo del servidor, así no se puede comprar.
-- Aditivo y repetible: sólo inserta o actualiza semillas. Los cosméticos se validan como piezas («buy_part»): mismo id y mismo precio que el juego.
insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values
  ('police', 140000, false, true, true, '{"accent": "#1a4fe0", "body": "#f2f2ee", "livery": 11, "rim": "#c0c5cc"}'::jsonb),
  ('strix', 170000, false, true, true, '{"accent": "#ff6a08", "body": "#3a3d44", "livery": 11, "rim": "#1b1d22"}'::jsonb)
on conflict (id) do update set price = excluded.price, starter = excluded.starter, modular = excluded.modular, buyable = excluded.buyable, paint = excluded.paint;

insert into public.online_cat_parts (id, category, price, shop, vehicles) values
  ('st_carbono_rojo', 'cosmetic', 6500, 'paint', '{}'::text[]),
  ('st_carbono_negro', 'cosmetic', 8000, 'paint', '{}'::text[]),
  ('st_competicion', 'cosmetic', 7000, 'paint', '{}'::text[]),
  ('st_competicion_roja', 'cosmetic', 7000, 'paint', '{}'::text[]),
  ('st_rojo_negro', 'cosmetic', 4500, 'paint', '{}'::text[]),
  ('st_dos_tonos_azul', 'cosmetic', 4500, 'paint', '{}'::text[]),
  ('st_neon_cian', 'cosmetic', 9500, 'paint', '{}'::text[]),
  ('st_neon_violeta', 'cosmetic', 9500, 'paint', '{}'::text[]),
  ('st_rally_clasico', 'cosmetic', 6000, 'paint', '{}'::text[]),
  ('st_rally_dakar', 'cosmetic', 6000, 'paint', '{}'::text[]),
  ('st_degrade_atardecer', 'cosmetic', 5500, 'paint', '{}'::text[]),
  ('st_degrade_hielo', 'cosmetic', 5500, 'paint', '{}'::text[]),
  ('st_damero', 'cosmetic', 5000, 'paint', '{}'::text[]),
  ('st_llamas', 'cosmetic', 8500, 'paint', '{}'::text[]),
  ('st_llamas_azul', 'cosmetic', 8500, 'paint', '{}'::text[]),
  ('st_oro', 'cosmetic', 12000, 'paint', '{}'::text[]),
  ('st_strix_vandal', 'cosmetic', 7500, 'paint', array['strix']::text[]),
  ('st_interceptor_noche', 'cosmetic', 7500, 'paint', array['police']::text[]),
  ('cab_rally', 'cosmetic', 5000, 'paint', '{}'::text[]),
  ('cab_carbono', 'cosmetic', 9000, 'paint', '{}'::text[]),
  ('cab_cuero_rojo', 'cosmetic', 7500, 'paint', '{}'::text[]),
  ('cab_clasico', 'cosmetic', 6500, 'paint', '{}'::text[]),
  ('cab_patrulla', 'cosmetic', 5500, 'paint', '{}'::text[]),
  ('cab_neon', 'cosmetic', 10000, 'paint', '{}'::text[]),
  ('cab_trabajo', 'cosmetic', 4000, 'paint', '{}'::text[]),
  ('vol_pro', 'cosmetic', 9000, 'paint', '{}'::text[]),
  ('vol_gamuza', 'cosmetic', 3500, 'paint', '{}'::text[]),
  ('vol_carbono', 'cosmetic', 6000, 'paint', '{}'::text[]),
  ('vol_madera', 'cosmetic', 5000, 'paint', '{}'::text[]),
  ('vol_blanco', 'cosmetic', 4500, 'paint', '{}'::text[])
on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;
