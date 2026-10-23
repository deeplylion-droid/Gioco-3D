# Collaudo del posizionamento: tecnici (camera delle onde e sala pompe)

Base: `lavoro/ambienti-2-inseguimento` al commit **604e519**. Squadra collaudo, 22 ottobre. Tutti i difetti qui sotto sono visti su 604e519.

Il raccordo (`Tecnici/Ambienti/Raccordo`, con magazzino e scale verso la risalita) e la piscina a onde non sono in questo resoconto: si fanno su `lavoro/godot` dopo l'unione, come deciso dal coordinatore.

Posizioni in metri nel mondo di `sala_principale.tscn`. Stato misurato: ritorno (blackout della tappa 7, porte aperte). Gli scatti sono in `scatti/` e i fogli in `fogli/`.

## Come è stato fatto

- **Distanze vere**: 84 oggetti della camera delle onde e della sala pompe (`tools/collaudo/distanze.py`), con le coppie di pezzi che devono toccarsi (lampada e vetro, pompa e manometro, filtro e modello).
- **Giro dagli occhi**: 28 punti dal pozzo della camera delle onde alla sala pompe e alla scala, 4 scatti per punto: 112 scatti (`fogli/tecnici_giro_*.jpg`).
- **Oggetti piccoli**: 36 sotto i 40 cm (`oggetti_piccoli.csv`); 24 vedute ravvicinate (`fogli/tecnici_vedute_01.jpg`).
- **Spazio per la testa**: nella camera delle onde e nella sala pompe c'è un solo caso, il 4 qui sotto.

## Difetti (visti su 604e519)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `Tecnici/Ambienti/SalaPompe/GRATA_leva` e `SALA_gabbia` | 5,10, -5,05, 46,7-47,2 | La scatola della leva della grata con la sua gabbia è a 5 cm da `SALA_struttura`: staccata dal muro, non tocca niente. | `scatti/vtec_SalaPompe_GRATA_leva.jpg`, `vtec_SalaPompe_SALA_gabbia.jpg` |
| 2 | `SalaPompe/FILTRO_2_modello` | sul `FILTRO_2` | Il modello del filtro è a 1,1 cm dal suo `FILTRO_2`: le due parti non si toccano (nel `FILTRO_1` sì). | `vtec_SalaPompe_FILTRO_2_modello.jpg` |
| 3 | `SalaPompe/POMPA_3_manometro` | sulla `POMPA_3` | Il manometro è a 1,5 cm dalla pompa: staccato (quelli delle pompe 1 e 2 toccano). | (posizione misurata: nessun punto dove si cammina da cui si veda bene) |
| 4 | Da verificare: `SalaPompe/QUADRO_strumenti` | -3,8…-3,44, -7,75…-6,80, 36,5-37,7 | Il quadro sporge 36 cm dal muro fra 1,3 e 2,25 m d'altezza. Il punto `tec011` (-3,5, -9,05, 37,0) risulta raggiungibile e la camera finisce dentro il quadro. `tecnici.gd` gli dà una collisione trimesh (`create_trimesh_collision`), che dovrebbe fermare il giocatore, ma il controllo delle celle con il raggio verso l'alto non l'ha vista. Va provato con il giocatore vero se ci si entra con la testa. | `fogli/tecnici_giro_02.jpg` (`tec011`) |

## Visti e a posto

- **Polaroid07** sulla scrivania della sala pompe (-3,23, -8,27, 43,36): a 604e519 tocca la scrivania (0,35 cm). A 921d14f era 3,5 cm sopra: è risolta. Scatto: `vtec_SalaPompe_Foglio_det_foglio_3.jpg`.
- Le lampade a gabbia della camera delle onde e della sala pompe toccano il muro o il tubo, e i loro vetri toccano la lampada.
- I lampeggianti della paratia, i fogli e le carte sulla scrivania e a terra, la leva con la sua base, il lettore della tessera e il cavo a terra poggiano su qualcosa.
- Nel giro non ci sono oggetti sospesi o compenetrati oltre a quelli sopra.
