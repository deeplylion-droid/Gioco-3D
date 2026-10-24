# Collaudo della v0.3.13: fiume lento, ciambelle sulla riva, fine della demo (24 ottobre)

Base finale: `lavoro/godot` **cc2884bd**, cioè l'unione di `lavoro/pile-a1` 75c02b57 più versione e note. Prima sono stati visti 4c4b48bd (giro preliminare) e 5339c137, su cui sono usciti D1 e D2. Squadra collaudo.

**Verdetto: superato.**
- I due difetti trovati, D1 e D2, sono corretti in cc2884bd e ricontrollati con gli scatti veri.
- Il controllo di posizionamento ha 0 casi nuovi e 0 "da correggere".
- In locale passano test_fine_titolo (12/0), test_ciambelle_riva (12/0) e test_multimesh_specchiati (6/0); la CI su cc2884bd è verde.

## Come è stato fatto

**Materiali veri**, non quelli semplici a due facce: con quelli il difetto delle pile della v0.3.12 non si vedeva.
- Gli scatti sono di `tests/collaudo/giro.gd` nella risalita vera (`risalita.tscn`, stato ritorno, stanze subito), 800×450, con la luce sulla camera.
- La strada viene dalla scena del fiume (`tests/cz/sonda_strada_fiume.gd`): i marker a piedi, i 7 tratti della corrente campionati ogni 2 m, l'altezza degli occhi da seduti sulla ciambella (1,65 m sopra l'acqua), gli oggetti piccoli e le unità delle pile.
- Il passaggio dalle coordinate del fiume a quelle della sala (fiume ruotato di -90° in -35, -5,4, 92) è verificato: le ciambelle lette nella risalita vera cadono esattamente dove la conversione le mette.

| Parte | Scatti | Fogli |
|---|---|---|
| Strada a piedi: ingresso, fila fra le transenne, piazza, imbarco; approdo e porta (ogni 1-2 m, 4 direzioni) | 108 | `strada_*` |
| Giro sulla ciambella, all'altezza degli occhi da seduti: Imbarco, Giusto1, Giusto2, Uscita (bivi giusti) e i tre rami sbagliati fino agli scivoli, ogni 2 m, avanti, destra, indietro, sinistra | 424 | `strada_*` (cb_…) |
| Pile: i 5 gruppi (379 unità) dai due lati, lungo tutta la lunghezza ogni 3 m, a 2,5 m dalla faccia, in orizzontale e verso l'alto (fino a 4,7 m) | 96 | `pile_*` |
| Rive e banchine (i 54 punti del giro precedente del fiume) | 216 | `rive_*` |
| Ravvicinati degli oggetti piccoli lungo la strada (101 oggetti, 2 lati ciascuno) | 202 | `ravvicinati_*` |
| Le quattro ciambelle spostate: ravvicinati a 0,6, 1,0 e 1,8 m e vedute dalla ciambella in corsa | 36 | `ciambelle_*`, `ciambelle_riva_*`, `ciambella_approdo.jpg` |

## Difetti trovati (tutti corretti)

| # | Dove | Problema | Su | Corretto in |
|---|---|---|---|---|
| D1 | Fine della demo dopo l'inseguimento | La scritta "FINE DELLA DEMO" stava nell'HUD (CanvasLayer al livello 1), sotto il nero di `SalaInseguimento._nero` (livello 80). Lo schermo restava tutto nero per 9,5 s e poi arrivava il titolo, senza che la scritta si vedesse mai. C'era già nella v0.3.12. (`fine_D1_prima_scritta_coperta.jpg`) | 5339c137 | c0408bbb: la scritta su un CanvasLayer suo al livello 90, fra il nero e la pausa (100) |
| D2 | Fiume, le tre ciambelle a riva | Nella risalita vera non comparivano: "ciambella a riva: nessun posto vicino a …" per tutte e tre. Esistevano solo nella scena di prova del fiume. | 5339c137 | 75c02b57: i raggi sulla roccia nelle coordinate del fiume, più test_ciambelle_riva nella scena vera |

