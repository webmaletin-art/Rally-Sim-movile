-- Dream Racing · ECONOMÍA ONLINE autoritativa (Etapas 3, 13, 18, 19 y seguridad).
-- Todo el dinero y los autos online viven en el SERVIDOR: el teléfono sólo pide acciones y recibe el resultado. Nada se escribe directo en las tablas (RLS sin políticas);
-- cada función valida dueño, auto (instance_id), catálogo, nivel, compatibilidad, precio, saldo y —para trabajos de taller— que el jugador esté de verdad en ese local (posición de presencia).
-- Es ADITIVA: no borra nada. Las funciones viejas del mercado (que mandaban un estado arbitrario y acreditaban «créditos de venta» al teléfono) quedan reemplazadas por un rechazo.
-- El catálogo de abajo se genera de godot/game/data/*.json con tools/online/export_catalog.gd + tools/online/gen_economy_sql.py (no editar las semillas a mano).

-- ───────────── catálogo (lo único contra lo que se valida) ─────────────
create table if not exists public.online_cat_vehicles (id text primary key, price int not null check (price >= 0), starter boolean not null default false, modular boolean not null default false, buyable boolean not null default true, paint jsonb);
alter table public.online_cat_vehicles add column if not exists buyable boolean not null default true;
alter table public.online_cat_vehicles add column if not exists paint jsonb;
create table if not exists public.online_cat_upgrades (category text not null, level int not null check (level >= 1), price int not null check (price >= 0), shop text not null, primary key (category, level));
create table if not exists public.online_cat_tires (id text primary key, price int not null check (price >= 0));
create table if not exists public.online_cat_parts (id text primary key, category text not null, price int not null check (price >= 0), shop text not null, vehicles text[] not null default '{}');
create table if not exists public.online_cat_shops (id text primary key, name text not null, x real not null, z real not null, radius real not null default 90);
create table if not exists public.online_cat_finishes (id text primary key);

-- ───────────── billeteras y autos online (separados del progreso offline) ─────────────
create table if not exists public.online_wallets (
  player_id  uuid primary key references public.players (id) on delete cascade,
  credits    bigint not null default 25000 check (credits >= 0),
  daily_at   timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists public.online_vehicles (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references public.players (id) on delete cascade,
  vehicle_id  text not null references public.online_cat_vehicles (id),
  upgrades    jsonb not null default '{}'::jsonb,            -- {categoría: nivel}
  tires       text not null default 'street' references public.online_cat_tires (id),
  tires_owned text[] not null default array['street'],
  tire_wear   jsonb not null default '{}'::jsonb,            -- {gomas: desgaste 0..1} (lo calcula el servidor)
  paint       jsonb not null default '{"body":"#b31f24","accent":"#1b1d22","rim":"#23262b"}'::jsonb,
  parts_owned text[] not null default '{}',
  mods        jsonb not null default '{}'::jsonb,            -- {categoría: {id, v}} piezas puestas (llantas, alerones…)
  km          numeric not null default 0 check (km >= 0),
  status      text not null default 'garage' check (status in ('garage', 'listed')),
  last_drive  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);
create index if not exists online_vehicles_owner_idx on public.online_vehicles (owner, created_at);

create table if not exists public.online_log (
  id         bigint generated always as identity primary key,
  player_id  uuid not null,
  kind       text not null,
  created_at timestamptz not null default now()
);
create index if not exists online_log_idx on public.online_log (player_id, kind, created_at desc);

alter table public.market_listings add column if not exists instance_id uuid references public.online_vehicles (id) on delete cascade;
alter table public.presence add column if not exists instance_id uuid;

alter table public.online_cat_vehicles enable row level security;
alter table public.online_cat_upgrades enable row level security;
alter table public.online_cat_tires    enable row level security;
alter table public.online_cat_parts    enable row level security;
alter table public.online_cat_shops    enable row level security;
alter table public.online_cat_finishes enable row level security;
alter table public.online_wallets      enable row level security;
alter table public.online_vehicles     enable row level security;
alter table public.online_log          enable row level security;
revoke all on public.online_cat_vehicles, public.online_cat_upgrades, public.online_cat_tires, public.online_cat_parts, public.online_cat_shops, public.online_cat_finishes,
  public.online_wallets, public.online_vehicles, public.online_log from anon, authenticated;

-- ───────────── semillas del catálogo (generadas) ─────────────
insert into public.online_cat_vehicles (id, price, starter, modular, buyable, paint) values
  ('pickup', 18000, true, true, true, '{"body": "#b31f24", "accent": "#1b1d22", "rim": "#23262b"}'::jsonb),
  ('t1plus', 62000, true, false, true, '{"body": "#1a4fe0", "accent": "#ff6a08", "rim": "#ff6a08"}'::jsonb),
  ('truck', 45000, false, true, false, '{"body": "#e8e6df", "accent": "#c1121f", "rim": "#1b1d22"}'::jsonb),
  ('genesis', 250000, false, false, false, '{"body": "#15181d", "accent": "#c9a24b", "rim": "#2a2d33"}'::jsonb),
  ('hatch', 24000, false, true, true, '{"body": "#f2f2ee", "accent": "#e11d2a", "rim": "#1b1d22"}'::jsonb),
  ('suv', 30000, false, true, true, '{"body": "#2f6f5e", "accent": "#d4d4cf", "rim": "#1b1d22"}'::jsonb),
  ('buggy', 38000, false, true, true, '{"body": "#ffc300", "accent": "#0b0c0e", "rim": "#0b0c0e"}'::jsonb),
  ('muscle', 52000, false, true, true, '{"body": "#e11d2a", "accent": "#f5f5f2", "rim": "#c0c5cc"}'::jsonb),
  ('gt', 70000, false, true, true, '{"body": "#1a4fe0", "accent": "#f5f5f2", "rim": "#16181c"}'::jsonb),
  ('gt3', 120000, false, true, false, '{"body": "#f5f5f2", "accent": "#ff6a08", "rim": "#c9a24b"}'::jsonb),
  ('hyper', 150000, false, true, false, '{"body": "#0b0c0e", "accent": "#00b4d8", "rim": "#c0c5cc"}'::jsonb)
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
  ('rim_multi5', 'wheel', 0, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_star5', 'wheel', 1500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_multi10', 'wheel', 2200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_turbine', 'wheel', 2800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_centerlock', 'wheel', 3500, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_dish6', 'wheel', 800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_dish8', 'wheel', 900, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_steel10', 'wheel', 400, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_beadlock', 'wheel', 1800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy']::text[]),
  ('rim_spoke6', 'wheel', 1200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_forked', 'wheel', 3200, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_mesh', 'wheel', 4200, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_classic', 'wheel', 2600, 'wheels', array['pickup', 'hatch', 'suv', 'buggy', 'muscle', 'gt']::text[]),
  ('rim_blade3', 'wheel', 3800, 'wheels', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rim_aero', 'wheel', 5200, 'wheels', array['hatch', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('spoiler_gt', 'spoiler', 1800, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('spoiler_duck', 'spoiler', 900, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('spoiler_rally', 'spoiler', 2600, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('front_splitter', 'front_bumper', 1100, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('front_bumper_sport', 'front_bumper', 2200, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('rear_diffuser', 'rear_bumper', 1400, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[]),
  ('skirt_sport', 'side_skirt', 1200, 'paint', array['pickup', 'truck', 'hatch', 'suv', 'buggy', 'muscle', 'gt', 'gt3', 'hyper']::text[])
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

-- ───────────── ayudas internas (sin permiso para el juego) ─────────────
create or replace function public._online_uid() returns uuid language plpgsql stable as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  return uid;
end;
$$;

-- límite de acciones por hora (anti-abuso)
create or replace function public._online_rate(p_uid uuid, p_kind text, p_max int) returns void language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.online_log where player_id = p_uid and kind = p_kind and created_at > now() - interval '1 hour') >= p_max then
    raise exception 'demasiadas acciones, esperá un rato' using errcode = '53400';
  end if;
  insert into public.online_log (player_id, kind) values (p_uid, p_kind);
  delete from public.online_log where player_id = p_uid and created_at < now() - interval '2 hours';
end;
$$;

-- la billetera existe (con el saldo inicial) y el jugador tiene su auto de partida
create or replace function public._online_ensure(p_uid uuid, p_name text) returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._ensure_player(p_uid, p_name);
  insert into public.online_wallets (player_id) values (p_uid) on conflict do nothing;
  if not exists (select 1 from public.online_vehicles where owner = p_uid) then
    insert into public.online_vehicles (owner, vehicle_id, paint) select p_uid, id, coalesce(paint, '{"body":"#b31f24","accent":"#1b1d22","rim":"#23262b"}'::jsonb) from public.online_cat_vehicles where starter order by price limit 1;
  end if;
end;
$$;

create or replace function public._online_spend(p_uid uuid, p_amount bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_amount < 0 then raise exception 'monto inválido' using errcode = '22023'; end if;
  update public.online_wallets set credits = credits - p_amount, updated_at = now() where player_id = p_uid and credits >= p_amount;
  if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
end;
$$;

-- ¿está el jugador en ese local? (su última posición de presencia, de hace menos de 2 min, a menos del radio del local)
create or replace function public._online_at_shop(p_uid uuid, p_shop text) returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.presence pr join public.online_cat_shops s on s.id = p_shop
    where pr.player_id = p_uid and pr.updated_at > now() - interval '2 minutes'
      and sqrt(power(pr.x - s.x, 2) + power(pr.z - s.z, 2)) <= s.radius
  );
$$;

create or replace function public._online_need_shop(p_uid uuid, p_shop text, p_expected text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_shop is distinct from p_expected then raise exception 'este trabajo no se hace en ese local' using errcode = '42501'; end if;
  if not public._online_at_shop(p_uid, p_shop) then raise exception 'no estás en el local' using errcode = '42501'; end if;
end;
$$;

create or replace function public._online_vjson(v public.online_vehicles) returns jsonb language sql stable as $$
  select jsonb_build_object('instance', v.id, 'vehicle', v.vehicle_id, 'upg', v.upgrades, 'tires', v.tires, 'tiresOwned', to_jsonb(v.tires_owned), 'tireWear', v.tire_wear,
    'paint', v.paint, 'partsOwned', to_jsonb(v.parts_owned), 'mods', v.mods, 'km', v.km, 'status', v.status);
$$;

-- el auto es mío y está en el garage (no en venta)
create or replace function public._online_mine(p_uid uuid, p_instance uuid) returns public.online_vehicles language plpgsql security definer set search_path = public as $$
declare v public.online_vehicles;
begin
  select * into v from public.online_vehicles where id = p_instance and owner = p_uid for update;
  if not found then raise exception 'ese auto no es tuyo' using errcode = '42501'; end if;
  if v.status <> 'garage' then raise exception 'el auto está en venta' using errcode = '22023'; end if;
  return v;
end;
$$;

-- ───────────── estado ─────────────
create or replace function public.online_state(p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); cr bigint;
begin
  perform public._online_ensure(uid, p_name);
  select credits into cr from public.online_wallets where player_id = uid;
  return jsonb_build_object('credits', cr, 'vehicles', coalesce((select jsonb_agg(public._online_vjson(v) order by v.created_at) from public.online_vehicles v where v.owner = uid), '[]'::jsonb));
end;
$$;

-- regalo diario (la única fuente de créditos online además del mercado entre jugadores; las carreras pagarán cuando el servidor valide los resultados)
create or replace function public.online_daily() returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); w public.online_wallets;
begin
  perform public._online_ensure(uid, null);
  update public.online_wallets set credits = credits + 2000, daily_at = now(), updated_at = now()
    where player_id = uid and (daily_at is null or daily_at < now() - interval '20 hours') returning * into w;
  if not found then return jsonb_build_object('ok', false, 'reason', 'ya cobraste el regalo de hoy'); end if;
  return jsonb_build_object('ok', true, 'credits', w.credits, 'gift', 2000);
end;
$$;

-- ───────────── concesionario ─────────────
create or replace function public.online_buy_vehicle(p_vehicle text, p_shop text default 'dealer') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); c public.online_cat_vehicles; v public.online_vehicles;
begin
  perform public._online_rate(uid, 'buy', 120);
  perform public._online_ensure(uid, null);
  perform public._online_need_shop(uid, p_shop, 'dealer');
  select * into c from public.online_cat_vehicles where id = p_vehicle;
  if not found then raise exception 'ese auto no existe' using errcode = '22023'; end if;
  if not c.buyable then raise exception 'ese auto no se compra con créditos online' using errcode = '42501'; end if;
  if (select count(*) from public.online_vehicles where owner = uid) >= 12 then raise exception 'garage lleno (máximo 12 autos)' using errcode = '53400'; end if;
  perform public._online_spend(uid, c.price);
  insert into public.online_vehicles (owner, vehicle_id, paint) values (uid, c.id, coalesce(c.paint, '{"body":"#b31f24","accent":"#1b1d22","rim":"#23262b"}'::jsonb)) returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

-- ───────────── talleres ─────────────
create or replace function public.online_buy_upgrade(p_instance uuid, p_category text, p_level int, p_shop text) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; u public.online_cat_upgrades; cur int;
begin
  perform public._online_rate(uid, 'buy', 120);
  v := public._online_mine(uid, p_instance);
  select * into u from public.online_cat_upgrades where category = p_category and level = p_level;
  if not found then raise exception 'esa mejora no existe' using errcode = '22023'; end if;
  perform public._online_need_shop(uid, p_shop, u.shop);
  cur := coalesce((v.upgrades ->> p_category)::int, 0);
  if p_level <> cur + 1 then raise exception 'primero comprá el nivel anterior' using errcode = '22023'; end if;
  perform public._online_spend(uid, u.price);
  update public.online_vehicles set upgrades = jsonb_set(upgrades, array[p_category], to_jsonb(p_level)) where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

create or replace function public.online_buy_tires(p_instance uuid, p_tire text, p_shop text default 'wheels') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; t public.online_cat_tires;
begin
  perform public._online_rate(uid, 'buy', 120);
  v := public._online_mine(uid, p_instance);
  perform public._online_need_shop(uid, p_shop, 'wheels');
  select * into t from public.online_cat_tires where id = p_tire;
  if not found then raise exception 'esas gomas no existen' using errcode = '22023'; end if;
  if not (p_tire = any (v.tires_owned)) then
    perform public._online_spend(uid, t.price);
    update public.online_vehicles set tires_owned = array_append(tires_owned, p_tire) where id = v.id;
  end if;
  update public.online_vehicles set tires = p_tire where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

-- cambiar el juego de gomas puesto por uno nuevo: la mitad de su precio (mínimo 250, múltiplos de 50)
create or replace function public.online_replace_tires(p_instance uuid, p_shop text default 'wheels') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; price int; cost int;
begin
  perform public._online_rate(uid, 'buy', 120);
  v := public._online_mine(uid, p_instance);
  perform public._online_need_shop(uid, p_shop, 'wheels');
  select t.price into price from public.online_cat_tires t where t.id = v.tires;
  cost := greatest(250, (round(price * 0.5 / 50.0) * 50)::int);
  perform public._online_spend(uid, cost);
  update public.online_vehicles set tire_wear = jsonb_set(tire_wear, array[v.tires], '0'::jsonb) where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'cost', cost, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

create or replace function public.online_set_paint(p_instance uuid, p_paint jsonb, p_shop text default 'paint') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; k text; val jsonb; clean jsonb := '{}'::jsonb;
begin
  perform public._online_rate(uid, 'buy', 120);
  v := public._online_mine(uid, p_instance);
  perform public._online_need_shop(uid, p_shop, 'paint');
  if jsonb_typeof(p_paint) is distinct from 'object' or octet_length(p_paint::text) > 600 then raise exception 'pintura inválida' using errcode = '22023'; end if;
  for k, val in select * from jsonb_each(p_paint) loop
    if k in ('body', 'accent', 'rim', 'tire', 'spring', 'caliper') then
      if jsonb_typeof(val) <> 'string' or (val #>> '{}') !~ '^#[0-9a-fA-F]{6}$' then raise exception 'color inválido' using errcode = '22023'; end if;
      clean := clean || jsonb_build_object(k, lower(val #>> '{}'));
    elsif k = 'finish' then
      if jsonb_typeof(val) <> 'string' or not exists (select 1 from public.online_cat_finishes where id = val #>> '{}') then raise exception 'acabado inválido' using errcode = '22023'; end if;
      clean := clean || jsonb_build_object(k, val #>> '{}');
    elsif k = 'livery' then
      if jsonb_typeof(val) <> 'number' or (val #>> '{}')::numeric not between 0 and 30 then raise exception 'rotulado inválido' using errcode = '22023'; end if;
      clean := clean || jsonb_build_object(k, (val #>> '{}')::int);
    elsif k = 'disc' then
      if (val #>> '{}') not in ('steel', 'dark', 'gold', 'carbon') then raise exception 'disco inválido' using errcode = '22023'; end if;
      clean := clean || jsonb_build_object(k, val #>> '{}');
    else
      raise exception 'campo de pintura desconocido: %', left(k, 20) using errcode = '22023';
    end if;
  end loop;
  clean := v.paint || clean;
  if clean <> v.paint then
    perform public._online_spend(uid, 300);
    update public.online_vehicles set paint = clean where id = v.id returning * into v;
  end if;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

-- piezas modulares (llantas, alerones, paragolpes…): sólo las compatibles con ese auto y en el local que corresponde; comprar = pagar una vez, cambiar entre las compradas es gratis
create or replace function public.online_buy_part(p_instance uuid, p_part text, p_shop text) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; p public.online_cat_parts;
begin
  perform public._online_rate(uid, 'buy', 120);
  v := public._online_mine(uid, p_instance);
  select * into p from public.online_cat_parts where id = p_part;
  if not found then raise exception 'esa pieza no existe' using errcode = '22023'; end if;
  perform public._online_need_shop(uid, p_shop, p.shop);
  if not (v.vehicle_id = any (p.vehicles)) then raise exception 'esa pieza no entra en este auto' using errcode = '22023'; end if;
  if not (p_part = any (v.parts_owned)) then
    perform public._online_spend(uid, p.price);
    update public.online_vehicles set parts_owned = array_append(parts_owned, p_part) where id = v.id;
  end if;
  update public.online_vehicles set mods = jsonb_set(mods, array[p.category], jsonb_build_object('id', p_part, 'v', 0)) where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

create or replace function public.online_remove_part(p_instance uuid, p_category text, p_shop text) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; sh text;
begin
  v := public._online_mine(uid, p_instance);
  select shop into sh from public.online_cat_parts where category = p_category limit 1;
  if sh is null then raise exception 'categoría inexistente' using errcode = '22023'; end if;
  perform public._online_need_shop(uid, p_shop, sh);
  update public.online_vehicles set mods = mods - p_category where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v));
end;
$$;

-- desgaste de gomas: el teléfono informa lo manejado (km, segundos y un promedio de exigencia 1..4); el servidor lo limita a lo físicamente posible y calcula el desgaste
create or replace function public.online_report_drive(p_instance uuid, p_km real, p_seconds real, p_stress real default 1.5) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; life real; fam text; kmv real; sec real; elapsed real; wear real; cur real;
begin
  select * into v from public.online_vehicles where id = p_instance and owner = uid for update;
  if not found then raise exception 'ese auto no es tuyo' using errcode = '42501'; end if;
  elapsed := extract(epoch from (now() - v.last_drive));
  sec := least(greatest(coalesce(p_seconds, 0), 0), 900, elapsed + 30);   -- no se puede manejar más tiempo del que pasó
  kmv := least(greatest(coalesce(p_km, 0), 0), sec * 0.12);               -- 120 m/s (≈ 430 km/h) como máximo
  fam := case v.tires when 'street' then 'STREET' when 'sport' then 'SPORT' when 'slick' then 'SPORT' when 'gravel' then 'RALLY' when 'mud' then 'RALLY' when 'drift' then 'DRIFT' else 'STREET' end;
  life := case fam when 'STREET' then 90 when 'SPORT' then 60 when 'RALLY' then 75 else 35 end;
  cur := coalesce((v.tire_wear ->> v.tires)::real, 0);
  wear := least(1, cur + kmv / life * least(greatest(coalesce(p_stress, 1.5), 1), 4));
  update public.online_vehicles set km = online_vehicles.km + kmv, tire_wear = jsonb_set(tire_wear, array[v.tires], to_jsonb(wear)), last_drive = now()
    where id = v.id returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v));
end;
$$;

-- ───────────── mercado entre jugadores (por auto, con traspaso del servidor) ─────────────
create or replace function public.market_list_instance(p_instance uuid, p_price int, p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); v public.online_vehicles; nm text; new_id bigint;
begin
  perform public._online_rate(uid, 'market', 30);
  if p_price is null or p_price < 100 or p_price > 99999999 then raise exception 'precio inválido' using errcode = '22023'; end if;
  nm := public._ensure_player(uid, p_name);
  v := public._online_mine(uid, p_instance);
  if (select count(*) from public.market_listings where seller = uid and status = 'open') >= 5 then raise exception 'máximo 5 autos en venta' using errcode = '53400'; end if;
  update public.online_vehicles set status = 'listed' where id = v.id returning * into v;
  insert into public.market_listings (seller, seller_name, car, state, price, instance_id) values (uid, nm, v.vehicle_id, public._online_vjson(v), p_price, v.id) returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id);
end;
$$;

create or replace function public.market_buy_instance(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); m public.market_listings; fee bigint; v public.online_vehicles;
begin
  perform public._online_rate(uid, 'market', 30);
  perform public._online_ensure(uid, null);
  select * into m from public.market_listings where id = p_id and status = 'open' and instance_id is not null for update;
  if not found then return jsonb_build_object('ok', false, 'reason', 'ya no está disponible'); end if;
  if m.seller = uid then return jsonb_build_object('ok', false, 'reason', 'es tu propio auto'); end if;
  if (select count(*) from public.online_vehicles where owner = uid) >= 12 then return jsonb_build_object('ok', false, 'reason', 'garage lleno'); end if;
  perform public._online_spend(uid, m.price);
  fee := greatest(1, (m.price * 5) / 100);
  insert into public.online_wallets (player_id) values (m.seller) on conflict do nothing;
  update public.online_wallets set credits = credits + (m.price - fee), updated_at = now() where player_id = m.seller;
  update public.online_vehicles set owner = uid, status = 'garage' where id = m.instance_id returning * into v;
  update public.market_listings set status = 'sold', buyer = uid, sold_at = now(), paid = true where id = m.id;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'price', m.price, 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

-- cancelar una venta: el auto vuelve al garage (reemplaza la versión anterior, mismo nombre y firma)
create or replace function public.market_cancel(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare m public.market_listings;
begin
  update public.market_listings set status = 'cancelled' where id = p_id and seller = auth.uid() and status = 'open' returning * into m;
  if found and m.instance_id is not null then
    update public.online_vehicles set status = 'garage' where id = m.instance_id and owner = auth.uid();
  end if;
end;
$$;

-- las funciones viejas del mercado (estado arbitrario del teléfono y créditos acreditados «de palabra») quedan cerradas: eran una puerta a crear créditos y autos de la nada
create or replace function public.market_list(p_car text, p_state jsonb, p_price int, p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
begin raise exception 'obsoleto: usá market_list_instance' using errcode = '0A000'; end;
$$;
create or replace function public.market_buy(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
begin raise exception 'obsoleto: usá market_buy_instance' using errcode = '0A000'; end;
$$;
create or replace function public.market_collect() returns jsonb language plpgsql security definer set search_path = public as $$
begin return jsonb_build_object('count', 0, 'credits', 0); end;
$$;
-- las ventas viejas abiertas (con un estado que mandó el teléfono) se cancelan: no tienen un auto verificado detrás
update public.market_listings set status = 'cancelled' where status = 'open' and instance_id is null;

-- ───────────── presencia con el auto real (Etapa 18) ─────────────
create or replace function public.presence_beat(p_x real, p_z real, p_speed real, p_car text, p_name text, p_instance uuid) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); nm text; car text := left(coalesce(p_car, ''), 40); inst uuid := null;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  nm := public._ensure_player(uid, p_name);
  if p_instance is not null then
    select vehicle_id, id into car, inst from public.online_vehicles where id = p_instance and owner = uid and status = 'garage';
    if not found then car := left(coalesce(p_car, ''), 40); inst := null; end if;
  end if;
  insert into public.presence (player_id, name, x, z, speed, car, instance_id, updated_at)
    values (uid, nm, p_x, p_z, least(greatest(p_speed, 0), 400), car, inst, now())
    on conflict (player_id) do update set name = excluded.name, x = excluded.x, z = excluded.z, speed = excluded.speed, car = excluded.car, instance_id = excluded.instance_id, updated_at = now();
  insert into public.presence_trail (player_id, x, z, speed) values (uid, p_x, p_z, least(greatest(p_speed, 0), 400));
  delete from public.presence_trail where player_id = uid and created_at < now() - interval '10 minutes';
end;
$$;

-- quién está conectado, con el modelo, la pintura y las llantas que el SERVIDOR sabe que tiene (no lo que diga el otro teléfono)
create or replace function public.presence_list_v(p_limit int default 60)
returns table (player_id uuid, name text, x real, z real, speed real, car text, is_friend boolean, follows_me boolean, is_me boolean, vehicle jsonb)
language sql stable security definer set search_path = public as $$
  select pr.player_id, pr.name, pr.x, pr.z, pr.speed, pr.car,
         exists (select 1 from public.follows f where f.follower = auth.uid() and f.target = pr.player_id),
         exists (select 1 from public.follows f where f.follower = pr.player_id and f.target = auth.uid()),
         (pr.player_id = auth.uid()),
         (select jsonb_build_object('vehicle', ov.vehicle_id, 'paint', ov.paint, 'mods', ov.mods, 'tires', ov.tires)
            from public.online_vehicles ov where ov.id = pr.instance_id and ov.owner = pr.player_id and ov.status = 'garage')
  from public.presence pr
  where pr.updated_at > now() - interval '45 seconds'
  order by 8 desc, 7 desc, pr.name
  limit greatest(1, least(coalesce(p_limit, 60), 200));
$$;

-- ───────────── permisos ─────────────
revoke all on function public._online_uid(), public._online_rate(uuid, text, int), public._online_ensure(uuid, text), public._online_spend(uuid, bigint), public._online_at_shop(uuid, text),
  public._online_need_shop(uuid, text, text), public._online_vjson(public.online_vehicles), public._online_mine(uuid, uuid) from public, anon, authenticated;
do $$
declare f text;
begin
  foreach f in array array[
    'online_state(text)', 'online_daily()', 'online_buy_vehicle(text, text)', 'online_buy_upgrade(uuid, text, int, text)', 'online_buy_tires(uuid, text, text)', 'online_replace_tires(uuid, text)',
    'online_set_paint(uuid, jsonb, text)', 'online_buy_part(uuid, text, text)', 'online_remove_part(uuid, text, text)', 'online_report_drive(uuid, real, real, real)',
    'market_list_instance(uuid, int, text)', 'market_buy_instance(bigint)', 'market_cancel(bigint)', 'presence_beat(real, real, real, text, text, uuid)', 'presence_list_v(int)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- las funciones cerradas ya no se pueden llamar
  foreach f in array array['market_list(text, jsonb, int, text)', 'market_buy(bigint)', 'market_collect()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
