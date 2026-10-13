-- Prueba de la economía de la CUENTA (créditos y autos del juego «sin conexión» que viven en el servidor): supabase/migrations/20261014000000_account_economy.sql.
-- Se corre contra una base con TODAS las migraciones aplicadas (tools/online/run_economy_test.sh la llama después de la prueba de la economía online):
--   psql -v ON_ERROR_STOP=1 -q -d <base> -f tools/online/account_test.sql
-- Cada comprobación que falla corta con «FALLA …».
create schema if not exists ta;
grant usage on schema ta to authenticated, service_role;
create sequence if not exists ta.seq;
grant usage on sequence ta.seq to authenticated, service_role;

create or replace function ta.expect_err(p_sql text, p_pat text, p_msg text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm ilike '%' || p_pat || '%' then
      raise notice 'OK   % (rechazado: %)', p_msg, sqlerrm;
      return;
    end if;
    raise exception 'FALLA % (error distinto: %)', p_msg, sqlerrm;
  end;
  raise exception 'FALLA % (no dio error)', p_msg;
end;
$$;
create or replace function ta.ok(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if not p_cond then raise exception 'FALLA %', p_msg; end if;
  raise notice 'OK   %', p_msg;
end;
$$;
-- un evento suelto: devuelve {ok, reason, credits, …}; si no trae id se le pone uno nuevo
create or replace function ta.one(p_ev jsonb) returns jsonb language plpgsql as $$
declare ev jsonb := p_ev; r jsonb;
begin
  if not (ev ? 'id') then ev := ev || jsonb_build_object('id', 'ta' || nextval('ta.seq')); end if;
  r := public.account_apply(jsonb_build_array(ev));
  return (r -> 'results' -> 0) || jsonb_build_object('credits', (r ->> 'credits')::bigint, 'cars', r -> 'cars', 'iap', r -> 'iap');
end;
$$;
create or replace function ta.st() returns jsonb language sql as $$ select public.account_state() $$;
create or replace function ta.set_user(p_n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', case p_n when 1 then '00000000-0000-0000-0000-0000000000a1' else '00000000-0000-0000-0000-0000000000a2' end, false);
  perform set_config('request.jwt.claims', '{}', false);
end;
$$;
create or replace function ta.credits_of(p_uid uuid) returns bigint language sql security definer as $$ select credits from public.account_econ where user_id = p_uid $$;
create or replace function ta.price_v(p_id text) returns int language sql security definer as $$ select price from public.online_cat_vehicles where id = p_id $$;
create or replace function ta.price_u(p_cat text, p_lvl int) returns int language sql security definer as $$ select price from public.online_cat_upgrades where category = p_cat and level = p_lvl $$;
create or replace function ta.price_t(p_id text) returns int language sql security definer as $$ select price from public.online_cat_tires where id = p_id $$;
create or replace function ta.price_p(p_id text) returns int language sql security definer as $$ select price from public.online_cat_parts where id = p_id $$;
create or replace function ta.part_for(p_vehicle text) returns text language sql security definer as $$ select id from public.online_cat_parts where p_vehicle = any (vehicles) order by price limit 1 $$;
create or replace function ta.part_not_for(p_vehicle text) returns text language sql security definer as $$ select id from public.online_cat_parts where cardinality(vehicles) > 0 and not (p_vehicle = any (vehicles)) limit 1 $$;
grant execute on all functions in schema ta to authenticated, service_role;

reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'a@t'), ('00000000-0000-0000-0000-0000000000a2', 'b@t') on conflict do nothing;
delete from public.account_econ where user_id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
delete from public.account_earns where user_id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
delete from public.account_seen where user_id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
delete from public.account_iap_tokens where user_id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');
set role authenticated;
select ta.set_user(1);

-- ───────── estado inicial ─────────
do $$
declare s jsonb;
begin
  s := public.account_state();
  perform ta.ok((s ->> 'credits')::bigint = 5000 and s -> 'cars' = '{}'::jsonb and (s ->> 'daily') = '', 'cuenta nueva: $5000, sin autos, sin regalo diario cobrado');
  perform ta.ok(public.account_state() = (s || jsonb_build_object('now', (public.account_state() ->> 'now')::bigint)), 'pedir el estado de nuevo no regala nada');
end $$;

-- ───────── nadie toca las tablas directo ─────────
select ta.expect_err($$select * from public.account_econ$$, 'permission denied', 'leer las cuentas directo de la tabla');
select ta.expect_err($$update public.account_econ set credits = 99999999$$, 'permission denied', 'subirse el saldo editando la tabla');
select ta.expect_err($$insert into public.account_econ (user_id, credits) values ('00000000-0000-0000-0000-0000000000a1', 1)$$, 'permission denied', 'crear la cuenta a mano');
select ta.expect_err($$select * from public.account_cfg$$, 'permission denied', 'leer la configuración de topes');
select ta.expect_err($$select * from public.account_earns$$, 'permission denied', 'leer el registro de premios');
select ta.expect_err($$select public._acct_one('00000000-0000-0000-0000-0000000000a1', '{"t":"earn","amount":5}')$$, 'permission denied', 'llamar a la función interna que aplica un evento');
select ta.expect_err($$select public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_coins_xl', 'aaaaaaaaaaaaaaaaaaaaaaaa')$$, 'permission denied', 'acreditarse una compra sin pasar por el servidor');
select ta.expect_err($$select public.account_admin_grant('a@t', 1000000, array['hyper'])$$, 'permission denied', 'regalarse créditos y autos con la función del dueño');

-- ───────── anónimos y sin sesión ─────────
select set_config('request.jwt.claims', '{"is_anonymous": true}', false);
select ta.expect_err($$select public.account_state()$$, 'cuenta con correo', 'una sesión anónima no tiene cuenta');
select ta.expect_err($$select public.account_apply('[]'::jsonb)$$, 'cuenta con correo', 'una sesión anónima no manda eventos');
select ta.set_user(1);
select set_config('request.jwt.claim.sub', '', false);
select ta.expect_err($$select public.account_state()$$, 'sin sesión', 'sin sesión no hay estado');
select ta.set_user(1);

-- ───────── auto de partida ─────────
do $$
declare r jsonb; ev jsonb := '{"id":"start1","t":"give_car","car":"hatch","why":"starter"}';
begin
  r := ta.one(ev);
  perform ta.ok((r ->> 'ok')::boolean and r -> 'cars' ? 'hatch' and r -> 'cars' -> 'hatch' -> 'tires' = '["street"]'::jsonb, 'el auto de partida (R2 Turbo) se entrega y viene con las gomas de calle');
  r := ta.one(ev);
  perform ta.ok((r ->> 'dup')::boolean is true and (r ->> 'credits')::bigint = 5000, 'repetir el mismo evento no hace nada (id repetido)');
  r := ta.one('{"t":"give_car","car":"hatch","why":"starter"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'dup')::boolean is true, 'pedir el mismo auto de partida con otro id tampoco lo duplica');
  r := ta.one('{"t":"give_car","car":"gt","why":"starter"}');
  perform ta.ok(not (r ->> 'ok')::boolean and not (r -> 'cars' ? 'gt'), 'no se puede pedir como «de partida» otro auto: ' || (r ->> 'reason'));
  r := ta.one('{"t":"give_car","car":"hyper","why":"iap"}');
  perform ta.ok(not (r ->> 'ok')::boolean and not (r -> 'cars' ? 'hyper'), 'el hypercar premium no se regala sin la compra: ' || (r ->> 'reason'));
  r := ta.one('{"t":"give_car","car":"genesis","why":"adventure"}');
  perform ta.ok((r ->> 'ok')::boolean and r -> 'cars' ? 'genesis', 'el auto de premio de la aventura se entrega (el servidor no sabe si la terminó: lo limita la aventura del juego)');
  r := ta.one('{"t":"give_car","car":"gt","why":"adventure"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'un auto común no se puede pedir como premio de la aventura');
  r := ta.one('{"t":"give_car","car":"nada","why":"starter"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'un auto que no existe tampoco');
end $$;

-- ───────── premios ─────────
do $$
declare r jsonb; c0 bigint;
begin
  r := ta.one('{"t":"earn","amount":1500,"kind":"race","ref":"debut_1"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 6500, 'cobrar un premio de carrera suma al saldo del servidor');
  r := ta.one('{"t":"earn","amount":1500,"kind":"race","ref":"debut_1"}');
  perform ta.ok(not (r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 6500, 'el mismo premio no se cobra dos veces seguidas: ' || (r ->> 'reason'));
  r := ta.one('{"t":"earn","amount":1500,"kind":"race","ref":"debut_2"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 8000, 'otra carrera distinta sí cobra');
  r := ta.one('{"t":"earn","amount":1000000000,"kind":"race","ref":"truco"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'granted')::bigint = 60000 and (r ->> 'clamped')::boolean, 'un premio gigante se recorta al tope de un solo premio (60000)');
  r := ta.one('{"t":"earn","amount":-500,"kind":"race","ref":"neg"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'un premio negativo se rechaza: ' || (r ->> 'reason'));
  r := ta.one('{"t":"earn","amount":0,"kind":"race","ref":"cero"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'un premio de cero se rechaza');
  -- tope por hora: 300000
  for i in 1..5 loop
    r := ta.one(jsonb_build_object('t', 'earn', 'amount', 60000, 'kind', 'act', 'ref', 'hora' || i));
  end loop;
  c0 := (r ->> 'credits')::bigint;
  perform ta.ok((r ->> 'credits')::bigint <= 5000 + 1500 + 1500 + 60000 + 300000, 'después de varios premios seguidos el saldo no pasa del tope por hora');
  r := ta.one('{"t":"earn","amount":60000,"kind":"act","ref":"hora_extra"}');
  perform ta.ok(not (r ->> 'ok')::boolean and (r ->> 'credits')::bigint = c0, 'llegado al tope por hora ya no acredita más: ' || (r ->> 'reason'));
end $$;

-- ───────── tope por día (se vuelve atrás el reloj de los premios de hoy) ─────────
reset role;
update public.account_earns set at = now() - interval '3 hours' where user_id = '00000000-0000-0000-0000-0000000000a1';
insert into public.account_earns (user_id, kind, ref, amount, at) values ('00000000-0000-0000-0000-0000000000a1', 'x', 'viejo', 700000, now() - interval '5 hours');
set role authenticated;
select ta.set_user(1);
do $$
declare r jsonb; used bigint;
begin
  reset role;
  select coalesce(sum(amount), 0) into used from public.account_earns where user_id = '00000000-0000-0000-0000-0000000000a1' and at > now() - interval '24 hours';
  set role authenticated;
  r := ta.one('{"t":"earn","amount":60000,"kind":"act","ref":"dia1"}');
  perform ta.ok((r ->> 'ok')::boolean, 'pasada una hora vuelve a cobrar (ya hay ' || used || ' en el día)');
  for i in 1..8 loop
    r := ta.one(jsonb_build_object('t', 'earn', 'amount', 60000, 'kind', 'act', 'ref', 'dia_' || i));
  end loop;
  reset role;
  select coalesce(sum(amount), 0) into used from public.account_earns where user_id = '00000000-0000-0000-0000-0000000000a1' and at > now() - interval '24 hours';
  set role authenticated;
  perform ta.ok(used <= 1200000, 'en un día no se acredita más de 1.200.000 (acreditado: ' || used || ')');
end $$;

-- (se le da saldo al jugador como lo haría un administrador, para probar las compras)
reset role;
update public.account_econ set credits = 500000 where user_id = '00000000-0000-0000-0000-0000000000a1';
delete from public.account_earns where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select ta.set_user(1);

-- ───────── gastos sueltos ─────────
do $$
declare r jsonb;
begin
  r := ta.one('{"t":"spend","amount":120,"kind":"fuel"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 499880, 'un gasto suelto (nafta) descuenta');
  r := ta.one('{"t":"spend","amount":99999999,"kind":"fuel"}');
  perform ta.ok(not (r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 499880, 'un gasto enorme se rechaza: ' || (r ->> 'reason'));
  r := ta.one('{"t":"spend","amount":-100,"kind":"fuel"}');
  perform ta.ok(not (r ->> 'ok')::boolean and (r ->> 'credits')::bigint = 499880, 'un gasto negativo no regala plata');
end $$;

-- ───────── autos ─────────
do $$
declare r jsonb; c0 bigint := (public.account_state() ->> 'credits')::bigint;
begin
  r := ta.one('{"t":"buy_car","car":"torito"}');
  perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = ta.price_v('torito') and r -> 'cars' ? 'torito', 'comprar un auto descuenta exactamente el precio del catálogo del servidor');
  r := ta.one('{"t":"buy_car","car":"torito"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'comprar dos veces el mismo auto se rechaza: ' || (r ->> 'reason'));
  r := ta.one('{"t":"buy_car","car":"hyper"}');
  perform ta.ok(not (r ->> 'ok')::boolean and not (r -> 'cars' ? 'hyper'), 'el hypercar premium no se compra con créditos: ' || (r ->> 'reason'));
  r := ta.one('{"t":"buy_car","car":"truck"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'el camión premium tampoco');
  r := ta.one('{"t":"buy_car","car":"gt3"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'el GT3 premium tampoco');
  r := ta.one('{"t":"buy_car","car":"nada"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'un auto que no existe');
  r := ta.one('{"t":"buy_car","car":"veltor_gtr"}');  -- 225000
  perform ta.ok((r ->> 'ok')::boolean, 'un auto caro se compra si alcanza el saldo');
  reset role;
  update public.account_econ set credits = 1000 where user_id = '00000000-0000-0000-0000-0000000000a1';
  set role authenticated;
  r := ta.one('{"t":"buy_car","car":"moust"}');  -- 205000: con $1000 no alcanza
  perform ta.ok(not (r ->> 'ok')::boolean and not (r -> 'cars' ? 'moust'), 'sin saldo suficiente no se compra: ' || (r ->> 'reason'));
end $$;

reset role;
update public.account_econ set credits = 500000 where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select ta.set_user(1);

-- ───────── mejoras, gomas, piezas ─────────
do $$
declare r jsonb; c0 bigint; part text; bad text;
begin
  c0 := (public.account_state() ->> 'credits')::bigint;
  r := ta.one('{"t":"buy_upgrade","car":"hatch","cat":"engine","level":1}');
  perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = ta.price_u('engine', 1) and r -> 'cars' -> 'hatch' -> 'owned' ? 'engine:1', 'la mejora de motor 1 cuesta lo del catálogo y queda anotada');
  c0 := (public.account_state() ->> 'credits')::bigint;
  r := ta.one('{"t":"buy_upgrade","car":"hatch","cat":"engine","level":1}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'dup')::boolean and c0 = (r ->> 'credits')::bigint, 'comprar la misma mejora otra vez no cobra de nuevo');
  r := ta.one('{"t":"buy_upgrade","car":"hatch","cat":"engine","level":99}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'una mejora que no existe');
  r := ta.one('{"t":"buy_upgrade","car":"gt","cat":"engine","level":1}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'mejorar un auto que no es tuyo: ' || (r ->> 'reason'));
  -- gomas
  c0 := (public.account_state() ->> 'credits')::bigint;
  r := ta.one('{"t":"buy_tires","car":"hatch","tire":"sport"}');
  perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = ta.price_t('sport') and r -> 'cars' -> 'hatch' -> 'tires' ? 'sport', 'comprar gomas deportivas descuenta su precio');
  r := ta.one('{"t":"buy_tires","car":"hatch","tire":"sport"}');
  perform ta.ok((r ->> 'dup')::boolean, 'las mismas gomas dos veces: no cobra');
  r := ta.one('{"t":"buy_tires","car":"hatch","tire":"goma_trucha"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'gomas que no existen');
  -- piezas
  part := ta.part_for('hatch');
  bad := ta.part_not_for('hatch');
  if part is not null then
    c0 := (public.account_state() ->> 'credits')::bigint;
    r := ta.one(jsonb_build_object('t', 'buy_part', 'car', 'hatch', 'part', part));
    perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = ta.price_p(part), 'comprar una pieza compatible descuenta su precio (' || part || ')');
    r := ta.one(jsonb_build_object('t', 'buy_part', 'car', 'hatch', 'part', part));
    perform ta.ok((r ->> 'dup')::boolean, 'la misma pieza dos veces: no cobra');
  end if;
  if bad is not null then
    r := ta.one(jsonb_build_object('t', 'buy_part', 'car', 'hatch', 'part', bad));
    perform ta.ok(not (r ->> 'ok')::boolean, 'una pieza que no es de ese auto se rechaza: ' || (r ->> 'reason'));
  end if;
  r := ta.one('{"t":"buy_part","car":"hatch","part":"pieza_trucha"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'una pieza que no existe');
  -- cambiar las gomas puestas: la mitad de su precio, mínimo $250, con hasta 20 % de descuento por el rango
  c0 := (public.account_state() ->> 'credits')::bigint;
  r := ta.one('{"t":"replace_tires","car":"hatch","tire":"street","cost":250}');
  perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = 250, 'cambiar las gomas de calle cuesta $250 (el mínimo)');
  r := ta.one('{"t":"replace_tires","car":"hatch","tire":"street","cost":10}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'cambiar las gomas por $10 se rechaza: ' || (r ->> 'reason'));
  r := ta.one('{"t":"replace_tires","car":"hatch","tire":"street","cost":900}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'cobrarse de más tampoco');
  c0 := (public.account_state() ->> 'credits')::bigint;
  r := ta.one('{"t":"replace_tires","car":"hatch","tire":"sport","cost":1000}');
  perform ta.ok((r ->> 'ok')::boolean and c0 - (r ->> 'credits')::bigint = 1000, 'las gomas deportivas (2500): la mitad redondeada a 50 es $1250; con 20 % de descuento llega a $1000');
  r := ta.one('{"t":"replace_tires","car":"hatch","tire":"sport","cost":900}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'más de 20 % de descuento no existe');
  r := ta.one('{"t":"replace_tires","car":"gt","tire":"street","cost":250}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'cambiar las gomas de un auto que no es tuyo');
end $$;

-- ───────── regalo diario ─────────
do $$
declare r jsonb; c0 bigint := (public.account_state() ->> 'credits')::bigint; s jsonb;
begin
  r := ta.one('{"t":"daily"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'amount')::int = 450 and (r ->> 'streak')::int = 1 and (r ->> 'credits')::bigint = c0 + 450, 'regalo diario: $450 el primer día (300 + 150 × racha 1)');
  r := ta.one('{"t":"daily"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'el mismo día no se cobra de nuevo: ' || (r ->> 'reason'));
  s := public.account_state();
  perform ta.ok((s ->> 'daily') = to_char((now() at time zone 'utc')::date, 'YYYY-MM-DD'), 'el estado dice qué día se cobró');
end $$;
reset role;
update public.account_econ set last_daily = (now() at time zone 'utc')::date - 1, streak = 3 where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select ta.set_user(1);
do $$
declare r jsonb;
begin
  r := ta.one('{"t":"daily"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'streak')::int = 4 and (r ->> 'amount')::int = 900, 'al día siguiente la racha sigue: 4 días = $900');
end $$;
reset role;
update public.account_econ set last_daily = (now() at time zone 'utc')::date - 3, streak = 6 where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select ta.set_user(1);
do $$
declare r jsonb;
begin
  r := ta.one('{"t":"daily"}');
  perform ta.ok((r ->> 'ok')::boolean and (r ->> 'streak')::int = 1 and (r ->> 'amount')::int = 450, 'si faltó un día la racha vuelve a 1');
end $$;

-- ───────── tandas ─────────
do $$
declare r jsonb; evs jsonb := '[]'::jsonb;
begin
  r := public.account_apply('[{"t":"earn","amount":5}, {"id":"b2","t":"spend","amount":10,"kind":"x"}]'::jsonb);
  perform ta.ok(not (r -> 'results' -> 0 ->> 'ok')::boolean and (r -> 'results' -> 1 ->> 'ok')::boolean, 'en una tanda un evento malo (sin id) no arrastra al bueno');
  for i in 1..61 loop evs := evs || jsonb_build_array(jsonb_build_object('id', 'm' || i, 't', 'spend', 'amount', 1, 'kind', 'x')); end loop;
  perform ta.expect_err(format($q$select public.account_apply(%L::jsonb)$q$, evs), 'demasiados eventos', 'una tanda de más de 60 eventos');
  perform ta.expect_err($q$select public.account_apply('{"a":1}'::jsonb)$q$, 'eventos inválidos', 'eventos que no son una lista');
  r := public.account_apply('[{"id":"x1","t":"hackear"}]'::jsonb);
  perform ta.ok(not (r -> 'results' -> 0 ->> 'ok')::boolean, 'un tipo de evento que no existe');
  r := public.account_apply('[]'::jsonb);
  perform ta.ok((r ->> 'credits')::bigint > 0 and r ? 'cars' and r ? 'iap' and r ? 'seq', 'una tanda vacía devuelve el estado del servidor');
end $$;

-- ───────── ritmo: tandas por hora ─────────
reset role;
update public.account_cfg set val = 3 where key = 'apply_hour';
update public.account_econ set rate_n = 0, rate_at = now() where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select ta.set_user(1);
select public.account_apply('[]'::jsonb) as _;
select public.account_apply('[]'::jsonb) as _;
select public.account_apply('[]'::jsonb) as _;
select ta.expect_err($$select public.account_apply('[]'::jsonb)$$, 'demasiadas acciones', 'más tandas por hora que el tope');
reset role;
update public.account_cfg set val = 600 where key = 'apply_hour';
set role authenticated;
select ta.set_user(1);
select public.account_apply('[]'::jsonb) as _;

-- ───────── compras de la tienda (sólo las puede acreditar el servidor con service_role) ─────────
reset role;
set role service_role;
do $$
declare r jsonb; c0 bigint;
begin
  c0 := ta.credits_of('00000000-0000-0000-0000-0000000000a1');
  r := public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_coins_m', 'hash-de-prueba-0001-aaaa');
  perform ta.ok((r ->> 'credits')::bigint = c0 + 12000 and (r ->> 'granted')::int = 12000, 'una compra de monedas verificada acredita el pack');
  r := public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_coins_m', 'hash-de-prueba-0001-aaaa');
  perform ta.ok((r ->> 'dup')::boolean and (r ->> 'credits')::bigint = c0 + 12000, 'el mismo recibo no acredita dos veces');
  r := public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'car_hyper', 'hash-de-prueba-0002-bbbb');
  perform ta.ok(r -> 'iap' ? 'car_hyper', 'una compra de auto desbloquea el producto');
  r := public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_garage', 'hash-de-prueba-0003-cccc');
  perform ta.ok(r -> 'iap' ? 'dr_garage', 'el paquete de garaje queda anotado');
  perform ta.expect_err($q$select public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_nada', 'hash-de-prueba-0004-dddd')$q$, 'producto desconocido', 'un producto que no existe');
  perform ta.expect_err($q$select public.account_iap_grant('00000000-0000-0000-0000-0000000000a1', 'dr_coins_s', 'corto')$q$, 'recibo inválido', 'un recibo vacío o corto');
  perform ta.expect_err($q$select public.account_iap_grant('00000000-0000-0000-0000-0000000000ff', 'dr_coins_s', 'hash-de-prueba-0005-eeee')$q$, 'usuario desconocido', 'un usuario que no existe');
end $$;
reset role;
set role authenticated;
select ta.set_user(1);
do $$
declare r jsonb;
begin
  r := ta.one('{"t":"give_car","car":"hyper","why":"iap"}');
  perform ta.ok((r ->> 'ok')::boolean and r -> 'cars' ? 'hyper', 'con la compra anotada, el hypercar se entrega');
  r := ta.one('{"t":"give_car","car":"truck","why":"iap"}');
  perform ta.ok((r ->> 'ok')::boolean and r -> 'cars' ? 'truck', 'con el paquete de garaje también el camión');
  r := ta.one('{"t":"give_car","car":"gt3","why":"iap"}');
  perform ta.ok((r ->> 'ok')::boolean and r -> 'cars' ? 'gt3', 'y el GT3');
end $$;

-- ───────── el dueño le regala a una cuenta (service_role) ─────────
reset role;
set role service_role;
do $$
declare r jsonb; c0 bigint := ta.credits_of('00000000-0000-0000-0000-0000000000a2');
begin
  r := public.account_admin_grant('B@T', 25000, array['gt', 'hyper']);
  perform ta.ok((r ->> 'credits')::bigint = c0 + 25000 and r -> 'cars' ? 'gt' and r -> 'cars' ? 'hyper', 'el dueño le regala créditos y autos (también premium) a una cuenta por su correo');
  r := public.account_admin_grant('b@t', -999999999, '{}');
  perform ta.ok((r ->> 'credits')::bigint = 0, 'y puede sacar créditos (nunca queda en negativo)');
  perform ta.expect_err($q$select public.account_admin_grant('nadie@t', 1, '{}')$q$, 'no hay una cuenta', 'un correo que no existe');
  perform ta.expect_err($q$select public.account_admin_grant('b@t', 1, array['auto_que_no_existe'])$q$, 'no existe', 'un auto que no existe');
end $$;
reset role;
update public.account_econ set credits = 5000, cars = '{}'::jsonb where user_id = '00000000-0000-0000-0000-0000000000a2';
set role authenticated;
select ta.set_user(2);

-- ───────── otro jugador: su cuenta es aparte ─────────
select ta.set_user(2);
do $$
declare s jsonb; r jsonb;
begin
  s := public.account_state();
  perform ta.ok((s ->> 'credits')::bigint = 5000 and s -> 'cars' = '{}'::jsonb and s -> 'iap' = '{}'::jsonb, 'otro jugador empieza de cero, sin los autos ni las compras del primero');
  r := ta.one('{"t":"buy_upgrade","car":"hatch","cat":"engine","level":1}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'no puede mejorar un auto que sólo tiene el otro: ' || (r ->> 'reason'));
  r := ta.one('{"t":"give_car","car":"hyper","why":"iap"}');
  perform ta.ok(not (r ->> 'ok')::boolean, 'no se lleva el hypercar de la compra del otro');
  r := ta.one('{"t":"give_car","car":"hatch","why":"starter"}');
  perform ta.ok((r ->> 'ok')::boolean, 'pero sí recibe su propio auto de partida');
end $$;
select ta.set_user(1);
do $$
declare s jsonb;
begin
  s := public.account_state();
  perform ta.ok(s -> 'cars' ? 'hatch' and s -> 'cars' ? 'torito' and (s ->> 'credits')::bigint > 5000, 'el primer jugador conserva lo suyo');
end $$;

-- ───────── borrar la cuenta: se va todo menos el código del comprobante (sin usuario) ─────────
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a3', 'c@t') on conflict do nothing;
set role service_role;
select public.account_iap_grant('00000000-0000-0000-0000-0000000000a3', 'dr_coins_s', 'hash-de-cuenta-borrada-0001') as _;
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a3';
do $$
declare n_econ int; n_tok int; n_uid int;
begin
  select count(*) into n_econ from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a3';
  select count(*) into n_tok from public.account_iap_tokens where token_hash = 'hash-de-cuenta-borrada-0001';
  select count(*) into n_uid from public.account_iap_tokens where token_hash = 'hash-de-cuenta-borrada-0001' and user_id is not null;
  perform ta.ok(n_econ = 0, 'al borrar la cuenta se borra su economía (créditos y autos)');
  perform ta.ok(n_tok = 1 and n_uid = 0, 'del comprobante queda sólo el código, sin usuario');
end $$;
set role service_role;
do $$
declare r jsonb;
begin
  r := public.account_iap_grant('00000000-0000-0000-0000-0000000000a2', 'dr_coins_s', 'hash-de-cuenta-borrada-0001');
  perform ta.ok((r ->> 'dup')::boolean, 'ese mismo comprobante no se puede usar en otra cuenta');
end $$;

reset role;
select 'CUENTA_TEST OK' as resultado;
