#!/bin/bash
# Il nome JILLY JUBILEE nella sala: targa sul lato ovest della vasca della medusa (sul lato sud
# un tentacolo la copriva), manifesto sul muro ovest vicino all'ingresso, insegna sopra la vasca
# d'arrivo. Ogni posto nei due stili (a = bolle, b = corsivo). Due scatti per processo: con più
# inquadrature la memoria supera i 13 GB.
D=$(dirname "$0")
J=proposte/mascotte/jilly
ST="muro=$J/targa_a.glb@-3.6,0.8,10@1,0,0;muro=$J/targa_b.glb@-3.6,0.8,10@1,0,0"
ST+=";muro=$J/manifesto_a.glb@-17,1.55,13@-1,0,0;muro=$J/manifesto_b.glb@-17,1.55,13@-1,0,0"
ST+=";muro=$J/insegna_a.glb@-17,3.4,2@-1,0,0;muro=$J/insegna_b.glb@-17,3.4,2@-1,0,0"
for SC in "jilly_targa_a:-6.6,0,13.6:-3,0.8,10:0;jilly_targa_b:-6.6,0,13.6:-3,0.8,10:1" \
	"jilly_manifesto_a:-15.6,0,11.6:-19.9,1.5,13:2;jilly_manifesto_b:-15.6,0,11.6:-19.9,1.5,13:3" \
	"jilly_insegna_a:-7.6,0,6:-19.9,3.2,2:4;jilly_insegna_b:-7.6,0,6:-19.9,3.2,2:5"; do
	SCATTI_TOGLI=Tecnici "$D/scatti_statue.sh" "$1" "$ST" "$SC" ${2:-25}
done
