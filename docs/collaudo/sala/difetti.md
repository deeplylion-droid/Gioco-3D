# Collaudo del posizionamento: sala principale

Ingresso, area bimbi, vasca di Jilly, acquari dell'enigma davanti al portone della torre (la piscina a onde è nel resoconto della zona 3). Base: `lavoro/godot` al commit 921d14f. Squadra collaudo, 22 ottobre.

Posizioni in metri nel mondo di `sala_principale.tscn`. Le distanze sono misurate fra le superfici vere delle mesh (`tools/collaudo/distanze.py`), comprese le istanze dei MultiMesh dei dettagli. Scatti in `scatti/`, fogli in `fogli/`.

## Come è stato fatto

- **Controllo della CI**: 0 casi nuovi. Nella sala restano 5 ingombri "da correggere" (due scatoloni caduti, la struttura dell'area bimbi, le due guide delle lampadine del portone).
- **Distanze vere**: 1617 oggetti della sala nello stato iniziale; gli oggetti dell'enigma e della tappa 7 anche negli stati ritorno (blackout, acquari pieni, lampadine accese, bava) e risolto (portone aperto).
- **Giro dagli occhi**: 110 punti, uno ogni 3,5 m, 440 scatti (`fogli/sala_giro_*.jpg`), stato iniziale. La sala intera sul renderer software non entra più in memoria: gli scatti hanno materiali semplici (il colore medio di ogni texture) e senza interni, risalita e tecnici. Le macchie e i decalcomanie con trasparenza della sala lì sembrano rettangoli grigi: non sono difetti.
- **Oggetti piccoli**: 587 sotto i 40 cm, 168 non sul pavimento (`oggetti_piccoli.csv`). Le vedute ravvicinate sono prese da un punto dove si cammina, all'altezza degli occhi, con la vista libera verificata sui triangoli veri (`fogli/sala_vedute_*.jpg`).

## Difetti

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `Gioco/EnigmaAcquari/AcquarioGiallo/Tirante2` e `Tirante4`, `AcquarioBlu/Tirante2` e `Tirante4` | giallo 16,05 / 17,75, y 1,5-4,5, z -21,45 / -23,15; blu 4,85 / 6,55, stesse y e z | Due dei quattro tiranti di ogni acquario colorato non toccano niente: in alto finiscono 3,0 cm (Tirante2) e 1,8 cm (Tirante4) sotto il coperchio, e in basso stanno fuori dalla base. Sono sospesi, in tutti gli stati. | `scatti/vg_AcquarioGiallo_Tirante4.jpg`, `vg_AcquarioBlu_Tirante2.jpg` |
| 2 | `Gioco/EnigmaAcquari/Disegno/Modello` | 17,42, 2,90, -21,33 | Il disegno a pastello dell'indizio non è attaccato al vetro dell'acquario giallo: è a 4 cm dal vetro e tocca solo lo spigolo del Tirante1. Nel GDD va "attaccato al vetro, retroilluminato". | `vs_Disegno_Modello.jpg`, `vr_Disegno_Modello.jpg` |
| 3 | `Gioco/RitornoAlBuio/Scia/BavaBordoVasca/Nastro` e `BavaMuroVasca/Nastro` (stato ritorno) | -0,25, 1,01, 12,15 e -0,46, 0,52, 12,39 | La bava sul bordo e sul muro della vasca di Jilly sta 1,2 e 1,9 cm staccata dalla superficie. | `vr_BavaBordoVasca_Nastro.jpg`, `vr_BavaMuroVasca_Nastro.jpg` |
| 4 | `Mascotte/TargaJilly/targa` | -3,01, 0,62, 10,00 | La targa smaltata è a 2,4 cm dalle sue viti: non tocca niente. | `vs_TargaJilly_targa.jpg` |
| 5 | `Mascotte/ManifestoJilly/manifesto` (con `manifesto_001`, `Plane`, `Plane_001`) | -19,93, 1,40, 13,95 | Il manifesto dello spettacolo è a 2,2 cm dal muro (Plane_001 a 1,4 cm dal manifesto). | `vs_ManifestoJilly_manifesto.jpg` |
| 6 | `Mascotte/InsegnaJilly/lampada_dx_lampadina` e `lampada_sx_lampadina` | -19,53, 5,39, 4,86 e 5,84 | Le lampadine delle due lampade a collo d'oca sono 2,9 cm fuori dal paralume: sospese davanti. | `vs_InsegnaJilly_lampada_dx_lampadina.jpg` |
| 7 | `Sala/AngoloScatoloni`: colonne `scat_0_0`, `0_2`, `0_3`, `1_2`, `2_0`, `2_2` (43 scatoloni su 148) | x -19,4 / -18,6 / -17,7, z 16,9-19,4, y 0,9-9,1 | Nelle pile c'è uno scatolone che non poggia su quello sotto: 1,0-1,3 cm d'aria, e tutti quelli sopra vengono dietro. | `vs_AngoloScatoloni_scat_2_0_4.jpg`, `fogli/sala_vedute_02.jpg` |
| 8 | `Sala/AngoloPalloni/pallone_62`, `pallone_66` (in vista) e 16 palloni interni | 19,41, 4,35, 19,09 e 17,57, 3,63, 19,43 | Palloni del mucchio che non toccano nessun altro pallone: 4,3 e 2,6 cm d'aria (quelli interni 1,3-4,3 cm). | `vs_AngoloPalloni_pallone_dentro_57.jpg` |
| 9 | `Sala/Dettagli/@MeshInstance3D@49` (applique) | 17,71, 3,02, 19,96 | L'applique a muro è sommersa dal mucchio di palloni: i palloni la coprono. | `sala_@MeshInstance3D@49_a.jpg` |
| 10 | `Sala/Dettagli/@MeshInstance3D@48` e `det_bocchetta_tonda` n. 3 | 19,96, 3,16, 4,45; bocchetta n. 3 sul muro | Applique messe sopra una bocchetta d'aerazione tonda: la gabbia tocca ed entra nella cornice della bocchetta. | `vs_Dettagli_@MeshInstance3D@48.jpg`, `vs_Dettagli_det_bocchetta_tonda_3.jpg` |
| 11 | `Sala/Dettagli/det_applique_emergenza_spenta` e `det_applique_emergenza_rotta` | 19,96, 2,83, -0,39 e 19,96, 2,72, -0,59 | Due applique una attaccata all'altra (20 cm), quasi alla stessa altezza: sembra un doppione. | `vs_Dettagli_det_applique_emergenza_spenta.jpg` |
| 12 | `Sala/Dettagli/det_pistola_acqua` n. 11 | 8,89, 0,08, -21,26 | La pistola ad acqua è 2,1 cm sopra il pavimento. | `vs_Dettagli_det_pistola_acqua_11.jpg` |
| 13 | `Sala/Dettagli/det_pannello_lamiera` n. 7 | -3,14, 0,19, 17,17 | Il pannello di lamiera a terra è 2,1 cm sopra il pavimento. | `vs_Dettagli_det_pannello_lamiera_7.jpg` |
| 14 | `Sala/Dettagli/@MeshInstance3D@40` | -17,43, 0,06, 3,24 | Dettaglio a terra (0,8 x 0,6 m) 1,8 cm sopra la pozzanghera. | (misura) |
| 15 | `Sala/Dettagli/det_macchia_ruggine_colata_muro` n. 12 | 19,99, 2,49, 15,01 | La colatura di ruggine è 1,5 cm staccata dal muro: di sbieco si vede sospesa. | `vs_Dettagli_det_macchia_ruggine_colata_muro_12.jpg` |
| 16 | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@95` | -1,48, 0,85, 12,29 | Un pezzetto (1 x 4,5 cm) della medusa sospeso a 7,2 cm dal bordo della vasca. | `vs_@Node3D@94_@MeshInstance3D@95.jpg` |
| 17 | `Sala/Dettagli/@MeshInstance3D@50` e `@52` | 7,24, 2,81, -23,83 e -18,20, 3,42, -23,81 | Da valutare: cassette sul muro nord girate di 45 gradi rispetto al muro, appoggiate su uno spigolo. | `vs_Dettagli_@MeshInstance3D@50.jpg`, `@52.jpg` |
| 18 | `Sala/Oggetti/ogg_salvagente_nave_17` | -19,91, 1,15, 1,00 | Da valutare: il salvagente è appeso sopra un oblò e lo copre a metà. | `vs_Oggetti_ogg_salvagente_nave_17.jpg` |

Restano aperti anche i 5 ingombri "da correggere" del controllo della CI nella sala (`AngoloScatoloni/scat_caduto_0` e `_6`, `AreaBimbi/sala_struttura_gioco`, `LampadePortone/Spente/GuidaDestra` e `GuidaSinistra`).

## Visti e a posto

La medusa nella vasca, le statue (squalo, polpi), i lettini, le panche, i cestini, la sedia del bagnino, i cartelli a terra, i giocattoli sul pavimento e in acqua, il festone di lampadine dell'area bimbi (tutte sul filo), la lampada della valvola (fissata al Tirante1 del blu), le staffe e le guide delle lampadine del portone, le Polaroid 04, 05, 08 e 09.

## Buchi del controllo della CI

- **Gli acquari dell'enigma non vengono controllati.** In `controllo_posizionamento.gd` (riga 164) una mesh è "acqua" se il percorso contiene `/acqua`, e `/AcquarioGiallo`, `/AcquarioBlu` e `/AcquarioMisto` ci cadono dentro: basi, coperchi, tiranti, vetri e anelli degli acquari sono presi per superfici d'acqua e non sono mai oggetti. Per questo i tiranti sospesi (difetto 1) non escono. Nel collaudo (`geometria.gd`) vale solo un pezzo di percorso che comincia con "acqua" e non con "acquari".
- **I MultiMesh restano fuori**, sia dal controllo sia, con `--headless`, da qualunque misura: i dettagli della sala con 6 o più copie (lampadine del portone comprese). Il collaudo rifà le istanze dei dettagli da `posizionamento.json`. Le lampadine del portone (`LampadePortone`, file `.res`), le lamelle della serranda e le medusine restano fuori anche dal collaudo: guardate solo negli scatti.
- **Le mesh con lo scheletro** (la medusa) si misurano nella posa di riposo, non in quella del gioco: per loro valgono solo gli scatti.
- Il controllo guarda gli ingombri solo nello stato iniziale: il portone aperto, la serranda e il portello aperto non passano dal controllo degli ingombri.
