# Report grafica (branch `lavoro/grafica`)

Ultimo aggiornamento: 15 ottobre 2026. Progetto di prova: `labs/grafica/` (Godot 4.7.2, Forward+). Come integrarlo nel gioco: `labs/grafica/README.md`.

## Cosa è finito

- **Consegna nel gioco**: `godot/addons/grafica/` (README con i passi esatti). Si rigenera dal laboratorio con `labs/grafica/strumenti/esporta_addon.sh`.
- **Look della sala principale vera** (`LookSala` + `sala/ambiente_sala.tres` + `sala/attributi_camera_sala.tres`): luci, GI, riflessi, nebbia, lampi e color grading sui GLB veri. Vedi la sezione "Sala principale" qui sotto.

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

## Pezzo campione: luce e immagine degli interni (15 ottobre, da approvare)

L'utente, dopo la v0.2.0: "è tutto offuscato e piatto" e "la torcia è troppo forte". Rifatti su un pezzo campione, da approvare prima del resto: corridoio del risveglio, tornello con la vasca lava-piedi, stanzino.

Screenshot 1600×900 da Godot, stessi punti prima e dopo (preset Alto), in `docs/report/render_grafica/campione/`:

| Inquadratura | Prima | Dopo |
|---|---|---|
| Corridoio dal risveglio | `prima_corridoio.jpg` | `dopo_corridoio.jpg` |
| Tornello con la vasca lava-piedi | `prima_tornello.jpg` | `dopo_tornello.jpg` |
| Dentro lo stanzino | `prima_stanzino.jpg` | `dopo_stanzino.jpg` |
| Corridoio al buio con la torcia | `prima_torcia.jpg` | `dopo_torcia.jpg` |

Cosa rendeva l'immagine "offuscata" e cosa è cambiato:
- **Antialiasing**: il TAA sul preset Alto ammorbidiva tutto. Ora Alto usa **SMAA** (nitido), Ultra **MSAA 4×**, Medio FSR 1 all'85% con nitidezza e SMAA; il TAA resta solo come scelta ("morbido") nel menu.
- **Grana e aberrazione cromatica spente di serie** (si possono riaccendere); vignetta leggera (0,3).
- **Nebbia** degli interni molto più leggera (0,008): aloni attorno alle lampade, nessun velo sull'immagine.
- **Profondità di campo** leggera, solo oltre i 14 m (negli interni quasi non si vede), disattivabile nel menu (Immagine > Profondità di campo).

Profondità e atmosfera invece di "piatto":
- Le luci rosse d'emergenza fanno **pozze raccolte** (raggio 4,2 m, calo rapido) invece di tingere di rosso pareti intere; i neon fanno la luce "di lavoro" fredda, con **ombre morbide**; la lampada sullo zaino è l'unica luce calda.
- **Ombre** in mezzo agli ambienti: zone buie vere tra una pozza di luce e l'altra; luce ambiente fredda minima (blu-verde, come il concept A) perché il buio non sia nero piatto.
- **SSAO** stretto (0,9 m) per gli angoli, **SSIL** a 3 m, **SSR** sul pavimento bagnato, **VoxelGI cotto per stanza** (dati in `godot/scenes/interni/gi/`, circa 10 MB) e le sonde di riflessione che c'erano già.
- AgX con contrasto 1,2 ed esposizione fissa; glow solo sulle lampade.

Torcia rifatta:
- Nuova texture del fascio: punto caldo pieno, anello del riflettore, stacco più scuro, corona larga e debole, bordo che sfuma senza scalino.
- **Bianco caldo** (circa 4000 K), energia 9 ma con calo più lento con la distanza e **attenuazione vicino ai muri**: illumina lontano senza bruciare da vicino.
- Segue lo sguardo con **un po' di inerzia**; nella nebbia è appena accennata.
- **Non illumina la lancia in mano** (strato 2 escluso dalla luce).

