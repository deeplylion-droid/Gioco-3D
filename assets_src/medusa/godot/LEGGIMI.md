# Medusa in Godot

File:

- `assets_src/medusa/medusa.glb`: la medusa finita, a grandezza vera (scheletro, pesi, blend shape, animazioni,
  materiali PBR).
- Questa cartella:
  - campana: shader (`medusa_campana.gdshader`), materiale (`medusa_campana.tres`) e texture
    (`campana_base_alfa.png`, `campana_emissione.png`);
  - tentacoli: materiale traslucido (`medusa_tentacoli.tres`) e texture (`tentacoli_base.jpg`,
    `tentacoli_emissione.jpg`, `tentacoli_normal.png`);
  - ciocche dei capelli: materiale lucido e bagnato (`medusa_ciocche.tres`) e texture (`ciocche_base.jpg`,
    `ciocche_emissione.jpg`, `ciocche_normal.png`);
  - pelle e labbro dell'orbita: vinile pervinca satinato (`medusa_pelle.tres`, `medusa_orbita.tres`) con le
    texture 4K del corpo (`medusa_colore_4k.jpg`, `medusa_normal_4k.jpg`).

## Dove metterli

Copia `medusa.glb` e tutto il contenuto di questa cartella nella stessa cartella del progetto, per esempio
`godot/assets/models/medusa/`. I `.tres` usano percorsi relativi: shader e texture devono stare accanto a loro.

## Grandezza, posa statua e misure

La statua e' imponente, come Huggy Wuggy nella hall di Poppy Playtime: **alta 4,5 m** dal piano d'appoggio dei
tentacoli alla cima della testa, gia' in scala vera nel GLB (1 unita' = 1 m, nessuna scala da applicare).

La posa di riposo del GLB e' la statua: mani giunte sul petto, **in piedi sui tentacoli**. Istanziata senza
animazioni, la medusa e' ferma come nel concept.

Misure: la medusa guarda verso +Z. **L'origine e' sul piano d'appoggio dei tentacoli**: metti l'istanza con
l'origine sulla faccia superiore del piedistallo. I tentacoli restano dentro un raggio di 1,55 m, quindi il
piedistallo deve avere un raggio di almeno 1,75 m (nei render: raggio 1,75 m, alto 1 m). Il bordo della campana
e' a circa 1,77 m, il busto tra 2,7 e 3,3 m, la cima della testa a 4,5 m.

## Animazioni (AnimationPlayer)

- `statua`: uguale alla posa di riposo.
- `sveglia` (30 fotogrammi, 1,25 s): si stacca dal piedistallo. Il corpo sale di 0,83 m, i tentacoli si
  staccano dal piano e pendono, le braccia si aprono un poco.
- `fluttua` (ciclo di 2 s): sospesa, ondeggia; la campana pulsa e i tentacoli si muovono.
- `insegue` (ciclo di 1 s): braccia protese, busto in avanti, tentacoli trascinati indietro.
- `fauce_apre` (1 s): attacco con la fauce che si apre.
- `affacciata` (ciclo di 4 s): la medusa vera affacciata alla vasca della sala centrale, immobile, con un
  respiro appena visibile (campana schiacciata sott'acqua). Vedi sotto.

Le animazioni da sveglia (`sveglia` alla fine, `fluttua`, `insegue`, `fauce_apre`) hanno il corpo alla stessa
altezza, quindi si possono fondere tra loro. Lo spostamento nel livello lo fa il gioco.

## Sala centrale: la medusa affacciata alla vasca (`affacciata`)

La medusa vera (stesso GLB, stessa scala) dentro la vasca sollevata al centro della sala, come nel concept
`docs/concept/medusa_sbircia.jpg`: immersa con il pelo dell'acqua appena sopra il seno (regola del GDD: il seno
resta coperto), busto inclinato in avanti, spalle alzate, testa sporta sopra lo spigolo interno e appena
inclinata; sbircia dal basso chi entra, con l'occhio all'altezza dei suoi occhi. Mani larghe aggrappate al
coping, gomiti in fuori; la campana brilla sott'acqua, schiacciata e allargata.

- Marker `medusa_affacciata`: **posizione (0, 0, 10,15), rotazione (0, 0, 0)** (come prima), con la vasca
  `sala_vasca_centrale.glb` centrata in (0, 0, 10). L'origine del GLB va al livello del pavimento della sala,
  2,1 m dietro il filo esterno del muro davanti (z 12,25); la medusa guarda verso +Z.
