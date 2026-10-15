-- Dream Racing · 15/10/2026 (pedido del dueño): eventos largos «tipo temporada», desafíos de drift y premios nuevos.
--   «Hay eventos que pueden estar por una semana, tipo temporada, para ganarse un súper deportivo, una skin, 50.000 pesos en reparaciones/mejoras;
--    o eventos de drifting: quien hace el mayor puntaje durante un tiempo limitado se lleva una mejora de drifting o tal vehículo.»
--   · season  TEMPORADA (7 días): cada evento que cumplís en la semana suma puntos (ganar suma el doble). Al cerrar, premios por puesto.
--   · drift   DESAFÍO DE DRIFT: en la Plaza de Drift, una sesión de run_s segundos; vale tu mejor puntaje. Al cerrar, premios por puesto.
--   · premios nuevos en _wev_grant: {"voucher": n} VALE DE TALLER (saldo aparte que sólo se gasta en mejoras, gomas, piezas, diseños y reglajes),
--     {"skin": id} un diseño para todos tus autos, {"tires": id} un juego de gomas para todos tus autos, {"car": "id"} un auto puntual.
--     En las tablas por puesto («top») cada premio puede ser un número (créditos) o un objeto con cualquiera de esos premios.
--   · el vale se usa solo: _acct_one pasa a ser un envoltorio de la función de siempre (_acct_one_base) que pone el vale delante de los créditos
--     en las compras del taller y devuelve lo que no se usó. OJO: una migración futura que reemplace _acct_one entera tiene que reemplazar _acct_one_base.
-- Aditivo y repetible. (Nunca nombrar una función «_<tabla>»: Postgres ya usa ese nombre para el tipo arreglo de la tabla.)

-- ───────────── vale de taller ─────────────
alter table public.account_econ add column if not exists voucher bigint not null default 0;
alter table public.account_econ drop constraint if exists account_econ_voucher_check;
alter table public.account_econ add constraint account_econ_voucher_check check (voucher >= 0);

create or replace function public._acct_json(r public.account_econ) returns jsonb language sql stable as $$
  select jsonb_build_object('credits', r.credits, 'voucher', r.voucher, 'cars', r.cars, 'iap', r.iap, 'streak', r.streak, 'daily', coalesce(to_char(r.last_daily, 'YYYY-MM-DD'), ''),
    'seq', r.seq, 'now', extract(epoch from now())::bigint)
$$;
revoke all on function public._acct_json(public.account_econ) from public, anon, authenticated;

do $do$
begin
  if to_regprocedure('public._acct_one_base(uuid, jsonb)') is null then
    alter function public._acct_one(uuid, jsonb) rename to _acct_one_base;
  end if;
end;
$do$;
revoke all on function public._acct_one_base(uuid, jsonb) from public, anon, authenticated;

