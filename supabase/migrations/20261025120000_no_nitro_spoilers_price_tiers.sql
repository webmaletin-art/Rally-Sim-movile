-- Dream Racing · 20/10/2026 (sexta tanda, [B]) — pedido del dueño, a la vista de todo el que juega:
--  1) Sin Nitro (N₂O): se saca la mejora «nitro» (niveles 1 y 2) del catálogo del servidor.
--  2) Sin alerones comprables (spoiler_gt, spoiler_duck, spoiler_rally): se sacan las piezas de la categoría «spoiler».
--     A quien ya los tuviera se le devuelve lo que pagó (al precio del catálogo) y se le sacan de los autos (cuentas y garaje online): no se le quita nada sin compensar.
--  3) Precios de los autos por escalones: «cada dos autos, el mismo precio» (así hay siempre dos o más autos para elegir en cada precio; el inicial, el R2 Turbo, no se vende).
--     Las semillas de más abajo salen de tools/online/online_catalog.json (que sale del catálogo del juego: godot/game/data/catalog.json), con los precios y los locales nuevos.
-- Repetible: la devolución sólo mira lo que todavía existe en el catálogo y las semillas son «on conflict do update».

do $$
declare
  a record;
  car text;
  refund bigint;
  x bigint;
  owned jsonb;
  prts jsonb;
  cars2 jsonb;
  spoilers text[] := array(select id from public.online_cat_parts where category = 'spoiler');
begin
  -- cuentas del juego (créditos y autos en el servidor): mejoras «nitro:N» y piezas de alerón de cada auto
  for a in select user_id, cars from public.account_econ where cars::text like '%nitro:%' or cars::text like '%spoiler%' loop
    cars2 := a.cars;
    refund := 0;
    for car in select jsonb_object_keys(a.cars) loop
      owned := coalesce(a.cars -> car -> 'owned', '[]'::jsonb);
      select coalesce(sum(u.price), 0) into x
        from (select o.k from jsonb_array_elements_text(owned) as o(k) where o.k ~ '^nitro:[0-9]+$') n
        join public.online_cat_upgrades u on u.category = 'nitro' and u.level = substr(n.k, 7)::int;
      refund := refund + x;
      select coalesce(jsonb_agg(o.k), '[]'::jsonb) into owned from jsonb_array_elements_text(owned) as o(k) where o.k !~ '^nitro:';
      prts := coalesce(a.cars -> car -> 'parts', '[]'::jsonb);
      select coalesce(sum(p.price), 0) into x
        from jsonb_array_elements_text(prts) as q(id) join public.online_cat_parts p on p.id = q.id
       where p.category = 'spoiler';
      refund := refund + x;
      select coalesce(jsonb_agg(q.id), '[]'::jsonb) into prts from jsonb_array_elements_text(prts) as q(id) where q.id <> all (spoilers);
      cars2 := jsonb_set(jsonb_set(cars2, array[car, 'owned'], owned), array[car, 'parts'], prts);
    end loop;
    if cars2 is distinct from a.cars then
      update public.account_econ set cars = cars2, credits = credits + refund, seq = seq + 1, updated_at = now() where user_id = a.user_id;
    end if;
  end loop;

  -- autos del garaje online: nivel de nitro, piezas compradas y puestas
  for a in select id, owner, upgrades, parts_owned, mods from public.online_vehicles
            where upgrades ? 'nitro' or parts_owned && spoilers or mods ? 'spoiler' loop
    refund := 0;
    if a.upgrades ? 'nitro' then
      select coalesce(sum(u.price), 0) into x from public.online_cat_upgrades u
       where u.category = 'nitro' and u.level <= coalesce((a.upgrades ->> 'nitro')::int, 0);
      refund := refund + x;
    end if;
    select coalesce(sum(p.price), 0) into x from public.online_cat_parts p where p.id = any (a.parts_owned) and p.category = 'spoiler';
    refund := refund + x;
    update public.online_vehicles
       set upgrades = upgrades - 'nitro',
           parts_owned = array(select pid from unnest(parts_owned) as pid where pid <> all (spoilers)),
           mods = mods - 'spoiler'
     where id = a.id;
    if refund > 0 then
      update public.online_wallets set credits = credits + refund, updated_at = now() where player_id = a.owner;
    end if;
  end loop;
end;
$$;

