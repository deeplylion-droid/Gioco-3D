# Medusa in Godot

File:

- `assets_src/medusa/medusa.glb`: la medusa finita (scheletro, pesi, blend shape, animazioni, materiali PBR).
- Questa cartella: lo shader della campana (`medusa_campana.gdshader`), il materiale da applicare
  (`medusa_campana.tres`) e le sue due texture (`campana_base_alfa.png`, `campana_emissione.png`).

## Dove metterli

Copia `medusa.glb` e tutto il contenuto di questa cartella nella stessa cartella del progetto, per esempio
`godot/assets/models/medusa/`. Il `.tres` usa percorsi relativi: shader e texture devono stare accanto a lui.

## Posa statua

La posa di riposo del GLB è già la statua (mani giunte sul petto): istanziata senza animazioni, la medusa è
ferma come nel concept. L'AnimationPlayer contiene anche `statua` (uguale alla posa di riposo), `insegue`,
`fluttua` (ciclo di 2 s) e `fauce_apre` (1 s).

Misure (1 unità = 1 m): la medusa guarda verso +Z, l'origine è all'altezza della vita; la cima della testa è
a circa y = +0,95 e le punte dei tentacoli a circa y = -2,2. Il piedistallo va messo con il piano a quella quota.

## Campana trasparente con i canali luminosi

Il glTF da solo dà una campana trasparente con i canali luminosi fissi. Lo shader aggiunge la trasparenza
"a gelatina" (più opaca di taglio, più trasparente di fronte) e la pulsazione dei canali.

- Dall'editor: doppio clic su `medusa.glb` > Advanced Import Settings > Materials > `M_campana` >
  Use External > scegli `medusa_campana.tres` > Reimport.
- Da codice: la campana è la superficie 2 della mesh `Medusa`:
  `$Medusa/Medusa_Scheletro/Skeleton3D/Medusa.set_surface_override_material(2, load("res://assets/models/medusa/medusa_campana.tres"))`

Parametri utili del materiale: `luce_canali` (intensità), `pulsazione_al_secondo` (0 = canali fissi, per
la statua "spenta"), `opacita_centro` / `opacita_bordo`.

## Ossa e blend shape utili

- `occhio`: ruota il bulbo dell'occhio (asse Y dell'osso = direzione dello sguardo). Rotazione massima
  prevista: 15 gradi, oltre il bulbo scopre l'orbita.
- `mascella` + blend shape `fauce_strappo` (mesh `Medusa`) e `fauce_aperta` (mesh `Medusa_Gola` e
  `Medusa_Denti`): la fauce. Da chiusa non si vede nulla; l'animazione `fauce_apre` muove tutto insieme
  (osso e blend shape da 0 a 1).
- `campana_contrai` (mesh `Medusa`): la campana si stringe, per la pulsazione quando nuota.
- `tentacolo_01_01` ... `tentacolo_12_10`: 12 catene di 10 ossa, figlie di `campana`, per la fisica
  (per esempio SpringBoneSimulator3D, una catena per tentacolo).
- `Medusa_Filamenti`: i 14 tentacoli sottili non hanno ossa; UV.y va da 0 (radice) a 1 (punta), per muoverli
  con uno shader.
