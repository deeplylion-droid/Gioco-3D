# Sala principale: come montarla in Godot

La sala principale dell'acquapark (capitolo 1) è pronta come **GLB a pezzi**, tutti con la stessa
origine: in Godot si istanziano tutti in **(0, 0, 0)**, scala 1, e combaciano. Misure in metri.
Le coordinate qui sotto sono già **in Godot** (Y in alto). Da Blender: `(x, y, z) -> (x, z, -y)`.
Tutti i numeri vengono da `glb/sala/sala_dati.json`, scritto dallo stesso script che fa i GLB; questo
file lo rigenera `tools/blender/ambiente_integrazione.py`.

## Novità (15 ottobre)

- **La sala è più lunga di 8 m verso sud**: il muro sud ora è a **z = 20** (prima 12). Tutto il resto
  (piscina, pozza, portello, turbina, cancello, vasche, torre, area bimbi) è **rimasto dov'era**:
  cambiano solo l'ingresso, lo spawn e la statua.
- **Vano verso gli spogliatoi** nel muro sud: luce **1,2 x 2,2 m**, x da -0.6 a 0.6,
  faccia verso la sala a z = 20, retro a z = 20.2 (muro spesso 0,2 m). Il vano è
  libero sia nella mesh sia nelle collisioni (verificato con raggi in Godot); davanti c'è una porta
  stagna aperta verso la sala, con la sua collisione. Prima il vano non c'era: il muro era pieno.
- **Spogliatoi** (`assets_src/ambienti_interni`): il marker_uscita_sala_principale degli spogliatoi (9,7; 0; -20,7) va sul retro del muro, in (0; 0; 20,2): traslare i tre glTF di (-9,7; 0; 40,9).
  Così il loro muro (con la saracinesca) sta subito dietro il nostro, senza sovrapporsi.
- **Monumento della statua** (`sala_monumento.glb`): entrando dal vano la medusa si vede subito, intera
  e centrata, a 10 m, con la cupola e la tempesta sopra la testa (provato in Godot con la medusa del
  gioco portata a 4,5 m).
- **Tubo dell'inseguimento**: è lo scivolo rosso a spirale (`sala_scivolo_spirale`), ora Ø interno
  **1,6 m** (parete 6 cm), come i moduli di `assets_src/ambienti_tecnici/glb/scivoli_kit.glb`. Parte dal
  piano in cima alla torre (y 8,6), esce dalla faccia ovest, gira intorno al pennone, attraversa la sala
  sopra la piscina e sputa nella vasca d'arrivo da est (bocca 16 cm sopra l'acqua). Gli altri due tubi
  restano da 1,0 m (decorativi).
- **Passata di qualità**: pavimento a piastrelle asciutte/umide/bagnate e pozzanghere a specchio, sporco
  nei colori dei vertici, battiscopa a sguscio e listelli, rivetti su travi e galleria, piastrelle
  mancanti, oblò con vetro scuro, cupola con costoloni a T e lastre sporche/incrinate/rotte, plafoniere
  calde (`luce_calda_*`) e insegne al neon (`luce_insegna_*`). Dettagli in `KIT.md`.

## File (cartella `assets_src/ambiente/glb/sala/`)

