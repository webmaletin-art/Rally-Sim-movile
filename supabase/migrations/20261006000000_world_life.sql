-- Dream Racing · World Life (etapa 1): el servidor sólo da la REFERENCIA del mundo (id, versión, semilla y hora lógica) al entrar. No simula nada: cada teléfono reconstruye la
-- vida del mundo (tráfico, estacionados, semáforos…) con esas cuatro cosas, y todos obtienen lo mismo. Aditiva: no toca datos existentes.

create table if not exists public.worlds (
  id         text primary key,
  version    int not null default 1 check (version >= 1),         -- versión de las REGLAS de World Life (no es el tiempo)
  seed       bigint not null check (seed between 1 and 9007199254740991), -- semilla determinista (cabe exacta en un número JSON)
  epoch      timestamptz not null default now(),                  -- instante (hora del servidor) en que el tiempo del mundo valía time0
  time0      double precision not null default 0,                 -- tiempo lógico del mundo (segundos) en `epoch`
  time_scale real not null default 1 check (time_scale >= 0),     -- segundos de mundo por segundo real
  updated_at timestamptz not null default now()
);

alter table public.worlds enable row level security;
revoke all on public.worlds from anon, authenticated;

-- el mundo de Dream City: arranca a las 9:00 (el día del mundo dura 960 s: 9:00 = 360 s)
insert into public.worlds (id, version, seed, epoch, time0, time_scale)
values ('dream_city', 1, (floor(random() * 9000000000000000) + 1)::bigint, now(), 360, 1)
on conflict (id) do nothing;

-- entrar al mundo (y volver a pedir la hora cada tanto para corregir la deriva): devuelve id, versión, semilla y el tiempo lógico de AHORA
create or replace function public.world_join(p_world text default 'dream_city') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare w public.worlds%rowtype;
begin
  if auth.uid() is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  select * into w from public.worlds where id = coalesce(nullif(p_world, ''), 'dream_city');
  if not found then raise exception 'mundo inexistente' using errcode = '22023'; end if;
  return jsonb_build_object(
    'world_id', w.id,
    'version', w.version,
    'seed', w.seed,
    'time', w.time0 + extract(epoch from (now() - w.epoch)) * w.time_scale,
    'time_scale', w.time_scale,
    'server_now', extract(epoch from now())
  );
end;
$$;

revoke all on function public.world_join(text) from public, anon;
grant execute on function public.world_join(text) to authenticated;
