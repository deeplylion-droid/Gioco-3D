# Ricontrollo di lavoro/torre-robusta (grafica-2, per la 0.3.25)

**Cosa ho controllato:** 76e82f28, solo i commit propri del branch:
- 8921e9e3: il perno della porta tagliafuoco, test_oggetti_morti e test_torre robusto;
- dcb33cc2: l'agnello liberato;
- l'unione con main su risveglio_squalo.gd.

La testa ora è 774e9c46, che rispetto a 76e82f28 tocca solo le staffe dell'ancora del tunnel (sottomarino_arredi_a2.gd, di enigmi).

**Confronto:** con la 0.3.24, cioè main dd5b3c4e, con gli stessi strumenti.

**Esito: superato, nessun difetto.**

## 1. Porta tagliafuoco, perno e goccia

### Nel gioco vero
Sonda `tests/collaudo/sonda_porta_g2.gd`, senza schermo. Due strade:
- da Nuova partita (titolo, spot, caricamento);
- da F9 Inizio, rispondendo sì a «Ricominciare da capo?».

Con tutte e due le strade, e uguale alla 0.3.24 riga per riga (`dati/porta_*.txt`):
- il perno è nell'albero, sotto Corridoio, a (12,265; 0; 40,18);
- la porta è attaccata al perno, con la collisione sullo strato 1;
- c'è un perno solo;
- il perno sta a 120° e la porta si chiude fra 14,30 e 14,50 s fino a 0°;
- la porta resta sul perno: si stacca al più di 0,0000 m;
- alla fine ci sono 0 nodi orfani.

### Ravvicinati del cardine
Strumento: `sonda_squalo_g2` con RAVV_PORTA=1 (`1_porta_cardine_branch.jpg`). Scatti:
- quando: a 0,5, 13,5, 14,37, 14,43 e 16 s;
- cardine: in basso, a metà e in alto, dai due lati;
- porta intera: dai due lati.

Sono 40 scatti, **identici pixel per pixel alla 0.3.24**, con differenza 0. Il cardine è attaccato al telaio, senza distacchi.

### Goccia
Spia delle pipeline 2D (`dati/goccia_spia_*.txt`), uguale alla 0.3.24:
- +1 canvas alla nascita della goccia (fotogramma 3, dietro il velo nero);
- **0 pipeline nuove quando compare**: in tutta la scena, dopo l'inizio, nessuna compilazione.

## 2. test_oggetti_morti e test_torre, 10 giri di fila
I risultati sono in `dati/dieci_giri.txt`.
- **test_oggetti_morti:** 10 su 10 con 8 controlli ok. Per torre e inseguimento, dalla seconda alla sesta ripartenza: +0 oggetti, nodi, orfani e risorse.
- **test_torre:** 10 su 10 con 96 controlli ok, compresi «nessun errore dall'inizio» e «caricamenti della torre tolta a metà finiti».
- In tutti i 20 log: 0 «Initializing already initialized RID», 0 «m is null», 0 «material is null».

Gli unici ERROR sono le perdite all'uscita del processo. Sono gli stessi tipi in ogni giro e uguali a quelli della 0.3.24 (lì test_torre fa 95 ok su 3 giri).

## 3. Bambino agnello
Strumento: `ricontrollo_agnellino_scala.gd`, in cima alla scala di C2 e poi la fuga lungo C2 fino al buco, a 30 fps fissi.
- **Numeri uguali alla 0.3.24:** piedi da fermo a 0,082 m (le ossa) e 0,007 m (le punte); nella corsa da -0,579 a 0,271 m, in 94 fotogrammi (`dati/agnello_*.txt`).
- **Scatti nella stessa posa** (44): il primo da fermo è identico pixel per pixel. Negli altri la differenza media è 1-2 su 255 ed è sparsa su tutto lo sfondo, dove cambia la luce del blackout. Sull'agnellino non ce n'è: nella differenza la sua sagoma è più scura del fondo (`3_agnello_0324_branch_differenza.jpg`: la 0.3.24, il branch, la differenza ×8).
- **Liberato:** test_agnello_liberato fa 4 ok, con 0 errori del motore in 3 giri.

## 4. ERROR nei log
Ho confrontato i tipi di ERROR, normalizzando i numeri, fra la 0.3.24 e il branch in queste prove:
- le due strade della porta;
- i ravvicinati;
- la spia della goccia;
- l'agnellino;
- test_torre.

**Nessun ERROR nuovo, nessuno sparito.** Restano quelli di sempre: le perdite all'uscita e ERR_CANT_OPEN dell'audio.

## Nota (non è un difetto)
`_aggancia_porta` adesso salta l'aggancio anche quando il perno non è ancora nell'albero (`not _perno.is_inside_tree()`). Oggi non succede: il perno entra con la stessa coda di chiamate differite, prima. Se un giorno gli interni venissero preparati fuori dall'albero, la porta resterebbe senza perno. Per il caso degli interni liberati basterebbe controllare `_perno.get_parent() == null`.
