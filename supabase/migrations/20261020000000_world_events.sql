-- Dream Racing · 15/10/2026 (pedido del dueño): el online, mientras no haya tiempo real (hasta pagar Supabase Pro), pasa a ser de EVENTOS DE CLASIFICACIÓN.
-- Cada uno juega en su celular, en su mapa, contra la IA; el SERVIDOR es el gestor de eventos y premios (y la base para que no haya trampa):
--   · programa eventos del mundo al azar, repetidos y no muy seguidos (plantillas wev_templates), algunos a hora fija (la cacería de las 22);
--   · cuenta los intentos, valida los tiempos y da los premios (créditos justos, autos de la cacería, autos ALQUILADOS por unos días);
--   · publica los ganadores.
-- Tipos de evento:
--   bounty  Cazarrecompensas: N autos sueltos a la vez (el mismo lugar y la misma hora para todos); el primero que se pega hold_s segundos a uno se lo lleva.
--   escape  Fuga: mantener una persecución de la policía chase_s segundos (y escapar) → premio (p. ej. el auto de policía por 3 días).
--   reach   Contrarreloj: llegar a una ciudad de la región antes del tiempo, con intentos limitados por día → créditos.
--   record  Carrera de la semana: el mejor tiempo de una carrera del mundo abierto; al cerrar, premios a los 3 primeros.
-- Reemplaza la recompensa suelta de 20261019000000 (su programación automática queda apagada; las tablas quedan por si se quiere mirar el historial).
-- Aditivo y repetible.

-- ───────────── configuración ─────────────
create table if not exists public.wev_cfg (key text primary key, val text not null);
insert into public.wev_cfg (key, val) values
  ('auto', 'true'),       -- el servidor programa solo los eventos
  ('max_open', '4'),      -- cuántos eventos a la vez (en curso + por empezar)
  ('bounty_cooldown_d', '7') -- el mismo jugador no gana dos autos de cacería en tantos días
on conflict (key) do nothing;
update public.bounty_cfg set val = 'false' where key = 'auto'; -- la recompensa vieja ya no se programa sola

create table if not exists public.wev_templates (
  id text primary key,
  kind text not null check (kind in ('bounty', 'escape', 'reach', 'record')),
  title text not null,
  descr text not null default '',
  weight int not null default 1,
  params jsonb not null default '{}'::jsonb,
  reward jsonb not null default '{}'::jsonb,
  duration_min int not null default 60,
  attempts int not null default 0,          -- intentos por jugador (0 = sin límite)
  max_winners int not null default 0,       -- ganadores con premio (0 = todos los que cumplan; en la cacería, uno por auto)
  notice_min int not null default 30,       -- se anuncia tanto antes
  cooldown_h int not null default 12,       -- no se repite antes de tantas horas
  hours_utc int[],                          -- horas fijas (UTC) en que empieza; null = a cualquier hora
  enabled boolean not null default true
);
-- plantillas de fábrica (premios justos). Se cambian desde el panel (Table Editor → wev_templates). Hora de Argentina = UTC − 3.
insert into public.wev_templates (id, kind, title, descr, weight, params, reward, duration_min, attempts, max_winners, notice_min, cooldown_h, hours_utc) values
  ('caza_22', 'bounty', 'Cazarrecompensas de las 22', 'Tres autos sueltos en Dream City. Durante 45 s se ve en el mapa dónde están: el primero que se pegue 60 s a uno se lo lleva.', 3,
   '{"n": 3, "pool": ["veltor_gtr", "moust", "strix", "veltor_s", "veltor", "trilux_gt", "kl5", "pro_gt"], "hold_s": 60, "map_s": 45}', '{"car": true}', 20, 0, 0, 120, 20, array[1]),
  ('caza_tarde', 'bounty', 'Cazarrecompensas de la tarde', 'Un auto suelto en Dream City: el primero que se le pegue 60 s se lo lleva.', 2,
   '{"n": 1, "pool": ["trilux_gt", "kl5", "pro_gt", "veltor", "gt", "trilux_s", "muscle", "rally80"], "hold_s": 60, "map_s": 45}', '{"car": true}', 15, 0, 0, 60, 20, array[19]),
  ('fuga_10', 'escape', 'Fuga de 10 minutos', 'Aguantá una persecución de la policía 10 minutos sin que te agarren y escapá: el DRP Interceptor es tuyo por 3 días.', 2,
   '{"chase_s": 600}', '{"rent": "police", "days": 3}', 1440, 5, 0, 60, 48, null),
  ('fuga_5', 'escape', 'Fuga de 5 minutos', 'Aguantá una persecución de la policía 5 minutos y escapá.', 3,
   '{"chase_s": 300}', '{"credits": 12000}', 360, 5, 0, 30, 12, null),
  ('llegada', 'reach', 'Contrarreloj entre ciudades', 'Salí de Dream City y llegá a la ciudad marcada antes del tiempo. Tres intentos.', 3,
   '{"speed": 24, "time_max": 1800}', '{"credits": 20000}', 1440, 3, 0, 30, 24, null),
  ('carrera_semana', 'record', 'Carrera de la semana', 'El mejor tiempo de la semana en la carrera marcada del mundo abierto. Premios para los 3 primeros.', 1,
   '{}', '{"top": [25000, 12000, 6000]}', 10080, 0, 3, 60, 160, null)
