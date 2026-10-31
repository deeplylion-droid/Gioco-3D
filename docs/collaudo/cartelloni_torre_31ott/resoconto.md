# Ricontrollo dei cartelloni rovinati nella torre degli scivoli (31 ottobre)

Ricontrollo di mascotte su `lavoro/poster-sala-muro` **2d959afd**. Torre costruita e preparata come nel gioco, dagli occhi del giocatore, preset alto, renderer vero. "Prima" = i materiali del GLB, cioè come nella 0.3.17.

**Esito: superato, nessun difetto.** 0 righe "ERROR: BUG," in tutti i log.

## Punto per punto

1. **Quali cartelloni.** Sono rovinati `torre_cartellone_0` e `_3` (delfino) e `_1` (balena); `_2` (polpo) è com'è. Il GLB non cambia e le luci sono intatte: cambia solo il materiale di quelle tre mesh. `test_torre` 95/95.
2. **Dagli occhi** (`1_dagli_occhi_prima_dopo.jpg`).
   - Balena e delfino 3: dalla pedana, dal fondo e dal pavimento davanti si capisce subito che sono bruciati e scarabocchiati.
   - Delfino 0: dalle pedane non si vede, né prima né dopo; è al buio, dietro le travi e lo scivolo.
   - Il tubo davanti al delfino 0 è `torre_scivolo_6`, con le travi `torre_A_travi`. Sta a 0,85 m dalla carta (raggi su una griglia 9 x 5) e non la tocca.
   - Lì sotto, dove si cammina, c'è spazio libero: dai grigliati (6,0 m) 4 m sopra, dai canali (4,2-5,3 m) almeno 2,83 m. Poco spazio libero c'è solo sopra le travi (0,17-0,47 m), dove non si cammina.
3. **Da vicino** (`2_…`, `3_…`). Cornice intera e appoggiata al muro, nessun distacco. Dai buchi si vede la lamiera arrugginita della cornice. Per il delfino 0 il ravvicinato è a 0,4 m, con una lampadina solo tecnica che nel gioco non c'è; i due scatti "dopo" sono identici.
4. **La macchia bianca sotto il delfino 3** (`4_macchia_bianca_goccia.jpg`). È una **goccia del gocciolatoio** della torre, passata a pochi centimetri dalla camera.
   - Nel primo foglio di enigmi (8e12e6b1, "delfino 3, davanti - dopo") è un ovale chiaro verticale: è la forma della mesh delle gocce (sfera di raggio 1,2 cm, alta 5 cm), con lo stesso materiale chiaro e lucido.
   - Messa apposta una goccia ferma a 5, 8 e 15 cm dall'obiettivo, nella stessa vista, viene la stessa macchia.
   - Il gocciolatoio più vicino è in (36,6; -8,8; -22,8): a 0,4-0,7 m in orizzontale dall'occhio della vista "davanti", 4,6 m più in alto. Le gocce partono con una dispersione di 45°.
   - In 84 scatti con le gocce (24 radi dal checkpoint, 60 fitti dal pavimento davanti) la macchia non torna: capita di rado e dura 1-2 fotogrammi. Non è un difetto dei cartelloni, e le gocce c'erano già nella 0.3.17.
5. **Sala.** `test_sala` 107/107: delfino, balena e i due teli rovinati; il polpo (n2) e il muro sud (s0) no. Lo spot VHS usa `sala_pulita.gd` e `torre_pulita.gd`, che non passano da `PosterRovinati`; dalla torre prende solo la funzione delle coordinate, quindi resta pulito.
6. **Posizionamento.** `controllo_posizionamento`: 0 casi nuovi, 64 già noti, 0 da correggere, 0 eccezioni non più trovate.

## Pipeline

Costruzione e preparazione della torre: +121 / +173 compilazioni. Durante gli scatti +1 / +1.
