# addons/audio

Tutto il suono di Splash Lagoon: fondi della sala, tuoni, nave, gocce, neon e luci d'emergenza,
passi, zaino-pompa, torcia, meccanismi, Polaroid, la sigla della mascotte (pulita e rovinata),
stinger di morte e dei bambini, filtro sott'acqua, volumi e pannello delle opzioni.

I suoni sono in `res://audio/` (OGG Vorbis, mono quelli posizionati, stereo fondi e musica):
fonti e licenze in `res://audio/LICENZE.md`, script che li generano in `assets_src/audio/`.

## Integrazione: una riga

In `project.godot`, sezione `[autoload]`, dopo `GameState`:

```
Audio="*res://addons/audio/audio.gd"
```

(Sul branch `lavoro/audio` la riga c'è già.) Non serve altro: l'autoload crea i bus, carica i
volumi e, a ogni cambio di scena, trova da solo i nodi che conosce e si collega ai loro segnali.
Gli script del gioco e degli altri addon non vanno toccati.

## Bus

```
Master  <- Mondo <- Musica, Ambiente, Effetti
Master  <- Interfaccia            (menu e Polaroid; segue il volume degli Effetti)
```

- **Effetti**: riverbero lungo della sala piastrellata (AudioEffectReverb).
- **Mondo**: passa-basso che si chiude sott'acqua (600 Hz) e in pausa (900 Hz, solo i fondi
  continuano: il resto del mondo è in pausa).
- **Master**: limitatore (AudioEffectHardLimiter).

Se il progetto ha già bus con questi nomi (un `default_bus_layout.tres`), usa quelli.

## Cosa collega da solo

| Nodo (class_name) | Suoni | Da dove |
|---|---|---|
| `Tempesta` (grafica) | tuono vicino (< 1,3 km) o lontano, volume dall'intensità | segnale `tuono` (già ritardato) |
| `Neon` (grafica) | ronzio che segue `livello`, clic, scintille | `acceso_cambiato`, `scintilla` |
| `LuceEmergenza` (grafica) | ronzio (PULSANTE segue la luce), motorino del ROTANTE | `modalita` |
| `Gocce` (grafica) | "plic" nel punto esatto | `goccia_caduta` |
| `Torcia` (grafica) | clic acceso/spento | `accesa_cambiata` |
| `UnderwaterEffect` (acqua) | filtro e fondo sott'acqua, tuffo, riemersione | `entered_water`, `exited_water` |
| `WaterDripEmitter` (acqua) | "plic" delle gocce | gocce che spariscono (non ha segnali) |
| `WaterInlet` (acqua) | scroscio mentre versa | particelle accese |
| `SlideWater` (acqua) | acqua nel tubo, nel punto più vicino a chi ascolta | `curve` |
| `WetSurfaceConverter` (acqua) | i passi sul pavimento "generico" diventano bagnati | presenza nella scena |
| `Player` | passi per superficie, atterraggi, salto, sciabordio nel serbatoio | `footstep`, `landed`, `jumped` |
| `WaterPack` | getto e aspirazione in loop, impatto del getto (3D, sul punto colpito), ricarica, serbatoio pieno/vuoto, pompata | segnali + `flow`, `has_hit`, `hit_point`, `tank_amount` |
| `WaterButton` | "ciunk" e campanello giocattolo, rilascio | `pressed`, `released` |
| `Turbine` | loop che segue `energy` (tono e volume); colpi se è bloccata | `energy`, `jet_hit` dello zaino |
| `StuckInflatable` | squittio della gomma quando il getto lo colpisce, sblocco e tonfo nella pozza | `released`, `jet_hit` |
| `PoweredDoor` | motore (o saracinesca, se sale in verticale), colpo a fine corsa | `open_amount`, `opened`, `closed` |
| `HingedHatch` | portello che cigola e sbatte | `opened` |
| `BucketWheel` | ruota a pale, secchio che si ribalta e torna, ruota del cancello, cancello, quadro in corto | segnali + `angular_speed` |
| `WaterTank` | gorgoglio dello scarico (sul gorgo `DrainVortex`), vasca svuotata, riempimento | `is_draining()`, `emptied`, `fill_sources` |
| `FlickerLight` | colpo del faro che si accende e ronzio che segue la luce | `is_on`, `light` |
| `MedusaStatue` | respiro umido appena udibile da vicino; risveglio | animazione `sveglia` |
| scena con `jingle_button` e `statue` (sala principale) | la **sigla rovinata** dal piedistallo | `pressed` del pulsante |
| `KidSighting` | stinger dei bambini sulla balconata | `seen` |
| `PackPickup` | zaino preso (cinghie, fibbia, pompate) | `interacted` |
| `PolaroidPhoto`, `Collectible` | foto raccolta (suona anche col gioco in pausa); visore che si chiude | `interacted` |
| `GameState` (autoload) | stinger di morte, mondo che si abbassa, ritorno alla ripartenza | `player_died`, `player_respawned` |
| `DeathSequence` | lo stinger sfuma se la scena viene saltata | `finished` |
| `Game` (autoload) | clic di pausa e ripresa | `paused_changed` |
| `MenuOpzioni` (grafica) | aggiunge la scheda **Audio** con i cursori | - |
| pulsanti, scelte e cursori dei menu | clic | `pressed`, `item_selected`, `value_changed` |
| luci del GLB della sala `luce_neon_*`, `luce_emergenza_*` | ronzio sulle 4 (neon) e 3 (emergenza) più vicine, clic e qualche scintilla quando sfarfallano | visibilità della luce |

