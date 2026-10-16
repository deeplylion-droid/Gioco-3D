#!/bin/bash
# Scatti delle PROPOSTE della sala (godot/tests/proposte_sala.gd): un processo di Godot per scatto,
# ognuno sotto il render.lock, con il controllo della memoria come tools/scatti_sala.sh.
# Le piante vogliono una risoluzione loro: bimbi_*_pianta e torre_nord_pianta 1000x1400,
# torre_est_pianta 1600x1000, il resto 1600x900.
#
# Uso: tools/proposte_sala.sh <cartella> <scatti separati da virgole> [preset] [frame]
# Variabili: LIMITE_MB (13000), MEM_MIN_KB (13,5 GB), LOCK (/home/user/tools/render.lock), LOGDIR (/tmp).
# Ogni scatto parte solo dentro il lock e con almeno 13,5 GB di MemAvailable (la macchina ne ha 15).
set -u
RADICE=$(cd "$(dirname "$0")/.." && pwd)
LIMITE_MB=${LIMITE_MB:-13000}
MEM_MIN_KB=${MEM_MIN_KB:-14155776}   # 13,5 GB di MemAvailable prima di partire
LOCK=${LOCK:-/home/user/tools/render.lock}

ris() {
	case "$1" in
		bimbi_*_pianta|torre_nord_pianta) echo 1000x1400 ;;
		torre_est_pianta) echo 1600x1000 ;;
		*) echo 1600x900 ;;
	esac
}

if [ "${1:-}" = "--uno" ]; then
	CARTELLA=$2; S=$3; PRESET=$4; FRAME=$5
	RIS=$(ris "$S")
	# dentro il lock: si parte solo con almeno MEM_MIN_KB liberi (uno scatto della sala arriva a ~12,7 GB)
	while [ "$(awk '/^MemAvailable/{print $2}' /proc/meminfo)" -lt "$MEM_MIN_KB" ]; do
		echo "$S: aspetto memoria ($(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo) MB liberi)"; sleep 20
	done
	LOG="${LOGDIR:-/tmp}/proposte_sala_$S.log"
	cd "$RADICE/godot" || exit 1
	xvfb-run -a -s "-screen 0 ${RIS}x24" nice -n 8 godot --rendering-driver vulkan --fixed-fps 60 \
		--resolution "$RIS" --path . --script res://tests/run.gd -- res://tests/proposte_sala.gd \
		"$CARTELLA" "$S" "$PRESET" "$FRAME" > "$LOG" 2>&1 &
	XP=$!
	MAX=0; GP=""; T0=$(date +%s); CPU_PREC=""; FERMA_DA=""
	while kill -0 "$XP" 2>/dev/null; do
		[ -z "$GP" ] && GP=$(pgrep -P "$XP" -x godot | head -1)
		# dopo il salvataggio, se il tempo di CPU resta fermo per più di 150 s Godot è bloccato
		# nell'uscita (tiene memoria e lock): si chiude
		if [ -n "$GP" ] && grep -q "^salvato" "$LOG" 2>/dev/null && [ -r "/proc/$GP/stat" ]; then
			CPU=$(awk '{print $14 + $15}' "/proc/$GP/stat" 2>/dev/null)
			if [ "$CPU" = "$CPU_PREC" ]; then
				[ -z "$FERMA_DA" ] && FERMA_DA=$(date +%s)
				if [ $(( $(date +%s) - FERMA_DA )) -gt 150 ]; then
					kill -9 "$GP"; echo "$S: Godot fermo dopo il salvataggio, chiuso"
				fi
			else
				FERMA_DA=""; CPU_PREC=$CPU
			fi
		fi
		if [ -n "$GP" ] && [ -r "/proc/$GP/status" ]; then
			R=$(awk '/^VmHWM/{print int($2/1024)}' "/proc/$GP/status" 2>/dev/null)
			if [ -n "$R" ]; then
				[ "$R" -gt "$MAX" ] && MAX=$R
				if [ "$R" -gt "$LIMITE_MB" ]; then
					kill -9 "$GP"; echo "$S: FERMATO, memoria $R MB oltre $LIMITE_MB MB"
				fi
			fi
		fi
		sleep 0.5
	done
	echo "$S: memoria massima ${MAX} MB, $(( $(date +%s) - T0 )) s"
	grep -E "salvato|PIANTA|SCRIPT ERROR|Parse Error|non-existent|manca " "$LOG" | head -8
	exit 0
fi

[ $# -lt 2 ] && { echo "uso: $0 <cartella> <scatti separati da virgole> [preset] [frame]"; exit 2; }
CARTELLA=$(realpath -m "$1"); SCATTI=$2; PRESET=${3:-alto_smaa}; FRAME=${4:-40}
mkdir -p "$CARTELLA"
for S in ${SCATTI//,/ }; do
	flock "$LOCK" bash "$0" --uno "$CARTELLA" "$S" "$PRESET" "$FRAME"
done
echo FINITO
