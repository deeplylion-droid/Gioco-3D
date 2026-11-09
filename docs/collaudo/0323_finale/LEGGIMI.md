# Collaudo finale della 0.3.23 (9 novembre)

Squadra collaudo. Ho fatto due giri:
- **il collaudo finale** di `lavoro/candidata-0323` **3c446cfb**;
- **il giro corto della torre** sulla candidata finale **f2f810a2**, con le lampade di sala-passi-lunghi 3effd587.

Nel gioco non ho cambiato niente.

**Esito: superato su tutte e due.** Su 3c446cfb `test_attesa_zone` falliva per pochi millisecondi, e su f2f810a2 è verde. Ci sono due cose piccole da sapere (punti 2 e 7), più il #146 già noto.

## 1. Guanto sulla lancia (5325f596)
`fogli/guanto_zone_fov.jpg`, `fogli/guanto_pose_e_stati.jpg`, `dati/guanto_compilazioni.txt`.
- **Dove ho guardato:** in tre zone (livello di prova, interni della sala, fiume), con FOV 62, 75 e 90, guardando in giù di 40°, 65° e 85°: 27 scatti.
- **Il guanto:** segue sempre la lancia e stringe l'impugnatura, senza buchi né pezzi staccati. Lo stesso vale nelle 8 pose (fermo, cammina, corre, accovacciato, scala, acqua, spara, aspira) e nelle 6 viste da vicino.
- **Compilazioni:** 0 quando il guanto entra in vista. Le uniche sono 2 a FOV 90 (prova giù 65, fiume giù 85): è un pezzo della lancia, il #146 già noto.

## 2. Scena dello squalo con la goccia B (7ef6ed5b)
`fogli/squalo_alto.jpg`, `squalo_basso.jpg`, `squalo_nuovo.jpg`, `dati/squalo_pipeline.txt`.

**La scena va in tutti e tre i casi:** preset alto, preset basso e primo avvio con un profilo vuoto (calibrato=false, qualita_provata=false). In tutti e tre:
- il controllo torna al giocatore a 19,2 s;
- gli unici ERROR sono quelli dell'audio, normali nel sandbox.

**La goccia:** compare a 6,3 s sul muso col filo di bava, poi scivola giù e sparisce prima di 9 s.

**Una cosa piccola, nei tre giri.** Nel fotogramma in cui compare la goccia (6,27 s) si compila **1 pipeline canvas**: il contatore canvas passa da 3 a 4, e surface e draw restano fermi. `test_effetti_primo_uso`, con la goccia da sola, dice «canvas 0». Il riscaldamento della goccia (`riscalda_goccia`) quindi non copre del tutto la goccia nella scena vera. Va guardato da grafica-2: non so dire se nel gioco vero dia uno scatto.

## 3. Menu di prova F9 col clic del mouse (80529af4)
`test_partenze_prova` passa 74 controlli su 74, compreso «un clic col mouse sulla partenza Risalita la sceglie».

## 4. Visore delle Polaroid (42ea553c)
`fogli/visore_it_en.jpg` (su f2f810a2; il visore è uguale a 3c446cfb), `dati/visore.txt`.

| | italiano | inglese |
|---|---|---|
| Raccolta nel mondo | col tasto E vero la foto si apre in pausa; A la chiude | uguale |
| Dall'album della pausa | A sulla prima cornice la riapre sopra l'album; B la chiude e si resta nell'album | uguale |
| Suggerimento | «E · Spazio · clic · A · B per continuare», tutto dentro lo schermo | «E · Space · click · A · B to continue», tutto dentro lo schermo |
| Album | «1 su 16», INDIETRO | «1 of 16», BACK |

`test_album_polaroid` passa 29 controlli su 29.

## 5. Fiume lento (812f163f)
`fogli/fiume_812f163f_e_candidata.jpg`, `dati/fiume_confronto.txt`.

Ho rifatto i 221 scatti del terzo ricontrollo sulla candidata.
- **Differenza media:** 0,10 su 255.
- **Dove cambia qualcosa:** solo il cielo animato nelle due viste dall'alto e i riflessi dell'acqua.
- **I test:** `test_fiume` 35 su 35, `test_fiume_gioco` 35 su 35.

## 6. Torre e inseguimento coi lavori a pezzi (6aaa8373), e giro corto della torre su f2f810a2
Strade: dal portone, F9 torre, morte nella torre, Continua dal titolo.

**I test sulle due versioni:**

