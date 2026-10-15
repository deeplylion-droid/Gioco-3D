# Medusa in Godot

File:

- `assets_src/medusa/medusa.glb`: la medusa finita (scheletro, pesi, blend shape, animazioni, materiali PBR).
- Questa cartella:
  - campana: shader (`medusa_campana.gdshader`), materiale (`medusa_campana.tres`) e texture
    (`campana_base_alfa.png`, `campana_emissione.png`);
  - tentacoli: materiale traslucido (`medusa_tentacoli.tres`) e texture (`tentacoli_base.jpg`,
    `tentacoli_emissione.jpg`, `tentacoli_normal.png`).

## Dove metterli

Copia `medusa.glb` e tutto il contenuto di questa cartella nella stessa cartella del progetto, per esempio
`godot/assets/models/medusa/`. I `.tres` usano percorsi relativi: shader e texture devono stare accanto a loro.

## Posa statua e misure

La posa di riposo del GLB è la statua: mani giunte sul petto, **in piedi sui tentacoli**. Istanziata senza
animazioni, la medusa è ferma come nel concept.

Misure (1 unità = 1 m): la medusa guarda verso +Z. **L'origine è sul piano d'appoggio dei tentacoli**: metti
l'istanza con l'origine sulla faccia superiore del piedistallo. I tentacoli restano dentro un raggio di 0,93 m,
quindi il piedistallo deve avere un raggio di almeno 1,05 m. Il bordo della campana è a circa y = 1,05, la cima
della testa a circa y = 2,7.

## Animazioni (AnimationPlayer)

- `statua`: uguale alla posa di riposo.
- `sveglia` (30 fotogrammi, 1,25 s): si stacca dal piedistallo. Il corpo sale di 0,5 m, i tentacoli si
  staccano dal piano e pendono, le braccia si aprono un poco.
- `fluttua` (ciclo di 2 s): sospesa, ondeggia; la campana pulsa e i tentacoli si muovono.
- `insegue` (ciclo di 1 s): braccia protese, busto in avanti, tentacoli trascinati indietro.
- `fauce_apre` (1 s): attacco con la fauce che si apre.

Le animazioni da sveglia (`sveglia` alla fine, `fluttua`, `insegue`, `fauce_apre`) hanno il corpo alla stessa
altezza (+0,5 m), quindi si possono fondere tra loro. Lo spostamento nel livello lo fa il gioco.

## Campana trasparente con i canali luminosi

Il glTF da solo dà una campana trasparente con i canali luminosi fissi. Lo shader aggiunge la trasparenza
"a gelatina" (più opaca di taglio, più trasparente di fronte) e la pulsazione dei canali.

- Dall'editor: doppio clic su `medusa.glb` > Advanced Import Settings > Materials > `M_campana` >
  Use External > scegli `medusa_campana.tres` > Reimport.
- Da codice: la campana è la superficie 2 della mesh `Medusa`:
  `$Medusa/Medusa_Scheletro/Skeleton3D/Medusa.set_surface_override_material(2, load("res://assets/models/medusa/medusa_campana.tres"))`

Parametri utili del materiale: `luce_canali` (intensità), `pulsazione_al_secondo` (0 = canali fissi, per
la statua "spenta"), `opacita_centro` / `opacita_bordo`.

## Tentacoli

Nastri carnosi magenta e rosa: un solo oggetto (`Medusa_Tentacoli`), una superficie, materiale `M_tentacoli`.
Dal glTF arrivano colore, emissione (la vena luminosa) e normal map. Per la traslucenza (subsurface,
controluce, bordo luminoso e lacca) usa `medusa_tentacoli.tres`, come per la campana:

- Advanced Import Settings > Materials > `M_tentacoli` > Use External > `medusa_tentacoli.tres`;
- oppure da codice: `$Medusa/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli.set_surface_override_material(0, load("res://assets/models/medusa/medusa_tentacoli.tres"))`.

Il subsurface scattering funziona con il renderer Forward+.

LOD: i tentacoli hanno circa 31 mila triangoli (la medusa intera circa 68 mila). Godot crea da solo i livelli
di dettaglio all'import (Advanced Import Settings > Meshes > Generate LODs, attivo di default): da lontano
i tentacoli scendono a pochi mila triangoli. Le texture sono a 2K (1024 x 2048 per i tentacoli).

## Ossa e blend shape utili

- `occhio`: ruota il bulbo dell'occhio (asse Y dell'osso = direzione dello sguardo). Rotazione massima
  prevista: 15 gradi, oltre il bulbo scopre l'orbita.
- `mascella` + blend shape `fauce_strappo` (mesh `Medusa`) e `fauce_aperta` (mesh `Medusa_Gola` e
  `Medusa_Denti`): la fauce. Da chiusa non si vede nulla; l'animazione `fauce_apre` muove tutto insieme
  (osso e blend shape da 0 a 1).
- `campana_contrai` (mesh `Medusa`): la campana si stringe, per la pulsazione quando nuota.
- `radice`: tutto il corpo (in `sveglia` sale di 0,5 m).
- Catene dei tentacoli, figlie di `campana`, per la fisica (per esempio SpringBoneSimulator3D, una catena
  per tentacolo): `tentacolo_01` ... `tentacolo_06` sono le 6 zampe (10 ossa: `tentacolo_01_01` ...
  `tentacolo_01_10`), `tentacolo_07` ... `tentacolo_13` i 7 medi (7 ossa), `tentacolo_14` ... `tentacolo_25`
  i 12 sottili (4 ossa). Nella posa statua i tentacoli reggono il peso: la fisica va accesa solo dopo `sveglia`.