Per non intralciare chi rifà modelli e texture degli stessi interni, le luci sono in una scena separata: `godot/scenes/interni/luci_interni.tscn` (istanziata in `interni.tscn`), con lo script `addons/grafica/look_interni.gd`.

**Risultato combinato** con i modelli e le texture nuovi di ambienti-1 (oggetti Meshy, pareti senza "mimetica", piastrelle con le fughe), VoxelGI ricotto sulla geometria nuova: `combinato_corridoio.jpg`, `combinato_tornello.jpg`, `combinato_stanzino.jpg`, `combinato_torcia.jpg`.

Il "disco azzurro" che si vedeva nel tornello era la cornice della finestra del gabbiotto, che sporgeva nel corridoio: ambienti-1 l'ha corretta (4bd815c); `combinato_tornello.jpg` è rifatto con la cornice a filo del muro e il VoxelGI ricotto.

**Approvato dall'utente** ("belle le luci e anche le grafiche").

**Secondo giro** (`giro2_corridoio.jpg`, `giro2_tornello.jpg`, `giro2_stanzino.jpg`, `giro2_torcia.jpg`), con soffitti da nave e usura delle pareti di ambienti-1:
- riflessi delle pozze netti: erano trasparenti e non ricevevano gli SSR (riflettevano solo il VoxelGI, sfocato: le "forme fantasma"); ora sono opache e lucide;
- torcia al buio davvero: GI cotto senza le emissioni delle lampade, scatto con tutte le luci spente;
- neon non più doppi (interni.gd);
- neon a 4,5 e luce ambiente 0,85: con i soffitti nuovi lo stanzino era quasi nero e l'usura delle pareti non si leggeva.

## Sala principale vera: prima e dopo

