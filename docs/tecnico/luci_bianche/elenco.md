# Luci bianche al 40%: come sono classificate, zona per zona

Scritto da `godot/proposte/mascotte/elenco_luci_bianche.gd`. Regola (`scripts/game/luci_bianche.gd`): bianca se la saturazione è al più 0.30; bianco-calda se la tinta è fra 0.045 e 0.17 (arancio-giallo) e la saturazione al più 0.76. Tutto il resto è colorato e resta com'è. Materiali: emissione accesa (almeno 0.3) dello stesso colore. Fra parentesi il colore (tinta, saturazione) e l'energia piena.

## sala_principale

Costo con questa scena caricata: 0.41 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 99 luci bianche e 88 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### Gioco/EnigmaAcquari — 7 bianche, 0 colorate, 2 materiali

Bianche (scendono al 40%):
- `AcquarioGiallo/LuceAcquario` (0.11, 0.14; 6.96)
- `AcquarioMisto/LuceAcquario` (0.11, 0.14; 3.48)
- `AcquarioBlu/LuceAcquario` (0.11, 0.14; 6.96)
- `LampadaValvola/Luce` (0.10, 0.34; 6.00)
- `LampadePortone/Accese/Lampada1/Luce` (0.09, 0.55; 2.20)
- `LampadePortone/Accese/Lampada2/Luce` (0.09, 0.55; 2.20)
- `LampadePortone/Accese/Lampada3/Luce` (0.09, 0.55; 2.20)

Materiali delle lampade:
- scende `senza nome` su `LampadaValvola/Modello/globo` (0.10, 0.40; 8.0)
- scende `disegno_carta` su `Disegno/Modello` (0.13, 0.45; 0.6)

### Gioco/PortoneTorre — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `LuceLampeggiante` (0.01, 0.94; 0.00)

### Interni — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceZaino` (0.09, 0.58; 2.60)

### Interni/Ambienti — 3 bianche, 65 colorate, 25 materiali

