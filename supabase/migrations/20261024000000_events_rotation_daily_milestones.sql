-- Dream Racing · 16/10/2026 — Versión candidata, FASE 5 (eventos y retención). NO APLICADA: se aplica con el flujo «Supabase · aplicar migraciones» cuando el dueño lo autorice.
--   1) Horarios ROTATIVOS: una plantilla con params.rotate = true empieza cada «día de evento» a UNA hora de su lista hours_utc, la que toca ese día
--      (hours_utc[(día % n) + 1]); el día de evento arranca a las 12 UTC (9 de la mañana en Argentina) para que la noche argentina, que cruza la medianoche
--      UTC, quede en el mismo día. Sin rotate todo sigue como antes (cualquiera de las horas de la lista). La cuenta se hace en _wev_next_slot (se prueba sola).
--      Las cacerías de fábrica pasan a rotar: la de la noche entre las 20 y las 23 h de Argentina, la de la tarde entre las 15 y las 18 h.
--   2) Cacería ACCESIBLE (plantilla nueva caza_inicial): dos autos de clase C (pickup, SUV, Camo, Torito, Clásico 60), la presa sin el empujón de motor ni de
--      agarre de las otras cacerías, más lenta y con errores (params boost/pace/errors, que lee game/city/city_modes.gd → prey_ai), 45 s pegado en vez de 60,
--      60 s en el mapa y sólo para autos de hasta PI 599 (params.max_pi, lo controla el juego). Mismo premio: el auto. Queda APAGADA hasta publicar la versión nueva.
--   3) DESAFÍOS DEL DÍA configurables: tabla game_cfg (clave → jsonb) con la fila «daily» {on, cr, n_play, n_race, tz_h}. El juego la recibe con el estado de
--      la cuenta (account_state / account_apply, campo «dcfg»): no hay consultas nuevas. Los premios se cobran como earn kind «daily» con once = true
--      (20261022 ya no los paga dos veces: la clave «daily:<día>:<n>» queda en account_econ.claims).
--   4) HITOS DE LA TEMPORADA: cada temporada trae params.hitos [{pts, reward}]; season_claim(id) paga los hitos alcanzados una sola vez (tabla wev_milestones),
--      durante la temporada y hasta 7 días después. _wev_json agrega «hitos» y «hitos_got» a la temporada.
-- Aditivo y repetible: tablas nuevas «if not exists», funciones reemplazadas con lo de antes + lo nuevo, plantillas cambiadas sólo si siguen de fábrica.

-- ───────────── 1) horarios rotativos ─────────────
insert into public.wev_cfg (key, val) values ('rotate_shift_h', '12') on conflict (key) do nothing;

-- La próxima hora de arranque de una plantilla a partir de p_from (respetando el aviso previo). null = ninguna en 48 h.
create or replace function public._wev_next_slot(p_hours int[], p_rotate boolean, p_shift_h int, p_from timestamptz, p_notice_min int) returns timestamptz
language plpgsql stable as $$
declare h int; c timestamptz; n int := coalesce(array_length(p_hours, 1), 0); dayn bigint;
begin
  if n = 0 then return null; end if;
  for h in 0..48 loop
    c := date_trunc('hour', p_from at time zone 'utc') at time zone 'utc' + make_interval(hours => h);
    continue when c <= p_from + make_interval(mins => p_notice_min);
    if p_rotate then
      dayn := floor(extract(epoch from (c - make_interval(hours => p_shift_h))) / 86400)::bigint;
      if extract(hour from c at time zone 'utc')::int = p_hours[(dayn % n)::int + 1] then return c; end if;
    elsif extract(hour from c at time zone 'utc')::int = any (p_hours) then
      return c;
    end if;
  end loop;
  return null;
end;
$$;
revoke all on function public._wev_next_slot(int[], boolean, int, timestamptz, int) from public, anon, authenticated;

-- igual que 20261020 (una plantilla por vez, con su descanso, al azar según el peso) pero la hora sale de _wev_next_slot
create or replace function public._wev_ensure() returns void language plpgsql security definer set search_path = public as $$
declare t public.wev_templates; open_n int; maxo int; st timestamptz; tries int := 0; skip text[] := '{}';
begin
  if coalesce(public._wev_conf('auto'), 'true') <> 'true' then return; end if;
  perform pg_advisory_xact_lock(424243);
  maxo := coalesce(public._wev_conf('max_open'), '4')::int;
  loop
    select count(*) into open_n from public.wev_events where ends_at > now();
    exit when open_n >= maxo or tries >= 8;
    tries := tries + 1;
    select * into t from public.wev_templates w
      where w.enabled and not (w.id = any (skip))
        and not exists (select 1 from public.wev_events e where e.tpl = w.id and e.ends_at > now())
        and not exists (select 1 from public.wev_events e where e.tpl = w.id and e.starts_at > now() - make_interval(hours => w.cooldown_h))
      order by -ln(greatest(random(), 1e-9)) / greatest(w.weight, 1) limit 1;
    exit when t.id is null;
    if t.hours_utc is not null and array_length(t.hours_utc, 1) > 0 then
      st := public._wev_next_slot(t.hours_utc, coalesce((t.params ->> 'rotate')::boolean, false), coalesce(public._wev_conf('rotate_shift_h'), '12')::int, now(), t.notice_min);
      if st is null then skip := skip || t.id; continue; end if;
    else
      st := now() + make_interval(mins => t.notice_min + floor(random() * 180)::int);
    end if;
    perform public._wev_make(t, st);
  end loop;
