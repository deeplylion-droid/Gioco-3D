# Registro del coordinatore (dal 15 novembre 2026, 18:38 UTC)

Il registro di prima (`/home/user/coordinatore/piano_0317_notte.md`, dal 31 ottobre) è andato perso alle 18:25 UTC del
15 novembre: la macchina del coordinatore è stata sostituita (uptime 9 minuti alle 18:33, cartelle fuori dal
repository sparite: registro, worktree `/home/user/wt/godot`, scratchpad, strumenti). Il lavoro non è perso: è tutto
nei branch. Da ora questa cartella si salva sul branch orfano `lavoro/coordinatore` con `salva.sh` (nessun workflow:
il branch non contiene `.github`). Le ore le scrive il comando (`O=$(date -u +%H:%M)`), mai a mano.

## Come si lavora (promemoria)

- Squadre (sessioni remote, messaggi SEMPRE con `priority: next`): mascotte session_01YWTG1mGq714ESVViUmQhYw,
  ambienti-2 session_019HZGeneQaXJBRDNw4H3tQj, ambienti-1 session_01NbNne93LWX1hZUrGWpCyL8 (ferma),
  enigmi session_01T7gXU9URJunXdQxrRAzoeN, collaudo session_011Hw88iHTraQBa6nqZmqVDF.
- Unioni senza checkout: `strumenti/unione.py` (merge-tree + commit-tree sopra origin/main), `strumenti/candidata.py`
  (versione + note), `strumenti/prova_tutti.py` (branch di sola prova che gira tutti i test senza fermarsi).
  Il repository locale è `/home/user/Gioco-3D` (clone superficiale: i branch si prendono con
  `git fetch --shallow-since=2026-11-01 origin +refs/heads/<b>:refs/remotes/origin/<b>`).
- CI: «Build del gioco» su ogni branch (~100 min, si ferma al primo rosso); «Prova su Vulkan» solo su lavoro/godot,
  lavoro/controllo-vulkan, lavoro/candidata-*, lavoro/correttiva-*. Stato con get_workflow_run, verdetto con
  get_job_logs(failed_only, tail 25-45); mai list_workflow_jobs. Regola di primo_avvio: se scade «col gioco ancora
  vivo» e tutto il resto è verde, è il limite noto e non blocca.
- Unione in main: commit-tree con l'albero della candidata, genitori main + candidata, differenza 0; la CI di main
  crea la Release v<config/version> con le note di docs/release/v<versione>.md. Mai push su main mentre gira una
  Release. I link dell'exe e della Release per intero nell'ultimo messaggio all'utente.
- Delega dell'utente (15 novembre): «procedi senza chiedermi per le prossime cose» → per le tre build del piano le
  scelte le prendo io, le scrivo nel GDD e gliele dico a cose fatte. CLAUDE.md non si tocca (commit negato).

## Stato alle 18:38 UTC del 15 novembre

