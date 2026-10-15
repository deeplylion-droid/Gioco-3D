# addons/grafica

Grafica del gioco: torcia, impostazioni grafiche con preset, menu delle opzioni, calibrazione della luminosità, lampi, neon, luci d'emergenza, particelle e post-processing. Viene da `labs/grafica/` (non modificare qui: si rigenera con `labs/grafica/strumenti/esporta_addon.sh`). Screenshot e scelte: `docs/report/grafica.md`.

Non è un plugin dell'editor: sono script con `class_name`, non va attivato in Progetto > Plugin.

## Integrazione, passo per passo

### 1. Autoload (obbligatorio)

In `project.godot`:
```
[autoload]
Grafica="*res://addons/grafica/impostazioni_grafiche.gd"
```
Carica `user://settings.cfg`, applica il preset (predefinito: Alto) e crea il post-processing (grana, vignettatura, aberrazione, gamma) su un CanvasLayer di livello 50. HUD sotto il 50, menu sopra (100).

### 2. Input

L'autoload crea da solo, se mancano, le azioni `torcia` (tasto F) e `menu_opzioni` (Esc). Se preferite definirle in `project.godot` con gli stessi nomi, vengono usate quelle.

### 3. Impostazioni di progetto consigliate

```
[rendering]
renderer/rendering_method="forward_plus"
lights_and_shadows/directional_shadow/size=4096
lights_and_shadows/positional_shadow/atlas_size=4096
lights_and_shadows/positional_shadow/soft_shadow_filter_quality=2
anti_aliasing/quality/use_debanding=true
environment/volumetric_fog/use_filter=1
global_illumination/voxel_gi/quality=0
```
Upscaling, antialiasing, ombre, GI, nebbia, SSR, SSAO e SSIL li imposta l'autoload a runtime secondo il preset: non serve fissarli nel progetto.

### 4. Torcia

Istanziare `res://addons/grafica/torcia.tscn` come figlia della `Camera3D` del giocatore. Si accende/spegne con F.
```gdscript
torcia.disturbo = 0.8          # sfarfallio continuo (es. mostro vicino), 0 = normale
torcia.sfarfalla(1.5)          # un colpo di sfarfallio
torcia.accesa_cambiata.connect(func(accesa): $SuonoClic.play())
torcia.batteria_attiva = false # batteria pronta ma spenta: scelta di design aperta
```

### 5. Environment della zona

```gdscript
$WorldEnvironment.environment = AmbienteHorror.crea()   # AgX, nebbia volumetrica, SSR/SSAO/SSIL
```
L'autoload accende e spegne gli effetti secondo le opzioni, ma non cambia i valori artistici. Consigliati per ogni zona: un `VoxelGI` (bake nell'editor, è la GI scelta per Alto/Ultra) e una `ReflectionProbe` in modalità interno.

### 6. Menu delle opzioni e calibrazione

```gdscript
var menu := preload("res://addons/grafica/menu_opzioni.tscn").instantiate()
add_child(menu)                       # si chiude da solo (Esc o "Chiudi")
menu.get_node("Menu").chiuso.connect(func(): get_tree().paused = false)
if not Grafica.valore("calibrato"):   # al primo avvio
	add_child(preload("res://addons/grafica/calibrazione_luminosita.tscn").instantiate())
```
Il menu lavora anche con il gioco in pausa (`process_mode = ALWAYS`).

### 7. Effetti ambientali (nodi da aggiungere al livello)

Tutti creano da soli la loro geometria e le luci; si posizionano e si regolano dall'Inspector.

| Nodo | Uso | Segnali per l'audio |
|---|---|---|
| `Tempesta` | lampi visti dalla cupola: una `DirectionalLight3D` che si muove, cielo `cielo_tempesta.gdshader`, materiali con parametro `lampo` (es. `vetro_cupola.gdshader`). `lampo_ora()` per i lampi a copione. | `lampo(intensita)`, `tuono(intensita, distanza_km)` già ritardato |
| `Neon` | modalità STABILE, SFARFALLA, GUASTO, MORENTE, SPENTO; `spegni()`, `accendi()` | `acceso_cambiato(acceso)`, `scintilla` |
| `LuceEmergenza` | rossa FISSA, PULSANTE o ROTANTE | `stato_cambiato(accesa)` |
| `Pulviscolo` | polvere nell'aria (`volume`) | - |
| `Vapore` | vapore che sale, con FogVolume | - |
| `Gocce` | gocce dal soffitto con schizzo | `goccia_caduta(posizione)` |

### 8. Facoltativo

- Priorità delle ombre di una luce: `luce.set_meta("grafica_priorita_ombra", 0)` sempre, `1` importante (predefinito), `2` secondaria. I preset bassi tolgono prima le secondarie.
- Particelle sotto l'opzione "Particelle": gruppo `grafica_particelle`.
- `Grafica.imposta("chiave", valore)`, `Grafica.applica_preset("ultra")`, segnale `Grafica.impostazione_cambiata`.