on conflict (id) do nothing;

create table if not exists public.wev_events (
  id bigserial primary key,
  tpl text,
  kind text not null,
  title text not null,
  descr text not null default '',
  params jsonb not null default '{}'::jsonb,
  reward jsonb not null default '{}'::jsonb,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  attempts int not null default 0,
  max_winners int not null default 0,
  seed int not null default 0,
  closed boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists wev_events_time on public.wev_events (ends_at desc);
create table if not exists public.wev_runs (
  id bigserial primary key,
  event_id bigint not null references public.wev_events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  slot int not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  ok boolean,
  value numeric,
  trace jsonb
);
create index if not exists wev_runs_ev on public.wev_runs (event_id, user_id);
create table if not exists public.wev_winners (
  id bigserial primary key,
  event_id bigint not null references public.wev_events (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  name text not null default 'Piloto',
  slot int not null default 0,
  value numeric,
  reward jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index if not exists wev_winners_ev on public.wev_winners (event_id);
create index if not exists wev_winners_at on public.wev_winners (at desc);
alter table public.wev_cfg enable row level security;
alter table public.wev_templates enable row level security;
alter table public.wev_events enable row level security;
alter table public.wev_runs enable row level security;
alter table public.wev_winners enable row level security;
revoke all on public.wev_cfg, public.wev_templates, public.wev_events, public.wev_runs, public.wev_winners from anon, authenticated;

create or replace function public._wev_conf(p_key text) returns text language sql stable security definer set search_path = public as $$
  select val from public.wev_cfg where key = p_key
$$;
revoke all on function public._wev_conf(text) from public, anon, authenticated;

-- ───────────── autos alquilados: un auto de la cuenta con «until» (segundos unix) se borra solo al vencer ─────────────
create or replace function public._acct_row(p_uid uuid) returns public.account_econ language plpgsql security definer set search_path = public as $$
declare r public.account_econ; nowe bigint := extract(epoch from now())::bigint;
begin
  insert into public.account_econ (user_id, credits) values (p_uid, public._acct_cfg('start_credits')) on conflict do nothing;
  select * into r from public.account_econ where user_id = p_uid for update;
  if exists (select 1 from jsonb_each(r.cars) e(k, v) where v ? 'until' and (v ->> 'until')::bigint <= nowe) then
    update public.account_econ set cars = (select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) from jsonb_each(r.cars) e(k, v) where not (v ? 'until') or (v ->> 'until')::bigint > nowe)
      where user_id = p_uid returning * into r;
  end if;
  return r;
end;
$$;
revoke all on function public._acct_row(uuid) from public, anon, authenticated;

-- da un premio: {credits: n} · {car: id} (para siempre; si ya lo tiene, la mitad del precio) · {rent: id, days: n} (alquilado; si ya lo tiene para siempre, nada)
create or replace function public._wev_grant(p_uid uuid, p_reward jsonb, p_car text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.account_econ; car text; price bigint; until bigint; cur jsonb; out jsonb := '{}'::jsonb;
begin
  r := public._acct_row(p_uid);
  if p_reward ? 'credits' then
    update public.account_econ set credits = credits + greatest(0, least((p_reward ->> 'credits')::bigint, 200000)) where user_id = p_uid;
    out := out || jsonb_build_object('credits', (p_reward ->> 'credits')::bigint);
  end if;
  if p_reward ? 'car' then
    car := coalesce(p_car, p_reward ->> 'car');
    cur := r.cars -> car;
    if cur is not null and not (cur ? 'until') then
      select coalesce(c.price, 0) into price from public.online_cat_vehicles c where c.id = car;
      update public.account_econ set credits = credits + coalesce(price, 0) / 2 where user_id = p_uid;
      out := out || jsonb_build_object('car', car, 'dup', true, 'credits', coalesce(price, 0) / 2);
    else
      update public.account_econ set cars = cars || jsonb_build_object(car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', coalesce(cur -> 'owned', '[]'::jsonb), 'tires', coalesce(cur -> 'tires', '["street"]'::jsonb), 'parts', coalesce(cur -> 'parts', '[]'::jsonb)))
        where user_id = p_uid;
      out := out || jsonb_build_object('car', car);
    end if;
  end if;
  if p_reward ? 'rent' then
    car := p_reward ->> 'rent';
    cur := r.cars -> car;
    if cur is null or (cur ? 'until') then
      until := greatest(coalesce((cur ->> 'until')::bigint, 0), extract(epoch from now())::bigint) + greatest(1, least(coalesce((p_reward ->> 'days')::int, 1), 30)) * 86400;
      update public.account_econ set cars = cars || jsonb_build_object(car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', coalesce(cur -> 'owned', '[]'::jsonb), 'tires', coalesce(cur -> 'tires', '["street"]'::jsonb), 'parts', coalesce(cur -> 'parts', '[]'::jsonb), 'until', until))
        where user_id = p_uid;
      out := out || jsonb_build_object('rent', car, 'until', until);
    else
      out := out || jsonb_build_object('rent', car, 'had', true);
    end if;
  end if;
  return out;
end;
$$;
revoke all on function public._wev_grant(uuid, jsonb, text) from public, anon, authenticated;

-- ───────────── programación ─────────────
create or replace function public._wev_make(t public.wev_templates, p_at timestamptz) returns bigint language plpgsql security definer set search_path = public as $$
declare prm jsonb := t.params; pool text[]; picked text[] := '{}'; n int; i int; nid bigint;
begin
  if t.kind = 'bounty' and prm ? 'pool' then
    select array_agg(x) into pool from (select jsonb_array_elements_text(prm -> 'pool') x order by random()) s;
    n := greatest(1, least(coalesce((prm ->> 'n')::int, 1), coalesce(array_length(pool, 1), 1), 5));
    for i in 1..n loop picked := picked || pool[i]; end loop;
    prm := prm || jsonb_build_object('cars', to_jsonb(picked));
  end if;
  insert into public.wev_events (tpl, kind, title, descr, params, reward, starts_at, ends_at, attempts, max_winners, seed)
  values (t.id, t.kind, t.title, t.descr, prm, t.reward, p_at, p_at + make_interval(mins => greatest(3, t.duration_min)), t.attempts, t.max_winners, floor(random() * 1000000)::int)
  returning id into nid;
  return nid;
end;
$$;
revoke all on function public._wev_make(public.wev_templates, timestamptz) from public, anon, authenticated;

-- mantiene programados unos pocos eventos (al azar según el peso, cada plantilla con su descanso; las de hora fija, a su hora)
create or replace function public._wev_ensure() returns void language plpgsql security definer set search_path = public as $$
declare t public.wev_templates; open_n int; maxo int; st timestamptz; h int; tries int := 0;
begin
  if coalesce(public._wev_conf('auto'), 'true') <> 'true' then return; end if;
  perform pg_advisory_xact_lock(424243);
  maxo := coalesce(public._wev_conf('max_open'), '4')::int;
  loop
    select count(*) into open_n from public.wev_events where ends_at > now();
    exit when open_n >= maxo or tries >= 8;
    tries := tries + 1;
    -- una plantilla habilitada, que no tenga uno abierto y que haya descansado, al azar según el peso
    select * into t from public.wev_templates w
      where w.enabled
        and not exists (select 1 from public.wev_events e where e.tpl = w.id and e.ends_at > now())
        and not exists (select 1 from public.wev_events e where e.tpl = w.id and e.starts_at > now() - make_interval(hours => w.cooldown_h))
      order by -ln(greatest(random(), 1e-9)) / greatest(w.weight, 1) limit 1;
    exit when t.id is null;
    if t.hours_utc is not null and array_length(t.hours_utc, 1) > 0 then
      st := null;
      for h in 0..47 loop
        if (extract(hour from (date_trunc('hour', now() at time zone 'utc') + make_interval(hours => h)))::int = any (t.hours_utc))
           and (date_trunc('hour', now() at time zone 'utc') + make_interval(hours => h)) at time zone 'utc' > now() + make_interval(mins => t.notice_min) then
          st := (date_trunc('hour', now() at time zone 'utc') + make_interval(hours => h)) at time zone 'utc';
          exit;
        end if;
      end loop;
      if st is null then continue; end if;
    else
      st := now() + make_interval(mins => t.notice_min + floor(random() * 180)::int);
    end if;
    perform public._wev_make(t, st);
  end loop;
end;
$$;
revoke all on function public._wev_ensure() from public, anon, authenticated;

-- cierra los eventos que terminaron: la carrera de la semana paga a sus 3 primeros
create or replace function public._wev_close() returns void language plpgsql security definer set search_path = public as $$
declare e public.wev_events; w record; pos int; tops jsonb;
begin
  for e in select * from public.wev_events where not closed and ends_at < now() for update skip locked loop
    if e.kind = 'record' then
      pos := 0;
      tops := coalesce(e.reward -> 'top', '[]'::jsonb);
      for w in select r.user_id, min(r.value) as best from public.wev_runs r where r.event_id = e.id and r.ok and r.value is not null group by r.user_id order by best limit greatest(e.max_winners, 1) loop
        if pos < jsonb_array_length(tops) then
          perform public._wev_grant(w.user_id, jsonb_build_object('credits', (tops ->> pos)::bigint));
          insert into public.wev_winners (event_id, user_id, name, slot, value, reward)
          values (e.id, w.user_id, coalesce((select name from public.players where id = w.user_id), 'Piloto'), pos, w.best, jsonb_build_object('credits', (tops ->> pos)::bigint));
        end if;
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
    'best', (select min(r.value) from public.wev_runs r where r.event_id = e.id and r.user_id = p_uid and r.ok),
    'winners', coalesce((select jsonb_agg(jsonb_build_object('name', w.name, 'slot', w.slot, 'value', w.value) order by w.at) from public.wev_winners w where w.event_id = e.id), '[]'::jsonb))
$$;
revoke all on function public._wev_json(public.wev_events, uuid) from public, anon, authenticated;

-- ───────────── lo que usa el juego ─────────────
-- los eventos abiertos (en curso y por empezar) y los últimos ganadores
create or replace function public.events_current() returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); evs jsonb; wins jsonb;
begin
  perform public._wev_close();
  perform public._wev_ensure();
  select coalesce(jsonb_agg(public._wev_json(e, uid) order by e.starts_at), '[]'::jsonb) into evs from public.wev_events e where e.ends_at > now() - interval '2 minutes';
  select coalesce(jsonb_agg(jsonb_build_object('event', ev.title, 'kind', ev.kind, 'name', w.name, 'slot', w.slot, 'value', w.value, 'reward', w.reward, 'car', ev.params -> 'cars' ->> w.slot, 'at', extract(epoch from w.at)::bigint) order by w.at desc), '[]'::jsonb)
    into wins from (select * from public.wev_winners order by at desc limit 12) w join public.wev_events ev on ev.id = w.event_id;
  return jsonb_build_object('now', extract(epoch from now())::bigint, 'events', evs, 'winners', wins);
end;
$$;
revoke all on function public.events_current() from public, anon;
grant execute on function public.events_current() to authenticated;

-- empieza un intento (gasta uno). En la cacería, p_slot = cuál de los autos.
create or replace function public.event_start(p_id bigint, p_slot int default 0) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); e public.wev_events; used int; rid bigint;
begin
  select * into e from public.wev_events where id = p_id;
  if not found then raise exception 'ese evento no existe' using errcode = '22023'; end if;
  if now() < e.starts_at - interval '20 seconds' or now() > e.ends_at then return jsonb_build_object('ok', false, 'reason', 'el evento no está en curso'); end if;
  if exists (select 1 from public.wev_winners w where w.event_id = p_id and w.user_id = uid) and e.kind <> 'record' then
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

-- termina un intento: p_ok = lo logró; p_value = segundos (llegada, carrera, aguante de la fuga) o barra (cacería). El servidor valida tiempos y cupos y da el premio.
create or replace function public.event_finish(p_run bigint, p_ok boolean, p_value numeric default null, p_trace jsonb default null, p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); run public.wev_runs; e public.wev_events; el numeric; why text := ''; nm text; got jsonb := '{}'::jsonb; nwin int; car text; prm jsonb;
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
  end if;
  if why <> '' then return jsonb_build_object('ok', true, 'won', false, 'reason', why); end if;
  update public.wev_runs set ok = true where id = p_run;
  nm := coalesce((select name from public.players where id = uid), nullif(left(trim(coalesce(p_name, '')), 20), ''), 'Piloto');
  if e.kind = 'record' then
    return jsonb_build_object('ok', true, 'won', false, 'saved', true, 'rank', (select count(*) + 1 from (select min(r.value) b from public.wev_runs r where r.event_id = e.id and r.ok group by r.user_id) s where s.b < p_value));
  end if;
  if exists (select 1 from public.wev_winners w where w.event_id = e.id and w.user_id = uid) then return jsonb_build_object('ok', true, 'won', false, 'reason', 'ya ganaste este evento'); end if;
  select count(*) into nwin from public.wev_winners where event_id = e.id;
  if e.kind <> 'bounty' and e.max_winners > 0 and nwin >= e.max_winners then return jsonb_build_object('ok', true, 'won', false, 'reason', 'ya se entregaron todos los premios'); end if;
  car := case when e.kind = 'bounty' then prm -> 'cars' ->> run.slot else null end;
  got := public._wev_grant(uid, e.reward, car);
  insert into public.wev_winners (event_id, user_id, name, slot, value, reward) values (e.id, uid, nm, run.slot, p_value, got);
  return jsonb_build_object('ok', true, 'won', true, 'reward', got);
end;
$$;
revoke all on function public.event_finish(bigint, boolean, numeric, jsonb, text) from public, anon;
grant execute on function public.event_finish(bigint, boolean, numeric, jsonb, text) to authenticated;

-- la tabla de una carrera de la semana (mejor tiempo de cada uno)
create or replace function public.event_board(p_id bigint, p_limit int default 10) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('rank', rk, 'name', nm, 'value', b, 'is_me', me) order by rk), '[]'::jsonb) from (
    select row_number() over (order by min(r.value)) rk, coalesce(p.name, 'Piloto') nm, min(r.value) b, bool_or(r.user_id = auth.uid()) me
    from public.wev_runs r left join public.players p on p.id = r.user_id
    where r.event_id = p_id and r.ok and r.value is not null group by r.user_id, p.name order by min(r.value) limit greatest(1, least(coalesce(p_limit, 10), 50))) s
