#!/bin/bash
# Terzo giro: due inquadrature rifatte (luce della prima visita) e i posti del ritorno al buio
# (tappa 7: serranda e area bimbi) con le luci in blackout.
D=$(dirname "$0")
ST="statua_squalo_A@7.2,15.6@-70;statua_polpo_A@-11.5,15@-39;statua_polpo_A@-5.5,-18@-12;statua_polpo_B@-18.3,-8@90"
SCATTI_TOGLI=Tecnici "$D/scatti_statue.sh" "$1" "$ST" \
	"squalo_1_ingresso:1.5,0,17.6:7.2,1.2,15.6:0;polpo_A_3_bimbi:-6.2,0,-9.5:-5.5,1.2,-18:2" 25
LOG=/tmp/scatti_statue_buio.log SCATTI_LUCI=BLACKOUT SCATTI_TOGLI=Tecnici "$D/scatti_statue.sh" "$1" "$ST" \
	"polpo_A_2_serranda_buio:-15,0,19:-11.5,1.2,15:1;polpo_B_1_bimbi_buio:-8.3,0,-4:-18.3,1.2,-8:3" 25