end;
$$;
revoke all on function public._wev_ensure() from public, anon, authenticated;

-- las cacerías de fábrica pasan a rotar (sólo si el dueño no las cambió desde el panel)
update public.wev_templates set hours_utc = array[23, 0, 1, 2], cooldown_h = 18, params = params || '{"rotate": true}'::jsonb,
  title = 'Cazarrecompensas de la noche',
  descr = 'Tres autos sueltos en Dream City, entre las 20 y las 23 (hora argentina; cada día a otra hora). Durante 45 s se ve en el mapa dónde están: el primero que se pegue 60 s a uno se lo lleva.'
  where id = 'caza_22' and hours_utc = array[1] and title = 'Cazarrecompensas de las 22';
update public.wev_templates set hours_utc = array[18, 19, 20, 21], cooldown_h = 18, params = params || '{"rotate": true}'::jsonb,
  descr = 'Un auto suelto en Dream City, entre las 15 y las 18 (hora argentina; cada día a otra hora): el primero que se le pegue 60 s se lo lleva.'
  where id = 'caza_tarde' and hours_utc = array[19];

-- ───────────── 2) cacería accesible ─────────────
-- APAGADA al aplicar (enabled = false): el APK estable usa el mismo servidor y no conoce boost/pace/errors/max_pi (soltaría la presa reforzada y sin tope de PI).
-- Se prende cuando la versión nueva sea la publicada: Table Editor → wev_templates → caza_inicial → enabled = true.
insert into public.wev_templates (id, kind, title, descr, weight, params, reward, duration_min, attempts, max_winners, notice_min, cooldown_h, hours_utc, enabled) values
  ('caza_inicial', 'bounty', 'Cacería para principiantes',
   'Dos autos de calle sueltos en Dream City (cada día a otra hora, entre las 11 y las 14 de Argentina). No escapan tan rápido y se equivocan: el primero que se pegue 45 s a uno se lo lleva. Sólo con autos de hasta PI 599 (clase C o B).', 3,
   '{"n": 2, "pool": ["pickup", "suv", "camo", "torito", "clasico60"], "hold_s": 45, "map_s": 60, "boost": 1.0, "pace": 0.95, "errors": true, "max_pi": 599, "rotate": true}',
   '{"car": true}', 20, 0, 0, 60, 18, array[14, 15, 16, 17], false)
on conflict (id) do nothing;

-- ───────────── 3) desafíos del día (configuración) ─────────────
create table if not exists public.game_cfg (key text primary key, val jsonb not null, note text not null default '');
insert into public.game_cfg (key, val, note) values
  ('daily', '{"on": true, "cr": [2500, 5000, 4000], "n_play": 2, "n_race": 2, "tz_h": -3}',
   'Desafíos del día: on (prendidos), cr (premio de cada uno), n_play (carreras del mapa a terminar), n_race (eventos del menú a terminar), tz_h (huso del día: -3 = Argentina)')
on conflict (key) do nothing;
alter table public.game_cfg enable row level security;
revoke all on public.game_cfg from anon, authenticated;

-- el estado de la cuenta de 20261022 + la configuración de los desafíos del día
create or replace function public._acct_json(r public.account_econ) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('credits', r.credits, 'voucher', r.voucher, 'cars', r.cars, 'iap', r.iap, 'streak', r.streak, 'daily', coalesce(to_char(r.last_daily, 'YYYY-MM-DD'), ''),
    'seq', r.seq, 'now', extract(epoch from now())::bigint, 'claims', r.claims,
    'dcfg', coalesce((select g.val from public.game_cfg g where g.key = 'daily'), '{}'::jsonb))
$$;
revoke all on function public._acct_json(public.account_econ) from public, anon, authenticated;