-- compras del taller: el vale va primero (el juego hace la misma cuenta y la manda como «v» en el evento, sólo para mostrarla)
create or replace function public._acct_one(p_uid uuid, e jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare t text := e ->> 't'; v bigint; c0 bigint; c1 bigint; used bigint; res jsonb;
begin
  if t in ('buy_upgrade', 'buy_tires', 'replace_tires', 'buy_part') or (t = 'spend' and coalesce(e ->> 'kind', '') in ('tune', 'repair')) then
    select a.voucher, a.credits into v, c0 from public.account_econ a where a.user_id = p_uid for update;
    if coalesce(v, 0) > 0 then
      update public.account_econ set credits = credits + v, voucher = 0 where user_id = p_uid;
      res := public._acct_one_base(p_uid, e);
      select a.credits into c1 from public.account_econ a where a.user_id = p_uid;
      used := least(v, greatest(0, c0 + v - c1));
      update public.account_econ set credits = credits - (v - used), voucher = v - used where user_id = p_uid;
      return res || jsonb_build_object('voucher_used', used);
    end if;
  end if;
  return public._acct_one_base(p_uid, e);
end;
$$;
revoke all on function public._acct_one(uuid, jsonb) from public, anon, authenticated;

-- ───────────── tipos nuevos ─────────────
alter table public.wev_templates drop constraint if exists wev_templates_kind_check;
alter table public.wev_templates add constraint wev_templates_kind_check check (kind in ('bounty', 'escape', 'reach', 'record', 'drift', 'season'));
update public.wev_cfg set val = '5' where key = 'max_open' and val = '4'; -- la temporada ocupa un lugar todo el tiempo

-- ───────────── premios ─────────────
create or replace function public._wev_grant(p_uid uuid, p_reward jsonb, p_car text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.account_econ; v_car text; price bigint; v_until bigint; cur jsonb; res jsonb := '{}'::jsonb; k text; n int; v bigint; pt public.online_cat_parts; ti public.online_cat_tires;
begin
  r := public._acct_row(p_uid);
  if p_reward ? 'credits' then
    v := greatest(0, least((p_reward ->> 'credits')::bigint, 200000));
    update public.account_econ set credits = credits + v where user_id = p_uid;
    res := res || jsonb_build_object('credits', v);
  end if;
  if p_reward ? 'voucher' then
    v := greatest(0, least((p_reward ->> 'voucher')::bigint, 200000));
    update public.account_econ set voucher = voucher + v where user_id = p_uid;
    res := res || jsonb_build_object('voucher', v);
  end if;
  if p_reward ? 'car' then
    v_car := coalesce(p_car, case when jsonb_typeof(p_reward -> 'car') = 'string' then p_reward ->> 'car' end);
    if v_car is not null and exists (select 1 from public.online_cat_vehicles c where c.id = v_car) then
      select * into r from public.account_econ where user_id = p_uid;
      cur := r.cars -> v_car;
      if cur is not null and not (cur ? 'until') then
        select coalesce(c.price, 0) into price from public.online_cat_vehicles c where c.id = v_car;
        update public.account_econ set credits = credits + coalesce(price, 0) / 2 where user_id = p_uid;
        res := res || jsonb_build_object('car', v_car, 'dup', true, 'credits', coalesce((res ->> 'credits')::bigint, 0) + coalesce(price, 0) / 2);
      else
        update public.account_econ set cars = cars || jsonb_build_object(v_car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', coalesce(cur -> 'owned', '[]'::jsonb),
          'tires', coalesce(cur -> 'tires', '["street"]'::jsonb), 'parts', coalesce(cur -> 'parts', '[]'::jsonb))) where user_id = p_uid;
        res := res || jsonb_build_object('car', v_car);
      end if;
    end if;
  end if;
  if p_reward ? 'rent' then
    v_car := p_reward ->> 'rent';
    select * into r from public.account_econ where user_id = p_uid;
    cur := r.cars -> v_car;
    if cur is null or (cur ? 'until') then
      v_until := greatest(coalesce((cur ->> 'until')::bigint, 0), extract(epoch from now())::bigint) + greatest(1, least(coalesce((p_reward ->> 'days')::int, 1), 30)) * 86400;
      update public.account_econ set cars = cars || jsonb_build_object(v_car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', coalesce(cur -> 'owned', '[]'::jsonb),
        'tires', coalesce(cur -> 'tires', '["street"]'::jsonb), 'parts', coalesce(cur -> 'parts', '[]'::jsonb), 'until', v_until)) where user_id = p_uid;
      res := res || jsonb_build_object('rent', v_car, 'until', v_until);
    else
      res := res || jsonb_build_object('rent', v_car, 'had', true);
    end if;
  end if;
  -- un diseño (pieza cosmética) para todos los autos de la cuenta en los que va
  if p_reward ? 'skin' then
    select * into pt from public.online_cat_parts where id = p_reward ->> 'skin';
    if found then
      n := 0;
      select * into r from public.account_econ where user_id = p_uid;
      for k in select jsonb_object_keys(r.cars) loop
        if (cardinality(pt.vehicles) = 0 or k = any (pt.vehicles)) and not (coalesce(r.cars -> k -> 'parts', '[]'::jsonb) ? pt.id) then
          update public.account_econ set cars = jsonb_set(cars, array[k, 'parts'], coalesce(cars -> k -> 'parts', '[]'::jsonb) || to_jsonb(pt.id)) where user_id = p_uid;
          n := n + 1;
        end if;
      end loop;
      res := res || jsonb_build_object('skin', pt.id, 'skin_cars', n);
    end if;
  end if;
  -- un juego de gomas (p. ej. las de drift) para todos los autos de la cuenta
  if p_reward ? 'tires' then
    select * into ti from public.online_cat_tires where id = p_reward ->> 'tires';
    if found then
      n := 0;
      select * into r from public.account_econ where user_id = p_uid;
      for k in select jsonb_object_keys(r.cars) loop
        if not (coalesce(r.cars -> k -> 'tires', '[]'::jsonb) ? ti.id) then
          update public.account_econ set cars = jsonb_set(cars, array[k, 'tires'], coalesce(cars -> k -> 'tires', '["street"]'::jsonb) || to_jsonb(ti.id)) where user_id = p_uid;
          n := n + 1;
        end if;
      end loop;
      res := res || jsonb_build_object('tires', ti.id, 'tires_cars', n);
    end if;
  end if;
  return res;
