# Collaudo dei blocchi (25 ottobre, sera)

Squadra collaudo. `lavoro/blocchi` di grafica, confrontato con main **89332366**. Cosa cambia:
- torre, interni e tecnici si riaccendono e si liberano a pezzi;
- i corpi statici sono divisi in un corpo per forma;
- il tunnel si costruisce a pezzi, con le forme convesse salvate;
- le porte aspettano la zona (scelta A dell'utente).

Il collaudo finale è su **588c6d6c**, che ha la correzione del crash col riscaldamento: le luci non cambiano più la cull mask. Prima erano stati provati 3602b3a0 e 963d8e3d, con lo stesso esito.

**Esito: nessun pezzo resta spento.** In tutte le zone e dopo le ripartenze, blocchi e main hanno:
- le stesse mesh visibili;
- le stesse forme di collisione attive nella fisica;
- gli stessi checkpoint attivi;
- le stesse porte e le stesse luci;
- gli stessi strati delle mesh e gli stessi strati e cull mask delle luci.

Nessuna mesh visibile ha lo strato 0 e nessuna luce ha strato o cull mask a 0. Nei log non c'è nessun "ERROR: BUG,". Nella torre i 163 scatti col renderer vero sono uguali a main. I fotogrammi più lunghi entrando nelle zone sono 4-6 volte più corti di main.

## Come

**L'elenco di cosa c'è davvero** (`godot/tests/collaudo/sonda_blocchi.gd`, senza schermo, nella sala intera). Si prende a lavori a pezzi finiti: `lavori_in_corso()` falso, nessun caricamento nel thread, poi 1 s.
- **Mesh visibili:** classe, centro e misura nel mondo, strato (layers).
- **Forme di collisione:** solo quelle attive nel mondo della fisica, con classe, centro e misura dei punti nel mondo, strato di collisione. Le forme dei corpi divisi hanno lo stesso posto nel mondo, quindi si confrontano anche se i corpi sono cambiati.
- **Luci accese:** classe, posto, strato e cull mask.
- **Checkpoint:** attivi, cioè monitoring, processo e area nel mondo della fisica.
- **Porte:** attive.

**Il confronto** (`tools/collaudo/confronta_inventari.py`):
- due elementi sono lo stesso se hanno la stessa classe e misura e il centro a meno di 5 cm;
- si tolgono il giocatore e i gommoni, che galleggiano;
- strati e cull mask si confrontano anche nodo per nodo, sullo stesso percorso.

**I casi**, su 588c6d6c e su main:
1. **Torre dal portone:** la strada vera di `test_strada`, dal risveglio attraverso la Risalita col fiume fino alla serranda, l'area bimbi, la spiaggia, il portone e la passerella. Poi l'elenco dentro la torre, che comprende anche la discesa, il fondo e l'inseguimento.
2. **Morte nella torre:** la ripartenza dal checkpoint del portone, poi di nuovo l'elenco.
3. **Inseguimento:** la partenza F9 dal fondo della torre, l'elenco e di nuovo dopo 30 s.
4. **Tunnel:** la partenza F9 dopo SB1, l'elenco, dopo 30 s, poi una morte e l'elenco dopo la ripartenza.
5. **Risalita:** la partenza F9 dopo la sala generatori, con le stanze, l'infermeria, gli oblò e le porte; l'elenco e di nuovo dopo 30 s.

**Il renderer vero (llvmpipe)**, per le zone da sole. La sala intera col renderer vero non entra nei 15 GB della macchina.
- **Torre:** `sala_torre.tscn`, 163 viste dagli occhi del giocatore: un terzo dei punti del giro finale più un terzo dei ravvicinati. Confronto vista per vista con main.
- **Tunnel:** 4 tratti della strada (0-90, 190-240 con la galleria 205, 400-460 con la galleria 425, 520-560 con l'approdo), dalle banchine e dall'acqua.

## Risultati

| Elenco | Mesh | Forme | Luci | Checkpoint attivi | Porte |
|---|---|---|---|---|---|
| torre dal portone | 2311 / 2313 | 1302 = | 267 / 266 | 23 = | 1 = |
| torre, dopo la morte | 2312 / 2308 | 1302 = | 254 / 253 | 23 = | 1 = |
| inseguimento (e dopo 30 s) | 2314 / 2311 | 1295 = | 256 / 251 | 23 = | 1 = |
| tunnel (e dopo 30 s) | 1948 / 1949 | 1145 = | 54 / 55 | 12 su 23 = | 1 = |
| tunnel, dopo la morte | 1948 / 1946 | 1145 = | 54 / 55 | 12 su 23 = | 1 = |
| risalita (e dopo 30 s) | 2695 = | 1846 = | 191 = | 23 su 26 = | 2 = |

(blocchi / main; "=" uguale)

- **Le differenze di mesh e luci sono tutte cose che si muovono o lampeggiano da sole**, e cambiano anche fra due elenchi dello stesso commit:
  - mesh: le particelle che scendono nei coni di luce delle lampade della sala (`LuciSala`, mesh di 1×7 cm che cambiano altezza), le gocce della pozza, lei nel tunnel, la scia del ritorno;
  - luci: i neon e le luci dell'area bimbi che sfarfallano, le 6 lampade delle vasche dell'inseguimento.
  - Le lampade delle vasche le ho seguite per 90 s in tutti e due i commit (`log/lampade_vasche_*.txt`): si accendono e si spengono uguali, 13 volte su 31.
- **Nel tunnel** sono spenti in tutti e due i commit gli 11 checkpoint della torre e dell'inseguimento: la torre resta caricata ma spenta. Sono attivi i 4 del tunnel e quelli della sala.
- **Nella risalita** sono spenti in tutti e due i 3 checkpoint dell'infermeria (DopoLuce, DopoRadiografia, DopoNegatoscopio), che si accendono con l'enigma.
- **Strati:**
  - mesh: 1 (il mondo), 2 (le mani e la lancia del giocatore), 1<<19 (le 6 superfici d'acqua);
  - luci: strato 1, cull mask piena, tranne il lampo della tempesta, che esclude lo strato 1<<19;
  - uguali nodo per nodo con main in tutti gli elenchi.
- **Le ripartenze** tornano al checkpoint giusto: il portone nella torre, il checkpoint 6 nel tunnel, con il giocatore nel posto salvato.
- **La strada di `test_strada`:** 35 controlli su 35, sia su blocchi sia su main. Compresi la porta del ponte, che aspetta le stanze della Risalita (qui erano già pronte: 0 s), e i checkpoint della strada.
- **I log:** 0 righe "ERROR: BUG," su blocchi, né senza schermo né col renderer vero. Errori del motore:
  - nel tunnel, su blocchi 0; su main 13, cioè `get_global_transform: !is_inside_tree()` e quelli del renderer finto, che la correzione del crash toglie;
  - sulla strada, uno solo su tutti e due (`Parameter "material" is null`, renderer finto).

### Fotogramma più lungo entrando nelle zone

Senza schermo, quindi solo il lavoro sulla CPU, senza shader e pipeline.

| Dove | blocchi 588c6d6c | main |
|---|---|---|
| inizio della partita (risveglio, a 6 s) | 2521 ms | 2499 ms |
| area bimbi, quando si apre il portone e parte la torre | 435 ms | 2094 ms |
| ripartenza nella torre | 357 ms | 1883 ms |
| arrivo nell'inseguimento (F9) | 317 ms | 1812 ms |
| arrivo nel tunnel (F9) | 158 ms | 170 ms |
| ripartenza nel tunnel | 154 ms | 190 ms |
| arrivo nella risalita (F9) | nessuno sopra 50 ms | nessuno sopra 50 ms |

Il blocco dell'inizio della partita è uguale nei due commit.

### Renderer vero

- **Torre** (`fogli/torre_main_e_blocchi.jpg`, `fogli/torre_blocchi_renderer_vero_00-02.jpg`): 163 viste su 163 uguali a main, con una differenza media sotto 1 su 255. Niente pezzi mancanti, 0 "ERROR: BUG,".
- **Tunnel** (`fogli/tunnel_blocchi_renderer_vero_00-01.jpg`): 123 viste, banchine, acqua, porta del bacino, gallerie e approdo. 121 sono uguali a main (differenza media sotto 1).
  - Le altre 2 sono le viste a 560 m, dove la camera della sonda finisce sotto la superficie dell'acqua dell'approdo: cambia solo il disegno animato dell'acqua (`fogli/tunnel_main_e_blocchi_le_due_viste_diverse.jpg`).
  - 0 "ERROR: BUG," nei log.

## Da guardare (grafica)

- `SalaTorre.STRATO_PREPARA` (1<<19), lo strato del riscaldamento fuori vista, è lo stesso di `WATER_LAYER` dell'acqua (`addons/acqua/scripts/water_body.gd`, 1<<19).
  - Durante il riscaldamento la camera fuori vista vede anche tutte le superfici d'acqua.
  - I pezzi messi su quello strato prendono il trattamento dell'acqua da chi lo distingue, per esempio il lampo della tempesta, che lo esclude dalla sua cull mask.
  - Finito il riscaldamento gli strati tornano giusti (lo dice l'elenco), quindi qui non si vede niente. Ma è una coincidenza da tenere a mente.

## Non verificato

- **La sala intera col renderer vero**, compreso il riscaldamento della schermata di caricamento sulla GPU: non entra in memoria. Il riscaldamento delle zone (`disegna_fuori_vista`, `disegna_a_pezzi`) gira anche senza schermo, e gli strati dopo sono giusti.
- **La Risalita caricata tardi.** Il caso in cui la porta del ponte aspetta davvero le stanze non è capitato: le stanze erano già pronte. Lo prova `test_strada` con l'attesa.
- **Le prestazioni sulla GPU vera.**
