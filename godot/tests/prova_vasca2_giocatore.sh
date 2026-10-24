#!/bin/bash
# Lei che sale in vasca_2 con il giocatore in 5 punti della vasca 3 (dove sta nel gioco quando lei sale lì: lei si gira
# verso di lui), più il punto del test. Per ognuno: vertici della pelle dentro e tratti dell'asse che attraversano.
# Uso, dalla radice del repo: bash godot/tests/prova_vasca2_giocatore.sh   (circa 30 s a punto, uno alla volta col flock)
cd "$(dirname "$0")/.."
for g in "" "69.5,-27.6,-5" "66.7,-27.6,-2.2" "72.3,-27.6,-2.2" "66.7,-27.6,-7.8" "72.3,-27.6,-7.8"; do
  echo "### giocatore ${g:-del test}"
  flock /home/user/tools/render.lock timeout 600 env SOLO=vasca_2 ${g:+GIOCATORE=$g} godot --headless --path . --fixed-fps 30 \
    --script res://tests/run.gd -- res://tests/test_morbidezza_inseguimento.gd 2>&1 \
    | grep -E "pelle vera:|pelle dentro di|KO|noto|RISULTATO" | grep -v "  at:"
done
