# Ricontrollo dei cartelloni del muro nord (31 ottobre)

Squadra collaudo. Ho controllato `lavoro/poster-sala-muro` **5ad8d9be** contro la 0.3.17 (main 9eec9510). Scatti dagli occhi del giocatore col renderer vero, preset alto, sala caricata a parti (`tests/collaudo/cartelloni_giro.gd`), con le luci prima del risveglio e col blackout, all'arrivo e col lampione.

**Esito: OK, nessun difetto. 0 righe "ERROR: BUG,".**

| Controllo | Esito |
|---|---|
| Cambiano solo delfino e balena | Nella sala del gioco hanno le texture rovinate solo `sala_cartellone_n0` (delfino) e `n1` (balena); il polpo `n2` e il muro sud `s0` hanno la texture di prima, e i teli quella della 0.3.17 (`sonda_cartelloni_spot.gd`). Negli scatti, polpo, muro sud e teli sono uguali alla 0.3.17: 0% di pixel diversi oltre 25 livelli (`fogli/3_invariati_prima_dopo.jpg`) |
| Dai cinque punti del giro (`fogli/1_giro_prima_dopo.jpg`) | dal centro della piscina, da ovest e da sotto il muro si vede che sono rovinati: macchie scure al posto dei colori. Dall'ingresso e da est sono piccoli; si vede che sono scuri e sporchi, non i dettagli |
| Da vicino, sotto e di lato (`fogli/2_vicino_prima_dopo.jpg`, `fogli/zoom_fronte.jpg`) | ghigni, occhi a spirale, zig-zag e bruciature si leggono. Dai buchi si vede la lamiera grigia della cornice, non il vuoto né il muro, e niente sfarfalla. Nelle texture manca il 28,1% della carta del delfino e il 29,1% della balena |
| Appoggio al muro | tutti e quattro i cartelloni, misurati dal retro della scatola al muro: 0,000 m. Le viste radenti lungo il muro non mostrano distacchi |
| Blackout (`fogli/4_blackout_dopo.jpg`) | come all'arrivo, più rossi; da vicino si leggono |
| Spot VHS (`sala_spot.tscn`) | tutti i cartelloni e i teli con le texture pulite di prima |
| Posizionamento | 0 casi da correggere |
| `test_sala` | 107/107 |
