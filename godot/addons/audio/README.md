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
| `PoweredDoor` | motore (o saracinesca, se sale in verticale), colpo a fine corsa | `open_amount`, `opened`, `closed` |
| `HingedHatch` | portello che cigola e sbatte | `opened` |
| `PiscinaOnde` | colpo del faro quando, a piscina vuota, il pulsante della botola si accende (tappa 5; per ora suoni già approvati) | `pulsante_attivato` |
| `WaterTank` | gorgoglio dello scarico (sul gorgo `DrainVortex`), vasca svuotata (anche quando la si svuota aspirando con lo zaino), riempimento | `is_draining()`, `emptied`, `fill_sources` |
| `FlickerLight` | colpo del faro che si accende e ronzio che segue la luce | `is_on`, `light` |
| `MedusaStatue` | respiro umido appena udibile da vicino; risveglio | animazione `sveglia` |
| scena con `jingle_button` e `statue` (sala principale) | la **sigla rovinata** dal piedistallo | `pressed` del pulsante |
| `KidSighting` | stinger dei bambini sulla balconata | `seen` |
| `PackPickup` | zaino preso (cinghie, fibbia, pompate) | `interacted` |
| `PolaroidPhoto`, `Collectible` | foto raccolta (suona anche col gioco in pausa); visore che si chiude | `interacted` |
| `GameState` (autoload) | stinger di morte, mondo che si abbassa, ritorno alla ripartenza; se ti prende lei (causa `&"medusa"`) il morso subito e lo stinger quando la fauce si chiude | `player_died`, `player_respawned` |
| `DeathSequence` | lo stinger sfuma se la scena viene saltata | `finished` |
| `Game` (autoload) | clic di pausa e ripresa | `paused_changed` |
| `MenuOpzioni` (grafica) | aggiunge la scheda **Audio** con i cursori | - |
| pulsanti, scelte e cursori dei menu | clic | `pressed`, `item_selected`, `value_changed` |
| luci del GLB della sala `luce_neon_*`, `luce_emergenza_*` | ronzio sulle 4 (neon) e 3 (emergenza) più vicine, clic e qualche scintilla quando sfarfallano | visibilità della luce |
| `MonitorCrt` (tappa 6) | fruscio della neve dal tubo, sullo schermo | `mostra_neve_attiva()` |
| `Paratia` (tappa 6) | motore e catene mentre scende (sul pannello), colpo sordo in fondo | `in_movimento`, `chiusa` |
| `LeiSbuca` (tappa 8) | la fossa che ribolle mentre l'acqua risale nelle vasche basse; tace quando lei va sotto | `fill` delle `vasche`, `fase`, `abilitata` |

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

## Tappe 5-6: sala pompe e risveglio

Suoni in `res://audio/tecnici/`. Il monitor e le paratie si collegano da soli (tabella sopra); il
resto lo suona `scripts/tecnici/risveglio_sala_pompe.gd` con l'API, con questi nomi:

| Suono | Cosa | Come |
|---|---|---|
| `pompe_ruggito_loop` | una pompa industriale a regime, ruggito basso (tre pompe = tre loop) | `crea_loop(&"pompe_ruggito_loop", pompa)`; `tono` 0,65 = appena partita, 0,95 = ruggisce |
| `pompa_avvio` | teleruttore che scatta e la pompa che prende giri (3,4 s) | `suona(&"pompa_avvio", pompa.global_position)` |
| `corrente_salta` | gli interruttori che saltano, arco, il ronzio di tutta la nave che muore (stereo) | `suona(&"corrente_salta")` |
| `crt_neve_loop` | neve del vecchio monitor a tubo | da solo (`MonitorCrt`) |
| `plastica_piega_lontano` | plastica grande che si piega a lungo, lontano e riverberato: è lei (12 s, stereo) | `suona(&"plastica_piega_lontano", punto_lontano)` |
| `tonfo_acqua_lontano` | un tonfo pesante in acqua, lontano (6 s, stereo) | `suona(&"tonfo_acqua_lontano", punto_lontano)` |
| `paratia_scende_loop` | paratia d'acciaio che scende: motore, catene, guide | da sola (`Paratia`) |
| `maniglione_bloccato` | maniglione antipanico spinto, ma la porta non si apre | `suona(&"maniglione_bloccato", porta.global_position)` |
| `porta_ponte_apre` | lo stesso maniglione che si sblocca, porta pesante che si apre | `suona(&"porta_ponte_apre", porta.global_position)` |

I due suoni lontani hanno già dentro la distanza (passa-basso e riverbero): in 3D danno solo la
direzione (`unit_size` 40), così si sentono anche dalla sala pompe, sotto il ruggito.

## Tappa 8: lei nell'area bimbi

Suoni in `res://audio/lei/`. Lei non parla (niente parole né voce umana), ma si sente la sua gola:
è la versione gutturale scelta dall'utente il 16 ottobre (la prima, solo acqua e pelle, è in
`assets_src/audio/scartati/lei_v1/`). La fossa e il morso li suona l'addon da solo; lei che sbuca e
che scivola sotto li chiama `scripts/game/lei_sbuca.gd` (`_suona()`).

| Suono | Cosa | Come |
|---|---|---|
| `fossa_ribolle_loop` | gorgoglio profondo dal condotto, bolle grosse: l'acqua che risale e riempie le vasche basse | da solo (`LeiSbuca`) |
| `lei_sbuca` | sale gorgogliando di gola sott'acqua, l'acqua che le cola di dosso, le mani bagnate sul bordo, un respiro profondo e umido; poi, affacciata, un rantolo trattenuto fino a quando va sotto (7,6 s) | `_sbuca()`: `_suona(&"lei_sbuca")` |
| `lei_scivola_sotto` | un brontolio di gola, le mani che scivolano dal bordo, il risucchio, l'ultimo fiato che gorgoglia sott'acqua sempre più giù, poi silenzio (4,5 s) | `_scivola()`: `_suona(&"lei_scivola_sotto")` |
| `morso` | lo scatto con un risucchio d'aria tra i denti, un ringhio che cresce mentre la pelle si strappa sotto l'occhio, la fauce che si chiude a 1,0 s col fiato spinto fuori, un gorgoglio che mastica (stereo, 1,8 s) | da solo, alla morte con causa `&"medusa"` |

Il morso suona sul bus Interfaccia (da vicino, niente riverbero, non si abbassa con la morte); la
fauce si chiude a `MORSO_COLPO` = 1,0 s, il lampo rosso di `DeathSequence`, e lì parte lo stinger.

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
aspirazione, pulsante, sigla, faro), monitor e paratie della sala pompe, la fossa e il morso della
tappa 8, i nomi dei suoni chiesti dagli script (devono esistere nel catalogo), pausa, menu, morte e
ripartenza, nessun errore.

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

Rigenera tutti gli OGG (deterministici), `catalogo.gd`, `res://audio/LICENZE.md` e le anteprime
`res://audio/anteprima/anteprima_audio.ogg`, `anteprima_tecnici.ogg` e `anteprima_lei.ogg` (cartella
con `.gdignore`: non entra nel gioco). Le proposte per l'utente non sono nel gioco: le loro anteprime
(`anteprima/proposta_*.ogg`) le fanno `genera_lei.py` con `genera_anteprima.py proposte` e
`genera_proposte.py`.
`assets_src/audio/verifica.py file.ogg --png cartella` stampa loudness e picchi e disegna lo
spettrogramma.