Intorno al giocatore, a caso: gemiti e scricchiolii metallici della nave, ticchettii delle
lamiere, colpi lontani di porte stagne e, di rado, l'allarme generale lontano. I fondi (pioggia
sulla cupola, vento, nave) suonano pieni dove c'è una `Tempesta`, attenuati altrove.

`Audio.collegati` dice cosa ha trovato (tipo -> quanti nodi), `Audio.conteggio` quante volte è
partito ogni suono.

### Superfici dei passi

Il giocatore passa la superficie col segnale `footstep`: meta `superficie` sul collider
(`&"metallo"`, `&"lamiera"`, `&"grata"` -> lamiera; `&"acqua"`, `&"scala"`), altrimenti piastrelle.
Bagnate se il collider ha il meta `bagnato`, se si è in una `WetZone` o se nella scena c'è un
`WetSurfaceConverter` (la sala principale). `Audio.pavimento_bagnato = true` le forza bagnate.

## La sigla e la campana

`sigla_rovinata` è a 96 BPM, cioè 1,6 battiti al secondo come `MedusaStatue.pulse_rate`. Quando il
getto preme il pulsante del piedistallo, la sigla parte dall'altoparlante (suono 3D sul pulsante)
aspettando il picco della pulsazione della campana: battiti e luce coincidono. È la stessa musica
della `sigla_pulita` (120 BPM, per il titolo) passata su un nastro rallentato con wow e flutter,
denti del carillon storti, accordi che scivolano nel minore e il meccanismo che alla fine si scarica.

## API

```gdscript
Audio.suona(&"neon_scintilla", posizione)        # Vector3, un Node3D da seguire, o null (non posizionale)
Audio.suona(&"tuono_vicino", null, -3.0, 0.9)     # volume in dB e tono
Audio.suona_sigla($Statua/PulsanteSigla, $Statua/Medusa)
Audio.musica_titolo()                             # la sigla pulita, per la schermata del titolo
Audio.ferma_musica(1.5)
Audio.ferma_tutto()                               # per esempio uscendo al menu principale
Audio.imposta_volume("musica", 0.7)               # generale, musica, ambiente, effetti (0..1)
Audio.volume("effetti")
Audio.volume_cambiato.connect(func(chiave, valore): ...)
```

I nomi dei suoni (con le varianti) sono in `catalogo.gd`, generato. Taratura (bus, volume, distanze
3D, variazione di tono) in cima ad `audio.gd`: `TARATURA`, `LOOP_3D`, `FONDI`. Opzioni:
`pavimento_bagnato`, `suoni_interfaccia`, `inietta_nel_menu`, `eventi_casuali`.

## Volumi e pannello

I volumi sono in `user://settings.cfg`, sezione `[audio]` (`generale`, `musica`, `ambiente`,
`effetti`, da 0 a 1); le altre sezioni (grafica) restano. Il pannello con i cursori è
`pannello_audio.tscn` (classe `PannelloAudio`): l'autoload lo aggiunge già come scheda "Audio" al
menu delle opzioni dell'addon grafica; per un altro menu:

```gdscript
contenitore.add_child(preload("res://addons/audio/pannello_audio.tscn").instantiate())
```

Lasciando un cursore parte un suono di prova sul suo bus (anche col gioco in pausa).

## Test

`tests/test_audio.gd` (anche nella CI): bus ed effetti, tutti gli stream del catalogo, volumi su
disco, collegamenti con la sala principale e suoni che partono davvero (tuono, passi, getto,
aspirazione, pulsante, sigla, faro), pausa, menu, morte e ripartenza, nessun errore.

```
godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_audio.gd
```

Con il driver audio "Dummy" (headless) i suoni non partono davvero, così all'uscita non restano
riproduzioni appese; lo stato resta giusto. Il test forza la riproduzione vera con
`AudioLoop.forza_riproduzione(true)` e ferma tutto prima di uscire.

## Rigenerare i suoni

```
/home/user/tools/blender-venv/bin/python assets_src/audio/genera_tutto.py
```

Rigenera tutti gli OGG (deterministici), `catalogo.gd`, `res://audio/LICENZE.md` e l'anteprima
`res://audio/anteprima/anteprima_audio.ogg` (cartella con `.gdignore`: non entra nel gioco).
`assets_src/audio/verifica.py file.ogg --png cartella` stampa loudness e picchi e disegna lo
spettrogramma.
