# Ambienti tecnici: come montarli in Godot

Sala pompe, camera delle onde, tubi degli scivoli e vasca d'arrivo. Misure in metri, scala reale.
Le coordinate qui sotto sono **già in Godot** (Y in alto), lette dai GLB importati in Godot 4.7.2.
Da Blender: `(x, y, z) -> (x, z, -y)`. Ogni GLB ha la sua origine: si istanzia dove serve nel livello.

## Import

1. Copia i GLB di `assets_src/ambienti_tecnici/glb/` nel progetto.
2. **Collisioni**: già nei GLB, con i suffissi dell'importer. `-convcolonly` (scatole convesse: muri, pavimenti, pompe, filtri, ringhiere) e `-colonly` (trimesh: interno dei tubi). Diventano da sole StaticBody3D + CollisionShape3D, invisibili.
   Le collisioni degli oggetti che si muovono (turbine, leva, porta, grate, paratie, pale, pulsante) sono **figlie dell'oggetto**: si muovono con lui. Se servono come AnimatableBody3D, basta cambiare il tipo del nodo.
3. **Materiali**: PBR (colore, normal, rugosità/metallo). Le texture sono **1K** (2K solo le piastrelle della sala pompe e quelle prese dal kit della sala): con 2K i GLB supererebbero i 50 MB. Si possono rifare a 2K esportando le texture fuori dal GLB, se serve.
4. Le grate (`rete_grata`) hanno l'alfa: in Godot mettere **alpha scissor**. `SCIVOLO_trasparente`: trasparenza alpha.
5. **Luci**: le puntiformi e gli spot arrivano come OmniLight3D e SpotLight3D, al loro posto; l'intensità va regolata (rosse d'emergenza `light_energy` 2-3, `omni_range` 6). I **neon** e lo **schermo del CRT** sono luci ad area, che il glTF non porta: in Godot aggiungere una luce sui tubi `neon_*` accesi (sono emissivi) e davanti a `SCHERMO_CRT`.
6. **Acqua**: tutti i nodi `ACQUA_*` sono segnaposto piatti col livello giusto, da sostituire con l'acqua vera.
7. **Vapore e aria**: i nodi `VAPORE_*` e `ARIA_*` sono Node3D vuoti dove mettere le particelle (vapore dalle valvole, soffi dalle bocchette).

## Sala pompe (`sala_pompe.glb`)

Stanza di 18 x 12 m, pavimento a y = 0, soffitto a 5,5 m. Origine al centro del pavimento.

- **Ingresso** dal tunnel della camera delle onde, sul lato ovest (x = -9): `PUNTO_tunnel_camera_onde`.
- **Uscita** dalla porta stagna sul lato est (x = 9): `PORTA_ponte`, cardine verticale sul lato del perno (ruotare attorno a Y), maniglione dal lato della sala. `PUNTO_porta_ponte_inferiore` è il punto davanti alla porta.
- **Pompe**: da sinistra (guardando il muro nord, -Z) gialla, rossa, blu. Le **turbine d'avviamento** `TURBINA_1..3` hanno il perno sull'asse e girano attorno al **loro asse Z locale** (è rivolto verso il giocatore). Il getto le colpisce sul davanti. Extras: `colore` e `ordine`.
- **Ordine giusto** (dallo schema `SCHEMA_pompe` sul muro est, senza testo): **blu (TURBINA_3), giallo (TURBINA_1), rosso (TURBINA_2)**, poi la leva.
- **Leva**: `LEVA`, perno alla base sul muro est, in alto (y = 3,9). Ruota attorno al suo asse Z locale; abbassata = -70°. Sta dentro una gabbia di rete: lo sportello è `GRATA_leva` (cerniera sul lato sud, ruota attorno a Y). Il getto passa attraverso la rete (in gioco: il raycast del getto deve ignorare la collisione della gabbia, oppure lo sportello si apre prima).
- **Vasca di raccolta** (acqua nera da aspirare): `ACQUA_vasca_raccolta`, pelo dell'acqua a y = -0,45, fondo a -1,7; vasca da x -3,2 a 1,6 e da z 1,6 a 4,6. Scaletta sul lato sud.
- **Monitor CRT**: `SCHERMO_CRT` ha UV 0..1, ci va la ViewportTexture della telecamera sulla sala grande (o la neve). `PUNTO_monitor` è il centro dello schermo.
- **Vapore**: `VAPORE_pompa_1..3` (sulle valvole delle mandate), `VAPORE_collettore`, `VAPORE_perdita_ovest`.