| File | Cosa contiene | Triangoli | Collisioni | Peso |
|---|---|---|---|---|
| `sala_architettura.glb` | pavimento (piastrelle asciutte, umide e bagnate; pozzanghere a specchio), pareti con oblò e il **vano verso gli spogliatoi** con la porta stagna aperta, galleria con colonne e ringhiere, scala della galleria est, soffitto con travi, cartelloni (solo disegni), plafoniere al neon, luci d'emergenza, insegna a pesce, altoparlanti | 246 mila | 275 | 42.7 MB |
| `sala_monumento.glb` | **monumento della statua (vuoto)**: piedistallo a gradoni con fregio a mosaico marino, conchiglie d'ottone, scatola del pulsante, 4 faretti dal basso; cordone di velluto su colonnine; lampione; 2 fari sulla ringhiera della galleria; offerte dei bambini (disegni, conchiglie, stelle marine, secchiello) | 18 mila | 14 | 20.7 MB |
| `sala_cupola.glb` | cupola: tamburo, costoloni, anelli, lastre di vetro (alcune rotte: lì sotto piove dentro) | 35 mila | - | 9.6 MB |
| `sala_piscina.glb` | piscina a onde vuota: fondo con pendenza e conca dello scarico, linea dell'ultimo livello dell'acqua, bordi a sfioro con griglie, bocchette della camera delle onde, rosa dei venti a mosaico, 2 scalette | 31 mila | 71 | 19.2 MB |
| `sala_area_bimbi.glb` | struttura di gioco, **secchio gigante** e **ruota a pale** (nodi a parte, con il perno giusto), vasche basse a scacchi | 6 mila | 30 | 16.8 MB |
| `sala_torre_scivoli.glb` | torre degli scivoli (piani a grigliato, scale a rampe, pozzo centrale aperto), 3 tubi colorati con sostegni e pennone della spirale, vasca d'arrivo | 92 mila | 147 | 29.2 MB |
| `sala_oggetti.glb` | oggetti di scena Meshy (istanze condivise), comprese le offerte alla base del monumento (salvagente, orsetto, paperelle, pallone, ciambella) | 747 mila | 79 | 25.0 MB |
| `sala_interattivi.glb` | elementi degli enigmi come nodi separati con il perno giusto (vedi sotto) | 6 mila | 11 | 10.4 MB |
| `sala_acqua.glb` | **segnaposto** piatti dell'acqua (da sostituire con l'acqua vera) | 8 | - | 0.0 MB |
| `sala_luci.glb` | 70 luci già al loro posto (Omni, Spot, una Directional) | - | - | |
| `sala_dati.json` | posizioni di luci, acqua, piedistallo, vano, spawn, camere | | | |

Texture: 2K JPG incorporate (colore, normal OpenGL, ORM = occlusione/rugosità/metallo). PNG solo dove
serve l'alfa (grigliati, rosa dei venti). Gli oggetti piccoli hanno texture 1K, i grandi 2K.
**Nuovo GLB da aggiungere alla scena: `sala_monumento.glb`** (con lo stesso import script degli altri).

## Import (una volta sola)

1. Copia la cartella `glb/sala/` nel progetto (per esempio `res://assets/ambiente/sala/`) e
   `assets_src/ambiente/godot/ambiente_post_import.gd` accanto.
2. Per ogni GLB: Import > **Import Script** = `ambiente_post_import.gd` > Reimport. Lo script:
   - accende `vertex_color_use_as_albedo` sui materiali `M_amb_*` (sporco, umidità e chiazze bagnate
     sono nei colori dei vertici, calcolati in spazio mondo: niente ripetizioni);
   - mette **alpha scissor** e doppia faccia ai grigliati e alla rosa dei venti;
   - vetri in trasparenza alpha; pozzanghere a rugosità 0,02; emissione più forte per neon e luci.
3. Le collisioni si creano da sole (nodi `-colonly`/`-convcolonly` diventano StaticBody3D +
   CollisionShape3D). I LOD li genera l'importer (`meshes/generate_lods`, attivo di serie).
   Le collisioni hanno i vertici già in coordinate della sala: lo script controlla prima dell'export
   che ognuna tocchi la geometria visibile, e lo stesso controllo è rifatto in Godot (0 fuori posto).
   **La toppa delle collisioni (`collision_fix.gd`, `BROKEN_COLLISIONS`) non serve più.**
4. Se usate LightmapGI: Import > Meshes > Light Baking = **Static Lightmaps** (genera la UV2).

## Montaggio

- Un `Node3D` "SalaPrincipale" con dentro le istanze dei GLB, tutte in (0, 0, 0).
- Le luci di `sala_luci.glb` le regola `LookSala` (addon grafica) con i valori consigliati più sotto.
  `assets_src/ambiente/godot/sala_luci_ambiente.gd` serve solo per le prove dell'ambiente.
