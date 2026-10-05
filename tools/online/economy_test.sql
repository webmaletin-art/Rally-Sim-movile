-- Prueba de la economía online autoritativa. Se corre contra una base con las migraciones aplicadas (ver docs/ECONOMIA_ONLINE.md):
--   psql -v ON_ERROR_STOP=1 -q -d <base> -f tools/online/economy_test.sql
-- Necesita los roles anon/authenticated y auth.uid() (los mismos que da Supabase). Cada comprobación que falla corta con «FALLA …».
create schema if not exists tt;
grant usage on schema tt to authenticated;

create or replace function tt.expect_err(p_sql text, p_pat text, p_msg text) returns void language plpgsql as $$
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
create or replace function tt.ok(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if not p_cond then raise exception 'FALLA %', p_msg; end if;
  raise notice 'OK   %', p_msg;
end;
$$;
-- lecturas «de la verdad» (la prueba corre como un jugador, que no puede leer las tablas)
create or replace function tt.credits(p_uid uuid) returns bigint language sql security definer as $$ select credits from public.online_wallets where player_id = p_uid $$;
create or replace function tt.vaccent(p_id text) returns text language sql security definer as $$ select paint ->> 'accent' from public.online_cat_vehicles where id = p_id $$;
create or replace function tt.vprice(p_id text) returns int language sql security definer as $$ select price from public.online_cat_vehicles where id = p_id $$;
create or replace function tt.uprice(p_cat text, p_lvl int) returns int language sql security definer as $$ select price from public.online_cat_upgrades where category = p_cat and level = p_lvl $$;
create or replace function tt.tprice(p_id text) returns int language sql security definer as $$ select price from public.online_cat_tires where id = p_id $$;
create or replace function tt.pprice(p_id text) returns int language sql security definer as $$ select price from public.online_cat_parts where id = p_id $$;
create or replace function tt.total_credits() returns bigint language sql security definer as $$ select coalesce(sum(credits), 0) from public.online_wallets $$;
create or replace function tt.vehicle_owner(p_id uuid) returns uuid language sql security definer as $$ select owner from public.online_vehicles where id = p_id $$;
create or replace function tt.rim_for(p_vehicle text) returns text language sql security definer as $$ select id from public.online_cat_parts where category = 'wheel' and p_vehicle = any (vehicles) order by price limit 1 $$;
create or replace function tt.rim_not_for(p_vehicle text) returns text language sql security definer as $$ select id from public.online_cat_parts where not (p_vehicle = any (vehicles)) limit 1 $$;
create or replace function tt.shop_pos(p_shop text) returns real[] language sql security definer as $$ select array[x, z] from public.online_cat_shops where id = p_shop $$;
create or replace function tt.set_user(p_n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', case p_n when 1 then '00000000-0000-0000-0000-0000000000b1' else '00000000-0000-0000-0000-0000000000b2' end, false);
end;
$$;
-- mover al jugador actual a un local (presencia real)
create or replace function tt.go(p_shop text, p_name text) returns void language plpgsql as $$
declare p real[] := tt.shop_pos(p_shop);
begin
  perform public.presence_beat((p[1] + 3)::real, (p[2] + 3)::real, 0::real, ''::text, p_name, null::uuid);
end;
$$;
grant execute on all functions in schema tt to authenticated;
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000b1', 'a@t'), ('00000000-0000-0000-0000-0000000000b2', 'b@t') on conflict do nothing;

set role authenticated;
select tt.set_user(1);

-- ───────── estado inicial ─────────
do $$
declare s jsonb;
begin
  s := public.online_state('Alfa');
  perform tt.ok((s ->> 'credits')::bigint = 25000 and jsonb_array_length(s -> 'vehicles') = 1, 'jugador nuevo: $25000 y un auto de partida');
  perform tt.ok(s -> 'vehicles' -> 0 ->> 'vehicle' = 'pickup', 'el auto de partida es la pick-up');
  perform tt.ok((public.online_state() ->> 'credits')::bigint = 25000 and jsonb_array_length(public.online_state() -> 'vehicles') = 1, 'pedir el estado de nuevo no regala otro auto ni dinero');
end $$;

-- (para las pruebas de talleres se le da saldo al jugador A directo en la base, como lo haría un administrador)
reset role;
update public.online_wallets set credits = 600000 where player_id = '00000000-0000-0000-0000-0000000000b1';
set role authenticated;
select tt.set_user(1);

-- ───────── nadie escribe ni lee las tablas directo ─────────
select tt.expect_err($$update public.online_wallets set credits = 99999999$$, 'permission denied', 'subirse el saldo editando la tabla');
select tt.expect_err($$select * from public.online_vehicles$$, 'permission denied', 'leer los autos de todos directo de la tabla');
select tt.expect_err($$insert into public.online_vehicles (owner, vehicle_id) values ('00000000-0000-0000-0000-0000000000b1', 'hyper')$$, 'permission denied', 'crearse un auto directo en la tabla');
select tt.expect_err($$select public._online_spend('00000000-0000-0000-0000-0000000000b1', 1)$$, 'permission denied', 'llamar a la función interna que descuenta dinero');
select tt.expect_err($$select public.market_list('hyper', '{"truco": true}'::jsonb, 1, 'x')$$, 'permission denied', 'la venta vieja con estado arbitrario está cerrada');
select tt.expect_err($$select public.market_collect()$$, 'permission denied', 'cobrar «créditos de venta» al estilo viejo está cerrado');
select tt.expect_err($$select public.market_buy(1)$$, 'permission denied', 'la compra vieja del mercado está cerrada');

-- ───────── concesionario ─────────
select tt.expect_err($$select public.online_buy_vehicle('hatch', 'dealer')$$, 'no estás en el local', 'comprar un auto sin estar en el concesionario');
select tt.go('dealer', 'Alfa');
select tt.expect_err($$select public.online_buy_vehicle('hatch', 'wheels')$$, 'no se hace en ese local', 'comprar un auto diciendo que es en el taller de ruedas');
select tt.expect_err($$select public.online_buy_vehicle('nada', 'dealer')$$, 'no existe', 'comprar un auto que no existe');
reset role;
update public.online_wallets set credits = 5 where player_id = '00000000-0000-0000-0000-0000000000b1';
set role authenticated;
select tt.set_user(1);
select tt.expect_err($$select public.online_buy_vehicle('gt', 'dealer')$$, 'no te alcanza', 'comprar sin saldo suficiente');
select tt.expect_err($$select public.online_buy_vehicle('hyper', 'dealer')$$, 'no se compra con cr', 'los autos premium y de premio no se compran con créditos online');
reset role;
update public.online_wallets set credits = 600000 where player_id = '00000000-0000-0000-0000-0000000000b1';
set role authenticated;
select tt.set_user(1);
do $$
declare c0 bigint := tt.credits('00000000-0000-0000-0000-0000000000b1'); r jsonb;
begin
  r := public.online_buy_vehicle('hatch', 'dealer');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = tt.vprice('hatch'), 'comprar un auto descuenta exactamente su precio del catálogo');
  perform tt.ok((r -> 'vehicle' ->> 'vehicle') = 'hatch' and (r ->> 'credits')::bigint = tt.credits('00000000-0000-0000-0000-0000000000b1'), 'el servidor devuelve el auto nuevo y el saldo real');
end $$;

-- ───────── talleres: mejoras ─────────
do $$
declare v text := (public.online_state() -> 'vehicles' -> 1 ->> 'instance'); c0 bigint;
begin
  perform set_config('tt.hatch', v, false);
  perform tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 2, 'engine')$q$, v), 'no estás en el local', 'mejorar el motor sin estar en el taller (y saltando el nivel 1)');
  perform tt.go('engine', 'Alfa');
  perform tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 2, 'engine')$q$, v), 'nivel anterior', 'saltarse un nivel de mejora');
  perform tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 1, 'paint')$q$, v), 'no se hace en ese local', 'comprar el motor diciendo que es el taller de pintura');
  perform tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 9, 'engine')$q$, v), 'no existe', 'mejora inexistente');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  perform public.online_buy_upgrade(v::uuid, 'engine', 1, 'engine');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = tt.uprice('engine', 1), 'la mejora de motor nivel 1 cuesta lo del catálogo');
  perform tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 1, 'engine')$q$, v), 'nivel anterior', 'comprar dos veces el mismo nivel');
