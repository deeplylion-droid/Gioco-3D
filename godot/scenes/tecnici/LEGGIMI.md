# Ambienti tecnici: camera delle onde e sala pompe (tappe 5-6)

`tecnici.tscn`: dal portello sul fondo della piscina a onde si scende con la scala del pozzo nella **camera delle onde** (24 m di camera + pozzo, pale, bocchette, due paratie), poi un **tunnel** di 12 m porta alla **sala pompe** (18 × 12 m, h 5,5). Script: `scripts/tecnici/tecnici.gd` (materiali, luci segnaposto, decal). Modelli: `assets/ambienti_tecnici/camera_onde.gltf` e `sala_pompe.gltf`, fatti da `tools/blender/ambienti2_camera_onde.py` e `ambienti2_sala_pompe.py` con `TECNICI_GODOT=1` (modelli Meshy in `assets_src/ambienti_tecnici/meshy_hq/`). La scena si rigenera con `python3 tools/godot_tecnici_scena.py`: i marker si leggono dai glTF, quindi restano giusti se i modelli cambiano.

Coordinate Godot, metri, pavimento a y = 0. La camera corre lungo +X; la sala pompe è il nodo `Ambienti/SalaPompe` in (37,3; 0; -2,2).

## Da sola

Si avvia così com'è (F6): crea il giocatore su `marker_arrivo_scala` (guarda verso est, lungo la camera) e l'Environment. Con `giocatore_proprio = false` non crea niente dei due.