- **Spawn del giocatore** (appena passato il vano): (0, 0, 19.2), guarda verso **-Z** (la statua).
- **Monumento (piedistallo vuoto, per la medusa)**: centro (0, 0, 10).
  - **Piano superiore a y = 1.15 m**, diametro del piano 2.78 m (con il toro del bordo
    2,84 m). La statua va appoggiata in **(0, 1.15, 10)**, rivolta verso **+Z** (la porta).
    Con 4,5 m di statua la cima arriva a y = 5.65 (la galleria è a 4,0-4,3; il soffitto a 11,5).
  - Gradoni: il primo Ø 4 m alto 0.28, il secondo Ø 3.24 m fino a 0.56;
    tamburo Ø 2.6 m con il fregio a mosaico (onde, pesci, stella marina, medusa).
  - **Pulsante dei bambini (sigla, scena S1)**: il fungo rosso è il nodo `sala_pulsante_piedistallo`
    in (0, 0.8, 11.43), sul davanti del tamburo, rivolto verso +Z; si preme verso -Z.
  - Cordone di velluto su colonnine a raggio 3 m, aperto sul davanti (varco di 3 m verso
    la porta); collisioni sulle campate.
  - Luci del monumento (in `sala_luci.glb`): `luce_faro_0/1` (fari sulla ringhiera della galleria sud,
    ombre accese), `luce_monumento_basso_0..3` (faretti nel primo gradino, dal basso), `luce_lampione`
    (lampione accanto, base (2.8, 0, 13.2), la lampada è sopra il davanti della statua).
  - Offerte dei bambini alla base (disegni a pastello senza scritte, conchiglie, stelle marine,
    secchiello; salvagente, orsetto, paperelle, pallone e ciambella in `sala_oggetti.glb`).
- **Secchio gigante**: nodo `sala_secchio_gigante`, perno sui suoi perni; si ribalta ruotando intorno all'asse **X**.
- **Ruota a pale**: nodo `sala_ruota_pale`, perno sull'asse, gira intorno all'asse **X**.
- La galleria si sale dalla scala sul lato est; la torre dalle rampe sul lato sud.

## Elementi interattivi (`sala_interattivi.glb`)

Ogni nodo ha l'origine sul suo perno (cerniera o asse): basta ruotarlo o spostarlo.
Non sono cambiati, tranne il pulsante del piedistallo (nuova posizione).

| Nodo | Perno in Godot |
|---|---|
| `sala_portello_scarico` | (0, -2.25, 1.36) |
| `sala_pulsante_portello` | (1.9, -1.15, 4.99) |
| `sala_turbina_scarico` | (4.6, -0.62, 4.84) |
| `sala_turbina_carter` | (0, 0, -0) |
| `sala_recinto_spiaggia` | (0, 0, -0) |
| `sala_cancello_spiaggia` | (-1, 0, -13.6) |
| `sala_ruota_cancello` | (-9.2, 1.45, -13.8) |
| `sala_trasmissione_cancello` | (0, 0, -0) |
| `sala_quadro_elettrico` | (-9, 1.1, -21.15) |
| `sala_pulsante_piedistallo` | (0, 0.8, 11.43) |

## Acqua (da fare con l'acqua vera; in `sala_acqua.glb` ci sono i segnaposto)

| Segnaposto | Cosa | Livello (y Godot) | Dove |
|---|---|---|---|
| `sala_pozza` | pozza torbida sul fondo della piscina a onde (sopra il portello dello scarico) | -2.07 | intorno a (0, -2.07, 2) |
| `sala_vasca_arrivo_acqua` | vasca d'arrivo degli scivoli (piena) | -0.22 | x da -16 a -9, z da -3 a 7 |
| `sala_vasca_bimbi_1_acqua` | vasca bassa a scacchi (area bimbi, scena "lei sbuca dal bordo") | 0.3 | x da -14.8 a -10.4, z da -11.2 a -8 |
| `sala_vasca_bimbi_2_acqua` | vasca bassa piccola con la balena sgonfia | 0.22 | x da -16.7 a -13.9, z da -13.8 a -11 |

La piscina a onde resta **vuota**: sul fondo si vede la linea scura dell'ultimo livello dell'acqua e la
conca dello scarico più sporca. Sul pavimento della sala le piastrelle più bagnate sono lucide e ci
sono pozzanghere a specchio (con SSR riflettono le luci rosse).

## Luci (in `sala_luci.glb`)

