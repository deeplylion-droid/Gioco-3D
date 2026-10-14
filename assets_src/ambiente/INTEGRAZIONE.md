# Sala principale: come montarla in Godot

La sala principale dell'acquapark (capitolo 1) è pronta come **GLB a pezzi**, tutti con la stessa
origine: in Godot si istanziano tutti in **(0, 0, 0)**, scala 1, e combaciano. Misure in metri.
Le coordinate qui sotto sono già **in Godot** (Y in alto). Da Blender: `(x, y, z) -> (x, z, -y)`.
Tutti i numeri vengono da `glb/sala/sala_dati.json`, scritto dallo stesso script che fa i GLB.

## File (cartella `assets_src/ambiente/glb/sala/`)

| File | Cosa contiene | Triangoli | Collisioni |
|---|---|---|---|
| `sala_architettura.glb` | pavimento (con pozzanghere lucide), pareti con oblò e porta degli spogliatoi, galleria con colonne e ringhiere, soffitto, piedistallo **vuoto**, lampione, cartelloni (solo disegni), plafoniere al neon, luci d'emergenza, insegna a pesce | 108 mila | 243 (pavimento trimesh, il resto convesse) |
| `sala_cupola.glb` | cupola: tamburo, costoloni, anelli, lastre di vetro (5 rotte) | 25 mila | nessuna (non si raggiunge) |
| `sala_piscina.glb` | piscina a onde vuota: fondo con pendenza e conca dello scarico, bordi a sfioro con griglie, bocchette della camera delle onde, portello, rosa dei venti a mosaico, 2 scalette | 30 mila | 71 (vasca trimesh) |
| `sala_area_bimbi.glb` | struttura di gioco, **secchio gigante** e **ruota a pale** (nodi a parte, con il perno giusto), vasche basse a scacchi | 6 mila | 30 (pedane, scala, ponte: si sale) |
| `sala_torre_scivoli.glb` | torre degli scivoli (piani a grigliato, scale a rampe, pozzo centrale aperto), 3 tubi colorati con sostegni e pennone della spirale, vasca d'arrivo | 79 mila | 145 (rampe, piani, tratti dei tubi) |
| `sala_oggetti.glb` | 39 oggetti di scena Meshy (12 modelli, istanze condivise) | 393 mila | 39 (una scatola ciascuno) |
| `sala_interattivi.glb` | elementi degli enigmi come nodi separati con il perno giusto (vedi sotto) | 7 mila | 11 |
| `sala_acqua.glb` | **segnaposto** piatti dell'acqua (da sostituire con l'acqua vera) | - | - |
| `sala_luci.glb` | 49 luci puntiformi già al loro posto (Omni, Spot, una Directional) | - | - |
| `sala_dati.json` | posizioni di luci, acqua, piedistallo, spawn, camere | | |

Texture: 2K JPG incorporate (colore, normal OpenGL, ORM = occlusione/rugosità/metallo). PNG solo dove
serve l'alfa (grigliati, rosa dei venti). Gli oggetti piccoli hanno texture 1K, i grandi 2K.

## Import (una volta sola)

1. Copia la cartella `glb/sala/` nel progetto (per esempio `res://assets/ambiente/sala/`) e
   `assets_src/ambiente/godot/ambiente_post_import.gd` accanto.
