# Kit modulare dell'acquapark (capitolo 1)

Specifiche e regole per i pezzi dell'ambiente: la nave da crociera anni '90 abbandonata, di notte.
Tutto si rigenera dagli script in `tools/blender/ambiente_*.py` (vedi in fondo). Per montare la
sala principale in Godot leggi `INTEGRAZIONE.md`.

## Stato

- **Sala principale (vertical slice): fatta**, palette `sala_a` = Opzione 1 adattata al concept A
  (scelta del coordinatore come la più vicina al concept A e allo storyboard). Le Opzioni 2 e 3
  restano alternative: basta `--palette` negli script e si rigenerano le texture.
- Proposte in attesa dell'utente: `docs/proposte/ambiente/` (angolo di prova in 3 palette, oggetti).

## Unità, assi, griglia

- **Metri**, scala reale. In Blender Z in alto; il GLB esce con Y in alto (glTF), come Godot.
  Conversione: `(x, y, z)_Blender -> (x, z, -y)_Godot`.
- **Griglia di posa 0,5 m**; moduli principali **2 m**; pezzi di riempimento da 0,5 m e 1 m.
- Altezza di un ponte (modulo di parete del kit): **3 m**. Nella sala (40 x 44 m, x da -20 a 20,
  y da -20 a 24 in Blender): 4 m sotto la galleria, soffitto a 11,5 m, cupola fino a 18 m.

## Misure reali usate

| Elemento | Misura |
|---|---|
| Piastrelle pareti e vasche | 12,5 x 12,5 cm (texture 1,5 m = 12 piastrelle) |
| Mosaico (Opzione 2, piedistallo) | 5 x 5 cm (texture 1,2 m = 24 tessere) |
| Pavimento antiscivolo | 25 x 25 cm (texture 1,5 m = 6 piastrelle) |
| Fasce della parete | zoccolo 0-0,25; piastrelle 0,25-0,75; fascia 0,75-1,0; piastrelle 1,0-2,0; intonaco sopra |
| Vasca standard / piscina a onde / vasca d'arrivo / vasche bimbi | 1,2 m / 2,0 m (spiaggia a 0) / 1,1 m / bordo 0,45 m |
| Bordo a sfioro | canale con griglia 25 cm (listelli ogni 3 cm) + copertina in ceramica 25 cm con toro |
| Scaletta della vasca | tubo inox Ø 43 mm, corrimano a 50 cm, alto 0,92 m sul ponte, gradini ogni 30 cm |
| Ringhiera | corrimano Ø 50 mm a 1,05 m (SOLAS chiede almeno 1,0 m), sbarre Ø 16 mm ogni 11 cm |
| Porta degli spogliatoi (kit) | doppia anta, luce 1,8 x 2,4 m, telaio metallico |
| Vano della sala verso gli spogliatoi | luce 1,2 x 2,2 m, porta stagna aperta (anta 1,4 x 2,3 m, 6 leve, volantino) |
| Porta stagna (da fare) | luce 0,8 x 1,9 m, soglia 0,3 m, angoli arrotondati, 8 tiranti |
| Oblò | luce Ø 60 cm, flangia Ø 84 cm con 12 bulloni, manicotto nello spessore (20 cm), centro a 1,5 m |
| Galleria | profonda 3 m, soletta 0,3 m, a 4,0 m (sala) / 3,0 m (kit) |
| Scivoli | tubo chiuso Ø interno 1,0 m, vetroresina 12 mm, flange imbullonate ogni 2 m; quello dell'inseguimento Ø 1,6 m, parete 6 cm |
| Plafoniera al neon | 2 tubi T8 da 120 cm (Ø 26 mm) |
| Luce d'emergenza | plafoniera stagna Ø 18 cm con gabbia e vetro rosso |
| Cartelloni | 2,4 x 1,35 m (kit) e 3,2 x 1,8 m (sala), solo disegni, nessuna scritta |
| Torre degli scivoli | 6 x 6 m, piani a 3,0 / 6,0 / 8,6 m, pozzo centrale 2,2 m, gradini da 18 cm |

