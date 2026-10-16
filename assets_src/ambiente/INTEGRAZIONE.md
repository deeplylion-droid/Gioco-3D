# Sala principale: come montarla in Godot

La sala principale dell'acquapark (capitolo 1) è pronta come **GLB a pezzi**, tutti con la stessa
origine: in Godot si istanziano tutti in **(0, 0, 0)**, scala 1, e combaciano. Misure in metri.
Le coordinate qui sotto sono già **in Godot** (Y in alto). Da Blender: `(x, y, z) -> (x, z, -y)`.
Tutti i numeri vengono da `glb/sala/sala_dati.json`, scritto dallo stesso script che fa i GLB; questo
file lo rigenera `tools/blender/ambiente_integrazione.py`.

## Novità (16 ottobre): le scelte dell'utente sulle proposte

- **Niente soppalco** (C1): via galleria, colonne, ringhiere e scala. Le plafoniere al neon sono sulle pareti alla
  quota di prima (3,88 m, 32 cm dal muro, su due staffe), con gli stessi nomi delle luci; i due fari della medusa
  (`luce_faro_0/1`) sono su due bracci fissati alla parete sud, alla stessa quota; cartelloni e altoparlanti sulle
  pareti nord e sud; la plafoniera calda `luce_calda_4` è sulla parete nord in (-4.6, 3, -23.75).
- **Cordone chiuso** intorno alla vasca della medusa (D1): 20 colonnine, niente varco, e su ogni campata un muro
  invisibile alto 2,5 m (`cordone_vasca_0..19`).
- **Area bimbi, disposizione 1**: struttura di gioco nell'angolo nord-ovest (centro (-14.6, 0, -19.6)), con la
  scala verso chi arriva e lo scivolo che scende nella vasca piccola (VascaBimbi2, ora con il centro dell'acqua in
  x -9.6, z -18.2); i due funghi nella piazza. La VascaBimbi1 e la fossa della tappa 8 restano dove sono.
  Niente ruota a pale (il secchio è scenografia), niente cannoncini; tolti i giocattoli sparsi nell'area e sulla
  strada della scia rosa (gli altri oggetti hanno gli stessi nomi di prima).
- **Pulsante della botola, versione A**: cassetta gialla sulla parete sud della piscina con il fungo rosso Ø 50 cm
  (`sala_pulsante_portello`, stesso nome di prima: si preme lungo il suo -Z) e il lampeggiante
  (`sala_lampeggiante_portello`, vetro giallo). Dati in `sala_dati.json` → `pulsante_botola`.
- **Tappa 5 rifatta**: via la turbina dello scarico, il recinto con il cancello, la ruota del cancello con la
  trasmissione e il quadro elettrico.
- **Sala della torre, versione 2 (a est)**: varco nella parete est (z da -18 a -12, alto 5 m) chiuso dal portone
  scorrevole con la torre dipinta e le bande a strisce, **senza l'insegna sopra**. L'anta è `sala_portone_torre`
  (perno (19.84, 0, -15)): si apre scorrendo verso +Z fino a 2,0 m. Il lampeggiante rosso è
  `sala_lampeggiante_torre`. Dietro c'è solo il guscio della sala (x da 20.2 a 40, alto 14 m), vuoto.
  La torre e gli scivoli di prima **non sono più nella sala**: si rifanno nella sala nuova, con una proposta a parte.
  Le luci che cadevano nel varco non ci sono più (`luce_neon_11`, `luce_emergenza_32`); le altre tengono il nome.
- **Varco della serranda** del magazzino dei gonfiabili (tappa 7 B, lo ha aggiunto ambienti-1): nel muro sud,
  x da -15.9 a -14.1, alto 2.5 m, con le collisioni. La serranda e il magazzino sono nel raccordo
  dei tecnici. Davanti al varco non c'è niente: il soppalco e le sue colonne non ci sono più.
- Il kit di dettagli ha 179 posti in meno (sotto il soppalco, area bimbi, varco della torre, varco della serranda, due che tagliavano lo sfondo):
  vedi `assets_src/ambiente_dettagli/posizionamento_tolti_2026-10-16.json`.
