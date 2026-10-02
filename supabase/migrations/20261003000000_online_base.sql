-- Dream Racing · base del modo online: jugadores anónimos, pistas y rankings.
-- Todo con seguridad por filas (RLS): el juego solo usa la clave pública (anon) y un usuario anónimo; nadie puede escribir directo
-- en las tablas, solo a través de las funciones de abajo, que validan lo que mandan.

-- ───────────── jugadores ─────────────
create table if not exists public.players (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text not null default 'Piloto' check (char_length(name) between 2 and 20),
  created_at  timestamptz not null default now(),
  last_seen   timestamptz not null default now()
);

-- ───────────── pistas (con su largo, para validar tiempos imposibles) ─────────────
create table if not exists public.tracks (
  id        text primary key,
  name      text not null,
  length_m  numeric not null check (length_m >= 0)
);

insert into public.tracks (id, name, length_m) values
  ('lake',        'Circuito del Lago',            2603),
  ('forest',      'Bosque de Tierra',             4461),
  ('forestRev',   'Bosque (inverso)',             4461),
  ('asphaltLong', 'Montaña Asfalto',              3395),
  ('asphaltRev',  'Montaña (inversa)',            3395),
  ('descent',     'Bajada de los Badenes',        5130),
  ('quarry',      'Cantera Roja',                 1857),
  ('quarryRev',   'Cantera (inversa)',            1857),
  ('paperRace',   'Paper Race (selva de papel)',  1900),
  ('dream',       'Vórtice de Ensueño',           9685),
  ('picada',      'Picada (400 m)',                402),
  ('drift',       'Drift Plaza',                     0)
on conflict (id) do update set name = excluded.name, length_m = excluded.length_m;

-- ───────────── mejores marcas: una por jugador, pista y tipo de tabla ─────────────
-- board: race / timetrial / drag → tiempo en segundos (menos es mejor) · drift → puntos (más es mejor)
create table if not exists public.scores (
  player_id   uuid not null references public.players (id) on delete cascade,
  track       text not null references public.tracks (id),
  board       text not null check (board in ('race', 'timetrial', 'drag', 'drift')),
  value       numeric not null check (value > 0),
  car         text not null default '' check (char_length(car) <= 40),
  laps        int  not null default 1 check (laps between 1 and 10),
  build       text not null default '' check (char_length(build) <= 40),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (player_id, track, board)
);
create index if not exists scores_rank_idx on public.scores (track, board, value);

-- registro de envíos, solo para limitar el abuso (no se lee desde el juego)
create table if not exists public.score_log (
  id         bigint generated always as identity primary key,
  player_id  uuid not null,
  created_at timestamptz not null default now()
);
create index if not exists score_log_player_idx on public.score_log (player_id, created_at desc);

-- ───────────── seguridad por filas ─────────────
alter table public.players   enable row level security;
alter table public.tracks    enable row level security;
alter table public.scores    enable row level security;
alter table public.score_log enable row level security;

-- lectura pública de nombres, pistas y marcas (es un ranking); nadie escribe directo
drop policy if exists players_read on public.players;
create policy players_read on public.players for select to anon, authenticated using (true);
drop policy if exists tracks_read on public.tracks;
create policy tracks_read on public.tracks for select to anon, authenticated using (true);
drop policy if exists scores_read on public.scores;
create policy scores_read on public.scores for select to anon, authenticated using (true);
-- score_log: sin políticas = nadie lo ve ni lo escribe desde el juego

revoke all on public.players, public.tracks, public.scores, public.score_log from anon, authenticated;
grant select on public.players, public.tracks, public.scores to anon, authenticated;

