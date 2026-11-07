# Squalo: correzioni dal collaudo di grafica-2 (8e481b9c)

Scatti dal gioco con le luci vere: preset alto, nebbia, 30 fps, la scena fatta girare con `giro_squalo.tscn` e `GIRO_ISTANTI=paura`. Ogni scatto riporta la luminosità media dell'inquadratura.

- `1_lampi.jpg`: i tre lampi, all'inizio e a metà della parte accesa.
  - Nel primo lui si riconosce, sagoma e testa, illuminato dall'alto dalla parte del giocatore. La luminosità media dell'inquadratura passa da 2,5 a 4,7-7,4; il corridoio resta buio.
  - Nel terzo si vede la faccia.
- `2_da_2_0_a_2_7_senza_stacchi.jpg`: dalla fine del terzo lampo alla luce che resta accesa, ogni 0,1 s. L'inquadratura resta la stessa, senza salti.
  - Il test misura lo scatto massimo della camera: 3,9 cm in un fotogramma a 60 fps e 7,7 cm a 30 fps (prima 52 cm).
  - La pelle resta al più vicino a 0,284 m.
- `3_fiuto_da_sinistra_a_destra.jpg`: lui si ritrae, la testa scende davanti al petto, il muso passa da sinistra a destra, poi sale alla faccia. Rispetto alla camera la bocca va da 0,13 m a sinistra a 0,35 m a destra.
