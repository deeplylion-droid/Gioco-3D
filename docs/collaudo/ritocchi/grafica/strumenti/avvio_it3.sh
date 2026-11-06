#!/bin/bash
L=/home/user/collaudo_log/gr; U=$L/avvio; export XDG_DATA_HOME=$U/xdg
SEGNO="$U/xdg/godot/app_userdata/Jilly Jubilee/sessione_aperta"
Xvfb :78 -screen 0 1280x720x24 >/dev/null 2>&1 & XP=$!; sleep 3; export DISPLAY=:78
cd /home/user/wt/collaudo/godot
segno() { test -f "$SEGNO" && echo c\'è || echo non c\'è; }
foto() { import -window root $U/$1.png; }
parti() { godot --path . --rendering-driver vulkan --resolution 1280x720 > $U/$1.log 2>&1 & GP=$!; sleep $2; foto $1; echo "== $1: segno $(segno)"; }
tasti() { /tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xv/bin/python $L/tasti.py :78 "$@" | tr '\n' ' '; echo; }
aspetta_uscita() { local t0=$(date +%s); while kill -0 $GP 2>/dev/null && [ $(($(date +%s)-t0)) -lt 300 ]; do sleep 2; done; if kill -0 $GP 2>/dev/null; then echo "   NON esce in 300 s: ucciso"; kill -9 $GP; else echo "   uscito da Esci dopo $(($(date +%s)-t0)) s: segno $(segno)"; fi; }
aspetta() { until [ $(awk '/MemAvailable/{print $2}' /proc/meminfo) -ge 13500000 ]; do sleep 5; done; }
(
flock 9
aspetta; LINGUA=it parti 10_italiano_domanda 90
tasti Down; sleep 2; tasti Return; sleep 8; foto 10c_titolo
tasti Down Down Down; sleep 2; foto 10d_su_esci; tasti Return; aspetta_uscita
aspetta; LINGUA=it parti 11_italiano_dopo_esci 90
tasti Down Down Down; sleep 2; foto 11b_su_esci; tasti Return; aspetta_uscita
) 9>/home/user/tools/render.lock
kill $XP
echo "AVVIO IT3 FINITO"
