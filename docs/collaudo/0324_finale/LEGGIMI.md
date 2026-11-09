# Collaudo finale della 0.3.24 (9 novembre, sera)

Squadra collaudo. Ho collaudato `lavoro/candidata-0324` **fb33bd56** e il confronto con main **48553e74**. Nella candidata finale **e97e1277** cambiano solo 8 righe dei segni dei tempi in `riscaldamento_shader.gd`, più le note: la parte 6 dice cosa ho rifatto lì.

Le prove girano una alla volta, sotto `render.lock`, con almeno 13,5 GB liberi. Nel gioco non ho cambiato niente.

**Esito: superato.** Restano cose piccole, già decise col coordinatore come non bloccanti:
- i tempi della costruzione del tunnel (parte B);
- gli ERROR rari di `test_torre`, che escono solo nei test senza schermo (parte 7).

Un limite di questa macchina riguarda la goccia: le tre strade dal titolo (Nuova partita, F9 Inizio, Continua) con Vulkan non entrano in memoria (parte A).

## A. La goccia di bava (617888f5)
`fogli/goccia_interni_0323_e_0324.jpg`, `dati/goccia_interni.txt`.

**La strada degli interni** (`giro_squalo`, che salta la schermata di caricamento e il suo riscaldamento). È la stessa strada su cui nella 0.3.23 si compilava la pipeline 2D, con preset alto a 1280x720.
- **Pipeline:** la pipeline 2D della goccia si compila al terzo fotogramma della scena, quando la rete di sicurezza la disegna trasparente. Quando compare (6,27 s) e nei 2 s dopo **non si compila nessuna pipeline nuova**, né 2D né 3D (canvas, mesh, surface, draw e specialization fermi). Nella 0.3.23 lì c'era +1 canvas.
- **Gli scatti negli stessi istanti della 0.3.23** (6,53, 7,03, 7,53, 8,03 s): la goccia è uguale. Differenza media da 0,01 a 0,06 su 255; i pochi pixel diversi sono sul bordo della goccia.
- Le compilazioni 3D all'inizio della scena (0,07-0,83 s) c'erano uguali nella 0.3.23.

**Il riscaldamento intero della schermata di caricamento** (`GIRO_RISCALDA=tutto`, come la sonda di grafica-2). È quello che fanno Nuova partita, F9 Inizio e Continua.
- Il riscaldamento compila la goccia nel suo SubViewport (+1 canvas).
- Quando parte la scena, la goccia ne compila ancora 2, al primo fotogramma, sotto la dissolvenza: la variante dello schermo vero è un'altra.
- Lo prende la rete di sicurezza all'inizio, non quando compare.
- Questo giro poi è stato ucciso per memoria prima della goccia.

**Quello che non ho potuto fare:**
- **Nuova partita, F9 Inizio e Continua con Vulkan:** la sala intera va fuori memoria anche a 640x360 col preset basso (ucciso a circa 14 GB).
- **Nuova partita senza grafica:** non ha trovato la scena in corso (credo sia finita durante il caricamento).
- **«Niente sopra i 33 ms»:** su llvmpipe ogni fotogramma con Vulkan dura circa un secondo, quindi non si può misurare.

## B. Il tunnel a passi corti (7bf1ed69)
`dati/tunnel_*.txt`: giochi veri senza schermo, con `TORRE_TEMPI` (i passi sopra 20 ms) e il tempo di ogni fotogramma.

**Gli strumenti:**
- `tunnel_tempi.gd` misura le strade:
  - F9 Inseguimento: la prima costruzione, la morte nelle condotte, la seconda costruzione, l'ingresso nel tunnel con `sb1_finito` come alla fine di SB1;
  - F9 Torre, il portone, F9 Tunnel con la morte nel tunnel.
- `sonda_thread_tunnel.gd` di enigmi prova titolo, morte ed esci durante la costruzione.

