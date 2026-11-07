# Avvio sicuro dopo una chiusura di colpo: la domanda resta scura? risponde? scatti a intervalli
L=/home/user/collaudo_log; U=$L/m22/vero/diag; mkdir -p $U; XDG=$1; N=$2; TASTO=$3
PY="/tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xv/bin/python /tmp/claude-0/-home-user-Gioco-3D/f5e5d037-885d-5565-b3d5-b4de770f14f6/scratchpad/xin.py :123 $U"
ls "$XDG/godot/app_userdata/Jilly Jubilee/"
Xvfb :123 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 & XP=$!; sleep 2
cd /home/user/wt/collaudo/godot
DISPLAY=:123 XDG_DATA_HOME=$XDG godot --path . --rendering-driver vulkan --resolution 1280x720 > $U/$N.log 2>&1 & G=$!
for t in 20 30 40 50 60 75 90; do sleep 10; $PY "s ${N}_t$t" > /dev/null; done
$PY "$TASTO" ; echo "premuto $TASTO"
for t in 3 6 10 15 25 40; do sleep 3; $PY "s ${N}_dopo$t" > /dev/null; done
grep -n "preset" "$XDG/godot/app_userdata/Jilly Jubilee/settings.cfg"
$PY "c 140 401; w 3; s ${N}_opzioni; k Escape; w 2; s ${N}_titolo" > /dev/null
kill -0 $G && echo VIVO; kill $G; sleep 3; kill -9 $G 2>/dev/null; kill $XP
grep -v "ALSA\|^ *at:" $U/$N.log | tail -5
echo "DIAG FINITO $N"