- **Controllo degli oggetti** che entrano nello sfondo o galleggiano (riscontro C3: il gonfiabile incastrato nella
  scala): `tools/blender/controlla_oggetti_sala.py`, sui GLB del gioco e sul kit di dettagli. Gli oggetti a terra
  inclinati ora toccano il pavimento con il punto più basso, i salvagenti appesi toccano il muro, e i dettagli del
  fondo in pendenza della piscina seguono la pendenza. Restano solo le 4 lampade a muro del kit, con la piastra
  4 cm dentro il muro (non si vede).

## Novità (15 ottobre)

- **Fossa della VascaBimbi1** (tappa 8, "lei sbuca dal bordo"): sul lato sud della prima vasca a scacchi c'è
  lo scarico di compensazione rotto, cioè la parte profonda della vasca. Pianta Godot x da -14,8 a -12,3 e
  z da -8,0 a -6,0, con l'angolo sud-ovest tagliato a 45 gradi. Fondo a y -3,0 (3 m sotto il fondo della
  vasca); piastrelle fino a y -0,6, poi cemento grezzo. In fondo, nella parete est, c'è il condotto
  (Ø 1,2 m, centro y -2,3) che va verso est fino a x -8,8; la griglia divelta pende dal lato nord.
  - Il bordo a scacchi (alto 0,45, largo 0,3) gira intorno alla fossa. L'angolo tagliato regge la
    medusa affacciata, rivolta a sud-ovest verso chi arriva lungo il muro ovest.
  - Collisioni: pareti, fondo, bordo e un **coperchio** invisibile `coperchio_fossa_col` (nodo a parte in
    `sala_area_bimbi.glb`) a filo del fondo della vasca, da accendere o spegnere nel gioco. Il condotto è
    chiuso dalla collisione della parete est.
  - Marker in `sala_dati.json` → `fossa_bimbi`: `medusa_sbuca` (origine della posa 'affacciata': coping
    1,0 m sopra, spigolo esterno 2,1 m davanti), `medusa_fuga` (in fondo al condotto) e
    `livello_acqua_pieno` (y 0,42, 3 cm sotto il bordo). Il segnaposto dell'acqua è
    `sala_fossa_bimbi_acqua`; la sua quota e il fondo sono nella lista `acqua`.
- **Buco del pozzo sotto il portello** (tappa 5): nel fondo della piscina a onde c'è il buco verso il pozzo
  della camera delle onde, **x da -0,64 a 0,64 e z da 1,36 a 2,64** (Godot), aperto sia nella mesh sia nella
  collisione. Il bordo è smussato (3 cm a 45 gradi) e il collare è piastrellato come il fondo, fino a
  y -2,48. Il portello ora è quadrato (1,42 x 1,37 m): copre il buco e appoggia sulle piastrelle intorno.
  Stesso nodo, stessa cerniera, stessa collisione. Sotto va il pozzo di ambienti-1, centrato in
  (0; -2,25; 2,0); il "Buio" nero a y -2,256 della scena va tolto quando c'è il pozzo.
- **Passata HQ** (al livello del pezzo campione degli interni): oggetti di scena rifatti con Meshy HQ
  (stessi nomi, posizioni e misure; ora anche ruotati come previsto: prima l'importatore lasciava tutti
  gli oggetti dritti), lampione, colonnine del cordone e secchio gigante HQ, panche, cestini e cartelli
  nuovi lungo i muri, struttura di gioco smussata, pavimento con **un solo materiale** (niente più
  chiazze a quadretti) e pozzanghere 3 mm sopra il pavimento. Il lampione tiene la lampadina dove c'è
  `luce_lampione` (la luce non si sposta) e il secchio tiene nodo, perno e collisione.
  **I GLB del gioco vanno bene sia con la vasca sia con il monumento**: le offerte dei bambini sono nel
  GLB del centro; in `godot/assets/ambiente/sala/` per ora c'è ancora `sala_monumento.glb` (rifatto con
  gli stessi pezzi HQ) e i vecchi `sala_interattivi.glb`, `sala_luci.glb` e `sala_acqua.glb`, che
  dipendono dal centro: quelli della vasca si mettono quando si monta la vasca.
- **La sala è più lunga di 8 m verso sud**: il muro sud ora è a **z = 20** (prima 12). Tutto il resto
  (piscina, pozza, portello, turbina, cancello, vasche, torre, area bimbi) è **rimasto dov'era**:
  cambiano solo l'ingresso, lo spawn e la statua.