## Centro della sala: la vasca sollevata (per la medusa affacciata)

Deciso dall'utente il 15 ottobre (GDD, "Il centro della sala"): al posto della statua sul monumento c'è la
**vasca sollevata** del concept `docs/concept/medusa_sbircia.jpg`, con dentro la medusa affacciata, immobile,
le mani sul bordo verso l'ingresso. Nodo `sala_vasca_centrale` in `sala_vasca_centrale.glb`.

- Centro Godot **(0, 0, 10)**; pianta esterna **6,0 x 4,5 m** (x per z) con angoli arrotondati r 0,5.
- Muro alto 1 m: **cima del bordo a 1,0 m**, coping largo **0,30 m** con il toro esterno (r 3,75 cm), bagnato e
  lucido; muro esterno rientrato di 3 cm sotto il toro. **Acqua a 0,88**, fondo interno a 0.
- Piastrelle da **25 cm a scacchi blu notte e crema** (`vasca_alta`, texture 2K su 3 m = 680 px/m), fughe scure
  in rilievo, ogni piastrella col suo tono, crepe e macchie; le UV seguono il perimetro (le piastrelle girano
  negli angoli). Sporco nei colori dei vertici: schizzi in basso, righe dove l'acqua è traboccata, alghe sotto
  l'acqua. Fascia RGBA di **alghe e calcare sulla linea dell'acqua** (`decal_calcare`).
- Marker **`medusa_affacciata`** in `sala_dati.json`: origine consigliata (0; 0,88; 11,75), rotazione (0, 0, 0),
  guarda verso +Z; mani sul coping in (±0,45; 1,0; 12,1).
- Pulsante della sigla sul muro davanti (nodo `sala_pulsante_piedistallo`), cordone di velluto a 1,3 m dal bordo
  con il varco davanti, lampione, 2 fari dalla galleria e 2 luci sott'acqua, offerte dei bambini intorno.
- Il **monumento della statua** (piedistallo a gradoni, piano 3,7 m, fregio marino) resta per più avanti:
  `glb/per_dopo/sala_monumento.glb`, si rifà con `ambiente_sala.py --glb <cartella> --monumento`.

## Passata di qualità della sala (ottobre)

Tutto in `tools/blender/ambiente_sala.py`, `ambiente_kit.py` e `ambiente_dettagli.py`:

- **Pavimento** a piastrelle da 25 cm con **un solo materiale**: umidità e sporco sfumati nei colori dei
  vertici (i tre materiali asciutto/umido/bagnato scelti piastrella per piastrella facevano chiazze a
  quadretti, tolti nella passata HQ); pozzanghere a specchio opache, 3 mm sopra il pavimento.
- **Sporco nei colori dei vertici** calcolato in spazio mondo (pareti, pavimento, galleria, piscina,
  scivoli, torre, giochi): niente ripetizioni. Pareti e pavimento hanno vertici ogni 25 cm.
- **Profili**: battiscopa a sguscio (raggio 8 cm) tra pavimento e piastrelle, listelli ai bordi della
  fascia rossa, toro bianco a 2 m dove finiscono le piastrelle; gocciolatoio e rivetti sul fronte della
  galleria; rivetti e irrigidimenti sulle travi del soffitto; piastre imbullonate e capitelli sulle
  colonne; spigoli smussati su torre e struttura di gioco.
- **Piastrelle mancanti** a gruppi (colla a righe di spatola, `M_amb_malta`) sulle pareti e in piscina.
- **Oblò** con vetro scuro e aloni di sale (`M_amb_vetro_oblo`, opaco: riflette con SSR).
- **Cupola**: costoloni e anelli a T, piastre imbullonate negli incroci, lesene sul tamburo; lastre da un
  atlante a 4 varianti (sporca con rivoli di pioggia, molto sporca con alghe, incrinata, velata);
  8 lastre rotte con le schegge nel telaio e i vetri caduti sotto (lì il pavimento è bagnato).