end $$;

-- ───────── talleres: gomas y llantas y pintura ─────────
do $$
declare v uuid := current_setting('tt.hatch')::uuid; c0 bigint; r jsonb; rim text; bad text;
begin
  perform tt.go('wheels', 'Alfa');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_buy_tires(v, 'sport', 'wheels');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = tt.tprice('sport') and (r -> 'vehicle' ->> 'tires') = 'sport', 'comprar gomas deportivas descuenta su precio y las pone');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_buy_tires(v, 'street', 'wheels');
  perform tt.ok(c0 = tt.credits('00000000-0000-0000-0000-0000000000b1'), 'volver a poner unas gomas que ya tenés es gratis');
  perform tt.expect_err(format($q$select public.online_buy_tires(%L, 'goma_trucha', 'wheels')$q$, v), 'no existen', 'gomas inexistentes');
  rim := tt.rim_for('hatch');
  bad := tt.rim_not_for('hatch');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_buy_part(v, rim, 'wheels');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = tt.pprice(rim) and (r -> 'vehicle' -> 'mods' -> 'wheel' ->> 'id') = rim, 'comprar una llanta compatible: se paga y queda puesta');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_buy_part(v, rim, 'wheels');
  perform tt.ok(c0 = tt.credits('00000000-0000-0000-0000-0000000000b1'), 'volver a ponerse una llanta ya comprada es gratis');
  if bad is not null then
    perform tt.expect_err(format($q$select public.online_buy_part(%L, %L, 'wheels')$q$, v, bad), 'no entra en este auto', 'pieza que no es compatible con ese auto');
  end if;
  perform tt.expect_err(format($q$select public.online_buy_part(%L, 'pieza_trucha', 'wheels')$q$, v), 'no existe', 'pieza inexistente');
  -- cambiar gomas gastadas
  perform public.online_report_drive(v, 3::real, 120::real, 2::real);
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_replace_tires(v, 'wheels');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = (r ->> 'cost')::int and (r ->> 'cost')::int >= 250 and (r -> 'vehicle' -> 'tireWear' ->> 'street')::numeric = 0, 'cambiar las gomas cuesta (mínimo $250) y las deja nuevas');
end $$;

