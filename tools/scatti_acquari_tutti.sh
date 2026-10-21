#!/bin/bash
# Tutti gli scatti della proposta degli acquari: UN processo di Godot per scatto (la memoria cresce a
# ogni scatto e la sala intera è al limite dei 12,5 GB). Salta gli scatti già fatti.
# Uso: tools/scatti_acquari_tutti.sh <cartella>
cd "$(dirname "$0")/.." || exit 1
OUT=$1; mkdir -p "$OUT"
BASE="Tecnici,Sala/TorreScivoli,BambiniBalconata"
SENZA_BIMBI="$BASE,Sala/AreaBimbi"   # dalla posizione 2 e dal portone l'area bimbi non si vede
corri() {   # <togli> <giro> <file atteso>
	[ -f "$OUT/$3" ] && return
	SCATTI_TOGLI="$1" LOG="$OUT/../log_${3%.jpg}.log" bash tools/scatti_acquari.sh "$OUT" "$2" 36 \
		| grep -E "memoria|FERMATO|salvato|SCRIPT ERROR: P" | tr '\n' ' '; echo
}
for st in A B; do
	l=$([ $st = A ] && echo lampadine || echo gabbia)
	for c in uscita meta vicino; do
		corri "$BASE" "$st,1,$l,1,vuoto,$c" "${st}1_$c.jpg"
		corri "$SENZA_BIMBI" "$st,2,$l,1,vuoto,$c" "${st}2_$c.jpg"
	done
	corri "$BASE" "$st,1,$l,1,verde,dettaglio" "${st}1_dettaglio_verde.jpg"
	corri "$SENZA_BIMBI" "$st,2,$l,1,torbido,dettaglio" "${st}2_dettaglio_torbido.jpg"
	corri "$BASE" "$st,1,$l,1,vuoto,vicino,bassi" "${st}1_vicino_tuttibassi.jpg"
	corri "$BASE" "$st,1,$l,1,vuoto,disegno_$st" "${st}1_disegno_$st.jpg"
done
for l in lampadine gabbia; do
	corri "$SENZA_BIMBI" "A,2,$l,0,vuoto,portone" "portone_${l}_spente.jpg"
	corri "$SENZA_BIMBI" "A,2,$l,1,vuoto,portone" "portone_${l}_accese.jpg"
done
echo TUTTI_FINITI