- **Luci**: plafoniere navali calde accese (`luce_calda_*`) tra le rosse, insegne al neon disegnate
  (onda azzurra sopra il vano, stella-sole gialla sopra l'area bimbi; un tratto spento).
- **Revisione di qualità**: vernice navale grigio-verde su colonne, sostegni, galleria e ringhiere
  (`metallo` #5f6d69, prima era bianca con la ruggine: sembravano tronchi di betulla); piano del
  piedistallo in piastrelle avorio lucide con un velo d'acqua (`piano_statua`, rugosità circa 0,06);
  due teli da 2 x 3 m con la mascotte (grafiche di `assets_src/ambienti_interni/poster`) appesi alla
  trave ai lati della statua, girati verso l'ingresso, con un faretto caldo ciascuno (`luce_cartellone_*`);
  tolti i due cartelloni del lato est.
- **Tubo dell'inseguimento** (lo scivolo rosso a spirale): Ø interno 1,6 m, parete 6 cm, flange ogni
  2 m con 12 bulloni, come i moduli di `assets_src/ambienti_tecnici/glb/scivoli_kit.glb`. La bocca
  sputa nella vasca d'arrivo da est, 16 cm sopra l'acqua. Gli altri due tubi restano da 1,0 m.

## Passata HQ della sala (al livello del pezzo campione)

- **Oggetti di scena rifatti con Meshy** come gli interni di ambienti-1 (`assets_src/ambiente/oggetti_hq/genera_hq.py`):
  immagine di riferimento nano-banana-pro nello stile del campione (bordi morbidi smussati, usura leggera)
  -> image-to-3d meshy-7.1, geometria 4k, PBR, remesh a triangoli. Nel repository i GLB hanno le texture
  già ridotte a 2K JPG (le 4K si riscaricano dal task in `<nome>.json`). Stessi nomi e stesse misure dei
  vecchi (lettino, salvagente, sedia del bagnino, paperella, pallone, ciambella, tubi, delfino, balena,
  orsacchiotto, fungo-fontana, cannoncino) più quelli nuovi: colonnina d'ottone del cordone, lampione
  col braccio, cestino a pesce, cartello giallo del pavimento bagnato, secchio gigante; la panca è quella
  HQ degli spogliatoi. In sala le texture sono 2K per gli oggetti grandi, 1K per i piccoli.
- **Lampione**: il modello HQ si gira e si scala da solo perché la lampadina cada dove c'è `luce_lampione`
  (la luce non si sposta); la lampadina che sfarfalla resta `M_amb_lampadina`, nel nodo `amb_lampione`.
- **Secchio gigante**: modello HQ nello stesso nodo `sala_secchio_gigante`, con i mozzi sul perno (asse x)
  e la stessa collisione; il gioco lo fa ribaltare come prima.
- **Cordone**: colonnine HQ (istanze), il velluto e le collisioni delle campate restano quelli di prima.
- **Arredi nuovi** (`arredi()` in `ambiente_sala.py`): 5 panche lungo i muri, 5 cestini, 4 cartelli
  (uno caduto), fuori dai percorsi.
- **Struttura di gioco** ancora fatta a mano (pedane e collisioni del gioco), con pali tondi a cappuccio,
  piastre di base, smussi più larghi e tubi più fitti.
- **GLB uguali col monumento e con la vasca**: le offerte dei bambini stanno nel GLB del centro
  (`sala_vasca_centrale.glb` o `sala_monumento.glb`), `sala_oggetti.glb` e `sala_architettura.glb` non
  dipendono dal centro (zone libere calcolate sempre sull'ingombro della vasca col cordone, che copre
  anche il monumento).

### Buco del pozzo (tappa 5)

Nel fondo della piscina a onde, sotto il portello, c'è il buco verso il pozzo della camera delle onde:
`BUCO_POZZO` in `ambiente_sala.py`, cioè x ±0,64 e y da -2,64 a -1,36 in Blender (Godot z da 1,36 a
2,64). La griglia del fondo ha le linee anche sul bordo del buco, quindi lo smusso e il collare
piastrellato (fino a 24 cm sotto lo scarico) condividono i vertici del fondo, senza fessure. La
collisione è la copia della mesh, quindi segue il buco. Il portello è quadrato e copre il buco.

## Convenzioni dei nomi

- Pezzi del kit: `amb_<pezzo>_<misure>[_variante]`, per esempio `amb_parete_2x3_oblo`, `amb_bordo_vasca_2`.
- Pezzi della sala: `sala_<parte>` (`sala_pavimento`, `sala_torre`, `sala_secchio_gigante`...).
- Materiali: `M_amb_<materiale>` (kit e sala), `M_prop_<oggetto>` (oggetti Meshy). Lo stesso nome
  in tutte le palette: cambia solo la texture.
- Oggetti di scena in sala: `ogg_<oggetto>_<n>` (istanze dello stesso modello).
- Collisioni: `<nome>-convcolonly` (convesse: scatole, rampe, tratti di tubo) e `<nome>-colonly`
  (trimesh: pavimento, piscina). Nomi sempre unici: un `.001` finale romperebbe il suffisso in Godot.

## Pivot

- Moduli di parete, pavimento, galleria: angolo in basso a sinistra sul fronte (x=0, y=0, z=0);
  il fronte guarda -y, lo spessore va verso +y.
- Bordo vasca: sul filo della parete della vasca, la vasca sta verso +y; angolo esterno: sullo spigolo.
- Oblò, luci d'emergenza, cartelloni: al centro (o al centro in basso), sul filo del muro.
- Oggetti di scena: alla base, al centro. Secchio gigante e ruota a pale: sul loro asse di rotazione.

## UV e densità delle texture

- UV0 in **scala reale**: 1 unità UV = il lato reale della texture del materiale (1,5 m piastrelle,
  1,2 m mosaico, 2 m intonaco, 1 m metalli e plastiche). Niente atlas: le texture si ripetono.
- Le texture a piastrelle sono **allineate**: una fuga cade sul bordo della texture. Ogni pezzo lungo
  un multiplo di 12,5 cm si accosta al vicino senza giunte visibili.
- Densità: 1365 px/m piastrelle, 1024 px/m intonaco, 2048 px/m metalli (texture 2K). Obiettivo:
  almeno 1024 px/m vicino al giocatore, 512 px/m per soffitti e superfici lontane.
- UV2 (lightmap): la genera Godot all'import se si usa LightmapGI.
- Colore dei vertici (COLOR_0): sporco e umidità che risale dal pavimento. In Godot serve
  `vertex_color_use_as_albedo` (lo accende lo script `godot/ambiente_post_import.gd`).

## Materiali e texture

- Texture CC0 da ambientCG e Poly Haven, 2K, in `textures/cc0/<nome>/` con nomi uniformi:
  `_col` (colore sRGB), `_nrm` (normal OpenGL), `_orm` (R occlusione, G rugosità, B metallo), `_alt` (altezza).
  Fonti e licenze: `textures/LICENZE.md`.
- Le palette ricolorano le CC0 (ogni piastrella prende il suo colore, sporco e fughe conservati):
  `textures/derivate/<palette>/`. Ricette in `tools/blender/ambiente_palette.py`.
- Bagnato: ogni piastrella del pavimento (25 cm) prende uno di tre materiali con la stessa texture di
  colore e rugosità diverse (`pavimento_asciutto`, `pavimento`, `pavimento_bagnato`), scelti da un
  campo in spazio mondo (più bagnato vicino alle vasche, sotto le lastre rotte della cupola e lungo il
  bordo della galleria). Le pozzanghere sono mesh a parte con la texture del pavimento (le fughe
  combaciano), lisce come specchi (`M_amb_pozzanghera`): con SSR riflettono.
- Sporco: colori dei vertici calcolati in spazio mondo (`tools/blender/ambiente_dettagli.py`): umidità
  che risale con la linea della marea, colature dall'alto, angoli più sporchi, linea dell'ultimo livello
  dell'acqua nella piscina. Le fughe delle piastrelle hanno la normal map più forte (`normale` 1,6).
- Grigliati e rosa dei venti: PNG con alfa (alpha scissor in Godot).
- Oggetti Meshy: GLB grezzi in `oggetti/<nome>/<nome>_meshy.glb` (texture ricompresse in JPG, la
  geometria è quella di Meshy); in sala hanno texture 1K se piccoli, 2K se grandi. Se esiste la versione
  HQ in `oggetti_hq/<nome>.glb` la sala usa quella.

## LOD e poligoni

- I LOD li genera Godot all'import (`meshes/generate_lods`, attivo di serie): i pezzi sono già leggeri.
- Sala: i numeri aggiornati di ogni GLB sono in `INTEGRAZIONE.md` (architettura circa 210 mila
  triangoli con pavimento e pareti più fitti per lo sporco nei colori dei vertici).
- Se servono più prestazioni: `visibility_range_end` sugli oggetti piccoli (palloni, paperelle) a 25-30 m.

## Collisioni

- Muri, colonne, galleria, ringhiere, piedistallo, lampione, oggetti: scatole convesse.
- Pavimento e piscina a onde: trimesh (seguono buchi, pendenza e conca).
- Torre: piani intorno al pozzo, parapetti, colonne, rampe inclinate (convesse).
- Struttura di gioco: pedane, parapetti, scala, passerelle e ponte (si sale davvero).
- Scivoli: tratti convessi di circa 2 m intorno al tubo (fuori). L'interno per l'inseguimento va
  fatto a parte (percorso su binario o collisioni dedicate).

## Export GLB per Godot

- `ambiente_kit.py`: un GLB per pezzo del kit. `--texture incorporate` (di serie, autonomo) oppure
  `--texture nessuna` (solo nomi dei materiali, file piccolissimi, da usare con materiali condivisi).
- `ambiente_sala.py --glb <cartella>`: la sala in 8 GLB + `sala_dati.json` (vedi `INTEGRAZIONE.md`).
- Opzioni usate: Y in alto, modificatori applicati, normali e UV, colori dei vertici, immagini nel
  formato originale (JPG; PNG solo con alfa), qualità JPG 88. Verificato l'import in Godot 4.7.2.

## Come si rigenera tutto

```
PY=/home/user/tools/blender-venv/bin/python
$PY tools/blender/ambiente_texture.py scarica              # texture CC0 (2K) + allineamento fughe
$PY tools/blender/ambiente_texture.py deriva sala_a        # texture della palette (anche p1_..., p2_..., p3_...)
$PY assets_src/ambiente/oggetti/meshy_oggetti.py immagini   # Meshy: immagini di riferimento (crediti!)
$PY assets_src/ambiente/oggetti/meshy_oggetti.py modelli    # Meshy: modelli 3D (crediti!)
python3 assets_src/ambiente/oggetti_hq/genera_hq.py [--immagini] [nomi]   # Meshy HQ (crediti!): solo quelli che mancano
$PY tools/blender/ambiente_oggetti.py ricomprimi --copia <cartella fuori dal repo>
$PY tools/blender/ambiente_sala.py --glb assets_src/ambiente/glb/sala          # GLB della sala
$PY tools/blender/ambiente_integrazione.py                                      # INTEGRAZIONE.md dai GLB
flock /home/user/tools/render.lock nice -n 10 $PY tools/blender/ambiente_sala.py --render S04_statua --uscita <cartella>   # render Cycles (max 1600x900)
$PY tools/blender/ambiente_kit.py --palette sala_a --uscita <cartella>          # pezzi del kit
nice -n 10 $PY tools/blender/ambiente_anteprima.py --palette p1_bianco_turchese --uscita <cartella>  # angolo di prova
$PY tools/blender/ambiente_proposte.py angolo <cartella render>                 # JPG con le etichette
```

Gli script Meshy salvano gli ID dei task in `meshy_task.json`: rilanciandoli non si ripagano i task già fatti.

## Da fare

Porte stagne, scale per la galleria, spogliatoi e corridoi, camera delle onde e sala pompe, tubo rotto,
angoli interni del bordo vasca, varianti rotte delle piastrelle (le CC0 "C" e "D" sono già pronte da usare).
