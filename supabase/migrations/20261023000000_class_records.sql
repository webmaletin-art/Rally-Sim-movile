-- Récords por CLASE (auditoría del ciclo de juego, fase 3 «competencia justa», 16/10/2026). ADITIVA: no borra ni cambia nada de lo que ya existe.
-- Antes una sola tabla por pista mezclaba un R2 Turbo de serie con un Bisonte de 1000 cv: el ranking lo ganaba el auto, no el piloto.
-- Ahora cada marca guarda el auto, su índice de rendimiento (PI) con mejoras, la clase que sale del PI, el nivel de ayudas (arcade / intermedio /
-- simulador / personalizado / aventura), las gomas y un resumen de las mejoras, y se compite contra los de la MISMA clase.
--   · public.class_scores: una marca por jugador, pista, tabla y clase (se puede tener el mejor tiempo en C y en S a la vez).
--   · submit_class_record(…): valida como submit_score/submit_record (tiempos posibles, tope de 40 envíos por hora), la clase la calcula el servidor
--     a partir del PI (no se puede mandar «clase D» con un PI de S) y devuelve {saved, best, rank, of, cls, top}.
--   · get_class_leaderboard(pista, tabla, clase, límite): la tabla de esa clase (clase '' = el mejor de cada jugador en cualquier clase).
-- Lo viejo (public.scores con submit_score / submit_record / get_leaderboard) queda igual: el APK estable lo sigue usando y el nuevo lo muestra como «HISTÓRICO».
-- El PI lo calcula el teléfono (como los tiempos): el servidor sólo comprueba que sea posible (100–999) y que la clase cuadre. Ver docs/AUDITORIA_CICLO_DE_JUEGO.md.

create table if not exists public.class_scores (
  player_id   uuid not null references public.players (id) on delete cascade,
  track       text not null check (track ~ '^[A-Za-z0-9_.:-]{1,48}$'),
  board       text not null check (board in ('race', 'timetrial', 'drag', 'drift', 'owev', 'fugitive')),
  cls         text not null check (cls in ('D', 'C', 'B', 'A', 'S', 'X')),
  value       numeric not null check (value > 0),
  car         text not null default '' check (char_length(car) <= 40),
  pi          int  not null check (pi between 100 and 999),
  sim         text not null default '' check (sim in ('', 'arcade', 'mid', 'pro', 'custom', 'adv')),
  tires       text not null default '' check (char_length(tires) <= 16),
  upg         text not null default '' check (char_length(upg) <= 40),
  laps        int  not null default 1 check (laps between 1 and 10),
  build       text not null default '' check (char_length(build) <= 40),
  late        boolean not null default false, -- se mandó desde la cola sin conexión (el tiempo se hizo antes; el servidor lo validó igual pero no lo vio llegar al momento)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (player_id, track, board, cls)
);
create index if not exists class_scores_rank_idx on public.class_scores (track, board, cls, value);

alter table public.class_scores enable row level security;
drop policy if exists class_scores_read on public.class_scores;
create policy class_scores_read on public.class_scores for select to anon, authenticated using (true);
revoke all on public.class_scores from anon, authenticated;
grant select on public.class_scores to anon, authenticated;

-- la clase que corresponde a un PI (los mismos cortes que game/data/catalog.json → classes)
create or replace function public._pi_class(p_pi int) returns text language sql immutable as $$
  select case when p_pi >= 800 then 'X' when p_pi >= 700 then 'S' when p_pi >= 600 then 'A' when p_pi >= 500 then 'B' when p_pi >= 400 then 'C' else 'D' end;
$$;

