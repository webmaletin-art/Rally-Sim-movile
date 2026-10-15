-- Caza recompensas (15/10/2026, pedido del dueño: «si te pegás a la IA mucho tiempo, ese auto es tuyo»): el evento give_car acepta el motivo «bounty».
-- Reglas del servidor (el juego aplica las mismas): ni premium (truck, gt3, hyper) ni premios de la aventura (genesis) ni especiales (police, f1, t1plus),
-- precio de catálogo hasta $150.000 y UN auto de recompensa cada 20 h por cuenta (se anota en account_earns, kind «bounty_car», monto 0; no toca los topes de premios).
-- Es la misma función de 20261014000000_account_economy.sql con esa rama agregada (nada más cambia).

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
    elsif v_kind = 'bounty' then
      -- Caza recompensas (city_modes.gd): el auto que atrapaste. Nunca premium ni premios de la aventura ni especiales, hasta $150.000 y UNO por día por cuenta.
      if car = any (premium_cars) or car = any (reward_cars) or car = any (array['police', 'f1', 't1plus']) then raise exception 'ese auto no se puede cazar' using errcode = '42501'; end if;
      if c.price > 150000 then raise exception 'ese auto es demasiado caro para una recompensa' using errcode = '42501'; end if;
      if exists (select 1 from public.account_earns a where a.user_id = p_uid and a.kind = 'bounty_car' and a.at > now() - interval '20 hours') then
        return jsonb_build_object('ok', false, 'reason', 'ya ganaste un auto de recompensa hoy');
      end if;
      insert into public.account_earns (user_id, kind, ref, amount) values (p_uid, 'bounty_car', car, 0);
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
