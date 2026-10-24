# Collaudo del tunnel sottomarino: pesci (240-315 m), abisso (390-470 m) e approdo (470-552 m)

Squadra grafica, 24 ottobre, su lavoro/sottomarino 6b3eb3c8 più ee20554a (l'approdo in rifacimento: il portello cambia ancora). La tartaruga (315-390 m) l'ha fatta la mascotte (lavoro/collaudo-masc bde178c9); i pesci sono passati a grafica il 24 sera.

Strumenti: `geometria.gd` (il tunnel costruito tutto, gommoni fermi, 1030 mesh, 9141 celle dove si cammina), `distanze.py` (soglia 1 cm), `testa.py`, `vedute.py` e il giro dagli occhi del giocatore (`giro.gd`). I fogli sono in `fogli/`.

## Abisso (390-470 m): superato

- Giro: 60 punti, 240 scatti (`fogli/foglio_abisso_01-10.jpg`; gli ultimi punti, da g026, sono già nell'approdo).
- Distanze vere: nessun oggetto staccato.
- Ravvicinati: 67 oggetti piccoli (`fogli/foglio_abisso_vicino_01-03.jpg`): le lucine a filo delle banchine, la fascia gialla e nera della galleria 425, le maniglie e le corde dei gommoni. Niente di staccato o compenetrato.
- La galleria 425 sta sotto 1,25-1,57 m: è il passaggio basso voluto.

## Per tutto il tunnel (segnalato al coordinatore e ad ambienti-2)

- **Lampade a gabbia nello spazio della testa** (`testa.py`): 11 lampade (gabbia e vetro) fra 1,5 e 1,94 m sopra la banchina sporgono 20-30 cm sopra punti dove si cammina (regola dei 2 m liberi). Punti (x; z): (-3; 84), (9; 76), (0,5; 50,5), (-3; 31,5), (-3; 13,5), (-15; -2,5), (-21; 6), (-36,5; 48,5), (-26; 58), (-35; 69,5), (-62,5; 78).
- **Gruppi che non arrivano al muro** (`distanze.py`): le 12 mensole coi coralli (66-109 m) e la mensola del palombaro (190 m): mensola e oggetto si toccano, ma il gruppo è a più di 1 cm dall'architettura.

## Pesci (240-315 m), su lavoro/sottomarino ad4dfae9: da chiudere coi pesci corretti di ambienti-1

- Giro: 64 punti, 256 scatti; ravvicinati: 46 oggetti (`fogli/foglio_pesci_01-13.jpg`).
- Distanze vere e controllo di posizionamento della zona sottomarino su ad4dfae9: 0 casi nuovi, 0 da correggere.
- **Difetti** (controllo di posizionamento della mascotte su ee20554a, da chiudere con la correzione dei pesci di ambienti-1, 7f71776d, che su lavoro/sottomarino non c'è ancora): `ArrediA1/Pesci/mensola_pesce_5` (-5,10; -27,79; 0,49) e `mensola_pesce_8` (-15,25; -27,79; -2,26) passano 10 cm dentro le lampade a muro (Luci/@Node3D@369 e @379); `pesce_0`-`pesce_3` (x -3,01, z 29,91 / 23,91 / 17,91 / 11,91) a più di 5 mm dalla loro mensola. Da rifare i ravvicinati quando la correzione è unita.

## Approdo (470-552 m), col portello nuovo ad arco (10d20d9c, punta ad4dfae9)

- Giro: 52 punti, 208 scatti; ravvicinati: 43 oggetti e 5 vedute del portello coi rivetti (`fogli/foglio_approdo_01-12.jpg`). Il telaio, i rivetti, il battente, il cardine e il volantino sono attaccati.
- Spazio per la testa: con gli oblò alzati a 2,55 m (052c0e98) le 16 segnalazioni sono sparite; restano il battente aperto e il volantino del portello, voluti.
- Lo schianto di lei sull'oblò: pelle vera a 0 vertici dentro (test_morbidezza_tunnel).
- **Difetti**: le 4 bitte (497, 503, 517, 524 m), un pezzo a 2 cm dall'altro: corrette da ambienti-1 (b2d40c13, su lavoro/godot): da rifare i ravvicinati quando arrivano su lavoro/sottomarino.
- Da guardare: una staffa della vetrina vuota (`vetrina_vuota`, @656) arriva sulla piastra di una lampada a muro (foglio 11): sembra appoggiata, non dentro.
- Il rettangolo chiaro verso 475-480 m è il segno della vetrina caduta (voluto, ambienti-1).

## (prima stesura)
## Approdo (470-552 m): da fare sul portello nuovo

- Le 4 bitte (497, 503, 517, 524 m): un pezzo di ognuna a 2 cm dall'altro (`distanze.py`); da guardare da vicino.
- Un rettangolo chiaro sul muro fra due lampade intorno ai 475-480 m (giro, g026-g029): da guardare da vicino.