create or replace function public.submit_class_record(p_board text, p_track text, p_value numeric, p_car text default '', p_pi int default 0,
  p_sim text default '', p_tires text default '', p_upg text default '', p_laps int default 1, p_build text default '', p_name text default null, p_late boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := public._online_uid(); higher boolean := p_board in ('drift', 'fugitive'); tid text := p_track; c text; prev numeric; best numeric; rnk bigint; tot bigint;
  saved boolean := false; len numeric; minval numeric;
begin
  if p_board not in ('race', 'timetrial', 'drag', 'drift', 'owev', 'fugitive') then raise exception 'tabla inválida' using errcode = '22023'; end if;
  if p_pi is null or p_pi < 100 or p_pi > 999 then raise exception 'PI imposible' using errcode = '22023'; end if;
  if coalesce(p_sim, '') not in ('', 'arcade', 'mid', 'pro', 'custom', 'adv') then raise exception 'nivel de ayudas inválido' using errcode = '22023'; end if;
  p_laps := greatest(1, least(coalesce(p_laps, 1), 10));
  if p_board = 'owev' then
    if p_track !~ '^[A-Za-z0-9_.:-]{1,40}$' then raise exception 'evento inválido' using errcode = '22023'; end if;
    tid := 'ow:' || p_track;
    if p_value < 8 or p_value > 3600 then raise exception 'tiempo imposible' using errcode = '22023'; end if;
  elsif p_board = 'fugitive' then
    tid := 'fugitivo';
    if p_value < 1 or p_value > 500 or p_value <> floor(p_value) then raise exception 'racha imposible' using errcode = '22023'; end if;
  else
    select length_m into len from public.tracks where id = p_track;
    if not found then raise exception 'pista inexistente' using errcode = '22023'; end if;
    if p_board = 'drift' then
      if p_value <= 0 or p_value > 5000000 then raise exception 'puntaje imposible' using errcode = '22023'; end if;
    elsif p_board = 'drag' then
      if p_value < 3.5 or p_value > 120 then raise exception 'tiempo imposible' using errcode = '22023'; end if;
    else
      minval := (len * p_laps) / 120.0;
      if p_value < minval or p_value > 7200 then raise exception 'tiempo imposible' using errcode = '22023'; end if;
    end if;
  end if;
  if (select count(*) from public.score_log where player_id = uid and created_at > now() - interval '1 hour') >= 40 then
    raise exception 'demasiados envíos' using errcode = '53400';
  end if;
  insert into public.score_log (player_id) values (uid);
  insert into public.players (id, name) values (uid, case when char_length(trim(coalesce(p_name, ''))) >= 2 then left(trim(p_name), 20) else 'Piloto' end)
    on conflict (id) do update set name = case when p_name is not null and char_length(trim(p_name)) >= 2 then left(trim(p_name), 20) else public.players.name end, last_seen = now();
  c := public._pi_class(p_pi);
  select value into prev from public.class_scores where player_id = uid and track = tid and board = p_board and cls = c;
  if prev is null then
    insert into public.class_scores (player_id, track, board, cls, value, car, pi, sim, tires, upg, laps, build, late)
      values (uid, tid, p_board, c, p_value, left(coalesce(p_car, ''), 40), p_pi, coalesce(p_sim, ''), left(coalesce(p_tires, ''), 16), left(coalesce(p_upg, ''), 40), p_laps, left(coalesce(p_build, ''), 40), coalesce(p_late, false));
    saved := true;
  elsif (higher and p_value > prev) or (not higher and p_value < prev) then
    update public.class_scores set value = p_value, car = left(coalesce(p_car, ''), 40), pi = p_pi, sim = coalesce(p_sim, ''), tires = left(coalesce(p_tires, ''), 16),
      upg = left(coalesce(p_upg, ''), 40), laps = p_laps, build = left(coalesce(p_build, ''), 40), late = coalesce(p_late, false), updated_at = now()
      where player_id = uid and track = tid and board = p_board and cls = c;
    saved := true;
  end if;
  select value into best from public.class_scores where player_id = uid and track = tid and board = p_board and cls = c;
  select count(*) + 1 into rnk from public.class_scores s where s.track = tid and s.board = p_board and s.cls = c and ((higher and s.value > best) or (not higher and s.value < best));
  select count(*) into tot from public.class_scores s where s.track = tid and s.board = p_board and s.cls = c;
  return jsonb_build_object('saved', saved, 'best', best, 'rank', rnk, 'of', tot, 'cls', c,
    'top', (select jsonb_build_object('name', p.name, 'value', s.value, 'car', s.car) from public.class_scores s join public.players p on p.id = s.player_id
      where s.track = tid and s.board = p_board and s.cls = c order by case when higher then -s.value else s.value end, s.updated_at limit 1));
end;
$$;
revoke all on function public.submit_class_record(text, text, numeric, text, int, text, text, text, int, text, text, boolean) from public, anon;
grant execute on function public.submit_class_record(text, text, numeric, text, int, text, text, text, int, text, text, boolean) to authenticated;

-- la tabla de una clase; p_cls = '' → el mejor de cada jugador en cualquier clase (para «todas»)
create or replace function public.get_class_leaderboard(p_track text, p_board text, p_cls text default '', p_limit int default 50)
returns table (rank bigint, name text, value numeric, car text, pi int, cls text, sim text, tires text, late boolean, is_me boolean)
language sql stable security definer set search_path = public as $$
  with b as (
    select distinct on (s.player_id) s.*
    from public.class_scores s
    where s.track = p_track and s.board = p_board and (coalesce(p_cls, '') = '' or s.cls = p_cls)
    order by s.player_id, case when p_board in ('drift', 'fugitive') then -s.value else s.value end, s.updated_at
  )
  select row_number() over (order by case when p_board in ('drift', 'fugitive') then -b.value else b.value end, b.updated_at) as rank,
         p.name, b.value, b.car, b.pi, b.cls, b.sim, b.tires, b.late, (b.player_id = auth.uid()) as is_me
  from b join public.players p on p.id = b.player_id
  order by 1
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;
revoke all on function public.get_class_leaderboard(text, text, text, int) from public;
grant execute on function public.get_class_leaderboard(text, text, text, int) to anon, authenticated;

-- autoprueba mínima (sin usuarios: sólo las reglas puras)
do $do$
begin
  if public._pi_class(399) <> 'D' or public._pi_class(400) <> 'C' or public._pi_class(599) <> 'B' or public._pi_class(600) <> 'A'
     or public._pi_class(799) <> 'S' or public._pi_class(800) <> 'X' then
    raise exception 'class_records: cortes de clase mal';
  end if;
end
$do$;
