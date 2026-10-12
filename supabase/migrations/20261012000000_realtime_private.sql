-- Dream Racing · Supabase Realtime (tiempo real) listo para conectar: canales PRIVADOS del mundo online.
-- Aditiva y repetible. No cambia nada del juego actual: sólo deja armadas las reglas que Realtime consulta al entrar a un canal «world:…» (posiciones de los autos, ver
-- godot/game/online/world_sync.gd) y quién puede mandar o recibir mensajes ahí:
--   · sólo cuentas con correo (no anónimas: las anónimas son las de los rankings y se crean de a miles)
--   · sólo temas que empiezan con «world:» (el mundo, en celdas de 2 km) y sólo mensajes de «broadcast» y «presence»
--   · y no las cuentas suspendidas (tabla realtime_bans: se carga a mano desde el panel de Supabase)
-- Hay que apagar además «Allow public access» en Realtime → Settings, para que NO se pueda entrar a canales públicos (ver docs/ONLINE_SUPABASE.md, «Tiempo real»).

create table if not exists public.realtime_bans (
  player_id uuid primary key,
  until timestamptz, -- null = para siempre
  reason text not null default '',
  created_at timestamptz not null default now()
);
alter table public.realtime_bans enable row level security;
revoke all on public.realtime_bans from anon, authenticated;

-- ¿Esta sesión puede usar el tiempo real? Se llama desde las políticas de realtime.messages (por eso es security definer: lee la tabla de suspendidas).
create or replace function public._rt_allowed() returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
     and not exists (select 1 from public.realtime_bans b where b.player_id = auth.uid() and (b.until is null or b.until > now()))
$$;
revoke all on function public._rt_allowed() from public, anon;
grant execute on function public._rt_allowed() to authenticated;

do $$
begin
  if to_regclass('realtime.messages') is null then
    raise notice 'No existe realtime.messages (¿Postgres sin Realtime?): no se crean las políticas del tiempo real.';
    return;
  end if;
  execute 'drop policy if exists dr_world_read on realtime.messages';
  execute 'drop policy if exists dr_world_write on realtime.messages';
  -- recibir (entrar al canal y oír a los demás)
  execute $p$create policy dr_world_read on realtime.messages for select to authenticated
    using (realtime.topic() like 'world:%' and realtime.messages.extension in ('broadcast', 'presence') and public._rt_allowed())$p$;
  -- mandar
  execute $p$create policy dr_world_write on realtime.messages for insert to authenticated
    with check (realtime.topic() like 'world:%' and realtime.messages.extension in ('broadcast', 'presence') and public._rt_allowed())$p$;
end $$;
