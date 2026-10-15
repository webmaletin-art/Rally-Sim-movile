-- Dream Racing · 15/10/2026 (pedidos del dueño):
--  1) INTERRUPTOR del juego en tiempo real: tabla app_flags (pvp = false). Mientras esté en false el juego NO entra al mundo online compartido (no se
--     encuentran jugadores, sin chat ni «quién está conectado»): sólo cuenta, plata, autos, eventos y ranking. Para habilitarlo: poner pvp en true
--     (Table Editor → app_flags) — no hace falta un APK nuevo. Ver docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md.
--  2) CAZA RECOMPENSAS como evento GLOBAL con UN SOLO GANADOR: el servidor programa cada tanto un auto suelto (el mismo para todos, a la misma hora);
--     cada jugador lo persigue en su propio mundo y el PRIMERO que completa los segundos pegado (hold_s) se lo lleva. Reemplaza el «1 auto por día»
--     de 20261018000000_bounty_car.sql (ese camino queda cerrado: give_car «bounty» se rechaza).
--  3) RANKING del mundo abierto: récords de las carreras para descubrir (board «owev», menos es mejor) y mejor racha del modo Fugitivo (board «fugitive»,
--     más es mejor), sobre las tablas de siempre (scores / get_leaderboard).
-- Aditivo y repetible.

-- ───────────── 1) interruptor ─────────────
create table if not exists public.app_flags (key text primary key, val boolean not null default false, note text not null default '');
insert into public.app_flags (key, val, note) values
  ('pvp', false, 'Mundo online en tiempo real: los jugadores se encuentran (Realtime, chat, conectados). true = habilitado.')
on conflict (key) do nothing;
alter table public.app_flags enable row level security;
revoke all on public.app_flags from anon, authenticated;

create or replace function public.app_flags() returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, val), '{}'::jsonb) from public.app_flags
$$;
revoke all on function public.app_flags() from public;
grant execute on function public.app_flags() to anon, authenticated;

-- ───────────── 2) caza recompensas ─────────────
create table if not exists public.bounty_cfg (key text primary key, val text not null);
insert into public.bounty_cfg (key, val) values
  ('auto', 'true'),               -- el servidor programa solo el próximo evento cuando no hay uno pendiente
  ('every_h', '6'),               -- cada cuántas horas (más una demora al azar de hasta jitter_min minutos)
  ('jitter_min', '90'),
  ('hold_s', '60'),               -- segundos pegado (en total) para ganarlo
  ('map_s', '45'),                -- segundos que se ve dónde está en el mapa al empezar
  ('duration_min', '15'),         -- cuánto dura suelto si nadie lo gana
  ('notice_min', '10'),           -- cuántos minutos antes se avisa
  ('cars', 'veltor_s,moust,veltor_gtr,strix,veltor,trilux_gt,kl5,pro_gt'),
  ('win_cooldown_d', '7')         -- el mismo jugador no gana dos recompensas en tantos días
on conflict (key) do nothing;

