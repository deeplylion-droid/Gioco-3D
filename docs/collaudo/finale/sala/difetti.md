# Passaggio finale: sala principale

Base: `lavoro/godot` al commit **79c8fea**. Dopo 4838459 cambiano solo il GDD e una pagina per l'utente, quindi vale anche per 4838459. Squadra collaudo, notte fra il 22 e il 23 ottobre. Confronto con il collaudo della sala su 921d14f (`docs/collaudo/sala/difetti.md`).

Posizioni in metri nel mondo di `sala_principale.tscn`. Gli scatti sono in `scatti/` e i fogli in `fogli/`.

## Come è stato fatto

- **Controllo della CI** (`controllo_posizionamento.gd`, tutto il gioco): 1 caso nuovo, 32 già noti, 7 "da correggere" aperti (sotto).
- **Distanze vere**: 1756 oggetti della sala (Sala, Gioco, Mascotte, Vasca, Vasche, Polaroid, LuciSala), con le istanze dei MultiMesh dei dettagli, negli stati inizio, ritorno (blackout della tappa 7, acquari pieni, lampadine del portone accese, bava) e risolto (portone aperto).
- **Spazio per la testa**: niente sopra i punti dove si cammina, a parte la statua del polpo e la valvola dell'enigma, che hanno la collisione.
- **Giro dagli occhi**: gli stessi 110 punti del collaudo su 921d14f (440 scatti), stato iniziale, materiali semplici (`fogli/sala_giro_*.jpg`). La sala intera sul renderer software va in OOM anche togliendo le altre zone, quindi il giro è in due metà.
  - Metà ovest (x < 0): tolti `Interni`, `Risalita`, `Tecnici`, `Atmosfera`, `Sala/AngoloPalloni`, `Gioco/EnigmaAcquari`.
  - Metà est (x ≥ 0): tolti `Interni`, `Risalita`, `Tecnici`, `Atmosfera`, `Sala/AngoloScatoloni`, `Sala/AreaBimbi`, `Mascotte`.
  - In ogni metà mancano quindi, sullo sfondo, gli angoli dell'altra.
- **Vedute ravvicinate**: 206 nello stato iniziale (acquari con pedana, allacci, tiranti e lampadine del portone, Polaroid, salvagenti, applique, targa, manifesto, insegna, scatoloni caduti, oggetti staccati) (`fogli/sala_vedute_*.jpg`). Per le vedute di Jilly e del manifesto la metà è quella ovest, per le altre conta dove sta la camera. Le 51 vedute dello stato di ritorno (lampadine accese, bava) vanno in OOM due volte anche togliendo gli angoli, e al terzo tentativo la macchina si è riavviata. Per non fermare le altre squadre non le ho rifatte: per quello stato ci sono solo le misure, che sono complete.

## Difetti (visti su 79c8fea)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `LuciSala/LuciAreaBimbi/PlafonieraBimbi` (paralume e disco, `@MeshInstance3D@1513`, `@1514`) con l'asta `LuciSala/LuciAreaBimbi/@MeshInstance3D@1515` | -11,9, 9,1, -14,8 | La plafoniera navale sopra l'area bimbi è a 6,7 cm dalla fine della sua asta: il paralume, girato verso la struttura, non tocca l'asta che scende dal soffitto. È appesa al nulla (`addons/grafica/look_sala.gd`, `PlafonieraBimbi`). È nuovo rispetto a 921d14f. | (posizione misurata: a 9 m d'altezza nessuna veduta da vicino) |
| 2 | `Gioco/RitornoAlBuio/Scia/BavaMuroVasca/Nastro` (stato ritorno) | -0,46, 0,52, 12,37 | La bava sul muro della vasca di Jilly è ancora a 1,5 cm dal muro (`sala_vasca_offerte`). Quella sul bordo invece adesso tocca (0,3 cm). | (posizione misurata) |
| 3 | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@127` | 1,48, 0,12, 12,29 | Un pezzetto della medusa è a 7,3 cm dalla vasca, sospeso (su 921d14f era il n. 16, dall'altro lato). È di mascotte, con i tentacoli in arrivo. | `scatti/vfs_@Node3D@126_@MeshInstance3D@127.jpg` |
| 4 | Da valutare, come su 921d14f: `Sala/Dettagli/@MeshInstance3D@50` e `@52` | 7,24, 2,81, -23,82 e -18,20, 3,42, -23,81 | Le due cassette sul muro nord sono ancora girate di 45 gradi rispetto al muro e appoggiate su uno spigolo. | `vfs_Dettagli_@MeshInstance3D@50.jpg`, `@52.jpg` |

**Casi aperti nel controllo della CI**:

- Nuovo: `Sala/Dettagli/det_foglio_2` n. 7 (14,0, 0,02, 18,06): il 23% dei suoi vertici è dentro `Sala/AngoloPalloni/pallone_9`. È già assegnato ad ambienti-2.
- Da correggere, enigmi: `AcquarioGiallo/AnelloVetro` e `AcquarioBlu/AnelloVetro` sono interi dentro il loro coperchio.
- Da correggere, mascotte (i tentacoli in arrivo): la medusa della fossa (`Gioco/LeiSbuca/MedusaFossa`) passa dentro la fossa per 41 e 116 cm e ingombra le gambe di chi cammina; la medusa della vasca (`Vasca/Medusa`) ha il 35% e il 77% dei vertici dentro la vasca.

## Superati da 921d14f (verificati su 79c8fea)

| Su 921d14f | Ora |
|---|---|
| 1. Tiranti degli acquari sospesi | toccano coperchio e base (0,1-0,4 cm) |
| 2. Disegno a 4 cm dal vetro | 0,3 cm dal vetro dell'acquario giallo |
| 3. Bava sul bordo e sul muro | bordo a posto; muro ancora a 1,5 cm (difetto 2) |
| 4. Targa smaltata | tocca la vasca |
| 5. Manifesto | a contatto con il muro |
| 6. Lampadine dell'insegna | dentro il portalampada |
| 7. Pile di scatoloni con l'aria | ogni scatolone tocca quello sotto (0-0,1 cm) |
| 8. Palloni del mucchio staccati | `pallone_62` e `_66` toccano i palloni dentro |
| 9-11. Applique sotto i palloni, sulla bocchetta e doppione | spostate (`@49` a -19,99, 1,94, 3,82; `@48` a 13,3, 2,03, 19,99; `emergenza_rotta` a 19,95, 3,16, 5,05) |
| 12-15. Pistola, pannello di lamiera, `@40`, colatura | a contatto (0-0,3 cm) |
| 16. Pezzetto della medusa | ce n'è ancora uno, dall'altro lato (difetto 3) |
| 17. Cassette a 45 gradi | invariate (difetto 4) |
| 18. Salvagente sopra l'oblò | spostato accanto all'oblò, non lo copre più |

Anche il resto è a posto: le Polaroid 04, 05, 08 e 09 toccano ciò su cui stanno; il salvagente della vasca centrale (`ogg_salvagente_nave_36`) è appeso al bordo; gli acquari rifatti (basamento, anello, coperchio, pedana, allacci e tubi delle pompe), le guide e le piastre delle lampadine del portone poggiano o sono fissati. Nello stato risolto, con il portone aperto, non ci sono altri stacchi.
