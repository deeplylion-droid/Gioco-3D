# Gioco vero senza --script, input veri XTEST. Uso: bash vero.sh <nome> <cartella_xdg> <"godot --path ." o exe> [LINGUA]
L=/home/user/collaudo_log; U=$L/m22/vero; mkdir -p $U; N=$1; XDG=$2; BIN=$3; LG=$4
PY="/tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xv/bin/python /tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xin.py :121 $U"
Xvfb :121 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 & XP=$!; sleep 2
cd /home/user/wt/collaudo/godot
lancia() { DISPLAY=:121 XDG_DATA_HOME=$XDG LINGUA=$LG $BIN --rendering-driver vulkan --resolution 1280x720 > $U/$1.log 2>&1 & G=$!; echo "lanciato $1 pid $G"; }
vivo() { kill -0 $G 2>/dev/null && echo "VIVO $1" || echo "MORTO $1"; }
utente() { ls "$XDG/godot/app_userdata/Jilly Jubilee/" 2>/dev/null | tr '\n' ' '; echo; }
mkdir -p "$XDG"
echo "cartella utente prima: $(utente)"
lancia ${N}_1; sleep 50; $PY "s ${N}_01_titolo"; vivo titolo
echo "cartella utente: $(utente)"; cp "$XDG/godot/app_userdata/Jilly Jubilee/settings.cfg" $U/${N}_settings_1.cfg 2>/dev/null
# mouse: Opzioni, Audio, cursori, altre schede, Esc, molte volte
$PY "c 140 401; w 2; s ${N}_02_opzioni; c 898 162; w 1; s ${N}_03_audio; d 923 212 800 212; w 0.6; s ${N}_04_audio_cursore"
for i in 1 2 3 4 5 6 7 8; do $PY "c 326 162; w 0.3; c 898 162; w 0.3; d 882 246 760 246; c 808 162; w 0.3; c 898 162; w 0.3; c 904 384; w 0.3; k Escape; w 1.2; c 140 401; w 1.2; c 898 162; w 0.5; k Escape; w 1" > /dev/null; done
vivo "dopo il mouse"; $PY "s ${N}_05_dopo_mouse"
# tastiera: frecce dal titolo e nelle opzioni
$PY "c 140 401; w 2; k Up 2; k Right 6; w 0.5; s ${N}_06_tastiera_destra; k Down 2; k Left 3; k Right 3; w 0.5; s ${N}_07_tastiera_cursore; k Escape; w 1.5" > /dev/null
for i in 1 2 3 4; do $PY "c 140 401; w 1.5; k Up 2; k Right 6; k Down; k Left 2; k Up; k Left 3; k Right 3; k Escape; w 1.2" > /dev/null; done
vivo "dopo la tastiera"; $PY "s ${N}_08_dopo_tastiera"
if [ "$5" = "kill" ]; then
  [ -f "$XDG/godot/app_userdata/Jilly Jubilee/sessione_aperta" ] || { echo "SEGNO MANCANTE prima del kill: salto l avvio sicuro"; kill $G; kill $XP; exit 0; }
  kill -9 $G; sleep 2; echo "ucciso con kill -9; cartella utente: $(utente)"
  lancia ${N}_2; sleep 50; $PY "s ${N}_10_dopo_kill"; vivo "dopo kill"
  $PY "k Return; w 3; s ${N}_11_risposta; c 140 401; w 2; s ${N}_12_opzioni_dopo; c 326 162; w 1; s ${N}_13_schermo; k Escape; w 1.5" > /dev/null
  cp "$XDG/godot/app_userdata/Jilly Jubilee/settings.cfg" $U/${N}_settings_2.cfg 2>/dev/null
fi
# esci col pulsante: il segno della sessione si deve cancellare
$PY "k Escape; w 1; c 116 516; w 6" > /dev/null; vivo "dopo Esci"
echo "cartella utente alla fine: $(utente)"
kill $G 2>/dev/null; kill $XP; wait 2>/dev/null
echo "VERO FINITO $N"
