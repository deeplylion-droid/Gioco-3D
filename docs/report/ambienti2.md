# Report: ambienti tecnici e scivoli (branch `lavoro/ambienti-2`)

Agente degli ambienti tecnici del capitolo 1. Ultimo aggiornamento: 15 ottobre 2026.

## Kit di dettagli per la sala principale (nuovo compito del coordinatore, 15 ottobre)

**Stato: primo giro finito.** In `assets_src/ambiente_dettagli/` (istruzioni in `README.md`):

- **96 dettagli in 8 GLB** (detriti, cavi, tubi e condotte con bocchette, cassette elettriche e quadro, corpi lampada, cartelli con soli disegni, alghe secche e incrostazioni, catene e corde), con più varianti. Usano i materiali e la palette `sala_a` del kit della sala; le texture nuove sono CC0 2K di ambientCG. 8 piccoli oggetti (giocattoli, ciabatta, maschera da sub) fatti con Meshy.
- **`posizionamento.json`: 479 posti suggeriti nella sala**, in coordinate Godot, trovati con dei raggi sulla geometria vera dei GLB della sala: pavimento libero, muri piatti senza oblò e porte, soffitto della galleria, bordi e fondo della piscina. Il percorso dallo spawn al piedistallo resta pulito. Provato in Godot 4.7.2: tutte le istanze si caricano; c'è lo snippet GDScript nel README.
- **Render da mostrare**: `docs/report/render_ambienti2/dettagli_vetrina.jpg` (render Cycles della vetrina) e lo screenshot dal motore, prima e dopo: `dettagli_godot_muro_prima.jpg` / `dettagli_godot_muro_dopo.jpg` (Godot 4.7.2, con lo script delle luci della sala).
- Scelte: niente collisioni (sono decorativi); niente luci dentro i dettagli (accesi/spenti si cambia il materiale); cartelli solo con pittogrammi; ho tolto un cartello con la mascotte disegnata, perché l'aspetto della mascotte lo decide l'utente.


## Cosa è finito

Tutti e quattro i pezzi sono **finiti**: modelli 3D, GLB per Godot e render Cycles (1600x900, denoiser OIDN, dal punto di vista del giocatore).

| Pezzo | GLB (in `assets_src/ambienti_tecnici/glb/`) | Render da mostrare all'utente (in `docs/report/render_ambienti2/`) |
|---|---|---|
| Sala pompe | `sala_pompe.glb` (35 MB) | `sala_pompe.jpg`, `sala_pompe_scrivania.jpg`, `sala_pompe_leva.jpg` |
| Camera delle onde | `camera_onde.glb` (33 MB) | `camera_onde.jpg`, `camera_onde_pale.jpg` |
| Tubi degli scivoli (13 moduli) | `scivoli_kit.glb` (23 MB) | `scivolo_interno.jpg`, `scivolo_bivio.jpg` |
| Vasca d'arrivo | `vasca_arrivo.glb` (30 MB) | `vasca_arrivo.jpg` |

I render più rappresentativi, da mostrare per primi: `sala_pompe.jpg`, `camera_onde.jpg`, `scivolo_interno.jpg`, `vasca_arrivo.jpg`.

Ho verificato l'import dei GLB in Godot 4.7.2: nodi, perni degli oggetti mobili, luci e collisioni arrivano giusti.

**Pronti per il gioco** (richiesta del coordinatore del 14 ottobre):
- collisioni semplificate in tutti i GLB, con i suffissi dell'importer: scatole convesse `-convcolonly` per muri, pavimenti, pompe, filtri, arredo, ringhiere; trimesh `-colonly` per l'interno dei tubi. Quelle degli oggetti mobili (turbine, leva, porta, grate, paratie, pale, portello, pulsante) sono figlie dell'oggetto e si muovono con lui. Corpi statici: sala pompe 61, camera delle onde 103, kit dei tubi 20, vasca 32;
- `assets_src/ambienti_tecnici/INTEGRAZIONE.md`: come importare e montare, con le posizioni in coordinate Godot di luci, acqua, vapore e oggetti interattivi, e le uscite dei moduli dei tubi.

## Cosa c'è dentro

**Sala pompe** (18 x 12 m, alta 5,5 m, un piano sotto la sala): tre pompe centrifughe arrugginite, ognuna verniciata del suo colore (gialla, rossa, blu) e con la sua **turbina d'avviamento** davanti: una girante a 8 pale rivolta verso il giocatore, così il getto la fa girare come una girandola. Le turbine sono oggetti separati con il perno sull'asse (`TURBINA_1..3`). E poi: mandate verticali con valvole a volantino e manometri, collettore sul soffitto, tubi di servizio, due grandi filtri tondi con boccaporto imbullonato, vasca di raccolta incassata nel pavimento con l'acqua nera, cordolo a strisce e ringhiera, scrivania con monitor CRT (neve sullo schermo) e sedia, leva grande in alto dietro una grata (`LEVA`, `GRATA_leva`), porta stagna verso il ponte inferiore col maniglione (`PORTA_ponte`), lo **schema a colori** sul muro, luci rosse d'emergenza, un neon azzurro funzionante e tre spenti, vapore dalle valvole.

