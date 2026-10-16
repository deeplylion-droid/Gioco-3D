#!/bin/bash
# Scatti fissi della sala principale (godot/tests/scatti_sala.gd, senza gli interni): un processo
# di Godot per scatto, ognuno sotto il render.lock (tra uno scatto e l'altro il lock si libera).
# Per ogni processo misura la memoria massima (VmHWM) e lo ferma se supera LIMITE_MB, così non
# rischia di far uccidere gli altri processi della macchina (15 GB in tutto).
#
# Uso: tools/scatti_sala.sh <cartella> <prefisso> [scatti separati da virgole | tutti] [preset] [frame]
#   per esempio: tools/scatti_sala.sh docs/report/qualita_sala dopo tutti alto_smaa 50
# Variabili: LIMITE_MB (13000), LOCK (/home/user/tools/render.lock), RISOLUZIONE (1600x900),
# LOGDIR (/tmp: il log di Godot di ogni scatto), MEM_MIN_KB (13,5 GB), SCATTI_TOGLI (vedi scatti_sala.gd).
# Ogni scatto parte solo dentro il lock e con almeno 13,5 GB di MemAvailable (regola della macchina, 16
# ottobre); se dopo il salvataggio Godot resta con la CPU ferma per più di 150 s (bloccato nell'uscita,
# con la memoria e il lock in mano) si chiude.
set -u
RADICE=$(cd "$(dirname "$0")/.." && pwd)
LIMITE_MB=${LIMITE_MB:-13000}
MEM_MIN_KB=${MEM_MIN_KB:-14155776}
LOCK=${LOCK:-/home/user/tools/render.lock}
RIS=${RISOLUZIONE:-1600x900}

if [ "${1:-}" = "--uno" ]; then
	CARTELLA=$2; PREFISSO=$3; S=$4; PRESET=$5; FRAME=$6
	while [ "$(awk '/^MemAvailable/{print $2}' /proc/meminfo)" -lt "$MEM_MIN_KB" ]; do
		echo "$S: aspetto memoria ($(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo) MB liberi)"; sleep 20
	done
	LOG="${LOGDIR:-/tmp}/scatti_sala_${PREFISSO}_$S.log"
	cd "$RADICE/godot" || exit 1
	xvfb-run -a -s "-screen 0 ${RIS}x24" nice -n 8 godot --rendering-driver vulkan --fixed-fps 60 \
		--resolution "$RIS" --path . --script res://tests/run.gd -- res://tests/scatti_sala.gd \
		"$CARTELLA" "$PREFISSO" "$S" "$PRESET" "$FRAME" > "$LOG" 2>&1 &
	XP=$!
	MAX=0; GP=""; T0=$(date +%s); CPU_PREC=""; FERMA_DA=""
	while kill -0 "$XP" 2>/dev/null; do
		[ -z "$GP" ] && GP=$(pgrep -P "$XP" -x godot | head -1)
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
	grep -E "salvato|SCRIPT ERROR|Parse Error|non-existent" "$LOG" | head -5
	exit 0
fi

[ $# -lt 2 ] && { echo "uso: $0 <cartella> <prefisso> [scatti|tutti] [preset] [frame]"; exit 2; }
CARTELLA=$(realpath -m "$1"); PREFISSO=$2; SCATTI=${3:-tutti}; PRESET=${4:-alto_smaa}; FRAME=${5:-50}
[ "$SCATTI" = tutti ] && SCATTI="a_ingresso,b_vasca_3m,c_piscina_spiaggia,d_area_bimbi,e_base_torre,f_galleria"
mkdir -p "$CARTELLA"
for S in ${SCATTI//,/ }; do
	flock "$LOCK" bash "$0" --uno "$CARTELLA" "$PREFISSO" "$S" "$PRESET" "$FRAME"
done
echo FINITO
