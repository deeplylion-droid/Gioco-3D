#!/bin/bash
cd /home/user/Gioco-3D
R=/tmp/claude-0/-home-user-Gioco-3D/5a8d173d-7f43-5afd-9c0f-94715580b1c8/scratchpad/ric_as
export XDG_DATA_HOME=$R/dati
U="$XDG_DATA_HOME/godot/app_userdata/Jilly Jubilee"
Xvfb :78 -screen 0 1280x720x24 > /dev/null 2>&1 &
XP=$!
sleep 3
export DISPLAY=:78
stato() { echo "$1: segno $( [ -f "$U/sessione_aperta" ] && echo SI || echo no ), $(grep -E '^(preset|calibrato)=' "$U/settings.cfg" 2>/dev/null | tr '\n' ' ')"; }
foto() { import -window root -display :78 $R/$1.png; }
tasto() { W=$(xdotool search --name "Jilly" | head -1); xdotool windowfocus --sync $W 2>/dev/null; xdotool key --window $W --delay 200 $@; }
parti() { godot --path godot --rendering-driver vulkan --resolution 1280x720 > $R/$1.log 2>&1 & G=$!; sleep 90; }
# A: primo avvio, chiusura di colpo senza confermare la luminosità
parti A; foto A_90s; stato "A prima della chiusura"; kill -9 $G; sleep 3; stato "A dopo kill"
# B: luminosità non confermata + chiusura di colpo prima
parti B; foto B_1_aperta; stato "B aperta"
tasto Return; sleep 8; foto B_2_dopo_invio; stato "B dopo Invio"
# C: seconda chiusura di colpo con la domanda aperta
kill -9 $G; sleep 3; stato "B dopo kill con la domanda aperta"
parti C; foto C_1_aperta; stato "C aperta (luminosità confermata)"
tasto Down Return; sleep 8; foto C_2_dopo_avvio_normale; stato "C dopo Avvio normale"
kill -9 $G; sleep 2
kill $XP
