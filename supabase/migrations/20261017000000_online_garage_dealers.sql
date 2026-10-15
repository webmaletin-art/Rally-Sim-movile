-- Garaje online único y concesionarios nuevos (15/10/2026, reporte del dueño: «me compré autos y camioneta y el modo online no me deja elegir:
-- tengo que volver a comprarlos»; «compraba y al rato me decía que ese no era el lugar para realizar eso»).
--  1. Los 3 concesionarios nuevos de Dream City (Rally & 4x4, Clásicos, Motorsport) no estaban en el catálogo de locales: comprar ahí fallaba siempre.
--  2. online_buy_vehicle acepta cualquier concesionario (id que empieza con «dealer»), siempre que el jugador esté en ESE local.
--  3. Garaje único: los autos comprados con la cuenta (account_econ.cars, el juego «sin conexión») también aparecen en el garaje online, UNA vez
--     cada uno (online_imports lo recuerda: si después se vende en el mercado no vuelve a aparecer gratis).
-- Aditiva y repetible.

insert into public.online_cat_shops (id, name, x, z) values
  ('dealer_rally', 'Rally & 4x4 del Puerto', -427.9, -36.0),
  ('dealer_classic', 'Clásicos de Colección', 21.5, 447.2),
  ('dealer_sport', 'Dream Motorsport', 461.9, 12.0)
on conflict (id) do update set name = excluded.name, x = excluded.x, z = excluded.z;

create or replace function public.online_buy_vehicle(p_vehicle text, p_shop text default 'dealer') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); c public.online_cat_vehicles; v public.online_vehicles;
begin
  perform public._online_rate(uid, 'buy', 120);
  perform public._online_ensure(uid, null);
  if p_shop is null or p_shop not like 'dealer%' then raise exception 'este trabajo no se hace en ese local' using errcode = '42501'; end if;
  if not public._online_at_shop(uid, p_shop) then raise exception 'no estás en el local' using errcode = '42501'; end if;
  select * into c from public.online_cat_vehicles where id = p_vehicle;
  if not found then raise exception 'ese auto no existe' using errcode = '22023'; end if;
  if not c.buyable then raise exception 'ese auto no se compra con créditos online' using errcode = '42501'; end if;
  if (select count(*) from public.online_vehicles where owner = uid) >= 40 then raise exception 'garage lleno (máximo 40 autos)' using errcode = '53400'; end if;
  perform public._online_spend(uid, c.price);
  insert into public.online_vehicles (owner, vehicle_id, paint) values (uid, c.id, coalesce(c.paint, '{"body":"#b31f24","accent":"#1b1d22","rim":"#23262b"}'::jsonb)) returning * into v;
  return jsonb_build_object('ok', true, 'vehicle', public._online_vjson(v), 'credits', (select credits from public.online_wallets where player_id = uid));
end;
$$;

-- los autos de la cuenta que ya pasaron al garaje online (una sola vez por auto)
create table if not exists public.online_imports (
  owner      uuid not null references public.players (id) on delete cascade,
  vehicle_id text not null,
  at         timestamptz not null default now(),
  primary key (owner, vehicle_id)
);
alter table public.online_imports enable row level security;

create or replace function public._online_import_account(p_uid uuid) returns void language plpgsql security definer set search_path = public as $$
declare k text; c public.online_cat_vehicles;
begin
  if to_regclass('public.account_econ') is null then return; end if;
  for k in select jsonb_object_keys(coalesce((select cars from public.account_econ where user_id = p_uid), '{}'::jsonb)) loop
    if exists (select 1 from public.online_imports where owner = p_uid and vehicle_id = k) then continue; end if;
    select * into c from public.online_cat_vehicles where id = k;
    if not found then continue; end if;
    insert into public.online_imports (owner, vehicle_id) values (p_uid, k) on conflict do nothing;
    if not exists (select 1 from public.online_vehicles where owner = p_uid and vehicle_id = k) then
      insert into public.online_vehicles (owner, vehicle_id, paint) values (p_uid, k, coalesce(c.paint, '{"body":"#b31f24","accent":"#1b1d22","rim":"#23262b"}'::jsonb));
    end if;
  end loop;
end;
$$;
revoke all on function public._online_import_account(uuid) from public, anon, authenticated;

create or replace function public.online_state(p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); cr bigint;
begin
  perform public._online_ensure(uid, p_name);
  perform public._online_import_account(uid);
  select credits into cr from public.online_wallets where player_id = uid;
  return jsonb_build_object('credits', cr, 'vehicles', coalesce((select jsonb_agg(public._online_vjson(v) order by v.created_at) from public.online_vehicles v where v.owner = uid), '[]'::jsonb));
end;
$$;
