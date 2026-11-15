# Lo squalo nel fiume lento (SqualoFiume, build 0.5.0)

Scelta A del GDD (15 novembre). Il mostro-squalo del risveglio segue la ciambella nell'acqua scura del fiume lento.
- Mentre segue si vedono solo la pinna dorsale e la scia.
- Quando attacca esce la testa con la bocca spalancata, col collo e la gobba del dorso dietro. Braccia, gambe, coda e pancia restano sotto.
- Il primo tratto (l'imbarco) è calmo. Dopo il primo bivio arrivano uno sbuffo alle spalle, la pinna e la scia.

La creatura e la macchina a stati sono di mascotte: `godot/scripts/creature/squalo_fiume.gd`. Il lato del fiume è di enigmi: dove vive lungo i tratti, la ripartenza dall'imbarco, Continua, i checkpoint, F9 «Fiume lento».

## Come si attacca (enigmi)

1. Un nodo `SqualoFiume` nel fiume (per esempio figlio di FiumeLento), con una **guida**: `squalo.guida = <oggetto>`. È un oggetto con questi metodi, tutti nel mondo:
   - `ciambella() -> Vector3`: dove sta la ciambella, sul pelo;
   - `dietro(m: float) -> Vector3`: il punto del fiume m metri dietro la ciambella, lungo la strada che ha fatto (anche nel tratto prima), sul pelo;
   - `avanti(m: float) -> Vector3`: il punto m metri davanti, sul pelo (serve solo vicino alla ciambella);
   - `velocita() -> float`: la velocità della ciambella (FiumeLento.v; nei tratti a velocità fissa quella del tratto);
   - `puo_attaccare() -> bool`: falso nel tratto d'imbarco, sullo scivolo in fondo a un ramo sbagliato, durante il nero e mentre il giocatore non è sulla ciambella;
   - facoltativo `durata_giro() -> float`: quanto dura un giro (s), per fare tre attacchi a giro. Senza, un attacco ogni 16-24 s.
2. **Quando compare.** Dopo il primo bivio il fiume chiama `squalo.comincia()`: lo sbuffo alle spalle, poi la pinna e la scia. Fuori dal fiume, o con l'interruttore spento, chiama `squalo.ferma()`.
3. **I segnali:**
   - `morde`, con `letale` acceso, quando la bocca si chiude davanti alla camera. Il fiume fa il nero e la ripartenza morbida dall'imbarco, sulla ciambella, con le paratie come le aveva lasciate. Non passa da `GameState.kill_player`/`respawn()`. Conta una morte (`GameState.morti_totali`, di ambienti-1). Poi chiama `squalo.riparti(false)`: sparisce. Dopo il primo bivio il fiume lo richiama con `comincia()`. Con `riparti(true)` riprende subito a seguire, a 12 m.
   - `urta`, con `letale` spento: il fiume fa girare la ciambella su sé stessa per `giro_urto` (3 s).
   - `compare`, `attacca` e `respinto`, per suoni o altro, se servono.
4. **L'interruttore:** `abilitato` (spento, sparisce) e `letale` (spento, urta invece di mordere).
5. **Riscaldamento:** intorno al disegno fuori vista del fiume chiama `squalo.posa_per_il_riscaldamento(true, punto)`: lui a bocca aperta con la scia. Alla fine chiama `posa_per_il_riscaldamento(false)`. Così il primo attacco non compila niente. Non fa niente se sta già seguendo.

## Nel fiume lento del gioco (enigmi)

Il nodo è `Risalita/Fiume/FiumeLento/Squalo`, creato da `scripts/risalita/fiume_gioco.gd`. La guida è `FiumeLento.GuidaSqualo`. I numeri sono esportati su FiumeLento, nel gruppo «Squalo»:
- `squalo_attivo` (l'interruttore: spento non compare) e `squalo_letale` (spento: urta e fa girare la ciambella invece di mordere).
- **Dove vive.** Nel tratto d'imbarco è calmo. Uscendo dall'imbarco il fiume chiama `comincia()`, anche nei rami sbagliati. Quando un ramo sbagliato riporta all'imbarco chiama `ferma()`, e così all'approdo.
- **Quando non attacca** (`puo_attaccare()` falso): nel tratto d'imbarco, negli ultimi `calmo_in_fondo_ai_rami` 14 m di un ramo sbagliato (lo scivolo), negli ultimi `calmo_prima_del_bivio` 20 m prima di un bivio (un urto lì farebbe perdere il disco), durante il nero, senza giocatore sulla ciambella, all'approdo.
- **Il morso:** il nero scende in `nero_giu` 0,25 s, resta `nero_fermo` 0,6 s e si schiarisce in `nero_su` 0,8 s. Nel nero la ciambella torna all'inizio dell'imbarco, girata verso valle, con le paratie come le aveva lasciate. La zona non si ricarica e non c'è `respawn()`. I primi morsi contano in `GameState.morti_totali`, se c'è.
- **Regola B** (coordinatore, 15 novembre): dopo `morsi_per_giro` 2 morsi nello stesso giro lo squalo urta soltanto, anche se lo si respinge, fino all'approdo. Il conto non si azzera con la ripartenza morbida: si azzera al checkpoint dell'approdo e con la partita nuova. Gli urti non contano come morti. Così chi non lo respinge mai arriva al terzo tentativo.
- **L'urto:** la ciambella gira su sé stessa per `giro_urto` dello squalo (3 s), partendo da `giri_urto` 0,6 giri al secondo e rallentando. Non la sposta dal tratto: non spinge in un ramo sbagliato e non fa perdere il bivio giusto.
- **Continua, checkpoint, F9 «Fiume lento»:** lo squalo riparte calmo (`ferma()`), e ricomincia uscendo dall'imbarco. Nel salvataggio del fiume ci sono `arrivato` e `morsi_giro`.
- **Riscaldamento:** `risalita_gioco.gd` lo mette in posa a bocca aperta, a metà del primo tratto giusto, mentre disegna il fiume fuori vista (`_riscalda_squalo_del_fiume` e il giro a pezzi).
- **Profondità vera:** il pelo è a −0,22 m e il fondo a −0,9 m, cioè 0,68 m d'acqua. La ciambella galleggia 0,12 m sopra il pelo (`pelo_sopra_la_ciambella`).

Test sul fiume vero: `godot/tests/test_squalo_strada.gd` (27 controlli): calmo all'imbarco e in fondo ai rami, i due morsi e la ripartenza morbida, il terzo tentativo che arriva all'approdo con gli urti, mai fuori strada, chi lo respinge sempre, chi a volte, letale spento, ripartenza calma dai checkpoint. Nei test che fanno solo la strada del fiume (`test_fiume_gioco`, `test_risalita`, `test_strada`, `test_presa_vera`) lo squalo è spento.

## Cosa fa (numeri esportati)

- **Segue** a `distanza` 12 m lungo il fiume, quando la ciambella va a `velocita_media` (2,2 m/s). La sua velocità è la media più `richiamo` × (metri in più). Con la ciambella lenta si avvicina: a 1,2 m/s sta a circa 5,5 m, mai sotto `distanza_min` (4 m). Con quella veloce resta indietro: a 3,2 m/s circa 18 m.
- **Attacca** tre volte per giro, se la guida dice `durata_giro()`. Accelera di `carica` (2,6 m/s più della ciambella) e a `distanza_attacco` (6 m) esce la testa a bocca aperta (`squalo_minaccia`). Dalla testa fuori al morso passano `tempo_morso` 3,0 s. La prima volta, finché il giocatore non l'ha respinto, sono `primo_morso` 4,0 s.
- **Respinta:** `getto_per_respingere` 0,5 s di getto di fila sul muso (bersaglio di 0,45 m sulla bocca) lo ricacciano sotto. Torna indietro e non attacca per almeno `pausa_respinta` 8 s.
- **Morso:** la camera è tirata giù verso la bocca, lui girato verso la camera. A 0,55 s (`MORSO_T`) la bocca si chiude, con `morso` e `squalo_denti`, ed emette `morde`. La camera torna al suo posto con `riparti()`.
- Dopo `riparti()` niente attacchi per `calma_ripartenza` 3 s, e poi un intervallo intero.

## I movimenti

Sono in `assets_src/mascotte/squalo_fiume.py` e finiscono in `godot/assets/models/mascotte/mostro_squalo_A_fiume.glb` (lo scheletro del risveglio, solo le animazioni del fiume). L'origine sta sul pelo e lui guarda verso +Z.
- `fiume_nuota` (ciclo 1,6 s): fuori solo la pinna, 22 cm.
- `fiume_emerge` (0,6 s).
- `fiume_attacco` (ciclo 1 s): la testa fuori fino a 0,5 m, la bocca a 0,27 m.
- `fiume_respinto` (0,8 s): finisce 0,9 m sotto, pinna compresa.
- `fiume_morso` (0,9 s).

Il controllo (`--controlla`) guarda la pelle deformata, non le ossa. In ogni fotogramma fuori dall'acqua ci sono solo la pinna (nuotata) o la testa col collo e la gobba (attacco). Alla fine del respinto non esce niente.

La scia è una V di schiuma che scorre (`shaders/creature/scia_squalo.gdshader`), più forte quando carica e attacca. Si spegne quando va sotto.

## Profondità

Nuotando lui arriva circa 1 m sotto il pelo (il corpo sdraiato). Nell'attacco, dritto, circa 1,9 m sotto. Se l'acqua del fiume è più bassa, i piedi attraversano il fondo: l'acqua è scura e non si vede, ma va guardato negli scatti. Dimmi la profondità vera e accorcio la posa.

## Test

`godot/tests/test_squalo_fiume.gd` (19 controlli), con un fiume finto: segue, si avvicina e si allontana, non attacca quando non può, l'attacco coi suoi tempi, il getto sul muso, l'urto, il morso davanti alla camera, la ripartenza, gli attacchi per giro.