end;
$$;
revoke all on function public._wev_grant(uuid, jsonb, text) from public, anon, authenticated;

-- ───────────── posiciones ─────────────
-- temporada: cada evento (que no sea otra temporada) con un intento logrado dentro de la semana suma params.pts[tipo]; ganarlo (premio) suma lo mismo otra vez
create or replace function public._wev_season_rows(p_ev bigint) returns table (who uuid, pts bigint) language sql stable security definer set search_path = public as $$
  with s as (select x.starts_at, x.ends_at, x.params from public.wev_events x where x.id = p_ev and x.kind = 'season'),
  done as (select distinct r.user_id u, x.id ev, x.kind k from public.wev_runs r join public.wev_events x on x.id = r.event_id cross join s
           where r.ok and x.kind <> 'season' and r.finished_at >= s.starts_at and r.finished_at <= s.ends_at),
  wins as (select w.user_id u, x.kind k from public.wev_winners w join public.wev_events x on x.id = w.event_id cross join s
           where x.kind <> 'season' and w.user_id is not null and w.at >= s.starts_at and w.at <= s.ends_at),
  allp as (select d.u, d.k from done d union all select w.u, w.k from wins w)
  select a.u, sum(coalesce((s.params -> 'pts' ->> a.k)::int, 10))::bigint from allp a cross join s group by a.u order by 2 desc
$$;
revoke all on function public._wev_season_rows(bigint) from public, anon, authenticated;

-- la tabla de un evento por puesto: carrera (menos tiempo), drift (más puntos), temporada (más puntos)
create or replace function public._wev_rank(p_ev bigint, p_kind text) returns table (who uuid, val numeric) language sql stable security definer set search_path = public as $$
  select z.u, z.b from (
    select r.user_id u, case when p_kind = 'drift' then max(r.value) else min(r.value) end b
      from public.wev_runs r where r.event_id = p_ev and r.ok and r.value is not null and p_kind in ('record', 'drift') group by r.user_id
    union all
    select s.who, s.pts::numeric from public._wev_season_rows(p_ev) s where p_kind = 'season') z
  order by case when p_kind = 'record' then z.b else -z.b end
$$;
revoke all on function public._wev_rank(bigint, text) from public, anon, authenticated;

-- cierra los eventos que terminaron: los de tabla (carrera, drift, temporada) pagan por puesto
create or replace function public._wev_close() returns void language plpgsql security definer set search_path = public as $$
declare e public.wev_events; w record; pos int; tops jsonb; prize jsonb; got jsonb;
begin
  for e in select * from public.wev_events where not closed and ends_at < now() for update skip locked loop
    if e.kind in ('record', 'drift', 'season') then
      pos := 0;
      tops := coalesce(e.reward -> 'top', '[]'::jsonb);
      for w in select * from public._wev_rank(e.id, e.kind) loop
        exit when pos >= jsonb_array_length(tops);
        prize := tops -> pos;
        if jsonb_typeof(prize) = 'number' then prize := jsonb_build_object('credits', prize); end if;
        got := public._wev_grant(w.who, prize);
        insert into public.wev_winners (event_id, user_id, name, slot, value, reward)
        values (e.id, w.who, coalesce((select name from public.players where id = w.who), 'Piloto'), pos, w.val, got);
        pos := pos + 1;
      end loop;
    end if;
    update public.wev_events set closed = true where id = e.id;
  end loop;
end;
$$;
revoke all on function public._wev_close() from public, anon, authenticated;

