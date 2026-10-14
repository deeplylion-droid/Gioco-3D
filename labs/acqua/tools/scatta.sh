#!/usr/bin/env bash
# Screenshot della demo senza schermo (Xvfb + Vulkan software).
# Uso: labs/acqua/tools/scatta.sh <file.jpg|png> [WxH] [argomenti per la demo, es. --shot=finale --style=0]
# Il timeout e' dentro xvfb-run, cosi' viene terminato solo il nostro Godot (e xvfb-run chiude il suo Xvfb).
set -uo pipefail
OUT="$1"; shift
RES="${1:-960x540}"; shift || true
DIR="$(cd "$(dirname "$0")/.." && pwd)"
W="${RES%x*}"; H="${RES#*x}"
LIMIT="${SCATTA_TIMEOUT:-900}"
# flock: un solo render pesante alla volta tra gli agenti della macchina
flock /home/user/tools/render.lock nice -n 10 xvfb-run -a -s "-screen 0 ${W}x${H}x24" \
  timeout --kill-after=15 "$LIMIT" godot --path "$DIR" --rendering-driver vulkan --resolution "${W}x${H}" -- --out="$OUT" "$@" 2>&1 \
  | grep -v -i -E "alsa|audio|^$|ERR_CANT_OPEN|status < 0" || true
