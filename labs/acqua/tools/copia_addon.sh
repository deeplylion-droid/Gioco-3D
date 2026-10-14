#!/usr/bin/env bash
# Copia l'addon dal laboratorio (labs/acqua/addons/acqua) nel progetto del gioco (godot/addons/acqua).
# I file .import e .uid vengono copiati (opzioni d'importazione e identificativi), la cache .godot no.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT/labs/acqua/addons/acqua"
DST="$ROOT/godot/addons/acqua"
rm -rf "$DST"
mkdir -p "$(dirname "$DST")"
cp -a "$SRC" "$DST"
find "$DST" -name ".godot" -prune -exec rm -rf {} +
echo "copiato in $DST"
