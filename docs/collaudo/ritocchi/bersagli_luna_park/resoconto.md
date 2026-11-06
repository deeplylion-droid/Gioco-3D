# Ricontrollo dei bersagli da luna park (grafica-2) per la 0.3.21

Squadra collaudo, 6 novembre.

**Su cosa.** Lo stato provato è quello indicato dal coordinatore: `lavoro/candidata-0321` 46768c5d più `lavoro/bersagli-luna-park-0321` fc93f763 più `lavoro/bocche-ombre-g2` 4e4679ec. Li ho uniti in locale senza conflitti (f61c2481, non spinto). Il confronto del getto è sulla candidata 46768c5d senza bersagli. Nel gioco non ho cambiato niente.

**Esito: va bene, nessun difetto da girare.**

## Test sull'unione (0 BUG, 0 SCRIPT ERROR)
| test | esito |
|---|---|
| check_scripts | 0 errori |
| test_inseguimento | 43 ok |
| test_occhio_sopra_acque | 106 ok |
| test_morbidezza_inseguimento | 72 ok |
| test_inseguimento_suoni | 24 ok |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti |

## 1. Uguali agli scatti approvati
Ho rifatto `scatti_bersagli_g2.gd` di grafica-2 dalle stesse pose dello stato provato e l'ho confrontato con gli scatti di `lavoro/bersagli-luna-park` 90756a37.
- In 13 scatti la differenza media sta fra 0,6 e 4,6 su 255, con l'1-6% dei pixel cambiati.
- Le paratie sono uguali:
  - il sole sorridente nell'anello verde sulla giusta;
  - il pesce grigio scrostato con gli occhi a croce sulla sbagliata;
  - i montanti a strisce caramella;
  - la luce verde, la lampada rossa e il getto che colpisce.
- **Quello che cambia sono le sagome di cartone del club**, che nella candidata stanno in posti diversi dagli scatti approvati: nella vasca 1, dietro la giusta, la stella non c'è più; accanto alla sbagliata c'è un granchio; nella vasca 3 c'è un cartello viola. Vengono dalla candidata 46768c5d (lavoro/sagome-club, enigmi), non dai bersagli.
- Il foglio è `fogli/approvati_e_ora.jpg`: in ogni coppia, a sinistra l'approvato e a destra adesso.

## 2. Le paratie in tutti gli stati
Ho usato `paratie_giro.gd numeri`, `paratie_morte.gd` e gli scatti.
- **Aperte.** In tutte e sei il pannello sale di 1,95 m e le sue collisioni non entrano in niente.
- **Chiuse.** Le collisioni del pannello toccano ins_A_struttura sotto il pavimento del vano. È identico sulla candidata senza bersagli (l'ha trovato anche ambienti-1), quindi c'era già.
- **Vicini.** Le scatole vicine (a meno di 5 cm) sono l'acqua, i grigliati, la bocca e la parete d'acqua. Il pannello della sbagliata della vasca 3 aperto è vicino a ins_A_tubo_2, ma senza collisioni dentro.
- **Dopo la morte e la ripartenza** (gioco vero, partenza F9 inseguimento, aperte le due della vasca 1):
  - tutti e sei i pannelli tornano esattamente dove erano all'arrivo, chiusi;
  - le uniche collisioni sono quelle di sempre con ins_A_struttura.
- **Lo scolo 1 dietro la sbagliata della vasca 2.** Dal tubo si vede solo il retro liscio del pannello: niente nervature e niente pezzi nel tubo, anche mentre si apre (`fogli/v2_sbagliata_scolo1.jpg`).
- **Le sagome del club.** Vicino alle paratie (vasca 1 e vasca 3) stanno dietro il bordo e non toccano i montanti.

## 3. Ravvicinati dei pannelli e dei montanti
Scatti con una lampadina tecnica: i 4 angoli, i montanti giù, a metà e su nei due lati, l'anello di sbieco e il bordo. I fogli sono `v1_giusta_chiusa.jpg`, `v1_sbagliata_chiusa.jpg`, `v2_giusta.jpg`, `v2_sbagliata_scolo1.jpg` e `v3.jpg`.
- I montanti sono attaccati ai bordi del pannello, senza stacchi visibili.
- Gli angoli in alto sono puliti.
- Gli angoli in basso stanno sotto il pavimento del vano, dove il giocatore non vede (i 43 cm sotto, che c'erano già).
- L'anello di led della giusta è appoggiato sulla faccia dipinta e sale col pannello. Negli scatti da aperta l'anello è in alto col pannello, e anche la lampada verde sale di 1,95 m (`v1_apertura_tubo.jpg`).
- Il bordo di sotto del pannello alzato è pulito.

## 4. Il getto
Getto vero dal checkpoint sul bersaglio di ogni paratia. È **identico, fotogramma per fotogramma, alla candidata senza bersagli**:

| paratia | primo colpo | si apre dopo | alzata del tutto dopo altri |
|---|---|---|---|
| vasca 1 giusta e sbagliata | 25 fotogrammi | 1,92 s | 1,00 s |
| vasca 2 giusta (la lenta) | 27 | 1,95 s | 3,02 s |
| vasca 2 sbagliata | 24 | 1,90 s | 1,00 s |
| vasca 3 giusta e sbagliata | 24 | 1,90 s | 1,00 s |

- Il getto sul sole apre la giusta, quello sul pesce apre la sbagliata.
- Lei su nella vasca 1 c'è negli scatti rifatti di grafica-2 (vasca1_lei_su_2: differenza media 0,59 dall'approvato).

I numeri sono in `numeri.txt`; gli strumenti `paratie_giro.gd` e `paratie_morte.gd` sono in `godot/tests/collaudo/`.
