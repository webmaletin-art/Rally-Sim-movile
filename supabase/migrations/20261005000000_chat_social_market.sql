-- Dream Racing · mundo online social: chat mundial y privado, jugadores conectados, amigos (seguir), reportes con evidencia y mercado de autos.
-- Igual que el resto: nada se escribe directo en las tablas (RLS sin políticas); todo pasa por funciones que validan. Hace falta una cuenta con correo (authenticated).

-- ───────────── presencia (quién está conectado y dónde) ─────────────
create table if not exists public.presence (
  player_id  uuid primary key references public.players (id) on delete cascade,
  name       text not null,
  x          real not null default 0,
  z          real not null default 0,
  speed      real not null default 0,
  car        text not null default '',
  updated_at timestamptz not null default now()
);

-- estela de posiciones (para los reportes): se guardan unos minutos y se borran solas
create table if not exists public.presence_trail (
  id         bigint generated always as identity primary key,
  player_id  uuid not null references public.players (id) on delete cascade,
  x          real not null,
  z          real not null,
  speed      real not null,
  created_at timestamptz not null default now()
);
create index if not exists presence_trail_idx on public.presence_trail (player_id, created_at desc);

-- ───────────── chat ─────────────
-- channel: 'world' (mundial) o 'dm:<uuid menor>:<uuid mayor>' (privado entre dos jugadores)
create table if not exists public.chat_messages (
  id          bigint generated always as identity primary key,
  channel     text not null check (channel = 'world' or channel like 'dm:%'),
  sender      uuid not null references public.players (id) on delete cascade,
  sender_name text not null,
  body        text not null check (char_length(body) between 1 and 200),
  created_at  timestamptz not null default now()
);
create index if not exists chat_messages_channel_idx on public.chat_messages (channel, id desc);

-- sanciones del chat: cada 10 mensajes con insultos se bloquea el chat 10 min × el número de la sanción (10, 20, 30, 40…). Nunca es un bloqueo permanente.
create table if not exists public.chat_blocks (
  player_id     uuid primary key references public.players (id) on delete cascade,
  strikes       int not null default 0,
  level         int not null default 0,
  blocked_until timestamptz,
  total_hits    int not null default 0
);

-- ───────────── amigos (seguir) ─────────────
create table if not exists public.follows (
  follower   uuid not null references public.players (id) on delete cascade,
  target     uuid not null references public.players (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower, target),
  check (follower <> target)
);

-- ───────────── reportes: evidencia para revisar a mano (no hay ningún castigo automático) ─────────────
create table if not exists public.reports (
  id         bigint generated always as identity primary key,
  reporter   uuid references public.players (id) on delete set null,
  reported   uuid references public.players (id) on delete set null,
  created_at timestamptz not null default now(),
  status     text not null default 'nuevo',
  evidence   jsonb not null
);
create index if not exists reports_reported_idx on public.reports (reported, created_at desc);

-- ───────────── mercado de autos entre jugadores ─────────────
create table if not exists public.market_listings (
  id          bigint generated always as identity primary key,
  seller      uuid not null references public.players (id) on delete cascade,
  seller_name text not null,
  car         text not null check (char_length(car) between 1 and 60),
  state       jsonb not null,             -- el auto con sus mejoras (piezas, pintura, etc.): viaja con la venta
  price       int not null check (price between 1 and 99999999),
  status      text not null default 'open' check (status in ('open', 'sold', 'cancelled')),
  buyer       uuid references public.players (id) on delete set null,
  paid        boolean not null default false, -- el vendedor ya cobró (los créditos se guardan en cada teléfono)
  created_at  timestamptz not null default now(),
  sold_at     timestamptz
);
create index if not exists market_open_idx on public.market_listings (status, created_at desc);

alter table public.presence       enable row level security;
alter table public.presence_trail enable row level security;
alter table public.chat_messages  enable row level security;
alter table public.chat_blocks    enable row level security;
alter table public.follows        enable row level security;
alter table public.reports        enable row level security;
alter table public.market_listings enable row level security;
revoke all on public.presence, public.presence_trail, public.chat_messages, public.chat_blocks, public.follows, public.reports, public.market_listings from anon, authenticated;

