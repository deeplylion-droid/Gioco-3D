#!/usr/bin/env bash
# Copia il codice riutilizzabile del laboratorio nel gioco: labs/grafica/grafica -> godot/addons/grafica
# (riscrive i percorsi res://grafica/ in res://addons/grafica/). Tocca solo godot/addons/grafica/.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=../../godot/addons/grafica
mkdir -p "$DEST/texture"
for f in grafica/*.gd grafica/*.gdshader; do
  sed 's#res://grafica/#res://addons/grafica/#g' "$f" > "$DEST/$(basename "$f")"
done
for d in sala interni; do
  mkdir -p "$DEST/$d"
  for f in grafica/$d/*.tres; do
    sed 's#res://grafica/#res://addons/grafica/#g; /^\[ext_resource/ s# uid="[^"]*"##' "$f" > "$DEST/$d/$(basename "$f")"
  done
done
cp grafica/texture/torcia_cookie.png "$DEST/texture/"
cp strumenti/addon/*.tscn strumenti/addon/README.md "$DEST/"
echo "esportato in $(cd "$DEST" && pwd)"
