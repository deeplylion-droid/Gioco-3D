#!/bin/bash
# Gli scatti dei posti delle statue e dei nomi JILLY JUBILEE rifatti senza torcia (tolta dal gioco,
# v0.3.6): stessi punti, solo la luce della sala. Un solo scatto per processo e controllo a 12,3 GB:
# con due inquadrature la sala arriva vicino al limite della macchina, che è ripartita due volte.
# Gli scatti già presenti nella cartella si saltano.
# Uso: senza_torcia.sh <cartella statue> <cartella nomi>
D=$(dirname "$0")
export SCATTI_TORCIA=0 LIMITE_MB=12300
uno() {   # <cartella> <statue> <togli> <scatto>
	[ -f "$1/${4%%:*}.jpg" ] && return
	SCATTI_TOGLI=$3 "$D/scatti_statue.sh" "$1" "$2" "$4" 25 | grep -v MURO
}
ST="statua_squalo_A@7.2,15.6@-70;statua_squalo_A@10,1.5@-90;statua_squalo_A@3,-16.8@0"
ST+=";statua_polpo_A@-7.5,14.5@55;statua_polpo_A@-11.5,15@-39;statua_polpo_A@-5.5,-18@-12"
ST+=";statua_polpo_B@-18.3,-8@90;statua_polpo_B@9.5,-15.5@-45;statua_polpo_B@14.5,1@-90"
# v0.3.6 pesa di più: si tolgono anche le creature e l'enigma che nella prima visita non si vedono
# (al buio della tappa 7 resta la medusa della fossa; la vasca centrale è già vuota, come nel gioco)
G=Gioco/BambiniBalconata,Gioco/EnigmaAcquari,Gioco/MedusaFossa,Gioco/LeiSbuca
T=Tecnici,$G; TT=Tecnici,Sala/TorreScivoli,$G; TB=Tecnici,Sala/TorreScivoli,Gioco/BambiniBalconata,Gioco/EnigmaAcquari,Vasca/Medusa
uno "$1" "$ST" $T "squalo_2_bordo_est:5.5,0,9.2:10,1.2,1.5:1"
uno "$1" "$ST" $T "polpo_B_3_solarium:6.5,0,7:14.5,1.2,1:8"
uno "$1" "$ST" $T "squalo_3_spiaggia:2,-0.15,-11:3,1.2,-16.8:2"
uno "$1" "$ST" $T "polpo_B_2_spiaggia_est:8.5,0,-6:9.5,1.2,-15.5:7"
uno "$1" "$ST" $TT "squalo_1_ingresso:1.5,0,17.6:7.2,1.2,15.6:0"
uno "$1" "$ST" $TT "polpo_A_1_ingresso:1,0,18.8:-7.5,1.2,14.5:3"
uno "$1" "$ST" $TT "polpo_A_2_serranda:-15,0,19:-11.5,1.2,15:4"
uno "$1" "$ST" $TT "polpo_A_3_bimbi:-6.2,0,-9.5:-5.5,1.2,-18:5"
uno "$1" "$ST" $TT "polpo_B_1_bimbi:-8.3,0,-4:-18.3,1.2,-8:6"
SCATTI_LUCI=BLACKOUT uno "$1" "$ST" $TB "polpo_A_2_serranda_buio:-15,0,19:-11.5,1.2,15:4"
SCATTI_LUCI=BLACKOUT uno "$1" "$ST" $TB "polpo_B_1_bimbi_buio:-8.3,0,-4:-18.3,1.2,-8:6"
# i nomi: le stesse posizioni di giro_jilly.sh
J=proposte/mascotte/jilly
eval "$(sed -n '/^ST=/p;/^ST+=/p' "$D/giro_jilly.sh")"
uno "$2" "$ST" $T "jilly_targa_a:-5.4,0,11.3:-2.95,0.8,10:0"
uno "$2" "$ST" $T "jilly_targa_b:-5.4,0,11.3:-2.95,0.8,10:1"
uno "$2" "$ST" $TT "jilly_manifesto_a:-15.6,0,12.2:-19.9,1.5,13.95:2"
uno "$2" "$ST" $TT "jilly_manifesto_b:-15.6,0,12.2:-19.9,1.5,13.95:3"
uno "$2" "$ST" $TT "jilly_insegna_a:-13.5,0,7.8:-19.9,4.1,5.35:4"
uno "$2" "$ST" $TT "jilly_insegna_b:-13.5,0,7.8:-19.9,4.1,5.35:5"
