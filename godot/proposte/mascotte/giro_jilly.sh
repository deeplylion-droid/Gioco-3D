#!/bin/bash
# Il nome JILLY JUBILEE nella sala: targa sul lato ovest della vasca della medusa (sul lato sud
# un tentacolo la copriva), manifesto sul muro ovest vicino all'ingresso, insegna sul muro
# ovest, tra due oblò e sopra il tubo (prima copriva un oblò e il tubo). Ogni posto nei due stili
# (a = bolle, b = corsivo). Due scatti per processo: con più inquadrature la memoria supera i 13 GB.
D=$(dirname "$0")
J=proposte/mascotte/jilly
ST="muro=$J/targa_a.glb@-3.6,0.62,10@1,0,0;muro=$J/targa_b.glb@-3.6,0.62,10@1,0,0"
ST+=";muro=$J/manifesto_a.glb@-17,1.4,13.95@-1,0,0@0.03;muro=$J/manifesto_b.glb@-17,1.4,13.95@-1,0,0@0.03"
ST+=";muro=$J/insegna_a.glb@-17,4.7,5.35@-1,0,0;muro=$J/insegna_b.glb@-17,4.7,5.35@-1,0,0"
ST+=";muro=$J/insegna_luce_a.glb@-17,4.7,5.35@-1,0,0;muro=$J/insegna_luce_b.glb@-17,4.7,5.35@-1,0,0"
for SC in "jilly_targa_a:-5.4,0,11.3:-2.95,0.65,10:0;jilly_targa_b:-5.4,0,11.3:-2.95,0.65,10:1" \
	"jilly_manifesto_a:-15.6,0,12.2:-19.9,1.5,13.95:2;jilly_manifesto_b:-15.6,0,12.2:-19.9,1.5,13.95:3" \
	"jilly_insegna_a:-13.5,0,7.8:-19.9,4.1,5.35:4;jilly_insegna_b:-13.5,0,7.8:-19.9,4.1,5.35:5"; do
	TOGLI=Tecnici
	# sul muro ovest la torre degli scivoli (lato est) non si vede: si toglie per stare nella memoria
	case "$SC" in jilly_targa*) ;; *) TOGLI=Tecnici,Sala/TorreScivoli ;; esac
	SCATTI_TOGLI=$TOGLI "$D/scatti_statue.sh" "$1" "$ST" "$SC" ${2:-25}
done
