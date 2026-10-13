-- Dream Racing · economía de la CUENTA: los créditos y los autos de TODO el juego (también el que se juega «sin conexión») viven en el servidor.
-- El jugador tiene que iniciar sesión (cuenta con correo); el juego le pregunta a Supabase cuántos créditos tiene y qué autos tiene esa cuenta, y no se fía de lo que diga el archivo del teléfono.
-- Antes la plata y los autos eran un archivo local (profile.json): cualquiera con el teléfono rooteado se los editaba (y se saltaba la tienda de monedas).
--
-- Cómo funciona (docs/CUENTA_Y_ECONOMIA.md):
--   · account_state()  → {credits, cars, iap, streak, daily, now}: lo que dice el servidor (crea la cuenta con $5000 la primera vez).
--   · account_apply(events) → aplica en orden una tanda de eventos (cada uno con un id: repetirlo no hace nada) y devuelve el estado de verdad más el resultado de cada evento.
--       compras (auto, mejora, gomas, piezas): el PRECIO sale del catálogo del servidor (online_cat_*), no del teléfono; hace falta saldo; los autos premium sólo con una compra de la tienda.
--       premios (carreras, aventura, actividades…): el servidor limita el monto de cada premio, cuánto se puede cobrar por hora y por día, y el mismo premio no se cobra dos veces seguidas.
--       gastos sueltos (nafta, peajes…): descuentan sin pasar de cero.
--       regalo diario: una vez por día del servidor.
--   · account_iap_grant(...) → sólo para el servidor (service_role, la función de borde que verifica el recibo de Google Play): acredita monedas o desbloquea un producto, una sola vez por recibo.
-- Todas las tablas tienen RLS sin políticas: el teléfono no lee ni escribe directo, sólo llama a las funciones. Aditiva y repetible.

create table if not exists public.account_cfg (key text primary key, val bigint not null);
insert into public.account_cfg (key, val) values
  ('start_credits', 5000),    -- saldo de una cuenta nueva
  ('earn_max_one', 60000),    -- tope de un solo premio (el más grande del juego: bonus de una copa Leyenda ≈ 26000)
  ('earn_hour', 300000),      -- tope de premios por hora (jugando en serio se ganan ~100000 por hora)
  ('earn_day', 1200000),      -- tope de premios por día
  ('earn_ref_gap_s', 15),     -- el mismo premio (mismo evento) no se cobra otra vez antes de tantos segundos
  ('spend_max_one', 250000),  -- tope de un gasto suelto
  ('apply_hour', 600)         -- cuántas tandas por hora
on conflict (key) do nothing;
alter table public.account_cfg enable row level security;