## Ricontrollo su cc2884bd

**Fine della demo (D1), superata.** Visto con gli scatti veri in una scena col giocatore vero e la sua HUD, con lo stesso nero di `_nero` (`fine_D1_dopo_nero_scritta_pausa.jpg`):
- la scritta si legge sul nero (livello 90) e il menu di pausa le sta sopra;
- in pausa il tempo della scritta resta fermo (4,99 s prima e dopo 8 s di pausa), e lo stesso vale per il ritorno al titolo (test_fine_titolo, con la fine vera dell'inseguimento: in pausa non torna, a 5 s di scritta è ancora la fine, poi torna da solo una volta e non ci ritorna);
- "Torna al titolo" dal menu di pausa durante la scritta, nella sala principale vera: la scena passa una volta sola al menu principale e nei 15 s seguenti non cambia più (`tests/cz/sonda_fine_dalla_pausa.gd`).
- La sonda con la scena di prova dell'inseguimento intera non sta nella memoria della macchina con il renderer vero (12,6-13,9 GB): per lo scatto si è usato lo stesso nero in una scena leggera, come fa anche test_fine_titolo.

**Ciambelle a riva (D2), superate.** Nella risalita vera sono tutte e tre: CiambellaRiva in (-39,8, -4,8, 113,2), inclinata di 8,7°; CiambellaRiva2 in (-58,2, -4,8, 79,8), 4,7°; CiambellaRiva3 in (-40,3, -4,8, 66,3), 4,9°.
- Stanno in piedi sulla banchina, con la cima contro la roccia.
- Non entrano nella roccia, non sporgono sul canale e non toccano paratie, scalette o cartelli.
- Dalla ciambella in corsa si vedono sulla riva e non intralciano.
- Il controllo di posizionamento non le segnala.

**ciambella6 (l'approdo), a posto.** È stesa sulla banchina, accanto al salvagente sul palo e alla staccionata, a 1,7 m dalla strada fra l'approdo e la porta.

**Pile, a posto.** Sono piene da tutti e due i lati in tutti i gruppi, con le casse blu sotto e il cartone sopra. Le vedute dei lati esterni che finiscono contro un muro grigio sono lati che il giocatore non vede.
- Le colonne che negli scatti verso l'alto sembrano inclinate lo sono per la prospettiva: nel codice ogni piano gira al massimo di ±0,7°.
- Le vedute delle pile su cc2884bd sono identiche, pixel per pixel, a quelle di 5339c137.

**Strada, rive e ravvicinati, a posto.**
- Rispetto a 5339c137 cambiano solo i pixel vicino alle ciambelle spostate (Giusto1_00-06, Giusto2_02-18, Imbarco_26-27, l'approdo). La modifica di `_a_terra` e `_cima` (le trasformazioni nel fiume mentre si costruisce) non ha spostato altro di visibile.
- Le transenne stese a terra nella fila sono volute: nel codice sono "transenne cadute".
- I due blocchetti grigi a 1,05 m sono le maniglie delle porte dell'ingresso e del personale.

**Posizionamento.** `controllo_posizionamento.gd` su cc2884bd: 0 nuovi, 42 già noti, 0 "da correggere". Il fiume è stato controllato negli stati della risalita con 638 oggetti.

## Strumenti nuovi (in `godot/tests/collaudo/`)

- `sonda_strada_fiume.gd`: la strada del fiume (marker, tratti, altezza degli occhi da seduti, oggetti piccoli, pile, ciambelle), in JSON;
- `sonda_ciambelle_risalita.gd`: le ciambelle nella risalita vera;
- `sonda_fine_leggera.gd`: nero, scritta e pausa con gli scatti;
- `sonda_fine_dalla_pausa.gd`: torna al titolo dalla pausa durante la scritta.

Le liste (`tools/collaudo/fiume_liste.py`, `fiume_pile.py`, `fiume_ciambelle.py`) convertono le coordinate e generano le righe per `giro.gd`.
