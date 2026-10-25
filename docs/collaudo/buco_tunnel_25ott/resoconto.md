# Collaudo del buco all'ingresso del tunnel (25 ottobre, sera)

Squadra collaudo. Correzione: `lavoro/buco-tunnel` **4ec62e3b** (ambienti-2), su f0d94d78. Il passaggio della porta del bacino ora arriva fino al muro delle condotte, a x 40,4.

**Esito: il buco è chiuso.**
- Dalla correzione non si vede niente fuori dal livello, né prima né dopo SB1: 0 viste con vuoto su 653.
- Sul commit di prima la stessa sonda trova il vuoto in 54 viste su 624, tutte dalla soglia e dal passaggio.
- Il pezzo nuovo è continuo coi vicini: il pavimento a piastrelle, i fianchi e il soffitto proseguono senza fessure, e niente è sospeso o compenetrato.

## Come

`godot/tests/collaudo/sonda_buco.gd` lavora nella scena di prova del tunnel (`sottomarino_prova.tscn`), col renderer vero, a 640×360.
- **Punti**: 12, all'altezza degli occhi del giocatore: due nel bacino, metà e cima della scaletta, passerella, uscita, soglia, passaggio, e cinque sulle banchine della testa del tunnel (s -3, 0 e +2, a sinistra e a destra).
- **Viste**: da ogni punto 8 direzioni, ognuna in alto (+50°), dritto e in basso (-50°).
- **Stati**: prima di SB1, e dopo SB1 (il segnale `sb1_finito` e 2 secondi di attesa).
- **Due scatti per vista**: uno con la grafica del gioco e uno con lo sfondo magenta e senza nebbia. Ogni pixel magenta è vuoto fuori dal livello; li conta `tools/collaudo/conta_magenta.py`.

## Risultati

| Commit | Prima di SB1 | Dopo SB1 | Viste con vuoto |
|---|---|---|---|
| f0d94d78 (prima della correzione) | 312 viste | 312 viste | **54**: soglia e passaggio, in alto e in basso (fino a 6578 pixel su 57600 in `soglia_y090_p-50`), uguali prima e dopo SB1 |
| 4ec62e3b (correzione) | 312 viste | 312 + 29 viste | **0** |

## Fogli

- `fogli/prima_e_dopo_soglia_passaggio.jpg`: le sei viste peggiori del commit di prima. Per ognuna ci sono la maschera di prima (la fessura magenta fra il muro del tunnel e quello delle condotte), la maschera sulla correzione e la grafica sulla correzione: ora lì c'è pavimento, o fianco, o soffitto.
- `fogli/prima_sb1_soglia_passaggio_1.jpg`, `_2.jpg`: soglia e passaggio prima di SB1, sulla correzione.
- `fogli/dopo_sb1_passaggio_soglia.jpg`, `fogli/dopo_sb1_soglia_uscita.jpg`: passaggio, soglia e uscita dopo SB1. Si vedono il passaggio intero, il cartello del pavimento bagnato e il tubo arrotolato sulla passerella, la scaletta e il bacino con la paperella.
- `fogli/dopo_sb1_passerella_scaletta_testa.jpg`: passerella, scaletta e testa del tunnel, guardando dritto.

## Note

- Nelle ultime viste dalla testa (s +2 a sinistra, da 135° in poi) l'immagine è coperta dal disturbo rosso della presa. Non è un difetto: dopo SB1 lei parte, e il giocatore della sonda, nascosto e fermo, viene preso. Le maschere di quelle viste non hanno magenta.
- **Non verificato qui**: che la porta si chiuda dopo la prima curva. La sonda non entra nel tunnel; quel controllo l'ha fatto ambienti-2.
