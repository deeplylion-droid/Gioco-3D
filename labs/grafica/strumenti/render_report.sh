#!/usr/bin/env bash
# Rigenera screenshot e video del report: docs/report/render_grafica/.
# Uso: bash labs/grafica/strumenti/render_report.sh [nome...]   (senza nomi: tutti)
# Gira su llvmpipe (Vulkan software): ogni immagine 1280x720 richiede 1-3 minuti.
set -u
cd "$(dirname "$0")/.."
OUT="$(cd ../.. && pwd)/docs/report/render_grafica"
mkdir -p "$OUT"
RES=1280x720

shot() {  # nome, argomenti...
  local nome=$1; shift
  if [ -n "${SOLO:-}" ] && [[ " $SOLO " != *" $nome "* ]]; then return; fi
  echo ">> $nome"
  xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
    --resolution $RES --fixed-fps 30 -- "$@" --out="$OUT/$nome.jpg" 2>&1 | grep -E "salvato|SCRIPT ERROR" || true
}

video() {  # nome, fotogrammi, argomenti...
  local nome=$1 frames=$2; shift 2
  if [ -n "${SOLO:-}" ] && [[ " $SOLO " != *" $nome "* ]]; then return; fi
  echo ">> video $nome"
  local tmp; tmp=$(mktemp -d)
  xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
    --resolution 854x480 --fixed-fps 24 --write-movie "$tmp/f.png" -- --video=1 --frames="$frames" "$@" 2>&1 | grep -E "SCRIPT ERROR" || true
  /home/user/tools/blender-venv/bin/python strumenti/componi_video.py "$tmp" "$OUT/$nome"
  rm -rf "$tmp"
}

SOLO="$*"
shot preset_basso      --preset=basso --inq=sala --torcia=1 --frames=40
shot preset_ultra      --preset=ultra --inq=sala --torcia=1 --frames=40
shot torcia_spenta     --preset=alto --inq=buio --buio=1 --torcia=0 --frames=30
shot torcia_accesa     --preset=alto --inq=buio --buio=1 --torcia=1 --frames=30
shot torcia_corridoio  --preset=alto --inq=corridoio --buio=1 --torcia=1 --frames=30
shot lampo_cupola      --preset=alto --inq=cupola --frames=31 --lampo=29 --azimut=170
shot lampo_sala        --preset=alto --inq=sala --frames=31 --lampo=29 --azimut=200
shot nebbia_luci       --preset=ultra --inq=nebbia --frames=40
shot nebbia_corridoio  --preset=ultra --inq=corridoio --frames=40
shot gi_nessuna        --preset=alto --inq=piedistallo --set=gi:0 --frames=40
shot gi_voxelgi        --preset=alto --inq=piedistallo --set=gi:1 --frames=40
shot gi_sdfgi          --preset=alto --inq=piedistallo --set=gi:2 --frames=60
shot menu_resa         --preset=alto --inq=sala --frames=24 --menu=1
shot menu_luci         --preset=alto --inq=sala --frames=24 --menu=2
shot calibrazione      --preset=alto --inq=sala --frames=14 --calibrazione=1
video lampi_cupola 168 --preset=alto --inq=cupola --lampi=12,80,140 --seme=4
video neon_corridoio 144 --preset=alto --inq=corridoio --seme=5