do $$
declare v uuid := current_setting('tt.hatch')::uuid; c0 bigint; r jsonb;
begin
  perform tt.go('paint', 'Alfa');
  perform tt.expect_err(format($q$select public.online_set_paint(%L, '{"body":"rojo"}'::jsonb, 'paint')$q$, v), 'color inválido', 'pintar con un color que no es hexadecimal');
  perform tt.expect_err(format($q$select public.online_set_paint(%L, '{"credits":99999}'::jsonb, 'paint')$q$, v), 'desconocido', 'meter un campo extraño en la pintura');
  perform tt.expect_err(format($q$select public.online_set_paint(%L, '{"finish":"oro_liquido"}'::jsonb, 'paint')$q$, v), 'acabado inválido', 'acabado fuera del catálogo');
  perform tt.expect_err(format($q$select public.online_set_paint(%L, '{"body":"#112233"}'::jsonb, 'wheels')$q$, v), 'no se hace en ese local', 'pintar en el taller equivocado');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  r := public.online_set_paint(v, '{"body":"#1A4FE0","finish":"metal"}'::jsonb, 'paint');
  perform tt.ok(c0 - tt.credits('00000000-0000-0000-0000-0000000000b1') = 300 and (r -> 'vehicle' -> 'paint' ->> 'body') = '#1a4fe0' and (r -> 'vehicle' -> 'paint' ->> 'accent') = tt.vaccent(r -> 'vehicle' ->> 'vehicle'), 'repintar cuesta $300 y conserva lo que no cambió');
  c0 := tt.credits('00000000-0000-0000-0000-0000000000b1');
  perform public.online_set_paint(v, '{"body":"#1a4fe0"}'::jsonb, 'paint');
  perform tt.ok(c0 = tt.credits('00000000-0000-0000-0000-0000000000b1'), 'pintar del mismo color no cobra');