## Sala principale: il look (LookSala)

Preset di illuminazione e post-processing per la sala vera (`assets_src/ambiente/glb/sala/`). Confronto prima/dopo: `docs/report/render_grafica/sala_reale/`.

1. Monta la sala come in `assets_src/ambiente/INTEGRAZIONE.md` (GLB in 0,0,0 sotto un Node3D "SalaPrincipale", con l'Import Script).
2. Su "SalaPrincipale" usa **`res://addons/grafica/look_sala.gd`** al posto di `sala_luci_ambiente.gd` (non vanno usati insieme).
3. Fa tutto da solo all'avvio:
   - mette nel `WorldEnvironment` (lo crea se manca) `sala/ambiente_sala.tres` e `sala/attributi_camera_sala.tres`;
   - regola le 49 luci di `sala_luci.glb` per nome: emergenze rosse profonde (ombre su 1 ogni 3, alcune pulsano), neon freddi verso il verde (quelli "a metà" sfarfallano, sono guasti o morenti), lampione caldo al sodio con ombre e cono visibile nella nebbia, area bimbi calda, luna blu con le ombre dei costoloni;
   - luci del monumento: `luce_faro_0/1` luce principale dall'alto e davanti (5,5, cono 13°, ombre), `luce_monumento_basso_*` faretti caldi dal basso (0,6; ombre solo sui due davanti), lampione caldo più basso (3,5) per non bruciare il vinile; più un **controluce** freddo dietro la statua (`ControluceStatua`) che la stacca dal fondo entrando dal vano sud;
   - plafoniere calde `luce_calda_*` (1,8) e insegne `luce_insegna_*` (1,3; la rosa 2,6);
   - crea `VoxelGI_Sala`, due `ReflectionProbe` (sala e piscina, modalità interno), la `Tempesta` (lampi dalla cupola), nebbia bassa (`FogVolume`), pulviscolo e gocce dal soffitto.
   - Volumi della sala come `@export` (`sala_centro` (0, 7,5, -2), `sala_dimensioni` (41, 21, 45): sala lunga fino a z = 20) e posizione del monumento (`monumento` (0, 0, 10), `altezza_statua` 4,5). Se la sala cambia di nuovo basta aggiornare questi valori: VoxelGI, sonde, nebbia e pulviscolo li seguono.
   - `vetro_cupola` (facoltativo): uno ShaderMaterial con `vetro_cupola.gdshader` che si accende con i lampi.
4. **VoxelGI**: senza dati l'autoload lo calcola all'avvio (qualche secondo, bloccante). Per la build: aggiungere a mano un `VoxelGI` con le stesse misure (posizione (0, 7,5, -2), dimensioni (41, 21, 45), subdiv 256), premere **Bake** nell'editor e mettere `crea_gi = false` su LookSala.
5. **Statua (medusa)**: nel materiale `medusa_tentacoli.tres` va messo `emission_operator = Multiply` (come nel GLB). Con "Add" (predefinito) il bianco di `emission` si somma alla texture delle vene e i tentacoli escono bianchi, "bruciati". Con Multiply le vene possono restare al 100%.
6. Le opzioni grafiche dell'utente (Grafica) restano attive: spengono VoxelGI, SSR, SSAO, SSIL, nebbia volumetrica secondo il preset; il color grading è quello dell'opzione "Color grading" (predefinito "Notte fredda": ombre verso il blu-verde).
7. Tutti i valori sono `@export` su LookSala (energie, colori) e le due `.tres` si possono ritoccare nell'Inspector.

## Interni (pezzo campione): LookInterni

Luce e immagine del corridoio del risveglio, degli spogliatoi con tornello e lava-piedi e dello stanzino. Prima e dopo: `docs/report/render_grafica/campione/`.

- Le luci stanno in una scena separata, `scenes/interni/luci_interni.tscn` (radice con `look_interni.gd`), istanziata in `interni.tscn` come `LuciInterni`: chi rifà modelli e texture degli interni non tocca le luci.
- All'avvio regola per nome i `Neon` e le `LuceEmergenza` create da `interni.gd` (rosse raccolte in pozze, neon freddi con ombre morbide, lampada calda sullo zaino), crea un `VoxelGI` per stanza con i dati cotti in `scenes/interni/gi/` e, quando la camera è dentro gli interni, le dà `interni/ambiente_interni.tres` e `interni/attributi_interni.tres` (in gioco gli interni stanno dentro la sala, che ha un Environment diverso).
- **Ricuocere il GI** quando cambiano i modelli: `xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/cuoci_gi_interni.gd`.
- Screenshot prima/dopo: `tests/screenshots_campione.gd` (istruzioni in cima al file).