| | 3c446cfb | f2f810a2 |
|---|---|---|
| test_portone_torre | 20/20 | 20/20 |
| test_ripartenza_oltre_portone | 53/53 | 53/53 |
| test_torre | 95/95 | 95/95 |
| test_inseguimento | 43/43 | 43/43 |
| test_continua | 127/127 | 127/127 |
| test_torre_pezzi_uguali | 8/8 | 10/10 |
| test_lampade_torre_strade | non c'è | 22/22 |
| **test_attesa_zone** | **KO in 2 giri su 2: un fotogramma di 101-105 ms (limite 100) a 6,1 s, quando finisce il thread rallentato** | **verde in 3 giri su 3** |

Il terzo giro su 3c446cfb lo scarto: la macchina era carica per il riavvio della sessione (`dati/attesa_zone.txt`).

**Le 7 lampade d'emergenza rosse** (`dati/lampade_strade.txt`, `fogli/lampade_torre.jpg`):
- **Posizioni:** nelle quattro strade sono negli stessi posti, al decimo di millimetro.
- **A filo del muro:** a 0,0 mm, e niente dentro la scatola (9+9 raggi, la misura del test).
- **La lampada 5:** sta sul muro est, a (39,92; −16; −15), sopra il tubo. Fra la scatola e il tubo c'è spazio, e la fascetta del tubo è sotto.
- **Gli avvisi «Posa: nessun muro dietro»** di `_emergenza` sulla 3c446cfb erano 4. Su f2f810a2 non ce ne sono più, in nessun log.
- **Gli scatti con Vulkan:** di fronte, radenti dai due lati e larghi. Le scatole stanno piatte sul muro, senza fessure e senza niente che le attraversa. La lampada 3, vista proprio di fronte, è in parte coperta dal palo giallo dello scivolo e da un tubo davanti al muro, ma non li tocca.
- **Come ho fatto gli scatti:** con la torre da sola (`sala_torre.tscn` con l'ambiente della sala e il blackout). Le posizioni sono le stesse delle quattro strade. La sala intera con la torre non entra in memoria con Vulkan: il mio primo strumento è stato ucciso a 14 GB, ed è stata colpa dello strumento, non del gioco.

**Fotogrammi lunghi:** nessuno nuovo (`dati/fotogrammi_strade.txt`, misure senza grafica, due giri per versione).
- **I passi della costruzione:** su f2f810a2 nessun passo lungo nell'inseguimento. Il fotogramma più carico della costruzione a pezzi è di 25 ms.
- **Il fotogramma lungo che resta (7):** in ogni strada, nei primi 1-3 s dopo l'arrivo, c'è un fotogramma di 350-930 ms. **C'è uguale su main d01e5a95 e su 3c446cfb**, quindi non viene dalla 0.3.23. Non è un passo della costruzione della torre e il log non dice cosa sia. Lo segnalo perché qualcuno lo guardi, se si vuole.

**Una nota su Continua.** Le partenze F9 non scrivono il salvataggio (lo dice `MenuProva`: partire da lì è come ripartire dopo una morte). Per questo nel mio giro Continua è ripartito dal salvataggio del risveglio. La torre si è costruita anche lì, con le lampade identiche.

## 8. Il resto
- **Import e script:** import ok, `check_scripts` 0 errori su tutte e due.
- **Gli altri test (3c446cfb):** test_scivoli 26, test_menu 85, test_primo_ingresso 7, test_strada 36, test_effetti_primo_uso 7, test_riscaldamento_pipeline 11, test_primo_uso 4: tutti ok.
- **controllo_cielo:** 686 posti, 0 col cielo, 0 fessure.
- **controllo_posizionamento: 0 da correggere** su 3c446cfb e su f2f810a2.
- **ERROR nei log:** sono quelli di sempre, uguali fra le due versioni:
  - 102 sulle blend shape e 16 su forme Jolt vuote nel posizionamento;
  - 4 «Parse JSON failed» in test_continua;
  - l'audio;
  - le perdite all'uscita.
- **Memoria:** senza grafica, dopo le quattro strade, 2,1 GB su f2f810a2 contro 2,07 su main.

## Strumenti
In `godot/tests/collaudo/`:
- `guanto_zone.gd`: il guanto in tre zone, con tre FOV e tre inclinazioni, e le compilazioni.
- `visore_scatti.gd`: il visore dal mondo, col tasto E vero su una Polaroid del capitolo, e dall'album, col joypad.
- `lampade_torre_giro.gd`: le quattro strade senza grafica, con lampade, fotogrammi e passi lunghi.
- `lampade_fotogrammi.gd`: solo i fotogrammi, per confrontare le versioni vecchie.
- `lampade_scatti_torre.gd`: gli scatti delle lampade con Vulkan.
- `fiume_giro.gd`: aggiornato.

In `dati/code.txt` ci sono le righe di riepilogo di tutte le code.
