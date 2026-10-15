# Report: ambienti interni dell'inizio del capitolo 1

Branch `lavoro/ambienti-1`. Corridoio del ponte inferiore, spogliatoi (con docce, corridoio lava-piedi, tornello e saracinesca) e stanzino dei bagnini: **finiti, in 3D, pronti per Godot**.

## Da mostrare all'utente

Render Cycles dal punto di vista del giocatore (occhi a 1,62 m), 1600×900 con denoiser:

| Render | Cosa si vede |
|---|---|
| `docs/report/render_ambienti1/corridoio_risveglio.jpg` | il corridoio dal punto del risveglio, luci rosse d'emergenza, acqua a terra, il cartellone in fondo a sinistra |
| `docs/report/render_ambienti1/corridoio_cartellone_vicino.jpg` | il cartellone della mascotte (cartone animato, senza scritte), sbiadito e strappato |
| `docs/report/render_ambienti1/corridoio_porta_pompe.jpg` | la porta della sala pompe accanto al cartellone |
| `docs/report/render_ambienti1/spogliatoi.jpg` | file di armadietti ammaccati (qualche anta gialla o rossa), panche, ciabatte e braccioli, docce in fondo |
| `docs/report/render_ambienti1/spogliatoi_docce.jpg` | le docce con i soffioni, piastrelle anni '90 |
| `docs/report/render_ambienti1/lavapiedi_tornello.jpg` | corridoio con la vasca lava-piedi, il tornello e la saracinesca |
| `docs/report/render_ambienti1/stanzino.jpg` | lo stanzino: salvagenti, rastrelliera dello zaino (posto libero), pronto soccorso |
| `docs/report/render_ambienti1/stanzino_rastrelliera.jpg` | dettaglio della rastrelliera |

Screenshot dal motore (Godot 4.7.2, scena di prova `labs/ambienti1`, senza l'addon grafica): `docs/report/render_ambienti1/godot_corridoio_risveglio.jpg`, `godot_spogliatoi.jpg`, `godot_lavapiedi_tornello.jpg`, `godot_stanzino.jpg`.

## Cosa c'è

- `assets_src/ambienti_interni/gltf/`: `corridoio.gltf`, `spogliatoi.gltf`, `stanzino.gltf` con le texture condivise (36 MB in tutto, ogni file sotto i 50 MB). Stesse coordinate: si mettono tutti all'origine e combaciano.
- **Collisioni** semplificate già nei file (`*-colonly`): verificato che Godot 4.7.2 le importa come StaticBody3D.
- `assets_src/ambienti_interni/INTEGRAZIONE.md`: come montarli in Godot, con tutte le posizioni in coordinate Godot (luci, neon, docce, acqua, pulsante, turbina, saracinesca, rastrelliera dello zaino, uscita verso la sala).
- `assets_src/ambienti_interni/README.md`: pianta, nomi, materiali e licenze.
- Script ripetibili: `tools/blender/ambienti1_texture.py`, `ambienti1_lib.py`, `ambienti1_build.py`, `ambienti1_render.py`; oggetti Meshy con `assets_src/ambienti_interni/meshy/genera_oggetti.py`; cartelloni con `poster/genera_poster.py` e `poster/invecchia.py`.
- `labs/ambienti1/`: scena Godot che carica i tre glTF a runtime e salva screenshot (`godot --path labs/ambienti1 -- tutte <cartella>`).

## Punti chiave per chi integra

- **Uscita verso la sala principale**: vano 1,2 × 2,2 m chiuso dalla saracinesca, `marker_uscita_sala_principale` in Godot (9,70; 0; -20,70), la sala continua verso -Z. Il branch `lavoro/ambiente` non esisteva ancora quando ho lavorato: le misure seguono la richiesta del coordinatore.
- **Zaino-pompa**: `marker_zaino_pompa` in Godot (14,94; 1,25; -8,43), sui due ganci centrali liberi della rastrelliera, schiena verso il muro est.
- **Risveglio**: `marker_risveglio` in (20,40; 0; -1,25), a terra, guarda verso ovest.
- Oggetti che si muovono con l'origine sul perno: porta tagliafuoco, porta della sala pompe (maniglione antipanico dal lato della sala pompe), porta dello stanzino, anta dell'armadietto che sbatte (dentro un salvagente a forma di papera), grata d'aerazione bassa, rotore del tornello, pulsante dietro il vetro rotto, saracinesca (origine come `PoweredDoor`), turbina, soffioni e rubinetti delle 5 docce con i punti d'emissione.

## Scelte di stile prese (da confermare con l'utente)

- **Pareti**: lamiera verniciata crema scrostata sopra, zoccolo verde petrolio scuro sotto, costole della nave ogni 2,5 m e tubi sul soffitto (uno rosso, antincendio). Come lo storyboard S01 e il concept A.
- **Luce**: quasi solo luci rosse d'emergenza a gabbia; neon in gran parte spenti, uno per zona che sfarfalla; un riempimento freddo verde-azzurro molto debole nelle ombre.
- **Colori dello stile B**: cartellone della mascotte nel corridoio, qualche anta di armadietto gialla o rossa, rastrelliera gialla, turbina gialla e rossa, salvagenti bianchi e rossi, ciabatte, braccioli, paperella e pallone colorati.
- **Docce**: piastrelle azzurro pallido con zoccolo di piastrelle verdi anni '90, 5 docce con divisori.
- **Cartellone**: la medusa con un occhio solo, disegnata come un cartone anni '90 (arcobaleno, onde, bolle), invecchiato con macchie d'acqua e strappi. Nello stanzino un poster con la mascotte vestita da bagnina e un cartello di soli pittogrammi. Nessuna scritta, nessun nome.
- **Tornello**: a tutta altezza (rotore a tre bracci), così non si scavalca; il pulsante è in un gabbiotto dietro un vetro con un buco.
- **Scala della sala pompe**: dietro la porta c'è un pianerottolo e una scala che scende di 1,8 m, da collegare alla sala pompe.

## Problemi e note

- I neon nei glTF non hanno la luce (Godot non importa le luci ad area): vanno messi i nodi `Neon` dell'addon `grafica`, posizioni in INTEGRAZIONE.md.
- Il collider del vetro rotto (`vetro_rotto_blocco`) deve fermare il giocatore ma non il getto: va messo sul livello di collisione giusto.
- Le porte e gli altri oggetti mobili non hanno collisione nel file: misure dei box in INTEGRAZIONE.md.
- `tools/meshy.py`: `create`/`wait` ora usano `/v2` per `text-to-3d` (con `/v1` dava 404). Gli altri endpoint restano su `/v1`.
- Crediti Meshy usati: circa 450 (14 oggetti e 3 cartelloni).
- `assets_src/ambienti_interni/texture/` (sorgenti ambientCG, 237 MB) e il `.blend` (150 MB) non sono nel repository: si rigenerano con gli script.

## Licenze

Texture di base CC0 di ambientCG (PaintedMetal004/006/009/011/013, Tiles032/036/040, MetalPlates006/013, Metal063, Rust007, Wood051, Concrete034). Oggetti e cartelloni generati con Meshy per questo progetto.
