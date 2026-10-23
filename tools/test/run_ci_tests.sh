#!/bin/bash
# Corre TODAS las pruebas obligatorias del juego, las mismas del flujo «Build Godot APK» (job «tests»): las lee de .github/workflows/build-godot.yml
# para que haya UNA sola lista. Se corta en la primera que falla (código de salida ≠ 0).
# Uso: tools/test/run_ci_tests.sh [--list]     (--list sólo muestra cuántas pruebas hay y no corre ninguna)
# Hace falta Godot en el PATH y los recursos importados (godot --headless --import en la carpeta godot/).
set -u
DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WF="$DIR/.github/workflows/build-godot.yml"
mapfile -t CMDS < <(awk '/^  tests:/{t=1} /^  build:/{t=0} t' "$WF" | grep -E '^\s+(timeout -k 5 [0-9]+ godot --headless --script res://tests/|python3 \.\./tools/)' | sed -E 's/^\s+//')
echo "Pruebas obligatorias encontradas en build-godot.yml: ${#CMDS[@]}"
[ "${#CMDS[@]}" -ge 50 ] || { echo "::error::Se esperaban al menos 50 pruebas y se encontraron ${#CMDS[@]}: ¿cambió el formato de build-godot.yml?"; exit 2; }
[ "${1:-}" = "--list" ] && exit 0
cd "$DIR/godot"
n=0
for c in "${CMDS[@]}"; do
  n=$((n+1))
  echo "[$n/${#CMDS[@]}] $c"
  if ! bash -c "$c"; then
    echo "::error::FALLÓ la prueba obligatoria: $c"
    exit 1
  fi
done
echo "TODAS LAS PRUEBAS PASARON (${#CMDS[@]})"