- Animazione `affacciata` (96 fotogrammi, 4 s) da mettere in ciclo (Loop Mode Linear) e far partire subito:
  tiene tutta la posa, il solo movimento e' il respiro sul petto e sulle spalle. Mette anche a 1 la blend shape
  `campana_schiaccia` (mesh `Medusa`, `Medusa_Interno`, `Medusa_Bordo`): la campana si abbassa (x0,38) e si
  allarga sott'acqua. Le altre animazioni non la toccano: se dopo l'affacciata se ne usa un'altra, rimetterla a 0.
- Dove tocca la vasca (coordinate della sala): occhio in (0; 1,63; 11,95), cima della testa a y 2,18; vita in
  (0; 0,43; 11,19); campana tra y 0,07 e 0,45 (tutta sott'acqua); seno sotto il pelo dell'acqua (0,88).
  Mani sul coping in x +-0,6: polso sullo spigolo interno (z 11,95), palmo sul coping, dita piegate oltre lo
  spigolo esterno con i polpastrelli sul fronte (fino a z 12,31, y 0,91), pollice sul coping verso l'interno.
- Tentacoli fuori dal bordo (escono dall'acqua lungo il muro interno, si appoggiano sul coping e ricadono lungo
  il muro davanti): 4 zampe in x -1,62, -1,42, +1,48, +1,68 che arrivano al pavimento e ci si allargano (fino a
  circa 0,4 m davanti al muro); 4 medi tra le mani e accanto (x -0,9, -0,34, +0,34, +0,9) che pendono lungo il
  muro. Restano liberi il pulsante (x -0,2..0,2) e i disegni appesi al muro. Gli altri 17 tentacoli stanno
  sott'acqua, dentro la vasca.
- **Aspetto bagnato** (solo questa scena): materiali alternativi da applicare in override al posto di quelli
  normali, senza cambiare le texture: `medusa_pelle_bagnata.tres` (superficie 0 di `Medusa`),
  `medusa_capelli_bagnata.tres` (superficie 1), `medusa_orbita_bagnata.tres` (superficie 3),
  `medusa_mani_bagnata.tres` (`Medusa_Mani`), `medusa_ciocche_bagnata.tres` (`Medusa_Ciocche`: punte piu' scure
  e lucide) e `medusa_tentacoli_bagnata.tres` (`Medusa_Tentacoli` e superficie 0 di `Medusa_Bordo`).
- Le gocce (punte dei capelli, mento, dita, tentacoli sul bordo) sono particelle del motore. La fisica dei
  tentacoli resta spenta in questa posa.
- Per far seguire il giocatore all'occhio si ruota l'osso `occhio` da codice, al massimo 15 gradi.

## Mani

Le mani sono un oggetto a parte, `Medusa_Mani` (materiale `M_mani`): mani da bambola in vinile rifatte da zero,
cinque dita separate con tre falangi, nocche e unghie appena accennate, pollice opponibile; la giuntura e' il
solco del polso, come nelle bambole. Ogni vertice dipende al massimo da due ossa (niente influenze da un dito
all'altro), quindi in Godot si deformano come in Blender. Le ossa hanno gli stessi nomi di prima (`mano`,
`pollice_1..3`, `indice_1..3`, `medio_1..3`, `anulare_1..3`, `mignolo_1..3`, con `.L` e `.R`); asse Z sul dorso,
la piega delle dita e' la rotazione intorno all'asse X. Il colore viene dal colore dei vertici (unghie appena piu'
chiare, pieghe un po' piu' scure): per la tinta del gioco usa `medusa_mani.tres` su `Medusa_Mani`.

## Occhio: versione malvagia (`venatura`)

`medusa_occhio.tres` (shader `medusa_occhio.gdshader`) su `Medusa_Occhio` mescola l'occhio calmo e quello venato
(capillari rossi dal bordo della sclera verso l'iride, sclera ingiallita, iride piu' accesa) con il parametro
`venatura` da 0 (calma, come nel glTF) a 1. In gioco si puo' animare quando attacca:
`$Medusa_Occhio.get_surface_override_material(0).set_shader_parameter("venatura", v)`.

## Campana: gelatina trasparente, canali luminosi, struttura interna, bordo

Il glTF da solo da' una campana trasparente con i canali luminosi fissi. Lo shader aggiunge la gelatina vera:
piu' opaca di taglio e trasparente di fronte, quello che sta dentro e dietro (struttura interna, radici dei
tentacoli) visto deformato e tinto di lilla, la luce dei canali che si sparge e la pulsazione.

- Dall'editor: doppio clic su `medusa.glb` > Advanced Import Settings > Materials > `M_campana` >
  Use External > scegli `medusa_campana.tres` > Reimport.
- Da codice: la campana e' la superficie 2 della mesh `Medusa`:
  `$Medusa/Medusa_Scheletro/Skeleton3D/Medusa.set_surface_override_material(2, load("res://assets/models/medusa/medusa_campana.tres"))`

