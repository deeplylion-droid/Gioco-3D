# La scena dello squalo dopo il riscontro del 22 ottobre (v0.3.8)

Dal motore, nel gioco vero (sala principale con gli interni, preset Alto), dagli occhi del giocatore, a torcia
spenta. Strumento: `godot/proposte/mascotte/video_risveglio.gd`. Il video e' senza audio.

1. **Torcia spenta all'inizio** (scelta dell'utente): `interni.gd`, `fai_risveglio()`. Dopo la scena si accende
   con F. Al buio lo squalo si legge: lo illuminano le luci rosse d'emergenza del corridoio e, nella corsa, la
   luce che c'era gia' solo per lui. Non ho aggiunto luci.
2. **La camera dentro lo squalo**: misurata fotogramma per fotogramma con la mesh vera deformata
   (`godot/proposte/mascotte/sonda_camera_squalo.gd`). Succedeva mentre il giocatore si rialza (1,7-2,1 s): la
   camera passava nella mascella e nel petto, fino a 1 cm dalla pelle; e a 6,1 s sfiorava una mano. Ora
   `risveglio_squalo.gd` tiene la camera ad almeno 24 cm dalla pelle (un vertice ogni 8 cm, deformato dallo
   scheletro a ogni fotogramma), spostandola indietro, via da lui, del minimo che basta: vale per qualunque
   animazione. Minimo misurato con la mesh intera: 22 cm. Costo: al piu' 7,5 ms per fotogramma su questa macchina
   lenta, solo mentre lo squalo e' vicino.
3. **Il giro e la corsa** (`assets_src/mascotte/mostro_anim.py`): il giro in 0,59 s (era 0,9), l'esitazione con lo
   sguardo indietro e lo sbuffo in 0,72 s (era 1,0), la corsa a 4,4 m/s (era 2,8) con lo scatto in 0,42 s (era
   0,9) e 3 passi al secondo (erano 2,2), piu' piegato in avanti, con meno rollio e meno sobbalzi, le braccia
   che pompano di piu'. Restano i tre scatti di testa, lo sguardo e lo sbuffo, l'abbassarsi alla porta, la
   porta che si chiude. Lo squalo arriva alla porta a 8,5 s (era 10,2): la scena dura 11,9 s (era 13,5).

| File | Cosa |
| --- | --- |
| `1_minaccia_3.0s.jpg` | la bocca spalancata davanti alla faccia |
| `2_si_gira_6.2s.jpg` | si gira verso la porta |
| `3_ti_guarda_7.1s.jpg` | si volta a guardarti sopra la spalla |
| `4_corsa_7.7s.jpg` | la corsa |
| `5_porta_8.5s.jpg` | alla porta |
| `risveglio_squalo_senza_audio.mp4` | la scena intera (12 s) |
