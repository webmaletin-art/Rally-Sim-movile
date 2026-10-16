-- Dream Racing · 15/10/2026 — Auditoría del ciclo de juego, P0 «premios irrepetibles» (docs/AUDITORIA_CICLO_DE_JUEGO.md):
--   logros, medallas, primeras victorias, rangos, niveles y la Aventura vivían sólo en el teléfono. Al reinstalar se volvían a cobrar (logros $205.500, carreras del
--   mapa $398.700) y a la vez se perdía el progreso. Ahora la cuenta guarda qué se cobró y lo logrado (account_econ.claims) y lo devuelve al sincronizar.
--   · `claims`: clave «tipo:ref» → {a: monto cobrado la 1.ª vez, m: mejor medalla, b: mejor tiempo (menos es mejor), h: mejor puntaje (más es mejor),
--     w: victorias, p: veces jugado, t: última vez}. Sólo datos del juego, nada personal.
--   · Premios de UNA sola vez por naturaleza (logro «goal», copa completa «cup», rango «rank», nivel «level», Aventura «adv»): el servidor no los paga dos veces,
--     también con las versiones viejas del juego (la referencia es única).
--   · Premios con «primera vez» más cara (carreras del mapa «owev», copas «race»): el juego manda {first: true, rep: monto de repetición}; si la cuenta ya lo tenía
--     (p. ej. después de reinstalar) paga la repetición.
--   · Evento nuevo «prog» (sin plata): actualiza medallas, tiempos o «descubierta» sin cobrar nada. Un servidor sin esta migración lo rechaza
--     («evento desconocido») sin romper la tanda.
-- Aditivo y repetible: una columna nueva con valor por defecto y funciones reemplazadas manteniendo lo de antes (el vale de taller de 20261021 sigue igual).
-- OJO (de 20261021): _acct_one es un envoltorio de _acct_one_base; reemplazar _acct_one entera = reemplazar el envoltorio, no la base.

alter table public.account_econ add column if not exists claims jsonb not null default '{}'::jsonb;

create or replace function public._acct_json(r public.account_econ) returns jsonb language sql stable as $$
  select jsonb_build_object('credits', r.credits, 'voucher', r.voucher, 'cars', r.cars, 'iap', r.iap, 'streak', r.streak, 'daily', coalesce(to_char(r.last_daily, 'YYYY-MM-DD'), ''),
    'seq', r.seq, 'now', extract(epoch from now())::bigint, 'claims', r.claims)
$$;
revoke all on function public._acct_json(public.account_econ) from public, anon, authenticated;

-- une lo guardado con lo nuevo: medalla, victorias, jugadas y puntaje suben; el tiempo baja; el monto cobrado es el mayor
create or replace function public._claim_merge(p_old jsonb, p_e jsonb, p_granted bigint) returns jsonb language plpgsql stable as $$
declare o jsonb := coalesce(p_old, '{}'::jsonb); r jsonb;
begin
  r := o || jsonb_build_object('t', extract(epoch from now())::bigint);
  if p_granted > 0 then r := r || jsonb_build_object('a', greatest(coalesce((o ->> 'a')::bigint, 0), p_granted)); end if;
  if p_e ? 'm' then r := r || jsonb_build_object('m', greatest(coalesce((o ->> 'm')::int, 0), least(greatest((p_e ->> 'm')::int, 0), 3))); end if;
  if p_e ? 'w' then r := r || jsonb_build_object('w', greatest(coalesce((o ->> 'w')::int, 0), least(greatest((p_e ->> 'w')::int, 0), 100000))); end if;
  if p_e ? 'p' then r := r || jsonb_build_object('p', greatest(coalesce((o ->> 'p')::int, 0), least(greatest((p_e ->> 'p')::int, 0), 100000))); end if;
  if p_e ? 'b' and (p_e ->> 'b')::numeric > 0 then r := r || jsonb_build_object('b', least(coalesce((o ->> 'b')::numeric, (p_e ->> 'b')::numeric), (p_e ->> 'b')::numeric)); end if;
  if p_e ? 'h' and (p_e ->> 'h')::numeric > 0 then r := r || jsonb_build_object('h', greatest(coalesce((o ->> 'h')::numeric, 0), (p_e ->> 'h')::numeric)); end if;
  return r;
end;
$$;
revoke all on function public._claim_merge(jsonb, jsonb, bigint) from public, anon, authenticated;

