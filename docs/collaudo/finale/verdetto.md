# Passaggio finale: verdetto sul candidato v0.3.9

Candidato: `lavoro/godot` **ceaeacd0**. Squadra collaudo, 23 ottobre.

**Verdetto: nessun difetto.**

| Zona | Base | Come | Esito |
|---|---|---|---|
| Controllo della CI, tutto il gioco | ceaeacd0 | `controllo_posizionamento.gd` | 2 controlli ok, 0 casi nuovi, 25 già noti, 0 "da correggere" |
| Sala principale | 79c8fea, poi le correzioni assegnate | `finale/sala/difetti.md` | difetti girati e corretti (plafoniera, bava, fari a muro); la goccia non è un difetto |
| Torre e inseguimento | 7f24d91b, portali su ceaeacd0 | giro di 220 scatti, 259 vedute; 78 vedute dei pali dei portali su ceaeacd0 (`candidato/fogli/portali_vedute_*.jpg`) | i pali dei portali di partenza ora poggiano sulla grata della pedana |
| Sala pompe, camera delle onde, raccordo | 7f24d91b / d66f5da0, `FILTRO_2` su ceaeacd0 | 692 oggetti misurati, 120 vedute (`candidato/fogli/tecnici_vedute_*.jpg`) | tutto a posto; il tubo d'uscita di `FILTRO_2` ora entra di 25 cm nel filtro (da y -5,65 a -5,85, con la cima del filtro a -5,60) |
| Acquari | 7f24d91b | misure, stato ritorno | basi, coperchi, cavo a contatto |
| Fiume e capannone | 75784262 | 1712 oggetti misurati, 22 vedute (`fiume_fossa/fogli/fiume_lampade_capannone.jpg`) | le 8 lampade toccano la catenella (0-1 mm) e pendono dritte; le liane sono sulla roccia; le ciambelle e la paperella galleggiano |
| Fossa dell'area bimbi con Jilly | 75784262 | stato `lei_fossa` (lo stesso della CI), 12 scatti (`fiume_fossa/fogli/fossa_jilly.jpg`) | mani appoggiate sul bordo, tentacoli fuori sopra il bordo, nessuna compenetrazione visibile; lettino 23 a terra |

## Note sugli strumenti

- La misura "pezzi gemelli" di `distanze.py` è da un lato solo, da un pezzo verso l'altro. Quando un tubo entra in un modello passando per la sua faccia, il valore dal modello verso il tubo resta diverso da zero (per `FILTRO_2_modello` 1,3 cm), anche se i due pezzi si toccano. Va letto insieme al valore nell'altro senso, che qui è 0,01 mm.
- Le scene intere sul renderer software arrivano a 11-12,5 GB. Una guardia (`guardia.sh`, nello scratch) uccide Godot sopra il limite per non far ripartire la macchina. Togliendo una vasca (`Vasche`), lei nella fossa non compare: per la fossa vanno tolti gli angoli e gli oggetti, non le vasche.
