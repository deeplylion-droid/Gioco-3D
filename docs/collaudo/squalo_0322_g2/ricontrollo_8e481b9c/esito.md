# Ricontrollo dello squalo dopo le correzioni di mascotte (lavoro/squalo-paura 8e481b9c)

Esito: **le tre correzioni passano, ma c'è 1 difetto nuovo**: annusando, la mano destra entra nel cartello giallo del pavimento bagnato.

## Le correzioni

| cosa | prima (86ab11f9) | ora (8e481b9c) |
|---|---|---|
| Salto della camera per fotogramma | 0,52 m a 2,25 s | al più 3,85 cm a 60 fps (2,17-2,22 s) e 7,7 cm a 30 fps (`misure_60fps.txt`, `misure_30fps.txt`, `dati_finestre_60fps.jsonl`) |
| Distanza minima dalla pelle | 0,234 m | 0,269 m (a 7,6 s) |
| Da 2,0 a 2,6 s, uno scatto ogni 0,02 s | stacco fra il lampo e la luce | continuo: nel terzo lampo la faccia si vede (illuminata di rosso dall'alto), nel buio la sagoma, alla luce la stessa inquadratura (`f_fin_01.jpg`) |
| Al richiamo (8,2-9,15 s), ogni 0,02 s | | morbido, senza scatti (`f_fin_01`-`04`) |
| Primo lampo | sagoma nera, media 2,5 su 255 | si riconosce: il sorriso, gli artigli, il corpo illuminati di rosso, i muri restano bui; media 7,3 (90%: 15) (`primo_lampo_0.67s.jpg`). Secondo lampo 24, terzo 29 |
| Luce rossa dei lampi | | si accende solo nei lampi (forza 7, 3 e 1,6), maschera solo sullo strato dello squalo, nessun'altra mesh su quello strato; si spegne a fine lampo, a fine scena e in tutte le interruzioni (`interruzioni.txt`) |
| Fiuto | da 0,42 m a sinistra al centro | il muso, rispetto alla camera, va da 0,13 m a sinistra (3,2 s) a 0,35 m a destra (4,4 s) (`misure_30fps.txt`, righe FIUTO) |

## Difetto nuovo

**La mano destra entra nel cartello del pavimento bagnato.**
- Da 3,1 a 3,5 s, mentre annusa, la sua mano destra (a sinistra nello schermo) passa dentro il cartello giallo: le dita e gli artigli attraversano la lamiera (`f_mani_01.jpg`, colonna di destra).
- Si vede dagli occhi del giocatore: a 3,33 s la mano è sul cartello e un artiglio ci entra (`mano_nel_cartello_dagli_occhi_3.33s.jpg`).
- L'osso della mano arriva a 2,5 cm da una superficie a 3,20 s; nella versione di prima non andava sotto i 26 cm. Viene dai tempi nuovi del corpo.

## Il resto, di nuovo

- Bocca chiusa nei tre morsi (5,95, 6,35, 7,70 s) e spalancata e ferma nella pausa, da tre lati (`f_ravv_01.jpg`).
- Piedi: il piede a terra resta fermo (0,22 m, la caviglia), nel buio, nei lampi e mentre se ne va (`f_ravv_02.jpg`).
- Mani, muso e coda: tranne la mano nel cartello, mai a meno di 10 cm dai muri.
- Camera ad almeno 0,31 m dai muri. Il giro più grande in un fotogramma è 4,4° a 2,9 s, quando si tira su a sedere.
- Lampade: al 3% nel buio, accese nei lampi e da 2,5 s, tutte a 1 a fine scena e dopo pausa, titolo, Nuova partita e Continua.
- Goccia da 4,50 a 7,20 s, poi più niente.
- Suoni: a fine scena non resta niente acceso.
