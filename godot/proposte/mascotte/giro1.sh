#!/bin/bash
# Primo giro di posti per le tre statue (nella luce della prima visita).
D=$(dirname "$0")
ST="statua_squalo_A@8.5,15.5@-67;statua_squalo_A@9.6,-4.5@-90;statua_squalo_A@3,-16.8@0"
ST+=";statua_polpo_A@-9.5,11.5@50;statua_polpo_A@-11.5,15@-39;statua_polpo_A@-7.5,-17@0"
ST+=";statua_polpo_B@-18.3,-8@90;statua_polpo_B@9.5,-15.5@-45;statua_polpo_B@14.5,1@-90"
SC="squalo_1_ingresso:0,0,19.2:5,1.2,15:0;squalo_2_bordo_est:6.2,0,9:9.6,1.2,-4.5:1;squalo_3_spiaggia:2,-0.15,-11:3,1.2,-16.8:2"
SC+=";polpo_A_1_ingresso:0,0,19.2:-9.5,1.2,11.5:3;polpo_A_2_serranda:-15,0,19:-11.5,1.2,15:4;polpo_A_3_bimbi:-8.5,0,-4:-7.5,1.2,-17:5"
SC+=";polpo_B_1_bimbi:-8.3,0,-4:-18.3,1.2,-8:6;polpo_B_2_spiaggia_est:8.5,0,-6:9.5,1.2,-15.5:7;polpo_B_3_solarium:6.5,0,7:14.5,1.2,1:8"
SC+=";pianta:0,3.6,1:46,0,0"
SCATTI_TOGLI=Tecnici "$D/scatti_statue.sh" "$1" "$ST" "$SC" 90
