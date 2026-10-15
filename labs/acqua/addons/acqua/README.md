# Acqua (addon per Splash Lagoon)

Acqua per Godot 4.7 (renderer **Forward+**): superficie delle vasche con rifrazione, riflessi,
schiuma e gorghi, caustiche su fondo e pareti, effetto sott'acqua, pavimenti bagnati con pozzanghere
e cerchi delle gocce, livello che sale e scende, particelle (schizzi, gocce, getti, aspirazione),
acqua che scorre negli scivoli. Sviluppato nel laboratorio `labs/acqua/` (scena di prova
`labs/acqua/demo/demo_piscina.tscn`); questa cartella si copia cosi' com'e' nel gioco.

## Installazione (passi esatti)

1. La cartella va in `res://addons/acqua/` (i percorsi interni sono tutti `res://addons/acqua/...`).
   Non e' un plugin dell'editor: non va attivato in Impostazioni progetto > Plugin.
2. **Autoload** (Impostazioni progetto > Globals > Autoload), obbligatorio:
   `WaterManager` = `res://addons/acqua/scripts/water_manager.gd` (attivo, "Global Variable").
   In `project.godot` e' la riga, nella sezione `[autoload]`:
   ```
   WaterManager="*res://addons/acqua/scripts/water_manager.gd"
   ```
3. **Variabili globali degli shader**: nel gioco le registra l'autoload all'avvio, non serve
   altro. Per vedere l'acqua anche nell'editor senza errori conviene dichiararle: copia in fondo a
   `project.godot` il blocco del file `shader_globals.txt` (in questa cartella).
