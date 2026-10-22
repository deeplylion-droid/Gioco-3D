# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-22 23:16:10. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 0. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 40. Eccezioni non più trovate: 0.

## Già noti

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/corridoio_statico` | 8.75, 0.00, 42.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (10 celle da 25 cm) (pavimenti fra y -1.58 e -0.00), senza collisione (si attraversa) (stato: tappa7) | da correggere: controllo del 22 ottobre notte, stato tappa7 (porte della sala pompe e portello aperti): nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (10 celle da 25 cm) (pavimenti fra y -1.58 e -0.00), senza collisione (si attraversa) (stato: tappa7) |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_rotore` | 0.00, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (2 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | -0.75, 0.00, 25.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |

### risalita

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | staccato | `Risalita/Fiume/@Node3D@23106/lampada` | -11.05, -2.40, 100.95 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] |
| enigmi | staccato | `Risalita/Fiume/@Node3D@23140/lampada` | -55.79, -2.40, 85.23 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] |
| enigmi | staccato | `Risalita/Fiume/@Node3D@23160/lampada` | -37.14, -2.40, 108.43 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] |
| enigmi | staccato | `Risalita/Fiume/@Node3D@23180/lampada` | -43.78, -2.40, 89.86 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 276.8 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 276.8 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] |
| enigmi | staccato | `Risalita/Fiume/@Node3D@23183/lampada` | -37.14, -2.40, 79.37 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 279.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: globo. (stato: risalita_arrivo) [modello: lampada_gabbia.glb] |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/AnelloVetro` | 5.70, 4.31, -22.30 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Coperchio/cilindro_coperchio | da correggere: controllo del 22 ottobre sera, acquari corretti da enigmi: passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Coperchio/cilindro_coperchio per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/AnelloVetro` | 16.90, 4.31, -22.30 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Coperchio/cilindro_coperchio | da correggere: controllo del 22 ottobre sera, acquari corretti da enigmi: passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Coperchio/cilindro_coperchio per 4 cm |
| mascotte | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa` | -13.82, -0.28, -6.90 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 41 cm (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 41 cm (stato: lei_fossa) |
| mascotte | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -13.24, -0.06, -6.85 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 17 cm (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 116 cm (stato: lei_fossa) |
| ambienti-2 | compenetra | `Sala/Dettagli/det_foglio_2_7` | 14.00, 0.02, 18.06 | il 23% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_9 | da correggere: controllo del 22 ottobre sera (dettaglio della sala in MultiMesh, prima non controllato): il 45% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_dentro_12 |
| ambienti-1 | compenetra | `Sala/VascaCentrale/ogg_salvagente_nave_36` | -1.75, 0.37, 12.40 | passa dentro Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli per 3 cm | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): passa dentro Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli per 3 cm |
| mascotte | ingombro | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -13.00, 0.00, -5.25 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.59 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.59 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: lei_fossa) |
| ambienti-1 | ingombro | `Sala/AreaBimbi/sala_struttura_gioco` | -15.50, 0.00, -19.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (74 celle da 25 cm) (pavimento a y -0.00), con la collisione (ci si sbatte contro) | voluto: struttura per bambini: i tettucci e le sbarre stanno all'altezza della testa di un adulto, ci si urta come contro un muro e si passa accovacciati (scelta dell'utente, 22 ottobre) |
| enigmi | staccato | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/CoperchioPompa` | 8.74, 0.81, -21.61 | la sua forma sfiora Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `Tecnici/Ambienti/CameraOnde/CAMERA_bocchette` | -1.75, -9.05, 15.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.58 e 2.00 m sopra il pavimento (12 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: bocchette dell'aria sul muro sud della camera delle onde (da 1,65 m), ora con la collisione: ci si ferma contro come contro il muro. Se non va bene: alzarle di 40 cm in ambienti2_camera_onde.py |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.25, -9.05, 33.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.90 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: quadro elettrico appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.30 e 2.00 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dal giocatore, fra 0.35 e 1.10 m sopra il pavimento (6 celle da 25 cm) (pavimenti fra y -9.05 e -8.89), senza collisione (si attraversa) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/ATTUATORE_stagno` | -2.65, -7.67, 47.51 | la sua forma sfiora Tecnici/Ambienti/SalaPompe/SALA_meccanismi, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 120.0 cm) | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora Tecnici/Ambienti/SalaPompe/SALA_meccanismi, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 120.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/POMPA_1_manometro` | 4.15, -6.83, 33.27 | la sua forma sfiora Tecnici/Ambienti/SalaPompe/POMPA_1, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 12.2 cm) | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora Tecnici/Ambienti/SalaPompe/POMPA_1, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 12.2 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/POMPA_2_manometro` | 4.15, -6.83, 37.77 | la sua forma sfiora Tecnici/Ambienti/SalaPompe/POMPA_2, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 12.2 cm) | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora Tecnici/Ambienti/SalaPompe/POMPA_2, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 12.2 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/plafoniera_0` | 1.20, -4.22, 34.16 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_0_tubi. | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_0_tubi. |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/plafoniera_1` | 1.20, -4.22, 39.16 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_1_tubo_sfarfalla. | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_1_tubo_sfarfalla. |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/plafoniera_2` | 1.20, -4.22, 43.66 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_2_tubi. | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_2_tubi. |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/plafoniera_3` | 5.70, -4.22, 39.16 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_3_tubi. | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 478.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_3_tubi. |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_struttura` | 44.00, -34.00, -4.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -34.00), con la collisione (ci si sbatte contro) | voluto: le celle sono dentro i tubi chiusi (sopra il tubo ci sono i suoi attacchi) e sulla scaletta di pioli del bacino, da dove si sale (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 50.50, -22.58, -14.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -22.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 63.00, -25.58, -27.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -25.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2` | 69.50, -28.58, -7.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -28.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 50.75, -34.00, -6.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -34.00), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreScivoli/torre_tubo_inseguimento` | 38.00, -19.98, -16.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.40 e 2.00 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -19.98), senza collisione (si attraversa) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreStruttura/torre_A_sostegni` | 38.00, -19.98, -16.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.68 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -19.98), senza collisione (si attraversa) | voluto: celle dentro il tubo dell'inseguimento, e il collare sotto la coda del tratto 5, 1,93 m sopra il terzo gradino della bocca, sul bordo est della salita (ambienti-2, 22 ottobre) |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_0/@MeshInstance3D@46565` | 54.61, -19.48, -16.40 | la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_0, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_0, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_2/@MeshInstance3D@46573` | 67.00, -22.48, -25.39 | la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_2, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_2, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_4/@MeshInstance3D@46581` | 66.89, -25.48, -3.60 | la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_4, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora SalaInseguimento/InseguimentoMobili/ins_paratia_4, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 158.8 cm) (stato: inseguimento_dopo) [modello: inseguimento_mobili.glb] |
| ambienti-2 | staccato | `SalaInseguimento/Luci/@Node3D@7530/Nastro` | 51.59, -21.48, -17.05 | la sua forma sfiora SalaInseguimento/InseguimentoTubi/ins_A_tubo_0, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 14.2 cm) [modello: sala_inseguimento.tscn] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora SalaInseguimento/InseguimentoTubi/ins_A_tubo_0, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 14.2 cm) [modello: sala_inseguimento.tscn] |
| ambienti-2 | staccato | `SalaInseguimento/Luci/@Node3D@7535/POMPA_3_modello` | 67.20, -31.25, -14.77 | la sua forma sfiora SalaInseguimento/Luci/@Node3D@7535/POMPA_3, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) [modello: sala_inseguimento.tscn] | da correggere: controllo del 22 ottobre notte (distanza vera fra le mesh, come il collaudo): la sua forma sfiora SalaInseguimento/Luci/@Node3D@7535/POMPA_3, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) [modello: sala_inseguimento.tscn] |

## Copertura

Per ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.

| Giro | Parte | Oggetti controllati |
|---|---|---|
| sala_principale · inizio | `Gioco/EnigmaAcquari` | 203 |
| sala_principale · inizio | `Interni/Ambienti` | 180 |
| sala_principale · inizio | `Interni/LampadaTornelli` | 2 |
| sala_principale · inizio | `Interni/Meccanismi` | 1 |
| sala_principale · inizio | `Interni/Polaroid` | 3 |
| sala_principale · inizio | `Interni/Zaino` | 1 |
| sala_principale · inizio | `LuciSala/LuciAreaBimbi` | 92 |
| sala_principale · inizio | `Mascotte/InsegnaJilly` | 23 |
| sala_principale · inizio | `Mascotte/ManifestoJilly` | 4 |
| sala_principale · inizio | `Mascotte/StatuaPolpoA` | 1 |
| sala_principale · inizio | `Mascotte/StatuaPolpoB` | 1 |
| sala_principale · inizio | `Mascotte/StatuaSqualo` | 1 |
| sala_principale · inizio | `Mascotte/TargaJilly` | 1 |
| sala_principale · inizio | `Piscina/LucePortellone` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid04` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid05` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid06` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid07` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid08` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid09` | 1 |
| sala_principale · inizio | `Risalita` | 197 |
| sala_principale · inizio | `Risalita/Corrimano` | 7 |
| sala_principale · inizio | `Risalita/lampada_emergenza` | 2 |
| sala_principale · inizio | `Sala/AngoloPalloni` | 129 |
| sala_principale · inizio | `Sala/AngoloScatoloni` | 148 |
| sala_principale · inizio | `Sala/AreaBimbi` | 4 |
| sala_principale · inizio | `Sala/Dettagli` | 854 |
| sala_principale · inizio | `Sala/Interattivi` | 8 |
| sala_principale · inizio | `Sala/Piscina` | 6 |
| sala_principale · inizio | `Sala/TorreScivoli` | 2 |
| sala_principale · inizio | `Sala/VascaCentrale` | 33 |
| sala_principale · inizio | `Tecnici/Ambienti` | 441 |
| sala_principale · inizio | `Tecnici/LampeggianteParatia1` | 2 |
| sala_principale · inizio | `Tecnici/Logica` | 38 |
| sala_principale · inizio | `Vasca/Medusa` | 9 |
| sala_torre · inizio | `FondoPozzo` | 1 |
| sala_torre · inizio | `Luci` | 358 |
| sala_torre · inizio | `Polaroid10/Modello` | 1 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inizio | `SalaInseguimento/Luci` | 76 |
| sala_torre · inizio | `TorreProp` | 23 |
| sala_torre · inizio | `TorreScivoli` | 20 |
| sala_principale · interni_dopo | `Interni/Ambienti` | 180 |
| sala_principale · interni_dopo | `Interni/LampadaTornelli` | 2 |
| sala_principale · interni_dopo | `Interni/Meccanismi` | 1 |
| sala_principale · interni_dopo | `Interni/Polaroid` | 3 |
| sala_principale · interni_dopo | `Interni/Zaino` | 1 |
| sala_principale · lei_fossa | `Gioco/LeiSbuca` | 9 |
| sala_principale · risalita_arrivo | `Risalita` | 197 |
| sala_principale · risalita_arrivo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_arrivo | `Risalita/Fiume` | 259 |
| sala_principale · risalita_arrivo | `Risalita/Infermeria` | 121 |
| sala_principale · risalita_arrivo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · risalita_dopo | `Risalita` | 197 |
| sala_principale · risalita_dopo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_dopo | `Risalita/Fiume` | 259 |
| sala_principale · risalita_dopo | `Risalita/Infermeria` | 177 |
| sala_principale · risalita_dopo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · tappa7 | `Interni/Ambienti` | 2 |
| sala_principale · tappa7 | `Sala/Interattivi` | 1 |
| sala_principale · tappa7 | `Tecnici/Ambienti` | 2 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/Luci` | 76 |
| sala_principale · acquari_comparsi | `Gioco/EnigmaAcquari` | 205 |
| sala_principale · acquari_comparsi | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_comparsi | `Sala/Interattivi` | 1 |
| sala_principale · acquari_risolti | `Gioco/EnigmaAcquari` | 205 |
| sala_principale · acquari_risolti | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_risolti | `Sala/Interattivi` | 1 |

### Parti nascoste all'inizio

Le parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). "Controllata nello stato" vuol dire che un giro con stato le ha viste visibili; "mai controllata" va guardato.

