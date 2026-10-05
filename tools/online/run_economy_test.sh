#!/bin/bash
# Arma una base temporal, aplica TODAS las migraciones en orden y corre la prueba de la economía online. Uso: PGHOST=<socket|host> PGUSER=postgres tools/online/run_economy_test.sh
set -e
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DB=econ_test
dropdb --if-exists $DB >/dev/null 2>&1 || true
createdb $DB
P="psql -d $DB -v ON_ERROR_STOP=1 -q"
$P -f "$DIR/tools/online/pg_stub.sql" >/dev/null
for f in "$DIR"/supabase/migrations/*.sql; do $P -f "$f" >/dev/null 2>/tmp/mig.err || { echo "FALLÓ $f"; grep -v NOTICE /tmp/mig.err | head; exit 1; }; done
# la migración de la economía tiene que poder correr dos veces sin romper nada
$P -f "$DIR"/supabase/migrations/20261007010000_online_economy.sql >/dev/null 2>/tmp/mig.err || { echo "FALLÓ al repetir la migración"; grep -v NOTICE /tmp/mig.err | head; exit 1; }
$P -f "$DIR/tools/online/economy_test.sql" 2>&1 | grep "NOTICE\|ERROR\|FALLA\|ECONOMIA" | sed 's/^psql:[^ ]* //; s/^NOTICE:  //'
dropdb $DB >/dev/null 2>&1 || true
