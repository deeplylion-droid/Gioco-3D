#!/bin/bash
# Scatti della proposta degli acquari (godot/tests/scatti_acquari.gd), sotto il render.lock, solo con
# almeno 13,5 GB di MemAvailable; ferma Godot se supera LIMITE_MB (12500) di memoria.
# Uso: tools/scatti_acquari.sh <cartella> "<giri>" [frame di attesa]
# SCRIPT_TEST: un altro script di scatti con gli stessi argomenti (per esempio tests/scatti_enigma.gd).
set -u
RADICE=$(cd "$(dirname "$0")/.." && pwd)
CARTELLA=$1; GIRI=$2; FRAME=${3:-40}
LIMITE_MB=${LIMITE_MB:-12500}
LOG=${LOG:-/tmp/scatti_acquari.log}
exec 9>/home/user/tools/render.lock
flock 9
while [ "$(awk '/^MemAvailable/{print $2}' /proc/meminfo)" -lt 14155776 ]; do
	echo "aspetto memoria ($(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo) MB liberi)"; sleep 20
done
cd "$RADICE/godot" || exit 1
xvfb-run -a -s "-screen 0 1600x900x24" nice -n 8 godot --rendering-driver vulkan --fixed-fps 60 \
	--resolution 1600x900 --path . --script res://tests/run.gd -- "${SCRIPT_TEST:-res://tests/scatti_acquari.gd}" \
	"$CARTELLA" "$GIRI" "$FRAME" > "$LOG" 2>&1 &
XP=$!; MAX=0; GP=""; T0=$(date +%s)
while kill -0 "$XP" 2>/dev/null; do
	[ -z "$GP" ] && GP=$(pgrep -P "$XP" -x godot | head -1)
	if [ -n "$GP" ] && [ -r "/proc/$GP/status" ]; then
		R=$(awk '/^VmHWM/{print int($2/1024)}' "/proc/$GP/status" 2>/dev/null)
		if [ -n "$R" ]; then
			[ "$R" -gt "$MAX" ] && MAX=$R
			[ "$R" -gt "$LIMITE_MB" ] && { kill -9 "$GP"; echo "FERMATO: memoria $R MB"; }
		fi
	fi
	sleep 1
done
echo "memoria massima ${MAX} MB, $(( $(date +%s) - T0 )) s"
grep -E "salvato|SCRIPT ERROR|Parse Error|ERROR" "$LOG" | grep -v ALSA | head -30
