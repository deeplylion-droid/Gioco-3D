# Giro al buio (23 ottobre, sera)

Collaudo su `lavoro/godot` **946a90d3**: niente torcia, luci bianche al 40%, preset alto con GI (la sala principale senza GI, per la memoria del renderer del sandbox: lì è un po' più buia del gioco). Richiesta del coordinatore: segnare solo quello che blocca davvero il gioco. I tre punti più bui (scala del pozzo, sala pompe a sinistra, area bimbi a destra) restano così per scelta dell'utente.

## Come è fatto

`godot/tests/collaudo/giro_buio.gd`, con la lista `interattivi`:
- per ogni oggetto che si usa (Interactable abilitato e visibile: oggetti da raccogliere, pulsanti, Polaroid, cassetti, rotelle, porte con il maniglione) cerca un punto dove sta il giocatore, a 1,3-2,5 m, con gli occhi a 1,6 m e niente in mezzo;
- fa uno scatto al buio e lo stesso con una luce sulla camera (`_luce`), per vedere dov'è l'oggetto.

Le zone sono aperte nel gioco come nel gioco vero:
- interni e risalita da soli, perché interni e tecnici mettono il loro ambiente sulla camera quando ci si entra;
- tecnici dentro la sala principale, perché la loro logica (leve, lettore, porte) la aggiunge la sala;
- torre da sola;
- sala principale.

Stati: inizio, ritorno (blackout) e risolto, dove cambiano qualcosa. I fogli si fanno con `tools/collaudo/foglio_buio.py`: a sinistra al buio, a destra con la luce.

## Blocchi

| # | Che cosa | Dove | Foglio |
|---|---|---|---|
| B1 | **La Polaroid 02 non si vede**: sta dentro l'armadietto aperto dello spogliatoio, e da 1,8 m l'interno è nero. Si trova solo puntando a caso fino a vedere "[E] Raccogli". | interni, spogliatoio (x 3,38, y 1,7, z -7,9 negli interni) | `B1_polaroid02.jpg` |

## Si trovano senza torcia

| Oggetto | Zona | Note |
|---|---|---|
| Zaino-pompa | interni | illuminato |
| Polaroid 01 | interni, a terra vicino alla porta tagliafuoco | il bordo bianco si vede come un quadratino chiaro |
| Polaroid 03 | interni, bacheca dello stanzino | |
| Lettore della tessera | tecnici, magazzino | la sua lucina |
| Maniglione della porta della sala pompe | tecnici | scuro, ma è nella sala pompe già accettata |
| Polaroid 06 | tecnici, a terra nella camera delle onde | quadratino chiaro, appena visibile al ritorno |
| Polaroid 07 | tecnici, sulla scrivania | |
| Polaroid 04, 08, 09 | sala, a terra | quadratino chiaro anche senza GI |
| Polaroid 10 | torre, sul lettino | illuminata (`torre_polaroid10.jpg`) |
| Ciambella | fiume | fosforescente |
| Negatoscopio, 10 cassetti, 3 rotelle della cassaforte | infermeria | stanza chiara |

**Non verificata: Polaroid 05**, sul fondo della piscina della sala. Negli stati del collaudo la piscina è ancora piena, e lo scatto con la vasca vuota va fuori memoria sul renderer del sandbox.

## Dove andare

Oltre ai tre punti già accettati, negli scatti di grafica (`docs/collaudo/buio_23ott/` su `lavoro/grafica-buio`) e in questi non c'è un passaggio di cui non si capisca dove porta.