| | main 48553e74 | candidata fb33bd56 |
|---|---|---|
| Passi più lunghi | `_luci` 369-422 ms, `_abisso_oblo` 80-86, `_buco_anello` 72 | `_corallo` fino a 34,1 (c'era già), `_relitto_staffe` 25,4, `_pezzo` 20-24 |
| Prima costruzione (F9 Inseguimento) | il più lungo 386-401 ms, 23-24 fotogrammi sopra 33 ms | 7 fotogrammi da 33,5 a 41,7 ms durante i passi; 83 ms quando il tunnel entra in scena; 48,6 ms all'ultimo |
| Seconda costruzione (dopo la morte nelle condotte) | 340-445 ms, 20-24 sopra 33 | 8 da 33,7 a 39,5 ms; 76,7 all'entrata; 50,9 alla fine |
| Da F9 Torre | | 94,5 ms all'entrata, 75 alla fine, 2 da 34 ms |
| Ingresso nel tunnel (sb1_finito, 4 s) | al più 17,7 ms | al più 20,7 ms |
| F9 Tunnel e morte nel tunnel | un fotogramma di 1,6-1,8 s circa 3,5 s dopo l'arrivo | uguale (1,6-2,0 s): c'era già |

**Lo stato della costruzione:**
- tunnel costruito e pronto in 7,5-8,0 s;
- nodi: **tunnel 2844, torre 1132** (`sonda_nodi_tunnel.gd` di enigmi).

**Le uscite e i log:**
- Titolo (a 0 fotogrammi e a metà), morte ed esci durante la costruzione: il tunnel riparte pronto, l'uscita è pulita.
- **0 «Invalid Task ID» in tutti i log** del collaudo.
- `test_tunnel_involucri_uscita` 2/2, `test_forme_tunnel` 28/28, `test_posizioni_tunnel` 4/4, `test_lei_tunnel_strada` 4/4, `test_inseguimento` 43/43.

Il limite dei 33 ms quindi non è rispettato del tutto. Il coordinatore ha deciso che non blocca (prima erano 386-445 ms) e lo fa correggere nella 0.3.25.

## C. Le Polaroid (6dbafdfe)
**I test:** `test_polaroid_appoggiate` 19/19 e `test_polaroid_fiume_ferma` 6/6. Tutte e 16 stanno a 0,19-0,20 mm nel punto più vicino, con 0 punti dentro (`dati/test_*.txt`).

**Gli scatti da vicino** (`polaroid_vicine.gd`, luci del blackout):
- dagli occhi (1,6 m) e da accovacciato (0,97 m);
- radenti a 6 mm da quattro lati e di lato a 2 cm, con una lampadina sulla camera.

`dati/polaroid_misure.txt`:

| | dove | misura | fogli |
|---|---|---|---|
| P05 | sul fondo in pendenza della piscina, sott'acqua | girata di 3,8° col fondo, 0,20 mm, 0 dentro | `polaroid_P05_piscina.jpg` |
| P10 | sul lettino della torre | 0,19 mm; i 18 mm «più lontano» sono lo spazio fra le stecche sotto la foto | `polaroid_P10_torre.jpg` |
| P12 | sul grigliato della torre | sulle barre, 0,20 mm | `polaroid_P12_torre.jpg` |
| P16 | nel fiume | 0,20 mm, 0 dentro | `polaroid_P16_fiume_acceso.jpg`, `polaroid_P16_radenti_ingranditi.jpg` |
| P16 col fiume fermo 30 s e poi ripartito | | durante l'attesa resta dov'era (29 mm più in alto), poi si appoggia nello stesso punto; gli scatti sono **identici al pixel** a quelli col fiume acceso | `polaroid_P16_fiume_fermo_e_ripartito.jpg` |
| P08 | sul bordo piastrellato della vasca d'arrivo della torre degli scivoli | girata di 3,4° col bordo, 0,20 mm, 0 dentro | `polaroid_P08_bordo_vasca.jpg` |

**P05 e P08, nella sala:** la sala intera con Vulkan non ci sta, quindi ho usato la sala ridotta. Lì la sala non risulta mai «costruita» e la foto aspetta la sua zona, così ho chiamato io `adagia()`, lo stesso calcolo del gioco. La posizione che viene fuori, (1,2002; −2,1776; 2,9001), è identica a quella della sala intera senza schermo (`sonda_sotto_p08.gd`).

**P08:** poggia sul bordo della vasca d'arrivo della torre degli scivoli (`Sala/TorreScivoli/arrivo_bordi`), come dice la sonda sulla sala intera. Per gli scatti ho usato una sala ridotta che tiene la torre degli scivoli e toglie piscina, area bimbi e dettagli, col preset basso. Con `adagia()` la posizione è (−8,9004; 0,0098; 6,6), la stessa della sala intera.

**In tutti gli scatti:** nessuna foto staccata o compenetrata. Da radente, a 6 mm d'altezza, sotto il centro della P16 si vede da un lato uno spicchio scuro sottile. È la curvatura del modello della foto (fino a 2,86 mm, la stessa per quasi tutte nel test), non un distacco. Dagli occhi e da accovacciati non si vede.

## D. Il giro delle zone cambiate
- **Polaroid:** le viste dagli occhi e da accovacciati sono nei fogli della parte C.
- **Goccia:** è uno strato sullo schermo; gli scatti sono nella parte A.
- **Tunnel:**
  - la costruzione cambia solo come si divide in passi;
  - i nodi sono 2844 e la torre 1132, come nei confronti di enigmi (0 differenze fra versioni);
  - la torre cambia solo per P10 e P12.
- **controllo_posizionamento:** 0 da correggere (gli ERROR sono i soliti 102 blend shape e 16 forme Jolt vuote, più le perdite all'uscita).
- Un giro a piedi lungo condotte e tunnel col giocatore non l'ho fatto, per il tempo. I nodi uguali e il posizionamento dicono che lì non si sposta niente.

## E. La memoria
Da F9 Inseguimento fino al tunnel, con la morte nelle condotte e quella nel tunnel, senza schermo:
- **picco della candidata 3366 MB, di main 3375 MB: 9 MB in meno**, dentro i ±50;
- fase per fase le due versioni sono a 3 MB l'una dall'altra.

## 6. La candidata finale e97e1277
`git diff fb33bd56 e97e1277`: 8 righe dei segni di `RiscaldamentoShader.disegna_fuori_vista`. Il nome della radice ora si prende all'inizio: prima, dopo l'attesa, si leggeva da una radice già liberata. Il resto sono le note (1ff30748).
- Su e97e1277: import ok, `check_scripts` 0 errori.
- **`test_strati_luci` con Vulkan: 5/5, 0 SCRIPT ERROR** (era il test rosso nella Prova su Vulkan).

## 7. Gli ERROR rari di test_torre: visti, solo nei test headless, non bloccanti
`dati/torre_errori_thread.txt`.

**Cosa ho visto:** in 1 giro su 3 di `test_torre` sulla candidata, all'instantiate della seconda torre (test_torre.gd:64), sono usciti:
- «Initializing already initialized RID»;
- «Parameter "mem" is null»;
- 4 volte «Parameter "m" is null», nel MeshStorage del renderer finto.

Il test passa perché li conta solo dopo.

**Cosa c'è dietro:** la prima torre, tolta dopo 3 fotogrammi, ha ancora 7-12 caricamenti in corso dalla sua precarica (`stendardi.glb`, i 4 stendardi png, `bambino_agnello.tscn`, `bambino_cubo.tscn`, texture MetalPlates, l'acqua dell'inseguimento). La finestra è la stessa su main.

**Cosa ho ripetuto** (`sonda_torre_thread.gd`):
- 6 giri senza schermo e 6 con Vulkan;
- 4 processi nuovi su main e 4 sulla candidata;
- `test_torre` 2 volte su main e altre 2 sulla candidata.

Sempre 0 errori: è una corsa rara fra il thread e il renderer finto, il cui MeshStorage non è thread-safe; quello di Vulkan sì. Il coordinatore la fa rendere robusta nella 0.3.25.

## 8. Gli altri test (fb33bd56)
- check_scripts 0 errori;
- test_squalo_schermo 7/7, test_polaroid 5/5, test_attesa_zone 6/6, test_torre 95/95, test_lampade_torre_strade 22/22, test_continua 127/127 (gli ERROR di sempre), test_partenze_prova 74/74.

## Strumenti
In `godot/tests/collaudo/`:
- `tunnel_tempi.gd`: le strade del tunnel coi tempi e la memoria;
- `goccia_strade.gd`: la goccia dalle strade del titolo, per una macchina che ci stia;
- `polaroid_vicine.gd`: gli scatti delle Polaroid;
- `sonda_torre_thread.gd`: i caricamenti in corso alla seconda torre;
- `sonda_sotto_p08.gd`: su che cosa poggiano P05 e P08 nella sala intera.

`sonda_nodi_tunnel.gd` e `sonda_thread_tunnel.gd` sono di enigmi (`lavoro/collaudo-tunnel-passi-lunghi`). In `dati/code.txt` ci sono le righe di riepilogo di tutte le code.
