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
| `scenes/convertitore_bagnato.tscn` (WetSurfaceConverter) | uno per gruppo di superfici | `roots` = le istanze dei GLB (sala_architettura, sala_piscina, sala_area_bimbi, sala_torre_scivoli). Rimpiazza i materiali con quello bagnabile tenendo le stesse texture: caustiche sott'acqua, banda bagnata sopra il pelo, pozzanghere (`puddle_amount`, per i pavimenti 0.4-0.6) con i cerchi delle gocce. `name_filter`/`exclude_filter` scelgono le mesh. |
| `scenes/gocciolatoio.tscn` (WaterDripEmitter) | sul soffitto, sopra pozzanghere e vasche | gocce che cadono e fanno cerchi nel punto esatto in cui cadono (serve una collisione sotto). |
| `scenes/effetto_sottacqua.tscn` (UnderwaterEffect) | figlio della Camera3D del giocatore | nebbia, distorsione e bollicine sott'acqua, gocce sull'obiettivo quando si riemerge. |
| `scenes/effetti_zaino.tscn` (WaterPackFX) | nella scena del giocatore | trova da solo il WaterPack (o imposta `pack`): gorgo e gocce risucchiate dove si aspira, spruzzi e increspature dove colpisce il getto. |
| `scenes/luce_medusa.tscn` (WaterGlowLight) | dentro la campana della medusa | luce rosa che si diffonde nell'acqua (vista da sopra e da sotto). Massimo 4 insieme. |
| `scenes/bocchetta.tscn` (WaterInlet) | sul bordo delle vasche che si riempiono | getto che cade nella vasca quando si riempie (asse -Z), con schiuma e increspature. |
| `scenes/scivolo_acqua.tscn` (SlideWater) | lungo ogni tubo degli scivoli | assegna `curve` (la Curve3D del tubo, coordinate locali) e `tube_radius`: nastro d'acqua che scorre, sale sulla parete nelle curve, schiuma e spruzzi, getto all'uscita. |
| `materials/pavimento_bagnato.tres`, `materials/piastrelle_vasca.tres` | su mesh senza UV (triplanare) | materiali pronti con texture CC0 (ambientCG). |

Coordinate dell'acqua nella sala principale (da `assets_src/ambiente/INTEGRAZIONE.md`):
pozza torbida livello -2,07 (fondo -2,24, scarico in x 0, z 2); vasca d'arrivo -0,22 (fondo -1,10,
x -16..-9, z -3..7); vasca bimbi 1 0,30 (fondo 0,02, x -14,8..-10,4, z -11,2..-8,0); vasca bimbi 2
0,22 (fondo 0,02, x -16,7..-13,9, z -13,8..-11,0).

## Aspetto (preset)

`presets/stile_3_scura.tres` (predefinito per vasche e vasche bimbi: scura e profonda, riflessi
rossi), `presets/stile_2_torbida.tres` (pozza verdastra), `presets/stile_1_limpida.tres`
(alternativa). Si cambia con la proprieta' `style` di WaterBody; i parametri sono in
`scripts/water_style.gd`. La scelta finale dell'aspetto e' dell'utente.

## Qualita'

`WaterManager.quality = 0 | 1 | 2` (bassa, media, alta; si puo' cambiare in gioco).

| | bassa | media | alta |
|---|---|---|---|
| riflessi | cubemap catturata all'avvio | + SSR nello shader (24 passi) | riflesso planare a meta' risoluzione (solo le vasche con `planar_reflection_on_high`) |
| increspature (texel) | 10 cm | 5 cm | 2,5 cm (max 512 per lato) |
| griglia della superficie | 25 cm | 10 cm | 5 cm |
| caustiche | 1 campione | 2 campioni | dispersione dei colori (4) |
| particelle | 35% | 65% | 100% |

## Note e limiti

- Le superfici che devono vedersi **sotto** l'acqua devono essere opache (o con alpha scissor):
  l'acqua legge l'immagine della scena opaca.
- Le caustiche e la banda bagnata compaiono solo sui materiali convertiti (WetSurfaceConverter o
  materiali con `wet_surface.gdshader`).
- Il riflesso planare rende di nuovo la scena: tenerlo su una sola vasca (quella in vista piu' spesso).
- Sul renderer software (llvmpipe) una ReflectionProbe insieme a una luce dall'alto con ombre ha
  prodotto pixel NaN nella sala di prova; su GPU vere non e' stato possibile verificarlo qui. Se
  compaiono macchie bianche/nere tremolanti, provare senza ReflectionProbe.
