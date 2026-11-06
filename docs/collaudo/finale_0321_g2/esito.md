# Collaudo finale 0.3.21, parte di grafica-2

Base: `lavoro/candidata-0321` 080ec07e, importata come la build (import e `godot_vram_textures.py` due volte). Ho controllato le cose fatte da mascotte e da grafica, che non ho costruito io.

## In breve
- **1 difetto**: quando la domanda «Avvio sicuro?» e la schermata della luminosità compaiono insieme, la domanda è nascosta ma ha il focus (punto 3).
- Il resto passa.

## 1. Bambini

**Test**

| test | esito |
|---|---|
| test_bambini_passi | 24 ok |
| test_agnellino | 14 ok |
| test_bambini_sfuggita | 75 ok |

**Passi di corsa**

| suono | durata | centroide | rms del file |
|---|---|---|---|
| bambino col cubo (`passo_bambino_muta_*`) | 0,19-0,20 s | circa 3 kHz, piede nudo e bagnato | -25 dB |
| agnellino (`passo_agnellino_*`) | 0,14-0,20 s | circa 1 kHz, tonfo morbido | -23/-24 dB |

- I due suoni sono diversi fra loro.
- Suonano dalla cartella «bambini» a -4 dB, posizionali (unit_size 2,5, fino a 30 m), con 0/-1,5 dB a caso: sono leggeri, più bassi dei passi del giocatore, che stanno a 0 dB e non posizionali.

**Agnellino della scala di C2** (`ricontrollo_agnellino_scala.gd`, foglio `agnellino_scala.jpg`)
- Da fermo respira e muove la testa. Le punte dei piedi stanno a 0,7 cm dal pavimento.
- In corsa sul piano (46 fotogrammi) il piede più basso sta fra -0,3 e +6,2 cm.
- Lo strumento stampa un minimo di -0,58 m, ma sono solo i fotogrammi del tuffo nel buco, girato in avanti da 17 a 75 gradi: non è un difetto.

**Agnellino della galleria** (`video_bambini_sfuggita.gd insegui_dentro`, foglio `agnellino_galleria.jpg`)
- Corre lungo la galleria e sparisce in fondo, al fotogramma 285.

## 2. Primo avvio, qualità automatica

- test_qualita_automatica: 26 ok. Con la misura vera senza schermo sceglie «ultra» in 2,6 s.
- La prova vera si fa la prima volta che si entra nella sala, e qui non la posso disegnare: la sala col renderer software non entra nella memoria. Col gioco vero e una cartella dati vuota, al titolo il file di impostazioni ha `preset="alto"`, `qualita_provata=false` e `scelta_automatica=""`, cioè aspetta la sala come previsto.
- **Da guardare sul PC vero**: entrando nella sala, la scritta «scelto in automatico: …» nelle opzioni e il tempo della prova.

## 3. Avvio sicuro

- test_avvio_sicuro: 17 ok.
- Col gioco vero (Xvfb, cartella dati vuota) ho chiuso di colpo con kill -9 e riavviato. Con la luminosità già confermata compare «Safe start?» (il sistema è in inglese), col focus su «Safe start». Scatto a destra in `avvio_sicuro.jpg`.
- Il segno `sessione_aperta` resta anche dopo una chiusura con SIGTERM. Va bene: è una chiusura non dal menu.

**DIFETTO: la domanda nascosta sotto la luminosità prende il focus.**
- **Quando**: al primo avvio dopo una chiusura di colpo, se la luminosità non è ancora stata confermata (`calibrato` falso). Succede se il gioco si è chiuso prima della conferma.
- **Cosa si vede**: la schermata della luminosità sopra, la domanda «Avvio sicuro?» sotto, nascosta. Il pulsante Conferma della luminosità non ha il focus (scatto a sinistra in `avvio_sicuro.jpg`).
- **Cosa succede**: col gioco come all'avvio vero (prima la luminosità, poi il titolo), la sonda `sonda_calibrazione_avvio_g2.gd` trova il focus su `MenuPrincipale/DomandaAvvioSicuro/.../Si`. Il giocatore preme Invio, o A sul joypad, per confermare la luminosità, e invece sceglie «Avvio sicuro» senza vederlo:
  - la qualità passa da alto a basso;
  - la luminosità resta aperta e non confermata;
  - su Windows cambierebbe anche il driver e il gioco si riavvierebbe.
- **Correzione proposta**:
  - la domanda aspetta che la calibrazione si chiuda e la fa dopo;
  - oppure, più semplice, non prende il focus finché c'è la calibrazione.
- Squadra: chi ha fatto l'avvio sicuro.

## 4. Texture più leggere

- Gli scatti sono quelli di `scatti_texture_props.gd`: gli oggetti piccoli (estintore, leva, fusti di cloro, manometro, valvola, quadro, carrello) e la torre (scivolo e metallo), da 0,6 m e a distanza di gioco.
- Ho confrontato la 0.3.21 con le stesse texture a 2048 come nella 0.3.20: `process/size_limit` rimesso a 0 nei loro 248 .import, poi reimportato e rimesso com'era.
- Differenza media 0,0-0,2 su 255; al più lo 0,5% dei pixel cambia di più di 8.
- Niente sfocature, il quadrante del manometro e le tacche si leggono uguali. Foglio `texture_0320_0321.jpg`.

## 5. Scatti al primo uso

- test_riscaldamento_pipeline: 11 ok.
- Nel riscaldamento al più 10 pipeline per fotogramma (l'effetto Gorgo, 13 in un fotogramma, è un caso già noto).
- Lei che compare dietro l'oblò, il tunnel in 37 punti, lei che riemerge, lo spruzzo, la nebbia viola: 0 compilazioni che bloccano, 0 anche in sottofondo.