Test: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_tecnici.gd`.
Screenshot: `tests/screenshots_tecnici.gd` (istruzioni in cima al file).

## Collisioni

Già nei glTF (suffissi `-colonly` / `-convcolonly`, diventano StaticBody3D): pavimenti, muri, soffitti, scala del pozzo (rampa), pale, pompe, turbine, filtri, vasca, ringhiera, scrivania, sedia, gabbia della leva, paratie, porta.

**Attenzione**: le collisioni delle parti che si muovono sono **figlie** del loro modello (`PARATIA_n`, `PORTA_ponte_anta-convcolonly` sotto `PORTA_ponte`, `GRATA_leva_anta` sotto `GRATA_leva`, `LEVA_braccio` sotto `LEVA`, `TURBINA_n_disco` sotto `TURBINA_n`): muovendo il nodo si muove anche la collisione. Le paratie e la porta sono **StaticBody3D**: se servono come porte vere conviene farle `AnimatableBody3D`.

## Marker (`Marker/`)

| Marker | Posizione | A cosa serve |
|---|---|---|
| `marker_portello` | (0; 6,8; 0) | il portello sul fondo della piscina a onde, in cima al pozzo |
| `marker_arrivo_scala` | (0,6; 0; 0) | in fondo alla scala, guarda verso +X. Spawn e checkpoint |
| `marker_paratia_1`, `_2` | (17,5; 2,65; 0), (21; 2,2; 0) | bordo basso delle paratie, alzate. Per chiudere scendono lungo -Y di 2,65 e 2,2 m (nodi `PARATIA_1`, `PARATIA_2`, origine sul bordo basso) |
| `marker_tunnel_sala_pompe` | (24; 0; 0) | vano 2,6 × 2,8 m nel muro est della camera: inizio del tunnel |
| `marker_pompa_1..3` | (31,5 / 36,0 / 40,5; 1,0; -5,25) | corpi delle pompe (muro nord) |
| `marker_turbina_1..3` | (31,8 / 36,3 / 40,8; 1,2; -3,25) | centro delle turbine d'avviamento (Ø 1,5 m), davanti alle pompe. Asse Z: guardano verso +Z, verso la stanza |
| `marker_leva` | (46,11; 3,61; -5,11) | mozzo della leva grande, in alto sul muro est; il braccio va verso nord (-Z) e in alto |
| `marker_grata_leva` | (45,35; 4,0; -4,55) | cardine della grata davanti alla leva |
| `marker_schema` | (46,27; 2,0; -2,6) | schema a colori sul muro est |
| `marker_vasca_raccolta` | (36,5; -0,45; 0,9) | superficie dell'acqua nera (vasca 4,8 × 3,2 m, x 34,1…38,9, z -0,6…2,4 globali; fondo a -1,7) |
| `marker_monitor` | (41,57; 1,05; 2,96) | schermo del monitor a tubo sulla scrivania (`SCHERMO_CRT`) |
| `marker_porta_ponte` | (45,3; 0; 1,4) | davanti alla porta del ponte inferiore, lato sala |
| `marker_porta_ponte_perno` | (46,25; 0; 1,4) | cardine della porta del ponte inferiore |

## Cosa collegare (scripts/mechanisms/)

- **Turbine** (`TURBINA_1` gialla, `TURBINA_2` rossa, `TURBINA_3` blu, da ovest a est): un `Turbine` su ogni `marker_turbina_n`, rotazione 0 (lo script guarda verso +Z come la turbina), `radius = 0.75`, `show_model = false`, `external_rotor` = il nodo `Ambienti/SalaPompe/TURBINA_n` (ruota sul suo asse Z locale). La tinta la mette `tecnici.gd`.
- **Ordine giusto** (lo schema): **blu, giallo, rosso**, cioè `TURBINA_3`, `TURBINA_1`, `TURBINA_2`. Poi la leva.
- **Pompe**: `POMPA_n` sono i corpi fermi; per il "ruggito" basta vibrarli e far partire i vapori sugli empty `VAPORE_pompa_n`, `VAPORE_collettore`, `VAPORE_perdita_ovest`.
- **Leva**: `LEVA` ruota sull'asse **X** (perpendicolare al muro) intorno al suo mozzo: alzata a 0, abbassata a circa -70° attorno all'asse X globale (`LEVA.global_rotate(Vector3.RIGHT, deg_to_rad(-70))`: il nodo ha già una rotazione su Y, quindi non basta `rotation.x`). Si colpisce col getto attraverso la grata: la `GRATA_leva` è di rete, quindi la sua collisione va messa su un livello che ferma il giocatore ma non il getto (come il vetro del gabbiotto negli interni). Se si vuole che la grata si apra, ruota su Y intorno a `marker_grata_leva`.
- **Vasca di raccolta**: un `WaterTank`/`WaterVolume` sulla forma della vasca; l'acqua `ACQUA_vasca_raccolta` è una lastra che si può abbassare.
- **Monitor**: `SCHERMO_CRT` è la mesh dello schermo; per le immagini della telecamera (statua, sagoma B3, poi neve) basta un `material_override` con una ViewportTexture o una texture animata. `LUCE_crt` è la sua luce.
- **Paratie** ("come esci"): dopo la leva scendono (vedi sopra), il giocatore resta chiuso nella sala.
- **Porta del ponte inferiore**: `PORTA_ponte` ruota su Y intorno a `marker_porta_ponte_perno`; il maniglione (`PORTA_ponte_maniglione`, figlio) è dal lato della sala. Si apre verso la sala (rotazione positiva).
- **Polaroid P7** "accanto al monitor": la scrivania ha spazio libero a sinistra dello schermo, verso (41,2; 0,8; 3,2).

## Dove va nel livello

- **Sotto la sala principale**: la scena va messa in **`position = (0, -9.05, 1.36)`**, senza rotazione. Così `marker_portello` cade sul portello dello scarico della piscina a onde (`sala_portello_scarico`, (0; -2,25; 1,36)) e il pozzo sale fino al fondo della piscina.
- **Aperto**: la porta del ponte inferiore (`marker_porta_ponte`, globale (45,3; -9,05; 2,76) con la posizione sopra) **non combacia ancora** con la porta della sala pompe del corridoio degli interni (perno (7,32; 0; 41,0) globale, con la scala a 36° che scende). Serve un raccordo (scala o corridoio) o uno spostamento dell'uno o dell'altro: da decidere con chi monta il livello.

## Luci

Solo segnaposto per gli scatti: i neon `*_tubo_sfarfalla` diventano nodi `Neon` (SFARFALLA), le `LUCE_rossa_*` diventano `LuceEmergenza` (qualcuna PULSANTE), le altre `LUCE_*` sono limitate a 2. Le luci finali le fa grafica. `LuceLeva` è una piccola luce calda dentro la gabbia, per leggere la leva da terra. Tre `ReflectionProbe` d'interno in `Atmosfera/`.
