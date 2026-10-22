# Lei nell'inseguimento: le animazioni (controllo del 22 ottobre)

Dal motore, nella sala dell'inseguimento vera (SalaInseguimento da sola, con l'ambiente della sala grande), con
le inquadrature degli scatti di ambienti-2. Strumento: `godot/proposte/mascotte/video_lei_inseguimento.gd`. Solo
per il controllo del coordinatore. Il video e' senza audio: lei non ha ancora suoni per queste animazioni.

| File | Cosa |
| --- | --- |
| `1_sale_1.0s.jpg` | vasca 1: sale dall'acqua, la testa per prima, le braccia lungo i fianchi |
| `2_incombe_3.0s.jpg` | incombe: si sporge con le braccia tese, la testa segue la camera |
| `3_respinta_4.3s.jpg` | il getto in faccia: si copre il viso e torna sotto |
| `4_presa_9.2s.jpg` | la presa: si tira indietro e scatta in avanti ad afferrare |
| `5_colpo_grata.jpg` | dietro la grata calata: carica e sbatte i palmi contro le sbarre (tre colpi) |
| `6_sb1_ti_fissa.jpg` | SB1: aggrappata al bordo del pozzo, la testa girata verso di te, ti fissa |
| `7_vasca_dettagli.jpg` | la vasca ingrandita: sale, incombe, respinta, presa, scende |
| `lei_inseguimento_senza_audio.mp4` | tutto (23,7 s): vasca (sale, incombe, respinta; sale, incombe, presa; sale, incombe, scende), grata, SB1 |

Come sono fatte e come si agganciano: `godot/assets/models/medusa/LEGGIMI.md`, "Animazioni dell'inseguimento".
Test: `godot/tests/test_lei_animazioni.gd`.

## Aggancio nel gioco (22 ottobre, pomeriggio)

Le animazioni sono agganciate in `sala_inseguimento.gd`. Scatti dal motore con le inquadrature di ambienti-2
(`godot/tests/scatti_inseguimento.gd`, ora con le animazioni), in `giro/`:
`1_primo_bivio`, `2_lei_ti_raggiunge` (incombe nella vasca 1), `4_grata` (il colpo contro la grata),
`5_sb1` (aggrappata allo spigolo del pozzo dalla parte del giocatore), `7_nel_tubo`.

Dove lei attraversa qualcosa, posto per posto (`godot/proposte/mascotte/sonda_lei_inseguimento.gd`: un raggio lungo
ogni osso, fotogramma per fotogramma, contro le collisioni della sala):
- vasca 1: niente. Lei sta fuori dalla vasca sospesa, accanto al bordo ovest, e sale dal buio sotto la vasca;
- vasca 2 (sulla condotta nord): i tentacoli passano nel muro nord (y 32) e, salendo e scendendo, nei grigliati a
  quota -24;
- vasca 3 (2,3 m a sud della vasca): i tentacoli passano nel muro sud (y -2); all'inizio della salita e alla fine
  della discesa le punte vanno sotto il fondo della sala allagata (-34), sott'acqua;
- vasche di scolo: 0, nella presa le dita entrano nel bordo della vasca; 1, braccia e petto attraversano la
  parete della vasca mentre incombe e prende; 2, salendo parte da sotto il fondo della sala;
- grata: lei sta sul fondo della sala (-34): salendo parte da 5 m sotto il pavimento; i tentacoli passano nel
  tubo 3 mentre sbatte;
- SB1: il pozzo e' profondo 5,2 m sotto il bordo, lei salendo parte da 8,9 m sotto: all'inizio attraversa il
  fondo del pozzo.

Le misure: all'inizio della salita lei va da 4,8 m sotto la sua origine a 0,2 m sotto; da su, le punte dei
tentacoli arrivano all'altezza dell'origine e la testa a 5,3 m sopra. Perche' salga dall'acqua senza vedersi
all'inizio e senza toccare il fondo servono circa 5 m d'acqua sotto il suo posto: la superficie almeno all'altezza
della sua origine "su" e il fondo almeno 5 m piu' giu'.

## Compenetrazioni corrette (22 ottobre, sera)

Controllo con la sonda (`godot/proposte/mascotte/sonda_lei_inseguimento.gd`), contando solo quello che il
giocatore puo' vedere: sopra il fondo della vasca dove sta lui (vasche e scolo) o sopra il pelo dell'acqua scura
(grata, SB1).

| Posto | Prima | Ora | Cosa ho fatto |
| --- | --- | --- | --- |
| vasca 1 | 0 | 0 | niente |
| vasca 2 | tentacoli nel muro nord e nei grigliati | uguale | da decidere (vedi sotto) |
| vasca 3 | tentacoli nel muro sud, punte sotto il pavimento | 0 visibili | sale da 2,9 m invece che da 5 (l'inizio resta dietro la vasca); tentacoli piu' raccolti nella presa, nella respinta e alla grata. Restano 10 incroci sotto il fondo della vasca, che da dentro non si vedono |
| scolo 0 | dita nel bordo nella presa | 0 | 25 cm piu' lontana dalla vasca |
| scolo 1 | braccia e petto nella parete e nel tubo | 0 visibili | sale da 2,7 m (l'inizio resta sotto il fondo della vasca) e 1,6 m piu' indietro dallo stesso lato; restano 2 incroci sotto il fondo della vasca |
| scolo 2 | sale da sotto il pavimento | 0 visibili | niente: tutto sotto il fondo della vasca, da dentro non si vede |
| grata | sale da sotto il pavimento, sta nello sbocco del tubo 3 | uguale | da decidere (vedi sotto) |
| SB1 | attraversa il fondo del pozzo all'inizio | 0 visibili | sale da 1,25 m: parte gia' sott'acqua nel pozzo (0,5 m sotto il pelo) |

Scatti dei posti cambiati in `giro/`: `9_vasca_3` (dal giocatore nella vasca), `9b_scolo_0` e `9c_scolo_1` (da
fuori: le vasche di scolo sono chiuse e buie dentro).
