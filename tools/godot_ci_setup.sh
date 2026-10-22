#!/usr/bin/env bash
# Scarica Godot (editor, usato senza schermo) e i soli template di export che servono
# (Windows x86_64 e Linux x86_64). Serve alla CI di GitHub Actions e alle sessioni nuove.
# Uso: bash tools/godot_ci_setup.sh   (variabili: GODOT_VERSION, GODOT_BIN_DIR)
set -euo pipefail
VER="${GODOT_VERSION:-4.7.2}"
BIN_DIR="${GODOT_BIN_DIR:-$HOME/godot-bin}"
mkdir -p "$BIN_DIR"
if [ ! -x "$BIN_DIR/godot" ]; then
  TMP="$(mktemp -d)"
  curl -sSL -A "jilly-jubilee-build/1.0" -o "$TMP/godot.zip" \
    "https://downloads.godotengine.org/?version=${VER}&flavor=stable&slug=linux.x86_64.zip&platform=linux.64"
  unzip -q -o "$TMP/godot.zip" -d "$TMP"
  mv "$TMP/Godot_v${VER}-stable_linux.x86_64" "$BIN_DIR/godot"
  chmod +x "$BIN_DIR/godot"
  rm -rf "$TMP"
fi
python3 "$(dirname "$0")/godot_export_templates.py" "$VER"
"$BIN_DIR/godot" --version