Parametri utili: `luce_canali` (intensita'), `pulsazione_al_secondo` (0 = canali fissi, per la statua
"spenta"), `opacita_centro` / `opacita_bordo`, `rifrazione`, `bagliore_dentro`. Dove sono i canali lo dice la
texture colore (le righe chiare, `soglia_canali`); `campana_emissione.png` da' solo la tinta, sfocata.

Dentro la campana c'e' la mesh `Medusa_Interno` (canali principali e secondari, canale ad anello, quattro
gonadi: materiale emissivo `M_campana_interno`); sul bordo `Medusa_Bordo` (frangia di linguette col materiale
dei tentacoli e puntini luminosi). Entrambe pulsano con la blend shape `campana_contrai`, come la campana.

## Pelle

Dal glTF la pelle arriva molto lucida (la ruvidita' della texture e' pensata per il render con la lacca).
Per il vinile pervinca satinato del gioco usa `medusa_pelle.tres` su `M_pelle` (superficie 0 della mesh
`Medusa`) e `medusa_orbita.tres` su `M_orbita` (superficie 3), sempre con Use External o da codice con
`set_surface_override_material`. Tinta pervinca (0,74; 0,80; 1,0) e rugosita' 0,24.

## Tentacoli

Nastri carnosi magenta e rosa: un oggetto (`Medusa_Tentacoli`), una superficie, materiale `M_tentacoli`.
Dal glTF arrivano colore, emissione (la vena luminosa) e normal map. Per la traslucenza (subsurface,
controluce, bordo luminoso e lacca) usa `medusa_tentacoli.tres`, come per la campana:

- Advanced Import Settings > Materials > `M_tentacoli` > Use External > `medusa_tentacoli.tres`;
- oppure da codice: `$Medusa/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli.set_surface_override_material(0, load("res://assets/models/medusa/medusa_tentacoli.tres"))`.

## Capelli

Il volume dei capelli fa da fondo (superficie `M_capelli` della mesh `Medusa`); sopra ci sono le ciocche
separate (`Medusa_Ciocche`, materiale `M_ciocche`): il colore viene dal colore dei vertici (preso dalla texture
dei capelli) moltiplicato per le fibre, con le punte rosa traslucide. Per il lucido bagnato usa
`medusa_ciocche.tres` (stesso modo: Use External su `M_ciocche`).

Subsurface scattering e refrazione funzionano con il renderer Forward+.

## Triangoli, texture e LOD

Circa 140 mila triangoli in tutto (corpo circa 60 mila, ciocche circa 33 mila, tentacoli circa 31 mila, campana
interna e bordo circa 15 mila, occhio e fauce il resto). Texture: corpo e capelli a 4K (colore, normal,
ruvidita'), campana a 2K, tentacoli e ciocche 1024 x 2048 e 512 x 1024.

LOD: Godot crea da solo i livelli di dettaglio all'import (Advanced Import Settings > Meshes > Generate LODs,
attivo di default): da lontano ogni mesh scende a pochi mila triangoli.

## Ossa e blend shape utili

- `occhio`: ruota il bulbo dell'occhio (asse Y dell'osso = direzione dello sguardo). Rotazione massima
  prevista: 15 gradi, oltre il bulbo scopre l'orbita.
- `mascella` + blend shape `fauce_strappo` (mesh `Medusa`) e `fauce_aperta` (mesh `Medusa_Gola` e
  `Medusa_Denti`): la fauce. Da chiusa non si vede nulla (il viso resta liscio); l'animazione `fauce_apre`
  muove tutto insieme (osso e blend shape da 0 a 1).
- `campana_contrai` (mesh `Medusa`, `Medusa_Interno`, `Medusa_Bordo`): la campana si stringe, per la pulsazione.
- `radice`: tutto il corpo (in `sveglia` sale di 0,83 m).
- Catene dei tentacoli, figlie di `campana`, per la fisica (per esempio SpringBoneSimulator3D, una catena
  per tentacolo): `tentacolo_01` ... `tentacolo_06` sono le 6 zampe (10 ossa: `tentacolo_01_01` ...
  `tentacolo_01_10`), `tentacolo_07` ... `tentacolo_13` i 7 medi (7 ossa), `tentacolo_14` ... `tentacolo_25`
  i 12 sottili (4 ossa). Nella posa statua i tentacoli reggono il peso: la fisica va accesa solo dopo `sveglia`.

Per un riflesso bagnato credibile sull'occhio di vetro e sulle ciocche serve una ReflectionProbe vicino alla
statua (o un cielo/ambiente nel WorldEnvironment).
