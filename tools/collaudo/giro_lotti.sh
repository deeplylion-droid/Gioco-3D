#!/bin/bash
# Collaudo: il giro dagli occhi (godot/tests/collaudo/giro.gd) a lotti di righe, con i materiali semplici
# (COLLAUDO_SEMPLICE=1), ogni lotto in un processo Godot suo sotto render.lock: la sala intera sul renderer
# software non sta in memoria in un colpo solo. Due tentativi per lotto.
# Uso: giro_lotti.sh <scena> <stato> <cartella scatti> <lista> <togli> [righe per lotto, 200]
set -u
scena=$1; stato=$2; cart=$3; lista=$(realpath "$4"); togli=$5; n=${6:-200}
lotti=$(mktemp -d)
split -l "$n" -d "$lista" "$lotti/$(basename "$lista")."
cd "$(dirname "$0")/../../godot"
for f in "$lotti"/*; do
  for t in 1 2; do
    COLLAUDO_SEMPLICE=1 flock /home/user/tools/render.lock xvfb-run -a -s '-screen 0 640x360x24' godot --path . \
      --rendering-driver vulkan --fixed-fps 60 --resolution 640x360 --script res://tests/run.gd -- \
      res://tests/collaudo/giro.gd "$scena" "$stato" "$cart" "$f" "$togli" > "$f.log" 2>&1
    if grep -q "COLLAUDO: finito" "$f.log"; then echo "lotto $(basename "$f"): $(grep 'COLLAUDO: finito' "$f.log")"; break; fi
    echo "lotto $(basename "$f"): fallito (tentativo $t), log in $f.log"
  done
done
echo "GIRO FINITO"