-- ───────────── filtro de palabras ─────────────
-- Devuelve el texto con los insultos tapados con asteriscos y cuántos había. Compara sin mayúsculas ni tildes (la traducción letra a letra mantiene las posiciones);
-- solo palabras de 4 letras o más, para no tapar partes de palabras normales.
create or replace function public.mask_bad_words(p_text text, out masked text, out hits int)
language plpgsql immutable as $$
declare
  words text[] := array[
    -- español
    'puta','puto','putita','hijoputa','hijodeputa','hdp','pelotudo','pelotuda','forro','forra','mierda','carajo','concha','conchudo','conchatumadre','culiado','culiao','culiada',
    'verga','pijudo','chupapija','idiota','estupido','estupida','imbecil','mogolico','retrasado','retrasada','maricon','marica','zorra','trolo','trola','cagon','gilipollas','cabron','coño',
    'sorete','garca','boludo','boluda','tarado','tarada','basura','inutil','mamahuevo','malparido','hijueputa','puñeta','cojudo',
    -- inglés
    'fuck','fucker','fucking','shit','shitty','bitch','bastard','asshole','dick','cunt','whore','slut','nigger','nigga','faggot','retard','retarded','motherfucker','pussy','cock','twat','wanker','douche'
  ];
  w text;
  norm text;
  idx int;
begin
  masked := p_text;
  hits := 0;
  norm := lower(translate(p_text, 'áéíóúüñÁÉÍÓÚÜÑàèìòùâêîôû', 'aeiouunaeiouunaeiouaeiou'));
  foreach w in array words loop
    w := lower(translate(w, 'áéíóúüñ', 'aeiouun'));
    if char_length(w) < 4 then continue; end if;
    idx := position(w in norm);
    while idx > 0 loop
      hits := hits + 1;
      norm   := overlay(norm   placing repeat('*', char_length(w)) from idx for char_length(w));
      masked := overlay(masked placing repeat('*', char_length(w)) from idx for char_length(w));
      idx := position(w in norm);
    end loop;
  end loop;
end;
$$;

