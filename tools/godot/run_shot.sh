#!/bin/bash
# Corre la escena principal con pantalla virtual y saca una captura. Uso: tools/godot/run_shot.sh salida.png [args del juego…]
# Muestra solo los errores de scripts (los avisos de fugas al cerrar en modo virtual no importan).
out=$1; shift
cd "$(dirname "$0")/../../godot"
G=${GODOT:-/tmp/godot/Godot_v4.4.1-stable_linux.x86_64}
timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --rendering-driver opengl3 --resolution 1280x576 res://game/main.tscn -- --shot="$out" --frames=${FRAMES:-100} "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|BENCH|ERROR: Failed|Invalid" | grep -v "leaked" | head -20
ls -la "$out" 2>/dev/null | awk '{print $5, $9}'
