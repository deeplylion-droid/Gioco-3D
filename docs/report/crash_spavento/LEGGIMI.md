# Crash dopo il primo spavento (v0.3.14)

Segnalazione dell'utente del 25 ottobre: su un PC nuovo e potente, la prima volta che ci gira il gioco, il gioco crasha dopo il primo spavento. Il primo spavento è la tappa 8: lei sbuca dalla fossa dell'area bimbi e ti prende, parte la sequenza di morte (urlo e glitch) e poi `GameState.respawn()` ricarica la sala intera.

## Come si è riprodotto

`godot/tests/test_presa_vera.gd` rifà il caso vero:

- la strada di `test_strada` fino alla serranda, con le stesse scorciatoie, così Risalita e torre si caricano nel thread come nel gioco;
- poi lungo la scia fino alla fossa, dove lei ti prende;
- la sequenza va fino in fondo senza saltarla;
- la sala si ricarica dal checkpoint e si giocano altri 30 s.

In CI `test_tappa8` saltava la sequenza, e la torre non era in caricamento.

## Cosa succede

- **La torre è ancora in caricamento nel thread.** Comincia quando si apre la serranda (`EnigmaAcquari.comparso` → `_precarica_torre`). Nella prova senza schermo, con `--verbose`:
  - alla presa la torre è `IN_PROGRESS`, alla ricarica pure, e anche 30 s dopo la ripartenza;
  - all'uscita `Game.esci` l'ha aspettata altri 18,7 s.
- **La sala si ricarica sopra il caricamento.** Il thread principale carica di seguito `sala_principale.tscn` mentre il thread 2 carica le texture della torre: nel log le due cose sono intrecciate. La sala nuova richiede la torre di nuovo mentre il primo caricamento è ancora in corso ("Another threaded load for resource path 'sala_torre.tscn' has been initiated").
- **Su un PC nuovo è ancora peggio.** La cache degli shader è vuota, quindi i thread del pool sono pieni di pipeline da compilare e il caricamento della torre (un task a bassa priorità) dura di più. È proprio la situazione in cui la sala viene liberata e ricaricata sotto un caricamento in corso.
- **Sequenza di morte e jumpscare: niente da segnalare.** `DeathSequence` e `JumpscareGlitch` controllano ogni riferimento con `is_instance_valid`. Dalla morte a 30 s dopo la ripartenza non c'è nessun errore del motore o degli script, né senza schermo (sala) né col renderer Vulkan con la cache vuota (interni, `tests/collaudo/morte_vulkan.gd`).
- **La riserva della torre non c'entra.** Quella con `CACHE_MODE_IGNORE_DEEP` parte solo col portone aperto da più di 20 s, e il portone si apre con l'enigma degli acquari, dopo la tappa 8.
- **Col renderer Vulkan la sala intera non sta nella memoria della macchina.** Con la cache vuota il processo viene ucciso a 14 GB prima di arrivare alla fossa, anche con le parti lontane nascoste (`tests/collaudo/presa_vulkan.gd`). Il crash esatto dentro il motore (Windows, GPU vera) qui non si vede. La condizione che lo provoca si vede, e si riproduce ogni volta.

## Sequenza intera e sequenza saltata

Indizio dell'utente: crasha solo se la sequenza di morte arriva fino in fondo (5 s), non se la si salta tenendo premuto.

- **Valori del motore: nessuna differenza.** `tests/collaudo/presa_ridotta.gd`, nella sala ridotta: a ogni fotogramma, dalla presa a 5 s dopo la ripartenza, cerca valori non finiti (NaN, infiniti) nella camera, nei nodi e nelle ossa di lei e nelle luci. Senza schermo non ce n'è nessuno, in nessuna delle due strade. Da 1 s alla fine la camera resta ferma a 0,62-0,67 m dall'occhio di lei.
- **Stato del gioco: è qui la differenza, al momento della ricarica.**
  - Saltata, la sala si ricarica a circa 1 s, quando la torre è ancora in caricamento nel thread e non c'è niente di istanziato.
  - Intera, si ricarica a 5 s. Su un PC veloce la torre ha appena finito di caricarsi e si sta preparando nascosta: si costruisce a pezzi e si disegna fuori vista, con le pipeline in compilazione. In `test_presa_vera` la torre è caricata 6 s dopo la serranda e alla presa è già "pronta, nascosta".
- **È lo stesso caso già visto in CI.** Su lavoro/godot 58cc633 il processo abortiva all'uscita subito dopo la fine di un caricamento grande. Aspettare 2 fotogrammi non bastava, 30 sì (`Game.esci`).

## La correzione

