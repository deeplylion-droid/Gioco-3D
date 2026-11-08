# Collaudo finale 0.3.22 (ambienti-2)

Candidata `lavoro/candidata-0322`: prima b18a9003, poi eda4fc21 (lo squalo parte a schermo chiaro). Branch del collaudo: `lavoro/collaudo-0322-finale`.
Dagli occhi del giocatore, con la cartella utente vuota (`XDG_DATA_HOME` su una cartella nuova). Col renderer vero (llvmpipe) la sala intera non sta in memoria, quindi:
- **le immagini** si fanno per parti (interni con l'ambiente della sala; torre, condotte e tunnel);
- **i tempi e il log** vengono dal flusso vero senza schermo, con la sala intera.

| Parte | Come | Esito |
|---|---|---|
| Titolo, Nuova partita, spot, caricamento con Jilly | Vulkan, cartella vuota (`giro_0322_inizio.gd titolo`) | ok: niente calibrazione, spot saltato tenendo premuto, barra fino al 99%, «Preparazione della sala…». Con la cartella vuota la lingua è quella del sistema (qui inglese), come deciso |
| Primo avvio su b18a9003 | flusso vero senza schermo (`reale`) | **difetto**: la scena dello squalo partiva sotto il nero della prova della qualità. Prova finita a 2,80 s della scena, schermo chiaro a 4,31 s: i tre lampi nel nero. Corretto da mascotte in eda4fc21 |
| Primo avvio su eda4fc21 | flusso vero senza schermo, cartella vuota | ok: attesa di 585 fotogrammi, finché la prova (alto e ultra) e la dissolvenza finiscono. Nell'attesa nessun suono, camera e testa dello squalo ferme. Primo lampo col nero a 0. Comandi a 17,3 s |
| Avvio normale su eda4fc21 | flusso vero, prova già fatta, senza salvataggio | ok: attesa di 233 fotogrammi (la dissolvenza), primo lampo col nero a 0, stesso resto |
| Scena dello squalo | Vulkan a 30 fps fissi, cartella vuota, prova vera (sceglie medio) | ok: `fogli/2_scena_squalo.jpg` |
| Lampade dopo lo squalo | massimo su 3 s di ogni luce degli interni | ok: fattori di emergenza a 1, nessun vetro sostituito. Le luci rosse pulsano e i neon sfarfallano per progetto, come nelle corse senza squalo |
| Primi corridoi | a piedi (avanti e sguardo), Vulkan e flusso vero | ok fin sotto la saracinesca; zaino preso; tornello e saracinesca con le scorciatoie di test_strada. `fogli/3_primi_corridoi.jpg` (verso la sala è nero perché la sala non c'è nelle parti) |
| F9 Inseguimento | flusso vero senza schermo | ok: arrivo a 18,9 s; morte con la scena intera; ripartenza nello stesso punto (37,91, -19,98, -14,84) |
| F9 Tunnel | flusso vero senza schermo | ok: arrivo; morte e ripartenza. Poi, fermo 8,5 s all'ingresso, lei lo prende (LeiTunnel.prendi, "medusa"), con la scena di morte breve e la ripartenza: è il gioco normale |
| Continua | flusso vero, dal checkpoint dei corridoi | ok: si riparte in (0, 0, 22,7) |
| Arrivi F9 | Vulkan in parti: torre, condotte e tunnel, SDFGI spento, mesh entro 25 m, camera a 1,6 m | ok: `fogli/4_arrivi_f9.jpg` |
| Log | tutte le corse | nessun errore durante il gioco; solo quelli normali all'uscita |

Difetto preesistente (c'era già nella 0.3.21, va nella coda della 0.3.23): nel menu F9 le voci non si cliccano col mouse, perché il livello «Radice» del titolo (layer 100, MOUSE_FILTER_STOP) sta sopra MenuProva (layer 50). Con la tastiera e il joypad funzionano.

Strumenti: `godot/tests/collaudo/giro_0322_inizio.gd` (modi `titolo`, `ingresso`, `reale`), `giro_0322_partenze.gd` (`f9 <id>`, `continua`), `scatti_0322_partenze.gd`.