-- el jugador existe (con el nombre que manda el juego)
create or replace function public._ensure_player(p_uid uuid, p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  insert into public.players (id, name) values (p_uid, coalesce(nullif(left(trim(p_name), 20), ''), 'Piloto'))
    on conflict (id) do update set last_seen = now(),
      name = case when p_name is not null and char_length(trim(p_name)) >= 2 then left(trim(p_name), 20) else public.players.name end;
  select name into nm from public.players where id = p_uid;
  return nm;
end;
$$;
revoke all on function public._ensure_player(uuid, text) from public, anon, authenticated;

-- ───────────── chat: mandar ─────────────
create or replace function public.chat_send(p_channel text, p_body text, p_name text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  nm text;
  b record;
  m record;
  body text := left(trim(coalesce(p_body, '')), 200);
  parts text[];
  lv int;
  until timestamptz;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if char_length(body) = 0 then return jsonb_build_object('ok', false, 'reason', 'vacío'); end if;
  nm := public._ensure_player(uid, p_name);
  if p_channel <> 'world' then
    parts := string_to_array(p_channel, ':');
    if array_length(parts, 1) <> 3 or parts[1] <> 'dm' or not (uid::text = parts[2] or uid::text = parts[3]) or parts[2] >= parts[3] then
      raise exception 'canal inválido' using errcode = '22023';
    end if;
    if not exists (select 1 from public.players where id::text = case when uid::text = parts[2] then parts[3] else parts[2] end) then
      raise exception 'jugador inexistente' using errcode = '22023';
    end if;
  end if;
  insert into public.chat_blocks (player_id) values (uid) on conflict do nothing;
  select * into b from public.chat_blocks where player_id = uid for update;
  if b.blocked_until is not null and b.blocked_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'bloqueado', 'blocked_until', b.blocked_until, 'seconds', ceil(extract(epoch from (b.blocked_until - now())))::int);
  end if;
  -- máximo un mensaje por segundo
  if exists (select 1 from public.chat_messages where sender = uid and created_at > now() - interval '1 second') then
    return jsonb_build_object('ok', false, 'reason', 'muy rápido');
  end if;
  select * into m from public.mask_bad_words(body);
  if m.hits > 0 then
    -- el insulto nunca se publica; cada mensaje con insultos suma uno y cada 10 se bloquea el chat un rato más largo
    update public.chat_blocks set strikes = strikes + 1, total_hits = total_hits + m.hits where player_id = uid returning strikes, level into b.strikes, b.level;
    if b.strikes >= 10 then
      lv := b.level + 1;
      until := now() + make_interval(mins => 10 * lv);
      update public.chat_blocks set strikes = 0, level = lv, blocked_until = until where player_id = uid;
      insert into public.chat_messages (channel, sender, sender_name, body) values (p_channel, uid, nm, m.masked);
      return jsonb_build_object('ok', true, 'masked', true, 'blocked_until', until, 'seconds', 600 * lv);
    end if;
  end if;
  insert into public.chat_messages (channel, sender, sender_name, body) values (p_channel, uid, nm, m.masked);
  return jsonb_build_object('ok', true, 'masked', m.hits > 0, 'strikes', b.strikes);
end;
$$;

-- ───────────── chat: leer ─────────────
create or replace function public.chat_fetch(p_channel text, p_after bigint default 0, p_limit int default 40)
returns table (id bigint, channel text, sender uuid, sender_name text, body text, created_at timestamptz, mine boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  parts text[];
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if p_channel <> 'world' then
    parts := string_to_array(p_channel, ':');
    if array_length(parts, 1) <> 3 or parts[1] <> 'dm' or not (uid::text = parts[2] or uid::text = parts[3]) then
      raise exception 'canal inválido' using errcode = '22023';
    end if;
  end if;
  return query
    select * from (
      select c.id, c.channel, c.sender, c.sender_name, c.body, c.created_at, (c.sender = uid) as mine
      from public.chat_messages c
      where c.channel = p_channel and c.id > coalesce(p_after, 0)
      order by c.id desc
      limit greatest(1, least(coalesce(p_limit, 40), 100))
    ) t order by t.id;
end;
$$;

-- conversaciones privadas: con quién hablé y el último mensaje
create or replace function public.chat_threads()
returns table (partner uuid, partner_name text, last_body text, last_at timestamptz, last_id bigint)
language sql stable security definer set search_path = public as $$
  with mine as (
    select c.*, case when split_part(c.channel, ':', 2) = auth.uid()::text then split_part(c.channel, ':', 3)::uuid else split_part(c.channel, ':', 2)::uuid end as other
    from public.chat_messages c
    where c.channel like 'dm:%' and (split_part(c.channel, ':', 2) = auth.uid()::text or split_part(c.channel, ':', 3) = auth.uid()::text)
  ), last_msg as (
    select distinct on (other) other, body, created_at, id from mine order by other, id desc
  )
  select l.other, p.name, l.body, l.created_at, l.id from last_msg l join public.players p on p.id = l.other order by l.id desc limit 40;
$$;

-- ───────────── presencia ─────────────
create or replace function public.presence_beat(p_x real, p_z real, p_speed real, p_car text default '', p_name text default null) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); nm text;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  nm := public._ensure_player(uid, p_name);
  insert into public.presence (player_id, name, x, z, speed, car, updated_at)
    values (uid, nm, p_x, p_z, least(greatest(p_speed, 0), 400), left(coalesce(p_car, ''), 40), now())
    on conflict (player_id) do update set name = excluded.name, x = excluded.x, z = excluded.z, speed = excluded.speed, car = excluded.car, updated_at = now();
  insert into public.presence_trail (player_id, x, z, speed) values (uid, p_x, p_z, least(greatest(p_speed, 0), 400));
  delete from public.presence_trail where player_id = uid and created_at < now() - interval '10 minutes';
end;
$$;

create or replace function public.presence_leave() returns void
language sql security definer set search_path = public as $$
  delete from public.presence where player_id = auth.uid();
$$;

create or replace function public.presence_list(p_limit int default 60)
returns table (player_id uuid, name text, x real, z real, speed real, car text, is_friend boolean, follows_me boolean, is_me boolean)
language sql stable security definer set search_path = public as $$
  select pr.player_id, pr.name, pr.x, pr.z, pr.speed, pr.car,
         exists (select 1 from public.follows f where f.follower = auth.uid() and f.target = pr.player_id),
         exists (select 1 from public.follows f where f.follower = pr.player_id and f.target = auth.uid()),
         (pr.player_id = auth.uid())
  from public.presence pr
  where pr.updated_at > now() - interval '45 seconds'
  order by 8 desc, 7 desc, pr.name
  limit greatest(1, least(coalesce(p_limit, 60), 200));
$$;

-- ───────────── amigos ─────────────
create or replace function public.follow_set(p_target uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if p_target = uid then raise exception 'no podés seguirte a vos' using errcode = '22023'; end if;
  if p_on then
    if (select count(*) from public.follows where follower = uid) >= 200 then raise exception 'demasiados amigos' using errcode = '53400'; end if;
    insert into public.follows (follower, target) select uid, p_target where exists (select 1 from public.players where id = p_target) on conflict do nothing;
  else
    delete from public.follows where follower = uid and target = p_target;
  end if;
end;
$$;

create or replace function public.follow_list()
returns table (player_id uuid, name text, online boolean, follows_me boolean)
language sql stable security definer set search_path = public as $$
  select f.target, p.name,
         exists (select 1 from public.presence pr where pr.player_id = f.target and pr.updated_at > now() - interval '45 seconds'),
         exists (select 1 from public.follows b where b.follower = f.target and b.target = auth.uid())
  from public.follows f join public.players p on p.id = f.target
  where f.follower = auth.uid()
  order by 3 desc, p.name;
$$;

-- ───────────── reportar ─────────────
-- Guarda la evidencia para revisar a mano: no se castiga a nadie por reportes. p_client = lo que vio el teléfono del que reporta (chat reciente, posición, velocidad, eventos).
create or replace function public.report_submit(p_reported uuid, p_note text default '', p_client jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  ev jsonb;
  nm text;
  b record;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if p_reported = uid then raise exception 'no podés reportarte a vos' using errcode = '22023'; end if;
  select name into nm from public.players where id = p_reported;
  if nm is null then raise exception 'jugador inexistente' using errcode = '22023'; end if;
  if (select count(*) from public.reports where reporter = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'demasiados reportes' using errcode = '53400';
  end if;
  if octet_length(p_client::text) > 30000 then p_client := '{}'::jsonb; end if;
  select * into b from public.chat_blocks where player_id = p_reported;
  ev := jsonb_build_object(
    'version', 1,
    'at', now(),
    'reporter', uid,
    'reporter_name', (select name from public.players where id = uid),
    'reported', p_reported,
    'reported_name', nm,
    'note', left(coalesce(p_note, ''), 300),
    'client', p_client,
    'reported_chat', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'channel', case when c.channel = 'world' then 'world' else 'dm' end, 'at', c.created_at, 'body', c.body) order by c.id)
        from (select * from public.chat_messages where sender = p_reported and (channel = 'world' or channel like '%' || uid::text || '%') order by id desc limit 30) c), '[]'::jsonb),
    'reported_trail', coalesce((select jsonb_agg(jsonb_build_object('at', t.created_at, 'x', t.x, 'z', t.z, 'speed', t.speed) order by t.id)
        from (select * from public.presence_trail where player_id = p_reported order by id desc limit 60) t), '[]'::jsonb),
    'reporter_trail', coalesce((select jsonb_agg(jsonb_build_object('at', t.created_at, 'x', t.x, 'z', t.z, 'speed', t.speed) order by t.id)
        from (select * from public.presence_trail where player_id = uid order by id desc limit 30) t), '[]'::jsonb),
    'chat_penalties', jsonb_build_object('strikes', coalesce(b.strikes, 0), 'level', coalesce(b.level, 0), 'total_hits', coalesce(b.total_hits, 0), 'blocked_until', b.blocked_until)
  );
  insert into public.reports (reporter, reported, evidence) values (uid, p_reported, ev);
  return jsonb_build_object('ok', true);