create or replace function public._wev_json(e public.wev_events, p_uid uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', e.id, 'tpl', e.tpl, 'kind', e.kind, 'title', e.title, 'descr', e.descr, 'params', e.params, 'reward', e.reward,
    'starts', extract(epoch from e.starts_at)::bigint, 'ends', extract(epoch from e.ends_at)::bigint, 'attempts', e.attempts, 'max_winners', e.max_winners, 'seed', e.seed,
    'used', (select count(*) from public.wev_runs r where r.event_id = e.id and r.user_id = p_uid),
    'done', exists (select 1 from public.wev_winners w where w.event_id = e.id and w.user_id = p_uid),
    'best', case when e.kind = 'drift' then (select max(r.value) from public.wev_runs r where r.event_id = e.id and r.user_id = p_uid and r.ok)
                 else (select min(r.value) from public.wev_runs r where r.event_id = e.id and r.user_id = p_uid and r.ok) end,
    'pts', case when e.kind = 'season' then coalesce((select s.pts from public._wev_season_rows(e.id) s where s.who = p_uid), 0) end,
    'rank', case when e.kind in ('season', 'drift', 'record') then (select z.rk from (select k.who, row_number() over (order by case when e.kind = 'record' then k.val else -k.val end) rk from public._wev_rank(e.id, e.kind) k) z where z.who = p_uid) end,
    'players', case when e.kind in ('season', 'drift', 'record') then (select count(*) from public._wev_rank(e.id, e.kind)) end,
    'winners', coalesce((select jsonb_agg(jsonb_build_object('name', w.name, 'slot', w.slot, 'value', w.value) order by w.at) from public.wev_winners w where w.event_id = e.id), '[]'::jsonb))
$$;
revoke all on function public._wev_json(public.wev_events, uuid) from public, anon, authenticated;

-- ───────────── lo que usa el juego ─────────────
create or replace function public.event_start(p_id bigint, p_slot int default 0) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); e public.wev_events; used int; rid bigint;
begin
  select * into e from public.wev_events where id = p_id;
  if not found then raise exception 'ese evento no existe' using errcode = '22023'; end if;
  if e.kind = 'season' then return jsonb_build_object('ok', false, 'reason', 'la temporada se juega con los demás eventos'); end if;
  if now() < e.starts_at - interval '20 seconds' or now() > e.ends_at then return jsonb_build_object('ok', false, 'reason', 'el evento no está en curso'); end if;
  if exists (select 1 from public.wev_winners w where w.event_id = p_id and w.user_id = uid) and e.kind not in ('record', 'drift') then
    return jsonb_build_object('ok', false, 'reason', 'ya ganaste este evento');
  end if;
  if e.kind = 'bounty' then
    if p_slot < 0 or p_slot >= coalesce(jsonb_array_length(e.params -> 'cars'), 0) then raise exception 'auto inválido' using errcode = '22023'; end if;
    if exists (select 1 from public.wev_winners w where w.event_id = p_id and w.slot = p_slot) then return jsonb_build_object('ok', false, 'reason', 'ese auto ya lo atrapó otro'); end if;
    select id into rid from public.wev_runs where event_id = p_id and user_id = uid and slot = p_slot and finished_at is null order by started_at limit 1;
    if rid is not null then return jsonb_build_object('ok', true, 'run', rid, 'now', extract(epoch from now())::bigint); end if;
  end if;
  select count(*) into used from public.wev_runs where event_id = p_id and user_id = uid;
  if e.attempts > 0 and used >= e.attempts then return jsonb_build_object('ok', false, 'reason', 'ya usaste tus ' || e.attempts || ' intentos'); end if;
  if used >= 60 then return jsonb_build_object('ok', false, 'reason', 'demasiados intentos'); end if;
  insert into public.wev_runs (event_id, user_id, slot) values (p_id, uid, greatest(p_slot, 0)) returning id into rid;
  return jsonb_build_object('ok', true, 'run', rid, 'now', extract(epoch from now())::bigint, 'left', case when e.attempts > 0 then e.attempts - used - 1 else -1 end);
end;
$$;
revoke all on function public.event_start(bigint, int) from public, anon;
grant execute on function public.event_start(bigint, int) to authenticated;

