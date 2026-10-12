-- Dream Racing · catálogo online con los 26 autos de la lista definitiva (generado con tools/online/gen_economy_sql.py --seeds-only).
-- Aditivo y repetible: sólo inserta o actualiza semillas. Los autos que ya no están en la lista (t1plus, que quedó sólo como física oculta) se dejan sin salida:
-- ni se compran ni sirven de auto de partida. El auto de partida pasa a ser el R2 Turbo (hatch), el más barato de los marcados «starter».
insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values
  ('pickup', 34000, false, true, true, '{"accent": "#1b1d22", "body": "#b31f24", "livery": 11.0, "rim": "#23262b"}'::jsonb),
  ('truck', 60000, false, true, true, '{"accent": "#c1121f", "body": "#e8e6df", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('genesis', 190000, false, true, true, '{"accent": "#c9a24b", "body": "#15181d", "livery": 11.0, "rim": "#15161a"}'::jsonb),
  ('hatch', 9000, true, true, true, '{"accent": "#f5f5f2", "body": "#e11d2a", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('suv', 38000, false, true, true, '{"accent": "#d4d4cf", "body": "#2f6f5e", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('buggy', 50000, false, true, true, '{"accent": "#0b0c0e", "body": "#ffc300", "livery": 11.0, "rim": "#f2f2f2"}'::jsonb),
  ('muscle', 56000, false, true, true, '{"accent": "#f5f5f2", "body": "#e11d2a", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('gt', 72000, false, true, true, '{"accent": "#f5f5f2", "body": "#1a4fe0", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('gt3', 130000, false, true, true, '{"accent": "#ff6a08", "body": "#f5f5f2", "livery": 11.0, "rim": "#c9a24b"}'::jsonb),
  ('hyper', 260000, false, true, true, '{"accent": "#00b4d8", "body": "#0b0c0e", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('camo', 46000, false, true, true, '{"accent": "#2c3a1e", "body": "#ffffff", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('torito', 18000, false, true, true, '{"accent": "#f5f5f2", "body": "#1e5aa8", "livery": 11.0, "rim": "#c9ccd2"}'::jsonb),
  ('clasico60', 30000, false, true, true, '{"accent": "#b31f24", "body": "#e8e2d0", "livery": 11.0, "rim": "#c9ccd2"}'::jsonb),
  ('kodiak', 44000, false, true, true, '{"accent": "#ff6a08", "body": "#f5f5f2", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('titan', 32000, false, true, true, '{"accent": "#f5f5f2", "body": "#1a4fe0", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('rally80', 64000, false, true, true, '{"accent": "#1a4fe0", "body": "#f5f5f2", "livery": 11.0, "rim": "#d4a017"}'::jsonb),
  ('kl5', 98000, false, true, true, '{"accent": "#ff6a08", "body": "#0f3d5e", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('trilux', 78000, false, true, true, '{"accent": "#e11d2a", "body": "#c0c5cc", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('trilux_s', 104000, false, true, true, '{"accent": "#0b0c0e", "body": "#e11d2a", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('trilux_gt', 118000, false, true, true, '{"accent": "#ffc300", "body": "#2b2f36", "livery": 11.0, "rim": "#ffc300"}'::jsonb),
  ('veltor', 150000, false, true, true, '{"accent": "#e11d2a", "body": "#f5f5f2", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('veltor_s', 185000, false, true, true, '{"accent": "#0b0c0e", "body": "#e11d2a", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('veltor_gtr', 225000, false, true, true, '{"accent": "#0b0c0e", "body": "#1a4fe0", "livery": 11.0, "rim": "#00b4d8"}'::jsonb),
  ('hatch2', 24000, false, true, true, '{"accent": "#e11d2a", "body": "#f2f2ee", "livery": 11.0, "rim": "#e6e7ea"}'::jsonb),
  ('pro_gt', 92000, false, true, true, '{"accent": "#e11d2a", "body": "#f5f5f2", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('moust', 205000, false, true, true, '{"accent": "#e11d2a", "body": "#3a3d44", "livery": 11.0, "rim": "#1b1d22"}'::jsonb)
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
  ('rim_multi5', 'wheel', 0, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_star5', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_multi10', 'wheel', 2200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_turbine', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_centerlock', 'wheel', 3500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_dish6', 'wheel', 800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_dish8', 'wheel', 900, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_steel10', 'wheel', 400, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_beadlock', 'wheel', 1800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'kodiak', 'titan']::text[]),
  ('rim_spoke6', 'wheel', 1200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_forked', 'wheel', 3200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_mesh', 'wheel', 4200, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'clasico60', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr']::text[]),
  ('rim_classic', 'wheel', 2600, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'torito', 'clasico60', 'kodiak']::text[]),
  ('rim_blade3', 'wheel', 3800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_aero', 'wheel', 5200, 'wheels', array['hatch', 'muscle', 'gt', 'gt3', 'hyper', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr']::text[]),
  ('spoiler_gt', 'spoiler', 1800, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('spoiler_duck', 'spoiler', 900, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('spoiler_rally', 'spoiler', 2600, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('front_splitter', 'front_bumper', 1100, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('front_bumper_sport', 'front_bumper', 2200, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rear_diffuser', 'rear_bumper', 1400, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('skirt_sport', 'side_skirt', 1200, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_bead10', 'wheel', 3600, 'wheels', array['pickup', 'truck', 'genesis', 'suv', 'buggy', 'camo', 'kodiak', 'rally80', 'hatch2']::text[]),
  ('rim_split8', 'wheel', 3000, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_rally7', 'wheel', 2400, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_dish5', 'wheel', 1000, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[]),
  ('rim_mag5', 'wheel', 2000, 'wheels', array['hatch', 'muscle', 'gt', 'torito', 'clasico60', 'rally80']::text[]),
  ('rim_steelcap', 'wheel', 500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'camo', 'torito', 'clasico60', 'kodiak', 'titan']::text[]),
  ('rim_mono12', 'wheel', 3300, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_trophy', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'genesis', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[]),
  ('rim_fan', 'wheel', 4000, 'wheels', array['genesis', 'hatch', 'muscle', 'gt', 'gt3', 'hyper', 'torito', 'clasico60', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_twin5', 'wheel', 2600, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_windows', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[])
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

-- autos viejos que ya no existen en el juego: no se compran y no son de partida (los que ya los tienen los conservan)
update public.online_cat_vehicles set buyable = false, starter = false where id not in ('pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust');
