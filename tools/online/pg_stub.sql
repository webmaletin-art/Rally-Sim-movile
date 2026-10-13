-- Simula lo mínimo de Supabase para probar las migraciones en un Postgres común: roles anon/authenticated, esquema auth y auth.uid().
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin; exception when duplicate_object then null; end $$;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated;
-- los datos del token (en Supabase: auth.jwt()); la prueba los pone con request.jwt.claims
create or replace function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;

-- Realtime: la tabla de mensajes (en Supabase la maneja el servicio, con RLS activa) y realtime.topic() (el canal de la sesión; la prueba lo pone con set_config('realtime.topic', …))
create schema if not exists realtime;
create table if not exists realtime.messages (id bigserial primary key, topic text not null, extension text not null, payload jsonb, inserted_at timestamptz not null default now());
alter table realtime.messages enable row level security;
create or replace function realtime.topic() returns text language sql stable as $$ select nullif(current_setting('realtime.topic', true), '') $$;
grant usage on schema realtime to anon, authenticated;
grant select, insert on realtime.messages to authenticated;
grant usage, select on sequence realtime.messages_id_seq to authenticated;