-- envoltorio de la función de siempre: el vale de taller (20261021) + los premios irrepetibles y el progreso (esta migración)
create or replace function public._acct_one(p_uid uuid, e jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  t text := e ->> 't'; v bigint; c0 bigint; c1 bigint; used bigint; res jsonb;
  k text; key text := ''; once boolean := false; cl jsonb; ee jsonb := e; granted bigint := 0; rep_amount bigint;
begin
  -- progreso sin plata (medallas, tiempos, carrera descubierta)
  if t = 'prog' then
    key := left(coalesce(e ->> 'key', ''), 64);
    if key !~ '^(owev|race):[A-Za-z0-9_.:-]{1,48}$' then raise exception 'progreso inválido' using errcode = '22023'; end if;
    select a.claims into cl from public.account_econ a where a.user_id = p_uid for update;
    if not (cl ? key) and (select count(*) from jsonb_object_keys(cl)) >= 3000 then return jsonb_build_object('ok', false, 'reason', 'demasiado progreso guardado'); end if;
    update public.account_econ set claims = jsonb_set(claims, array[key], public._claim_merge(claims -> key, e, 0)) where user_id = p_uid;
    return jsonb_build_object('ok', true);
  end if;
  -- premios: una sola vez / primera vez
  if t = 'earn' then
    k := left(coalesce(e ->> 'kind', 'misc'), 16);
    if coalesce(e ->> 'ref', '') <> '' then key := k || ':' || left(e ->> 'ref', 40); end if;
    once := k in ('goal', 'cup', 'rank', 'level', 'adv') or coalesce((e ->> 'once')::boolean, false);
    if key <> '' and (once or e ? 'first' or e ? 'm' or e ? 'b' or e ? 'h' or e ? 'w' or e ? 'p') then
      select a.claims into cl from public.account_econ a where a.user_id = p_uid for update;
      cl := coalesce(cl, '{}'::jsonb);
      if once and cl ? key then
        return jsonb_build_object('ok', false, 'reason', 'ese premio ya se cobró', 'dup', true, 'claimed', true);
      end if;
      if e ? 'first' and cl ? key then
        -- la cuenta ya lo tenía (reinstalación, otro teléfono): paga como repetición
        rep_amount := greatest(0, least(coalesce((e ->> 'amount')::bigint, 0), coalesce((e ->> 'rep')::bigint, 0)));
        if rep_amount <= 0 then
          update public.account_econ set claims = jsonb_set(claims, array[key], public._claim_merge(claims -> key, e, 0)) where user_id = p_uid;
          return jsonb_build_object('ok', true, 'granted', 0, 'repeat', true);
        end if;
        ee := jsonb_set(e, '{amount}', to_jsonb(rep_amount));
      end if;
      if not (cl ? key) and (select count(*) from jsonb_object_keys(cl)) >= 3000 then
        return public._acct_one_base(p_uid, ee); -- (tope de tamaño: se paga como siempre pero no se guarda)
      end if;
      res := public._acct_one_base(p_uid, ee);
      if coalesce((res ->> 'ok')::boolean, false) then
        granted := coalesce((res ->> 'granted')::bigint, 0);
        update public.account_econ set claims = jsonb_set(claims, array[key], public._claim_merge(claims -> key, e, granted)) where user_id = p_uid;
      end if;
      if ee is distinct from e then res := res || jsonb_build_object('repeat', true); end if;
      return res;
    end if;
    return public._acct_one_base(p_uid, e);
  end if;
  -- compras del taller: el vale va primero (20261021, sin cambios)
  if t in ('buy_upgrade', 'buy_tires', 'replace_tires', 'buy_part') or (t = 'spend' and coalesce(e ->> 'kind', '') in ('tune', 'repair')) then
    select a.voucher, a.credits into v, c0 from public.account_econ a where a.user_id = p_uid for update;
    if coalesce(v, 0) > 0 then
      update public.account_econ set credits = credits + v, voucher = 0 where user_id = p_uid;
      res := public._acct_one_base(p_uid, e);
      select a.credits into c1 from public.account_econ a where a.user_id = p_uid;
      used := least(v, greatest(0, c0 + v - c1));
      update public.account_econ set credits = credits - (v - used), voucher = v - used where user_id = p_uid;
      return res || jsonb_build_object('voucher_used', used);
    end if;
  end if;
  return public._acct_one_base(p_uid, e);
end;
$$;
revoke all on function public._acct_one(uuid, jsonb) from public, anon, authenticated;

-- autoprueba al aplicar (si algo falla, se deshace todo)
do $do$
declare j jsonb;
begin
  if to_regprocedure('public._acct_one_base(uuid, jsonb)') is null then raise exception 'autoprueba: falta _acct_one_base (migración 20261021)'; end if;
  j := public._claim_merge('{"m": 1, "b": 50}'::jsonb, '{"m": 3, "b": 60, "w": 2}'::jsonb, 500);
  if (j ->> 'm')::int <> 3 or (j ->> 'b')::numeric <> 50 or (j ->> 'w')::int <> 2 or (j ->> 'a')::bigint <> 500 then raise exception 'autoprueba: _claim_merge %', j; end if;
  raise notice 'premios irrepetibles y progreso: listo';
end;
$do$;