end;
$$;

-- ───────────── mercado de autos ─────────────
create or replace function public.market_list(p_car text, p_state jsonb, p_price int, p_name text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); nm text; new_id bigint;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if p_price is null or p_price < 1 or p_price > 99999999 then raise exception 'precio inválido' using errcode = '22023'; end if;
  if octet_length(p_state::text) > 20000 then raise exception 'auto demasiado grande' using errcode = '22023'; end if;
  nm := public._ensure_player(uid, p_name);
  if (select count(*) from public.market_listings where seller = uid and status = 'open') >= 5 then
    raise exception 'máximo 5 autos en venta' using errcode = '53400';
  end if;
  insert into public.market_listings (seller, seller_name, car, state, price) values (uid, nm, left(p_car, 60), p_state, p_price) returning id into new_id;
  return jsonb_build_object('ok', true, 'id', new_id);
end;
$$;

create or replace function public.market_browse(p_limit int default 40)
returns table (id bigint, seller_name text, car text, state jsonb, price int, mine boolean, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.id, m.seller_name, m.car, m.state, m.price, (m.seller = auth.uid()), m.created_at
  from public.market_listings m where m.status = 'open'
  order by m.id desc limit greatest(1, least(coalesce(p_limit, 40), 100));
$$;

create or replace function public.market_cancel(p_id bigint) returns void
language sql security definer set search_path = public as $$
  update public.market_listings set status = 'cancelled' where id = p_id and seller = auth.uid() and status = 'open';
$$;

-- comprar: el auto queda reservado para quien lo pide primero; el teléfono del comprador descuenta los créditos y se queda con el auto (con sus mejoras)
create or replace function public.market_buy(p_id bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); m public.market_listings%rowtype;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  update public.market_listings set status = 'sold', buyer = uid, sold_at = now()
    where id = p_id and status = 'open' and seller <> uid returning * into m;
  if not found then return jsonb_build_object('ok', false, 'reason', 'ya no está disponible'); end if;
  return jsonb_build_object('ok', true, 'car', m.car, 'state', m.state, 'price', m.price);
end;
$$;

-- cobrar lo vendido: devuelve cuántos autos se vendieron desde la última vez y el total de créditos
create or replace function public.market_collect() returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n int; total bigint;
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  with c as (update public.market_listings set paid = true where seller = uid and status = 'sold' and paid = false returning price)
    select count(*), coalesce(sum(price), 0) into n, total from c;
  return jsonb_build_object('count', n, 'credits', total);
end;
$$;

-- ───────────── permisos ─────────────
revoke all on function public.mask_bad_words(text) from public, anon, authenticated;
grant execute on function public.mask_bad_words(text) to authenticated;
do $$
declare f text;
begin
  foreach f in array array[
    'chat_send(text, text, text)', 'chat_fetch(text, bigint, int)', 'chat_threads()', 'presence_beat(real, real, real, text, text)', 'presence_leave()', 'presence_list(int)',
    'follow_set(uuid, boolean)', 'follow_list()', 'report_submit(uuid, text, jsonb)', 'market_list(text, jsonb, int, text)', 'market_browse(int)', 'market_cancel(bigint)', 'market_buy(bigint)', 'market_collect()'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- borrar la cuenta también borra el chat, la presencia, los amigos y los autos en venta (por cascada); los reportes quedan sin los datos de quien los hizo
create or replace function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'sin sesión' using errcode = '28000';
  end if;
  delete from public.score_log where player_id = uid;
  delete from public.scores    where player_id = uid;
  delete from public.players   where id = uid;
  delete from auth.users       where id = uid;
end;
$$;