| Scena | Parte nascosta | Mesh | Controllata |
|---|---|---|---|
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1341` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1342` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1343` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1344` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1345` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1346` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Acqua/Surface` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Graybox/Superficie` | 1 | no: segnaposto graybox, al suo posto si vede il modello vero |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Vetro/Volume` | 1 | no: variante nello stesso posto di una parte controllata |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa` | 12 | sì, in uno stato |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/SchizzoCoda/Corona` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoCoda/Schiuma` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoTesta/Corona` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoTesta/Schiuma` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Corridoio/acqua_pozze_corridoio` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Spogliatoi/acqua_lavapiedi` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Spogliatoi/acqua_pozze_spogliatoi` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Stanzino/acqua_pozza_stanzino` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1389` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1390` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1391` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1392` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1395` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1396` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1397` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1398` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1401` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1402` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1403` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1404` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1407` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1408` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1409` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1410` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/EffettoSottacqua/UnderwaterQuad` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/ViewModel` | 13 | **mai controllata** |
| sala_principale | `Player/WaterPack/Aspirazione` | 2 | **mai controllata** |
| sala_principale | `Player/WaterPack/GettoPotente/@MeshInstance3D@1686` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Risalita/Fiume` | 378 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria` | 177 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto11/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto12/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto13/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto14/Frontale/Radiografia` | 1 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto14/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto15/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto21/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto22/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto23/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto24/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto25/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Keycard` | 2 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Negatoscopio/Lastra` | 2 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/PolaroidPecora` | 1 | sì, in uno stato |
| sala_principale | `Tecnici/Ambienti/SalaPompe/ACQUA_vasca_raccolta` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@103` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@104` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@105` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@106` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@107` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@108` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@111` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@112` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@113` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@114` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@115` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@116` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@119` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@120` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@121` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@122` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@123` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@124` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@127` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@128` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@129` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@130` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@131` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@132` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@87` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@88` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@89` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@90` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@91` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@92` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@100` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@95` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@96` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@97` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@98` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@99` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@79` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@80` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@81` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@82` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@83` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@84` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata0` | 2 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata1` | 3 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata2` | 2 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata3` | 3 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `SalaInseguimento/Lei` | 12 | no: creatura, si muove (la guarda il collaudo) |