### 0.4.0 «L'acqua è sua»
- main 44361d67 (GDD: fossa finale, morte nelle pozze senza viso, scelte della build 2).
- Pezzi: lavoro/acqua-di-lei 466b9d3b (mascotte; IN ARRIVO ~19:00 lo SHA con la scena di morte nelle pozze, piano B),
  lavoro/pozze-lei f342d44a (enigmi, CONSEGNA FINALE: liquido opaco, opaco anche nella morte con l'interruttore
  liquido_trasparente_alla_presa spento, riscaldamento anche ripartendo: 0 draw e 0 specialization alla prima uscita
  da strada normale, F9, Continua e dopo una presa; elenco JSON della risalita valido sull'unione),
  lavoro/canto-prima 422c5221, lavoro/pompe-lezione 243eaf76, lavoro/tunnel-spruzzo 6fd9fdef, lavoro/lancia-fov
  1e123eec, commit delle partenze 7e66df28 + dd38cef2 + a117e574 (mai unire lavoro/partenze-0400 intero).
  Fuori: lavoro/torre-vasche-lei c1923c73 (non unire, non cancellare).
- Candidate: lavoro/candidata-0400 d9a801c7 (prima: Build rossa in test_tappa8, test vecchio contro la fossa nuova;
  Vulkan 43738622096 in corso), lavoro/candidata-0400b 0c177214 (seconda, 17:40: Build 43742397419 e Vulkan
  43742397389 in corso, valgono come informazione), lavoro/prova-0400-tutti-i-test 64ba3667 (sola prova: elenco dei
  rossi atteso ~19:15). TERZA CANDIDATA da fare su lavoro/candidata-0400c quando arriva lo SHA di mascotte:
  `unione.py "Candidata 0.4.0" acqua-di-lei,canto-prima,pozze-lei,tunnel-spruzzo,pompe-lezione,lancia-fov 7e66df28,dd38cef2,a117e574`
  poi `candidata.py <unione> 0.4.0 0400/v0.4.0.md "<riassunto>"`, push, e SHA a collaudo, enigmi, mascotte.
  Prova a secco con f342d44a: nessun conflitto.
- Ri-esecuzione di lavoro/prova-0400-senza-pozze cfc7b450 (43725747044, torre): in corso alle 18:05; ambienti-2 ha
  mostrato che test_oblo_leggeri rosso era rumore del runner. Non spingere su quel branch.
- Decisioni mie di oggi (nel GDD): liquido opaco quando lei c'è; tempo_presa 1,6 s; fossa che non sorprende mai
  (13 m; 21 m solo fuori dalla fascia della vasca; sbuca in vista oltre 3,4 m dall'occhio; già affacciata solo fuori
  vista o a schermo nero oltre 8 m; l'acqua sale anche quando sbuca); luce sui muri vicino all'acqua non è un difetto;
  morte nelle pozze senza viso (piano B: la camera cade, viene trascinata al bordo, si ferma 15 cm sopra il pelo e
  guarda il braccio che rientra; il viso sott'acqua, piano A, chiede ~3 ore di mascotte: da proporre all'utente);
  riscaldamento anche ripartendo dentro la 0.4.0.
- Collaudo: su 0c177214 fossa coi numeri nuovi (percorsi, tre ripartenze, pelo quando sbuca) e scatti delle pozze
  non di morte; sulla terza candidata morte nelle pozze e prima uscita dopo F9/Continua/presa. Fogli su
  lavoro/collaudo-0400 (e06b7c13 i primi). Già superati: zona A, punti 1-3 e 6-7, tunnel, 9 partenze F9, pozze
  funzionali, fossa su d9a801c7.
- Poi: Build e Vulkan verdi sulla terza candidata, collaudo superato coi fogli guardati da me, unione in main
  (0400/merge_msg_0400.txt), Release, link in chat.

### Build 2 «la storia» (0.5.0)
- ambienti-1: FINITA e ferma, lavoro/storia-disegni 6f2bea4f (otto disegni, componente DisegnoBambino, D1 e D2 in
  scena guardati da me, suoni, contatori, riepilogo).
- ambienti-2: lavoro/storia-finale baaa54ca+: finale coi sei bambini (v2 guardata: luce a posto; da fare la presa
  coi pollici davanti e le dita dietro, senza nastri sul foglio in mano, poi rifare lo scatto 03), D3 e D4 posati e
  approvati (D4 senza impronte), poi sagome, morte nell'ultimo tratto, Continua, fotogramma della girata.
- mascotte: lavoro/storia-mascotte (squalo, «porge»); dopo la 0.4.0: fischio, posa agli acquari (scelta A), presa
  del foglio coi pollici, texture doppie dello squalo.
- enigmi: brief mandato alle 18:38 (build2/brief_enigmi.md): squalo nel fiume, colore riempito nelle pozze, apparizione
  agli acquari, DF; branch lavoro/storia-fiume da 0c177214 + f342d44a; entro le 10:00 UTC del 16.

### Altro
- Controllo programmato alle 19:18 UTC (trig_01Kcopjk4ch5fhatrDuXrAGc).
- Pagina «Proposte nel dettaglio» (https://claude.ai/artifact/DagEbSgymA14naZ3dkfY1a): nessuna risposta alle 17:42.
- Dopo la 0.4.0: #168 primo_avvio affidabile; da proporre all'utente: torre rigenerata con gli scarichi, morte
  nelle pozze col viso sott'acqua. Restano sue: prova con 3-5 persone nuove, testo per Steam, voce dello spot.

## Registro

- 18:38 UTC: ripartenza dopo il riavvio della macchina. Ricreati gli strumenti e le note dalla seconda candidata più le
  due modifiche della morte nelle pozze. Arrivi delle 18:26-18:33: enigmi CONSEGNA FINALE f342d44a (letta: 9 file);
  ambienti-2 finale v2 (81428ca3) e D3/D4 posati (baaa54ca), guardati e approvati con le due correzioni sul foglio in
  mano. Brief della build 2 mandato a enigmi.
- 18:38 UTC: CI alle 18:39: seconda candidata 0c177214 Build 43742397419 in corso a 59 minuti (ha passato test_tappa8, che cade al 26° minuto: il test adeguato da mascotte regge in CI); Vulkan su d9a801c7 (43738622096) in corso a 99 minuti; ri-esecuzione di cfc7b450 (43725747044) ancora in corso a 136 minuti (più lenta del solito: da riguardare alle 19:18). Messaggi mandati: ambienti-2 (mani coi pollici davanti e dita dietro, niente nastri sul foglio in mano, D3 e D4 approvati, D4 senza impronte), enigmi (brief della build 2). Cartella salvata su lavoro/coordinatore (afad031d).
- 18:39 UTC: le voci del registro perso scritte oggi fra le 17:33 e le 18:08 sono ricostruite in archivio_15nov_1733-1808.md (dal registro della sessione, che però comincia alle 17:28: le voci più vecchie non si recuperano). L'elenco delle attività è stato rifatto (5 voci).
- 18:40 UTC: AMBIENTI-2 (18:38): lavoro/storia-finale 60d6b6f3: interruttore nastri in DisegnoBambino (spento sul foglio del finale), D4 senza impronte, mani passate a mascotte per dopo la 0.4.0; test_finale_gioco 11 ok nel gioco vero (F9 Tunnel, morte nell'ultimo tratto, Continua, seconda volta); posizionamento del tunnel con gli stati del finale: 0 nuovi (lampada della stanza alzata a 2,35 m); i bambini ad almeno 55 cm fra loro e 35 cm dai muri; misura delle pipeline alla girata in corso. ENIGMI (18:39): parte su lavoro/storia-fiume (0c177214 + f342d44a). Domanda sullo squalo: con 3 attacchi a giro chi non lo respinge mai non finisce il giro. DECISIONE MIA: B, dopo 2 morsi nello stesso giro urta soltanto (ciambella che gira 3 s) fino all'approdo; il conto si azzera all'approdo e con la partita nuova, non ripartendo dall'imbarco; l'urto non spinge mai nel ramo sbagliato; i 2 morsi contano come morti, gli urti no; parametri esportati. GDD 757a48cf ([skip ci], main).
- 18:41 UTC: COLLAUDO (18:40), pozze col renderer vero su d9a801c7 (stesse pozze di 01ffca25), fogli su lavoro/collaudo-0400 3124f605, docs/collaudo/0400/fogli/pozze_*.jpg (dimostrativa + una uscita per colore, 11 scatti l'una). GUARDATI DA ME turchese d'angolo e arancione: A POSTO. 0 compilazioni da ESCE a SU nelle sei uscite (partendo già nella stanza); liquido pieno e opaco nel silenzio e mentre lei è fuori, torna del suo colore 1,5 s dopo; la testa mai fuori dal pelo; mano e tentacoli sulla passerella senza staccarsi né entrare nel grigliato, anche nella pozza d'angolo; getto sulla mano: respinta dopo 0,87 s. Luce: chiarore rosa sul muro dietro le pozze durante l'avviso e riflesso sul grigliato accanto alla pozza quando lei è su: DECISIONE MIA, va bene (morbido, attaccato all'acqua). Restano sulla terza candidata: scena di morte, prima uscita dopo F9/Continua/presa, passaggio della luce fra le pozze dagli occhi in piedi. Fossa su 0c177214: percorsi partiti.
- 18:47 UTC: SECONDO RIAVVIO della macchina verso le 18:46 (uptime 0 minuti alle 18:47), ma stavolta il disco è rimasto: cartella del coordinatore, clone e scratchpad intatti. Causa non mia (nessun processo pesante qui). AMBIENTI-2 (18:46): fotogramma della girata del finale misurato col tunnel a pezzi: dallo schianto alla fine nessuna draw, surface o mesh nuova (82/243/57 costanti), 3 specialization in sottofondo; test_finale_tunnel 27 ok (distanze fra i bambini e dai muri); per la build 2 le resta solo lo scatto 03 con la posa nuova delle mani. FERMATA fino a nuovo avviso.
- 18:54 UTC: AMBIENTI-1 (18:54): la CI di 6f2bea4f era verde fino al passo 97, poi annullata dal suo push nuovo; ha aggiunto test_contatori e test_disegni_bambino a build.yml; SHA finale lavoro/storia-disegni 621d9362, CI in corso, controlla l'esito fra un'ora e mezza e si ferma. DA RICORDARE all'unione della build 2: lavoro/storia-finale ha dentro storia-disegni f768bc16 (più vecchio) e ha cambiato il componente DisegnoBambino (interruttore nastri): possibile conflitto con 621d9362, da far risolvere ad ambienti-2.
