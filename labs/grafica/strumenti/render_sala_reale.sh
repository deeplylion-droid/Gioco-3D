#!/usr/bin/env bash
# Screenshot 1920x1080 "prima/dopo" della sala vera: docs/report/render_grafica/sala_reale/.
# Prima: bash strumenti/prepara_sala_reale.sh. Uso: bash strumenti/render_sala_reale.sh [nomi...]
set -u
cd "$(dirname "$0")/.."
OUT="$(cd ../.. && pwd)/docs/report/render_grafica/sala_reale"
mkdir -p "$OUT"
SOLO="$*"
shot() {
  local nome=$1; shift
  if [ -n "$SOLO" ] && [[ " $SOLO " != *" $nome "* ]]; then return; fi
  echo ">> $nome"
  timeout -k 5 3000 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
    --resolution 1920x1080 --fixed-fps 30 res://sala_reale/sala_reale.tscn -- "$@" --out="$OUT/$nome.jpg" 2>&1 \
    | grep -E "salvato|SCRIPT ERROR" || true
}
for v in ingresso piscina area_bimbi torre; do
  shot "dopo_$v" --look=dopo --vista=$v --frames=30
  shot "prima_$v" --look=prima --vista=$v --frames=30
done
shot dopo_lampo_ingresso --look=dopo --vista=ingresso --frames=31 --lampo=29 --azimut=200
shot dopo_sdfgi_piscina --look=dopo --vista=piscina --frames=60 --set=gi:2
shot dopo_senza_gi_piscina --look=dopo --vista=piscina --frames=30 --set=gi:0
