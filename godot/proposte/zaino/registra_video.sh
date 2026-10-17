#!/bin/bash
# PROPOSTA zaino: registra il video di 8 s di uno stile di getto con Godot Movie Maker, poi lo taglia
# dall'inizio della scaletta e lo converte in MP4 H.264 (circa 4 MB al massimo).
# Uso: godot/proposte/zaino/registra_video.sh <stile: attuale|A|B> <uscita.mp4> [lancia: attuale|res://...tscn]
set -euo pipefail
STILE=$1; OUT=$(realpath -m "$2"); LANCIA=${3:-attuale}
QUI=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/claude-0/video_XXXX)
cd "$QUI"
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --resolution 1280x720 \
	--fixed-fps 30 --write-movie "$TMP/grezzo.avi" --script res://tests/run.gd -- \
	res://proposte/zaino/video_zaino.gd "$STILE" "$LANCIA" video > "$TMP/log.txt" 2>&1 || true
N=$(grep -o "INIZIO frame [0-9]*" "$TMP/log.txt" | grep -o "[0-9]*$")
INIZIO=$(python3 -c "print($N/30)")
echo "inizio a $INIZIO s"
ffmpeg -y -loglevel error -ss "$INIZIO" -i "$TMP/grezzo.avi" -t 8 -c:v libx264 -preset slow -crf 23 \
	-maxrate 3.5M -bufsize 7M -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart "$OUT"
ls -la "$OUT"
rm -rf "$TMP"
