# Report grafica (branch `lavoro/grafica`)

Ultimo aggiornamento: 14 ottobre 2026. Progetto di prova: `labs/grafica/` (Godot 4.7.2, Forward+). Come integrarlo nel gioco: `labs/grafica/README.md`.

## Cosa è finito

- **Consegna nel gioco**: `godot/addons/grafica/` (README con i passi esatti). Si rigenera dal laboratorio con `labs/grafica/strumenti/esporta_addon.sh`.
- **Look della sala principale vera** (`LookSala` + `sala/ambiente_sala.tres` + `sala/attributi_camera_sala.tres`): in corso i render prima/dopo a 1920×1080.

- **Scena di prova notturna**: sala rotonda con cupola di vetro e costoloni, piscina vuota con pozza, 12 colonne, balconata con ringhiera, corridoio laterale, piedistallo con la base Meshy della medusa (ridotta) e lampione. Geometria semplice, luci e materiali veri (texture CC0 Poly Haven).
- **Opzioni grafiche** (autoload `Grafica`): preset Basso/Medio/Alto/Ultra, salvataggio in `user://settings.cfg`, applicazione immediata.
- **Menu delle opzioni** a 5 schede (Schermo, Resa, Luci e ombre, Immagine, Luminosità) e **calibrazione della luminosità**.
- **Torcia**: fascio con texture (cookie), ombre morbide, ritardo nel seguire lo sguardo, tasto F, sfarfallio a comando, batteria implementata ma spenta.
- **Tempesta**: lampi a più scariche, ombre dei costoloni che si spostano, fulmine visibile nel cielo, nuvole illuminate, vetro bagnato che si accende, segnale `tuono` in ritardo (circa 3 s per km).
- **Neon** (stabili, sfarfallanti, guasti, morenti, spenti), **luci d'emergenza** rosse fisse, pulsanti e rotanti.
- **Nebbia volumetrica** che reagisce alle luci, nebbia bassa sul pavimento, **pulviscolo** illuminato solo dove arriva la luce, **vapore**, **gocce** dal soffitto con schizzo e segnale per il suono, **pioggia** sopra la cupola.
- **Post-processing**: AgX, esposizione, glow, grana, vignettatura, aberrazione cromatica, color grading con LUT 3D generate da codice (4 stili) più contrasto e saturazione.

## Da mostrare all'utente

Tutti in `docs/report/render_grafica/` (presi dal motore, 1280×720, Vulkan software):

| File | Cosa mostra |
|---|---|
| `preset_basso.jpg` / `preset_ultra.jpg` | La sala con il preset Basso e con Ultra (stessa inquadratura, torcia accesa) |
| `torcia_spenta.jpg` / `torcia_accesa.jpg` | Al buio, solo luci d'emergenza: torcia spenta e accesa |
| `torcia_corridoio.jpg` | La torcia nel corridoio al buio (fascio nella nebbia, ombre) |
| `lampo_cupola.jpg` / `lampo_sala.jpg` | Un lampo visto attraverso la cupola e la sala illuminata dal lampo |
| `nebbia_luci.jpg` / `nebbia_corridoio.jpg` | Nebbia volumetrica con le luci d'emergenza e i neon |
| `menu_resa.jpg` / `menu_luci.jpg` / `calibrazione.jpg` | Il menu delle opzioni e la calibrazione della luminosità |
| `lampi_cupola.mp4` (+ `.gif`) | 7 secondi di temporale visto dalla sala |
| `neon_corridoio.mp4` (+ `.gif`) | 6 secondi di neon che sfarfallano e lampeggiante rotante |

## Scelte prese (e perché)

### Illuminazione globale: VoxelGI

| | LightmapGI (precalcolata) | VoxelGI | SDFGI |
|---|---|---|---|
| Costo in gioco | il più basso | medio | alto |
| Luci che cambiano (blackout, neon guasti, lampi, torcia) | **no**: la luce rimbalzata resta "cotta" anche a luci spente | **sì**, in tempo reale | sì |
| Ambienti chiusi e bui | ottima | buona | perde luce attraverso i muri sottili, celle grossolane |
| Preparazione | bake lungo nell'editor (serve GPU) | bake veloce della geometria (1-2 s per la sala) | nessuna |

Il capitolo 1 si basa su luci che cambiano: le pompe accendono tutto e poi fanno saltare la corrente, i neon si guastano, i lampi passano dalla cupola, la torcia è la luce principale. Con LightmapGI il rimbalzo di quelle luci resterebbe nella scena anche a luci spente. Quindi:

