# Ricontrollo delle bocche e delle ombre di grafica-2 (grafica, 6 novembre)

Controllato `lavoro/bocche-ombre-g2` 4e4679ec unito coi bersagli da luna park `lavoro/bersagli-luna-park-0321` fc93f763
(branch `lavoro/collaudo-bocche-ombre`). Strumento: `godot/tests/collaudo/collaudo_bocche_grafica.gd`, che usa le pose
di `scatti_bocche_da_sotto.gd` con pose sue. Vulkan software, 960x540, blackout come nel gioco, paratie aperte, lei nascosta.

## Esito: passa, nessun difetto della modifica
- **L'unione coi bersagli**: nessun conflitto. I bersagli cambiano solo le GLB di struttura e mobili, nessuno script.
  Sullo stato unito passano check_scripts (0), test_inseguimento (43/43) e test_occhio_sopra_acque (106/106). Le paratie
  verdi coi bersagli nuovi si vedono bene dalla vasca (foglio 4).
- **Le sei bocche da dentro, ferme** (foglio 1): a 2,5, 1,5, 0,8 e 0,3 m dentro il tubo, guardando la vasca, e a 0,8 m
  guardando un po' in su. Sotto il pelo la parete è acqua sfocata e mossa, dello stesso colore in tutte e sei. Le
  piastrelle e la griglia non sono più nitide. Sopra il pelo si vede la sala come prima.
- **Scivolando** (foglio 2): in ogni tubo si entra dalla vasca e, passati 1,3 m, ci si gira mentre si scivola. Sono 6
  scatti ogni 3 fotogrammi: niente scatti né strisce fra uno e l'altro, e le sei bocche sono uguali. Nel tubo 3 non c'è
  la riga verde. (Nello scolo 0 gli ovali chiari sono gocce davanti alla camera mentre si entra in acqua, non la parete.)
- **Dalla vasca** (foglio 3): sopra il pelo la bocca si vede come prima. Da sotto il pelo la parete vista da dietro è
  scura e non fa luce.
- **La riga verde nel tubo 3** (foglio 4, posa (65,29; -27,92; -3,15) verso (0,98; 0,15; 0,15)): non c'è.
- **Le luci con ombra**: la scena intera ne ha 48 qui e 50 con le tre ombre della candidata, quindi 2 in meno, come dice
  grafica-2. Il suo 48 → 46 conta una parte più piccola; la sonda ne conta 46.
- **Prestazioni** (`sonda_ombre.gd` del collaudo, le stesse pose, due giri, `ombre.txt`): le proporzioni sono come quelle
  di grafica-2. Il costo resta davanti alla paratia della vasca 3, e altrove si è vicini a «nessuna»:
  - paratia verde 0: tre ombre 893/850 ms, solo vasca 3 844/867, nessuna 754/798;
  - paratia verde 2: 1389/1407, 1359/1325, 1316/1319;
  - paratia verde 4: 1820/1907, 1929/1871, 1873/1835;
  - tubo 3 da dentro: 646/654, 667/640, 595/627;
  - punto peggiore: 875/864, 837/823, 756/771.

## Una nota, non della modifica
Vicino alla bocca (0,3-0,5 m dentro il tubo), fra la sala sopra il pelo e l'acqua sotto, c'è una fascia scura netta
alta circa un quinto dello schermo. **C'è uguale nella candidata** (foglio 5, alla stessa posa, a sinistra col
`water_inseguimento.gdshader` di prima): non viene da questa modifica. Si vede solo nei primi passi dentro il tubo,
appena sotto il pelo.

## Fogli
1_fermo_sei_bocche, 2_scivolando, 3_dalla_vasca, 4_riga_tubo3_e_paratie_verdi, 5_confronto_candidata_vicino_alla_bocca;
ombre.txt.
