#!/bin/bash
# Registra lo spot VHS della crociera col Movie Maker di Godot e lo monta in godot/assets/spot/spot.ogv (solo video:
# l'audio e il filtro VHS li mette dal vivo il lettore, scripts/spot/lettore_spot.gd).
# Un processo Godot per segmento (scenes/spot/spot_inquadrature.json), uno alla volta sotto il render.lock: la sala
# dello spot da sola prende quasi tutta la memoria. I primi PREP secondi di ogni segmento (camera ferma, la GI si
# assesta) si tagliano al montaggio.
# Uso: bash tools/spot/registra_spot.sh [segmento ...]   (senza argomenti: tutti)
# Per una prova bassa: SPOT_RIS=640x360 SPOT_FPS=15 SPOT_FILE=/percorso/prova.ogv bash tools/spot/registra_spot.sh
set -e
QUI="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${SPOT_OUT:-/home/user/spot_registrazione}"
PREP="${SPOT_PREP:-4}"
FPS="${SPOT_FPS:-30}"
RIS="${SPOT_RIS:-1280x720}"
FILE="${SPOT_FILE:-$QUI/godot/assets/spot/spot.ogv}"
mkdir -p "$OUT"
JSON="$QUI/godot/scenes/spot/spot_inquadrature.json"
TUTTI=$(python3 -c "import json,sys;print(' '.join(s['nome'] for s in json.load(open(sys.argv[1]))['segmenti']))" "$JSON")
SEGMENTI="${*:-$TUTTI}"
for s in $SEGMENTI; do
	echo "== segmento $s"
	while [ "$(awk '/MemAvailable/{print $2}' /proc/meminfo)" -lt 13500000 ]; do sleep 20; done
	flock /home/user/tools/render.lock xvfb-run -a -s "-screen 0 ${RIS}x24" godot --path "$QUI/godot" \
		--rendering-driver vulkan --resolution $RIS --fixed-fps $FPS --write-movie "$OUT/$s.avi" \
		--script res://tests/run.gd -- res://scripts/spot/regia_spot.gd "$s" "$PREP" 2>&1 | grep -v ALSA | tail -5
done
# montaggio: ogni segmento senza la preparazione, poi tutti di fila
INGRESSI=""; FILTRO=""; N=0
for s in $TUTTI; do
	# alla durata esatta del segmento (la regia si ferma un fotogramma dopo: senza, lo spot andava avanti all'audio)
	DUR=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));g=[x for x in d['segmenti'] if x['nome']==sys.argv[2]][0]['inquadrature'];print(g[-1]['inizio']+g[-1]['durata']-g[0]['inizio'])" "$JSON" "$s")
	ffmpeg -y -loglevel error -ss "$PREP" -i "$OUT/$s.avi" -t "$DUR" -an -c:v mjpeg -q:v 2 "$OUT/${s}_tagliato.avi"
	INGRESSI="$INGRESSI -i $OUT/${s}_tagliato.avi"; FILTRO="$FILTRO[$N:v]"; N=$((N + 1))
done
mkdir -p "$(dirname "$FILE")"
# un filo di grana (sotto il filtro VHS non si vede): senza, Theora salta i fotogrammi uguali (il logo fermo) e il
# lettore di Godot mostrava in anticipo l'inquadratura dopo
ffmpeg -y -loglevel error $INGRESSI -filter_complex "${FILTRO}concat=n=$N:v=1:a=0,noise=alls=2:allf=t[v]" -map "[v]" -an -r $FPS \
	-c:v libtheora -q:v 8 "$FILE"
ls -la "$FILE"
