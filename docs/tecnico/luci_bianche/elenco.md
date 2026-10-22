# Luci bianche al 40%: come sono classificate, zona per zona

Scritto da `godot/proposte/mascotte/elenco_luci_bianche.gd`. Regola (`scripts/game/luci_bianche.gd`): bianca se la saturazione è al più 0.30; bianco-calda se la tinta è fra 0.045 e 0.17 (arancio-giallo) e la saturazione al più 0.76. Tutto il resto è colorato e resta com'è. Jilly, le creature, le statue e gli oggetti di gioco restano com'erano. Materiali: solo delle lampade vere (nome da lampada, o mesh piccola vicino a una luce), emissione accesa (almeno 0.3) dello stesso colore. Fra parentesi il colore (tinta, saturazione) e l'energia piena.

## sala_principale

Costo con questa scena caricata: 0.59 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 99 luci bianche e 69 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### Gioco/EnigmaAcquari — 7 bianche, 0 colorate, 1 materiali

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

### Gioco/PortoneTorre — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `LuceLampeggiante` (0.01, 0.94; 0.00)

### Interni — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceZaino` (0.09, 0.58; 2.60)

### Interni/Ambienti — 3 bianche, 64 colorate, 25 materiali

Colorate (restano com'erano):
- `Corridoio/luce_emergenza_01_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_02_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_03_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_04_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_05_luce` (0.01, 0.89; 1195.73)
- `Corridoio/luce_emergenza_06_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_07_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_08_luce` (0.01, 0.89; 1739.25)
- `Corridoio/luce_emergenza_01_rossa/@OmniLight3D@1009` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_01_rossa/@Node3D@1010/@SpotLight3D@1011` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_01_rossa/@Node3D@1010/@SpotLight3D@1012` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_02_rossa/@OmniLight3D@1015` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_02_rossa/@Node3D@1016/@SpotLight3D@1017` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_02_rossa/@Node3D@1016/@SpotLight3D@1018` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_03_rossa/@OmniLight3D@1021` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_03_rossa/@Node3D@1022/@SpotLight3D@1023` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_03_rossa/@Node3D@1022/@SpotLight3D@1024` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_04_rossa/@OmniLight3D@1027` (0.00, 0.97; 1.28)
- `Corridoio/luce_emergenza_04_rossa/@Node3D@1028/@SpotLight3D@1029` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_04_rossa/@Node3D@1028/@SpotLight3D@1030` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_05_rossa/@OmniLight3D@1033` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_05_rossa/@Node3D@1034/@SpotLight3D@1035` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_05_rossa/@Node3D@1034/@SpotLight3D@1036` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_06_rossa/@OmniLight3D@1039` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_06_rossa/@Node3D@1040/@SpotLight3D@1041` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_06_rossa/@Node3D@1040/@SpotLight3D@1042` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_07_rossa/@OmniLight3D@1045` (0.00, 0.97; 2.80)
- `Corridoio/luce_emergenza_07_rossa/@Node3D@1046/@SpotLight3D@1047` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_07_rossa/@Node3D@1046/@SpotLight3D@1048` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_08_rossa/@OmniLight3D@1051` (0.00, 0.97; 1.28)
- `Corridoio/luce_emergenza_08_rossa/@Node3D@1052/@SpotLight3D@1053` (0.01, 0.97; 5.00)
- `Corridoio/luce_emergenza_08_rossa/@Node3D@1052/@SpotLight3D@1054` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_01_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_02_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_03_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_04_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_05_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_06_luce` (0.01, 0.89; 2174.06)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@OmniLight3D@1057` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@Node3D@1058/@SpotLight3D@1059` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@Node3D@1058/@SpotLight3D@1060` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@OmniLight3D@1063` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@Node3D@1064/@SpotLight3D@1065` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@Node3D@1064/@SpotLight3D@1066` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@OmniLight3D@1069` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@Node3D@1070/@SpotLight3D@1071` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@Node3D@1070/@SpotLight3D@1072` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@OmniLight3D@1075` (0.00, 0.97; 1.28)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@Node3D@1076/@SpotLight3D@1077` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@Node3D@1076/@SpotLight3D@1078` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@OmniLight3D@1081` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@Node3D@1082/@SpotLight3D@1083` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@Node3D@1082/@SpotLight3D@1084` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@OmniLight3D@1087` (0.00, 0.97; 2.80)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@Node3D@1088/@SpotLight3D@1089` (0.01, 0.97; 5.00)
- `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@Node3D@1088/@SpotLight3D@1090` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_01_luce` (0.01, 0.89; 1630.54)
- `Stanzino/luce_emergenza_stanzino_02_luce` (0.01, 0.89; 1195.73)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@OmniLight3D@1093` (0.00, 0.97; 2.80)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@Node3D@1094/@SpotLight3D@1095` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_01_rossa/@Node3D@1094/@SpotLight3D@1096` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@OmniLight3D@1099` (0.00, 0.97; 1.28)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@Node3D@1100/@SpotLight3D@1101` (0.01, 0.97; 5.00)
- `Stanzino/luce_emergenza_stanzino_02_rossa/@Node3D@1100/@SpotLight3D@1102` (0.01, 0.97; 5.00)

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `Spogliatoi/luce_pulsante_tornello` (0.03, 0.69; 0.40)

Bianche (scendono al 40%):
- `Corridoio/neon_corridoio_2_neon/@OmniLight3D@1004` (0.44, 0.22; 6.00)
- `Spogliatoi/neon_spogliatoi_1_neon/@OmniLight3D@1005` (0.44, 0.22; 6.00)
- `Stanzino/neon_stanzino_neon/@OmniLight3D@1006` (0.44, 0.22; 4.80)

Materiali delle lampade:
- resta `hq_lampada_muro_vetro` su `Corridoio/luce_emergenza_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Corridoio/neon_corridoio_1_tubi` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Corridoio/neon_corridoio_2_neon/neon_corridoio_2_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Corridoio/luce_emergenza_01_rossa/@MeshInstance3D@1008` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_02_rossa/@MeshInstance3D@1014` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_03_rossa/@MeshInstance3D@1020` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_04_rossa/@MeshInstance3D@1026` (0.01, 0.97; 1.8)
- resta `senza nome` su `Corridoio/luce_emergenza_05_rossa/@MeshInstance3D@1032` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_06_rossa/@MeshInstance3D@1038` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_07_rossa/@MeshInstance3D@1044` (0.01, 0.97; 3.0)
- resta `senza nome` su `Corridoio/luce_emergenza_08_rossa/@MeshInstance3D@1050` (0.01, 0.97; 1.8)
- resta `hq_lampada_muro_vetro` su `Spogliatoi/luce_emergenza_spogliatoi_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Spogliatoi/neon_spogliatoi_2_tubi` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Spogliatoi/neon_spogliatoi_1_neon/neon_spogliatoi_1_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_01_rossa/@MeshInstance3D@1056` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_02_rossa/@MeshInstance3D@1062` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_03_rossa/@MeshInstance3D@1068` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_04_rossa/@MeshInstance3D@1074` (0.01, 0.97; 1.8)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_05_rossa/@MeshInstance3D@1080` (0.01, 0.97; 3.0)
- resta `senza nome` su `Spogliatoi/luce_emergenza_spogliatoi_06_rossa/@MeshInstance3D@1086` (0.01, 0.97; 3.0)
- resta `hq_lampada_muro_vetro` su `Stanzino/luce_emergenza_stanzino_01_vetro` (0.02, 0.85; 14.0)
- scende `hq_plafoniera_neon_diffusore` su `Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `hq_plafoniera_neon_diffusore` su `Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` (0.43, 0.08; 10.0)
- resta `senza nome` su `Stanzino/luce_emergenza_stanzino_01_rossa/@MeshInstance3D@1092` (0.01, 0.97; 3.0)
- resta `senza nome` su `Stanzino/luce_emergenza_stanzino_02_rossa/@MeshInstance3D@1098` (0.01, 0.97; 1.8)

### Interni/LampadaTornelli — 1 bianche, 0 colorate, 1 materiali

Bianche (scendono al 40%):
- `Luce` (0.44, 0.22; 6.00)

Materiali delle lampade:
- scende `hq_plafoniera_neon_diffusore` su `lampada_tubi` (0.43, 0.08; 10.0)

### LuciSala — 0 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `ControluceStatua` (0.60, 0.38; 5.00)

### LuciSala/LuciAreaBimbi — 1 bianche, 12 colorate, 7 materiali

Colorate (restano com'erano):
- `@OmniLight3D@1446` (0.12, 0.80; 1.10)
- `@OmniLight3D@1453` (0.88, 0.55; 1.10)
- `@OmniLight3D@1466` (0.88, 0.55; 1.10)
- `@OmniLight3D@1479` (0.88, 0.55; 1.10)
- `@OmniLight3D@1486` (0.12, 0.80; 1.10)
- `@OmniLight3D@1499` (0.12, 0.80; 1.10)
- `@OmniLight3D@1506` (0.88, 0.55; 1.10)
- `@OmniLight3D@1513` (0.12, 0.80; 1.10)
- `@OmniLight3D@1520` (0.88, 0.55; 1.10)
- `@OmniLight3D@1527` (0.12, 0.80; 1.10)
- `@OmniLight3D@1534` (0.88, 0.55; 1.10)
- `@OmniLight3D@1541` (0.12, 0.80; 1.10)

Bianche (scendono al 40%):
- `PlafonieraBimbi/@SpotLight3D@1547` (0.09, 0.32; 7.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1443` (0.99, 0.75; 4.0)
- resta `senza nome` su `@MeshInstance3D@1445` (0.12, 0.80; 4.0)
- resta `senza nome` su `@MeshInstance3D@1448` (0.59, 0.75; 4.0)
- resta `senza nome` su `@MeshInstance3D@1450` (0.36, 0.65; 4.0)
- resta `senza nome` su `@MeshInstance3D@1452` (0.88, 0.55; 4.0)
- resta `senza nome` su `@MeshInstance3D@1468` (0.08, 0.85; 4.0)
- scende `senza nome` su `PlafonieraBimbi/@MeshInstance3D@1545` (0.09, 0.32; 6.0)

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

### Piscina/SvuotaPiscina — 0 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `SegnalePulsante` (0.11, 0.92; 4.00)

### Player/Head — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `Camera3D/Torcia/Luce` (0.09, 0.32; 0.00) — torcia: resta com'è

### Risalita — 0 bianche, 6 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@723` (0.01, 0.88; 1.80)
- `@OmniLight3D@854` (0.01, 0.88; 1.80)
- `@OmniLight3D@856` (0.01, 0.88; 1.80)
- `@OmniLight3D@965` (0.01, 0.88; 1.80)
- `@OmniLight3D@967` (0.01, 0.88; 1.80)
- `@OmniLight3D@969` (0.01, 0.88; 1.80)

### Risalita/Fiume — 37 bianche, 12 colorate, 4 materiali

Colorate (restano com'erano):
- `Cartello1Sx/@OmniLight3D@210` (0.38, 0.90; 2.20)
- `Cartello1Dx/@OmniLight3D@222` (0.38, 0.90; 0.00)
- `Cartello2Sx/@OmniLight3D@234` (0.38, 0.90; 2.20)
- `Cartello2Dx/@OmniLight3D@246` (0.38, 0.90; 0.00)
- `Cartello3Sx/@OmniLight3D@258` (0.38, 0.90; 2.20)
- `Cartello3Dx/@OmniLight3D@270` (0.38, 0.90; 0.00)
- `@OmniLight3D@280` (0.01, 0.88; 2.60)
- `@OmniLight3D@302` (0.01, 0.88; 2.60)
- `@OmniLight3D@341` (0.01, 0.88; 2.60)
- `@OmniLight3D@363` (0.01, 0.88; 2.60)
- `@OmniLight3D@468` (0.01, 0.88; 2.60)
- `@OmniLight3D@488` (0.01, 0.88; 2.60)

Bianche (scendono al 40%):
- `@OmniLight3D@178` (0.09, 0.45; 2.20)
- `@OmniLight3D@183` (0.09, 0.45; 2.20)
- `@OmniLight3D@188` (0.09, 0.45; 2.20)
- `@OmniLight3D@191` (0.09, 0.45; 2.20)
- `FiumeLento/Paratia1/LuceDisco` (0.11, 0.30; 1.20)
- `FiumeLento/Paratia2/LuceDisco` (0.11, 0.30; 1.20)
- `FiumeLento/Paratia3/LuceDisco` (0.11, 0.30; 1.20)
- `@SpotLight3D@211` (0.11, 0.45; 0.00)
- `@SpotLight3D@223` (0.11, 0.45; 2.50)
- `@SpotLight3D@235` (0.11, 0.45; 2.50)
- `@SpotLight3D@247` (0.11, 0.45; 0.00)
- `@SpotLight3D@259` (0.11, 0.45; 0.00)
- `@SpotLight3D@271` (0.11, 0.45; 2.50)
- `@OmniLight3D@277` (0.09, 0.50; 3.00)
- `@OmniLight3D@283` (0.09, 0.50; 3.00)
- `@OmniLight3D@289` (0.09, 0.50; 3.00)
- `@OmniLight3D@294` (0.09, 0.50; 3.00)
- `@OmniLight3D@299` (0.09, 0.50; 3.00)
- `@OmniLight3D@306` (0.09, 0.50; 3.00)
- `@OmniLight3D@312` (0.09, 0.50; 3.00)
- `@OmniLight3D@317` (0.09, 0.50; 3.00)
- `@OmniLight3D@322` (0.09, 0.50; 3.00)
- `@OmniLight3D@327` (0.09, 0.50; 3.00)
- `@OmniLight3D@332` (0.09, 0.50; 3.00)
- `@OmniLight3D@337` (0.09, 0.50; 3.00)
- `@OmniLight3D@344` (0.09, 0.50; 3.00)
- `@OmniLight3D@349` (0.09, 0.50; 3.00)
- `@OmniLight3D@354` (0.09, 0.50; 3.00)
- `@OmniLight3D@360` (0.09, 0.50; 3.00)
- `@OmniLight3D@415` (0.08, 0.75; 2.50)
- `@OmniLight3D@443` (0.09, 0.50; 3.00)
- `@OmniLight3D@445` (0.09, 0.50; 3.00)
- `@OmniLight3D@447` (0.09, 0.50; 3.00)
- `@OmniLight3D@449` (0.09, 0.50; 2.50)
- `@OmniLight3D@466` (0.09, 0.50; 3.00)
- `@OmniLight3D@486` (0.09, 0.50; 3.00)
- `@OmniLight3D@490` (0.09, 0.50; 2.50)

Materiali delle lampade:
- scende `senza nome` su `Cartello1Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `Cartello2Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `Cartello3Sx/Faccia` (0.00, 0.00; 3.0)
- scende `senza nome` su `lampada_gabbia/globo` (0.09, 0.65; 3.0)

### Risalita/Infermeria — 0 bianche, 6 colorate, 2 materiali

Colorate (restano com'erano):
- `@OmniLight3D@577` (0.12, 0.90; 0.00)
- `LuceVano` (0.03, 0.50; 0.70)
- `@OmniLight3D@683` (0.01, 0.90; 1.60)
- `@OmniLight3D@685` (0.01, 0.90; 1.60)
- `@OmniLight3D@688` (0.38, 0.80; 0.35)
- `@OmniLight3D@700` (0.03, 0.30; 1.20)

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `Negatoscopio/@OmniLight3D@561` (0.59, 0.15; 0.04)
- `LuceNegatoscopio` (0.59, 0.18; 0.05)
- `Cassetto14/Frontale/Adesivo/AloneAdesivo` (0.89, 0.70; 0.25)

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@687` (0.00, 0.00; 2.5)
- scende `senza nome` su `@MeshInstance3D@699` (0.08, 0.40; 3.0)

### Sala/Architettura — 0 bianche, 0 colorate, 2 materiali

Materiali delle lampade:
- scende `M_amb_lampadina` su `sala_cartellone_mascotte_0_luce` (0.10, 0.32; 35.0)
- scende `M_amb_neon` su `sala_lampade` (0.44, 0.08; 28.0)

### Sala/Dettagli — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `M_det_faro_vetro_acceso` su `det_faro` (0.10, 0.30; 25.0)

### Sala/Luci — 40 bianche, 27 colorate, 0 materiali

Colorate (restano com'erano):
- `luce_emergenza_30` (0.00, 0.98; 5.50)
- `luce_emergenza_31` (0.00, 0.98; 1.56)
- `luce_emergenza_33` (0.00, 0.98; 5.50)
- `luce_emergenza_34` (0.00, 0.98; 5.50)
- `luce_emergenza_35` (0.00, 0.98; 5.50)
- `luce_emergenza_36` (0.00, 0.98; 1.56)
- `luce_emergenza_37` (0.00, 0.98; 5.50)
- `luce_emergenza_38` (0.00, 0.98; 5.50)
- `luce_emergenza_39` (0.00, 0.98; 5.50)
- `luce_emergenza_40` (0.00, 0.98; 5.50)
- `luce_emergenza_41` (0.00, 0.98; 1.56)
- `luce_emergenza_42` (0.00, 0.98; 5.50)
- `luce_emergenza_43` (0.00, 0.98; 5.50)
- `luce_emergenza_44` (0.00, 0.98; 5.50)
- `luce_emergenza_45` (0.00, 0.98; 5.50)
- `luce_emergenza_46` (0.00, 0.98; 1.56)
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

### Tecnici/Ambienti — 0 bianche, 103 colorate, 22 materiali

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
- `CameraOnde/neon_1_neon/@OmniLight3D@1153` (0.56, 0.45; 2.20)
- `CameraOnde/emergenza_l1/@OmniLight3D@1158` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l1/@Node3D@1159/@SpotLight3D@1160` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l1/@Node3D@1159/@SpotLight3D@1161` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@OmniLight3D@1164` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@Node3D@1165/@SpotLight3D@1166` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l3/@Node3D@1165/@SpotLight3D@1167` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@OmniLight3D@1170` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@Node3D@1171/@SpotLight3D@1172` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l4/@Node3D@1171/@SpotLight3D@1173` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@OmniLight3D@1176` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@Node3D@1177/@SpotLight3D@1178` (0.00, 0.97; 2.40)
- `CameraOnde/emergenza_l5/@Node3D@1177/@SpotLight3D@1179` (0.00, 0.97; 2.40)
- `CameraOnde/neon_0_neon/@OmniLight3D@1563` (0.56, 0.45; 2.20)
- `CameraOnde/neon_2_neon/@OmniLight3D@1564` (0.56, 0.45; 2.20)
- `SalaPompe/LUCE_rossa_l1` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l2` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l3` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l4` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l5` (0.02, 0.78; 3261.08)
- `SalaPompe/LUCE_rossa_l7` (0.02, 0.78; 3261.08)
- `SalaPompe/neon_1_neon/@OmniLight3D@1154` (0.56, 0.45; 2.20)
- `SalaPompe/emergenza_l1/@OmniLight3D@1182` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l1/@Node3D@1183/@SpotLight3D@1184` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l1/@Node3D@1183/@SpotLight3D@1185` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@OmniLight3D@1188` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@Node3D@1189/@SpotLight3D@1190` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l2/@Node3D@1189/@SpotLight3D@1191` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@OmniLight3D@1194` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@Node3D@1195/@SpotLight3D@1196` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l3/@Node3D@1195/@SpotLight3D@1197` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@OmniLight3D@1200` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@Node3D@1201/@SpotLight3D@1202` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l4/@Node3D@1201/@SpotLight3D@1203` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@OmniLight3D@1206` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@Node3D@1207/@SpotLight3D@1208` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l5/@Node3D@1207/@SpotLight3D@1209` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@OmniLight3D@1212` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@Node3D@1213/@SpotLight3D@1214` (0.00, 0.97; 2.40)
- `SalaPompe/emergenza_l7/@Node3D@1213/@SpotLight3D@1215` (0.00, 0.97; 2.40)
- `SalaPompe/neon_0_neon/@OmniLight3D@1565` (0.56, 0.45; 2.20)
- `SalaPompe/neon_2_neon/@OmniLight3D@1566` (0.56, 0.45; 2.20)
- `SalaPompe/neon_3_neon/@OmniLight3D@1567` (0.56, 0.45; 2.20)
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
- `Raccordo/neon_rc_neon/@OmniLight3D@1155` (0.56, 0.45; 2.20)
- `Raccordo/emergenza_rc1/@OmniLight3D@1218` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc1/@Node3D@1219/@SpotLight3D@1220` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc1/@Node3D@1219/@SpotLight3D@1221` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@OmniLight3D@1224` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@Node3D@1225/@SpotLight3D@1226` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc2/@Node3D@1225/@SpotLight3D@1227` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@OmniLight3D@1230` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@Node3D@1231/@SpotLight3D@1232` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_rc3/@Node3D@1231/@SpotLight3D@1233` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@OmniLight3D@1236` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@Node3D@1237/@SpotLight3D@1238` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2a/@Node3D@1237/@SpotLight3D@1239` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@OmniLight3D@1242` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@Node3D@1243/@SpotLight3D@1244` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2b/@Node3D@1243/@SpotLight3D@1245` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@OmniLight3D@1248` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@Node3D@1249/@SpotLight3D@1250` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c2c/@Node3D@1249/@SpotLight3D@1251` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@OmniLight3D@1254` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@Node3D@1255/@SpotLight3D@1256` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3a/@Node3D@1255/@SpotLight3D@1257` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@OmniLight3D@1260` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@Node3D@1261/@SpotLight3D@1262` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_c3b/@Node3D@1261/@SpotLight3D@1263` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@OmniLight3D@1266` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@Node3D@1267/@SpotLight3D@1268` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_a/@Node3D@1267/@SpotLight3D@1269` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@OmniLight3D@1272` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@Node3D@1273/@SpotLight3D@1274` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_mag_b/@Node3D@1273/@SpotLight3D@1275` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@OmniLight3D@1278` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@Node3D@1279/@SpotLight3D@1280` (0.00, 0.97; 2.40)
- `Raccordo/emergenza_t7_serranda/@Node3D@1279/@SpotLight3D@1281` (0.00, 0.97; 2.40)

Materiali delle lampade:
- resta `hq_lampada_muro_vetro` su `CameraOnde/lampada_l1_vetro` (0.02, 0.85; 14.0)
- resta `luce_emergenza` su `CameraOnde/NICCHIA_1` (0.02, 0.81; 40.0)
- scende `hq_plafoniera_neon_diffusore` su `CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 5.0)
- scende `hq_plafoniera_neon_diffusore` su `CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` (0.43, 0.08; 10.0)
- scende `senza nome` su `CameraOnde/neon_0_neon/neon_0_tubi` (0.43, 0.18; 10.0)
- scende `senza nome` su `CameraOnde/neon_2_neon/neon_2_tubi` (0.43, 0.18; 5.0)
- scende `senza nome` su `CameraOnde/neon_2_neon/neon_2_tubi` (0.43, 0.18; 10.0)
- resta `hq_lampada_muro_vetro` su `SalaPompe/lampada_l1_vetro` (0.02, 0.85; 14.0)
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
- `@OmniLight3D@1128` (0.01, 0.97; 0.45)
- `@Node3D@1129/@SpotLight3D@1130` (0.01, 0.97; 7.50)
- `@Node3D@1129/@SpotLight3D@1131` (0.01, 0.97; 7.50)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1127` (0.01, 0.97; 3.0)

### Tecnici/Logica — 0 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `SalaPompe/Monitor/LuceMonitor` (0.55, 0.35; 0.65)
- `LettoreTessera/Aspetto/Luce` (0.01, 0.95; 0.60)
- `LettoreTessera/Spia` (0.01, 0.95; 0.00)

### Tecnici/LuciTecnici — 2 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `LuceMonitor` (0.60, 0.25; 1.00)

Bianche (scendono al 40%):
- `Faretto_QUADRO_strumenti` (0.57, 0.25; 1.60)
- `Faretto_QUADRO_elettrico` (0.57, 0.25; 1.60)

## sala_torre

Costo con questa scena caricata: 0.33 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 38 luci bianche e 141 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### @OmniLight3D@2199 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2199` (0.93, 0.68; 1.00)

### @OmniLight3D@2200 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2200` (0.93, 0.68; 1.00)

### @SpotLight3D@2201 — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2201` (0.93, 0.68; 1.00)

### LuceLampo — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLampo` (0.61, 0.15; 0.00)

### Luci — 21 bianche, 29 colorate, 35 materiali

Colorate (restano com'erano):
- `@OmniLight3D@1946` (0.00, 0.98; 3.50)
- `@OmniLight3D@1948` (0.00, 0.98; 3.50)
- `@OmniLight3D@1950` (0.00, 0.98; 3.50)
- `@OmniLight3D@1952` (0.00, 0.98; 3.50)
- `@OmniLight3D@1954` (0.00, 0.98; 3.50)
- `@OmniLight3D@1956` (0.00, 0.98; 3.50)
- `@OmniLight3D@1958` (0.00, 0.98; 3.50)
- `@OmniLight3D@2146` (0.37, 0.90; 1.60)
- `@SpotLight3D@2147` (0.37, 0.90; 9.00)
- `@OmniLight3D@2148` (0.37, 0.90; 1.20)
- `@OmniLight3D@2152` (0.37, 0.90; 1.60)
- `@SpotLight3D@2153` (0.37, 0.90; 9.00)
- `@OmniLight3D@2154` (0.37, 0.90; 1.20)
- `@OmniLight3D@2158` (0.37, 0.90; 1.60)
- `@SpotLight3D@2159` (0.37, 0.90; 9.00)
- `@OmniLight3D@2160` (0.37, 0.90; 1.20)
- `@OmniLight3D@2164` (0.37, 0.90; 1.60)
- `@SpotLight3D@2165` (0.37, 0.90; 9.00)
- `@OmniLight3D@2166` (0.37, 0.90; 1.20)
- `@OmniLight3D@2170` (0.37, 0.90; 1.60)
- `@SpotLight3D@2171` (0.37, 0.90; 9.00)
- `@OmniLight3D@2172` (0.37, 0.90; 1.20)
- `@OmniLight3D@2176` (0.37, 0.90; 1.60)
- `@SpotLight3D@2177` (0.37, 0.90; 9.00)
- `@OmniLight3D@2178` (0.37, 0.90; 1.20)
- `@OmniLight3D@2181` (0.00, 0.98; 0.00)
- `@OmniLight3D@2186` (0.00, 0.98; 0.00)
- `@OmniLight3D@2191` (0.00, 0.98; 0.00)
- `@OmniLight3D@2196` (0.00, 0.98; 0.00)

Bianche (scendono al 40%):
- `@OmniLight3D@1964` (0.08, 0.64; 4.00)
- `@OmniLight3D@1970` (0.08, 0.64; 4.00)
- `@OmniLight3D@1976` (0.08, 0.64; 4.00)
- `@OmniLight3D@1982` (0.08, 0.64; 4.00)
- `@OmniLight3D@1988` (0.08, 0.64; 4.00)
- `@OmniLight3D@1994` (0.08, 0.64; 4.00)
- `@OmniLight3D@2000` (0.08, 0.64; 4.00)
- `@OmniLight3D@2006` (0.08, 0.64; 4.00)
- `@SpotLight3D@2017` (0.10, 0.28; 16.00)
- `@SpotLight3D@2028` (0.10, 0.28; 16.00)
- `@SpotLight3D@2039` (0.10, 0.28; 16.00)
- `@SpotLight3D@2050` (0.10, 0.28; 16.00)
- `@SpotLight3D@2061` (0.10, 0.28; 16.00)
- `@SpotLight3D@2072` (0.10, 0.28; 16.00)
- `@SpotLight3D@2083` (0.10, 0.28; 16.00)
- `@SpotLight3D@2094` (0.10, 0.28; 16.00)
- `@SpotLight3D@2105` (0.10, 0.28; 16.00)
- `@SpotLight3D@2116` (0.10, 0.28; 16.00)
- `@OmniLight3D@2129` (0.09, 0.38; 6.00)
- `@OmniLight3D@2136` (0.09, 0.38; 6.00)
- `@OmniLight3D@2143` (0.09, 0.38; 6.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@1945` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1947` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1949` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1951` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1953` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1955` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@1957` (0.00, 0.98; 6.0)
- scende `senza nome` su `@MeshInstance3D@1959` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1965` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1971` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1977` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1983` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1989` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@1995` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@2001` (0.07, 0.75; 1.2)
- scende `senza nome` su `@MeshInstance3D@2123` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2125` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2127` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2130` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2132` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2134` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2137` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2139` (0.08, 0.64; 9.0)
- scende `senza nome` su `@MeshInstance3D@2141` (0.08, 0.64; 9.0)
- resta `senza nome` su `LedImbocco` (0.37, 0.90; 1.8)
- resta `senza nome` su `@MeshInstance3D@2145` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2151` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2157` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2163` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2169` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2175` (0.37, 0.90; 2.2)
- resta `senza nome` su `@MeshInstance3D@2180` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2185` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2190` (0.00, 0.98; 0.3)
- resta `senza nome` su `@MeshInstance3D@2195` (0.00, 0.98; 0.3)

### Luci/@Node3D@2007 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2010` (0.07, 0.72; 0.9)

### Luci/@Node3D@2018 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2021` (0.07, 0.72; 0.9)

### Luci/@Node3D@2029 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2032` (0.07, 0.72; 0.9)

### Luci/@Node3D@2040 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2043` (0.07, 0.72; 0.9)

### Luci/@Node3D@2051 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2054` (0.07, 0.72; 0.9)

### Luci/@Node3D@2062 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2065` (0.07, 0.72; 0.9)

### Luci/@Node3D@2073 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2076` (0.07, 0.72; 0.9)

### Luci/@Node3D@2084 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2087` (0.07, 0.72; 0.9)

### Luci/@Node3D@2095 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2098` (0.07, 0.72; 0.9)

### Luci/@Node3D@2106 — 0 bianche, 0 colorate, 1 materiali

Materiali delle lampade:
- scende `senza nome` su `@MeshInstance3D@2109` (0.07, 0.72; 0.9)

### SalaInseguimento/InseguimentoMobili — 0 bianche, 3 colorate, 3 materiali

Colorate (restano com'erano):
- `ins_paratia_0/@OmniLight3D@2258` (0.38, 0.75; 1.50)
- `ins_paratia_2/@OmniLight3D@2266` (0.38, 0.75; 1.50)
- `ins_paratia_4/@OmniLight3D@2274` (0.38, 0.75; 1.50)

Materiali delle lampade:
- resta `senza nome` su `ins_paratia_0/@MeshInstance3D@2257` (0.38, 0.75; 6.0)
- resta `senza nome` su `ins_paratia_2/@MeshInstance3D@2265` (0.38, 0.75; 6.0)
- resta `senza nome` su `ins_paratia_4/@MeshInstance3D@2273` (0.38, 0.75; 6.0)

### SalaInseguimento/Lei — 0 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `@OmniLight3D@2234` (0.93, 0.68; 6.00)

### SalaInseguimento/Luci — 16 bianche, 20 colorate, 24 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2237` (0.00, 0.98; 3.50)
- `@OmniLight3D@2239` (0.00, 0.98; 3.50)
- `@OmniLight3D@2241` (0.00, 0.98; 3.50)
- `@OmniLight3D@2243` (0.00, 0.98; 3.50)
- `@OmniLight3D@2245` (0.00, 0.98; 3.50)
- `@OmniLight3D@2255` (0.38, 0.75; 2.00)
- `@SpotLight3D@2256` (0.38, 0.75; 14.00)
- `@OmniLight3D@2260` (0.00, 0.98; 0.00)
- `@SpotLight3D@2261` (0.00, 0.98; 0.00)
- `@OmniLight3D@2263` (0.38, 0.75; 2.00)
- `@SpotLight3D@2264` (0.38, 0.75; 14.00)
- `@OmniLight3D@2268` (0.00, 0.98; 0.00)
- `@SpotLight3D@2269` (0.00, 0.98; 0.00)
- `@OmniLight3D@2271` (0.38, 0.75; 2.00)
- `@SpotLight3D@2272` (0.38, 0.75; 14.00)
- `@OmniLight3D@2276` (0.00, 0.98; 0.00)
- `@SpotLight3D@2277` (0.00, 0.98; 0.00)
- `@OmniLight3D@2279` (0.38, 0.75; 3.00)
- `@Node3D@2312/@OmniLight3D@2313` (0.90, 0.84; 0.45)
- `@Node3D@2312/@OmniLight3D@2314` (0.90, 0.84; 0.45)

Bianche (scendono al 40%):
- `@OmniLight3D@2247` (0.08, 0.64; 6.50)
- `@OmniLight3D@2249` (0.08, 0.64; 6.50)
- `@OmniLight3D@2251` (0.08, 0.64; 6.50)
- `@OmniLight3D@2253` (0.08, 0.64; 6.50)
- `@OmniLight3D@2283` (0.08, 0.64; 4.00)
- `@OmniLight3D@2287` (0.43, 0.20; 4.00)
- `@OmniLight3D@2291` (0.08, 0.64; 4.00)
- `@OmniLight3D@2295` (0.08, 0.64; 4.00)
- `@OmniLight3D@2299` (0.43, 0.20; 4.00)
- `@OmniLight3D@2303` (0.08, 0.64; 4.00)
- `@OmniLight3D@2305` (0.56, 0.15; 3.00)
- `@OmniLight3D@2307` (0.56, 0.15; 3.00)
- `@SpotLight3D@2308` (0.10, 0.28; 18.00)
- `@SpotLight3D@2309` (0.10, 0.28; 18.00)
- `@SpotLight3D@2310` (0.10, 0.28; 18.00)
- `@SpotLight3D@2311` (0.10, 0.28; 18.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2236` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2238` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2240` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2242` (0.00, 0.98; 6.0)
- resta `senza nome` su `@MeshInstance3D@2244` (0.00, 0.98; 6.0)
- scende `senza nome` su `@MeshInstance3D@2246` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2248` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2250` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2252` (0.08, 0.64; 8.0)
- resta `senza nome` su `@MeshInstance3D@2254` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2259` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2262` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2267` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2270` (0.38, 0.75; 9.0)
- resta `senza nome` su `@MeshInstance3D@2275` (0.00, 0.98; 4.0)
- resta `senza nome` su `@MeshInstance3D@2278` (0.38, 0.75; 8.0)
- scende `senza nome` su `@MeshInstance3D@2282` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2286` (0.43, 0.20; 8.0)
- scende `senza nome` su `@MeshInstance3D@2290` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2294` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2298` (0.43, 0.20; 8.0)
- scende `senza nome` su `@MeshInstance3D@2302` (0.08, 0.64; 8.0)
- scende `senza nome` su `@MeshInstance3D@2304` (0.56, 0.15; 6.0)
- scende `senza nome` su `@MeshInstance3D@2306` (0.56, 0.15; 6.0)

## menu_principale

Costo con questa scena caricata: 0.17 ms per fotogramma (applica e ripristina, su questa macchina lenta), per 10 luci bianche e 143 materiali delle lampade (condivisi: uno per materiale, non uno per lampada).

VoxelGI con i dati cotti raccolti finora (tutte le scene): 7, scendono tutti al 40%.

### LuceEmergenzaDestra — 0 bianche, 1 colorate, 1 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2363` (0.01, 0.97; 3.00)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2362` (0.01, 0.97; 3.0)

### LuceEmergenzaDestra/@Node3D@2364 — 0 bianche, 2 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2365` (0.01, 0.97; 7.50)
- `@SpotLight3D@2366` (0.01, 0.97; 7.50)

### LuceEmergenzaSinistra — 0 bianche, 1 colorate, 1 materiali

Colorate (restano com'erano):
- `@OmniLight3D@2357` (0.01, 0.97; 2.87)

Materiali delle lampade:
- resta `senza nome` su `@MeshInstance3D@2356` (0.01, 0.97; 3.8)

### LuceEmergenzaSinistra/@Node3D@2358 — 0 bianche, 2 colorate, 0 materiali

Colorate (restano com'erano):
- `@SpotLight3D@2359` (0.01, 0.97; 7.50)
- `@SpotLight3D@2360` (0.01, 0.97; 7.50)

### Luna — 0 bianche, 1 colorate, 0 materiali

Colorate (restano com'erano):
- `Luna` (0.63, 0.45; 0.12)

### Sfondo/Acqua — 2 bianche, 0 colorate, 1 materiali

Bianche (scendono al 40%):
- `insegna/luce_dx/@SpotLight3D@2441` (0.09, 0.58; 2.20)
- `insegna/luce_sx/@SpotLight3D@2442` (0.09, 0.58; 2.20)

Materiali delle lampade:
- scende `lampadina` su `insegna/lampada_dx_lampadina` (0.09, 0.33; 2.0)

### Statua — 0 bianche, 0 colorate, 0 materiali

Di Jilly, delle creature o degli oggetti di gioco (restano com'erano anche se bianche):
- `LuceCampana` (0.89, 0.64; 0.50)
- `FaroGalleriaSinistro` (0.10, 0.24; 7.00)
- `FaroGalleriaDestro` (0.10, 0.24; 7.00)
- `FarettoBasso0` (0.10, 0.42; 1.60)
- `FarettoBasso1` (0.10, 0.42; 1.60)
- `FarettoBasso2` (0.10, 0.42; 1.60)
- `FarettoBasso3` (0.10, 0.42; 1.60)
- `Controluce` (0.59, 0.32; 5.00)
- `LuceViso` (0.10, 0.12; 3.20)

### Tempesta — 1 bianche, 0 colorate, 0 materiali

Bianche (scendono al 40%):
- `LuceLampo` (0.62, 0.26; 0.00)