- **Vano verso gli spogliatoi** nel muro sud: luce **1,2 x 2,2 m**, x da -0.6 a 0.6,
  faccia verso la sala a z = 20, retro a z = 20.2 (muro spesso 0,2 m). Il vano è
  libero sia nella mesh sia nelle collisioni (verificato con raggi in Godot); davanti c'è una porta
  stagna aperta verso la sala, con la sua collisione. Prima il vano non c'era: il muro era pieno.
- **Spogliatoi** (`assets_src/ambienti_interni`): il marker_uscita_sala_principale degli spogliatoi (9,7; 0; -20,7) va sul retro del muro, in (0; 0; 20,2): traslare i tre glTF di (-9,7; 0; 40,9).
  Così il loro muro (con la saracinesca) sta subito dietro il nostro, senza sovrapporsi.
- **Al centro della sala ora c'è la VASCA SOLLEVATA** (`sala_vasca_centrale.glb`, decisione dell'utente del
  15 ottobre): dentro la medusa affacciata, immobile, con le mani sul bordo verso l'ingresso. Il monumento
  con la statua resta per più avanti: `glb/per_dopo/sala_monumento.glb` (si rifà con
  `ambiente_sala.py --monumento`). **Togliere `sala_monumento.glb` dalla scena e mettere `sala_vasca_centrale.glb`.**
- **Tubo dell'inseguimento**: è lo scivolo rosso a spirale (`sala_scivolo_spirale`), ora Ø interno
  **1,6 m** (parete 6 cm), come i moduli di `assets_src/ambienti_tecnici/glb/scivoli_kit.glb`. Parte dal
  piano in cima alla torre (y 8,6), esce dalla faccia ovest, gira intorno al pennone, attraversa la sala
  sopra la piscina e sputa nella vasca d'arrivo da est (bocca 16 cm sopra l'acqua). Gli altri due tubi
  restano da 1,0 m (decorativi).
- **Revisione di qualità**: metallo grigio-verde (colonne, sostegni, galleria), due teli con la mascotte
  ai lati del centro della sala (faretti `luce_cartellone_*`); tolti i due cartelloni del lato est.
- **Passata di qualità**: pavimento a piastrelle asciutte/umide/bagnate e pozzanghere a specchio, sporco
  nei colori dei vertici, battiscopa a sguscio e listelli, rivetti su travi e galleria, piastrelle
  mancanti, oblò con vetro scuro, cupola con costoloni a T e lastre sporche/incrinate/rotte, plafoniere
  calde (`luce_calda_*`) e insegne al neon (`luce_insegna_*`). Dettagli in `KIT.md`.

## File (cartella `assets_src/ambiente/glb/sala/`)

| File | Cosa contiene | Triangoli | Collisioni | Peso |
|---|---|---|---|---|
| `sala_architettura.glb` | pavimento (un solo materiale, umidità e sporco sfumati nei colori dei vertici; pozzanghere a specchio opache 3 mm sopra), pareti con oblò, il **vano verso gli spogliatoi** con la porta stagna aperta e il **varco della sala della torre** nella parete est, soffitto con travi, cartelloni (solo disegni), plafoniere al neon e altoparlanti sulle pareti, luci d'emergenza, insegna a pesce, il **guscio della sala della torre** (`sala_torre_guscio`) | 194 mila | 179 | 39.5 MB |
| `sala_vasca_centrale.glb` | **vasca sollevata al centro** (6 x 4,5 m, bordo a 1,0 m, acqua a 0,88): piastrelle a scacchi blu notte e crema, coping bagnato con il toro, alghe e calcare sulla linea dell'acqua, scatola del pulsante della sigla; cordone di velluto su colonnine d'ottone HQ; lampione HQ; 2 fari sulla parete sud; offerte dei bambini (anche quelle Meshy: salvagente, orsetto, paperelle, pallone, ciambella) | 145 mila | 36 | 24.3 MB |
| `sala_cupola.glb` | cupola: tamburo, costoloni, anelli, lastre di vetro (alcune rotte: lì sotto piove dentro) | 35 mila | - | 9.6 MB |
| `sala_piscina.glb` | piscina a onde vuota: fondo con pendenza e conca dello scarico, buco del pozzo sotto il portello (bordo smussato, collare piastrellato), linea dell'ultimo livello dell'acqua, bordi a sfioro con griglie, bocchette della camera delle onde, rosa dei venti a mosaico, 2 scalette | 31 mila | 71 | 19.2 MB |
| `sala_area_bimbi.glb` | struttura di gioco (pali tondi, bordi smussati) nell'angolo nord-ovest, **secchio gigante** HQ (nodo a parte, con il perno giusto), vasche basse a scacchi, **fossa della VascaBimbi1** (tappa 8) con il coperchio di collisione `coperchio_fossa_col` | 22 mila | 40 | 25.4 MB |
| `sala_torre_scivoli.glb` | solo la **vasca d'arrivo** (la torre e gli scivoli non sono più nella sala dal 16 ottobre; il nome del file resta per la scena) | 13 mila | 41 | 13.2 MB |
| `sala_oggetti.glb` | oggetti di scena Meshy HQ (istanze condivise): giocattoli e gonfiabili, lettini, sedia del bagnino, funghi-fontana, panche, cestini, cartelli. Uguale con la vasca e con il monumento: le offerte dei bambini stanno nel GLB del centro | 597 mila | 71 | 16.0 MB |
| `sala_interattivi.glb` | elementi degli enigmi come nodi separati con il perno giusto (vedi sotto): portello della botola, **pulsante A** con il lampeggiante, **portone della sala della torre**, pulsante della sigla | 5 mila | 3 | 6.0 MB |
| `sala_acqua.glb` | **segnaposto** piatti dell'acqua (da sostituire con l'acqua vera) | 124 | - | 0.0 MB |
| `sala_luci.glb` | 67 luci già al loro posto (Omni, Spot, una Directional) | - | - | |
| `sala_dati.json` | posizioni di luci, acqua, piedistallo, vano, spawn, camere | | | |