Scena di prova: `labs/grafica/sala_reale/` con i GLB veri (`strumenti/prepara_sala_reale.sh` li copia e li importa con lo script di post-import). Consegna: `godot/addons/grafica/look_sala.gd` + `godot/addons/grafica/sala/*.tres` (passi nel README dell'addon).

Screenshot 1920×1080 in `docs/report/render_grafica/sala_reale/` (prima = `sala_luci_ambiente.gd`, dopo = `LookSala`, preset Ultra):

| Inquadratura | Prima | Dopo |
|---|---|---|
| Ingresso dal vano sud, statua sul monumento | `prima_ingresso.jpg` | `dopo_ingresso.jpg` |
| Monumento da vicino | `prima_monumento.jpg` | `dopo_monumento.jpg` |
| Piscina | `prima_piscina.jpg` | `dopo_piscina.jpg` |
| Area bimbi | `prima_area_bimbi.jpg` | `dopo_area_bimbi.jpg` |
| Cima della torre | `prima_torre.jpg` | `dopo_torre.jpg` |

In più: `dopo_lampo_ingresso.jpg` (un lampo). `dopo_sdfgi_piscina.jpg` e `dopo_senza_gi_piscina.jpg` (confronto della GI) sono ancora della sala prima dell'allungamento. Sala allungata (muro sud a z = 20) con il monumento; la statua è la medusa vera del gioco, alta 4,5 m.

Cosa cambia nel "dopo":
- **Colore come il concept A**: emergenze rosse più profonde e più forti (alcune pulsano), neon freddi verso il verde, ambiente e ombre verso il blu-verde (color grading "Notte fredda"), luce calda solo dal lampione e dall'area bimbi per il contrasto.
- **AgX** con contrasto 1,3 ed esposizione fissa (niente esposizione automatica: la sala deve restare buia).
- **VoxelGI** su tutta la sala (rimbalzo del rosso su pavimento e muri, cambia col blackout), **due ReflectionProbe** (sala e piscina, modalità interno) a intensità ridotta, **SSR** sulle pozzanghere, SSAO e SSIL.
- **Nebbia volumetrica** leggera che prende i coni delle luci, più una nebbia bassa con rumore sul pavimento e nella piscina.
- **Luna senza penombra**: con il diametro angolare realistico (0,6°) le ombre dei costoloni sottili sparivano dal pavimento; a 0° tornano le strisce sul pavimento e nella piscina.
- Lampi dalla cupola, pulviscolo, gocce; neon "a metà" che sfarfallano, sono guasti o morenti.
- **Statua**: fari dall'alto e davanti (5,5), faretti caldi dal basso (0,6), controluce freddo da dietro, lampione abbassato (3,5): entrando dal vano è la cosa più leggibile della sala, senza bruciare il vinile.
- **Difetto trovato nella medusa**: `medusa_tentacoli.tres` non ha `emission_operator = Multiply` (il GLB sì). Con "Add" i tentacoli escono bianchi: era questo il "bruciato" visto dall'integratore. Segnalato al coordinatore.

GI per la sala vera:
- **VoxelGI** resta la scelta: costo moderato, segue le luci che cambiano.
- **SDFGI** (immagine apposta): funziona ma con muri e gallerie sottili fa filtrare luce e costa di più.
- **LightmapGI**: la UV2 si genera già all'import (`meshes/light_baking = Static Lightmaps` nello script di preparazione), ma il bake si fa solo dall'editor con la GPU: nel sandbox (rendering software, senza editor interattivo) non è stato possibile cuocerlo. Resta comunque sconsigliato come GI principale, perché il capitolo spegne e riaccende le luci della sala.

### Revisione di qualità (15 ottobre, notte)

Correzioni chieste dalla revisione sugli scatti Ultra, controllate con `sala_reale/dopo_ingresso_revisione.jpg`:
- **Campo visivo** di serie 62° verticali (circa 92° orizzontali); cursore da 50 a 90 che mostra anche i gradi orizzontali.
- **Torcia**: energia 11 (prima 28) e attenuazione vicino ai muri: un raggio di 3 m davanti e luce × clamp(distanza / 2,5; 0,4; 1).
- **Luna** più debole (0,3) e morbida (1,3°, opacità dell'ombra 0,75): la "ragnatela" netta dei costoloni compare solo durante il lampo.
- **Esposizione**: luce ambiente 0,7, contrasto AgX 1,15, vignetta 0,3, nebbia volumetrica 0,015 con anisotropia 0,3 (fasci visibili anche di lato), nebbia bassa 0,04.
- **Cielo** della cupola più chiaro, nuvole più contrastate. L'orizzonte del mare non c'è: dalla sala si vede solo il cielo sopra la cupola.
- **Scheda Controlli** nel menu: sensibilità del mouse, inverti Y, oscillazione della camera (in `settings.cfg`, chiavi `sensibilita_mouse`, `inverti_y`, `oscillazione_camera`: le legge il controller del giocatore).
- FPS: sul rendering software del sandbox non sono misurabili. La nebbia più densa non cambia il costo (dipende dalla dimensione del volume, non dalla densità).

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
- **TAA e FSR 2 con particelle minuscole molto luminose**: diventano puntini neri. Il pulviscolo è su uno strato che la luce del lampo non illumina (`Tempesta.STRATO_NO_LAMPO`).
- **Ombre direzionali morbide (PCSS)**: con il diametro angolare del sole/luna > 0 le ombre di oggetti sottili e alti (costoloni della cupola) spariscono.
- Sul rendering software del sandbox ogni immagine 1280×720 richiede 1-3 minuti: i tempi non dicono niente sulle prestazioni vere.

## Prossimi passi per l'integrazione

1. Copiare `labs/grafica/grafica/` in `godot/grafica/` e aggiungere l'autoload `Grafica` (dettagli in `labs/grafica/README.md`).
2. Nel livello vero: un `WorldEnvironment` come quello della sala di prova, `VoxelGI` per zona (bake nell'editor), una `ReflectionProbe` per stanza.
3. Mettere la `Torcia` sulla camera del giocatore e collegare i segnali all'audio (tuono, neon, gocce, clic della torcia).
4. Collegare il menu delle opzioni al menu di pausa e mostrare la calibrazione al primo avvio.
5. Da decidere con l'utente: lo stile del menu, la batteria della torcia, il color grading definitivo.