$$;
revoke all on function public.event_board(bigint, int) from public;
grant execute on function public.event_board(bigint, int) to anon, authenticated;

-- los últimos ganadores de los eventos (ranking del menú)
create or replace function public.event_winners(p_limit int default 15) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('event', ev.title, 'kind', ev.kind, 'name', w.name, 'value', w.value, 'reward', w.reward, 'car', ev.params -> 'cars' ->> w.slot, 'at', extract(epoch from w.at)::bigint) order by w.at desc), '[]'::jsonb)
  from (select * from public.wev_winners order by at desc limit greatest(1, least(coalesce(p_limit, 15), 50))) w join public.wev_events ev on ev.id = w.event_id
$$;
revoke all on function public.event_winners(int) from public;
grant execute on function public.event_winners(int) to anon, authenticated;

-- programar uno a mano desde el panel (SQL Editor): select public.event_admin_schedule('caza_22', now() + interval '15 minutes');
create or replace function public.event_admin_schedule(p_tpl text, p_at timestamptz) returns jsonb language plpgsql security definer set search_path = public as $$
declare t public.wev_templates;
begin
  select * into t from public.wev_templates where id = p_tpl;
  if not found then raise exception 'esa plantilla no existe' using errcode = '22023'; end if;
  return jsonb_build_object('ok', true, 'id', public._wev_make(t, p_at));
end;
$$;
revoke all on function public.event_admin_schedule(text, timestamptz) from public, anon, authenticated;

-- ───────────── autoprueba al aplicar (si algo falla acá, la migración entera se deshace y el flujo muestra el error) ─────────────
do $do$
declare n int; j jsonb;
begin
  perform public._wev_close();
  perform public._wev_ensure();
  select count(*) into n from public.wev_events where ends_at > now();
  if n = 0 then raise exception 'autoprueba: no se programó ningún evento'; end if;
  select public._wev_json(e, null) into j from public.wev_events e order by id desc limit 1;
  if j is null or not (j ? 'kind') then raise exception 'autoprueba: _wev_json'; end if;
  raise notice 'eventos programados: %', n;
end;
$do$;