### Nodi utili
| Nodo | Tipo | Posizione Godot | Note |
|---|---|---|---|
| `ACQUA_vasca_raccolta` | MeshInstance3D | (-0.80, -0.45, 3.10) |  |
| `GRATA_leva` | MeshInstance3D | (8.05, 4.00, -2.35) |  |
| `LEVA` | MeshInstance3D | (8.83, 3.90, -2.90) | asse_rotazione: Y Blender = -Z Godot; abbassata = -70 gradi |
| `LUCE_rossa_l1` | OmniLight3D | (-8.73, 3.30, -1.00) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l2` | OmniLight3D | (8.73, 3.10, 3.60) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l3` | OmniLight3D | (-3.20, 2.40, -5.73) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l4` | OmniLight3D | (1.20, 3.20, 5.73) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l5` | OmniLight3D | (5.80, 2.40, -5.73) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l7` | OmniLight3D | (8.73, 4.70, -4.00) | colore (1.00, 0.31, 0.22) |
| `PORTA_ponte` | MeshInstance3D | (8.95, 0.00, 4.15) | cardine: asse Z Blender (Y Godot), si apre verso l esterno |
| `PUNTO_monitor` | Node3D | (4.29, 0.99, 5.21) |  |
| `PUNTO_porta_ponte_inferiore` | Node3D | (8.00, 0.00, 3.60) |  |
| `PUNTO_tunnel_camera_onde` | Node3D | (-12.50, 0.00, 2.20) |  |
| `SCHEMA_pompe` | MeshInstance3D | (0.00, 0.00, 0.00) | ordine: blu, giallo, rosso, poi la leva |
| `SCHERMO_CRT` | MeshInstance3D | (0.00, 0.00, 0.00) |  |
| `TURBINA_1` | MeshInstance3D | (-5.50, 1.20, -1.05) | colore: giallo ordine: 2.0 asse_rotazione: Y Blender = -Z Godot |
| `TURBINA_2` | MeshInstance3D | (-1.00, 1.20, -1.05) | colore: rosso ordine: 3.0 asse_rotazione: Y Blender = -Z Godot |
| `TURBINA_3` | MeshInstance3D | (3.50, 1.20, -1.05) | colore: blu ordine: 1.0 asse_rotazione: Y Blender = -Z Godot |
| `VAPORE_collettore` | Node3D | (-3.20, 4.35, -4.70) |  |
| `VAPORE_perdita_ovest` | Node3D | (-8.50, 3.90, -3.00) |  |
| `VAPORE_pompa_1` | Node3D | (-4.85, 2.62, -2.15) |  |
| `VAPORE_pompa_2` | Node3D | (-0.35, 2.62, -2.15) |  |
| `VAPORE_pompa_3` | Node3D | (4.15, 2.62, -2.15) |  |
Collisioni: 61 corpi statici.

## Camera delle onde (`camera_onde.glb`)

Tunnel lungo X, da x = -2 a 24, largo 4,4 m (z da -2,2 a 2,2), alto 4,2. Pavimento a y = 0. Origine sotto il portello.
Negli extras, "Z" e "Y" sono gli assi di Blender: qui sotto sono già tradotti per Godot.

- **Arrivo dalla piscina**: il portello `PORTELLO` sta in cima al pozzo (y = 6,8, sopra il soffitto: è il fondo della piscina). Cerniera lungo l'asse Z di Godot; nel GLB è **aperto** (ruotato di -110°), chiuso = 0. Scala alla marinara da y = 0 a 6,8 sul lato ovest del pozzo; `PUNTO_arrivo_scala` è dove si scende. In cima al pozzo, nel livello, va attaccato il fondo della piscina a onde (portello e conca: vedi `sala_piscina.glb` del kit della sala).
- **Pale delle onde** `PALA_1..3` (lato nord, -Z): perno sulla cerniera in basso, oscillano attorno a **X** tra -12° e +12°. Stanno in nicchie allagate (`ACQUA_nicchia_1..3`, pelo a y = -0,35, fondo a -1,6). L'albero a gomiti `ALBERO_pale` gira attorno a X; le bielle `BIELLA_1..3` hanno l'origine sul perno dell'albero (da muovere via script, oppure lasciarle ferme).
- **Bocchette dell'aria** sul lato sud: `ARIA_bocchetta_1..3` (soffi d'aria a intervalli, rivolti verso il centro del tunnel) e `ARIA_nicchia_1..3` sull'acqua delle nicchie.
- **Paratie** `PARATIA_1` (x = 17,5) e `PARATIA_2` (x = 21): origine sul bordo inferiore, **scendono lungo Y** fino a y = 0 quando ripartono le pompe. Nel GLB sono alzate (bordo a 2,65 e 2,2 m: si passa sotto).
- **Verso la sala pompe**: il tunnel finisce aperto in x = 24 (`PUNTO_verso_sala_pompe`); si collega al tunnel ovest della sala pompe (`PUNTO_tunnel_camera_onde`, largo 2,6 m: nel livello serve un raccordo o si allarga quello della sala).

### Nodi utili

| Nodo | Tipo | Posizione Godot | Note |
|---|---|---|---|
| `ACQUA_nicchia_1` | MeshInstance3D | (6.00, -0.35, -3.65) |  |
| `ACQUA_nicchia_2` | MeshInstance3D | (10.00, -0.35, -3.65) |  |
| `ACQUA_nicchia_3` | MeshInstance3D | (14.00, -0.35, -3.65) |  |
| `ALBERO_pale` | MeshInstance3D | (10.00, 3.45, -2.95) | asse_rotazione: X |
| `ARIA_bocchetta_1` | Node3D | (6.00, 2.20, 1.68) |  |
| `ARIA_bocchetta_2` | Node3D | (10.00, 2.20, 1.68) |  |
| `ARIA_bocchetta_3` | Node3D | (14.00, 2.20, 1.68) |  |
| `ARIA_nicchia_1` | Node3D | (6.00, -0.05, -4.80) |  |
| `ARIA_nicchia_2` | Node3D | (10.00, -0.05, -4.80) |  |
| `ARIA_nicchia_3` | Node3D | (14.00, -0.05, -4.80) |  |
| `BIELLA_1` | MeshInstance3D | (6.00, 3.45, -3.40) |  |
| `BIELLA_2` | MeshInstance3D | (10.00, 3.84, -2.72) |  |
| `BIELLA_3` | MeshInstance3D | (14.00, 3.06, -2.72) |  |
| `LUCE_nicchia_1` | OmniLight3D | (7.00, 3.60, -4.60) | colore (1.00, 0.35, 0.25) |
| `LUCE_nicchia_2` | OmniLight3D | (11.00, 3.60, -4.60) | colore (1.00, 0.35, 0.25) |
| `LUCE_nicchia_3` | OmniLight3D | (15.00, 3.60, -4.60) | colore (1.00, 0.35, 0.25) |
| `LUCE_paratia_1` | OmniLight3D | (17.00, 3.80, -1.90) | colore (1.00, 0.35, 0.22) |
| `LUCE_paratia_2` | OmniLight3D | (20.50, 3.80, -1.90) | colore (1.00, 0.35, 0.22) |
| `LUCE_portello` | SpotLight3D | (0.00, 8.30, 0.00) | colore (0.77, 0.85, 0.95) |
| `LUCE_rossa_l1` | OmniLight3D | (3.00, 3.00, 1.93) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l3` | OmniLight3D | (12.00, 3.00, 1.93) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l4` | OmniLight3D | (16.00, 3.00, -1.93) | colore (1.00, 0.31, 0.22) |
| `LUCE_rossa_l5` | OmniLight3D | (23.00, 3.00, 1.93) | colore (1.00, 0.31, 0.22) |
| `PALA_1` | MeshInstance3D | (6.00, -1.30, -3.70) | asse_rotazione: X; oscilla tra -12 e +12 gradi |
| `PALA_2` | MeshInstance3D | (10.00, -1.30, -3.70) | asse_rotazione: X; oscilla tra -12 e +12 gradi |
| `PALA_3` | MeshInstance3D | (14.00, -1.30, -3.70) | asse_rotazione: X; oscilla tra -12 e +12 gradi |
| `PARATIA_1` | MeshInstance3D | (17.50, 2.65, 0.00) | movimento: scende lungo Z da 2.65 a 0 |
| `PARATIA_2` | MeshInstance3D | (21.00, 2.20, 0.00) | movimento: scende lungo Z da 2.2 a 0 |
| `PORTALE_1` | MeshInstance3D | (0.00, 0.00, 0.00) |  |
| `PORTALE_2` | MeshInstance3D | (0.00, 0.00, 0.00) |  |
| `PORTELLO` | MeshInstance3D | (0.58, 6.92, 0.00) | cardine: asse Y Blender (-Z Godot); chiuso = 0, aperto = -110 gradi |
| `PUNTO_arrivo_scala` | Node3D | (0.60, 0.00, 0.00) |  |
| `PUNTO_portello` | Node3D | (0.00, 6.80, 0.00) |  |
| `PUNTO_verso_sala_pompe` | Node3D | (24.00, 0.00, 0.00) |  |
| `VAPORE_tunnel` | Node3D | (11.00, 0.50, -0.40) |  |
Collisioni: 103 corpi statici.