end $$;

-- ───────── desgaste: lo calcula el servidor y no se puede inventar ─────────
do $$
declare v uuid := current_setting('tt.hatch')::uuid; r jsonb;
begin
  r := public.online_report_drive(v, 500::real, 10::real, 4::real);  -- 500 km en 10 s: imposible
  perform tt.ok((r -> 'vehicle' ->> 'km')::numeric < 10, 'un reporte de 500 km en 10 s se recorta a lo posible (km = ' || (r -> 'vehicle' ->> 'km') || ')');
  r := public.online_report_drive(v, 0::real, 0::real, 1::real);
  perform tt.ok((r -> 'vehicle' -> 'tireWear' ->> 'street')::numeric < 0.2, 'el desgaste de un reporte exagerado sigue acotado');
end $$;

-- ───────── otro jugador no toca mis autos ─────────
select tt.set_user(2);
select public.online_state('Beta');
select tt.go('engine', 'Beta');
select tt.expect_err(format($q$select public.online_buy_upgrade(%L, 'engine', 1, 'engine')$q$, current_setting('tt.hatch')), 'no es tuyo', 'mejorar el auto de otro jugador');
select tt.expect_err(format($q$select public.online_set_paint(%L, '{"body":"#000000"}'::jsonb, 'paint')$q$, current_setting('tt.hatch')), 'no es tuyo', 'repintar el auto de otro jugador');
select tt.expect_err(format($q$select public.market_list_instance(%L, 100, 'Beta')$q$, current_setting('tt.hatch')), 'no es tuyo', 'poner en venta el auto de otro jugador');
select tt.expect_err(format($q$select public.online_report_drive(%L, 1::real, 10::real, 1::real)$q$, current_setting('tt.hatch')), 'no es tuyo', 'reportar manejo con el auto de otro');

-- ───────── presencia con el auto real (Etapa 18) ─────────
do $$
declare l record; n int := 0;
begin
  perform public.presence_beat(10::real, 10::real, 20::real, 'cualquiera'::text, 'Beta'::text, current_setting('tt.hatch')::uuid); -- intenta hacerse pasar por el hatch de A
  for l in select * from public.presence_list_v(50) loop
    if l.name = 'Beta' then perform tt.ok(l.vehicle is null and l.car = 'cualquiera', 'un auto ajeno en la presencia no se muestra como mío'); n := n + 1; end if;
  end loop;
  perform tt.ok(n = 1, 'Beta aparece en la lista');
end $$;
select tt.set_user(1);
select public.presence_beat(30::real, 30::real, 40::real, 'lo-que-diga'::text, 'Alfa'::text, current_setting('tt.hatch')::uuid) as _;
do $$
declare l record; seen boolean := false;
begin
  for l in select * from public.presence_list_v(50) loop
    if l.name = 'Alfa' then
      seen := true;
      perform tt.ok(l.car = 'hatch' and (l.vehicle ->> 'vehicle') = 'hatch' and (l.vehicle -> 'paint' ->> 'body') = '#1a4fe0' and (l.vehicle -> 'mods' -> 'wheel') is not null,
        'los demás ven el modelo, la pintura y las llantas que el SERVIDOR sabe (no el nombre que mandó el teléfono)');
    end if;
  end loop;
  perform tt.ok(seen, 'Alfa aparece con su auto');
