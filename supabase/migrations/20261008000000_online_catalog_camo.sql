-- Catálogo online: autos y piezas nuevos (generado con tools/online/gen_economy_sql.py --seeds-only). Aditivo: sólo inserta o actualiza semillas.
insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values
  ('pickup', 18000, true, true, true, '{"accent": "#1b1d22", "body": "#b31f24", "rim": "#23262b"}'::jsonb),
  ('t1plus', 62000, true, false, true, '{"accent": "#ff6a08", "body": "#1a4fe0", "rim": "#ff6a08"}'::jsonb),
  ('truck', 45000, false, true, false, '{"accent": "#c1121f", "body": "#e8e6df", "rim": "#1b1d22"}'::jsonb),
  ('genesis', 250000, false, false, false, '{"accent": "#c9a24b", "body": "#15181d", "rim": "#2a2d33"}'::jsonb),
  ('hatch', 24000, false, true, true, '{"accent": "#e11d2a", "body": "#f2f2ee", "rim": "#1b1d22"}'::jsonb),
  ('suv', 30000, false, true, true, '{"accent": "#d4d4cf", "body": "#2f6f5e", "rim": "#1b1d22"}'::jsonb),
  ('buggy', 38000, false, true, true, '{"accent": "#0b0c0e", "body": "#ffc300", "rim": "#0b0c0e"}'::jsonb),
  ('muscle', 52000, false, true, true, '{"accent": "#f5f5f2", "body": "#e11d2a", "rim": "#c0c5cc"}'::jsonb),
  ('gt', 70000, false, true, true, '{"accent": "#f5f5f2", "body": "#1a4fe0", "rim": "#16181c"}'::jsonb),
  ('gt3', 120000, false, true, false, '{"accent": "#ff6a08", "body": "#f5f5f2", "rim": "#c9a24b"}'::jsonb),
  ('hyper', 150000, false, true, false, '{"accent": "#00b4d8", "body": "#0b0c0e", "rim": "#c0c5cc"}'::jsonb),
  ('camo', 42000, false, true, true, '{"accent": "#2c3a1e", "body": "#ffffff", "livery": 6.0, "rim": "#d9a21c"}'::jsonb)
on conflict (id) do update set price = excluded.price, starter = excluded.starter, modular = excluded.modular, buyable = excluded.buyable, paint = excluded.paint;

insert into public.online_cat_upgrades (category, level, price, shop) values
  ('engine', 1, 3500, 'engine'),
  ('engine', 2, 8500, 'engine'),
  ('engine', 3, 17000, 'engine'),
  ('turbo', 1, 6000, 'engine'),
  ('turbo', 2, 12500, 'engine'),
  ('weight', 1, 3000, 'engine'),
  ('weight', 2, 9000, 'engine'),
  ('weight', 3, 18000, 'engine'),
  ('brakes', 1, 2000, 'susp'),
  ('brakes', 2, 6000, 'susp'),
  ('brakes', 3, 14000, 'susp'),
  ('suspension', 1, 3000, 'susp'),
  ('suspension', 2, 8000, 'susp'),
  ('suspension', 3, 15000, 'susp'),
  ('gearbox', 1, 2500, 'gearbox'),
  ('gearbox', 2, 7000, 'gearbox'),
  ('gearbox', 3, 14000, 'gearbox'),
  ('diff', 1, 4000, 'gearbox'),
  ('diff', 2, 10000, 'gearbox'),
  ('aero', 1, 4500, 'tune_a'),
  ('aero', 2, 11000, 'tune_a'),
  ('nitro', 1, 8000, 'engine'),
  ('nitro', 2, 15000, 'engine'),
  ('stance', 1, 2500, 'susp'),
  ('stance', 2, 6000, 'susp')
on conflict (category, level) do update set price = excluded.price, shop = excluded.shop;

insert into public.online_cat_tires (id, price) values
  ('street', 0),
  ('sport', 2500),
  ('slick', 6500),
  ('gravel', 4000),
  ('mud', 5000),
  ('drift', 3000)
on conflict (id) do update set price = excluded.price;

insert into public.online_cat_parts (id, category, price, shop, vehicles) values
  ('rim_multi5', 'wheel', 0, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_star5', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_multi10', 'wheel', 2200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_turbine', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_centerlock', 'wheel', 3500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_dish6', 'wheel', 800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_dish8', 'wheel', 900, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_steel10', 'wheel', 400, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_beadlock', 'wheel', 1800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy']::text[]),
  ('rim_spoke6', 'wheel', 1200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_forked', 'wheel', 3200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_mesh', 'wheel', 4200, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_classic', 'wheel', 2600, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt']::text[]),
  ('rim_blade3', 'wheel', 3800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rim_aero', 'wheel', 5200, 'wheels', array['hatch', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('spoiler_gt', 'spoiler', 1800, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('spoiler_duck', 'spoiler', 900, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('spoiler_rally', 'spoiler', 2600, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('front_splitter', 'front_bumper', 1100, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('front_bumper_sport', 'front_bumper', 2200, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('rear_diffuser', 'rear_bumper', 1400, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[]),
  ('skirt_sport', 'side_skirt', 1200, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo']::text[])
on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;

insert into public.online_cat_shops (id, name, x, z) values
  ('dealer', 'Concesionario Dream City', 25.4, -193.2),
  ('tune_a', 'Reglaje Central', 210.3, -31.6),
  ('paint', 'Taller de Pintura', -26.5, 182.3),
  ('engine', 'Taller de Motor', 210.7, 210.5),
  ('gearbox', 'Taller de Transmisión', -119.5, 131.2),
  ('susp', 'Suspensión y Frenos', -151.9, -90.8),
  ('wheels', 'Taller de Ruedas', 121.4, -128.1),
  ('tune_b', 'Reglaje del Puerto', 632.7, 947.5)
on conflict (id) do update set name = excluded.name, x = excluded.x, z = excluded.z;

insert into public.online_cat_finishes (id) values ('gloss'), ('metal'), ('matte'), ('chrome') on conflict do nothing;
