# Ambienti tecnici: camera delle onde e sala pompe (tappe 5-6)

`tecnici.tscn`: dal portello sul fondo della piscina a onde si scende con la scala del pozzo nella **camera delle onde** (24 m di camera + pozzo, pale, bocchette, due paratie), poi un **tunnel** di 12 m porta alla **sala pompe** (18 × 12 m, h 5,5). Dalla porta del ponte inferiore un **raccordo di servizio** (corridoio e due rampe di scale, sale di 7,25 m) arriva ai piedi della scala che scende dal corridoio degli interni: ci si passa al ritorno al buio (tappa 7). Script: `scripts/tecnici/tecnici.gd` (materiali, luci segnaposto, decal). Modelli: `assets/ambienti_tecnici/camera_onde.gltf`, `sala_pompe.gltf` e `raccordo.gltf`, fatti da `tools/blender/ambienti2_camera_onde.py`, `ambienti2_sala_pompe.py` e `ambienti2_raccordo.py` con `TECNICI_GODOT=1` (modelli Meshy in `assets_src/ambienti_tecnici/meshy_hq/`). La scena si rigenera con `python3 tools/godot_tecnici_scena.py`: i marker si leggono dai glTF, quindi restano giusti se i modelli cambiano.

Coordinate Godot, metri, pavimento a y = 0. La camera corre lungo +X; la sala pompe è il nodo `Ambienti/SalaPompe` in (37,3; 0; -2,2).

## Da sola

Si avvia così com'è (F6): crea il giocatore su `marker_arrivo_scala` (guarda verso est, lungo la camera) e l'Environment. Con `giocatore_proprio = false` non crea niente dei due.

