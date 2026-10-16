#!/bin/bash
# Corre UNA prueba de Godot con tope de tiempo y registro en vivo (pedido del dueño, 16/10/2026):
#   - cada renglón que imprime la prueba se guarda al instante en test_logs/<prueba>.log con los segundos transcurridos;
#   - si la prueba se traba, se corta al llegar al tope y el registro conserva todo lo que alcanzó a comprobar (OK/FALLA hasta ese momento);
#   - al final se agrega un renglón a test_logs/RESUMEN.txt: fecha · prueba · OK / FALLA / TIEMPO AGOTADO · segundos · cuántos OK y FALLA vio.
# Uso: tools/test/run_test.sh <prueba> [segundos_tope=60]        (ej.: tools/test/run_test.sh class_records_test 30)
#      tools/test/run_test.sh --lista a_test b_test c_test [tope]   (varias seguidas, cada una con el mismo tope)
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOGS="$DIR/test_logs"
mkdir -p "$LOGS"

uno() {
  local t="$1" lim="${2:-60}"
  local log="$LOGS/$t.log"
  local t0; t0=$(date +%s)
  echo "### $t · tope ${lim}s · $(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$log"
  if [ ! -f "$DIR/godot/tests/$t.gd" ]; then
    echo "NO EXISTE godot/tests/$t.gd" >> "$log"
    echo "$(date -u '+%F %T') · $t · NO EXISTE" >> "$LOGS/RESUMEN.txt"
    echo "$t: NO EXISTE"; return 2
  fi
  # el registro se escribe renglón por renglón (si la prueba se cuelga, lo anterior ya quedó en disco)
  ( cd "$DIR/godot" && timeout -k 5 "$lim" godot --headless --script "res://tests/$t.gd" 2>&1 ) | while IFS= read -r line; do
    printf '[%4ss] %s\n' "$(( $(date +%s) - t0 ))" "$line" >> "$log"
  done
  local rc=${PIPESTATUS[0]}
  local dt=$(( $(date +%s) - t0 ))
  local nok nfa est
  nok=$(grep -cE '\] (OK|  OK)\b|TEST OK|TODO OK' "$log")
  nfa=$(grep -cE '\] FALLA( |$)|SCRIPT ERROR|Parse Error|FALLAS: [1-9]' "$log")
  if [ "$rc" = "124" ] || [ "$rc" = "137" ]; then est="TIEMPO AGOTADO"
  elif [ "$rc" = "0" ] && [ "$nfa" = "0" ]; then est="OK"
  else est="FALLA (código $rc)"; fi
  echo "### fin: $est · ${dt}s" >> "$log"
  echo "$(date -u '+%F %T') · $t · $est · ${dt}s · ${nok} OK · ${nfa} FALLA" >> "$LOGS/RESUMEN.txt"
  echo "$t: $est · ${dt}s · ${nok} OK · ${nfa} FALLA   (registro: test_logs/$t.log)"
  [ "$est" = "OK" ]
}

if [ "${1:-}" = "--lista" ]; then
  shift
  lim=60
  last="${!#}"
  if [[ "$last" =~ ^[0-9]+$ ]]; then lim="$last"; set -- "${@:1:$(($#-1))}"; fi
  fails=0
  for t in "$@"; do uno "$t" "$lim" || fails=$((fails+1)); done
  exit $fails
fi
uno "${1:?falta el nombre de la prueba}" "${2:-60}"
