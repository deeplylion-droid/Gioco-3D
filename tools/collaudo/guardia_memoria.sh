#!/bin/bash
# Collaudo: uccide i processi godot sopra il limite di memoria (kB di RSS, di serie 11,5 GB), per non far ripartire la
# macchina da 15 GB quando una scena intera sul renderer software cresce troppo. Uso: guardia_memoria.sh [limite in kB] &
LIM=${1:-11500000}
while true; do
  for p in $(pgrep -x godot); do
    r=$(awk '/VmRSS/{print $2}' /proc/$p/status 2>/dev/null)
    if [ -n "$r" ] && [ "$r" -gt "$LIM" ]; then echo "$(date +%T) ucciso godot $p con RSS $r kB"; kill -9 $p; fi
  done
  sleep 2
done