Test: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tecnici.gd`.
Screenshot: `tests/screenshots_tecnici.gd` (istruzioni in cima al file).

## Collisioni

Già nei glTF (suffissi `-colonly` / `-convcolonly`, diventano StaticBody3D): pavimenti, muri, soffitti, pareti del pozzo, rampe lisce a 36° sotto i gradini del raccordo, pale, pompe, turbine, filtri, vasca, ringhiera, scrivania, sedia, gabbia della leva, paratie, porta.

**Attenzione**: le collisioni delle parti che si muovono sono **figlie** del loro modello (`PARATIA_n`, `PORTA_ponte_anta-convcolonly` sotto `PORTA_ponte`, `GRATA_leva_anta` sotto `GRATA_leva`, `LEVA_braccio` sotto `LEVA`, `TURBINA_n_disco` sotto `TURBINA_n`): muovendo il nodo si muove anche la collisione. Le paratie e la porta sono **StaticBody3D**: se servono come porte vere conviene farle `AnimatableBody3D`.

## Marker (`Marker/`)

| Marker | Posizione | A cosa serve |
|---|---|---|
| `marker_portello` | (0,64; 6,8; 0) | centro del pozzo (vano 1,3 × 1,3) in cima, cioè il centro del portello sul fondo della piscina a onde |
| `marker_arrivo_scala` | (1,24; 0; 0) | in fondo alla scala del pozzo, guarda verso +X. Spawn e checkpoint |
| `marker_paratia_1`, `_2` | (17,5; 2,65; 0), (21; 2,2; 0) | bordo basso delle paratie, alzate. Per chiudere scendono lungo -Y di 2,65 e 2,2 m (nodi `PARATIA_1`, `PARATIA_2`, origine sul bordo basso) |
| `marker_tunnel_sala_pompe` | (24; 0; 0) | vano 2,6 × 2,8 m nel muro est della camera: inizio del tunnel |
| `marker_pompa_1..3` | (31,5 / 36,0 / 40,5; 1,0; -5,25) | corpi delle pompe (muro nord) |
| `marker_turbina_1..3` | (31,8 / 36,3 / 40,8; 1,2; -3,25) | centro delle turbine d'avviamento (Ø 1,5 m), davanti alle pompe. Asse Z: guardano verso +Z, verso la stanza |
| `marker_leva` | (46,10; 3,79; -5,19) | occhio del perno della leva grande (braccio rosso `LEVA` sulla base in ghisa `LEVA_base`), in alto sul muro est; il braccio va verso nord (-Z) e in alto |
| `marker_grata_leva` | (45,35; 4,0; -4,55) | cardine della grata davanti alla leva |
| `marker_schema` | (46,27; 2,0; -2,6) | schema a colori sul muro est |
| `marker_vasca_raccolta` | (36,5; -0,45; 0,9) | superficie dell'acqua nera (vasca 4,8 × 3,2 m, x 34,1…38,9, z -0,6…2,4 globali; fondo a -1,7) |
| `marker_monitor` | (41,57; 1,05; 2,96) | schermo del monitor a tubo sulla scrivania (`SCHERMO_CRT`) |
| `marker_porta_ponte` | (45,3; 0; 1,4) | davanti alla porta del ponte inferiore, lato sala |
| `marker_porta_ponte_perno` | (46,25; 0; 1,4) | cardine della porta del ponte inferiore |
| `marker_chiavistello` | accanto alla porta, lato maniglione | puleggia del `CHIAVISTELLO` (catenaccio giallo e nero sul muro): ci arriva il cavo d'acciaio della leva |
| `marker_chiusura_stagna` | accanto alla porta, lato cardine | cilindro idraulico `ATTUATORE_stagno` della chiusura stagna: ci arrivano i tre tubi delle turbine |
| `marker_raccordo_sala` | (47,2; 0; 1,4) | nel raccordo, appena fuori dalla porta del ponte inferiore |
| `marker_raccordo_interni` | (44,04; 7,25; -7,8) | in cima al raccordo, ai piedi della scala degli interni. Buon posto per un checkpoint della tappa 7 |

## Cosa collegare (scripts/mechanisms/)

- **Turbine** (`TURBINA_1` gialla, `TURBINA_2` rossa, `TURBINA_3` blu, da ovest a est): un `Turbine` su ogni `marker_turbina_n`, rotazione 0 (lo script guarda verso +Z come la turbina), `radius = 0.75`, `show_model = false`, `external_rotor` = il nodo `Ambienti/SalaPompe/TURBINA_n` (ruota sul suo asse Z locale). La tinta la mette `tecnici.gd`.
- **Ordine giusto** (lo schema): **blu, giallo, rosso**, cioè `TURBINA_3`, `TURBINA_1`, `TURBINA_2`. Poi la leva.
- **Pompe**: `POMPA_n` sono i corpi fermi; per il "ruggito" basta vibrarli e far partire i vapori sugli empty `VAPORE_pompa_n`, `VAPORE_collettore`, `VAPORE_perdita_ovest`.
- **Leva**: `LEVA` (il braccio rosso) ruota sull'asse **X** (perpendicolare al muro) intorno all'occhio del perno: alzata a 0, abbassata a circa -70° attorno all'asse X globale (`LEVA.global_rotate(Vector3.RIGHT, deg_to_rad(-70))`: il nodo ha già delle rotazioni, quindi non basta `rotation.x`). `LEVA_base` è fissa. Si colpisce col getto attraverso la grata: la `GRATA_leva` è di rete, quindi la sua collisione va messa su un livello che ferma il giocatore ma non il getto (come il vetro del gabbiotto negli interni). Se si vuole che la grata si apra, ruota su Y intorno a `marker_grata_leva`.
- **Leva e chiavistello, turbine e chiusura stagna** (questionario del 15 ottobre: deve essere chiaro a cosa servono). Dalla leva un **cavo d'acciaio** con due pulegge corre lungo il muro est fino al `CHIAVISTELLO` accanto alla porta: abbassando la leva il catenaccio si sfila (basta spostare il nodo di 0,12 m allontanandolo dalla porta, cioè verso -Z nelle coordinate della scena dei tecnici). Dalle tre turbine partono **tre tubi dei loro colori** (giallo, rosso, blu) che salgono, corrono sotto il soffitto e scendono sull'`ATTUATORE_stagno` dall'altro lato della porta: quando le tre turbine girano nell'ordine giusto, la chiusura stagna si sblocca. Cavo, pulegge e tubi sono in `SALA_meccanismi` (fermi).
- **Vasca di raccolta** (piena d'acqua nera, da lì si ricarica il serbatoio dello zaino): è già collegata all'addon acqua. `Acqua/VascaRaccolta` è un `WaterTank` (4,8 × 1,7 × 3 m, origine al centro del fondo, `fill` 0,91 = pelo a -0,15, 80 litri, `suckable`); `Acqua/AcquaVascaRaccolta` è il `WaterTankLink` dell'addon con lo stile `stile_3_scura`, che disegna la superficie e la fa scendere quando si aspira. La lastra `ACQUA_vasca_raccolta` del glTF è solo un segnaposto e `tecnici.gd` la nasconde. La scatola dei riflessi (`env_box_*`) la calcola `tecnici.gd` in coordinate mondo, quindi resta giusta anche con la scena girata.
- **Monitor**: `SCHERMO_CRT` è la mesh dello schermo; per le immagini della telecamera (statua, sagoma B3, poi neve) basta un `material_override` con una ViewportTexture o una texture animata. `LUCE_crt` è la sua luce.
- **Paratie** ("come esci"): dopo la leva scendono (vedi sopra), il giocatore resta chiuso nella sala.
- **Porta del ponte inferiore**: `PORTA_ponte` ruota su Y intorno a `marker_porta_ponte_perno`; il maniglione (`PORTA_ponte_maniglione`, figlio) è dal lato della sala. Si apre verso la sala (rotazione positiva).
- **Polaroid P7** "accanto al monitor": la scrivania ha spazio libero a sinistra dello schermo, verso (41,2; 0,8; 3,2).

## Dove va nel livello

Righe da aggiungere a `scenes/sala_principale.tscn` (accanto agli interni, che restano in (-9,7; 0; 40,9)):

```
[ext_resource type="PackedScene" path="res://scenes/tecnici/tecnici.tscn" id="tecnici_1"]

