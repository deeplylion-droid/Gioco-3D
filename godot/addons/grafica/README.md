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
