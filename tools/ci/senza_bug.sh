#!/usr/bin/env bash
# Lancia un comando (un test col renderer Vulkan) e fallisce anche se nell'uscita c'è una riga "ERROR: BUG,": un
# errore interno del motore, come "BUG, indexing did not unpair geometries from light" (25 ottobre), che a volte non fa
# crashare il test ma nel gioco può diventare un crash quando si libera una zona.
# Uso: tools/ci/senza_bug.sh xvfb-run ... godot ... --script res://tests/run.gd -- res://tests/<test>.gd
log=$(mktemp)
"$@" 2>&1 | tee "$log"
codice=${PIPESTATUS[0]}
if grep -n "ERROR: BUG," "$log" > "$log.bug"; then
	echo "::error::Errore interno del motore (ERROR: BUG,) in: $*"
	head -20 "$log.bug"
	exit 1
fi
exit "$codice"