create table if not exists public.bounty_events (
  id bigserial primary key,
  car text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  hold_s int not null check (hold_s between 10 and 600),
  map_s int not null default 45,
  seed int not null default 0,
  winner uuid references auth.users (id) on delete set null,
  winner_name text,
  won_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists bounty_events_time on public.bounty_events (starts_at desc);
create table if not exists public.bounty_joins (event_id bigint not null references public.bounty_events (id) on delete cascade, user_id uuid not null references auth.users (id) on delete cascade, joined_at timestamptz not null default now(), primary key (event_id, user_id));
create table if not exists public.bounty_claims (id bigserial primary key, event_id bigint not null, user_id uuid references auth.users (id) on delete set null, at timestamptz not null default now(), ok boolean not null, reason text not null default '', trace jsonb);
alter table public.bounty_cfg enable row level security;
alter table public.bounty_events enable row level security;
alter table public.bounty_joins enable row level security;
alter table public.bounty_claims enable row level security;
revoke all on public.bounty_cfg, public.bounty_events, public.bounty_joins, public.bounty_claims from anon, authenticated;

create or replace function public._bounty_cfg(p_key text) returns text language sql stable security definer set search_path = public as $$
  select val from public.bounty_cfg where key = p_key
$$;
revoke all on function public._bounty_cfg(text) from public, anon, authenticated;

-- programa el próximo si no hay ninguno por venir (uno a la vez; la traba evita que dos pedidos creen dos)
create or replace function public._bounty_ensure() returns void language plpgsql security definer set search_path = public as $$
declare cars text[]; n int; st timestamptz;
begin
  if coalesce(public._bounty_cfg('auto'), 'true') <> 'true' then return; end if;
  perform pg_advisory_xact_lock(424242);
  if exists (select 1 from public.bounty_events where ends_at > now() and winner is null) then return; end if;
  cars := string_to_array(replace(coalesce(public._bounty_cfg('cars'), 'veltor'), ' ', ''), ',');
  n := coalesce(array_length(cars, 1), 0);
  if n = 0 then return; end if;
  st := now() + make_interval(mins => coalesce(public._bounty_cfg('notice_min'), '10')::int)
        + make_interval(hours => greatest(0, coalesce(public._bounty_cfg('every_h'), '6')::int - 1))
        + make_interval(mins => floor(random() * (coalesce(public._bounty_cfg('jitter_min'), '90')::int + 1))::int);
  insert into public.bounty_events (car, starts_at, ends_at, hold_s, map_s, seed)
  values (cars[1 + floor(random() * n)::int], st, st + make_interval(mins => coalesce(public._bounty_cfg('duration_min'), '15')::int),
          coalesce(public._bounty_cfg('hold_s'), '60')::int, coalesce(public._bounty_cfg('map_s'), '45')::int, floor(random() * 1000000)::int);
end;
$$;
revoke all on function public._bounty_ensure() from public, anon, authenticated;

create or replace function public._bounty_json(e public.bounty_events) returns jsonb language sql stable as $$
  select jsonb_build_object('id', e.id, 'car', e.car, 'starts', extract(epoch from e.starts_at)::bigint, 'ends', extract(epoch from e.ends_at)::bigint,
    'hold_s', e.hold_s, 'map_s', e.map_s, 'seed', e.seed, 'won', e.winner is not null, 'winner', coalesce(e.winner_name, ''),
    'mine', e.winner is not null and e.winner = auth.uid(), 'now', extract(epoch from now())::bigint,
    'notice_s', coalesce(public._bounty_cfg('notice_min'), '10')::int * 60)
$$;

-- el evento actual o el próximo (y el último ganado de la última hora, para mostrar quién se lo llevó)
create or replace function public.bounty_current() returns jsonb language plpgsql security definer set search_path = public as $$
declare e public.bounty_events; last public.bounty_events;
begin
  perform public._bounty_ensure();
  select * into e from public.bounty_events where ends_at > now() and winner is null order by starts_at limit 1;
  select * into last from public.bounty_events where winner is not null and won_at > now() - interval '1 hour' order by won_at desc limit 1;
  return jsonb_build_object('next', case when e.id is null then null else public._bounty_json(e) end,
                            'last', case when last.id is null then null else public._bounty_json(last) end);
end;
$$;
revoke all on function public.bounty_current() from public, anon;
grant execute on function public.bounty_current() to authenticated;

-- «salí a buscarlo»: queda anotada la hora (para ganarlo hay que haber estado al menos hold_s segundos en la caza)
create or replace function public.bounty_join(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); e public.bounty_events; j timestamptz;
begin
  select * into e from public.bounty_events where id = p_id;
  if not found then raise exception 'esa recompensa no existe' using errcode = '22023'; end if;
  if now() < e.starts_at - interval '30 seconds' or now() > e.ends_at then return jsonb_build_object('ok', false, 'reason', 'la recompensa no está suelta'); end if;
  if e.winner is not null then return jsonb_build_object('ok', false, 'reason', 'ya la ganó ' || coalesce(e.winner_name, 'otro piloto'), 'winner', coalesce(e.winner_name, '')); end if;
  insert into public.bounty_joins (event_id, user_id) values (p_id, uid) on conflict do nothing;
  select joined_at into j from public.bounty_joins where event_id = p_id and user_id = uid;
  return jsonb_build_object('ok', true, 'joined', extract(epoch from j)::bigint);
end;
$$;
revoke all on function public.bounty_join(bigint) from public, anon;
grant execute on function public.bounty_join(bigint) to authenticated;

-- «completé la barra»: el PRIMERO que llega se lo lleva (fila trabada: dos pedidos a la vez no ganan los dos). Se guarda el recorrido que manda el juego
-- (posiciones del jugador y del auto cada segundo, hasta 400 puntos) para poder revisar un ganador sospechoso.
create or replace function public.bounty_claim(p_id bigint, p_trace jsonb default null, p_name text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); e public.bounty_events; j timestamptz; nm text; r public.account_econ; price bigint; dup boolean := false; why text := '';
begin
  if p_trace is not null and (jsonb_typeof(p_trace) <> 'array' or jsonb_array_length(p_trace) > 400) then raise exception 'recorrido inválido' using errcode = '22023'; end if;
  select * into e from public.bounty_events where id = p_id for update;
  if not found then raise exception 'esa recompensa no existe' using errcode = '22023'; end if;
  select joined_at into j from public.bounty_joins where event_id = p_id and user_id = uid;
  if e.winner is not null then why := 'ya la ganó ' || coalesce(e.winner_name, 'otro piloto');
  elsif now() > e.ends_at + interval '1 minute' then why := 'la recompensa ya se fue';
  elsif j is null then why := 'no saliste a buscarla';
  elsif now() < greatest(j, e.starts_at) + make_interval(secs => e.hold_s + 5) then why := 'todavía no pudiste completar la barra';
  elsif exists (select 1 from public.bounty_events b where b.winner = uid and b.won_at > now() - make_interval(days => coalesce(public._bounty_cfg('win_cooldown_d'), '7')::int)) then
    why := 'ya ganaste una recompensa hace poco: dejá que la gane otro';
  end if;
  if why <> '' then
    insert into public.bounty_claims (event_id, user_id, ok, reason, trace) values (p_id, uid, false, why, p_trace);
    return jsonb_build_object('ok', false, 'reason', why, 'winner', coalesce(e.winner_name, ''));
  end if;
  nm := coalesce((select name from public.players where id = uid), nullif(left(trim(coalesce(p_name, '')), 20), ''), 'Piloto');
  update public.bounty_events set winner = uid, winner_name = nm, won_at = now() where id = p_id;
  insert into public.bounty_claims (event_id, user_id, ok, reason, trace) values (p_id, uid, true, '', p_trace);
  -- el premio: el auto va a la cuenta (si ya lo tenía, la mitad de su precio en créditos)
  r := public._acct_row(uid);
  if r.cars ? e.car then
    dup := true;
    select coalesce(c.price, 0) into price from public.online_cat_vehicles c where c.id = e.car;
    update public.account_econ set credits = credits + coalesce(price, 0) / 2 where user_id = uid;
  else
    update public.account_econ set cars = cars || jsonb_build_object(e.car, jsonb_build_object('bought', extract(epoch from now())::bigint, 'owned', '[]'::jsonb, 'tires', '["street"]'::jsonb, 'parts', '[]'::jsonb)) where user_id = uid;
  end if;
  return jsonb_build_object('ok', true, 'car', e.car, 'dup', dup, 'credits', case when dup then coalesce(price, 0) / 2 else 0 end);
end;
$$;
revoke all on function public.bounty_claim(bigint, jsonb, text) from public, anon;
grant execute on function public.bounty_claim(bigint, jsonb, text) to authenticated;

-- los últimos ganadores (para la pantalla de ranking)
create or replace function public.bounty_winners(p_limit int default 10) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', winner_name, 'car', car, 'at', extract(epoch from won_at)::bigint) order by won_at desc), '[]'::jsonb)
  from (select * from public.bounty_events where winner is not null order by won_at desc limit greatest(1, least(coalesce(p_limit, 10), 50))) w
$$;
revoke all on function public.bounty_winners(int) from public;
grant execute on function public.bounty_winners(int) to anon, authenticated;

-- programar uno a mano (desde el SQL Editor del panel; el juego no puede): select public.bounty_admin_schedule('veltor_gtr', now() + interval '10 minutes', 60);
create or replace function public.bounty_admin_schedule(p_car text, p_at timestamptz, p_hold_s int default 60, p_minutes int default 15) returns jsonb language plpgsql security definer set search_path = public as $$
declare nid bigint;
begin
  if not exists (select 1 from public.online_cat_vehicles where id = p_car) then raise exception 'ese auto no existe' using errcode = '22023'; end if;
  insert into public.bounty_events (car, starts_at, ends_at, hold_s, map_s, seed)
  values (p_car, p_at, p_at + make_interval(mins => greatest(3, p_minutes)), greatest(10, least(p_hold_s, 600)), coalesce(public._bounty_cfg('map_s'), '45')::int, floor(random() * 1000000)::int)
  returning id into nid;
  return jsonb_build_object('ok', true, 'id', nid);
end;
$$;
revoke all on function public.bounty_admin_schedule(text, timestamptz, int, int) from public, anon, authenticated;

-- ───────────── el camino viejo (1 auto por día con give_car «bounty») queda cerrado ─────────────
-- (se reemplaza sólo la regla dentro de _acct_one: el auto de la recompensa lo da bounty_claim)
do $do$
declare src text;
begin
  src := pg_get_functiondef('public._acct_one(uuid, jsonb)'::regprocedure);
  if position('''bounty''' in src) > 0 and position('se cobra en el evento' in src) = 0 then
    src := replace(src, 'elsif v_kind = ''bounty'' then', 'elsif v_kind = ''bounty'' then
      raise exception ''la recompensa se cobra en el evento (bounty_claim)'' using errcode = ''42501'';');
    execute src;
  end if;
end;
$do$;

-- ───────────── 3) ranking del mundo abierto ─────────────
alter table public.scores drop constraint if exists scores_board_check;
alter table public.scores add constraint scores_board_check check (board in ('race', 'timetrial', 'drag', 'drift', 'owev', 'fugitive'));

-- récord de una carrera del mundo abierto (p_id = id del evento, tiempo en s) o de la racha del modo Fugitivo (p_id = 'fugitivo', escapes seguidos)
create or replace function public.submit_record(p_board text, p_id text, p_value numeric, p_car text default '', p_name text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tid text; higher boolean := p_board = 'fugitive'; prev numeric; best numeric; rnk bigint; saved boolean := false;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if p_board not in ('owev', 'fugitive') then raise exception 'tabla inválida' using errcode = '22023'; end if;
  if p_id !~ '^[A-Za-z0-9_.:-]{1,40}$' then raise exception 'evento inválido' using errcode = '22023'; end if;
  if p_board = 'owev' and (p_value < 8 or p_value > 3600) then raise exception 'tiempo imposible' using errcode = '22023'; end if;
  if p_board = 'fugitive' and (p_value < 1 or p_value > 500 or p_value <> floor(p_value)) then raise exception 'racha imposible' using errcode = '22023'; end if;
  if (select count(*) from public.score_log where player_id = uid and created_at > now() - interval '1 hour') >= 40 then
    raise exception 'demasiados envíos' using errcode = '53400';
  end if;
  insert into public.score_log (player_id) values (uid);
  tid := case when p_board = 'fugitive' then 'fugitivo' else 'ow:' || p_id end;
  insert into public.tracks (id, name, length_m) values (tid, case when p_board = 'fugitive' then 'Modo Fugitivo' else 'Mundo abierto · ' || p_id end, 0) on conflict (id) do nothing;
  insert into public.players (id, name) values (uid, coalesce(nullif(left(trim(p_name), 20), ''), 'Piloto'))
    on conflict (id) do update set name = case when p_name is not null and char_length(trim(p_name)) >= 2 then left(trim(p_name), 20) else public.players.name end, last_seen = now();
  select value into prev from public.scores where player_id = uid and track = tid and board = p_board;
  if prev is null then
    insert into public.scores (player_id, track, board, value, car) values (uid, tid, p_board, p_value, left(coalesce(p_car, ''), 40));
    saved := true;
  elsif (higher and p_value > prev) or (not higher and p_value < prev) then
    update public.scores set value = p_value, car = left(coalesce(p_car, ''), 40), updated_at = now() where player_id = uid and track = tid and board = p_board;
    saved := true;
  end if;
  select value into best from public.scores where player_id = uid and track = tid and board = p_board;
  select count(*) + 1 into rnk from public.scores s where s.track = tid and s.board = p_board and ((higher and s.value > best) or (not higher and s.value < best));
  return jsonb_build_object('saved', saved, 'best', best, 'rank', rnk, 'top', (select jsonb_build_object('name', p.name, 'value', s.value) from public.scores s join public.players p on p.id = s.player_id
    where s.track = tid and s.board = p_board order by case when higher then -s.value else s.value end, s.updated_at limit 1));
end;
$$;
revoke all on function public.submit_record(text, text, numeric, text, text) from public, anon;
grant execute on function public.submit_record(text, text, numeric, text, text) to authenticated;

-- el ranking: drift y la racha del Fugitivo, de mayor a menor; los tiempos, de menor a mayor
create or replace function public.get_leaderboard(p_track text, p_board text, p_limit int default 50)
returns table (rank bigint, name text, value numeric, car text, is_me boolean)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by case when p_board in ('drift', 'fugitive') then -s.value else s.value end, s.updated_at) as rank,
         p.name, s.value, s.car, (s.player_id = auth.uid()) as is_me
  from public.scores s
  join public.players p on p.id = s.player_id
  where s.track = p_track and s.board = p_board
  order by 1
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;
revoke all on function public.get_leaderboard(text, text, int) from public;
grant execute on function public.get_leaderboard(text, text, int) to anon, authenticated;
