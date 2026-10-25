# Collaudo della roccia del fiume (25 ottobre, sera)

Squadra collaudo. Correzione: `lavoro/roccia-fiume` **f54b72c3** (ambienti-1), su f0d94d78. Un pannello di roccia di 2,6 m sulla sponda interna del bivio 3 (`_roccia_prima_colonna`, a 224,4°) chiude il varco prima della colonna.

**Esito: il varco è chiuso, la roccia è continua lungo tutto il percorso giusto.**
- Il pannello nuovo poggia sulla banchina come i vicini, arriva alla stessa altezza e si attacca alla colonna senza fessure.
- Niente è sospeso, e il pannello non entra nel tubo né nel parapetto.
- Non cambia niente nel resto del fiume.
- CI della correzione verde (run 40216277127). Il controllo di posizionamento della squadra ha 0 casi nuovi.

## Come

`godot/tests/collaudo/sonda_roccia_giro.gd` carica il fiume (`fiume.tscn`) da solo, con l'ambiente e la camera della sala, col renderer vero, a 640×360. La camera sta dove ha gli occhi il giocatore seduto sulla ciambella: 1,65 m sopra il punto del tratto.
- **Tratti**: Imbarco, Giusto1, Giusto2 e Uscita, ogni metro, guardando avanti, a sinistra e a destra.
- **Giusto2 fra 12 e 26 m**: ogni mezzo metro, anche di sbieco in avanti e all'indietro e in alto a sinistra e a destra.
- **Viste**: 645 per commit, ognuna anche con lo sfondo magenta per il vuoto fuori dal livello.
- **Confronto**: lo stesso giro su f0d94d78 (prima) e su f54b72c3 (correzione), vista per vista (`tools/collaudo/confronta_giri.py`).

## Risultati

| | Prima | Correzione |
|---|---|---|
| Viste con vuoto fuori dal livello | 0 su 645 | 0 su 645 |
| Viste che cambiano fra i due giri | | 36, tutte a destra (sponda interna) nel Giusto2 fra 15 e 20,5 m; nessun'altra vista cambia |

Il buco di prima non era vuoto fuori dal livello. Era un varco nella roccia: attraverso si vedeva oltre la sponda, in una zona con la luce rossa. Per questo la maschera magenta non lo trova e il confronto si fa sulla grafica.

## Cosa si vede

- **Fra 17 e 20 m, guardando a destra** (`fogli/prima_dopo_destra_17_20.jpg`): prima c'era il varco con la zona rossa dietro, ora c'è roccia continua. Il pannello ha la stessa texture e le stesse crepe orizzontali dei vicini.
- **Di sbieco e in alto** (`fogli/prima_dopo_sbieco_e_alto.jpg`): avvicinandosi (17,5 e 18 m in avanti) la colonna e il pannello sono una parete sola. Guardando indietro (19 m) la sponda prosegue senza aperture. In alto il bordo superiore è allineato coi vicini.
- **Arrivando e dopo la colonna** (`fogli/prima_dopo_avvicinandosi_e_dopo_la_colonna.jpg`): da 15 m guardando avanti la fessura buia dietro la colonna non c'è più. Da 16 m in alto e da 19,5 m indietro la cresta della roccia è continua.
- **Ravvicinato** (`fogli/pannello_e_colonna_ravvicinato.jpg`, schiarito): il pannello poggia sulla banchina, si attacca alla colonna e il tubo del parapetto entra nella colonna come prima. Niente sospeso o compenetrato.
- **Tutte le viste fra 17 e 20 m sulla correzione** (`fogli/correzione_17_20_tutte_le_viste.jpg`, senza schiarire, com'è nel gioco).

I fogli di confronto sono schiariti (×2,2-2,6) perché nel gioco il fiume è buio. Il pannello nuovo risulta appena più rosso dei vicini (rosso/verde 2,2 contro 1,9-2,1 dei pannelli accanto). La differenza sta nella variazione che c'è già fra un pannello e l'altro, e nel gioco, al buio, non si nota.

## Non verificato qui

- **Il retro del pannello, dalla parte della zona rossa**: lì il giocatore non passa lungo il percorso giusto. I tratti sbagliati non sono stati girati.
- **Il varco al disco della paratia 3**, che resta com'è come voleva l'utente.