Le posizioni e le direzioni sono giuste; le intensità **nel gioco le decide `LookSala` dell'addon
grafica** (con `LookSalaLunga` dell'integratore): glTF e Godot usano unità diverse. Valori consigliati
(`light_energy`, raggio): emergenza rosse 3 (raggio 8); neon 2,5 (spot, raggio 7, angolo 70); fari del
monumento `luce_faro_*` **9,5** (spot, angolo 15, raggio 16, ombre), faretti `luce_monumento_basso_*`
**0,6** (spot, angolo 24, raggio 7); lampione 10 (spot 55 gradi, ombre); plafoniere calde `luce_calda_*`
1,8 (raggio 7,5, colore 1,0/0,68/0,38); insegne `luce_insegna_*` 1,3 (raggio 5,5); subacquee 3 (raggio 5);
luna 0,35 con ombre. `godot/sala_luci_ambiente.gd` serve solo per le prove dell'ambiente e usa gli
stessi valori. In tutto 30 neon accesi, 21 luci d'emergenza, lampione, 2 fari e 4 faretti del monumento,
5 plafoniere calde, 3 insegne, 2 subacquee, area bimbi, luna.

| Nome | Tipo | Posizione Godot | Colore | Note |
|---|---|---|---|---|
| `luce_neon_00` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, 16) | (0.8, 1, 0.93) | piena |
| `luce_neon_01` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 16) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_02` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 12) | (0.8, 1, 0.93) | piena |
| `luce_neon_03` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, 8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_04` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_05` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, 4) | (0.8, 1, 0.93) | piena |
| `luce_neon_06` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, 4) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_07` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -0) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_08` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -4) | (0.8, 1, 0.93) | piena |
| `luce_neon_09` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -4) | (0.8, 1, 0.93) | piena |
| `luce_neon_10` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -8) | (0.8, 1, 0.93) | piena |
| `luce_neon_11` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -12) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_12` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -12) | (0.8, 1, 0.93) | piena |
| `luce_neon_13` | neon (OmniLight3D o SpotLight3D verso il basso) | (18.5, 3.88, -20) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_14` | neon (OmniLight3D o SpotLight3D verso il basso) | (-18.5, 3.88, -20) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_15` | neon (OmniLight3D o SpotLight3D verso il basso) | (-16, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_16` | neon (OmniLight3D o SpotLight3D verso il basso) | (-16, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_17` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, 18.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_18` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_19` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_20` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_21` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_22` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_23` | neon (OmniLight3D o SpotLight3D verso il basso) | (4, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_24` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, 18.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_25` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, -22.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_26` | neon (OmniLight3D o SpotLight3D verso il basso) | (12, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_27` | neon (OmniLight3D o SpotLight3D verso il basso) | (12, 3.88, -22.5) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_28` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, 18.5) | (0.8, 1, 0.93) | piena |
| `luce_neon_29` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, -22.5) | (0.8, 1, 0.93) | piena |
| `luce_emergenza_30` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, 6) | (1, 0.035, 0.02) |  |
| `luce_emergenza_31` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, -6) | (1, 0.035, 0.02) |  |
| `luce_emergenza_32` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, -18) | (1, 0.035, 0.02) |  |
| `luce_emergenza_33` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, 4) | (1, 0.035, 0.02) |  |
| `luce_emergenza_34` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, -8) | (1, 0.035, 0.02) |  |
| `luce_emergenza_35` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, -20) | (1, 0.035, 0.02) |  |
| `luce_emergenza_36` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-6, 2.9, -23.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_37` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (8, 2.9, -23.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_38` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-5, 2.9, 19.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_39` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (5, 2.9, 19.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_40` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 8.6, -0) | (1, 0.035, 0.02) |  |
| `luce_emergenza_41` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 8.6, -12) | (1, 0.035, 0.02) |  |
| `luce_emergenza_42` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-12, 8.6, -23.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_43` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (12, 8.6, 19.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_44` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (2, 8.6, -23.88) | (1, 0.035, 0.02) |  |
| `luce_emergenza_45` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 8.6, -14) | (1, 0.035, 0.02) |  |
| `luce_emergenza_46` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 8.6, 6) | (1, 0.035, 0.02) |  |
| `luce_emergenza_47` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, 14) | (1, 0.035, 0.02) |  |
| `luce_emergenza_48` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-19.88, 2.9, 16) | (1, 0.035, 0.02) |  |
| `luce_emergenza_49` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 8.6, 12) | (1, 0.035, 0.02) |  |
| `luce_emergenza_50` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (-14, 8.6, 19.88) | (1, 0.035, 0.02) |  |
| `luce_lampione` | SpotLight3D verso il basso, angolo 60 gradi, calda, ronza | (1.65, 4.42, 13.2) | (1, 0.72, 0.42) |  |
| `luce_insegna_onda` | OmniLight3D davanti all'insegna al neon | (0, 2.95, 19.5) | (0.25, 0.85, 1) |  |
| `luce_insegna_stella` | OmniLight3D davanti all'insegna al neon | (-12.5, 7, -23.4) | (1, 0.72, 0.25) |  |
| `luce_calda_0` | OmniLight3D calda (plafoniera navale accesa) | (1.75, 2.5, 19.75) | (1, 0.68, 0.38) |  |
| `luce_calda_1` | OmniLight3D calda (plafoniera navale accesa) | (19.75, 2.7, -9) | (1, 0.68, 0.38) |  |
| `luce_calda_2` | OmniLight3D calda (plafoniera navale accesa) | (-19.75, 2.7, 1) | (1, 0.68, 0.38) |  |
| `luce_calda_3` | OmniLight3D calda (plafoniera navale accesa) | (10.5, 2.6, -14.13) | (1, 0.68, 0.38) |  |
| `luce_calda_4` | OmniLight3D calda (plafoniera navale accesa) | (-3, 3, -20.9) | (1, 0.68, 0.38) |  |
| `luce_monumento_basso_0` | SpotLight3D: faretto nel gradino, illumina la statua dal basso | (1.252, 0.451, 8.748) | (1, 0.82, 0.58) | punta verso (-0.306, 0.901, 0.306) |
| `luce_monumento_basso_1` | SpotLight3D: faretto nel gradino, illumina la statua dal basso | (-1.252, 0.451, 8.748) | (1, 0.82, 0.58) | punta verso (0.306, 0.901, 0.306) |
| `luce_monumento_basso_2` | SpotLight3D: faretto nel gradino, illumina la statua dal basso | (-1.252, 0.451, 11.252) | (1, 0.82, 0.58) | punta verso (0.306, 0.901, -0.306) |
| `luce_monumento_basso_3` | SpotLight3D: faretto nel gradino, illumina la statua dal basso | (1.252, 0.451, 11.252) | (1, 0.82, 0.58) | punta verso (-0.306, 0.901, -0.306) |
| `luce_faro_0` | SpotLight3D: faro sulla ringhiera della galleria, punta la statua | (-2.014, 5.547, 16.616) | (1, 0.9, 0.76) | punta verso (0.288, -0.143, -0.947) |
| `luce_faro_1` | SpotLight3D: faro sulla ringhiera della galleria, punta la statua | (2.014, 5.547, 16.616) | (1, 0.9, 0.76) | punta verso (-0.288, -0.143, -0.947) |
| `luce_subacquea_0` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, 6.85) | (0.25, 0.95, 0.75) |  |
| `luce_subacquea_1` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, -2.85) | (0.25, 0.95, 0.75) |  |
| `luce_insegna_rosa` | OmniLight3D davanti all insegna a pesce | (-3, 7.4, -23.5) | (1, 0.22, 0.6) |  |
| `luce_area_bimbi` | OmniLight3D gialla sulla struttura | (-12.8, 3.6, -17.6) | (1, 0.8, 0.5) |  |
| `luce_luna` | DirectionalLight3D blu dalla cupola (ombre dei costoloni) | direzione (0.25, -1, 0.18) | (0.55, 0.66, 1) |  |

## Ambiente consigliato (WorldEnvironment)

- Nebbia volumetrica: densità ~0,02, più fitta in basso, albedo grigio-azzurro.
- SSR acceso (pavimento bagnato e pozzanghere), SSAO, SSIL, glow per neon e luci rosse; SDFGI va bene.
- Cielo: notte di tempesta (scuro, nuvole) con qualche lampo: si vede dalla cupola.
- Tonemap AgX o Filmic: la sala deve restare buia con le pozze di luce.

## Cosa manca

Kit di dettagli della sessione ambienti-2 (detriti, cavi, tubi a muro, bocchette, corpi lampada):
quando arriva in main lo si posiziona con il suo JSON. L'interno del tubo dell'inseguimento per il
gioco è nel kit degli scivoli di ambienti_tecnici (qui il tubo ha solo le collisioni esterne).
