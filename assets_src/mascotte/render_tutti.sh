#!/bin/bash
# Render finali delle sei varianti (uno alla volta, sotto render.lock).
cd "$(dirname "$0")/../.."
O=docs/proposte/mascotte
R="nice -n 10 /home/user/tools/blender-venv/bin/python assets_src/mascotte/render_mascotte.py"
G=assets_src/mascotte/gen
while read nome glb opz; do
  [ -f $O/${nome}_buio.jpg ] && continue
  flock /home/user/tools/render.lock $R $G/$glb $O/$nome $opz 2>&1 | grep -E "MODELLO|RENDER|Error"
done <<LISTA
statua_squalo_A 3d_squalo_a_nbp.glb --altezza 2.3 --dettaglio 0.8
statua_squalo_B 3d_squalo_b_nbp.glb --altezza 2.3 --dettaglio 0.8
statua_polpo_A 3d_polpo_a_nbp.glb --altezza 2.3 --dettaglio 0.78
statua_polpo_B 3d_polpo_b_nbp.glb --altezza 2.3 --dettaglio 0.78
mostro_squalo_A 3d_mostro_a2_gpt.glb --altezza 2.2 --dettaglio 0.7 --bagnato 0.4
mostro_squalo_B 3d_mostro_b_nbp.glb --altezza 2.2 --dettaglio 0.66 --bagnato 0.5
statua_squalo_A_nuova ritex_nuova_squalo_a.glb --altezza 2.3 --viste tre_quarti,buio
statua_squalo_B_nuova ritex_nuova_squalo_b.glb --altezza 2.3 --viste tre_quarti,buio
statua_polpo_A_nuova ritex_nuova_polpo_a.glb --altezza 2.3 --viste tre_quarti,buio
statua_polpo_B_nuova ritex_nuova_polpo_b.glb --altezza 2.3 --viste tre_quarti,buio
LISTA
