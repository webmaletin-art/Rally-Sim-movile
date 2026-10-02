#!/bin/bash
# Saca capturas del juego (pantalla virtual, 1920×1080) para la ficha de Play Store → store_listing/capturas/
# Uso: tools/play/capturas.sh      (las capturas con el auto andando conviene sacarlas en el teléfono: botón 📷 del juego)
cd "$(dirname "$0")/../../godot"
G=${GODOT:-/tmp/godot/Godot_v4.4.1-stable_linux.x86_64}
OUT=../store_listing/capturas
mkdir -p $OUT
shot() { # nombre, args…
  n=$1; shift
  timeout 280 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --path . --rendering-driver opengl3 --resolution 1920x1080 -- --menu --noconsent "$@" --mshot=$OUT/$n.png 2>&1 | grep -E "SCRIPT ERROR" | head -3
  ls -la $OUT/$n.png 2>/dev/null | awk '{print $5, $9}'
}
shot 01_menu --screen=home --mframes=80
shot 02_tienda_bisonte --screen=dealer --mframes=80
shot 03_taller --screen=workshop --mframes=80
