# Collaudo del tunnel sottomarino: abisso (390-470 m) e approdo (470-552 m)

Squadra grafica, 24 ottobre, su lavoro/sottomarino 6b3eb3c8 più ee20554a (l'approdo in rifacimento: il portello cambia ancora). La tartaruga e i pesci li fa la mascotte.

Strumenti: `geometria.gd` (il tunnel costruito tutto, gommoni fermi, 1030 mesh, 9141 celle dove si cammina), `distanze.py` (soglia 1 cm), `testa.py`, `vedute.py` e il giro dagli occhi del giocatore (`giro.gd`). I fogli sono in `fogli/`.

## Abisso (390-470 m): superato

- Giro: 60 punti, 240 scatti (`fogli/foglio_abisso_01-10.jpg`; gli ultimi punti, da g026, sono già nell'approdo).
- Distanze vere: nessun oggetto staccato.
- Ravvicinati: 67 oggetti piccoli (`fogli/foglio_abisso_vicino_01-03.jpg`): le lucine a filo delle banchine, la fascia gialla e nera della galleria 425, le maniglie e le corde dei gommoni. Niente di staccato o compenetrato.
- La galleria 425 sta sotto 1,25-1,57 m: è il passaggio basso voluto.

## Per tutto il tunnel (segnalato al coordinatore e ad ambienti-2)

- **Lampade a gabbia nello spazio della testa** (`testa.py`): 11 lampade (gabbia e vetro) fra 1,5 e 1,94 m sopra la banchina sporgono 20-30 cm sopra punti dove si cammina (regola dei 2 m liberi). Punti (x; z): (-3; 84), (9; 76), (0,5; 50,5), (-3; 31,5), (-3; 13,5), (-15; -2,5), (-21; 6), (-36,5; 48,5), (-26; 58), (-35; 69,5), (-62,5; 78).
- **Gruppi che non arrivano al muro** (`distanze.py`): le 12 mensole coi coralli (66-109 m) e la mensola del palombaro (190 m): mensola e oggetto si toccano, ma il gruppo è a più di 1 cm dall'architettura.

## Approdo (470-552 m): da fare sul portello nuovo

- Le 4 bitte (497, 503, 517, 524 m): un pezzo di ognuna a 2 cm dall'altro (`distanze.py`); da guardare da vicino.
- Un rettangolo chiaro sul muro fra due lampade intorno ai 475-480 m (giro, g026-g029): da guardare da vicino.