create or replace function public.event_finish(p_run bigint, p_ok boolean, p_value numeric default null, p_trace jsonb default null, p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); run public.wev_runs; e public.wev_events; el numeric; why text := ''; nm text; got jsonb := '{}'::jsonb; nwin int; v_car text; prm jsonb; run_s numeric;
begin
  if p_trace is not null and (jsonb_typeof(p_trace) <> 'array' or jsonb_array_length(p_trace) > 600) then raise exception 'recorrido inválido' using errcode = '22023'; end if;
  select * into run from public.wev_runs where id = p_run and user_id = uid for update;
  if not found then raise exception 'ese intento no existe' using errcode = '22023'; end if;
  if run.finished_at is not null then return jsonb_build_object('ok', false, 'reason', 'ese intento ya terminó'); end if;
  select * into e from public.wev_events where id = run.event_id for update;
  el := extract(epoch from (now() - run.started_at));
  prm := e.params;
  update public.wev_runs set finished_at = now(), ok = false, value = p_value, trace = p_trace where id = p_run;
  if not coalesce(p_ok, false) then return jsonb_build_object('ok', true, 'won', false); end if;
  -- validación por tipo
  if now() > e.ends_at + interval '2 minutes' then why := 'el evento ya terminó';
  elsif e.kind = 'bounty' then
    if el < coalesce((prm ->> 'hold_s')::numeric, 60) + 5 then why := 'todavía no pudiste completar la barra';
    elsif exists (select 1 from public.wev_winners w where w.event_id = e.id and w.slot = run.slot) then why := 'ese auto ya lo atrapó ' || (select name from public.wev_winners w where w.event_id = e.id and w.slot = run.slot limit 1);
    elsif exists (select 1 from public.wev_winners w where w.event_id = e.id and w.user_id = uid) then why := 'ya atrapaste uno en este evento';
    elsif exists (select 1 from public.wev_winners w join public.wev_events x on x.id = w.event_id where w.user_id = uid and x.kind = 'bounty' and w.at > now() - make_interval(days => coalesce(public._wev_conf('bounty_cooldown_d'), '7')::int)) then
      why := 'ya ganaste un auto de cacería hace poco: dejá que lo gane otro';
    end if;
  elsif e.kind = 'escape' then
    if p_value is null or p_value < coalesce((prm ->> 'chase_s')::numeric, 600) or p_value > el + 10 then why := 'la persecución no llegó al tiempo pedido'; end if;
  elsif e.kind = 'reach' then
    if p_value is null or p_value < 60 or p_value > coalesce((prm ->> 'time_max')::numeric, 1800) or p_value > el + 10 then why := 'tiempo imposible'; end if;
  elsif e.kind = 'record' then
    if p_value is null or p_value < 8 or p_value > 3600 or p_value > el + 10 then why := 'tiempo imposible'; end if;
  elsif e.kind = 'drift' then
    -- la sesión dura run_s segundos (se termina entera) y no se pueden hacer más de cap_rate puntos por segundo
    run_s := coalesce((prm ->> 'run_s')::numeric, 90);
    if p_value is null or p_value <= 0 or el < run_s - 5 or p_value > coalesce((prm ->> 'cap_rate')::numeric, 1500) * least(el, run_s + 10) then why := 'puntaje imposible'; end if;
  else
    why := 'este evento no se juega así';
  end if;
  if why <> '' then return jsonb_build_object('ok', true, 'won', false, 'reason', why); end if;
  update public.wev_runs set ok = true where id = p_run;
  nm := coalesce((select name from public.players where id = uid), nullif(left(trim(coalesce(p_name, '')), 20), ''), 'Piloto');
  if e.kind in ('record', 'drift') then
    return jsonb_build_object('ok', true, 'won', false, 'saved', true, 'rank', (select count(*) + 1 from (select case when e.kind = 'drift' then max(r.value) else min(r.value) end b
      from public.wev_runs r where r.event_id = e.id and r.ok group by r.user_id) s where (e.kind = 'record' and s.b < p_value) or (e.kind = 'drift' and s.b > p_value)));
  end if;
  if exists (select 1 from public.wev_winners w where w.event_id = e.id and w.user_id = uid) then return jsonb_build_object('ok', true, 'won', false, 'reason', 'ya ganaste este evento'); end if;
  select count(*) into nwin from public.wev_winners where event_id = e.id;
  if e.kind <> 'bounty' and e.max_winners > 0 and nwin >= e.max_winners then return jsonb_build_object('ok', true, 'won', false, 'reason', 'ya se entregaron todos los premios'); end if;
  v_car := case when e.kind = 'bounty' then prm -> 'cars' ->> run.slot else null end;
  got := public._wev_grant(uid, e.reward, v_car);
  insert into public.wev_winners (event_id, user_id, name, slot, value, reward) values (e.id, uid, nm, run.slot, p_value, got);
  return jsonb_build_object('ok', true, 'won', true, 'reward', got);
