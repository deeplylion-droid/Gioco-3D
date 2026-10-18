#!/bin/bash
# Scatti di controllo dell'enigma degli acquari nel gioco (godot/tests/scatti_enigma.gd): un processo per
# scatto, sotto il render.lock, con almeno 13,5 GB liberi e il limite di memoria di scatti_acquari.sh.
# Uso: tools/scatti_enigma.sh <cartella> [scatti...]   (di serie: meta pieni verde portone gorgo)
cd "$(dirname "$0")/.." || exit 1
OUT=$1; shift
LISTA=${*:-meta pieni verde portone gorgo}
export SCATTI_TOGLI=${SCATTI_TOGLI:-Tecnici,Sala/TorreScivoli,BambiniBalconata,Sala/AreaBimbi,Polaroid}   # senza Tecnici non c è la serranda: gli acquari compaiono con la tappa 8 finita
mkdir -p "$OUT"
for s in $LISTA; do
	[ -f "$OUT/gioco_$s.jpg" ] && continue
	LOG="$OUT/../log_gioco_$s.log" SCRIPT_TEST=res://tests/scatti_enigma.gd bash tools/scatti_acquari.sh "$OUT" "$s" 0 \
		| grep -E "memoria|FERMATO|salvato" | tr '\n' ' '; echo
done
