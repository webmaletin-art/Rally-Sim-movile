#!/bin/bash
# Arranca el juego 60 cuadros con pantalla virtual y muestra solo errores de scripts. Uso: tools/godot/check.sh [args…]
cd "$(dirname "$0")/../../godot"
G=${GODOT:-/tmp/godot/Godot_v4.4.1-stable_linux.x86_64}
timeout ${T:-45} xvfb-run -a -s "-screen 0 1280x720x24" "$G" --path . --rendering-driver opengl3 --resolution 1280x576 res://game/main.tscn -- --frames=${FRAMES:-60} "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed|Invalid|at: " | grep -v "leaked\|audio_driver\|gl_manager\|audio_server" | head -${N:-25}
