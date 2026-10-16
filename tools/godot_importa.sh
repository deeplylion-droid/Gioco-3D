#!/bin/bash
# Importa il progetto Godot come la CI: prima importazione, texture estratte dai GLB in VRAM
# compressa (tools/godot_vram_textures.py), seconda importazione.
# Senza il passaggio in mezzo le texture estratte restano Lossless, cioè non compresse in memoria
# video: sul renderer software (llvmpipe) sono circa 5 GB in più e la sala non entra in memoria.
# Uso: bash tools/godot_importa.sh [cartella del progetto, predefinita: godot]
set -e
cd "$(dirname "$0")/.."
P=${1:-godot}
GODOT=${GODOT:-godot}
"$GODOT" --headless --path "$P" --import > /dev/null 2>&1 || true
python3 tools/godot_vram_textures.py "$P"
"$GODOT" --headless --path "$P" --import > /dev/null 2>&1 || true
echo "godot_importa: importazione finita (texture estratte in VRAM)"