- **`Game.aspetta_caricamenti(livello)`** è un punto solo, usato prima di liberare il livello:
  - il livello si ferma (`process_mode` disabilitato), così non comincia altro;
  - si aspetta, fotogramma per fotogramma, che i caricamenti nel thread di `carica_in_thread` siano finiti e che il livello non abbia lavori a metà (`lavori_in_corso()` della sala: la torre che si prepara nascosta);
  - se qualcosa ha appena finito (un caricamento o la torre preparata), altri 30 fotogrammi e 1 s, come in `Game.esci`;
  - poi altri 2 fotogrammi disegnati;
  - i risultati restano a chi li ha chiesti: la sala ricaricata li richiede e li trova pronti.
- **Se l'attesa supera 1,5 s** compare il nero con la lucina rossa che pulsa e la scritta "Caricamento…", come nella schermata di caricamento, finché la scena non cambia.
- **Dove si usa:**
  - `GameState.respawn()`, sia ricarica sia scena diversa, al massimo 60 s;
  - `Game.return_to_title()`, dal menu di pausa e da solo dopo la fine della demo: aspetta col gioco ancora in pausa;
  - F1 e F2 nelle build di debug.
- Se intanto si esce dal gioco o si torna al titolo, la ripartenza non ricarica.
- **Un secondo accesso a un oggetto liberato**, trovato da `test_torre` con il conteggio degli errori: `FormeTunnel.prepara_a_pezzi`, una funzione statica a pezzi, quindi non si ferma quando il tunnel viene liberato. Dopo una morte nella torre, mentre si preparavano le forme del tunnel, continuava sulle forme di collisione già liberate ("previously freed"). Nel gioco esportato è un crash. Ora a ogni forma controlla che tunnel e forma ci siano ancora.
- `LuciBianche` non legge più le geometrie fuori dall'albero. Nella ricarica toccava una lampada della sala vecchia, già tolta dalla scena, con l'errore `get_global_transform: !is_inside_tree()`.

## La ricarica in due tempi (memoria)

L'utente ha una scheda da 4 GB e la sala da sola ne usa 2,2-2,4. Prima, alla ricarica, la sala nuova si costruiva e si caricava sulla GPU mentre la vecchia non era ancora liberata nel renderer. Misure di `tests/collaudo/memoria_ripartenza.gd`, a ogni fotogramma:

| | In un tempo (prima) | In due tempi (ora) |
|---|---|---|
| Vulkan, sala ridotta: memoria video | da 1789 a 2427 MB (+638), poi memoria della macchina finita | 1789, 1250 nella scena vuota, picco 1887 (+98), poi 1789 |
| Senza schermo, sala intera: memoria statica | +11 MB | +5 MB (nella scena vuota scende da 1579 a 1440) |
| Senza schermo, sala intera: oggetti | da 14345 a 17959 (+3600) | +300 |

`GameState._cambia_in_due_tempi`: prima una scena vuota (`Game.cambia_scena_in_due_tempi`; resta il nero della sequenza di morte). Poi 2 fotogrammi e 2 `frame_post_draw`, finché la sala vecchia è liberata anche nel renderer. Infine `change_scene_to_packed` dal PackedScene della sala tenuto in GameState: le risorse restano in cache e la ripartenza non si allunga. Il PackedScene si lascia andare al ritorno al titolo e al cambio di livello.

## Prove

- `test_presa_vera` (in CI), che verifica:
  - lei ti prende alla fossa;
  - la sequenza va fino in fondo;
  - la sala si ricarica solo a caricamenti nel thread finiti. Se la torre ha già finito, come su un PC veloce, alla fine della sequenza comincia il caricamento del tunnel, così la ripartenza trova lo stesso un caricamento in corso;
  - la spia compare se l'attesa è lunga;
  - dalla presa a 30 s dopo la ripartenza ci sono 0 errori del motore o degli script. Li conta un `Logger`, perché nel gioco esportato un accesso a un oggetto già liberato è un crash.
- `tests/collaudo/morte_vulkan.gd`: sequenza intera, ricarica e 30 s col renderer Vulkan e la cache vuota, negli interni.
- Gli altri test con morti, ricariche e ritorno al titolo, in locale col codice finale:
  - check_scripts ok;
  - test_presa_vera 31, test_tappa8 69, test_mechanics 85, test_torre 93, test_inseguimento 43;
  - test_scaletta_bacino 13, test_acquari 83, test_risalita 10, test_risalita_tardi 12, test_audio 116;
  - test_bambini 49, test_scivoli 26, test_fiume_gioco 31, test_infermeria_gioco 36, test_partenze_prova 72;
  - test_fiume 35, test_infermeria 22, test_strada 35, test_fine_titolo 12, test_menu 72, test_uscita 19.
- `test_continua` di lavoro/continua (mascotte), su un'unione di prova: 58 controlli; il crash vero: 3 controlli.
- I test che aspettano il livello dopo una ripartenza ora aspettano a tempo (fino a 90 s) e non più per un numero fisso di fotogrammi, perché la ripartenza può durare qualche secondo.
