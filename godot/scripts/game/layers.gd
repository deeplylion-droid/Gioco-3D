@tool
class_name Layers
## Livelli fisici del progetto. I nomi sono in Impostazioni progetto > Nomi dei livelli > Fisica 3D.

const WORLD := 1            ## 1 "mondo": pavimenti, muri, porte, piattaforme
const PLAYER := 2           ## 2 "giocatore"
const ENEMIES := 4          ## 3 "nemici"
const PROPS := 8            ## 4 "oggetti": corpi rigidi che si spingono
const INTERACTION := 16     ## 5 "interazione": aree Interactable (tasto E)
const WATER_TARGETS := 32   ## 6 "bersagli_acqua": aree WaterHitbox colpite dal getto
const WATER_VOLUMES := 64   ## 7 "volumi_acqua": WaterVolume e zone bagnate
const LADDERS := 128        ## 8 "scale": aree Ladder
