#!/bin/bash
# Copia a godot/game/ los modelos y datos que usa el juego Godot (mientras conviva con la versión HTML).
# Uso: tools/godot/sync_assets.sh
set -e
cd "$(dirname "$0")/../.."
mkdir -p godot/game/models godot/game/data
for f in volt_body volt_body_lo volt_wheel volt_wheel_lo genesis_body genesis_body_lo genesis_rim genesis_rim_lo pilot pilot_lo; do cp models/$f.glb godot/game/models/; done
node tools/godot/js_reference.mjs > /dev/null
echo "assets sincronizados"
