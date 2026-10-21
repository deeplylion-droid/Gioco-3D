#!/bin/bash
# Secondo giro: posti corretti dopo il primo (squalo 2 era dietro la sedia del bagnino, polpo A 3
# toccava la vasca bimbi 2). Luce della prima visita.
D=$(dirname "$0")
ST="statua_squalo_A@7.2,15.6@-70;statua_squalo_A@10,1.5@-90;statua_squalo_A@3,-16.8@0"
ST+=";statua_polpo_A@-7.5,14.5@55;statua_polpo_A@-11.5,15@-39;statua_polpo_A@-5.5,-18@-12"
ST+=";statua_polpo_B@-18.3,-8@90;statua_polpo_B@9.5,-15.5@-45;statua_polpo_B@14.5,1@-90"
SC="pianta:0,3.6,1:46,0,0"
SC+=";squalo_1_ingresso:-1.5,0,18.6:7.2,1.2,15.6:0;squalo_2_bordo_est:5.5,0,9.2:10,1.2,1.5:1"
SC+=";polpo_A_1_ingresso:1,0,18.8:-7.5,1.2,14.5:3;polpo_A_3_bimbi:-8.5,0,-4:-5.5,1.2,-18:5"
SC+=";polpo_B_2_spiaggia_est:8.5,0,-6:9.5,1.2,-15.5:7;polpo_B_3_solarium:6.5,0,7:14.5,1.2,1:8"
SCATTI_TOGLI=Tecnici "$D/scatti_statue.sh" "$1" "$ST" "$SC" ${2:-25}
