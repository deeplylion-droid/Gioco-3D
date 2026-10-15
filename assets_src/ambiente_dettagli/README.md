# Kit di dettagli per la sala principale

Detriti, cavi, tubi e condotte da muro, bocchette, cassette elettriche, corpi lampada, cartelli con soli disegni, alghe secche e incrostazioni, catene e corde. Servono a dare più dettaglio alla sala dell'acquapark (`assets_src/ambiente/`): stessi materiali e stessa palette (`sala_a`) del kit della sala, texture PBR 2K.

Tutto si rigenera dagli script `tools/blender/dettagli_*.py`:

```bash
PY=/home/user/tools/blender-venv/bin/python
MESHY_API_KEY=... python3 tools/blender/dettagli_meshy.py     # 8 piccoli oggetti (giocattoli, ciabatta): solo se mancano
$PY tools/blender/dettagli_texture.py      # CC0 2K da ambientCG + texture derivate (cartelli, macchie, asciugamani...)
$PY tools/blender/dettagli_kit.py          # i GLB del kit e catalogo.json
$PY tools/blender/dettagli_posiziona.py    # posizionamento.json (raycast sui GLB della sala) [--render]
$PY tools/blender/dettagli_vetrina.py      # render della vetrina [--anteprima]
```

## File

- `glb/<categoria>.glb`: un GLB per categoria (detriti, cavi, tubi, elettrico, lampade, cartelli, organico, catene_corde), ognuno sotto i 50 MB. Texture incorporate (JPG; PNG solo per le macchie con l'alfa).
- `gltf/<categoria>.gltf` + `.bin`, con le texture in **una sola cartella `gltf/texture/` deduplicata per contenuto** (79 file, 92 MB, contro i 145 MB dei GLB che ripetono le texture). È la versione da usare nella build: `dettagli_sala.gd` la usa di serie (`usa_gltf = true`). Si rifà con `dettagli_kit.py` e poi `gltf_condividi.py assets_src/ambiente_dettagli/gltf`.
- `catalogo.json`: tutti i nodi, con categoria, appoggio, ingombro e triangoli.
- `posizionamento.json`: **1219 posti in 457 gruppi** nella sala lunga (con il monumento), in coordinate Godot, con il riepilogo di triangoli e istanze.
- `godot/dettagli_sala.gd`: lo script che li monta (MultiMeshInstance3D per i nodi ripetuti). `godot/foto_dettagli.gd`: la scena di prova degli screenshot prima/dopo.
- `texture/`: CC0 nuove (`cc0/`) e derivate (`derivate/`). Le altre texture vengono dal kit della sala (`assets_src/ambiente/textures/`).

## Convenzioni

- Ogni dettaglio è un **nodo radice `det_*`**. Nel GLB i nodi sono messi in fila (per vederli), ma conta solo la loro origine: in Godot si prende il nodo e gli si dà la trasformazione del file di posizionamento.
- **Appoggio** e origine:
  - `pavimento`: origine alla base, al centro;
  - `muro`: origine sul filo del muro; il dettaglio sporge verso **+Z locale** in Godot (-Y in Blender). I pezzi lunghi (tubi, condotte, festoni) partono dall'origine e vanno lungo +X;
  - `soffitto`: origine nel punto d'attacco, l'oggetto pende verso -Y.
- **Materiali** `M_det_*`. Accesi o spenti si cambia il materiale: `M_det_neon_acceso` / `M_det_neon_spento`, `M_det_vetro_rosso_acceso` / `M_det_vetro_rosso_spento`, `M_det_faro_vetro_acceso`. I dettagli non hanno luci: se un neon o una luce d'emergenza deve illuminare, si aggiunge una luce in Godot.
- **Macchie** (`det_macchia_*`): sono piani con l'alfa (alpha blend; in Godot va bene anche alpha scissor o un nodo Decal con la stessa texture PNG). Stanno 3 mm sopra la superficie.
- **Niente collisioni**: sono dettagli decorativi e leggeri. Se ne serve qualcuna (quadro elettrico, mucchi di piastrelle), basta una scatola.
- I LOD li genera Godot all'import.

## Come montarli in Godot

Attaccare `godot/dettagli_sala.gd` a un `Node3D` in (0, 0, 0) accanto ai GLB della sala e impostare `cartella` (dove stanno `glb/` e `posizionamento.json`). Lo script:
- raggruppa i posti per nodo: i nodi con almeno 6 istanze diventano un **MultiMeshInstance3D** (un draw call per superficie), gli altri sono copie normali;
- spegne le ombre dei dettagli e nasconde i pezzi piccoli (fogli, piastrelle, giocattoli, macchie, alghe) oltre 30 m (`visibility_range_end`).

**Numeri** (riepilogo in `posizionamento.json`): 1219 posti, 87 nodi diversi, 66 MultiMesh con 1153 istanze, 66 copie singole; **573,630 triangoli** in tutto (prima dei LOD e della distanza di visibilità).
Misurati in Godot 4.7.2 (Forward+, 1600x900): dallo spawn i draw call passano da 158 a 324 e le primitive da 774 mila a 868 mila; guardando un muro laterale da 54 a 201 draw call e da 390 a 468 mila primitive.

**Come sono messi.** Sempre a **gruppi**, controllati con dei raggi sulla geometria vera della sala:
- mucchi di detriti (un pezzo grosso, piastrelle, carte, vetri, pannelli caduti, giocattoli) negli angoli, alla base dei muri e negli 8 m nuovi vicino al vano sud;
- corse di tubi e condotte una dopo l'altra lungo i muri, con le colature di ruggine sotto; incrostazioni continue alla base delle pareti;
- angoli tecnici (quadro o cassetta, interruttore, tubo che sale, cartello, macchie); più cartelli a pittogrammi;
- fasci di cavi a festone lungo i muri sotto la galleria; plafoniere spente o penzolanti con cavi e catene intorno e i vetri caduti sotto;
- alghe secche e calcare a tratti lungo il bordo della piscina; giocattoli e alghe sul fondo della piscina vuota.

**Zone libere**: il percorso dallo spawn (0, 0, 19,2) al monumento, il cordone del monumento (raggio 3 m più margine) e il lampione. Le cose appese stanno fuori dal cono di vista dallo spawn verso la statua, che si vede intera entrando.

Ogni voce ha anche `gruppo` e `zona`: per togliere un gruppo intero basta filtrare su `gruppo`.

## Dettagli

### detriti

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_piastrella_rotta_1` | pavimento | 0.14 x 0.11 x 0.01 | 16 | pezzo di piastrella staccata |
| `det_piastrella_rotta_2` | pavimento | 0.07 x 0.05 x 0.01 | 16 | pezzo di piastrella staccata |
| `det_piastrella_rotta_3` | pavimento | 0.07 x 0.07 x 0.01 | 16 | pezzo di piastrella staccata |
| `det_piastrella_rotta_4` | pavimento | 0.19 x 0.10 x 0.01 | 12 | pezzo di piastrella staccata |
| `det_piastrella_rotta_5` | pavimento | 0.09 x 0.09 x 0.01 | 20 | pezzo di piastrella staccata |
| `det_piastrella_rotta_6` | pavimento | 0.07 x 0.05 x 0.01 | 16 | pezzo di piastrella staccata |
| `det_mucchio_piastrelle_1` | pavimento | 0.47 x 0.52 x 0.04 | 168 | mucchio di piastrelle cadute, ~0,8 m: sotto le pareti scrostate |
| `det_mucchio_piastrelle_2` | pavimento | 0.61 x 0.49 x 0.04 | 192 | mucchio di piastrelle cadute, ~0,8 m: sotto le pareti scrostate |
| `det_mucchio_piastrelle_3` | pavimento | 0.60 x 0.59 x 0.04 | 280 | mucchio di piastrelle cadute, ~0,8 m: sotto le pareti scrostate |
| `det_vetri_rotti_1` | pavimento | 0.61 x 0.74 x 0.01 | 192 | schegge di vetro (oblo, plafoniere): sotto le lampade rotte |
| `det_vetri_rotti_2` | pavimento | 0.60 x 0.67 x 0.01 | 200 | schegge di vetro (oblo, plafoniere): sotto le lampade rotte |
| `det_vetri_rotti_3` | pavimento | 0.54 x 0.60 x 0.01 | 172 | schegge di vetro (oblo, plafoniere): sotto le lampade rotte |
| `det_foglio_1` | pavimento | 0.36 x 0.35 x 0.02 | 280 | foglio bagnato (moduli, volantini: solo righe, niente testo) |
| `det_foglio_2` | pavimento | 0.24 x 0.32 x 0.03 | 280 | foglio bagnato (moduli, volantini: solo righe, niente testo) |
| `det_foglio_3` | pavimento | 0.30 x 0.35 x 0.04 | 280 | foglio bagnato (moduli, volantini: solo righe, niente testo) |
| `det_foglio_4` | pavimento | 0.36 x 0.35 x 0.07 | 280 | foglio bagnato (moduli, volantini: solo righe, niente testo) |
| `det_carta_accartocciata_1` | pavimento | 0.08 x 0.09 x 0.08 | 320 | pallina di carta |
| `det_carta_accartocciata_2` | pavimento | 0.10 x 0.10 x 0.10 | 320 | pallina di carta |
| `det_carta_accartocciata_3` | pavimento | 0.12 x 0.12 x 0.12 | 320 | pallina di carta |
| `det_asciugamano_1` | pavimento | 0.61 x 0.65 x 0.16 | 3440 | asciugamano bagnato, abbandonato per terra |
| `det_asciugamano_2` | pavimento | 0.71 x 0.54 x 0.14 | 3440 | asciugamano bagnato, abbandonato per terra |
| `det_asciugamano_3` | pavimento | 0.70 x 0.34 x 0.11 | 3440 | asciugamano bagnato, abbandonato per terra |
| `det_asciugamano_4` | pavimento | 0.63 x 0.34 x 0.18 | 3440 | asciugamano bagnato, abbandonato per terra |
| `det_paperella` | pavimento | 0.08 x 0.11 x 0.10 | 6000 | paperella di gomma |
| `det_secchiello` | pavimento | 0.14 x 0.13 x 0.16 | 6000 | secchiello da spiaggia |
| `det_paletta` | pavimento | 0.12 x 0.22 x 0.08 | 6000 | paletta |
| `det_barchetta` | pavimento | 0.20 x 0.07 x 0.20 | 6000 | barchetta |
| `det_pistola_acqua` | pavimento | 0.20 x 0.04 x 0.12 | 5999 | pistola ad acqua |
| `det_pesce_gomma` | pavimento | 0.06 x 0.12 x 0.06 | 6000 | pesce di gomma |
| `det_maschera_sub` | pavimento | 0.14 x 0.20 x 0.14 | 6000 | maschera da sub |
| `det_ciabatta` | pavimento | 0.26 x 0.11 x 0.07 | 5999 | ciabatta di gomma |

### cavi

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_cavo_pendente_1` | soffitto | 0.19 x 0.14 x 1.21 | 612 | cavo strappato che pende, 1.2 m |
| `det_cavo_pendente_2` | soffitto | 0.15 x 0.19 x 2.01 | 996 | cavo strappato che pende, 2.0 m |
| `det_cavo_pendente_3` | soffitto | 0.18 x 0.22 x 2.82 | 1188 | cavo strappato che pende, 2.8 m |
| `det_cavo_pendente_4` | soffitto | 0.18 x 0.20 x 1.61 | 804 | cavo strappato che pende, 1.6 m |
| `det_cavo_festone_1` | soffitto | 2.04 x 0.03 x 0.28 | 792 | cavo a festone tra due attacchi a 2.0 m (lungo +X Blender) |
| `det_cavo_festone_2` | soffitto | 4.04 x 0.03 x 0.63 | 1560 | cavo a festone tra due attacchi a 4.0 m (lungo +X Blender) |
| `det_cavo_festone_3` | soffitto | 6.04 x 0.03 x 1.03 | 2424 | cavo a festone tra due attacchi a 6.0 m (lungo +X Blender) |
| `det_fascio_cavi_4m` | soffitto | 4.01 x 0.08 x 0.98 | 6752 | fascio di 4 cavi con fascette, 4 m |

### tubi

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_tubo_muro_10cm_2m` | muro | 2.00 x 0.17 x 0.14 | 528 | tubo orizzontale Ø 10 cm, 2 m lungo +X, con staffe |
| `det_tubo_muro_16cm_2m` | muro | 2.00 x 0.23 x 0.20 | 528 | tubo orizzontale Ø 16 cm, 2 m lungo +X, con staffe |
| `det_tubo_muro_7cm_2m` | muro | 2.00 x 0.14 x 0.12 | 528 | tubo orizzontale Ø 7 cm, 2 m lungo +X, con staffe |
| `det_tubi_paralleli_2m` | muro | 2.00 x 0.18 x 0.50 | 120 | tre tubi paralleli su un supporto, 2 m |
| `det_tubo_curva_su` | muro | 1.06 x 0.16 x 1.56 | 2008 | tubo che gira e sale verso la galleria (1,5 m) |
| `det_tubo_verticale_3m` | muro | 0.10 x 0.14 x 3.00 | 68 | tubo verticale 3 m, origine in basso |
| `det_tubo_valvola_T` | muro | 1.20 x 0.28 x 0.77 | 512 | raccordo a T con valvola a volantino e manometro |
| `det_condotta_aria_2m` | muro | 2.03 x 0.33 x 0.28 | 48 | condotta dell aria 30 x 25 cm, 2 m lungo +X |
| `det_condotta_aria_4m` | muro | 4.03 x 0.33 x 0.28 | 72 | condotta dell aria 30 x 25 cm, 4 m lungo +X |
| `det_condotta_aria_curva` | muro | 0.61 x 0.33 x 0.81 | 36 | condotta che sale (curva a 90 gradi) |
| `det_bocchetta_rettangolare` | muro | 0.53 x 0.03 x 0.28 | 144 | bocchetta dell aria 50 x 25 cm |
| `det_bocchetta_rettangolare_rotta` | muro | 0.63 x 0.29 x 0.43 | 144 | bocchetta con la griglia storta |
| `det_bocchetta_tonda` | muro | 0.38 x 0.04 x 0.38 | 744 | bocchetta tonda Ø 36 cm |

### elettrico

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_cassetta_piccola` | muro | 0.18 x 0.09 x 0.98 | 92 | scatola di derivazione 18 x 18 cm, tubo che sale 80 cm |
| `det_cassetta_aperta` | muro | 0.41 x 0.53 x 1.70 | 848 | cassetta 40 x 30 con lo sportello aperto e i fili che pendono |
| `det_quadro_elettrico` | muro | 1.09 x 1.00 x 2.60 | 1748 | quadro elettrico 80 x 120, aperto: interruttori e fili. Origine al centro (metterlo a 1,4 m) |
| `det_interruttore_stagno` | muro | 0.09 x 0.07 x 0.96 | 40 | interruttore stagno con tubo che sale |

### lampade

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_neon_soffitto` | soffitto | 1.26 x 0.20 x 0.11 | 160 | plafoniera 2 x T8 120 cm, accesa (materiale M_det_neon_acceso) |
| `det_neon_soffitto_spento` | soffitto | 1.26 x 0.20 x 0.11 | 160 | plafoniera spenta |
| `det_neon_senza_diffusore` | soffitto | 1.26 x 0.20 x 0.10 | 148 | plafoniera senza diffusore, un tubo rotto |
| `det_neon_penzolante` | soffitto | 1.08 x 0.20 x 1.12 | 548 | plafoniera staccata da un lato, pende da una catenella (origine sull attacco rimasto) |
| `det_applique_emergenza` | muro | 0.18 x 0.17 x 0.18 | 932 | luce d emergenza rossa accesa (Ø 18 cm, gabbia) |
| `det_applique_emergenza_spenta` | muro | 0.18 x 0.17 x 0.18 | 932 | luce d emergenza spenta |
| `det_applique_emergenza_rotta` | muro | 0.18 x 0.17 x 0.18 | 700 | luce d emergenza col vetro rotto |
| `det_faro` | muro | 0.36 x 0.38 x 0.27 | 300 | faro da muro acceso, inclinato in basso di 25 gradi |
| `det_faro_spento` | muro | 0.36 x 0.35 x 0.29 | 300 | faro spento, girato verso il basso |

### cartelli

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_cartello_non_correre` | muro | 0.40 x 0.01 x 0.40 | 126 | cartello 40 x 40 cm, solo disegno (dritto); centro a 1,6-1,8 m |
| `det_cartello_non_tuffarsi` | muro | 0.46 x 0.01 x 0.46 | 126 | cartello 40 x 40 cm, solo disegno (storto); centro a 1,6-1,8 m |
| `det_cartello_vietato_vetro` | muro | 0.40 x 0.01 x 0.40 | 126 | cartello 40 x 40 cm, solo disegno (dritto); centro a 1,6-1,8 m |
| `det_cartello_pavimento_bagnato` | muro | 0.56 x 0.01 x 0.56 | 42 | cartello 40 x 40 cm, solo disegno (penzolante); centro a 1,6-1,8 m |
| `det_cartello_profondita` | muro | 0.40 x 0.01 x 0.40 | 126 | cartello 40 x 40 cm, solo disegno (dritto); centro a 1,6-1,8 m |
| `det_cartello_uscita` | muro | 0.46 x 0.01 x 0.46 | 126 | cartello 40 x 40 cm, solo disegno (storto); centro a 1,6-1,8 m |
| `det_cartello_pronto_soccorso` | muro | 0.40 x 0.10 x 0.40 | 126 | cartello 40 x 40 cm, solo disegno (piegato); centro a 1,6-1,8 m |
| `det_cartello_salvagente` | muro | 0.40 x 0.01 x 0.40 | 126 | cartello 40 x 40 cm, solo disegno (dritto); centro a 1,6-1,8 m |
| `det_cartello_non_correre_penzolante` | muro | 0.56 x 0.01 x 0.56 | 42 | variante appesa a una vite sola |
| `det_cartello_pavimento_bagnato_penzolante` | muro | 0.56 x 0.01 x 0.56 | 42 | variante appesa a una vite sola |

### organico

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_macchia_calcare_muro` | muro | 1.20 x 0.00 x 0.60 | 2 | decal con alfa (alpha scissor): macchia |
| `det_macchia_muffa_muro` | muro | 1.00 x 0.00 x 0.80 | 2 | decal con alfa (alpha scissor): macchia |
| `det_macchia_ruggine_colata_muro` | muro | 0.35 x 0.00 x 1.20 | 2 | decal con alfa (alpha scissor): sotto un tubo o un attacco: la colatura scende dall origine |
| `det_macchia_alghe_secche_pavimento` | pavimento | 1.40 x 1.00 x 0.00 | 2 | decal con alfa (alpha scissor): macchia |
| `det_macchia_alghe_verdi_pavimento` | pavimento | 1.20 x 0.90 x 0.00 | 2 | decal con alfa (alpha scissor): macchia |
| `det_macchia_calcare_pavimento` | pavimento | 1.00 x 1.00 x 0.00 | 2 | decal con alfa (alpha scissor): macchia |
| `det_alghe_secche_mucchio_1` | pavimento | 1.10 x 0.98 x 0.02 | 1794 | mucchio di alghe secche: bordi delle vasche, scarichi, fondo della piscina |
| `det_alghe_secche_mucchio_2` | pavimento | 1.07 x 1.15 x 0.02 | 2306 | mucchio di alghe secche: bordi delle vasche, scarichi, fondo della piscina |
| `det_alghe_secche_mucchio_3` | pavimento | 1.03 x 1.12 x 0.02 | 2818 | mucchio di alghe secche: bordi delle vasche, scarichi, fondo della piscina |
| `det_incrostazione_spigolo_1` | muro | 1.00 x 0.04 x 0.06 | 200 | crosta di calcare lungo uno spigolo, 1 m lungo +X (bordo vasca, base del muro) |
| `det_incrostazione_spigolo_2` | muro | 1.00 x 0.04 x 0.06 | 200 | crosta di calcare lungo uno spigolo, 1 m lungo +X (bordo vasca, base del muro) |

### catene_corde

| Nodo | Appoggio | Ingombro (m, Blender x y z) | Triangoli | Note |
|---|---|---|---|---|
| `det_catena_pendente_1m` | soffitto | 0.07 x 0.06 x 1.03 | 2892 | catena che pende, 1 m |
| `det_catena_pendente_2m` | soffitto | 0.07 x 0.06 x 2.03 | 5772 | catena che pende, 2 m |
| `det_catena_pendente_3m` | soffitto | 0.07 x 0.06 x 3.03 | 8652 | catena che pende, 3 m |
| `det_catena_festone_3m` | soffitto | 2.98 x 0.04 x 0.62 | 9360 | catena a festone tra due punti a 3 m (ringhiere, transenne) |
| `det_catena_a_terra` | pavimento | 0.31 x 0.39 x 0.05 | 8928 | catena ammucchiata per terra |
| `det_gancio` | soffitto | 0.09 x 0.05 x 0.23 | 256 | gancio (da mettere in fondo a una catena) |
| `det_corda_pendente_1` | soffitto | 0.11 x 0.03 x 1.55 | 632 | corda che pende sfilacciata, 1.5 m |
| `det_corda_pendente_2` | soffitto | 0.11 x 0.03 x 3.05 | 1432 | corda che pende sfilacciata, 3.0 m |
| `det_corda_galleggianti_4m` | soffitto | 4.01 x 0.07 x 0.55 | 2228 | corda corsia con galleggianti, 4 m (tra due ringhiere o appesa) |
| `det_corda_rotolo` | pavimento | 0.35 x 0.35 x 0.13 | 3808 | rotolo di corda per terra |

## Licenze

Vedi `LICENZE.md`.
