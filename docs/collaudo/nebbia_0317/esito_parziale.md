# Ricontrollo nebbia 0.3.17 (lavoro/nebbia-0317 786dcf48): parziale di ambienti-1, poi passato a enigmi

Fatto solo il tunnel (preset alto, blackout, occhi del giocatore; `godot/tests/collaudo/giro_tunnel_0317.gd`):
- **strada leggibile e buia** in 8 punti (`foglio_tunnel.jpg`): banchine, gommoni di 74, 138, 268, 348, 484, bocche delle gallerie a 205 e 425 con le strisce, cancello, macerie e vetrina. Nessun "ERROR: BUG,".
- **luce rosa quando lei si avvicina** (s 100, `foglio_lei.jpg`, `misure_tunnel.txt`):
  - guardando lei si nota: rosa (R-G) da 3,3 a 11 m a 6,9 a 3 m;
  - **guardando avanti, come quando scappi, quasi non si nota**: R-G da 0,2 a 0,6, anche se l'energia della luce va da 9,9 a 19,6. Da confrontare coi valori della 0.3.16 (giro_tunnel_0317.gd con 4° argomento "lei" e 5° "0316"): prova non fatta.
- Non fatti: piscina (`giro_piscina_0317.gd` va lanciato con `ATTESA_FERMO=900`: il cambio di shader compila per più di 60 s), infermeria (in `giro_infermeria_0317.gd` la zona non scatta col giocatore fermo: va messa a mano con `nv.zona(z, true, true)`), impostazioni versione 3 (`prova_impostazioni_v3.gd`, mai lanciata), nebbia spenta e riaccesa.
