#!/bin/bash
# esegui.sh <caso> [etichetta]: un caso del collaudo del menu F9 (godot/tests/collaudo/collaudo_menu_f9.gd) in una
# cartella utente nuova e vuota, sotto il lucchetto dei processi pesanti, con almeno 13,5 GB liberi. Serve xdotool.
# Gli scatti e i log vanno in $CARTELLA (predefinita: /tmp/collaudo_menu_f9). Si lancia dalla radice del repository.
M=${CARTELLA:-/tmp/collaudo_menu_f9}
caso=$1; et=${2:-fix}
mkdir -p "$M/scatti_$et"
flock /home/user/tools/render.lock bash -c "
for i in \$(seq 120); do m=\$(awk '/MemAvailable/{print \$2}' /proc/meminfo); [ \$m -ge 14155776 ] && break; sleep 5; done
U=\$(mktemp -d $M/utente_XXXX)
XDG_DATA_HOME=\$U timeout 600 xvfb-run -a -s '-screen 0 1280x720x24' godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/collaudo_menu_f9.gd $M/scatti_$et $caso > $M/log_${et}_$caso.log 2>&1
echo \"caso $caso ($et): uscita \$?\"
rm -rf \$U"
grep -E "^  (OK|NO)|RISULTATO|SCRIPT ERROR|Parse Error|CLIC|CONTROLLO:" $M/log_${et}_$caso.log | cut -c1-220