end $$;

-- ───────── mercado: traspaso hecho por el servidor ─────────
do $$
declare v uuid := current_setting('tt.hatch')::uuid; r jsonb; a0 bigint; b0 bigint; tot0 bigint; lid bigint; price int := 8000;
begin
  perform tt.expect_err($q$select public.market_list_instance('00000000-0000-0000-0000-000000000000', 1000, 'Alfa')$q$, 'no es tuyo', 'vender un auto inexistente');
  perform tt.expect_err(format($q$select public.market_list_instance(%L, 5, 'Alfa')$q$, v), 'precio inválido', 'precio ridículo');
  r := public.market_list_instance(v, price, 'Alfa');
  lid := (r ->> 'id')::bigint;
  perform tt.ok((r ->> 'ok')::boolean, 'poner un auto en venta');
  perform tt.expect_err(format($q$select public.online_set_paint(%L, '{"body":"#ffffff"}'::jsonb, 'paint')$q$, v), 'en venta', 'modificar un auto mientras está en venta');
  perform set_config('tt.lid', lid::text, false);
  perform set_config('tt.a0', tt.credits('00000000-0000-0000-0000-0000000000b1')::text, false);
  perform set_config('tt.tot0', tt.total_credits()::text, false);
  r := public.market_buy_instance(lid);
  perform tt.ok(not (r ->> 'ok')::boolean, 'no podés comprarte tu propio auto');
end $$;
select tt.set_user(2);
do $$
declare lid bigint := current_setting('tt.lid')::bigint; r jsonb; b0 bigint := tt.credits('00000000-0000-0000-0000-0000000000b2'); a0 bigint := current_setting('tt.a0')::bigint;
begin
  r := public.market_buy_instance(lid);
  perform tt.ok((r ->> 'ok')::boolean and b0 - tt.credits('00000000-0000-0000-0000-0000000000b2') = 8000, 'comprar un auto del mercado descuenta el precio al comprador');
  perform tt.ok(tt.credits('00000000-0000-0000-0000-0000000000b1') - a0 = 8000 - 400, 'el vendedor cobra el precio menos 5 % de comisión, acreditado por el servidor en el momento');
  perform tt.ok(tt.total_credits() = current_setting('tt.tot0')::bigint - 400, 'no se crea dinero: el total sólo baja por la comisión');
  perform tt.ok(tt.vehicle_owner((r -> 'vehicle' ->> 'instance')::uuid) = '00000000-0000-0000-0000-0000000000b2', 'el auto pasó a nombre del comprador');
  r := public.market_buy_instance(lid);
  perform tt.ok(not (r ->> 'ok')::boolean, 'no se puede comprar dos veces la misma venta');
end $$;

-- ───────── regalo diario ─────────
do $$
declare r jsonb;
begin
  r := public.online_daily();
  perform tt.ok((r ->> 'ok')::boolean, 'el regalo diario se cobra una vez');
  r := public.online_daily();
  perform tt.ok(not (r ->> 'ok')::boolean, 'el mismo día no se cobra dos veces');
end $$;

-- ───────── límite de acciones por hora ─────────
select tt.set_user(1);
select tt.go('wheels', 'Alfa');
do $$
declare i int; got boolean := false; v uuid := (public.online_state() -> 'vehicles' -> 0 ->> 'instance')::uuid;
begin
  for i in 1..140 loop
    begin
      perform public.online_buy_tires(v, 'street', 'wheels'); -- acción válida y gratis (poner gomas que ya tiene)
    exception when others then
      if sqlerrm ilike '%demasiadas acciones%' then got := true; exit; end if;
      raise;
    end;
  end loop;
  perform tt.ok(got, 'después de muchas acciones seguidas el servidor frena el abuso');
end $$;

reset role;
select 'ECONOMIA_ONLINE_TEST OK' as resultado;