Texture: 2K JPG incorporate (colore, normal OpenGL, ORM = occlusione/rugosità/metallo). PNG solo dove
serve l'alfa (grigliati, rosa dei venti). Gli oggetti piccoli hanno texture 1K, i grandi 2K.
**GLB nuovo da aggiungere alla scena: `sala_vasca_centrale.glb`** (con lo stesso import script degli altri),
al posto di `sala_monumento.glb`, che è in `glb/per_dopo/`.

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
- **Spawn del giocatore** (appena passato il vano): (0, 0, 19.2), guarda verso **-Z** (la vasca).
- **Vasca sollevata (per la medusa affacciata)**: centro (0, 0, 10), pianta esterna 6 x 4.5 m
  (x per z) con gli angoli arrotondati r 0.5; **cima del bordo a y 1**, coping largo 0.3 m con il toro;
  **pelo dell'acqua a y 0.88**, fondo interno a y 0. Lato verso l'ingresso: filo esterno a z 12.25,
  filo interno a z 11.95.
  - **Marker `medusa_affacciata`** (in `sala_dati.json`): origine consigliata (0, 0.88, 11.75), rotazione (0, 0, 0),
    guarda verso +Z; mani sul coping in (-0.45, 1, 12.1) e (0.45, 1, 12.1).
  - **Pulsante della sigla (scena S1)**: il nodo `sala_pulsante_piedistallo` (stesso nome di prima) è sul
    muro davanti della vasca, in (0, 0.62, 12.35), rivolto verso +Z; si preme verso -Z.
  - Collisioni: muro e bordo (4 tratti dritti e 4 angoli), cordone di velluto a 1.3 m dal bordo, chiuso,
    con un muro invisibile alto 2,5 m. L'acqua è il segnaposto `sala_vasca_centrale_acqua` in `sala_acqua.glb`.
  - Luci: `luce_faro_0/1` (fari su due bracci della parete sud, puntati sul davanti della vasca),
    `luce_vasca_0/1` (sott'acqua, verso la medusa), `luce_lampione` (base (2.8, 0, 13.2)).
  - Offerte dei bambini intorno alla vasca: disegni a pastello senza scritte, conchiglie, stelle marine,
    secchiello; salvagente, orsetto, paperelle (una galleggia), ciambella in acqua e pallone (sono nello stesso GLB della vasca).
- **Secchio gigante**: nodo `sala_secchio_gigante`, perno sui suoi perni; si ribalta ruotando intorno all'asse **X**.
- Niente ruota a pale, galleria e torre (16 ottobre).

## Elementi interattivi (`sala_interattivi.glb`)

Ogni nodo ha l'origine sul suo perno (cerniera o asse): basta ruotarlo o spostarlo.
Il 16 ottobre: nuovi il pulsante A della botola (cassetta, fungo, lampeggiante) e il portone della sala della torre
(anta, telaio, lampeggiante); tolti turbina, recinto, cancello, ruota del cancello, trasmissione e quadro elettrico.

| Nodo | Perno in Godot |
|---|---|
| `sala_portello_scarico` | (0, -2.25, 1.36) |
| `sala_pulsante_portello_cassetta` | (0, 0, -0) |
| `sala_pulsante_portello` | (2.25, -1.12, 4.72) |
| `sala_lampeggiante_portello` | (2.25, -0.58, 4.895) |
| `sala_portone_torre` | (19.84, 0, -15) |
| `sala_portone_torre_telaio` | (0, 0, -0) |
| `sala_lampeggiante_torre` | (19.8, 5.63, -15) |
| `sala_pulsante_piedistallo` | (0, 0.62, 12.35) |

## Acqua (da fare con l'acqua vera; in `sala_acqua.glb` ci sono i segnaposto)

| Segnaposto | Cosa | Livello (y Godot) | Dove |
|---|---|---|---|
| `sala_pozza` | pozza torbida sul fondo della piscina a onde (sopra il portello dello scarico) | -2.07 | intorno a (0, -2.07, 2) |
| `sala_vasca_arrivo_acqua` | vasca d'arrivo degli scivoli (piena) | -0.22 | x da -16 a -9, z da -3 a 7 |
| `sala_vasca_bimbi_1_acqua` | vasca bassa a scacchi (area bimbi, scena "lei sbuca dal bordo") | 0.3 | x da -14.8 a -10.4, z da -11.2 a -8 |
| `sala_vasca_bimbi_2_acqua` | vasca bassa piccola, dove finisce lo scivolo della struttura di gioco | 0.22 | x da -11 a -8.2, z da -19.6 a -16.8 |
| `sala_fossa_bimbi_acqua` | fossa dello scarico rotto, la parte profonda della VascaBimbi1 (stessa acqua): pianta nel poligono 'fossa_bimbi.pianta_godot' | 0.3 | x da -14.8 a -12.3, z da -8 a -6 |

La piscina a onde resta **vuota**: sul fondo si vede la linea scura dell'ultimo livello dell'acqua e la
conca dello scarico più sporca. Sul pavimento della sala le piastrelle più bagnate sono lucide e ci
sono pozzanghere a specchio (con SSR riflettono le luci rosse).

## Luci (in `sala_luci.glb`)

Le posizioni e le direzioni sono giuste; le intensità **nel gioco le decide `LookSala` dell'addon
grafica** (con `LookSalaLunga` dell'integratore): glTF e Godot usano unità diverse. Valori consigliati
(`light_energy`, raggio): emergenza rosse 3 (raggio 8); neon 2,5 (spot, raggio 7, angolo 70); fari
`luce_faro_*` **9,5** (spot, angolo 15, raggio 16, ombre: puntano il davanti della vasca, dove si affaccia
la medusa); sott'acqua `luce_vasca_*` 1,5 (spot, angolo 35, raggio 4, turchese); lampione 10 (spot 55 gradi,
ombre); plafoniere calde `luce_calda_*`
1,8 (raggio 7,5, colore 1,0/0,68/0,38); insegne `luce_insegna_*` 1,3 (raggio 5,5); subacquee 3 (raggio 5);
faretti dei teli con la mascotte `luce_cartellone_*` 2,5 (spot, angolo 30, raggio 6, caldi); luna 0,35 con ombre. `godot/sala_luci_ambiente.gd` serve solo per le prove dell'ambiente e usa gli
stessi valori. In tutto 29 neon accesi, 20 luci d'emergenza, lampione, 2 fari, 2 luci sott'acqua nella
vasca sollevata, 2 faretti dei teli, 4 plafoniere calde, 3 insegne, 2 subacquee della vasca d'arrivo, area bimbi, luna.

| Nome | Tipo | Posizione Godot | Colore | Note |
|---|---|---|---|---|
| `luce_neon_00` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, 16) | (0.8, 1, 0.93) | piena |
| `luce_neon_01` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, 16) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_02` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, 12) | (0.8, 1, 0.93) | piena |
| `luce_neon_03` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, 8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_04` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, 8) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_05` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, 4) | (0.8, 1, 0.93) | piena |
| `luce_neon_06` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, 4) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_07` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, -0) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_08` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, -4) | (0.8, 1, 0.93) | piena |
| `luce_neon_09` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, -4) | (0.8, 1, 0.93) | piena |
| `luce_neon_10` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, -8) | (0.8, 1, 0.93) | piena |
| `luce_neon_12` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, -12) | (0.8, 1, 0.93) | piena |
| `luce_neon_13` | neon (OmniLight3D o SpotLight3D verso il basso) | (19.68, 3.88, -20) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_14` | neon (OmniLight3D o SpotLight3D verso il basso) | (-19.68, 3.88, -20) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_15` | neon (OmniLight3D o SpotLight3D verso il basso) | (-16, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_16` | neon (OmniLight3D o SpotLight3D verso il basso) | (-16, 3.88, -23.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_17` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, 19.68) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_18` | neon (OmniLight3D o SpotLight3D verso il basso) | (-12, 3.88, -23.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_19` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_20` | neon (OmniLight3D o SpotLight3D verso il basso) | (-8, 3.88, -23.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_21` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_22` | neon (OmniLight3D o SpotLight3D verso il basso) | (-4, 3.88, -23.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_23` | neon (OmniLight3D o SpotLight3D verso il basso) | (4, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_24` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, 19.68) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_25` | neon (OmniLight3D o SpotLight3D verso il basso) | (8, 3.88, -23.68) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_26` | neon (OmniLight3D o SpotLight3D verso il basso) | (12, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_27` | neon (OmniLight3D o SpotLight3D verso il basso) | (12, 3.88, -23.68) | (0.8, 1, 0.93) | metà (un tubo spento: sfarfallio) |
| `luce_neon_28` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, 19.68) | (0.8, 1, 0.93) | piena |
| `luce_neon_29` | neon (OmniLight3D o SpotLight3D verso il basso) | (16, 3.88, -23.68) | (0.8, 1, 0.93) | piena |
| `luce_emergenza_30` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, 6) | (1, 0.035, 0.02) |  |
| `luce_emergenza_31` | emergenza rossa (OmniLight3D, raggio 6-8 m) | (19.88, 2.9, -6) | (1, 0.035, 0.02) |  |
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
| `luce_calda_4` | OmniLight3D calda (plafoniera navale accesa) | (-4.6, 3, -23.75) | (1, 0.68, 0.38) |  |
| `luce_cartellone_0` | SpotLight3D: faretto caldo sul telo con la mascotte | (-5.274, 6.81, 10.414) | (1, 0.78, 0.5) | punta verso (-0.172, -0.93, -0.324) |
| `luce_cartellone_1` | SpotLight3D: faretto caldo sul telo con la mascotte | (5.274, 6.81, 10.414) | (1, 0.78, 0.5) | punta verso (0.172, -0.93, -0.324) |
| `luce_vasca_0` | SpotLight3D sott'acqua nella vasca sollevata, verso la medusa | (-1.4, 0.25, 10.2) | (0.35, 0.9, 0.85) | punta verso (0.646, 0.323, 0.692) |
| `luce_vasca_1` | SpotLight3D sott'acqua nella vasca sollevata, verso la medusa | (1.4, 0.25, 10.2) | (0.35, 0.9, 0.85) | punta verso (-0.646, 0.323, 0.692) |
| `luce_faro_0` | SpotLight3D: faro sulla ringhiera della galleria, punta la statua o la medusa affacciata | (-2.029, 5.422, 19.188) | (1, 0.9, 0.76) | punta verso (0.236, -0.428, -0.872) |
| `luce_faro_1` | SpotLight3D: faro sulla ringhiera della galleria, punta la statua o la medusa affacciata | (2.029, 5.422, 19.188) | (1, 0.9, 0.76) | punta verso (-0.236, -0.428, -0.872) |
| `luce_subacquea_0` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, 6.85) | (0.25, 0.95, 0.75) |  |
| `luce_subacquea_1` | OmniLight3D sott'acqua, vasca d'arrivo | (-12.5, -0.7, -2.85) | (0.25, 0.95, 0.75) |  |
| `luce_insegna_rosa` | OmniLight3D davanti all insegna a pesce | (-3, 7.4, -23.5) | (1, 0.22, 0.6) |  |
| `luce_area_bimbi` | OmniLight3D gialla sulla struttura | (-14.4, 3.6, -21.2) | (1, 0.8, 0.5) |  |
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