delete from public.online_cat_upgrades where category = 'nitro';
delete from public.online_cat_parts where category = 'spoiler';

-- Semillas del catálogo online (generadas con tools/online/gen_economy_sql.py --seeds-only): precios de autos por escalones, locales y piezas. Sólo inserta o actualiza.
insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values
  ('pickup', 32000, false, true, true, '{"accent": "#1b1d22", "body": "#b31f24", "livery": 11.0, "rim": "#23262b"}'::jsonb),
  ('truck', 58000, false, true, true, '{"accent": "#c1121f", "body": "#e8e6df", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('genesis', 187000, false, true, true, '{"accent": "#c9a24b", "body": "#15181d", "livery": 11.0, "rim": "#15161a"}'::jsonb),
  ('hatch', 9000, true, true, true, '{"accent": "#f5f5f2", "body": "#e11d2a", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('suv', 43000, false, true, true, '{"accent": "#d4d4cf", "body": "#2f6f5e", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('buggy', 58000, false, true, true, '{"accent": "#0b0c0e", "body": "#ffc300", "livery": 11.0, "rim": "#f2f2f2"}'::jsonb),
  ('muscle', 58000, false, true, true, '{"accent": "#f5f5f2", "body": "#e11d2a", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('gt', 89000, false, true, true, '{"accent": "#f5f5f2", "body": "#1a4fe0", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('gt3', 135000, false, true, true, '{"accent": "#ff6a08", "body": "#f5f5f2", "livery": 11.0, "rim": "#c9a24b"}'::jsonb),
  ('hyper', 240000, false, true, true, '{"accent": "#00b4d8", "body": "#0b0c0e", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('camo', 43000, false, true, true, '{"accent": "#2c3a1e", "body": "#ffffff", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('torito', 21000, false, true, true, '{"accent": "#f5f5f2", "body": "#1e5aa8", "livery": 11.0, "rim": "#c9ccd2"}'::jsonb),
  ('clasico60', 32000, false, true, true, '{"accent": "#b31f24", "body": "#e8e2d0", "livery": 11.0, "rim": "#c9ccd2"}'::jsonb),
  ('kodiak', 43000, false, true, true, '{"accent": "#ff6a08", "body": "#f5f5f2", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('titan', 32000, false, true, true, '{"accent": "#f5f5f2", "body": "#1a4fe0", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('rally80', 58000, false, true, true, '{"accent": "#1a4fe0", "body": "#f5f5f2", "livery": 11.0, "rim": "#d4a017"}'::jsonb),
  ('kl5', 89000, false, true, true, '{"accent": "#ff6a08", "body": "#0f3d5e", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('trilux', 89000, false, true, true, '{"accent": "#e11d2a", "body": "#c0c5cc", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('trilux_s', 89000, false, true, true, '{"accent": "#0b0c0e", "body": "#e11d2a", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('trilux_gt', 135000, false, true, true, '{"accent": "#ffc300", "body": "#2b2f36", "livery": 11.0, "rim": "#ffc300"}'::jsonb),
  ('veltor', 135000, false, true, true, '{"accent": "#e11d2a", "body": "#f5f5f2", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('veltor_s', 187000, false, true, true, '{"accent": "#0b0c0e", "body": "#e11d2a", "livery": 11.0, "rim": "#2a2d33"}'::jsonb),
  ('veltor_gtr', 240000, false, true, true, '{"accent": "#0b0c0e", "body": "#1a4fe0", "livery": 11.0, "rim": "#00b4d8"}'::jsonb),
  ('hatch2', 21000, false, true, true, '{"accent": "#e11d2a", "body": "#f2f2ee", "livery": 11.0, "rim": "#e6e7ea"}'::jsonb),
  ('pro_gt', 89000, false, true, true, '{"accent": "#e11d2a", "body": "#f5f5f2", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('moust', 187000, false, true, true, '{"accent": "#e11d2a", "body": "#3a3d44", "livery": 11.0, "rim": "#1b1d22"}'::jsonb),
  ('police', 135000, false, true, true, '{"accent": "#1a4fe0", "body": "#f2f2ee", "livery": 11.0, "rim": "#c0c5cc"}'::jsonb),
  ('strix', 187000, false, true, true, '{"accent": "#ff6a08", "body": "#3a3d44", "livery": 11.0, "rim": "#1b1d22"}'::jsonb)
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
  ('rim_multi5', 'wheel', 0, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_star5', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_multi10', 'wheel', 2200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_turbine', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_centerlock', 'wheel', 3500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_dish6', 'wheel', 800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_dish8', 'wheel', 900, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_steel10', 'wheel', 400, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_beadlock', 'wheel', 1800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'kodiak', 'titan']::text[]),
  ('rim_spoke6', 'wheel', 1200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_forked', 'wheel', 3200, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_mesh', 'wheel', 4200, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'clasico60', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr']::text[]),
  ('rim_classic', 'wheel', 2600, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'torito', 'clasico60', 'kodiak']::text[]),
  ('rim_blade3', 'wheel', 3800, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_aero', 'wheel', 5200, 'wheels', array['hatch', 'muscle', 'gt', 'gt3', 'hyper', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr']::text[]),
  ('front_splitter', 'front_bumper', 1100, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('front_bumper_sport', 'front_bumper', 2200, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rear_diffuser', 'rear_bumper', 1400, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('skirt_sport', 'side_skirt', 1200, 'paint', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_bead10', 'wheel', 3600, 'wheels', array['pickup', 'truck', 'genesis', 'suv', 'buggy', 'camo', 'kodiak', 'rally80', 'hatch2']::text[]),
  ('rim_split8', 'wheel', 3000, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_rally7', 'wheel', 2400, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_dish5', 'wheel', 1000, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[]),
  ('rim_mag5', 'wheel', 2000, 'wheels', array['hatch', 'muscle', 'gt', 'torito', 'clasico60', 'rally80']::text[]),
  ('rim_steelcap', 'wheel', 500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'camo', 'torito', 'clasico60', 'kodiak', 'titan']::text[]),
  ('rim_mono12', 'wheel', 3300, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_trophy', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'genesis', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[]),
  ('rim_fan', 'wheel', 4000, 'wheels', array['genesis', 'hatch', 'muscle', 'gt', 'gt3', 'hyper', 'torito', 'clasico60', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust']::text[]),
  ('rim_twin5', 'wheel', 2600, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper', 'camo', 'torito', 'clasico60', 'kodiak', 'titan', 'rally80', 'kl5', 'trilux', 'trilux_s', 'trilux_gt', 'veltor', 'veltor_s', 'veltor_gtr', 'hatch2', 'pro_gt', 'moust', 'police', 'strix']::text[]),
  ('rim_windows', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'genesis', 'hatch', 'suv', 'buggy', 'camo', 'kodiak', 'titan', 'rally80', 'hatch2']::text[])
on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;

insert into public.online_cat_shops (id, name, x, z) values
  ('dealer', 'Concesionario Dream City', 25.4, -193.2),
  ('tune_a', 'Reglaje Central', 210.3, -31.6),
  ('paint', 'Taller de Pintura', -26.5, 182.3),
  ('engine', 'Taller de Motor', 208.9, 202.8),
  ('gearbox', 'Taller de Transmisión', -115.6, 116.7),
  ('susp', 'Suspensión y Frenos', -142.5, -86.0),
  ('wheels', 'Taller de Ruedas', 119.0, -121.7),
  ('tune_b', 'Reglaje del Puerto', 632.7, 947.5),
  ('dealer_rally', 'Rally & 4x4 del Puerto', -413.7, -41.6),
  ('dealer_classic', 'Clásicos de Colección', 21.5, 447.2),
  ('dealer_sport', 'Dream Motorsport', 461.9, 12.0)
on conflict (id) do update set name = excluded.name, x = excluded.x, z = excluded.z;

insert into public.online_cat_finishes (id) values ('gloss'), ('metal'), ('matte'), ('chrome') on conflict do nothing;

-- autoprueba: sin nitro, sin alerones, y todo precio de auto lo comparten dos o más (menos el inicial, que no se vende)
do $$
declare lonely text;
begin
  if exists (select 1 from public.online_cat_upgrades where category = 'nitro') then raise exception 'quedó el nitro en el catálogo'; end if;
  if exists (select 1 from public.online_cat_parts where category = 'spoiler') then raise exception 'quedaron alerones en el catálogo'; end if;
  select string_agg(price::text, ', ') into lonely from (select price from public.online_cat_vehicles where buyable and not starter group by price having count(*) < 2) t;
  if lonely is not null then raise exception 'hay precios de autos con un solo auto: %', lonely; end if;
end;
$$;