[node name="Tecnici" parent="." instance=ExtResource("tecnici_1")]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 0, -9.05, 1.36)
giocatore_proprio = false
```

cioè `position = (0, -9.05, 1.36)` e `rotation_degrees.y = -90`. Così:

- `marker_portello` cade in (0; -2,25; 2,0), al centro del portello dello scarico della piscina a onde (`sala_portello_scarico` ha la cerniera a nord, in z 1,36, e va fino a 2,64): il pozzo sale fino al fondo della piscina, dove il buco lo apre il GLB della sala. Si sale e si scende con `Gioco/ScalaPozzo`, un `Ladder` alto 6,8 m contro la parete del pozzo verso la camera (-X locale, nord globale). Il coperchio `PORTELLO` in cima al pozzo nel glTF della camera è un segnaposto: con il portello della sala va nascosto; la camera delle onde corre verso sud (+Z globale), sotto la sala, e la sala pompe finisce sotto il retro degli interni (y da -9,05 a -3,55: non tocca niente);
- `marker_raccordo_interni` cade in (7,8; -1,8; 45,4) globali, proprio ai piedi della scala che scende dalla porta "sala pompe" del corridoio degli interni. Il raccordo chiude anche i fianchi e il fondo di quella scala;
- il soffitto del pianerottolo in cima al raccordo arriva a +0,8 globale, appena a sud del muro degli interni (z da 44,8 a 47): lì non deve esserci altro.

**Scala degli interni**: perché si possa percorrere, il muro sud del loro pianerottolo ha un'apertura alta 0,5 m sopra la scala (luce 2,3 m) e la loro rampa di collisione va dal bordo del pianerottolo fino al piano di sotto (commit separato sugli interni). Dal mio lato `attacco_scala_interni` raccorda la loro rampa al pianerottolo in cima al raccordo. Il test cammina dalla sala pompe fino davanti alla porta "sala pompe" del corridoio.

## Luci

Solo segnaposto per gli scatti: i neon `*_tubo_sfarfalla` diventano nodi `Neon` (SFARFALLA), le `LUCE_rossa_*` diventano `LuceEmergenza` (qualcuna PULSANTE), le altre `LUCE_*` sono limitate a 2. Le luci finali le fa grafica. `LuceLeva` è una piccola luce calda dentro la gabbia, per leggere la leva da terra. Tre `ReflectionProbe` d'interno in `Atmosfera/`.