-- ───────────── enviar una marca ─────────────
-- Valida: usuario con sesión, pista existente, valor plausible (nadie recorre una pista más rápido que 120 m/s ≈ 430 km/h) y un
-- máximo de 40 envíos por hora. Guarda solo si mejora la marca anterior. Devuelve {saved, best, rank}.
create or replace function public.submit_score(
  p_track text, p_board text, p_value numeric,
  p_car text default '', p_laps int default 1, p_build text default '', p_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid     uuid := auth.uid();
  tr      public.tracks%rowtype;
  lower_is_better boolean := p_board <> 'drift';
  minval  numeric;
  prev    numeric;
  saved   boolean := false;
  best    numeric;
  rnk     bigint;
begin
  if uid is null then
    raise exception 'sin sesión' using errcode = '28000';
  end if;
  if p_board not in ('race', 'timetrial', 'drag', 'drift') then
    raise exception 'tabla inválida' using errcode = '22023';
  end if;
  select * into tr from public.tracks where id = p_track;
  if not found then
    raise exception 'pista inexistente' using errcode = '22023';
  end if;
  p_laps := greatest(1, least(coalesce(p_laps, 1), 10));

  -- valor plausible
  if p_board = 'drift' then
    if p_value <= 0 or p_value > 5000000 then raise exception 'puntaje imposible' using errcode = '22023'; end if;
  elsif p_board = 'drag' then
    if p_value < 3.5 or p_value > 120 then raise exception 'tiempo imposible' using errcode = '22023'; end if;
  else
    minval := (tr.length_m * p_laps) / 120.0;
    if p_value < minval or p_value > 7200 then raise exception 'tiempo imposible' using errcode = '22023'; end if;
  end if;

  -- límite de envíos
  if (select count(*) from public.score_log where player_id = uid and created_at > now() - interval '1 hour') >= 40 then
    raise exception 'demasiados envíos' using errcode = '53400';
  end if;
  insert into public.score_log (player_id) values (uid);

  -- el jugador se crea (o actualiza el nombre) al enviar
  insert into public.players (id, name)
    values (uid, coalesce(nullif(left(trim(p_name), 20), ''), 'Piloto'))
    on conflict (id) do update
      set name = case when p_name is not null and char_length(trim(p_name)) >= 2 then left(trim(p_name), 20) else public.players.name end,
          last_seen = now();

  select value into prev from public.scores where player_id = uid and track = p_track and board = p_board;
  if prev is null then
    insert into public.scores (player_id, track, board, value, car, laps, build)
      values (uid, p_track, p_board, p_value, left(coalesce(p_car, ''), 40), p_laps, left(coalesce(p_build, ''), 40));
    saved := true;
  elsif (lower_is_better and p_value < prev) or (not lower_is_better and p_value > prev) then
    update public.scores
      set value = p_value, car = left(coalesce(p_car, ''), 40), laps = p_laps, build = left(coalesce(p_build, ''), 40), updated_at = now()
      where player_id = uid and track = p_track and board = p_board;
    saved := true;
  end if;

  select value into best from public.scores where player_id = uid and track = p_track and board = p_board;
  select count(*) + 1 into rnk from public.scores s
    where s.track = p_track and s.board = p_board
      and ((lower_is_better and s.value < best) or (not lower_is_better and s.value > best));
  return jsonb_build_object('saved', saved, 'best', best, 'rank', rnk);
end;
$$;

-- ───────────── ver el ranking ─────────────
create or replace function public.get_leaderboard(p_track text, p_board text, p_limit int default 50)
returns table (rank bigint, name text, value numeric, car text, is_me boolean)
language sql
stable
security definer
set search_path = public
as $$
  select row_number() over (order by case when p_board = 'drift' then -s.value else s.value end, s.updated_at) as rank,
         p.name, s.value, s.car, (s.player_id = auth.uid()) as is_me
  from public.scores s
  join public.players p on p.id = s.player_id
  where s.track = p_track and s.board = p_board
  order by 1
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

revoke all on function public.submit_score(text, text, numeric, text, int, text, text) from public, anon;
grant execute on function public.submit_score(text, text, numeric, text, int, text, text) to authenticated;
revoke all on function public.get_leaderboard(text, text, int) from public;
grant execute on function public.get_leaderboard(text, text, int) to anon, authenticated;

-- ───────────── cambiar el nombre ─────────────
create or replace function public.set_player_name(p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if char_length(trim(coalesce(p_name, ''))) < 2 then raise exception 'nombre muy corto' using errcode = '22023'; end if;
  insert into public.players (id, name) values (auth.uid(), left(trim(p_name), 20))
    on conflict (id) do update set name = left(trim(p_name), 20), last_seen = now();
end;
$$;
revoke all on function public.set_player_name(text) from public, anon;
grant execute on function public.set_player_name(text) to authenticated;