end;
$$;
revoke all on function public.event_finish(bigint, boolean, numeric, jsonb, text) from public, anon;
grant execute on function public.event_finish(bigint, boolean, numeric, jsonb, text) to authenticated;

-- la tabla de un evento por puesto (carrera de la semana, drift, temporada)
create or replace function public.event_board(p_id bigint, p_limit int default 10) returns jsonb language sql stable security definer set search_path = public as $$
  with ev as (select x.kind from public.wev_events x where x.id = p_id),
  t as (select k.who, k.val, row_number() over (order by case when ev.kind = 'record' then k.val else -k.val end) rk from ev cross join lateral public._wev_rank(p_id, ev.kind) k)
  select coalesce(jsonb_agg(jsonb_build_object('rank', q.rk, 'name', coalesce(p.name, 'Piloto'), 'value', q.val, 'is_me', q.who = auth.uid()) order by q.rk), '[]'::jsonb)
  from (select * from t order by t.rk limit greatest(1, least(coalesce(p_limit, 10), 50))) q left join public.players p on p.id = q.who
$$;
revoke all on function public.event_board(bigint, int) from public;
grant execute on function public.event_board(bigint, int) to anon, authenticated;

-- ───────────── plantillas nuevas (premios justos; se cambian desde el panel) ─────────────
insert into public.wev_templates (id, kind, title, descr, weight, params, reward, duration_min, attempts, max_winners, notice_min, cooldown_h, hours_utc) values
  ('temporada', 'season', 'Temporada de la semana',
   'Toda la semana: cada evento que cumplís suma puntos (cacería 100, fuga 40, contrarreloj 30, carrera y drift 25) y ganarlo suma el doble. 1.º: el Veltor Max Pro GTR. 2.º: el diseño Oro para todos tus autos y $50.000 de vale de taller. 3.º a 5.º: $25.000 de vale de taller.', 6,
   '{"pts": {"bounty": 100, "escape": 40, "reach": 30, "record": 25, "drift": 25}}',
   '{"top": [{"car": "veltor_gtr"}, {"skin": "st_oro", "voucher": 50000}, {"voucher": 25000}, {"voucher": 25000}, {"voucher": 25000}]}', 10080, 0, 5, 120, 160, null),
  ('drift_finde', 'drift', 'Desafío de drift',
   'En la Plaza de Drift (al final de la Ruta 60): 90 segundos para hacer la mayor cantidad de puntos. Vale tu mejor intento. 1.º: el KAIRÓS KL5. 2.º y 3.º: gomas de drift para todos tus autos y vale de taller.', 3,
   '{"run_s": 90, "cap_rate": 1500}', '{"top": [{"car": "kl5"}, {"tires": "drift", "voucher": 20000}, {"tires": "drift", "voucher": 10000}]}', 4320, 0, 3, 60, 96, null),
  ('fuga_vale', 'escape', 'Fuga por el vale',
   'Aguantá 8 minutos una persecución y escapá: $50.000 de vale de taller (mejoras, gomas, piezas, diseños y reglajes).', 1,
   '{"chase_s": 480}', '{"voucher": 50000}', 1440, 3, 0, 60, 72, null)
on conflict (id) do nothing;

-- ───────────── autoprueba al aplicar (si algo falla, se deshace todo) ─────────────
do $do$
declare j jsonb; n int;
begin
  if to_regprocedure('public._acct_one_base(uuid, jsonb)') is null then raise exception 'autoprueba: falta _acct_one_base'; end if;
  select count(*) into n from public.wev_templates where kind in ('season', 'drift');
  if n < 2 then raise exception 'autoprueba: faltan las plantillas nuevas'; end if;
  perform * from public._wev_rank(-1, 'season');
  perform * from public._wev_rank(-1, 'drift');
  j := public.event_board(-1, 5);
  if j is null or jsonb_typeof(j) <> 'array' then raise exception 'autoprueba: event_board'; end if;
  perform public._wev_close();
  perform public._wev_ensure();
  select public._wev_json(e, null) into j from public.wev_events e order by id desc limit 1;
  if j is not null and not (j ? 'pts') then raise exception 'autoprueba: _wev_json'; end if;
  raise notice 'temporada y drift listos';
end;
$do$;
