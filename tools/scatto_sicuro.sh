#!/bin/bash
# Uno script di scatti qualsiasi della sala (godot/tests/...), sotto il render.lock, solo con
# almeno 13,5 GB di MemAvailable; ferma Godot se supera LIMITE_MB (12500) di memoria o se resta fermo
# ATTESA_FERMO secondi (60) dopo un salvataggio senza salvarne altri.
# Uso: tools/scatto_sicuro.sh res://tests/<script>.gd [argomenti dello script...]
set -u
RADICE=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT=$1; shift
LIMITE_MB=${LIMITE_MB:-12500}
LOG=${LOG:-/tmp/scatto_sicuro.log}
exec 9>/home/user/tools/render.lock
flock 9
while [ "$(awk '/^MemAvailable/{print $2}' /proc/meminfo)" -lt 14155776 ]; do
	echo "aspetto memoria ($(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo) MB liberi)"; sleep 20
done
cd "$RADICE/godot" || exit 1
xvfb-run -a -s "-screen 0 1600x900x24" nice -n 8 godot --rendering-driver vulkan --fixed-fps 60 \
	--resolution ${RISOLUZIONE:-1280x720} --path . --script res://tests/run.gd -- "$SCRIPT" "$@" \
	> "$LOG" 2>&1 &
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
	# a volte Godot resta bloccato all'uscita dopo aver salvato (con la memoria e il lock in mano)
	if [ -n "$GP" ] && grep -q "^salvato" "$LOG" 2>/dev/null; then
		[ -z "${SALVATO_DA:-}" ] && SALVATO_DA=$(date +%s)
		if [ $(( $(date +%s) - SALVATO_DA )) -gt ${ATTESA_FERMO:-60} ] && ! grep -q "memoria massima del processo" "$LOG"; then
			N_SALVATI=$(grep -c "^salvato" "$LOG")
			[ "$N_SALVATI" = "${N_PREC:-}" ] && { kill -9 "$GP"; echo "Godot fermo dopo il salvataggio, chiuso"; }
			N_PREC=$N_SALVATI; SALVATO_DA=$(date +%s)
		fi
	fi
	sleep 1
done
echo "memoria massima ${MAX} MB, $(( $(date +%s) - T0 )) s"
grep -E "salvato|SCRIPT ERROR|Parse Error|ERROR" "$LOG" | grep -v ALSA | head -30
