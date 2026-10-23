# Ricollaudo: lo squalo della scena del risveglio (23 ottobre, sera)

Base: `lavoro/squalo-bocca` **221c8ecf**, con le correzioni di S1-S6 del collaudo di 2903de31 (`resoconto.md`). Le
misure sono fatte con gli stessi strumenti e le stesse soglie: `sonda_squalo_scena.gd` registra la scena fotogramma
per fotogramma, `tools/collaudo/analisi_squalo.py`, `dettagli_squalo.py` e `bava_squalo.py` misurano la pelle
deformata. Gli scatti sono dagli occhi del giocatore (`scatti_squalo.gd`, 1280×720, uno ogni 3 fotogrammi). Le
posizioni sono nella scena degli interni aperta da sola.

**Verdetto: S1-S6 corretti. Resta un difetto nuovo, S7: lo squalo che si stringe alla porta si nota.**

## S1-S6: le misure

| # | Prima (2903de31) | Ora (221c8ecf) | |
|---|---|---|---|
| S1 bava | capi a 0,6-5,8 cm dalle labbra, archetti nel buio della bocca | tutti i capi dei tre fili tra 0,8 e 7,6 mm dalla pelle, in tutta la scena (a 0,5, 1, 2, 3, 4,5, 5,5, 6,5 e 7,5 s) | a posto |
| S2 piedi che scivolano | 30 fotogrammi oltre 1 cm (fino a 5,6 cm) | nessun fotogramma oltre 1 cm, né per il piede sinistro né per il destro | a posto |
| S3 gambe nel pavimento | 1,2-1,4 cm da fermo, 5,8 cm nel giro | al massimo 0,4 cm, in tutta la scena (non si vede) | a posto |
| S4 mano nel muro nord | 14,9 cm | 0 | a posto |
| S5 porta tagliafuoco | braccia negli stipiti fino a 35 cm, nell'anta 15,5 cm | nel vano (z -1,90…-0,68) il corpo sta fra -1,89 e -0,83, sotto l'architrave arriva a 2,02 m su 2,08; nessun vertice nell'anta e nessuno a meno di 5 mm da stipiti, muri o altri oggetti | a posto (a sud restano 8 mm di margine) |
| S6 piede nel cartello | circa 350 vertici dentro | nessun vertice dentro la mesh del cartello (27 nel suo riquadro ma fuori) | a posto |

Ancora a posto:
- **camera**: mai dentro lo squalo, al minimo a 20,6 cm dalla pelle;
- **denti**: tutti e 65 entro 4 mm da gengiva, bocca o corpo;
- **dopo la scena** il giocatore è come prima: comandi attivi, torcia spenta, stessa posizione e sguardo a -90 gradi, stesso checkpoint e stesso HUD.

La scena ora dura 14,3 s. Il branch non ha ancora "niente torcia" di lavoro/godot (b1c162b3): andrà unito prima della build.

## S7: lo squalo che si stringe alla porta si nota (nuovo)

**Quando**: da 10,35 a 11,35 s. È un secondo, non mezzo. Il massimo dura da 10,6 a 11,25 s.

**Di quanto**:
- spina al 73% e collo al 75% di lato;
- petto all'88% di lato e anche in profondità;
- con le braccia raccolte, la larghezza del corpo vista dalla camera va da 1,79 m (10,13 s) a 1,04 m (10,63 s): -42% in mezzo secondo;
- l'altezza resta 2,0-2,1 m, quindi il rapporto larghezza/altezza passa da 0,89 a 0,49.

**Dove**: succede a 5-6,5 m dalla camera, con lo squalo ancora tutto di qua dalla porta e in piena vista, prima di entrare nel vano. Il ritorno alla larghezza giusta (11,33-11,53 s) avviene di là dalla porta, al buio, e la porta si chiude a 11,5 s: quello non si vede.

**Dagli occhi del giocatore**, in `fogli/sq_stringe.jpg` (e tutto il passaggio in `fogli/sq_porta_221c8ec.jpg`; misure con `tools/collaudo/stringe_squalo.py` e `stringe_squalo_vista.py`):
- a 10,1 s lo squalo è largo e pesante;
- a 10,5 s è diventato stretto e alto, con la testa e la pinna grandi come prima su un busto sottile;
- non sembra che si giri o che si metta di sbieco: sembra che si assottigli, come di gomma.

Con il giro "goofy" già bocciato dall'utente, lo segno come difetto. La soluzione del coordinatore è farlo passare girando le spalle di sbieco invece di stringerlo. Da sapere per chi la fa:
- il vano è largo 1,22 m;
- con le braccia raccolte e senza scala, a 9,3-9,6 s, lo squalo è largo 1,37-1,40 m nella fascia del busto (da 0,6 a 1,6 m d'altezza);
- girando tutto il corpo diventa più largo, perché testa e coda sono lunghe 2,3 m;
- quindi deve girare solo il busto, le spalle, e la nuova posa va rimisurata sullo stesso vano.

## Sul ramo unito (lavoro/godot ff9860bb)

Rifatte le stesse misure dopo l'unione (con niente torcia, tentacoli e il resto della v0.3.12):
- tutto identico a 221c8ecf: bava 0,8-7,6 mm, nessuno scivolamento, pavimento 0,4 cm, muri, vano, anta e cartello a posto;
- camera a 20,6 cm minimo, denti entro 4 mm;
- dopo la scena il giocatore com'era (la torcia non c'è più).

Negli scatti dagli occhi del giocatore senza torcia (`fogli/sq_risveglio_ff9860bb.jpg`):
- la faccia si vede bene da 2,4 a 4,2 s;
- lo squalo nel corridoio si vede da 6,6 a 10 s;
- il buio a 4,8-5,4 s è lo sfarfallio della luce, come prima.

S7 resta così per scelta dell'utente (D).