-- ───────────── 4) hitos de la temporada ─────────────
create table if not exists public.wev_milestones (
  event_id bigint not null references public.wev_events (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  idx int not null,
  reward jsonb not null default '{}'::jsonb,
  at timestamptz not null default now(),
  primary key (event_id, user_id, idx)
);
alter table public.wev_milestones enable row level security;
revoke all on public.wev_milestones from anon, authenticated;

update public.wev_templates set params = params || '{"hitos": [{"pts": 25, "reward": {"credits": 3000}}, {"pts": 60, "reward": {"credits": 6000}}, {"pts": 150, "reward": {"voucher": 15000}}, {"pts": 300, "reward": {"credits": 20000}}]}'::jsonb
  where id = 'temporada' and not (params ? 'hitos');

-- los hitos de una temporada: los de su evento o, si se programó antes de esta migración, los de su plantilla
create or replace function public._wev_hitos(e public.wev_events) returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(e.params -> 'hitos', (select w.params -> 'hitos' from public.wev_templates w where w.id = e.tpl), '[]'::jsonb)
$$;
revoke all on function public._wev_hitos(public.wev_events) from public, anon, authenticated;

create or replace function public.season_claim(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := public._online_uid(); e public.wev_events; hs jsonb; pts bigint; i int; got jsonb := '[]'::jsonb; g jsonb; n int;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'iniciá sesión'); end if;
  select * into e from public.wev_events where id = p_id and kind = 'season';
  if not found then return jsonb_build_object('ok', false, 'reason', 'esa temporada no existe'); end if;
  if now() < e.starts_at or now() > e.ends_at + interval '7 days' then return jsonb_build_object('ok', false, 'reason', 'la temporada no está abierta'); end if;
  perform pg_advisory_xact_lock(424245, hashtext(uid::text));
  pts := coalesce((select s.pts from public._wev_season_rows(e.id) s where s.who = uid), 0);
  hs := public._wev_hitos(e);
  for i in 0 .. jsonb_array_length(hs) - 1 loop
    if pts >= coalesce((hs -> i ->> 'pts')::bigint, 1000000000) then
      insert into public.wev_milestones (event_id, user_id, idx) values (e.id, uid, i) on conflict do nothing;
      get diagnostics n = row_count;
      if n = 1 then
        g := public._wev_grant(uid, coalesce(hs -> i -> 'reward', '{}'::jsonb));
        update public.wev_milestones set reward = g where event_id = e.id and user_id = uid and idx = i;
        got := got || jsonb_build_object('idx', i, 'reward', g);
      end if;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'pts', pts, 'granted', got,
    'got', coalesce((select jsonb_agg(m.idx order by m.idx) from public.wev_milestones m where m.event_id = e.id and m.user_id = uid), '[]'::jsonb));
end;
$$;
revoke all on function public.season_claim(bigint) from public;
grant execute on function public.season_claim(bigint) to authenticated;

-- lo de 20261021 + los hitos de la temporada y cuáles ya cobró el jugador
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
    'hitos', case when e.kind = 'season' then public._wev_hitos(e) end,
    'hitos_got', case when e.kind = 'season' then coalesce((select jsonb_agg(m.idx order by m.idx) from public.wev_milestones m where m.event_id = e.id and m.user_id = p_uid), '[]'::jsonb) end,
    'winners', coalesce((select jsonb_agg(jsonb_build_object('name', w.name, 'slot', w.slot, 'value', w.value) order by w.at) from public.wev_winners w where w.event_id = e.id), '[]'::jsonb))
$$;
revoke all on function public._wev_json(public.wev_events, uuid) from public, anon, authenticated;

-- ───────────── autoprueba al aplicar (si algo falla, se deshace todo) ─────────────
do $do$
declare a timestamptz; b timestamptz; j jsonb;
begin
  -- sin rotar: la primera hora de la lista que llega después del aviso
  a := public._wev_next_slot(array[19], false, 12, '2026-10-16 10:00+00', 30);
  if a <> '2026-10-16 19:00+00'::timestamptz then raise exception 'autoprueba: hora fija %', a; end if;
  -- rotando: dos días seguidos caen a horas distintas de la lista y nunca a menos de 18 h (el descanso de la plantilla)
  a := public._wev_next_slot(array[23, 0, 1, 2], true, 12, '2026-10-16 13:00+00', 60);
  b := public._wev_next_slot(array[23, 0, 1, 2], true, 12, a + interval '1 hour', 60);
  if a is null or b is null or extract(hour from a at time zone 'utc') = extract(hour from b at time zone 'utc') or b - a < interval '18 hours' then
    raise exception 'autoprueba: rotación % → %', a, b;
  end if;
  if (select count(*) from public.wev_templates where id = 'caza_inicial') <> 1 then raise exception 'autoprueba: falta caza_inicial'; end if;
  if (select val ->> 'on' from public.game_cfg where key = 'daily') is null then raise exception 'autoprueba: falta la configuración de los desafíos'; end if;
  perform public._wev_ensure();
  select public._wev_json(e, null) into j from public.wev_events e where e.kind = 'season' order by id desc limit 1;
  if j is not null and not (j ? 'hitos') then raise exception 'autoprueba: _wev_json sin hitos'; end if;
  raise notice 'horarios rotativos, cacería accesible, desafíos del día y hitos de temporada: listo';
end;
$do$;
