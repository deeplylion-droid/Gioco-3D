#!/bin/bash
# Registra lo spot VHS della crociera col Movie Maker di Godot e lo monta in godot/assets/spot/spot.ogv (solo video:
# l'audio e il filtro VHS li mette dal vivo il lettore, scripts/spot/lettore_spot.gd).
# Un processo Godot per segmento (scenes/spot/spot_inquadrature.json), uno alla volta sotto il render.lock: la sala
# dello spot da sola prende quasi tutta la memoria. I primi PREP secondi di ogni segmento (camera ferma, la GI si
# assesta) si tagliano al montaggio.
# Uso: bash tools/spot/registra_spot.sh [segmento ...]   (senza argomenti: tutti; quelli già registrati si tengono)
set -e
QUI="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${SPOT_OUT:-/home/user/spot_registrazione}"
PREP="${SPOT_PREP:-4}"
FPS=30
mkdir -p "$OUT"
JSON="$QUI/godot/scenes/spot/spot_inquadrature.json"
TUTTI=$(python3 -c "import json,sys;print(' '.join(s['nome'] for s in json.load(open(sys.argv[1]))['segmenti']))" "$JSON")
SEGMENTI="${*:-$TUTTI}"
for s in $SEGMENTI; do
	echo "== segmento $s"
	while [ "$(awk '/MemAvailable/{print $2}' /proc/meminfo)" -lt 13500000 ]; do sleep 20; done
	flock /home/user/tools/render.lock xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$QUI/godot" \
		--rendering-driver vulkan --resolution 1280x720 --fixed-fps $FPS --write-movie "$OUT/$s.avi" \
		--script res://tests/run.gd -- res://scripts/spot/regia_spot.gd "$s" "$PREP" 2>&1 | grep -v ALSA | tail -5
done
# montaggio: ogni segmento senza la preparazione, poi tutti di fila
: > "$OUT/lista.txt"
for s in $TUTTI; do
	ffmpeg -y -loglevel error -ss "$PREP" -i "$OUT/$s.avi" -an -c:v mjpeg -q:v 2 "$OUT/${s}_tagliato.avi"
	echo "file '$OUT/${s}_tagliato.avi'" >> "$OUT/lista.txt"
done
mkdir -p "$QUI/godot/assets/spot"
ffmpeg -y -loglevel error -f concat -safe 0 -i "$OUT/lista.txt" -an -r $FPS -c:v libtheora -q:v 8 \
	"$QUI/godot/assets/spot/spot.ogv"
ls -la "$QUI/godot/assets/spot/spot.ogv"
