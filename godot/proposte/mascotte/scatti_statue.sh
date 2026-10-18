#!/bin/bash
# Lancia proposte/mascotte/scatti_statue.gd (statue montate al volo nella sala) con le regole della
# macchina: dentro render.lock, solo con almeno 13,5 GB liberi, e fermato se supera 13 GB.
# Uso: godot/proposte/mascotte/scatti_statue.sh <cartella> "<statue>" "<scatti>" [frame]
set -u
RADICE=$(cd "$(dirname "$0")/../../.." && pwd)
CARTELLA=$(realpath -m "$1"); STATUE=$2; SCATTI=$3; FRAME=${4:-90}
LOG=${LOG:-/tmp/scatti_statue.log}
exec 9>/home/user/tools/render.lock
flock 9
while [ "$(awk '/^MemAvailable/{print $2}' /proc/meminfo)" -lt 14155776 ]; do
	echo "aspetto memoria ($(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo) MB liberi)"; sleep 20
done
cd "$RADICE/godot"
xvfb-run -a -s "-screen 0 1600x900x24" nice -n 8 godot --rendering-driver vulkan --fixed-fps 60 \
	--resolution 1600x900 --path . --script res://tests/run.gd -- res://proposte/mascotte/scatti_statue.gd \
	"$CARTELLA" "$STATUE" "$SCATTI" "$FRAME" > "$LOG" 2>&1 &
XP=$!; MAX=0; GP=""; T0=$(date +%s)
while kill -0 "$XP" 2>/dev/null; do
	[ -z "$GP" ] && GP=$(pgrep -P "$XP" -x godot | head -1)
	if [ -n "$GP" ] && [ -r "/proc/$GP/status" ]; then
		R=$(awk '/^VmHWM/{print int($2/1024)}' "/proc/$GP/status" 2>/dev/null)
		if [ -n "$R" ]; then
			[ "$R" -gt "$MAX" ] && MAX=$R
			[ "$R" -gt 13000 ] && { kill -9 "$GP"; echo "FERMATO: memoria $R MB"; }
		fi
	fi
	sleep 0.5
done
echo "memoria massima ${MAX} MB, $(( $(date +%s) - T0 )) s"
grep -E "salvato|STATUA|ATTENZIONE|SCRIPT ERROR|Parse Error" "$LOG" | head -40
