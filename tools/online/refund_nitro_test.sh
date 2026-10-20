#!/bin/bash
# Prueba de la migración 20261025120000_no_nitro_spoilers_price_tiers.sql con datos de verdad: arma una base con TODAS las migraciones anteriores, deja cuentas y autos que ya tenían el nitro y los
# alerones, aplica la migración (dos veces) y comprueba que se devolvió lo pagado, que se sacaron de los autos y que el catálogo quedó sin nitro, sin alerones y con precios por escalones.
# Uso: PGHOST=<socket|host> PGUSER=postgres tools/online/refund_nitro_test.sh
set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DB=refund_test
MIG=20261025120000_no_nitro_spoilers_price_tiers.sql
dropdb --if-exists $DB >/dev/null 2>&1 || true
createdb $DB
P="psql -d $DB -v ON_ERROR_STOP=1 -q"
$P -f "$DIR/tools/online/pg_stub.sql" >/dev/null
for f in "$DIR"/supabase/migrations/*.sql; do
  [ "$(basename "$f")" = "$MIG" ] && continue
  [ "$(basename "$f")" \> "$MIG" ] && continue
  $P -f "$f" >/dev/null 2>/tmp/mig.err || { echo "FALLÓ $f"; grep -v NOTICE /tmp/mig.err | head; exit 1; }
done
$P <<'SQL' 2>&1 | grep -v "^$" | sed 's/^psql:[^ ]* //; s/^NOTICE:  //' | grep "OK\|FALLA\|ERROR" || true
-- una cuenta con el nitro (niveles 1 y 2) y dos alerones en un auto, y otra con un alerón y una mejora que NO se toca
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'a@x'), ('00000000-0000-0000-0000-0000000000a2', 'b@x'), ('00000000-0000-0000-0000-0000000000a3', 'c@x');
insert into public.account_econ (user_id, credits, cars) values
  ('00000000-0000-0000-0000-0000000000a1', 1000, '{"hatch": {"bought": 1, "owned": ["engine:1", "nitro:1", "nitro:2"], "tires": ["street"], "parts": ["spoiler_gt", "spoiler_duck", "rim_x"]}, "gt": {"bought": 2, "owned": [], "tires": ["street"], "parts": []}}'),
  ('00000000-0000-0000-0000-0000000000a2', 50, '{"hatch": {"bought": 1, "owned": ["engine:2"], "tires": ["street"], "parts": ["spoiler_rally"]}}'),
  ('00000000-0000-0000-0000-0000000000a3', 77, '{"hatch": {"bought": 1, "owned": ["engine:1"], "tires": ["street"], "parts": []}}');
-- el garaje online: un auto con nitro nivel 2, un alerón comprado y puesto
insert into public.players (id, name) values ('00000000-0000-0000-0000-0000000000a1', 'Uno'), ('00000000-0000-0000-0000-0000000000a2', 'Dos');
insert into public.online_wallets (player_id, credits) values ('00000000-0000-0000-0000-0000000000a1', 500), ('00000000-0000-0000-0000-0000000000a2', 10);
insert into public.online_vehicles (id, owner, vehicle_id, upgrades, parts_owned, mods) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'hatch', '{"engine": 1, "nitro": 2}', array['spoiler_gt', 'rim_x'], '{"spoiler": {"id": "spoiler_gt", "v": 0}, "wheel": {"id": "rim_x", "v": 0}}'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'hatch', '{"engine": 2}', array['rim_x'], '{"wheel": {"id": "rim_x", "v": 0}}');
SQL
$P -f "$DIR/supabase/migrations/$MIG" >/dev/null 2>/tmp/mig.err || { echo "FALLÓ $MIG"; grep -v NOTICE /tmp/mig.err | head; exit 1; }
$P -f "$DIR/supabase/migrations/$MIG" >/dev/null 2>/tmp/mig.err || { echo "FALLÓ al repetir $MIG"; grep -v NOTICE /tmp/mig.err | head; exit 1; }
$P <<'SQL' 2>&1 | grep "NOTICE\|ERROR\|FALLA" | sed 's/^psql:[^ ]* //; s/^NOTICE:  //'
create function pg_temp.ok(c boolean, m text) returns void language plpgsql as $$ begin if not c then raise exception 'FALLA %', m; end if; raise notice 'OK   %', m; end; $$;
select pg_temp.ok((select credits from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a1') = 1000 + 8000 + 15000 + 1800 + 900, 'la cuenta con nitro 1 y 2 y dos alerones recibe 8.000 + 15.000 + 1.800 + 900 de vuelta');
select pg_temp.ok(not (select cars::text like '%nitro%' or cars::text like '%spoiler%' from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a1'), 'a esa cuenta ya no le quedan nitro ni alerones en los autos');
select pg_temp.ok((select cars -> 'hatch' -> 'owned' from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a1') = '["engine:1"]'::jsonb and (select cars -> 'hatch' -> 'parts' from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a1') = '["rim_x"]'::jsonb, 'lo demás (motor, llanta) queda como estaba');
select pg_temp.ok((select credits from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a2') = 50 + 2600, 'la otra cuenta recibe los 2.600 del alerón rally');
select pg_temp.ok((select credits from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a3') = 77 and (select cars -> 'hatch' -> 'owned' from public.account_econ where user_id = '00000000-0000-0000-0000-0000000000a3') = '["engine:1"]'::jsonb, 'una cuenta sin nitro ni alerones no se toca');
select pg_temp.ok((select credits from public.online_wallets where player_id = '00000000-0000-0000-0000-0000000000a1') = 500 + 8000 + 15000 + 1800, 'el garaje online devuelve el nitro (niveles 1 y 2) y el alerón GT');
select pg_temp.ok((select upgrades from public.online_vehicles where id = '00000000-0000-0000-0000-0000000000b1') = '{"engine": 1}'::jsonb and (select mods from public.online_vehicles where id = '00000000-0000-0000-0000-0000000000b1') = '{"wheel": {"id": "rim_x", "v": 0}}'::jsonb and (select parts_owned from public.online_vehicles where id = '00000000-0000-0000-0000-0000000000b1') = array['rim_x'], 'el auto del garaje online queda sin nitro y sin alerón');
select pg_temp.ok((select credits from public.online_wallets where player_id = '00000000-0000-0000-0000-0000000000a2') = 10, 'el otro jugador online no recibe nada');
select pg_temp.ok(not exists (select 1 from public.online_cat_upgrades where category = 'nitro') and not exists (select 1 from public.online_cat_parts where category = 'spoiler'), 'el catálogo del servidor ya no tiene nitro ni alerones');
select pg_temp.ok((select count(*) from public.online_cat_upgrades) = 23 and (select count(*) from public.online_cat_parts where category = 'wheel') = 26 and (select count(*) from public.online_cat_parts where category = 'cosmetic') = 35, 'quedan las 23 mejoras, las 26 llantas y los 35 cosméticos');
select pg_temp.ok(not exists (select price from public.online_cat_vehicles where buyable and not starter group by price having count(*) < 2), 'todo precio de auto lo comparten dos o más autos');
select pg_temp.ok((select price from public.online_cat_vehicles where id = 'hatch') = 9000 and (select price from public.online_cat_vehicles where id = 'torito') = (select price from public.online_cat_vehicles where id = 'hatch2'), 'el inicial sigue en 9.000 y el clásico de demolición y el hatch de rally valen lo mismo');
SQL
dropdb $DB >/dev/null 2>&1 || true
