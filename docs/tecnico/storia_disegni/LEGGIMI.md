# I disegni del bambino con la scatola: come si mettono

Build 0.5.0, «La storia» (GDD del 15 novembre, righe «Build 2»). Il bambino con la scatola aiuta il giocatore coi suoi disegni: fogli a pastello attaccati ai muri con il nastro di carta, firmati in basso a destra con un quadratino turchese col sorriso (la sua scatola). Li usano ambienti-1 (D1, D2), ambienti-2 (D3, D4, DZ) ed enigmi (DF).

## I fogli

Sono in `godot/assets/storia_disegni/` (1024×1365, JPG q90, compressi VRAM con mipmap):

| File | Dove | Cosa c'è |
|---|---|---|
| `disegno_d1.jpg` | corridoio del risveglio (ambienti-1) | l'omino arancione in basso, una freccia grossa, la scialuppa in alto |
| `disegno_d2.jpg` | dopo la sala pompe, verso la Risalita (ambienti-1) | la vasca con la medusa, l'omino che le gira intorno lontano dal bordo, la scala, la scialuppa |
| `disegno_df.jpg` | corridoio del fiume (enigmi) | il fiume ad anello, l'omino sulla ciambella, lo squalo dietro, lo spruzzo verso lo squalo |
| `disegno_d3.jpg` | prima della torre (ambienti-2) | la torre coi tubi colorati, l'omino che sale, la freccia, la scialuppa in cima |
| `disegno_d4.jpg` | inizio del tunnel (ambienti-2, A3 orizzontale) | il tubo, l'omino che corre e spruzza indietro, la medusa dietro, la porta tonda e la scialuppa |
| `disegno_dz.jpg` | il foglio del finale (ambienti-2, formato A4) | la fila di bambini per mano, l'omino in mezzo, la medusa sopra che tiene tutti per mano |