Colorate (restano com'erano):
- `Corridoio/luce_emergenza_01_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_02_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_03_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_04_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_05_luce` (0.01, 0.89; 1195.73)
- `Corridoio/luce_emergenza_06_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_07_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_08_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_01_rossa/@OmniLight3D@988` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_01_rossa/@Node3D@989/@SpotLight3D@990` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_01_rossa/@Node3D@989/@SpotLight3D@991` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_02_rossa/@OmniLight3D@994` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_02_rossa/@Node3D@995/@SpotLight3D@996` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_02_rossa/@Node3D@995/@SpotLight3D@997` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_03_rossa/@OmniLight3D@1000` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_03_rossa/@Node3D@1001/@SpotLight3D@1002` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_03_rossa/@Node3D@1001/@SpotLight3D@1003` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_04_rossa/@OmniLight3D@1006` (0.00, 0.97; 1.28)
- `Corridoio/luce_emergenza_04_rossa/@Node3D@1007/@SpotLight3D@1008` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_04_rossa/@Node3D@1007/@SpotLight3D@1009` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_05_rossa/@OmniLight3D@1012` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_05_rossa/@Node3D@1013/@SpotLight3D@1014` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_05_rossa/@Node3D@1013/@SpotLight3D@1015` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_06_rossa/@OmniLight3D@1018` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_06_rossa/@Node3D@1019/@SpotLight3D@1020` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_06_rossa/@Node3D@1019/@SpotLight3D@1021` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_07_rossa/@OmniLight3D@1024` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_07_rossa/@Node3D@1025/@SpotLight3D@1026` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_07_rossa/@Node3D@1025/@SpotLight3D@1027` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_08_rossa/@OmniLight3D@1030` (0.00, 0.97; 1.28)
- `Corridoio/luce_emergenza_08_rossa/@Node3D@1031/@SpotLight3D@1032` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_08_rossa/@Node3D@1031/@SpotLight3D@1033` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_01_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_02_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_03_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_04_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_05_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_06_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_pulsante_tornello` (0.03, 0.69; 0.40)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@OmniLight3D@1036` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@Node3D@1037/@SpotLight3D@1038` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@Node3D@1037/@SpotLight3D@1039` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@OmniLight3D@1042` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@Node3D@1043/@SpotLight3D@1044` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@Node3D@1043/@SpotLight3D@1045` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@OmniLight3D@1048` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@Node3D@1049/@SpotLight3D@1050` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@Node3D@1049/@SpotLight3D@1051` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@OmniLight3D@1054` (0.00, 0.97; 1.28)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@Node3D@1055/@SpotLight3D@1056` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@Node3D@1055/@SpotLight3D@1057` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@OmniLight3D@1060` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@Node3D@1061/@SpotLight3D@1062` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@Node3D@1061/@SpotLight3D@1063` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@OmniLight3D@1066` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@Node3D@1067/@SpotLight3D@1068` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@Node3D@1067/@SpotLight3D@1069` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_01_luce` (0.01, 0.89; 1630.54)
- `Stanzino/luce_emergenza_stanzino_02_luce` (0.01, 0.89; 1195.73)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@OmniLight3D@1072` (0.00, 0.97; 2.80)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@Node3D@1073/@SpotLight3D@1074` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@Node3D@1073/@SpotLight3D@1075` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@OmniLight3D@1078` (0.00, 0.97; 1.28)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@Node3D@1079/@SpotLight3D@1080` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@Node3D@1079/@SpotLight3D@1081` (0.01, 0.97; 5.00)

Bianche (scendono al 40%):
- `Corridoio/neon_corridoio_2_neon/@OmniLight3D@983` (0.44, 0.22; 6.00)
- `Spogliatoi/neon_spogliatoi_1_neon/@OmniLight3D@984` (0.44, 0.22; 6.00)
- `Stanzino/neon_stanzino_neon/@OmniLight3D@985` (0.44, 0.22; 4.80)

Materiali delle lampade:
- resta `hq_lampada_muro_vetro` su `Corridoio/luce_emergenza_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Corridoio/neon_corridoio_1_tubi` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Corridoio/neon_corridoio_2_neon/neon_corridoio_2_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Corridoio/luce_emergenza_01_rossa/@MeshInstance3D@987` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_02_rossa/@MeshInstance3D@993` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_03_rossa/@MeshInstance3D@999` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_04_rossa/@MeshInstance3D@1005` (0.01, 0.97; 1.8)
- resta `senza nome` su `Corridoio/luce_emergenza_05_rossa/@MeshInstance3D@1011` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_06_rossa/@MeshInstance3D@1017` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_07_rossa/@MeshInstance3D@1023` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_08_rossa/@MeshInstance3D@1029` (0.01, 0.97; 1.8)
- resta `hq_lampada_muro_vetro` su `Spogliatoi/luce_emergenza_spogliatoi_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Spogliatoi/neon_spogliatoi_2_tubi` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Spogliatoi/neon_spogliatoi_1_neon/neon_spogliatoi_1_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@MeshInstance3D@1035` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@MeshInstance3D@1041` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@MeshInstance3D@1047` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@MeshInstance3D@1053` (0.01, 0.97; 1.8)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@MeshInstance3D@1059` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@MeshInstance3D@1065` (0.01, 0.97; 3.0)
- resta `hq_lampada_muro_vetro` su `Stanzino/luce_emergenza_stanzino_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Stanzino/luce_emergenza_stanzino_01_rossa/@MeshInstance3D@1071` (0.01, 0.97; 3.0)
- resta `senza nome` su `Stanzino/luce_emergenza_stanzino_02_rossa/@MeshInstance3D@1077` (0.01, 0.97; 1.8)

### Interni/LampadaTornelli — 1 bianche, 0 colorate, 1 materiali

Bianche (scendono al 40%):
- `Luce` (0.44, 0.22; 6.00)

Materiali delle lampade:
- scende `hq_plafoniera_neon_diffusore` su `lampada_tubi` (0.43, 0.08; 10.0)

### Interni/Meccanismi — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `senza nome` su `Saracinesca/Graybox/Spia` (0.01, 0.90; 2.0)

### LuciSala — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `ControluceStatua` (0.60, 0.38; 5.00)

### LuciSala/LuciAreaBimbi — 1 bianche, 12 colorate, 7 materiali

Colorate (restano com'erano):
- `@OmniLight3D@1425` (0.12, 0.80; 1.10)
- `@OmniLight3D@1432` (0.88, 0.55; 1.10)
- `@OmniLight3D@1445` (0.88, 0.55; 1.10)
- `@OmniLight3D@1458` (0.88, 0.55; 1.10)
- `@OmniLight3D@1465` (0.12, 0.80; 1.10)
- `@OmniLight3D@1478` (0.12, 0.80; 1.10)
- `@OmniLight3D@1485` (0.88, 0.55; 1.10)
- `@OmniLight3D@1492` (0.12, 0.80; 1.10)
- `@OmniLight3D@1499` (0.88, 0.55; 1.10)
- `@OmniLight3D@1506` (0.12, 0.80; 1.10)
- `@OmniLight3D@1513` (0.88, 0.55; 1.10)
- `@OmniLight3D@1520` (0.12, 0.80; 1.10)

Bianche (scendono al 40%):
- `PlafonieraBimbi/@SpotLight3D@1526` (0.09, 0.32; 7.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1422` (0.99, 0.75; 4.0)
- resta `senza nome` su `@MeshInstance3D@1424` (0.12, 0.80; 4.0)
- resta `senza nome` su `@MeshInstance3D@1427` (0.59, 0.75; 4.0)
- resta `senza nome` su `@MeshInstance3D@1429` (0.36, 0.65; 4.0)
- resta `senza nome` su `@MeshInstance3D@1431` (0.88, 0.55; 4.0)
- resta `senza nome` su `@MeshInstance3D@1447` (0.08, 0.85; 4.0)
- scende `senza nome` su `PlafonieraBimbi/@MeshInstance3D@1524` (0.09, 0.32; 6.0)

### LuciSala/Tempesta — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLampo` (0.62, 0.26; 0.00)

### Mascotte/InsegnaJilly — 2 bianche, 0 colorate, 1 materiali

Bianche (scendono al 40%):
- `luce_dx/Faretto` (0.09, 0.58; 1.40)
- `luce_sx/Faretto` (0.09, 0.58; 1.40)

Materiali delle lampade:
- scende `lampadina` su `lampada_dx_lampadina` (0.09, 0.33; 2.0)

### Piscina/LucePortellone — 0 bianche, 1 colorate, 1 materiali

Colorate (restano com'erano):
- `LuceSubacquea` (0.08, 0.84; 3.00)

Materiali delle lampade:
- resta `senza nome` su `Anello` (0.08, 0.84; 24.0)

### Piscina/SvuotaPiscina — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `SegnalePulsante` (0.11, 0.92; 4.00)

### Player/Head — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `Camera3D/Torcia/Luce` (0.09, 0.32; 0.00) — torcia: resta com'è

### Risalita — 0 bianche, 6 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@702` (0.01, 0.88; 1.80)
- `@OmniLight3D@833` (0.01, 0.88; 1.80)
- `@OmniLight3D@835` (0.01, 0.88; 1.80)
- `@OmniLight3D@944` (0.01, 0.88; 1.80)
- `@OmniLight3D@946` (0.01, 0.88; 1.80)
- `@OmniLight3D@948` (0.01, 0.88; 1.80)

### Risalita/Fiume — 37 bianche, 12 colorate, 4 materiali

Colorate (restano com'erano):
- `Cartello1Sx/@OmniLight3D@202` (0.38, 0.90; 2.20)
- `Cartello1Dx/@OmniLight3D@210` (0.38, 0.90; 0.00)
- `Cartello2Sx/@OmniLight3D@218` (0.38, 0.90; 2.20)
- `Cartello2Dx/@OmniLight3D@226` (0.38, 0.90; 0.00)
- `Cartello3Sx/@OmniLight3D@234` (0.38, 0.90; 2.20)
- `Cartello3Dx/@OmniLight3D@242` (0.38, 0.90; 0.00)
- `@OmniLight3D@256` (0.01, 0.88; 2.60)
- `@OmniLight3D@289` (0.01, 0.88; 2.60)
- `@OmniLight3D@352` (0.01, 0.88; 2.60)
- `@OmniLight3D@386` (0.01, 0.88; 2.60)
- `@OmniLight3D@471` (0.01, 0.88; 2.60)
- `@OmniLight3D@495` (0.01, 0.88; 2.60)

Bianche (scendono al 40%):
- `@OmniLight3D@175` (0.09, 0.45; 2.20)
- `@OmniLight3D@180` (0.09, 0.45; 2.20)
- `@OmniLight3D@185` (0.09, 0.45; 2.20)
- `@OmniLight3D@188` (0.09, 0.45; 2.20)
- `FiumeLento/Paratia1/LuceDisco` (0.11, 0.30; 1.20)
- `FiumeLento/Paratia2/LuceDisco` (0.11, 0.30; 1.20)
- `FiumeLento/Paratia3/LuceDisco` (0.11, 0.30; 1.20)
- `@SpotLight3D@203` (0.11, 0.45; 0.00)
- `@SpotLight3D@211` (0.11, 0.45; 2.50)
- `@SpotLight3D@219` (0.11, 0.45; 2.50)
- `@SpotLight3D@227` (0.11, 0.45; 0.00)
- `@SpotLight3D@235` (0.11, 0.45; 0.00)
- `@SpotLight3D@243` (0.11, 0.45; 2.50)
- `@OmniLight3D@251` (0.09, 0.50; 3.00)
- `@OmniLight3D@260` (0.09, 0.50; 3.00)
- `@OmniLight3D@269` (0.09, 0.50; 3.00)
- `@OmniLight3D@277` (0.09, 0.50; 3.00)
- `@OmniLight3D@285` (0.09, 0.50; 3.00)
- `@OmniLight3D@295` (0.09, 0.50; 3.00)
- `@OmniLight3D@304` (0.09, 0.50; 3.00)
- `@OmniLight3D@312` (0.09, 0.50; 3.00)
- `@OmniLight3D@321` (0.09, 0.50; 3.00)
- `@OmniLight3D@330` (0.09, 0.50; 3.00)
- `@OmniLight3D@338` (0.09, 0.50; 3.00)
- `@OmniLight3D@346` (0.09, 0.50; 3.00)
- `@OmniLight3D@356` (0.09, 0.50; 3.00)
- `@OmniLight3D@365` (0.09, 0.50; 3.00)
- `@OmniLight3D@373` (0.09, 0.50; 3.00)
- `@OmniLight3D@382` (0.09, 0.50; 3.00)
- `@OmniLight3D@394` (0.08, 0.75; 2.50)
- `@OmniLight3D@442` (0.09, 0.50; 3.00)
- `@OmniLight3D@444` (0.09, 0.50; 3.00)
- `@OmniLight3D@446` (0.09, 0.50; 3.00)
- `@OmniLight3D@448` (0.09, 0.50; 2.50)
- `@OmniLight3D@469` (0.09, 0.50; 3.00)
- `@OmniLight3D@493` (0.09, 0.50; 3.00)
- `@OmniLight3D@497` (0.09, 0.50; 2.50)

Materiali delle lampade:
- scende `senza nome` su `Cartello1Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `Cartello2Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `Cartello3Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `lampada_gabbia/globo` (0.09, 0.65; 3.0)

### Risalita/Infermeria — 2 bianche, 7 colorate, 3 materiali

Colorate (restano com'erano):
- `@OmniLight3D@582` (0.12, 0.90; 0.00)
- `Cassetto14/Frontale/Adesivo/AloneAdesivo` (0.89, 0.70; 0.25)
- `LuceVano` (0.03, 0.50; 0.70)
- `@OmniLight3D@672` (0.01, 0.90; 1.60)
- `@OmniLight3D@674` (0.01, 0.90; 1.60)
- `@OmniLight3D@677` (0.38, 0.80; 0.35)
- `@OmniLight3D@689` (0.03, 0.30; 1.20)

Bianche (scendono al 40%):
- `Negatoscopio/@OmniLight3D@566` (0.59, 0.15; 0.04)
- `LuceNegatoscopio` (0.59, 0.18; 0.05)

Materiali delle lampade:
- resta `senza nome` su `Cassetto14/Frontale/Adesivo/@MeshInstance3D@610` (0.89, 0.70; 2.2)
- scende `senza nome` su `@MeshInstance3D@676` (0.00, 0.00; 2.5)
- scende `senza nome` su `@MeshInstance3D@688` (0.08, 0.40; 3.0)

### Sala/Architettura — 0 bianche, 0 colorate, 6 materiali

Materiali delle lampade:
- scende `M_amb_lampadina` su `sala_cartellone_mascotte_0_luce` (0.10, 0.32; 35.0)
- resta `M_amb_neon_rosa` su `sala_insegna_pesce` (0.91, 0.54; 22.0)
- resta `M_amb_neon_azzurro` su `sala_insegne_neon` (0.52, 0.46; 22.0)
- scende `M_amb_neon_giallo` su `sala_insegne_neon` (0.12, 0.52; 22.0)
- scende `M_amb_neon` su `sala_lampade` (0.44, 0.08; 28.0)
- resta `M_amb_luce_rossa` su `sala_lampade` (0.01, 0.87; 4.0)

### Sala/Dettagli — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `M_det_faro_vetro_acceso` su `det_faro` (0.10, 0.30; 25.0)

### Sala/Interattivi — 0 bianche, 0 colorate, 2 materiali

Materiali delle lampade:
- resta `M_amb_faro_giallo` su `sala_lampeggiante_portello` (0.12, 1.00; 6.0)
- resta `M_amb_faro_rosso` su `sala_lampeggiante_torre` (0.02, 0.94; 6.0)

### Sala/Luci — 40 bianche, 27 colorate, 0 materiali

Colorate (restano com'erano):
- `luce_emergenza_30` (0.00, 0.98; 5.50)
- `luce_emergenza_31` (0.00, 0.98; 5.09)
- `luce_emergenza_33` (0.00, 0.98; 5.50)
- `luce_emergenza_34` (0.00, 0.98; 5.50)
- `luce_emergenza_35` (0.00, 0.98; 5.50)
- `luce_emergenza_36` (0.00, 0.98; 5.09)
- `luce_emergenza_37` (0.00, 0.98; 5.50)
- `luce_emergenza_38` (0.00, 0.98; 5.50)
- `luce_emergenza_39` (0.00, 0.98; 5.50)
- `luce_emergenza_40` (0.00, 0.98; 5.50)
- `luce_emergenza_41` (0.00, 0.98; 5.09)
- `luce_emergenza_42` (0.00, 0.98; 5.50)
- `luce_emergenza_43` (0.00, 0.98; 5.50)
- `luce_emergenza_44` (0.00, 0.98; 5.50)
- `luce_emergenza_45` (0.00, 0.98; 5.50)
- `luce_emergenza_46` (0.00, 0.98; 5.09)
- `luce_emergenza_47` (0.00, 0.98; 5.50)
- `luce_emergenza_48` (0.00, 0.98; 5.50)
- `luce_emergenza_49` (0.00, 0.98; 5.50)
- `luce_emergenza_50` (0.00, 0.98; 5.50)
- `luce_insegna_onda` (0.52, 0.46; 1.30)
- `luce_insegna_rosa` (0.90, 0.49; 2.60)
- `luce_luna` (0.63, 0.45; 0.30)
- `luce_subacquea_0` (0.46, 0.45; 3.00)
- `luce_subacquea_1` (0.46, 0.45; 3.00)
- `luce_vasca_0` (0.55, 0.55; 2.20)
- `luce_vasca_1` (0.55, 0.55; 2.20)

Bianche (scendono al 40%):
- `luce_area_bimbi` (0.09, 0.58; 4.00)
- `luce_calda_0` (0.08, 0.64; 1.80)
- `luce_calda_1` (0.08, 0.64; 1.80)
- `luce_calda_2` (0.08, 0.64; 1.80)
- `luce_calda_4` (0.08, 0.64; 1.80)
- `luce_cartellone_0` (0.09, 0.50; 1.20)
- `luce_cartellone_1` (0.09, 0.50; 1.20)
- `luce_faro_0` (0.08, 0.20; 2.00)
- `luce_faro_1` (0.08, 0.20; 2.00)
- `luce_insegna_stella` (0.12, 0.46; 1.30)
- `luce_lampione` (0.08, 0.64; 3.50)
- `luce_neon_00` (0.42, 0.22; 3.00)
- `luce_neon_01` (0.42, 0.22; 3.00)
- `luce_neon_02` (0.42, 0.22; 3.00)
- `luce_neon_03` (0.42, 0.22; 3.00)
- `luce_neon_04` (0.42, 0.22; 3.00)
- `luce_neon_05` (0.42, 0.22; 3.00)
- `luce_neon_06` (0.42, 0.22; 3.00)
- `luce_neon_07` (0.42, 0.22; 3.00)
- `luce_neon_08` (0.42, 0.22; 3.00)
- `luce_neon_09` (0.42, 0.22; 3.00)
- `luce_neon_10` (0.42, 0.22; 3.00)
- `luce_neon_12` (0.42, 0.22; 3.00)
- `luce_neon_13` (0.42, 0.22; 3.00)
- `luce_neon_14` (0.42, 0.22; 3.00)
- `luce_neon_15` (0.42, 0.22; 3.00)
- `luce_neon_16` (0.42, 0.22; 3.00)
- `luce_neon_17` (0.42, 0.22; 3.00)
- `luce_neon_18` (0.42, 0.22; 3.00)
- `luce_neon_19` (0.42, 0.22; 3.00)
- `luce_neon_20` (0.42, 0.22; 3.00)
- `luce_neon_21` (0.42, 0.22; 3.00)
- `luce_neon_22` (0.42, 0.22; 3.00)
- `luce_neon_23` (0.42, 0.22; 3.00)
- `luce_neon_24` (0.42, 0.22; 3.00)
- `luce_neon_25` (0.42, 0.22; 3.00)
- `luce_neon_26` (0.42, 0.22; 3.00)
- `luce_neon_27` (0.42, 0.22; 3.00)
- `luce_neon_28` (0.42, 0.22; 3.00)
- `luce_neon_29` (0.42, 0.22; 3.00)

### Sala/VascaCentrale — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `M_amb_lampadina` su `amb_lampione` (0.10, 0.32; 35.0)

### Tecnici — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLeva` (0.09, 0.40; 1.60)

### Tecnici/Ambienti — 0 bianche, 103 colorate, 24 materiali

Colorate (restano com'erano):
- `CameraOnde/LUCE_nicchia_1` (0.00, 0.97; 2.40)
- `CameraOnde/LUCE_nicchia_2` (0.00, 0.97; 2.40)
- `CameraOnde/LUCE_nicchia_3` (0.00, 0.97; 2.40)
- `CameraOnde/LUCE_paratia_1` (0.00, 0.97; 2.40)
- `CameraOnde/LUCE_paratia_2` (0.00, 0.97; 2.40)
- `CameraOnde/LUCE_portello` (0.56, 0.45; 1.20)
- `CameraOnde/LUCE_rossa_l1` (0.02, 0.78; 2445.81)
- `CameraOnde/LUCE_rossa_l3` (0.02, 0.78; 2445.81)
- `CameraOnde/LUCE_rossa_l4` (0.02, 0.78; 2445.81)
- `CameraOnde/LUCE_rossa_l5` (0.02, 0.78; 2445.81)
- `CameraOnde/neon_1_neon/@OmniLight3D@1132` (0.56, 0.45; 2.20)
- `CameraOnde/emergenza_l1/@OmniLight3D@1137` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l1/@Node3D@1138/@SpotLight3D@1139` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l1/@Node3D@1138/@SpotLight3D@1140` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@OmniLight3D@1143` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@Node3D@1144/@SpotLight3D@1145` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@Node3D@1144/@SpotLight3D@1146` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@OmniLight3D@1149` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@Node3D@1150/@SpotLight3D@1151` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@Node3D@1150/@SpotLight3D@1152` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@OmniLight3D@1155` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@Node3D@1156/@SpotLight3D@1157` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@Node3D@1156/@SpotLight3D@1158` (0.00, 0.97; 2.40)
- `CameraOnde/neon_0_neon/@OmniLight3D@1542` (0.56, 0.45; 2.20)
- `CameraOnde/neon_2_neon/@OmniLight3D@1543` (0.56, 0.45; 2.20)
- `SalaPompe/LUCE_rossa_l1` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l2` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l3` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l4` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l5` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l7` (0.02, 0.78; 3261.08)
- `SalaPompe/neon_1_neon/@OmniLight3D@1133` (0.56, 0.45; 2.20)
- `SalaPompe/emergenza_l1/@OmniLight3D@1161` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l1/@Node3D@1162/@SpotLight3D@1163` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l1/@Node3D@1162/@SpotLight3D@1164` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@OmniLight3D@1167` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@Node3D@1168/@SpotLight3D@1169` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@Node3D@1168/@SpotLight3D@1170` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@OmniLight3D@1173` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@Node3D@1174/@SpotLight3D@1175` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@Node3D@1174/@SpotLight3D@1176` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@OmniLight3D@1179` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@Node3D@1180/@SpotLight3D@1181` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@Node3D@1180/@SpotLight3D@1182` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@OmniLight3D@1185` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@Node3D@1186/@SpotLight3D@1187` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@Node3D@1186/@SpotLight3D@1188` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@OmniLight3D@1191` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@Node3D@1192/@SpotLight3D@1193` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@Node3D@1192/@SpotLight3D@1194` (0.00, 0.97; 2.40)
- `SalaPompe/neon_0_neon/@OmniLight3D@1544` (0.56, 0.45; 2.20)
- `SalaPompe/neon_2_neon/@OmniLight3D@1545` (0.56, 0.45; 2.20)
- `SalaPompe/neon_3_neon/@OmniLight3D@1546` (0.56, 0.45; 2.20)
- `Raccordo/LUCE_rossa_rc1` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_rc2` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_rc3` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_c2a` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_c2b` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_c2c` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_c3a` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_c3b` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_mag_a` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_mag_b` (0.02, 0.78; 3261.08)
- `Raccordo/LUCE_rossa_t7_serranda` (0.02, 0.78; 3261.08)
- `Raccordo/LuciUscita/uscita_r1` (0.37, 0.70; 0.35)
- `Raccordo/LuciUscita/uscita_l1` (0.37, 0.70; 0.35)
- `Raccordo/LuciUscita/uscita_t` (0.37, 0.70; 0.35)
- `Raccordo/LuciUscita/uscita_c3` (0.37, 0.70; 0.35)
- `Raccordo/LuciUscita/uscita_mag` (0.37, 0.70; 0.35)
- `Raccordo/neon_rc_neon/@OmniLight3D@1134` (0.56, 0.45; 2.20)
- `Raccordo/emergenza_rc1/@OmniLight3D@1197` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc1/@Node3D@1198/@SpotLight3D@1199` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc1/@Node3D@1198/@SpotLight3D@1200` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@OmniLight3D@1203` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@Node3D@1204/@SpotLight3D@1205` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@Node3D@1204/@SpotLight3D@1206` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@OmniLight3D@1209` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@Node3D@1210/@SpotLight3D@1211` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@Node3D@1210/@SpotLight3D@1212` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@OmniLight3D@1215` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@Node3D@1216/@SpotLight3D@1217` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@Node3D@1216/@SpotLight3D@1218` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@OmniLight3D@1221` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@Node3D@1222/@SpotLight3D@1223` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@Node3D@1222/@SpotLight3D@1224` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@OmniLight3D@1227` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@Node3D@1228/@SpotLight3D@1229` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@Node3D@1228/@SpotLight3D@1230` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@OmniLight3D@1233` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@Node3D@1234/@SpotLight3D@1235` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@Node3D@1234/@SpotLight3D@1236` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@OmniLight3D@1239` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@Node3D@1240/@SpotLight3D@1241` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@Node3D@1240/@SpotLight3D@1242` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@OmniLight3D@1245` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@Node3D@1246/@SpotLight3D@1247` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@Node3D@1246/@SpotLight3D@1248` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@OmniLight3D@1251` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@Node3D@1252/@SpotLight3D@1253` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@Node3D@1252/@SpotLight3D@1254` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@OmniLight3D@1257` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@Node3D@1258/@SpotLight3D@1259` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@Node3D@1258/@SpotLight3D@1260` (0.00, 0.97; 2.40)

Materiali delle lampade:
- resta `hq_lampada_muro_vetro` su `CameraOnde/lampada_l1_vetro` (0.02, 0.85; 14.0)
- resta `luce_emergenza` su `CameraOnde/NICCHIA_1` (0.02, 0.81; 40.0)
- scende `hq_plafoniera_neon_diffusore` su `CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 5.0)
- scende `hq_plafoniera_neon_diffusore` su `CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `senza nome` su `CameraOnde/neon_0_neon/neon_0_tubi` (0.43, 0.18; 10.0)
- scende `senza nome` su `CameraOnde/neon_2_neon/neon_2_tubi` (0.43, 0.18; 5.0)
- scende `senza nome` su `CameraOnde/neon_2_neon/neon_2_tubi` (0.43, 0.18; 10.0)
- resta `hq_lampada_muro_vetro` su `SalaPompe/lampada_l1_vetro` (0.02, 0.85; 14.0)
- resta `neon_azzurro` su `SalaPompe/SALA_luci` (0.51, 0.46; 15.0)
- resta `neon_azzurro` su `SalaPompe/SALA_luci` (0.51, 0.46; 25.0)
- scende `hq_plafoniera_neon_diffusore` su `SalaPompe/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 5.0)
- scende `hq_plafoniera_neon_diffusore` su `SalaPompe/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `senza nome` su `SalaPompe/neon_0_neon/neon_0_tubi` (0.43, 0.18; 10.0)
- scende `senza nome` su `SalaPompe/neon_2_neon/neon_2_tubi` (0.43, 0.18; 10.0)
- scende `senza nome` su `SalaPompe/neon_3_neon/neon_3_tubi` (0.43, 0.18; 10.0)
- resta `hq_lampada_muro_vetro` su `Raccordo/lampada_rc1_vetro` (0.02, 0.85; 14.0)
- resta `hq_cartello_uscita_luce` su `Raccordo/ArredoRisalita/uscita_c3_luce` (0.38, 0.42; 1.5)
- resta `hq_cartello_uscita_luce` su `Raccordo/ArredoRisalita/uscita_c3_luce` (0.38, 0.42; 2.5)
- scende `hq_plafoniera_neon_diffusore` su `Raccordo/neon_rc_neon/neon_rc_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `senza nome` su `CameraOnde/neon_0_neon/neon_0_tubi` (0.43, 0.18; 5.0)
- scende `senza nome` su `SalaPompe/neon_0_neon/neon_0_tubi` (0.43, 0.18; 5.0)
- scende `senza nome` su `SalaPompe/neon_2_neon/neon_2_tubi` (0.43, 0.18; 5.0)
- scende `senza nome` su `SalaPompe/neon_3_neon/neon_3_tubi` (0.43, 0.18; 5.0)
- scende `hq_plafoniera_neon_diffusore` su `Raccordo/neon_rc_neon/neon_rc_tubo_sfarfalla` (0.43, 0.08; 5.0)

### Tecnici/LampeggianteParatia1 — 0 bianche, 3 colorate, 1 materiali

Colorate (restano com'erano):
- `@OmniLight3D@1107` (0.01, 0.97; 0.45)
- `@Node3D@1108/@SpotLight3D@1109` (0.01, 0.97; 7.50)
- `@Node3D@1108/@SpotLight3D@1110` (0.01, 0.97; 7.50)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1106` (0.01, 0.97; 3.0)

### Tecnici/Logica — 0 bianche, 3 colorate, 2 materiali

Colorate (restano com'erano):
- `SalaPompe/Monitor/LuceMonitor` (0.55, 0.35; 0.65)
- `LettoreTessera/Aspetto/Luce` (0.01, 0.95; 0.60)
- `LettoreTessera/Spia` (0.01, 0.95; 0.00)

Materiali delle lampade:
- resta `senza nome` su `SerrandaMagazzino/Graybox/Spia` (0.01, 0.90; 2.0)
- resta `senza nome` su `LettoreTessera/Aspetto/Spia` (0.01, 0.95; 2.5)

### Tecnici/LuciTecnici — 3 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `Faretto_QUADRO_strumenti` (0.57, 0.25; 1.60)
- `Faretto_QUADRO_elettrico` (0.57, 0.25; 1.60)
- `LuceMonitor` (0.60, 0.25; 1.00)

### Vasca/Medusa — 0 bianche, 0 colorate, 6 materiali

Materiali delle lampade:
- scende `M_campana` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa` (0.00, 0.00; 2.5)
- scende `M_tentacoli_bagnata` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.5)
- scende `M_tentacoli` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.0)
- scende `M_campana_interno` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 4.0)
- scende `M_ciocche` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Ciocche` (0.00, 0.00; 1.0)
- scende `M_occhio_bulbo` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Occhio` (0.00, 0.00; 1.0)

## sala_torre

Costo con questa scena caricata: 0.25 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 38 luci bianche e 167 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### @OmniLight3D@2168 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2168` (0.93, 0.68; 1.00)

### @OmniLight3D@2169 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2169` (0.93, 0.68; 1.00)

### @SpotLight3D@2170 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2170` (0.93, 0.68; 1.00)

### BambinoBalconata1/Calmo — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `agnello_calmo` su `Scheletro/Skeleton3D/agnello_calmo` (0.90, 0.82; 1.6)

### BambinoBalconata1/Rivelato — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `agnello_occhio` su `Scheletro/Skeleton3D/agnello_occhio` (0.90, 0.82; 1.6)

### BambinoBalconata3/Calmo — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `agnello_calmo` su `Scheletro/Skeleton3D/agnello_calmo` (0.90, 0.82; 1.6)

### BambinoBalconata3/Rivelato — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `agnello_occhio` su `Scheletro/Skeleton3D/agnello_occhio` (0.90, 0.82; 1.6)

### FondoPozzo — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- resta `senza nome` su `FondoPozzo` (0.93, 0.68; 3.0)

### LuceLampo — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLampo` (0.61, 0.15; 0.00)

### Luci — 21 bianche, 29 colorate, 35 materiali

Colorate (restano com'erano):
- `@OmniLight3D@1915` (0.00, 0.98; 3.50)
- `@OmniLight3D@1917` (0.00, 0.98; 3.50)
- `@OmniLight3D@1919` (0.00, 0.98; 3.50)
- `@OmniLight3D@1921` (0.00, 0.98; 3.50)
- `@OmniLight3D@1923` (0.00, 0.98; 3.50)
- `@OmniLight3D@1925` (0.00, 0.98; 3.50)
- `@OmniLight3D@1927` (0.00, 0.98; 3.50)
- `@OmniLight3D@2115` (0.37, 0.90; 1.60)
- `@SpotLight3D@2116` (0.37, 0.90; 9.00)
- `@OmniLight3D@2117` (0.37, 0.90; 1.20)
- `@OmniLight3D@2121` (0.37, 0.90; 1.60)
- `@SpotLight3D@2122` (0.37, 0.90; 9.00)
- `@OmniLight3D@2123` (0.37, 0.90; 1.20)
- `@OmniLight3D@2127` (0.37, 0.90; 1.60)
- `@SpotLight3D@2128` (0.37, 0.90; 9.00)
- `@OmniLight3D@2129` (0.37, 0.90; 1.20)
- `@OmniLight3D@2133` (0.37, 0.90; 1.60)
- `@SpotLight3D@2134` (0.37, 0.90; 9.00)
- `@OmniLight3D@2135` (0.37, 0.90; 1.20)
- `@OmniLight3D@2139` (0.37, 0.90; 1.60)
- `@SpotLight3D@2140` (0.37, 0.90; 9.00)
- `@OmniLight3D@2141` (0.37, 0.90; 1.20)
- `@OmniLight3D@2145` (0.37, 0.90; 1.60)
- `@SpotLight3D@2146` (0.37, 0.90; 9.00)
- `@OmniLight3D@2147` (0.37, 0.90; 1.20)
- `@OmniLight3D@2150` (0.00, 0.98; 0.00)
- `@OmniLight3D@2155` (0.00, 0.98; 0.00)
- `@OmniLight3D@2160` (0.00, 0.98; 0.00)
- `@OmniLight3D@2165` (0.00, 0.98; 0.00)

Bianche (scendono al 40%):
- `@OmniLight3D@1933` (0.08, 0.64; 4.00)
- `@OmniLight3D@1939` (0.08, 0.64; 4.00)
- `@OmniLight3D@1945` (0.08, 0.64; 4.00)
- `@OmniLight3D@1951` (0.08, 0.64; 4.00)
- `@OmniLight3D@1957` (0.08, 0.64; 4.00)
- `@OmniLight3D@1963` (0.08, 0.64; 4.00)
- `@OmniLight3D@1969` (0.08, 0.64; 4.00)
- `@OmniLight3D@1975` (0.08, 0.64; 4.00)
- `@SpotLight3D@1986` (0.10, 0.28; 16.00)
- `@SpotLight3D@1997` (0.10, 0.28; 16.00)
- `@SpotLight3D@2008` (0.10, 0.28; 16.00)
- `@SpotLight3D@2019` (0.10, 0.28; 16.00)
- `@SpotLight3D@2030` (0.10, 0.28; 16.00)
- `@SpotLight3D@2041` (0.10, 0.28; 16.00)
- `@SpotLight3D@2052` (0.10, 0.28; 16.00)
- `@SpotLight3D@2063` (0.10, 0.28; 16.00)
- `@SpotLight3D@2074` (0.10, 0.28; 16.00)
- `@SpotLight3D@2085` (0.10, 0.28; 16.00)
- `@OmniLight3D@2098` (0.09, 0.38; 6.00)
- `@OmniLight3D@2105` (0.09, 0.38; 6.00)
- `@OmniLight3D@2112` (0.09, 0.38; 6.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1914` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1916` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1918` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1920` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1922` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1924` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1926` (0.00, 0.98; 6.0)
- scende `senza nome` su `@MeshInstance3D@1928` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1934` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1940` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1946` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1952` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1958` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1964` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1970` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@2092` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2094` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2096` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2099` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2101` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2103` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2106` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2108` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2110` (0.08, 0.64; 9.0)
- resta `senza nome` su `LedImbocco` (0.37, 0.90; 1.8)
- resta `senza nome` su `@MeshInstance3D@2114` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2120` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2126` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2132` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2138` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2144` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2149` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2154` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2159` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2164` (0.00, 0.98; 0.3)

### Luci/@Node3D@1976 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@1979` (0.07, 0.72; 0.9)

### Luci/@Node3D@1987 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@1990` (0.07, 0.72; 0.9)

### Luci/@Node3D@1998 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2001` (0.07, 0.72; 0.9)

### Luci/@Node3D@2009 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2012` (0.07, 0.72; 0.9)

### Luci/@Node3D@2020 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2023` (0.07, 0.72; 0.9)

### Luci/@Node3D@2031 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2034` (0.07, 0.72; 0.9)

### Luci/@Node3D@2042 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2045` (0.07, 0.72; 0.9)

### Luci/@Node3D@2053 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2056` (0.07, 0.72; 0.9)

### Luci/@Node3D@2064 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2067` (0.07, 0.72; 0.9)

### Luci/@Node3D@2075 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2078` (0.07, 0.72; 0.9)

### SalaInseguimento/InseguimentoMobili — 0 bianche, 3 colorate, 3 materiali

Colorate (restano com'erano):
- `ins_paratia_0/@OmniLight3D@2227` (0.38, 0.75; 1.50)
- `ins_paratia_2/@OmniLight3D@2235` (0.38, 0.75; 1.50)
- `ins_paratia_4/@OmniLight3D@2243` (0.38, 0.75; 1.50)

Materiali delle lampade:
- resta `senza nome` su `ins_paratia_0/@MeshInstance3D@2226` (0.38, 0.75; 6.0)
- resta `senza nome` su `ins_paratia_2/@MeshInstance3D@2234` (0.38, 0.75; 6.0)
- resta `senza nome` su `ins_paratia_4/@MeshInstance3D@2242` (0.38, 0.75; 6.0)

### SalaInseguimento/InseguimentoStruttura — 0 bianche, 0 colorate, 2 materiali

Materiali delle lampade:
- resta `M_amb_faro_giallo` su `ins_A_struttura` (0.12, 1.00; 6.0)
- resta `M_amb_faro_rosso` su `ins_A_struttura` (0.02, 0.94; 6.0)

### SalaInseguimento/Lei — 0 bianche, 1 colorate, 6 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2203` (0.93, 0.68; 6.00)

Materiali delle lampade:
- scende `M_campana` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa` (0.00, 0.00; 2.5)
- scende `M_tentacoli_bagnata` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.5)
- scende `M_tentacoli` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.0)
- scende `M_campana_interno` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 4.0)
- scende `M_ciocche` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Ciocche` (0.00, 0.00; 1.0)
- scende `M_occhio_bulbo` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Occhio` (0.00, 0.00; 1.0)

### SalaInseguimento/Luci — 16 bianche, 20 colorate, 24 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2206` (0.00, 0.98; 3.50)
- `@OmniLight3D@2208` (0.00, 0.98; 3.50)
- `@OmniLight3D@2210` (0.00, 0.98; 3.50)
- `@OmniLight3D@2212` (0.00, 0.98; 3.50)
- `@OmniLight3D@2214` (0.00, 0.98; 3.50)
- `@OmniLight3D@2224` (0.38, 0.75; 2.00)
- `@SpotLight3D@2225` (0.38, 0.75; 14.00)
- `@OmniLight3D@2229` (0.00, 0.98; 0.00)
- `@SpotLight3D@2230` (0.00, 0.98; 0.00)
- `@OmniLight3D@2232` (0.38, 0.75; 2.00)
- `@SpotLight3D@2233` (0.38, 0.75; 14.00)
- `@OmniLight3D@2237` (0.00, 0.98; 0.00)
- `@SpotLight3D@2238` (0.00, 0.98; 0.00)
- `@OmniLight3D@2240` (0.38, 0.75; 2.00)
- `@SpotLight3D@2241` (0.38, 0.75; 14.00)
- `@OmniLight3D@2245` (0.00, 0.98; 0.00)
- `@SpotLight3D@2246` (0.00, 0.98; 0.00)
- `@OmniLight3D@2248` (0.38, 0.75; 3.00)
- `@Node3D@2281/@OmniLight3D@2282` (0.90, 0.84; 0.45)
- `@Node3D@2281/@OmniLight3D@2283` (0.90, 0.84; 0.45)

Bianche (scendono al 40%):
- `@OmniLight3D@2216` (0.08, 0.64; 6.50)
- `@OmniLight3D@2218` (0.08, 0.64; 6.50)
- `@OmniLight3D@2220` (0.08, 0.64; 6.50)
- `@OmniLight3D@2222` (0.08, 0.64; 6.50)
- `@OmniLight3D@2252` (0.08, 0.64; 4.00)
- `@OmniLight3D@2256` (0.43, 0.20; 4.00)
- `@OmniLight3D@2260` (0.08, 0.64; 4.00)
- `@OmniLight3D@2264` (0.08, 0.64; 4.00)
- `@OmniLight3D@2268` (0.43, 0.20; 4.00)
- `@OmniLight3D@2272` (0.08, 0.64; 4.00)
- `@OmniLight3D@2274` (0.56, 0.15; 3.00)
- `@OmniLight3D@2276` (0.56, 0.15; 3.00)
- `@SpotLight3D@2277` (0.10, 0.28; 18.00)
- `@SpotLight3D@2278` (0.10, 0.28; 18.00)
- `@SpotLight3D@2279` (0.10, 0.28; 18.00)
- `@SpotLight3D@2280` (0.10, 0.28; 18.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2205` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2207` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2209` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2211` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2213` (0.00, 0.98; 6.0)
- scende `senza nome` su `@MeshInstance3D@2215` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2217` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2219` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2221` (0.08, 0.64; 8.0)
- resta `senza nome` su `@MeshInstance3D@2223` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2228` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2231` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2236` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2239` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2244` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2247` (0.38, 0.75; 8.0)
- scende `senza nome` su `@MeshInstance3D@2251` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2255` (0.43, 0.20; 8.0)
- scende `senza nome` su `@MeshInstance3D@2259` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2263` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2267` (0.43, 0.20; 8.0)
- scende `senza nome` su `@MeshInstance3D@2271` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2273` (0.56, 0.15; 6.0)
- scende `senza nome` su `@MeshInstance3D@2275` (0.56, 0.15; 6.0)

## menu_principale

Costo con questa scena caricata: 0.23 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 10 luci bianche e 172 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### LuceEmergenzaDestra — 0 bianche, 1 colorate, 1 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2332` (0.01, 0.97; 3.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2331` (0.01, 0.97; 3.0)

### LuceEmergenzaDestra/@Node3D@2333 — 0 bianche, 2 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2334` (0.01, 0.97; 7.50)
- `@SpotLight3D@2335` (0.01, 0.97; 7.50)

### LuceEmergenzaSinistra — 0 bianche, 1 colorate, 1 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2326` (0.01, 0.97; 2.87)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2325` (0.01, 0.97; 3.8)

### LuceEmergenzaSinistra/@Node3D@2327 — 0 bianche, 2 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2328` (0.01, 0.97; 7.50)
- `@SpotLight3D@2329` (0.01, 0.97; 7.50)

### Luna — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `Luna` (0.63, 0.45; 0.12)

### Sfondo/Acqua — 2 bianche, 0 colorate, 1 materiali

Bianche (scendono al 40%):
- `insegna/luce_dx/@SpotLight3D@2410` (0.09, 0.58; 2.20)
- `insegna/luce_sx/@SpotLight3D@2411` (0.09, 0.58; 2.20)

Materiali delle lampade:
- scende `lampadina` su `insegna/lampada_dx_lampadina` (0.09, 0.33; 2.0)

### Statua — 7 bianche, 2 colorate, 0 materiali

Colorate (restano com'erano):
- `LuceCampana` (0.89, 0.64; 0.50)
- `Controluce` (0.59, 0.32; 5.00)

Bianche (scendono al 40%):
- `FaroGalleriaSinistro` (0.10, 0.24; 7.00)
- `FaroGalleriaDestro` (0.10, 0.24; 7.00)
- `FarettoBasso0` (0.10, 0.42; 1.60)
- `FarettoBasso1` (0.10, 0.42; 1.60)
- `FarettoBasso2` (0.10, 0.42; 1.60)
- `FarettoBasso3` (0.10, 0.42; 1.60)
- `LuceViso` (0.10, 0.12; 3.20)

### Statua/Medusa — 0 bianche, 0 colorate, 7 materiali

Materiali delle lampade:
- scende `M_campana` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa` (0.00, 0.00; 2.5)
- scende `M_tentacoli` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.0)
- scende `M_campana_interno` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 4.0)
- scende `M_ciocche` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Ciocche` (0.00, 0.00; 1.0)
- scende `M_occhio_bulbo` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Occhio` (0.00, 0.00; 1.0)
- scende `M_tentacoli` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` (0.00, 0.00; 1.5)
- scende `M_tentacoli` su `Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` (0.00, 0.00; 1.5)

### Statua/Piedistallo — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `M_amb_lampadina` su `Sala/amb_piedistallo` (0.10, 0.32; 35.0)

### Tempesta — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLampo` (0.62, 0.26; 0.00)