4. **Input**: nessuno obbligatorio. Gli effetti dello zaino leggono lo stato del WaterPack del
   gioco (azioni gia' esistenti `suck` e `spray`).
5. Renderer **Forward+** (le increspature interattive usano un compute shader; con Compatibility
   l'acqua si vede ma senza increspature).
6. Riflessi: la superficie dell'acqua sta sul **layer di rendering 20** (`WaterBody.WATER_LAYER`).
   La camera del giocatore deve vederlo (di serie si'); i ReflectionProbe vengono esclusi da soli.

## Cosa mettere nella sala

| Scena / nodo | Dove | Note |
|---|---|---|
| `scenes/acqua_per_vasca.tscn` (WaterTankLink) | uno per ogni `WaterTank` o `WaterVolume` | imposta `tank`; prende da li' dimensioni e livello a ogni fotogramma e nasconde il segnaposto grigio. Scegli lo `style` (vedi sotto). Per la pozza: `drain_offset` = posizione dello scarico rispetto al centro della vasca, il gorgo parte quando lo scarico e' aperto (`get_drain_strength()`). |
| `scenes/pozza_torbida.tscn`, `vasca_acqua.tscn`, `vasca_bimbi.tscn` (WaterBody) | in alternativa, se una vasca non ha un WaterTank | nodo al centro dell'area d'acqua; `size` = rettangolo in pianta, `level` = quota del pelo dell'acqua, `bottom` = quota del fondo piu' basso, `max_level` = bordo. Livello: `set_target_level(y, velocita')`, `fill()`, `drain()`, oppure `level = y` (subito). Segnali: `level_changed(level)`, `emptied`, `filled`. Aspirazione: `remove_volume(m3)`. |
| `scenes/convertitore_bagnato.tscn` (WetSurfaceConverter) | uno per gruppo di superfici | `roots` = le istanze dei GLB (sala_architettura, sala_piscina, sala_area_bimbi, sala_torre_scivoli). Rimpiazza i materiali con quello bagnabile tenendo le stesse texture: caustiche sott'acqua, banda bagnata e bordo scuro sopra il pelo, pozzanghere (`puddle_amount`, per i pavimenti 0.4-0.6) con i cerchi delle gocce. `name_filter`/`exclude_filter` scelgono le mesh. |
| `scenes/gocciolatoio.tscn` (WaterDripEmitter) | sul soffitto, sopra pozzanghere e vasche | gocce che cadono e fanno cerchi nel punto esatto in cui cadono (serve una collisione sotto). |
| `scenes/effetto_sottacqua.tscn` (UnderwaterEffect) | figlio della Camera3D del giocatore | nebbia, distorsione e bollicine sott'acqua, gocce sull'obiettivo quando si riemerge. |
| `scenes/effetti_zaino.tscn` (WaterPackFX) | nella scena del giocatore | trova da solo il WaterPack (o imposta `pack`): gorgo e gocce risucchiate dove si aspira, spruzzi e increspature dove colpisce il getto. |
| `scenes/luce_medusa.tscn` (WaterGlowLight) | dentro la campana della medusa | luce rosa che si diffonde nell'acqua (vista da sopra e da sotto). Massimo 4 insieme. |
| `scenes/bocchetta.tscn` (WaterInlet) | sul bordo delle vasche che si riempiono (per esempio le vasche bimbi) | getto che cade nella vasca mentre il livello sale (asse -Z), con schiuma e increspature; funziona anche con `acqua_per_vasca.tscn` quando la WaterTank del gioco si riempie. |
| `scenes/scivolo_acqua.tscn` (SlideWater) | lungo ogni tubo degli scivoli | assegna `curve` (la Curve3D del tubo, coordinate locali) e `tube_radius`: nastro d'acqua che scorre, sale sulla parete nelle curve, schiuma e spruzzi, getto all'uscita. |
| `materials/pavimento_bagnato.tres`, `materials/piastrelle_vasca.tres` | su mesh senza UV (triplanare) | materiali pronti con texture CC0 (ambientCG). |
| `materials/acqua_scivolo_kit.tres` | `material_override` delle strisce `ACQUA_scorre_*` del kit degli scivoli (`scivoli_kit.glb`, `vasca_arrivo.glb`) | acqua che scorre a 6 m/s lungo le UV del kit (UV.x lungo il tubo, 1 = 5 m), schiuma sui bordi. `ACQUA_scorre_bivio_camera` non ha UV: usa `acqua_che_scorre_piano.tres` con `local_flow_dir` = (1, 0). |
| `materials/acqua_che_scorre_piano.tres` | piani d'acqua che scorre, per esempio `FlowingWater.water_material` | il flusso segue il piano XZ locale della mesh: `local_flow_dir` (di serie (0, -1), come `FlowingWater.flow`) e `flow_speed` in m/s. |
| `materials/pozzanghera.tres` | mesh piatte delle pozzanghere (`acqua_pozze_*` degli ambienti interni) | pozza scura a specchio, opaca (la riflette l'SSR di Godot), con i cerchi delle gocce dei gocciolatoi. |
| `scenes/pozzanghera.tscn` (WaterPuddle) | sul pavimento, dove serve una pozzanghera in piu' | genera una pozzanghera di forma irregolare con `pozzanghera.tres`: `size` (m), `irregularity`, `shape_seed`; con `snap_to_floor` si appoggia da sola sulla collisione sotto. |

Gorgo della pozza: WaterTankLink lo disegna da solo sulla superficie (imbuto, schiuma a spirale,
increspature) quando lo scarico della vasca e' aperto, nel centro della vasca piu' `drain_offset`.
Un altro gorgo sovrapposto (per esempio un piano con uno shader a parte) si vede doppio: tenerne uno.

Altri ambienti (segnaposto `ACQUA_*` e `acqua_*`): vasche e nicchie (`ACQUA_vasca_raccolta` della
sala pompe, `ACQUA_nicchia_1..3`, `ACQUA_vasca_arrivo`, `acqua_lavapiedi`) = una `WaterTank` del gioco
con un `acqua_per_vasca.tscn`, oppure un `vasca_acqua.tscn` con le quote dei loro INTEGRAZIONE.md;
strisce `ACQUA_scorre_*` = `acqua_scivolo_kit.tres`; pozzanghere piatte = `pozzanghera.tres`.

### Valori consigliati per la sala principale (revisione di qualita')

Nella build la pozza si leggeva quasi nera e i pavimenti sembravano asciutti. Valori consigliati:

- `PavimentiBagnati` (WetSurfaceConverter dei pavimenti): `base_wetness` circa 0,65,
  `wet_darkening` 0,5, `puddle_amount` 0,6, `puddle_scale` 0,18.
- 8-10 pozzanghere da 1-3 m (`scenes/pozzanghera.tscn`, cioe' `pozzanghera.tres` su una forma
  irregolare che si appoggia da sola sul pavimento): sotto le luci d'emergenza lungo il bordo della
  vasca, davanti ai lettini e intorno al monumento. Con l'SSR acceso riflettono le luci rosse; i
  gocciolatoi ci fanno i cerchi.
- `AcquaPozza`: `planar_reflection_on_high = false` (il valore di serie dell'addon); la pozza prende
  i riflessi con l'SSR dello shader.
- Tutte le vasche della sala: `env_box_max` = (20, 11,5, 20) (con `env_box_min` (-20, -2,5, -24)).
- Pozza e vasche usano gia' i preset aggiornati (pozza grigio-verde con patina, riflessi piu' forti,
  bordo bagnato scuro sul fondo intorno): basta aggiornare la cartella dell'addon.

Coordinate dell'acqua nella sala principale (da `assets_src/ambiente/INTEGRAZIONE.md`):
pozza torbida livello -2,07 (fondo -2,24, scarico in x 0, z 2); vasca d'arrivo -0,22 (fondo -1,10,
x -16..-9, z -3..7); vasca bimbi 1 0,30 (fondo 0,02, x -14,8..-10,4, z -11,2..-8,0); vasca bimbi 2
0,22 (fondo 0,02, x -16,7..-13,9, z -13,8..-11,0).

## Aspetto (preset)

`presets/stile_3_scura.tres` (predefinito per vasche e vasche bimbi: scura e profonda, riflessi
rossi), `presets/stile_2_torbida.tres` (pozza verdastra), `presets/stile_1_limpida.tres`
(alternativa). Si cambia con la proprieta' `style` di WaterBody; i parametri sono in
`scripts/water_style.gd` (tra gli altri: `reflection_strength` e `reflection_stretch` per i riflessi
e le scie verticali delle luci, `turbidity` e `scatter_color` per quanto l'acqua e' torbida e di che
colore, `foam_shore_*` e `scum_amount` per schiuma e patina, `caustics_*`). Il bordo bagnato scuro
sopra il pelo dell'acqua sta nel convertitore (`shoreline_height`, `shoreline_darkening`).
La scelta finale dell'aspetto e' dell'utente.

## Qualita'

`WaterManager.quality = 0 | 1 | 2` (bassa, media, alta; si puo' cambiare in gioco).

| | bassa | media | alta |
|---|---|---|---|
| riflessi | cubemap catturata all'avvio | + SSR nello shader (24 passi) | riflesso planare a meta' risoluzione (solo le vasche con `planar_reflection_on_high`) |
| increspature (texel) | 10 cm | 5 cm | 2,5 cm (max 512 per lato) |
| griglia della superficie | 25 cm | 10 cm | 5 cm |
| caustiche | 1 campione | 2 campioni | dispersione dei colori (4) |
| particelle | 35% | 65% | 100% |
| costo misurato nella sala vera (4 vasche, 960x540) | +8 draw call, +5 mila triangoli | +2 draw call, +32 mila triangoli | la sala viene resa due volte: draw call 373 -> 756, triangoli 1,09 -> 2,02 milioni |

I tempi in millisecondi non sono misurabili qui (Vulkan software su CPU, condiviso con altri
lavori); misura: `godot --path labs/acqua res://tests/sala_vera/test_sala_vera.tscn -- --measure`.
Su GPU vere il riflesso planare e' la voce che pesa di piu': se serve, `planar_reflection_on_high`
solo sulla vasca piu' vista (di serie e' spento).

## Note e limiti

- Le superfici che devono vedersi **sotto** l'acqua devono essere opache (o con alpha scissor):
  l'acqua legge l'immagine della scena opaca.
- Le caustiche e la banda bagnata compaiono solo sui materiali convertiti (WetSurfaceConverter o
  materiali con `wet_surface.gdshader`).
- Il riflesso planare rende di nuovo la scena: tenerlo su una sola vasca (quella in vista piu' spesso).
- Sul renderer software (llvmpipe) una ReflectionProbe insieme a una luce dall'alto con ombre ha
  prodotto pixel NaN nella sala di prova; su GPU vere non e' stato possibile verificarlo qui. Se
  compaiono macchie bianche/nere tremolanti, provare senza ReflectionProbe.
