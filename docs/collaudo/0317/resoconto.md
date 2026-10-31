# Collaudo finale della 0.3.17 (30-31 ottobre)

Squadra collaudo. Lavoro a pezzi man mano che le correzioni arrivavano in `lavoro/godot`, poi il giro finale sulla candidata **a486e51c**.

Ho usato il giocatore vero coi tasti veri e il renderer vero dove serve vedere. Ogni prova ha i suoi dati salvati in una cartella a parte.

**Esito: superato, nessun difetto bloccante. 0 righe "ERROR: BUG," in tutti i log.**

## Difetti

Nessuno.

## Da sapere (non difetti)

- **Teli di Jilly bruciati.** All'arrivo e col lampione sono quasi neri: si intravede appena la faccia. Bruciature e scarabocchi si leggono solo coi ravvicinati con la torcia, che nel gioco non c'è. Scatti: `teli_*.jpg` qui accanto. È una questione di aspetto.
- **Lei nell'oblò della torre** torna illuminata rosa-salmone, come nella 0.3.15 (`fogli/lei_oblo.jpg`). Il coordinatore conferma che è la scelta B dell'utente. Le righe rosa nelle condotte non tornano (`fogli/condotte_righe.jpg`).
- **Squalo all'inizio, a 6,0 s.** Mentre si gira sopra la camera, in alto a sinistra il corpo mostra un'apertura dal bordo chiaro, per circa mezzo secondo. C'era già uguale nella 0.3.16 (`fogli/squalo_6s_prima_dopo.jpg`).
- **Grana della nebbia**, solo da annotare (la nebbia la tiene l'utente, scelta C). Il rumore fine è 1,37 con 16 passi, 0,98 con 24 e 0,86 con 32; senza nebbia è 0,68.

## Che cosa va

| Prova | Esito |
|---|---|
| Posizionamento sulla candidata, col blocco dei "da correggere" | 0 nuovi, 64 noti, 0 da correggere, 0 eccezioni vecchie |
| Strada intera (`test_strada`) | 35/35 |
| 21 test delle zone cambiate | tutti ok: scalette_piscina 108, sala 106, interni 57, enigma 87, polaroid 5, continua 127, risalita 15, fiume_gioco 31, torre 94, inseguimento 43, effetti 13, morbidezza_inseguimento 64, sottomarino_gioco 13, morbidezza_tunnel 46, luci_bianche_gioco 13, zona_nebbia 21, bambini_sfuggita 53, agnellino 13, audio 116, partenze_prova 72, menu 73; fine del tunnel 14 |
| Continua dalla risalita e dal tunnel, dopo un crash vero | checkpoint giusto, a 0,00 m dal posto salvato; zaino, acqua, inventario e Polaroid uguali. Dopo la morte si riparte in piedi in 4,6 s (risalita) e in 9,0-9,2 s (tunnel). La prima prova del tunnel, subito dopo un riavvio della macchina coi file a freddo, ha impiegato 30,7 s. |
| Scalette della piscina, sala intera, col giocatore vero (`sonda_discesa.gd`) | dal bordo ci si aggrappa e si arriva sul fondo, in tutte e due, piena e vuota, guardando dritto, in basso e in alto; `ricontrollo_scalette` 60/60 |
| Scalette dagli occhi (`fogli/scalette_viste.jpg`) | viste in salita, in cima coi corrimano, sul fondo e dal bordo. Lo strumento carica la sala a pezzi, senza la configurazione delle scalette di `sala_principale.gd`: lì il comportamento non vale, le viste sì |
| Muri a pannelli: interni, 120 scatti con luci di prima e blackout; tecnici, 56 col blackout | nessuna riga a zig-zag (`fogli/pareti_*.jpg`) |
| Passi (`sonda_passi.gd`) | 0,97 m camminando, 1,29 correndo, 0,73 accovacciati; 3,5, 4,5 e 2,3 passi al secondo; regolari entro 12 ms; dondolio 3-5 cm |
| Tunnel con le lampade al 20%, partita intera dagli occhi, stessi input prima e dopo (`fogli/tunnel_20_*.jpg`) | luminanza da 28,2 a 21,3. Le lampade sono accese e deboli, nessuna è rimasta forte. La banchina si legge anche nei tratti più bui. Lei, gli oblò e le plafoniere sono come prima. 6 getti, 6 respinte, 0 prese |
| Corridoio in fondo alla scala del fiume (`fogli/corridoio_*.jpg`) | il giocatore vero lo percorre avanti, indietro e accovacciato: mai fermo, niente fra 0,1 e 2 m sopra i piedi, niente sospeso. La P13 si vede e si raccoglie; `test_polaroid` 5/5 |
| Muro sopra l'oblò della torre (`fogli/muro_tre.jpg`, `muro_oblo_a.jpg`) | di nuovo rosso come nella 0.3.15, senza la fascia scura |
| Nebbia dal fondo della piscina vuota, al buio e con le luci (`fogli/piscina_*.jpg`) | lo strato è leggero, pavimento e giocattoli si leggono |
| Squalo all'inizio, dagli occhi, confrontato con la 0.3.16 (`fogli/squalo_prima_dopo_*.jpg`) | la faccia col riflesso viola al ruggito si vede; braccia e pinna non stanno più davanti al petto; porta e corsa vanno; la camera non entra mai nella pelle |
| Agnellino del tunnel (`fogli/agn_*_zoom.jpg`) e di C2 (`fogli/agn_c2_00.jpg`) | quello del tunnel sparisce dopo lo spigolo, fuori vista; quello di C2 si volta in 0,6 s |
| Corridoio delle pile del fiume (`fogli/fiume_00.jpg`) | luminanze 19,9, 12,7, 9,7 e 11,3, uguali alle misure di grafica |
| Tubi dell'inseguimento | vedi `docs/collaudo/tubi_inseguimento_30ott/` su `lavoro/collaudo` |

## Strumenti nuovi

In `godot/tests/collaudo/`:
- `corridoio_giro.gd`: il corridoio del fiume col giocatore vero e la P13;
- `pareti_giro.gd`: i muri a pannelli con i materiali veri;
- `sonda_passi.gd`: il ritmo dei passi;
- `sonda_discesa.gd`: la discesa dal bordo con le scalette, nella sala intera;
- `scalette_giro.gd`: le viste delle scalette, con la sala a pezzi;
- `tubi_giro.gd`, che ora ha anche la sonda "ombra".
