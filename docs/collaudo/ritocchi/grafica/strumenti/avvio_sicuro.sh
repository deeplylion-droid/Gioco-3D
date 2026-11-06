#!/bin/bash
# Avvio sicuro dal gioco vero (senza --script), sul titolo: avvio pulito, ucciso, riavvio (domanda?), chiuso
# normale, riavvio (niente domanda), poi in inglese.
L=/home/user/collaudo_log/gr; U=$L/avvio; mkdir -p $U; rm -rf $U/xdg; mkdir -p "$U/xdg/godot/app_userdata/Jilly Jubilee"
cp "/home/user/collaudo_log/g20/xdg/godot/app_userdata/Jilly Jubilee/settings.cfg" "$U/xdg/godot/app_userdata/Jilly Jubilee/"
export XDG_DATA_HOME=$U/xdg
SEGNO="$U/xdg/godot/app_userdata/Jilly Jubilee/sessione_aperta"
Xvfb :77 -screen 0 1280x720x24 >/dev/null 2>&1 & XP=$!; sleep 3; export DISPLAY=:77
cd /home/user/wt/collaudo/godot
parti() { godot --path . --rendering-driver vulkan --resolution 1280x720 > $U/$1.log 2>&1 & GP=$!; sleep $2; import -window root $U/$1.png; echo "== $1: segno $(test -f "$SEGNO" && echo c\'è || echo non c\'è)"; }
aspetta() { until [ $(awk '/MemAvailable/{print $2}' /proc/meminfo) -ge 13500000 ]; do sleep 5; done; }
(
flock 9
aspetta; parti 1_primo 60; kill -9 $GP; sleep 3; echo "   ucciso: segno $(test -f "$SEGNO" && echo c\'è || echo non c\'è)"
aspetta; parti 2_dopo_ucciso 60; /tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xv/bin/python $L/chiudi.py :77; sleep 15; kill -0 $GP 2>/dev/null && { echo "   ancora vivo dopo la X: ucciso"; kill -9 $GP; }; echo "   chiuso con la X: segno $(test -f "$SEGNO" && echo c\'è || echo non c\'è)"
aspetta; parti 3_dopo_chiuso 60; kill -9 $GP; sleep 3
aspetta; LINGUA=en parti 4_inglese 60; /tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xv/bin/python $L/chiudi.py :77; sleep 15; kill -0 $GP 2>/dev/null && kill -9 $GP
) 9>/home/user/tools/render.lock
kill $XP
echo "AVVIO FINITO"
