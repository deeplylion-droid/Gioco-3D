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
- **Zaino-pompa**: `marker_zaino_pompa` in Godot (14,50; 1,25; -8,43), sui due ganci centrali liberi della rastrelliera, schiena verso il muro est.
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

## Tappa 2: gli interni montati nel gioco (Godot)

Su richiesta del coordinatore ho montato gli ambienti nel progetto del gioco. Lavoro sul mio branch `lavoro/ambienti-1`, in cui ho unito `lavoro/godot`: non ho creato `lavoro/interni`, perché posso pubblicare solo su questo branch.

- `godot/scenes/interni/interni.tscn`: scena autonoma (si genera con `tools/godot_interni_scena.py`) con i tre glTF nelle coordinate comuni, collisioni, gameplay e luci. Istruzioni e righe esatte per metterla nella sala in `godot/scenes/interni/README.md` (traslazione (-9,7; 0; 40,9), `giocatore_proprio = false`, Player della sala in (10,7; 0; 39,65) girato verso ovest).
- `godot/scripts/interni/interni.gd`: risveglio a terra (la camera si rialza), giocatore senza zaino, neon del modello trasformati in `Neon` (sfarfallano), luci rosse in `LuceEmergenza` (alcune pulsano), docce che si aprono da sole (getti dell'addon acqua e vapore), armadietto che sbatte, tornello che si sblocca col pulsante dietro il vetro.
- `godot/scripts/interni/saracinesca.gd`: `PoweredDoor` che alza il modello vero, comandata dalla turbina.
- Zaino-pompa (`PackPickup`) sulla rastrelliera dello stanzino; vasca lava-piedi come prima fonte d'acqua (`WaterTank` + acqua dell'addon); Polaroid P1, P2 (nell'armadietto aperto) e P3 (bacheca); 6 checkpoint invisibili con `order` da -10 a -5.
- Texture importate in compressione VRAM (con le normal map marcate), `.import` versionati.
- Test `godot/tests/test_interni.gd` (24 controlli, aggiunto alla CI): la scena si carica con le collisioni, il giocatore parte dal marker, lo zaino si prende, la vasca lava-piedi riempie il serbatoio e il livello scende, il getto preme il pulsante del tornello attraverso il vetro rotto, la turbina alza la saracinesca e l'uscita è libera, la Polaroid P2 si raggiunge. `check_scripts` 0 errori, `test_mechanics` 58/58, `test_sala` 33/33.
- Screenshot dal motore (1600×900): `docs/report/render_ambienti1/interni_corridoio.jpg`, `interni_spogliatoi.jpg`, `interni_lavapiedi.jpg`, `interni_stanzino.jpg` (lo zaino sulla rastrelliera), `interni_docce.jpg` (docce aperte).

Ritocchi alla sorgente per il gameplay: la collisione degli armadietti copre solo la parte posteriore (la Polaroid P2 è raggiungibile) e il buco del vetro rotto è libero (il getto deve arrivare al pulsante).

Da fare nella sala principale (non toccata): togliere `PostazioneBagnini` (lo zaino ora è nello stanzino) e le Polaroid 01-03 (sono negli interni).

### Correzioni dalla revisione di qualità

- Vetro sporco trasparente in Godot (alfa 0,18, rugosità 0,1, senza culling): dal corridoio lava-piedi si vede il pulsante del tornello nel gabbiotto (`interni_vetro.jpg`).
- Tolto il poster doppio nello stanzino: resta quello sulla bacheca.
- Luci: Environment `AmbienteHorror` (AgX), una ReflectionProbe d'interno per zona, `LuceEmergenza` a energia 2, solo i neon `_tubo_sfarfalla` accesi (nodo `Neon`). La lucina del pulsante del tornello illuminava tutto il corridoio: ora ha portata 1,2 m.
- La vasca lava-piedi è un `WaterTank` (già nel gruppo `water_sources`) con `acqua_per_vasca.tscn` stile limpido.
- Non fatto (per la 0.2.1): convertitore dei pavimenti bagnati e vernice scrostata meno uniforme, con texture propria per gli armadietti.

## Pezzo campione di qualità (15 ottobre, da approvare dall'utente)

Richiesta: l'utente ha bocciato la qualità della v0.2.0 (forme squadrate, texture ripetute, tornello in bassa definizione). Ho rifatto un pezzo campione: corridoio del risveglio, zona del tornello con la vasca lava-piedi, interno dello stanzino. **Mi fermo qui finché l'utente non dà un riscontro.**

**Da mostrare all'utente** (screenshot da Godot 1600×900, stessi punti prima e dopo):

| Prima | Dopo |
|---|---|
| `docs/report/qualita_interni/prima_corridoio.jpg` | `docs/report/qualita_interni/dopo_corridoio.jpg` |
| `docs/report/qualita_interni/prima_lavapiedi.jpg` | `docs/report/qualita_interni/dopo_lavapiedi.jpg` |
| `docs/report/qualita_interni/prima_stanzino.jpg` | `docs/report/qualita_interni/dopo_stanzino.jpg` |

Cosa è cambiato:
- **Oggetti Meshy di qualità alta** (meshy-7.1, geometria 4k, texture PBR 4K ridotte a 2K, remesh a 8-60 mila triangoli): tornello a tutta altezza (telaio e rotore separati), finestra del gabbiotto, quadro con il pulsante, porta tagliafuoco, porte di servizio (sala pompe, stanzino, fondo), armadietti (chiusi interi; quelli aperti con l'anta ricavata dal modello), panche, lampade d'emergenza a gabbia, plafoniere dei neon, valvole a volantino, cartello del pavimento bagnato, rastrelliera, scrivania, bacheca. Script: `assets_src/ambienti_interni/meshy_hq/genera_hq.py` (le immagini di riferimento in `rif/` sono solo un input interno). Integrazione: `tools/blender/ambienti1_hq.py`.
- **Architettura meno a scatole**: battiscopa e listello tra zoccolo e parete, costole e travi smussate, telai delle porte smussati, bordi della vasca a toro, tubi più rotondi.
- **Texture senza ripetizioni** (shader in `godot/shaders/interni/`, applicati da `scripts/interni/materiali_interni.gd`): pareti con vernice intera, macro-variazione in spazio mondo, giunti dei pannelli con rivetti, colature scure dall'alto, sporco in basso, scrostature solo in basso, vicino ai tubi e in poche chiazze; piastrelle con tinta diversa per ogni piastrella, fughe in rilievo (parallasse) e chiazze bagnate a specchio. Decal di colature di ruggine, crepe e macchie d'acqua.
- Nessun poster nuovo. Luci, ombre e post-processing non toccati (li fa la sessione grafica), salvo i materiali emissivi delle lampade.
- Stesse coordinate e stesso gameplay: `test_interni` 24/24, `test_sala` 43/43, `check_scripts` 0 errori. Lo zaino è appeso davanti alla nuova rastrelliera (`marker_zaino_pompa` ora in (14,50; 1,25; -8,43)).

Crediti Meshy usati per il campione: circa 750.

### Secondo giro sul campione (soffitti e usura)

- **Soffitti da nave** nel corridoio, nel corridoio lava-piedi, nel gabbiotto e nello stanzino: pannelli di lamiera smussati con i giunti aperti, ordinate, un pannello mancante (si vede il buio sopra) e uno staccato che pende (corridoio e stanzino); condotto dell'aria con flange e bocchette, canalina con i cavi (uno pende), sprinkler sul tubo rosso (testina Meshy). Funzioni in `tools/blender/ambienti1_build.py`: `soffitto_nave`, `condotto_aria`, `canalina_cavi`, `sprinkler`.
- **Macchie d'acqua sul soffitto** fatte nello shader con il rumore in spazio mondo: chiazze con l'alone, mai uguali.
- **Usura delle pareti** (shader `parete.gdshader`, tutto in spazio mondo): tinta diversa per ogni pannello, colature di ruggine sotto alcuni rivetti, aloni d'acqua scesi dal soffitto con il bordo scuro, strisciate in basso, sporco più scuro verso il pavimento, rivetti con l'anello; due lamiere ammaccate nel corridoio, lontano dal cartellone.
- Scatti di controllo da Godot: `docs/report/qualita_interni/giro2_corridoio.jpg`, `giro2_lavapiedi.jpg`, `giro2_stanzino.jpg` (la luce è ancora quella vecchia: la rifà la sessione grafica).
- Test: `test_interni` 24/24, `test_sala` 43/43, `check_scripts` 0 errori.

## Ambienti tecnici: camera delle onde e sala pompe (tappe 5-6)

Scena `godot/scenes/tecnici/tecnici.tscn` (si rigenera con `python3 tools/godot_tecnici_scena.py`), istruzioni per l'integratore in `godot/scenes/tecnici/LEGGIMI.md`. Percorso: fondo della scala del pozzo sotto il portello → camera delle onde (24 m, pale, bocchette, due paratie) → tunnel → sala pompe.

- **Modelli Meshy nuovi** (`assets_src/ambienti_tecnici/meshy_hq/`, generati con `genera_hq.py`, stessa pipeline degli interni): tre pompe (gialla, rossa, blu), turbina d'avviamento, filtro tondo, manometro, quadro elettrico, quadro strumenti, monitor a tubo, leva, paratia. Scrivania, sedia, porta e lampade sono quelle degli interni.
- **Shader senza ripetizioni**: cemento, lamiere e piastrelle usano gli shader degli interni (`parete.gdshader` ha la nuova modalità `usa_base`, che prende le texture del glTF e ci aggiunge variazione, colature e sporco in coordinate mondo). Decal di ruggine, macchie e crepe in punti scelti.
- **Tubi** con flange e bulloni, raccordi curvi; gli spigoli delle scatole sono smussati.
- **Collisioni** nei glTF; le parti mobili (paratie, porta, grata, leva, turbine) hanno la collisione come figlia. Test: `tests/test_tecnici.gd` (45 controlli, anche in CI).
- **Marker** per la logica in `Marker/` (pompe, turbine, leva, grata, schema, vasca, monitor, porta, paratie, portello, arrivo scala).
- **Texture** in `godot/assets/ambienti_tecnici/texture/` (25 MB): dopo ogni export da Blender vanno alleggerite con `tools/comprimi_texture.py`. Se cambia solo il `.bin` Godot non reimporta da solo: cancellare `.godot/imported/<nome>.gltf-*`.
- **Raccordo di servizio** (`tools/blender/ambienti2_raccordo.py`, `raccordo.gltf`): dalla porta del ponte inferiore un corridoio e due rampe di scale a 36° (sale di 7,25 m) fino ai piedi della scala degli interni. Per tenerlo corto la scena tecnica va nel livello girata di -90° (vedi LEGGIMI). Il test cammina dalla sala pompe fino in cima con le due scene messe come nel livello.
- **Vasca di raccolta** piena d'acqua nera (pelo a -0,15), già collegata all'addon acqua (`WaterTank` + `WaterTankLink`, stile scuro).
- **Scala degli interni sistemata** (commit separato, ok del coordinatore): apertura alta 0,5 m nel muro del pianerottolo sopra la scala (prima c'era solo 1,80 m di luce e il giocatore urtava) e rampa di collisione lunga quanto la scala (prima finiva 17 cm sopra il pavimento, in cima e in fondo).

Screenshot Godot, preset Alto, 1600 × 900: `docs/report/tecnici/`.