**Camera delle onde** (tunnel di 26 m, largo 4,4 e alto 4,2): pozzo con scala alla marinara e **portello aperto** che sale al fondo della piscina, tre nicchie allagate con le **grandi pale** delle onde mosse da un albero a gomiti con volani gialli e bielle (oggetti separati), bocche grigliate verso la piscina, bocchette tonde dell'aria con alette sul muro opposto, condotta dell'aria, **due paratie** a ghigliottina con guide e luci rosse, canaletta grigliata, pavimento bagnato.

**Tubi degli scivoli** (diametro interno 1,6 m): plastica colorata consumata, giunture ogni 2 m con anello e bulloni dentro e flangia fuori, striscia d'acqua che scorre sul fondo, luci di servizio color ambra. Moduli: dritto, curve a 45° e 90° (destra e sinistra), inizio e fine discesa, discesa dritta, mezza spirale, **tratto trasparente**, **tratto spaccato** (partenza e arrivo, bordi frastagliati), **bivio** (camera di smistamento d'acciaio con due uscite e due paratie a ribalta con un bersaglio colorato), **grata cieca** per la strada sbagliata.

**Vasca d'arrivo** (7 x 10 m, come quella della sala): bocca dello scivolo con bordo a campana, il tubo che risale verso la torre su pilastri, **grata di sicurezza** a ghigliottina che cala (`GRATA_sicurezza`), pulsante a fungo su un palo giallo (`PULSANTE_grata`), scaletta, griglie di scolo, ciambelle e pallone in acqua, neon rosa e azzurro, luci rosse.

## Scelte prese (da confermare con l'utente se vuole)

- **Stile**: concept A (buio, ruggine, rosso d'emergenza, neon azzurro, vapore) con i colori saturi solo su pompe, schema e scivoli.
- **Ordine delle pompe**: lo schema dice **blu, giallo, rosso, poi la leva** (dischi colorati, puntini 1-2-3 e frecce, nessun testo). Nella sala le pompe stanno, da sinistra, gialla, rossa e blu: l'ordine non coincide con la posizione, così c'è un minimo di enigma.
- **Turbine d'avviamento**: giranti assiali rivolte verso il giocatore (si leggono bene e il getto frontale le fa girare in modo credibile).
- **Bivio**: invece di un tubo che si sdoppia, una camera di smistamento d'acciaio con due bocche e due paratie a ribalta. È più leggibile in gioco e si costruisce bene. La paratia da colpire ha un bersaglio colorato al centro (giallo a sinistra, rosso a destra).
- **Colori degli scivoli**: gli stessi della torre fatta dall'agente dell'ambiente (rosso, verde, blu, giallo). Il tubo principale dell'inseguimento è **rosso**, i rami del bivio verde e blu, il tratto spaccato giallo.
- **Luce nei tubi**: luci di servizio stagne color ambra sul cielo del tubo. Nei render c'è anche la luce rosa di lei alle spalle (solo nel render, non nel GLB).
- **Vasca d'arrivo**: stesse texture e misure della vasca nella sala (acqua a -0,22, fondo a -1,10).
- Nessuna scritta con i nomi provvisori. Le uniche scritte sono i numeri della scala dei manometri (0-8).

## Problemi e cose da sapere

- **Diametro dei tubi**: nel kit dell'agente dell'ambiente gli scivoli della torre hanno diametro interno **1,0 m**; i miei moduli, come chiedeva il compito, sono da **1,6 m** perché il giocatore ci deve stare dentro. Il livello dice che ci si butta "nel tubo più grande": propongo che il tubo dell'inseguimento sulla torre sia da 1,6 m e gli altri restino da 1,0 m. Va deciso col coordinatore.
- Nella sala principale c'è già una vasca d'arrivo (in `sala_torre_scivoli.glb`). La mia ha in più la bocca grande con la grata e il pulsante: si può usare al suo posto, oppure prenderne solo bocca, grata e pulsante.
- L'acqua (`ACQUA_*`) ha un materiale segnaposto: nei render quella che scorre nei tubi sembra una striscia scura e lucida. Lo shader vero lo fa l'agente dell'acqua.
- Le luci ad area (neon, schermo del CRT) il glTF non le esporta: vanno aggiunte in Godot. Le intensità delle altre luci vanno regolate.
- Le turbine, la leva, le pale, le paratie e la grata sono pronte per essere animate, ma le animazioni e le collisioni non le ho fatte: le collisioni dei tubi per l'inseguimento vanno fatte a parte (binario o collisioni dedicate), come dice anche il KIT dell'ambiente.
- Le texture sono 1K (2K solo le piastrelle della sala pompe e quelle prese dal kit della sala): il coordinatore chiedeva 2K, ma così i GLB supererebbero i 50 MB. Oggi pesano tra 23 e 35 MB. Per averle a 2K si possono esportare le texture fuori dal GLB e condividerle tra le stanze: è un lavoro di un'ora, lo faccio se serve.

## Come si rigenera

Vedi `assets_src/ambienti_tecnici/README.md`: texture CC0 da ambientCG, tre oggetti Meshy (scrivania, monitor, sedia), tutto il resto procedurale con gli script `tools/blender/ambienti2_*.py`. Licenze in `assets_src/ambienti_tecnici/LICENZE.md`.
