-- Dream Racing · borrar la cuenta desde el juego (Google Play lo exige para las apps que dejan crear cuentas).
-- Borra el usuario (y, por cascada, su fila de players y sus marcas en scores) y el registro de envíos. Solo borra al propio usuario.

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

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