- **Alto e Ultra: VoxelGI**, un nodo per zona (massimo 8 visibili insieme), calcolato nell'editor. Il rosso delle luci d'emergenza rimbalza su pavimento e muri e cambia col blackout.
- **Basso e Medio: niente GI**, solo luce ambiente scura (più SSIL su Alto/Ultra per i dettagli vicini).
- **SDFGI** resta come opzione nel menu, ma non è consigliato: costa di più e in sala con muri sottili fa filtrare luce.
- LightmapGI potrà servire più avanti solo per zone con luci che non cambiano mai.

### Riflessi e occlusione

- **ReflectionProbe** per stanza (modalità interno, proiezione a scatola): base per i riflessi su piastrelle e acqua, costo quasi nullo.
- **SSR** da Medio in su per il pavimento bagnato (riflette neon e luci rosse).
- **SSAO** da Medio in su, **SSIL** da Alto in su.

### Ombre

- Le luci hanno una priorità: 0 = sempre (torcia), 1 = importante, 2 = secondaria (neon, lampeggianti). I preset bassi tolgono prima le ombre secondarie.
- Livelli: Minime (solo torcia, ombre dure), Basse, Medie, Alte (filtro morbido medio, 4 cascate), Ultra (atlante 8192, filtro alto).
- La luce del lampo ha ombre a cascate (2 o 4, distanza 25-80 m).

### Upscaling e antialiasing (cosa offre Godot 4.7.2)

- Upscaler: **bilineare, AMD FSR 1.0, AMD FSR 2.2**. MetalFX esiste solo su Mac/iOS. **DLSS e XeSS non ci sono** in Godot (servirebbero estensioni esterne).
- Antialiasing: **FXAA, SMAA, TAA, MSAA 2×/4×/8×**. FSR 2 fa già da antialiasing temporale (al 100% di scala funziona come AA di qualità).
- Preset: Basso = scala 67% + FSR 1 + FXAA; Medio = 77% + FSR 2; Alto = 100% + TAA; Ultra = 100% + FSR 2 come antialiasing.

### Post-processing e immagine

- Tonemap **AgX** fisso (gestisce bene luci rosse sature e neon senza bruciarli).
- Esposizione, contrasto, saturazione, glow, grana, vignettatura, aberrazione cromatica regolabili; color grading "Notte fredda" di default.
- Opzione di accessibilità **"Riduci i lampi"**: lampi più deboli e senza sfarfallio rapido.

### Torcia

- LED leggermente caldo, cono di 30°, texture del fascio con punto caldo, anello del riflettore, alone e piccoli graffi sulla lente.
- Tenuta a destra e in basso rispetto agli occhi, così gli oggetti vicini fanno ombre visibili.
- Segue lo sguardo con un leggero ritardo; la proprietà `disturbo` (0..1) la fa sfarfallare finché il mostro è vicino, `sfarfalla(durata)` dà un colpo singolo.
- Batteria implementata ma **spenta** (`batteria_attiva = false`): è una scelta di design dell'utente.

## Limiti di Godot incontrati

- **Texture del proiettore lette come sRGB**: il cookie della torcia va codificato con gamma 1/2.2, altrimenti l'alone esterno diventa quasi nero (lo fa già lo script che lo genera).
- **Colori `source_color` negli shader** sono sRGB: i colori scuri del cielo vanno scritti più chiari di quanto sembri.
- `environment_set_ssr_roughness_quality` in 4.7 non fa più niente (deprecato): la qualità degli SSR si regola solo con il numero di passi.
- **Qualità delle texture**: Godot non riduce la risoluzione delle texture a runtime. L'opzione usa bias dei mipmap e filtro anisotropico; per risparmiare davvero memoria servirebbero texture importate in due versioni.
- **VoxelGI**: massimo 8 visibili insieme; il bake va fatto nell'editor (a runtime funziona ma blocca 1-2 s).
- Sul rendering software del sandbox ogni immagine 1280×720 richiede 1-3 minuti: i tempi non dicono niente sulle prestazioni vere.

## Prossimi passi per l'integrazione

1. Copiare `labs/grafica/grafica/` in `godot/grafica/` e aggiungere l'autoload `Grafica` (dettagli in `labs/grafica/README.md`).
2. Nel livello vero: un `WorldEnvironment` come quello della sala di prova, `VoxelGI` per zona (bake nell'editor), una `ReflectionProbe` per stanza.
3. Mettere la `Torcia` sulla camera del giocatore e collegare i segnali all'audio (tuono, neon, gocce, clic della torcia).
4. Collegare il menu delle opzioni al menu di pausa e mostrare la calibrazione al primo avvio.
5. Da decidere con l'utente: lo stile del menu, la batteria della torcia, il color grading definitivo.