Sorgenti e script in `assets_src/storia_disegni/`: `genera_disegni.py` (Meshy), `prepara_fogli.py` (taglio, misura, firma; mette la firma anche sui due disegni che c'erano già), `pastello.py` (Blender), `impronte.py`. Il foglio con tutti e otto affiancati: `assets_src/storia_disegni/anteprima/otto_disegni.jpg`.

## Il componente `DisegnoBambino`

`godot/scripts/game/disegno_bambino.gd` (classe `DisegnoBambino`, anche nell'editor). Un nodo con lo script, niente scena da istanziare: tutto si costruisce dai parametri.

- **L'origine è il centro del foglio, sulla superficie del muro che si vede.** Il foglio guarda verso **+Z** del nodo (il muro è dietro, a z = 0). Il nodo si gira solo attorno alla verticale.
- `disegno`: la texture del foglio.
- `formato`: A3 (29,7 × 42 cm, verticale), A4 (21 × 29,7, per DZ) o A3_ORIZZONTALE (42 × 29,7, per D4).
- `altezza`: quanto il centro del foglio sta sopra il pavimento. L'ha attaccato un bambino: fra 1,0 e 1,2 m (D1 è a 0,84, perché nel corridoio del risveglio c'è una fascia sul muro a 1,07-1,13 m: un foglio sopra la fascia non starebbe piatto).
- `emissione`: 0,12, come il disegno dei giocattoli (i pastelli si vedono appena al buio). Non cambiarla senza chiedere.
- Il foglio è una lastra di carta di 0,4 mm col retro sul muro; davanti il disegno; quattro pezzi di nastro di carta di sbieco sugli angoli, a cavallo fra il foglio e il muro.
- **`pastello`** (facoltativo): un pastello a cera turchese per terra sotto il foglio (`assets/storia_disegni/pastello.glb`, sdraiato su una faccia, origine sul pavimento). `pastello_dove` è dove sta (x lungo il muro, y fuori dal muro, in metri, nel sistema del nodo), `pastello_giro` quanto è girato.
- **`impronte`** (facoltativo): una fila di impronte bagnate dei suoi piedi nudi (Decal), da `impronte_da` (x lungo il muro, y fuori dal muro, sul pavimento) fin sotto il foglio, a passi alternati, le prime più asciutte. **Devono arrivare da dove lui può essere passato**: una porta, un buco, l'acqua. In D1 vengono dalla porta degli spogliatoi (le docce).

Ognuna delle due aggiunte va messa solo se ha un perché in quel posto.

## Come si mette

1. Scegli il muro sulla strada, dove il foglio si vede senza cercarlo, e un punto a 1,0-1,2 m.
2. Trova il punto esatto sul muro che si vede con lo strumento comune (Posa), che controlla anche che il muro sia piano sotto tutto il foglio:
   ```
   flock /home/user/tools/render.lock godot --headless --path godot --script res://tests/run.gd -- \
     res://tests/storia/posa_disegni.gd res://scenes/<zona>.tscn "x,y,z" "verso x,y,z" A3 "pastello x,z"
   ```
   `verso` è la direzione verso cui guarda il foglio (fuori dal muro). Stampa l'origine da scrivere nella scena, lo scarto del muro sotto il foglio (deve essere 0: con `PROFILO=1` davanti al comando stampa il profilo del muro in verticale, per vedere fasce e pannelli), cosa c'è davanti, il pavimento e l'altezza del centro, e dove si appoggia il pastello. Un oggetto fermo si posa una volta così e il posto si scrive nella scena (regola di `docs/tecnico/posizionamento/LEGGIMI.md`).
3. Scrivi il nodo nella scena con quei valori (esempio: `StoriaD2` in `scenes/sala_principale.tscn`):
   ```
   [node name="StoriaD2" type="Node3D" parent="Tecnici"]
   transform = Transform3D(-4.371139e-08, 0, -1, 0, 1, 0, 1, 0, -4.371139e-08, 52.5996, 1.1, 1.5)
   script = ExtResource("storia_disegno")
   disegno = ExtResource("storia_d2")
   pastello = true
   pastello_dove = Vector2(0.15, 0.1)
   ```
4. Controlla:
   - `tests/test_disegni_bambino.gd` (in CI): per ogni `DisegnoBambino` della sala, il foglio a contatto col muro in 25 punti, niente davanti, il centro fra 0,8 e 1,25 m, il pastello appoggiato, le impronte sul pavimento. Se il tuo disegno sta in un'altra scena (la torre, il tunnel), aggiungi la scena al test;
   - il controllo di posizionamento (`tests/controllo_posizionamento.gd`): 0 casi nuovi;
   - il giro dagli occhi del giocatore, e il collaudo prima della build (scatto ravvicinato degli angoli col nastro).

## DF nel gioco (enigmi)

Il corridoio del fiume è costruito da codice: il foglio lo mette `RisalitaGioco._disegno_df` (`godot/scripts/risalita/risalita_gioco.gd`), nodo `Risalita/StoriaDF`. Sta sul muro in fondo al corridoio, dietro il bambino col cubo, al centro del muro (x da xc a xc + 2, la faccia a z = fine), A3 col centro a 1,1 m. Il pastello è per terra sotto il foglio; le impronte bagnate vengono dalla porta del capannone, cioè dal fiume (il pavimento è piano). test_disegni_bambino lo trova nella sala (la Risalita è figlia della sala) e lo controlla come gli altri. Scatti in `docs/proposte/storia_fiume/df_*.jpg`.

Il pannello chiaro a destra in `df_3_davanti_riflesso_cielo.jpg` non è un pezzo del corridoio (sonda `df_sonda` di `tests/collaudo/scatti_storia_fiume.gd`, 15 novembre). Nella Risalita non c'è nessuna ReflectionProbe. Il pannello misura 0,130 di luminosità nei primi 5 fotogrammi disegnati dopo il salto della camera, poi da solo 0,033-0,038, cioè il muro com'è, qualunque pezzo si nasconda (130 pezzi provati). È un residuo dei primi fotogrammi dello scatto: la camera salta lì col disegno fermo, e probabilmente un effetto che si accumula nel tempo, forse la nebbia volumetrica, non si è ancora assestato. Negli scatti di questo corridoio si aspettano almeno 10 fotogrammi disegnati prima di scattare. Resta da rifare df_3 così, per conferma.

## Cose da sapere

- La firma è già nei fogli: non serve aggiungerla.
- Le scritte non ci sono: solo disegni. Non aggiungere targhette o didascalie.
- Le impronte sono Decal: non contano nel controllo di posizionamento, ma il test controlla che stiano sul pavimento. Vanno solo su pavimenti piani.
- Il pastello è piccolo (8,5 cm): non è un ingombro, ma non metterlo davanti a una porta o su un gradino.
