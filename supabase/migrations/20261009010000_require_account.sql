-- Dream Racing · seguridad: la economía online, el mercado, el chat y la presencia son SÓLO para cuentas con correo.
-- Hasta ahora cualquier usuario anónimo (Supabase deja crear miles con «Allow anonymous sign-ins», que el juego necesita para los rankings) podía llamar a esas funciones:
-- con muchas cuentas anónimas se podía cobrar el regalo diario de cada una, comprar autos y pasárselos a una cuenta principal por el mercado.
-- Los rankings (submit_score, get_leaderboard, set_player_name) siguen abiertos a los anónimos: no mueven plata ni autos.
-- Aditivo y repetible. Los dos puntos de entrada de todas las funciones de escritura son _online_uid() y _ensure_player().

create or replace function public._is_anon() returns boolean language sql stable as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
$$;
revoke all on function public._is_anon() from public, anon, authenticated;

create or replace function public._online_uid() returns uuid language plpgsql stable as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'sin sesión' using errcode = '28000'; end if;
  if public._is_anon() then raise exception 'hace falta una cuenta con correo' using errcode = '42501'; end if;
  return uid;
end;
$$;

create or replace function public._ensure_player(p_uid uuid, p_name text) returns text
language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if public._is_anon() then raise exception 'hace falta una cuenta con correo' using errcode = '42501'; end if;
  insert into public.players (id, name) values (p_uid, coalesce(nullif(left(trim(p_name), 20), ''), 'Piloto'))
    on conflict (id) do update set last_seen = now(),
      name = case when p_name is not null and char_length(trim(p_name)) >= 2 then left(trim(p_name), 20) else public.players.name end;
  select name into nm from public.players where id = p_uid;
  return nm;
end;
$$;
revoke all on function public._ensure_player(uuid, text) from public, anon, authenticated;
revoke all on function public._online_uid() from public, anon, authenticated;
