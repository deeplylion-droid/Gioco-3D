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

Le animazioni da sveglia (`sveglia` alla fine, `fluttua`, `insegue`, `fauce_apre`) hanno il corpo alla stessa
altezza, quindi si possono fondere tra loro. Lo spostamento nel livello lo fa il gioco.

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
