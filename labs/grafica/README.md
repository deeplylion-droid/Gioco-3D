# Laboratorio grafica

Progetto Godot 4.7.2 (Forward+) separato dal gioco, per provare luci, torcia, effetti ambientali e opzioni grafiche. Il codice riutilizzabile sta tutto in `grafica/`; `scena/` contiene solo la sala di prova.

- Aprire: `godot --path labs/grafica` (scena principale `scena/sala_prova.tscn`).
- Comandi nella sala di prova: WASD, Shift per correre, mouse, **F** torcia, **Esc** menu delle opzioni.
- Report con screenshot e scelte: `docs/report/grafica.md`.

## Cosa c'è in `grafica/`

| File | Cosa fa |
|---|---|
| `impostazioni_grafiche.gd` | **Autoload `Grafica`**: impostazioni, preset Basso/Medio/Alto/Ultra, salvataggio in `user://settings.cfg`, applicazione immediata a finestra, viewport, Environment, luci, VoxelGI, particelle e post-processing. |
| `post_processing.gdshader` | Passaggio finale: grana, vignettatura, aberrazione cromatica, gamma della calibrazione. Lo crea l'autoload (CanvasLayer 50). |
| `menu_opzioni.gd` | `MenuOpzioni`: menu delle opzioni grafiche costruito da codice (stile neutro, da decidere). |
| `calibrazione_luminosita.gd` | `CalibrazioneLuminosita`: schermata "il simbolo di sinistra si vede appena". |
| `torcia.gd` + `texture/torcia_cookie.png` | `Torcia`: fascio con texture, ombre morbide, ritardo nel seguire lo sguardo, tasto F, sfarfallio, batteria (spenta di default). |
| `tempesta.gd` + `cielo_tempesta.gdshader` | `Tempesta`: lampi con ombre che si spostano, fulmine nel cielo, segnale `tuono` in ritardo. |
| `vetro_cupola.gdshader` | Vetro della cupola con rivoli di pioggia; si accende col lampo. |
| `neon.gd` | `Neon`: lampade stabili, che sfarfallano, guaste, morenti o spente (luce ad area `AreaLight3D`). |
| `luce_emergenza.gd` | `LuceEmergenza`: luce rossa fissa, pulsante o rotante. |
| `pulviscolo.gd`, `vapore.gd`, `gocce.gd`, `punteggio_morbido.gd` | Polvere nell'aria, vapore (particelle + FogVolume), gocce dal soffitto con schizzo. |

## Come portarlo nel gioco (`godot/`)

1. **Copiare** la cartella `labs/grafica/grafica/` in `godot/grafica/` (stessi percorsi `res://grafica/...`).
2. **Autoload**: in `project.godot`, sezione `[autoload]`:
   ```
   Grafica="*res://grafica/impostazioni_grafiche.gd"
   ```
   Va caricato prima degli altri script che lo usano (`Tempesta`, `Vapore`, `Torcia` tramite le luci).
3. **Input**: l'autoload crea da solo le azioni `torcia` (F) e `menu_opzioni` (Esc) se non esistono. Se il gioco le definisce già in `project.godot`, vengono usate quelle.
4. **Impostazioni di progetto consigliate** (`[rendering]`):
   ```
   lights_and_shadows/directional_shadow/size=4096
   lights_and_shadows/positional_shadow/atlas_size=4096
   anti_aliasing/quality/use_debanding=true
   environment/volumetric_fog/use_filter=1
   ```
5. **Environment del livello**: il `WorldEnvironment` lo prepara chi fa il livello (vedi `_crea_ambiente()` in `scena/sala_prova.gd` come riferimento: AgX, nebbia volumetrica, SSR/SSAO/SSIL accese). L'autoload **non** cambia i valori artistici: accende e spegne gli effetti secondo le opzioni e moltiplica esposizione, contrasto e saturazione.
   - Se un effetto è spento nell'Environment del livello, resta spento anche con le opzioni al massimo.
   - Con "Nebbia: semplice" la nebbia volumetrica viene sostituita da una nebbia di profondità dello stesso colore.
6. **Giocatore**: aggiungere un nodo `Torcia` come figlio della `Camera3D`:
   ```gdscript
   var torcia := Torcia.new()
   camera.add_child(torcia)
   mostro.vicino.connect(func(d): torcia.disturbo = clampf(1.0 - d / 8.0, 0, 1))  # esempio
   torcia.accesa_cambiata.connect(func(_a): $Clic.play())
   ```
   Batteria: `torcia.batteria_attiva = true` (spenta di default: è una scelta di design aperta).
7. **Menu**: dal menu di pausa
   ```gdscript
   var layer := CanvasLayer.new(); layer.layer = 100
   var m := MenuOpzioni.new(); layer.add_child(m); add_child(layer)
   m.chiuso.connect(layer.queue_free)
   ```
   Al primo avvio, se `Grafica.valore("calibrato")` è `false`, mostrare `CalibrazioneLuminosita.new()`.
8. **Luci della scena**: nessuna configurazione obbligatoria. Opzionale, per decidere chi perde l'ombra sui preset bassi: `luce.set_meta("grafica_priorita_ombra", 0)` (sempre), `1` (importante, predefinito), `2` (secondaria).
9. **VoxelGI**: i nodi `VoxelGI` del livello vanno **calcolati nell'editor** (pulsante Bake) e salvati. Se non hanno dati, l'autoload li calcola all'avvio (1-2 s, va bene solo per le prove). L'autoload li mostra o nasconde secondo l'opzione "Illuminazione globale".
10. **Particelle**: i nodi `Pulviscolo`, `Vapore` e quelli nel gruppo `grafica_particelle` seguono l'opzione "Particelle".
11. **Audio**: collegare i segnali `Tempesta.tuono(intensita, distanza_km)`, `Tempesta.lampo`, `Neon.acceso_cambiato`, `Neon.scintilla`, `LuceEmergenza.stato_cambiato`, `Gocce.goccia_caduta(posizione)`, `Torcia.accesa_cambiata`.

## Strumenti

- `strumenti/render_report.sh [nomi...]`: rigenera gli screenshot e i video del report (xvfb + Vulkan software).
- `strumenti/genera_cookie_torcia.py`: rigenera la texture del fascio della torcia.
- `strumenti/riduci_statua.py`: versione leggera della base Meshy della medusa, solo per questa scena.
- `scena/cattura.gd`: regia per le catture, con argomenti dopo `--` (vedi l'inizio del file).

Texture della sala: Poly Haven (CC0): `anti_skid_tiles`, `long_white_tiles`, `peeling_painted_wall`, `concrete_floor_painted`, `green_metal_rust`.