create table if not exists public.account_econ (
  user_id uuid primary key references auth.users (id) on delete cascade,
  credits bigint not null default 5000 check (credits >= 0),
  cars jsonb not null default '{}'::jsonb,   -- id de auto → {bought, owned: ["engine:1", …], tires: ["street", …], parts: ["rueda_x", …]}
  iap jsonb not null default '{}'::jsonb,    -- producto → {at, hash}
  streak int not null default 0,
  last_daily date,
  seq bigint not null default 0,
  rate_at timestamptz not null default now(),   -- ventana de una hora para limitar las tandas
  rate_n int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.account_econ add column if not exists rate_at timestamptz not null default now();
alter table public.account_econ add column if not exists rate_n int not null default 0;
create table if not exists public.account_earns (id bigserial primary key, user_id uuid not null references auth.users (id) on delete cascade, at timestamptz not null default now(), kind text not null, ref text not null default '', amount int not null);
create index if not exists account_earns_user_at on public.account_earns (user_id, at desc);
create table if not exists public.account_seen (user_id uuid not null references auth.users (id) on delete cascade, event_id text not null, at timestamptz not null default now(), primary key (user_id, event_id));
-- (al borrar la cuenta queda sólo el código del comprobante, sin usuario: así el mismo recibo no se puede usar dos veces en otra cuenta)
create table if not exists public.account_iap_tokens (token_hash text primary key, user_id uuid references auth.users (id) on delete set null, product text not null, credits int not null default 0, at timestamptz not null default now());
create table if not exists public.account_products (product text primary key, kind text not null check (kind in ('coins', 'entitlement')), credits int not null default 0);
insert into public.account_products (product, kind, credits) values
  ('dr_coins_s', 'coins', 5000), ('dr_coins_m', 'coins', 12000), ('dr_coins_l', 'coins', 30000), ('dr_coins_xl', 'coins', 80000),
  ('dr_adventure', 'entitlement', 0), ('dr_full', 'entitlement', 0), ('dr_garage', 'entitlement', 0), ('car_truck', 'entitlement', 0), ('car_gt3', 'entitlement', 0), ('car_hyper', 'entitlement', 0)
on conflict (product) do update set kind = excluded.kind, credits = excluded.credits;
alter table public.account_econ enable row level security;
alter table public.account_earns enable row level security;
alter table public.account_seen enable row level security;
alter table public.account_iap_tokens enable row level security;
alter table public.account_products enable row level security;
revoke all on public.account_cfg, public.account_econ, public.account_earns, public.account_seen, public.account_iap_tokens, public.account_products from anon, authenticated;
revoke all on sequence public.account_earns_id_seq from anon, authenticated;

-- ───────────── ayudas internas (sin permiso para el juego) ─────────────
create or replace function public._acct_cfg(p_key text) returns bigint language sql stable security definer set search_path = public as $$
  select val from public.account_cfg where key = p_key
$$;

create or replace function public._acct_row(p_uid uuid) returns public.account_econ language plpgsql security definer set search_path = public as $$
declare r public.account_econ;
begin
  insert into public.account_econ (user_id, credits) values (p_uid, public._acct_cfg('start_credits')) on conflict do nothing;
  select * into r from public.account_econ where user_id = p_uid for update;
  return r;
end;
$$;

create or replace function public._acct_json(r public.account_econ) returns jsonb language sql stable as $$
  select jsonb_build_object('credits', r.credits, 'cars', r.cars, 'iap', r.iap, 'streak', r.streak, 'daily', coalesce(to_char(r.last_daily, 'YYYY-MM-DD'), ''), 'seq', r.seq, 'now', extract(epoch from now())::bigint)
$$;

-- ¿tiene el producto (o uno que lo incluye)?
create or replace function public._acct_has(r public.account_econ, p_product text) returns boolean language sql stable as $$
  select r.iap ? p_product or r.iap ? 'dr_full' or (p_product in ('car_truck', 'car_gt3', 'car_hyper') and r.iap ? 'dr_garage')
$$;

-- una sola función por evento; devuelve {ok, reason?, …}. Cualquier error (raise) deshace sólo ese evento (lo atrapa account_apply).
create or replace function public._acct_one(p_uid uuid, e jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  t text := e ->> 't';
  r public.account_econ;
  car text := left(coalesce(e ->> 'car', ''), 40);
  v_kind text := left(coalesce(e ->> 'kind', 'misc'), 16);
  v_ref text := left(coalesce(e ->> 'ref', ''), 40);
  amount bigint;
  granted bigint; used_h bigint; used_d bigint; last_at timestamptz;
  c public.online_cat_vehicles;
  u public.online_cat_upgrades;
  tr public.online_cat_tires;
  pt public.online_cat_parts;
  cur jsonb; key text; today date; stk int; base int;
  premium_cars text[] := array['truck', 'gt3', 'hyper'];
  reward_cars text[] := array['genesis'];
begin
  select * into r from public.account_econ where user_id = p_uid for update;
  if t is null then raise exception 'evento sin tipo' using errcode = '22023'; end if;

  -- ───── premios ─────
  if t = 'earn' then
    amount := coalesce((e ->> 'amount')::bigint, 0);
    if amount <= 0 then raise exception 'monto inválido' using errcode = '22023'; end if;
    if v_ref <> '' then
      select max(a.at) into last_at from public.account_earns a where a.user_id = p_uid and a.kind = v_kind and a.ref = v_ref;
      if last_at is not null and last_at > now() - make_interval(secs => public._acct_cfg('earn_ref_gap_s')) then
        return jsonb_build_object('ok', false, 'reason', 'ese premio ya se cobró');
      end if;
    end if;
    amount := least(amount, public._acct_cfg('earn_max_one'));
    select coalesce(sum(a.amount), 0) into used_h from public.account_earns a where a.user_id = p_uid and a.at > now() - interval '1 hour';
    select coalesce(sum(a.amount), 0) into used_d from public.account_earns a where a.user_id = p_uid and a.at > now() - interval '24 hours';
    granted := least(amount, greatest(0, public._acct_cfg('earn_hour') - used_h), greatest(0, public._acct_cfg('earn_day') - used_d));
    if granted <= 0 then return jsonb_build_object('ok', false, 'reason', 'llegaste al límite de premios, probá en un rato'); end if;
    insert into public.account_earns (user_id, kind, ref, amount) values (p_uid, v_kind, v_ref, granted);
    delete from public.account_earns where user_id = p_uid and at < now() - interval '3 days';
    update public.account_econ set credits = credits + granted where user_id = p_uid;
    return jsonb_build_object('ok', true, 'granted', granted, 'clamped', granted < coalesce((e ->> 'amount')::bigint, 0));

  -- ───── gastos sueltos (nafta, peajes, trámites) ─────
  elsif t = 'spend' then
    amount := coalesce((e ->> 'amount')::bigint, 0);
    if amount <= 0 or amount > public._acct_cfg('spend_max_one') then raise exception 'monto inválido' using errcode = '22023'; end if;
    update public.account_econ set credits = greatest(0, credits - amount) where user_id = p_uid returning credits into amount;
    return jsonb_build_object('ok', true);

  -- ───── regalo diario ─────
  elsif t = 'daily' then
    today := (now() at time zone 'utc')::date;
    if r.last_daily = today then return jsonb_build_object('ok', false, 'reason', 'ya cobraste el regalo de hoy'); end if;
    stk := case when r.last_daily = today - 1 then least(7, r.streak + 1) else 1 end;
    base := 300 + stk * 150;
    update public.account_econ set credits = credits + base, streak = stk, last_daily = today where user_id = p_uid;
    return jsonb_build_object('ok', true, 'amount', base, 'streak', stk);

  -- ───── autos ─────
  elsif t = 'buy_car' then
    select * into c from public.online_cat_vehicles where id = car;
    if not found then raise exception 'ese auto no existe' using errcode = '22023'; end if;
    if car = any (premium_cars) then raise exception 'ese auto se desbloquea con una compra de la tienda' using errcode = '42501'; end if;
    if car = any (reward_cars) then raise exception 'ese auto es un premio de la aventura' using errcode = '42501'; end if;
    if r.cars ? car then raise exception 'ya tenés ese auto' using errcode = '22023'; end if;
    update public.account_econ set credits = credits - c.price where user_id = p_uid and credits >= c.price;
    if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
    update public.account_econ set cars = cars || jsonb_build_object(car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', '[]'::jsonb, 'tires', '["street"]'::jsonb, 'parts', '[]'::jsonb)) where user_id = p_uid;
    return jsonb_build_object('ok', true, 'price', c.price);

  elsif t = 'give_car' then
    v_kind := left(coalesce(e ->> 'why', ''), 16);
    select * into c from public.online_cat_vehicles where id = car;
    if not found then raise exception 'ese auto no existe' using errcode = '22023'; end if;
    if r.cars ? car then return jsonb_build_object('ok', true, 'dup', true); end if;
    if v_kind = 'starter' then
      if r.cars <> '{}'::jsonb or not c.starter then raise exception 'ese no es el auto de partida' using errcode = '42501'; end if;
    elsif v_kind = 'iap' then
      if not (car = any (premium_cars)) or not public._acct_has(r, 'car_' || car) then raise exception 'falta la compra de ese auto' using errcode = '42501'; end if;
    elsif v_kind = 'adventure' then
      if not (car = any (reward_cars)) then raise exception 'ese auto no es un premio de la aventura' using errcode = '42501'; end if;
    else
      raise exception 'motivo inválido' using errcode = '22023';
    end if;
    update public.account_econ set cars = cars || jsonb_build_object(car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', '[]'::jsonb, 'tires', '["street"]'::jsonb, 'parts', '[]'::jsonb)) where user_id = p_uid;
    return jsonb_build_object('ok', true);

  -- ───── mejoras, gomas y piezas ─────
  elsif t in ('buy_upgrade', 'buy_tires', 'replace_tires', 'buy_part') then
    if not (r.cars ? car) then raise exception 'ese auto no es tuyo' using errcode = '42501'; end if;
    cur := r.cars -> car;
    if t = 'buy_upgrade' then
      select * into u from public.online_cat_upgrades where category = left(coalesce(e ->> 'cat', ''), 24) and level = coalesce((e ->> 'level')::int, 0);
      if not found then raise exception 'esa mejora no existe' using errcode = '22023'; end if;
      key := u.category || ':' || u.level;
      if cur -> 'owned' ? key then return jsonb_build_object('ok', true, 'dup', true); end if;
      update public.account_econ set credits = credits - u.price where user_id = p_uid and credits >= u.price;
      if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
      update public.account_econ set cars = jsonb_set(cars, array[car, 'owned'], (cars -> car -> 'owned') || to_jsonb(key)) where user_id = p_uid;
      return jsonb_build_object('ok', true, 'price', u.price);
    elsif t = 'buy_tires' then
      select * into tr from public.online_cat_tires where id = left(coalesce(e ->> 'tire', ''), 24);
      if not found then raise exception 'esas gomas no existen' using errcode = '22023'; end if;
      if cur -> 'tires' ? tr.id then return jsonb_build_object('ok', true, 'dup', true); end if;
      update public.account_econ set credits = credits - tr.price where user_id = p_uid and credits >= tr.price;
      if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
      update public.account_econ set cars = jsonb_set(cars, array[car, 'tires'], (cars -> car -> 'tires') || to_jsonb(tr.id)) where user_id = p_uid;
      return jsonb_build_object('ok', true, 'price', tr.price);
    elsif t = 'replace_tires' then
      -- cambiar el juego de gomas puesto: la mitad de su precio (mínimo 250, múltiplos de 50), con hasta 20 % de descuento por el rango del jugador
      select * into tr from public.online_cat_tires where id = left(coalesce(e ->> 'tire', ''), 24);
      if not found then raise exception 'esas gomas no existen' using errcode = '22023'; end if;
      base := greatest(250, round(tr.price * 0.5 / 50.0)::int * 50);
      amount := coalesce((e ->> 'cost')::bigint, 0);
      if amount < floor(base * 0.79) or amount > ceil(base * 1.01) then raise exception 'precio inválido' using errcode = '22023'; end if;
      update public.account_econ set credits = credits - amount where user_id = p_uid and credits >= amount;
      if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
      return jsonb_build_object('ok', true, 'price', amount);
    else
      select * into pt from public.online_cat_parts where id = left(coalesce(e ->> 'part', ''), 48);
      if not found then raise exception 'esa pieza no existe' using errcode = '22023'; end if;
      if cardinality(pt.vehicles) > 0 and not (car = any (pt.vehicles)) then raise exception 'esa pieza no va en ese auto' using errcode = '22023'; end if;
      if cur -> 'parts' ? pt.id then return jsonb_build_object('ok', true, 'dup', true); end if;
      update public.account_econ set credits = credits - pt.price where user_id = p_uid and credits >= pt.price;
      if not found then raise exception 'no te alcanza el dinero' using errcode = 'P0001'; end if;
      update public.account_econ set cars = jsonb_set(cars, array[car, 'parts'], (cars -> car -> 'parts') || to_jsonb(pt.id)) where user_id = p_uid;
      return jsonb_build_object('ok', true, 'price', pt.price);
    end if;
  end if;
  raise exception 'evento desconocido' using errcode = '22023';
end;
$$;

-- ───────────── lo que usa el juego ─────────────
create or replace function public.account_state() returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); r public.account_econ;
begin
  r := public._acct_row(uid);
  return public._acct_json(r);
end;
$$;

create or replace function public.account_apply(p_events jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); r public.account_econ; e jsonb; res jsonb := '[]'::jsonb; one jsonb; eid text;
begin
  if p_events is null or jsonb_typeof(p_events) <> 'array' then raise exception 'eventos inválidos' using errcode = '22023'; end if;
  if jsonb_array_length(p_events) > 60 then raise exception 'demasiados eventos juntos' using errcode = '22023'; end if;
  r := public._acct_row(uid);
  if r.rate_at < now() - interval '1 hour' then
    update public.account_econ set rate_at = now(), rate_n = 1 where user_id = uid;
  else
    if r.rate_n >= public._acct_cfg('apply_hour') then raise exception 'demasiadas acciones, esperá un rato' using errcode = '53400'; end if;
    update public.account_econ set rate_n = rate_n + 1 where user_id = uid;
  end if;
  for e in select * from jsonb_array_elements(p_events) loop
    eid := left(coalesce(e ->> 'id', ''), 64);
    if eid = '' then
      res := res || jsonb_build_array(jsonb_build_object('id', eid, 'ok', false, 'reason', 'evento sin id'));
      continue;
    end if;
    if exists (select 1 from public.account_seen where user_id = uid and event_id = eid) then
      res := res || jsonb_build_array(jsonb_build_object('id', eid, 'ok', true, 'dup', true));
      continue;
    end if;
    begin
      one := public._acct_one(uid, e);
    exception when others then
      one := jsonb_build_object('ok', false, 'reason', sqlerrm);
    end;
    insert into public.account_seen (user_id, event_id) values (uid, eid) on conflict do nothing;
    res := res || jsonb_build_array(jsonb_build_object('id', eid) || one);
  end loop;
  delete from public.account_seen where user_id = uid and at < now() - interval '14 days';
  update public.account_econ set seq = seq + 1, updated_at = now() where user_id = uid returning * into r;
  return public._acct_json(r) || jsonb_build_object('results', res);
end;
$$;

-- Sólo para el servidor (la función de borde que verifica el recibo con Google Play): acredita las monedas o desbloquea el producto, UNA vez por recibo
create or replace function public.account_iap_grant(p_user uuid, p_product text, p_token_hash text) returns jsonb language plpgsql security definer set search_path = public as $$
declare pr public.account_products; r public.account_econ;
begin
  select * into pr from public.account_products where product = p_product;
  if not found then raise exception 'producto desconocido' using errcode = '22023'; end if;
  if p_token_hash is null or length(p_token_hash) < 16 then raise exception 'recibo inválido' using errcode = '22023'; end if;
  if not exists (select 1 from auth.users where id = p_user) then raise exception 'usuario desconocido' using errcode = '22023'; end if;
  r := public._acct_row(p_user);
  insert into public.account_iap_tokens (token_hash, user_id, product, credits) values (p_token_hash, p_user, p_product, pr.credits) on conflict do nothing;
  if not found then return public._acct_json(r) || jsonb_build_object('dup', true); end if;
  if pr.kind = 'coins' then
    update public.account_econ set credits = credits + pr.credits, updated_at = now() where user_id = p_user returning * into r;
  else
    update public.account_econ set iap = iap || jsonb_build_object(p_product, jsonb_build_object('at', extract(epoch from now())::bigint, 'hash', left(p_token_hash, 12))), updated_at = now() where user_id = p_user returning * into r;
  end if;
  return public._acct_json(r) || jsonb_build_object('granted', pr.credits);
end;
$$;

-- Sólo para el dueño (editor SQL de Supabase o service_role; el juego no puede llamarla): regalarle créditos y autos a una cuenta por su correo (probadores, compensaciones, el progreso que
-- alguien tenía antes de que la economía pasara al servidor). Ejemplo:  select public.account_admin_grant('alguien@correo.com', 50000, array['gt','hatch2']);
create or replace function public.account_admin_grant(p_email text, p_credits bigint default 0, p_cars text[] default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid; r public.account_econ; c text;
begin
  select id into uid from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if uid is null then raise exception 'no hay una cuenta con ese correo' using errcode = '22023'; end if;
  r := public._acct_row(uid);
  if coalesce(p_credits, 0) <> 0 then
    update public.account_econ set credits = greatest(0, credits + p_credits) where user_id = uid;
  end if;
  foreach c in array coalesce(p_cars, '{}'::text[]) loop
    if exists (select 1 from public.online_cat_vehicles v where v.id = c) then
      update public.account_econ set cars = cars || jsonb_build_object(c, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', '[]'::jsonb, 'tires', '["street"]'::jsonb, 'parts', '[]'::jsonb))
        where user_id = uid and not (cars ? c);
    else
      raise exception 'ese auto no existe: %', c using errcode = '22023';
    end if;
  end loop;
  update public.account_econ set updated_at = now(), seq = seq + 1 where user_id = uid returning * into r;
  return public._acct_json(r);
end;
$$;

-- permisos: el teléfono sólo ve account_state y account_apply; account_iap_grant y account_admin_grant son del servidor
revoke all on function public._acct_cfg(text) from public, anon, authenticated;
revoke all on function public._acct_row(uuid) from public, anon, authenticated;
revoke all on function public._acct_json(public.account_econ) from public, anon, authenticated;
revoke all on function public._acct_has(public.account_econ, text) from public, anon, authenticated;
revoke all on function public._acct_one(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.account_iap_grant(uuid, text, text) from public, anon, authenticated;
revoke all on function public.account_admin_grant(text, bigint, text[]) from public, anon, authenticated;
revoke all on function public.account_state() from public, anon;
revoke all on function public.account_apply(jsonb) from public, anon;
grant execute on function public.account_state() to authenticated;
grant execute on function public.account_apply(jsonb) to authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.account_iap_grant(uuid, text, text) to service_role;
    grant execute on function public.account_admin_grant(text, bigint, text[]) to service_role;
  end if;
end $$;