2. Per ogni GLB: Import > **Import Script** = `ambiente_post_import.gd` > Reimport. Lo script:
   - accende `vertex_color_use_as_albedo` sui materiali `M_amb_*` (lo sporco e l'umidità in basso
     sono nei colori dei vertici; l'importer 4.7.2 lo lascia spento su alcune superfici);
   - mette **alpha scissor** e doppia faccia ai grigliati e alla rosa dei venti;
   - vetri in trasparenza alpha; pozzanghere a rugosità 0,02; emissione più forte per neon e luci.
   Verificato su Godot 4.7.2 (import, nodi, collisioni, materiali).
3. Le collisioni si creano da sole (nodi `-colonly`/`-convcolonly` diventano StaticBody3D +
   CollisionShape3D). I LOD li genera l'importer (`meshes/generate_lods`, attivo di serie).
   Le collisioni dei pezzi uniti hanno i vertici già in coordinate della sala (nodo in identità):
   lo script controlla prima dell'export che ognuna tocchi la geometria visibile, e lo stesso
   controllo è stato rifatto in Godot (0 collisioni fuori posto su 578).
4. Se usate LightmapGI: Import > Meshes > Light Baking = **Static Lightmaps** (genera la UV2).

## Montaggio

- Un `Node3D` "SalaPrincipale" con dentro le istanze dei GLB, tutte in (0, 0, 0).
- Attacca a "SalaPrincipale" lo script `assets_src/ambiente/godot/sala_luci_ambiente.gd`: regola le
  luci di `sala_luci.glb` (intensità, raggi, ombre solo su luna e lampione), fa sfarfallare alcuni neon
  e, se nella scena non c'è, crea un WorldEnvironment notturno (nebbia volumetrica, SSR, SSAO, glow).
  Provato in Godot 4.7.2: vedi `docs/proposte/ambiente/sala/sala_godot_*.jpg`.
- **Spawn del giocatore** (uscita dagli spogliatoi): (0, 0, 11.2), guarda verso **-Z** (il piedistallo).
- **Piedistallo (vuoto, per la medusa)**: centro della base (0, 0, 6.9); piano superiore a **y = 0.9 m**,
  diametro del piano **2.2 m** (tamburo 2.0 m, zoccolo 2.3 m).
  La statua va appoggiata in (0, 0.9, 6.9). Il pulsante dei bambini è sul davanti, verso lo spawn.
- **Secchio gigante**: nodo `sala_secchio_gigante`, perno sui suoi perni; si ribalta ruotando intorno all'asse **X**.
- **Ruota a pale**: nodo `sala_ruota_pale`, perno sull'asse, gira intorno all'asse **X**.
- La galleria non ha ancora scale per salirci (si vede, non si usa); la torre si sale dalle rampe sul lato sud.

## Elementi interattivi (`sala_interattivi.glb`)

Ogni nodo ha l'origine sul suo perno (cerniera o asse): basta ruotarlo o spostarlo.
Anche `sala_secchio_gigante` e `sala_ruota_pale` (in `sala_area_bimbi.glb`) sono nodi separati.

| Nodo | Perno in Godot | Cosa fa |
|---|---|---|
| `sala_portello_scarico` | (0, -2.25, 1.36) | portello sul fondo, sotto la pozza: cerniera sul lato nord, si apre ruotando sull'asse X |
| `sala_pulsante_portello` | (1.9, -1.15, 4.99) | pulsante sulla parete sud della vasca: apre il portello |
| `sala_turbina_scarico` | (4.6, -0.62, 4.84) | turbina dello scarico in alto sulla parete sud della vasca, gira sull'asse Z di Godot (Y di Blender); ci va incastrato un gonfiabile |
| `sala_turbina_carter` | (0, 0, -0) | carter fisso della turbina (non si muove) |
| `sala_recinto_spiaggia` | (0, 0, -0) | recinzione bassa sulla spiaggia della piscina (fissa) |
| `sala_cancello_spiaggia` | (-1, 0, -13.6) | cancello della piscina a onde: cerniera a sinistra (x = -1), ruota sull'asse Y di Godot |
| `sala_ruota_cancello` | (-9.2, 1.45, -13.8) | grande ruota che apre il cancello (la fa girare l'ondata del secchio), asse X |
| `sala_trasmissione_cancello` | (0, 0, -0) | albero di trasmissione ruota -> cancello (fisso) |
| `sala_quadro_elettrico` | (-9, 1.1, -21.15) | quadro elettrico vicino alla struttura di gioco: l'acqua del secchio lo bagna (scintille, sigla) |
| `sala_pulsante_piedistallo` | (0, 0.47, 8.02) | pulsante dei bambini sul piedistallo: fa partire la sigla |

## Acqua (da fare con l'acqua vera; in `sala_acqua.glb` ci sono i segnaposto)

| Dove | Segnaposto | Livello (y Godot) | Fondo | Note |
|---|---|---|---|---|
| Pozza torbida della piscina a onde | `sala_pozza` | -2,07 | -2,0 / -2,24 al centro | il fondo è a conca intorno allo scarico (x 0, z 2): l'acqua visibile è un cerchio di raggio 3-3,5 m. Sotto c'è il portello. Svuotandola si vede la conca |
| Vasca d'arrivo degli scivoli | `sala_vasca_arrivo_acqua` | -0,22 | -1,10 | x da -16 a -9, z da -3 a 7. Qui finiscono i 3 scivoli |
| Vasca bassa a scacchi (lei sbuca dal bordo) | `sala_vasca_bimbi_1_acqua` | 0,30 | 0,02 | x da -14,8 a -10,4, z da -11,2 a -8,0; bordo alto 0,45: l'acqua può salire fino al bordo |
| Vasca bassa piccola (balena sgonfia) | `sala_vasca_bimbi_2_acqua` | 0,22 | 0,02 | x da -16,7 a -13,9, z da -13,8 a -11,0 |

La piscina a onde resta **vuota**: piastrelle asciutte sopra, bagnate nella conca (i colori dei vertici le scuriscono).

## Luci (in `sala_luci.glb`, da regolare)

Le posizioni sono giuste; le intensità no (glTF e Godot usano unità diverse). Valori di partenza:
emergenza rosse `light_energy` 2-3, `omni_range` 7, ombre spente tranne 2-3; neon 1,5-2,5 (alcuni
a metà o spenti: farli sfarfallare con uno script); lampione 6-8, ombre accese, ronzio; luna 0,3-0,5
blu con ombre (i costoloni della cupola disegnano le strisce sul pavimento); subacquee 3, insegna 2.

| Nome | Tipo | Posizione Godot | Colore | Note |
|---|---|---|---|---|
| `luce_neon_00` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, 8) | (0.8, 1, 0.93) | piena |
| `luce_neon_01` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_02` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 4) | (0.8, 1, 0.93) | piena |
| `luce_neon_03` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -0) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_04` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -0) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_05` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -4) | (0.8, 1, 0.93) | piena |
| `luce_neon_06` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -4) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_07` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_08` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -12) | (0.8, 1, 0.93) | piena |
| `luce_neon_09` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -12) | (0.8, 1, 0.93) | piena |
| `luce_neon_10` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -16) | (0.8, 1, 0.93) | piena |
| `luce_neon_11` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -20) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_12` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -20) | (0.8, 1, 0.93) | piena |
| `luce_neon_13` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, 10.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_14` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, -22.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_15` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, 10.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_16` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_17` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, 10.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_18` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_19` | neon (OmniLight3D o SpotLight3D verso il basso) | (4, 3.88, 10.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_20` | neon (OmniLight3D o SpotLight3D verso il basso) | (4, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_21` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, 10.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_22` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_23` | neon (OmniLight3D o SpotLight3D verso il basso) | (12, 3.88, 10.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_24` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, 10.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_25` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, -22.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_emergenza_26` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, 6) | (1, 0.04, 0.02) | |
| `luce_emergenza_27` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, -6) | (1, 0.04, 0.02) | |
| `luce_emergenza_28` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, -18) | (1, 0.04, 0.02) | |
| `luce_emergenza_29` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, 4) | (1, 0.04, 0.02) | |
| `luce_emergenza_30` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, -8) | (1, 0.04, 0.02) | |
| `luce_emergenza_31` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, -20) | (1, 0.04, 0.02) | |
| `luce_emergenza_32` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-6, 2.9, -23.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_33` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (8, 2.9, -23.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_34` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-5, 2.9, 11.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_35` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (5, 2.9, 11.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_36` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 8.6, -0) | (1, 0.04, 0.02) | |
| `luce_emergenza_37` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 8.6, -12) | (1, 0.04, 0.02) | |
| `luce_emergenza_38` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-12, 8.6, -23.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_39` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (12, 8.6, 11.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_40` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (2, 8.6, -23.88) | (1, 0.04, 0.02) | |
| `luce_emergenza_41` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 8.6, -14) | (1, 0.04, 0.02) | |
| `luce_emergenza_42` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 8.6, 6) | (1, 0.04, 0.02) | |
| `luce_lampione` | SpotLight3D verso il basso, angolo 60 gradi, calda, ronza | (0.75, 4.42, 7.9) | (1, 0.72, 0.42) | |
| `luce_subacquea_0` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, 6.85) | (0.25, 0.95, 0.75) | |
| `luce_subacquea_1` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, -2.85) | (0.25, 0.95, 0.75) | |
| `luce_insegna_rosa` | OmniLight3D davanti all insegna a pesce | (-3, 7.4, -23.5) | (1, 0.22, 0.6) | |
| `luce_area_bimbi` | OmniLight3D gialla sulla struttura | (-12.8, 3.6, -17.6) | (1, 0.8, 0.5) | |
| `luce_luna` | DirectionalLight3D blu dalla cupola (ombre dei costoloni) | direzione (0.25, -1, 0.18) | (0.55, 0.66, 1) | |

In tutto 26 neon accesi, 17 luci d'emergenza, lampione, 2 subacquee, insegna, area bimbi, luna.

## Ambiente consigliato (WorldEnvironment)

- Nebbia volumetrica: densità ~0,02, più fitta in basso (height falloff), albedo grigio-azzurro.
- SSR acceso (pavimento bagnato e pozzanghere), SSAO, glow per neon e luci rosse.
- Cielo: notte di tempesta (scuro, nuvole) con qualche lampo: si vede dalla cupola.
- Tonemap Filmic o AgX, esposizione bassa: la sala deve restare buia con le pozze di luce.

## Cosa manca (da fare nei prossimi passi)

Scale per la galleria, altre porte (stagne), spogliatoi e corridoi, tubo rotto (da confermare),
interno della camera delle onde e sala pompe, Polaroid e bambini. Il portello e il pulsante del
piedistallo sono dentro le mesh: se servono animati vanno separati (lo script lo fa in un attimo).
