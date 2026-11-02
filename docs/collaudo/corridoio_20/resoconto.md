# Collaudo del fiume: pile sfalsate e lampade al 20% (2 novembre)

Collaudo di enigmi. Non ha lavorato nel fiume.

Ho controllato `lavoro/corridoio-20`, alla punta ff5abab8, con il codice di 16b15cad:
- le pile di scatoloni di ambienti-1 (79a367e5);
- le lampade a gabbia al 20% di grafica-2.

**Esito.** 1 difetto, da passare ad ambienti-1. 0 righe "ERROR: BUG," in tutti i log.

Lo strumento è `godot/tests/collaudo/collaudo_fiume_20.gd`, sul branch `lavoro/collaudo-corridoio-20`. Gira nella Risalita della scena di prova, come `scatti_pile_fiume.gd`:
- luci del blackout;
- ambiente della sala senza GI, nebbia volumetrica e SSIL (per la memoria);
- dagli occhi del giocatore, a 1,6 m.

## Difetto

1. **Una fessura fra le pile, all'angolo dei muri di pile 3 e 4** (ambienti-1). È in (-9,4; -5,4) del fiume, dove la pila a sinistra della fila gira verso sud, fino al ramo ovest.
   - Dalla strada, alla fine della fila vicino alla tettoia della cabina (in (-6,5; -6,7)), fra due colonne si vede il buio fino alla roccia, 3,9 m dietro la fila.
   - La fessura è alta quanto le pile: i raggi passano a 0,4, 1,0, 1,6, 2,2 e 2,8 m. È stretta, qualche centimetro (1 raggio ogni 0,3°), e nel gioco quasi non si vede perché dietro è buio. Però è un buco fra le pile: "chiudendo bene tutto".
   - Scatti: `fogli/buchi.jpg` (in alto a sinistra, con la luce ×3).

## Che cosa va

| Prova | Esito |
|---|---|
| Controllo di posizionamento della CI (col blocco) | 0 nuovi, 64 noti, 0 da correggere |
| Appoggi di tutte le scatole e unità delle pile (3674: 105 unità di casse, 224 di cartone, 46 aperte, 2478 scatoloni, 785 colorati, 36 casse sciolte), coi raggi dagli angoli e dal centro della faccia di sotto | 0 staccati di più di 1 cm, 0 appoggiati male (meno di 3 punti su 5), 0 affondati di più di 1 cm |
| Compenetrazioni fra due scatole o unità (più di 5 mm) | 0 |
| Il pesante sotto | le casse di plastica tutte a terra: le unità di casse alla base e le casse sciolte nei due piani di sotto |
| Strada libera fino a 2 m, lungo la strada a piedi dall'ingresso alla ciambella e dall'approdo alla porta | niente delle pile. Il cilindro sull'asse della fila tocca solo due transenne cadute a terra (in (-19,1; -21,3) e (-7,6; -8,9)): ci sono dal 21 ottobre (17a038a9) e questo branch non le cambia |
| Buchi visti dalla strada: raggi a 360° ogni 0,3°, a 5 altezze, ogni metro (234.000 raggi) | 3 punti. Uno è il difetto qui sopra. Gli altri due non sono buchi:<br>- **muro 2:** la fila finisce contro la roccia della riva, e dietro si vede la roccia, non il vuoto;<br>- **muro nord:** solo a 2,8 m, 2-3 raggi: è la nicchia della lampada a muro (le pile si fermano 15 cm sotto) |
| Il disegno (`fogli/giro_strada.jpg`) | sembra un magazzino riempito di fretta: colonne che sporgono o rientrano, qualcuna storta, gradini, gruppi di scatole colorate, non un rumore uniforme. Nel tratto più buio (fra la seconda e la terza lampada) le differenze si leggono poco: si vede soprattutto vicino alle lampade |
| Cime aperte e scatoloni caduti sopra il film (`fogli/vicino.jpg`, con una torcia sulla camera: lassù non arriva luce) | appoggiati, niente di staccato. Le misure sono quelle degli appoggi qui sopra |

## Luci (`fogli/luci.jpg`)

- **Il numero di lampade è giusto.** Nel fiume ci sono 21 lampade a gabbia a 0,60 e 2 a 0,50. I globi sono 23 a 0,60, più 5 rotte spente.
- **La lampada della valvola degli acquari, nella sala, è invariata.** Rispetto a `main` il branch cambia solo `fiume_gioco.gd`, che non tocca luci fuori dal fiume.
- **Bivio 1: la paratia si vede e si capisce dove andare.** La strada è quasi nera: senza GI ho media 1,7-2,9, mediana 0,1. Ma la paratia da colpire si vede: il disco a strisce bianche e rosse risalta, avvicinandosi (scatto `paratia1`). Si capisce anche dove andare: sopra il ramo giusto c'è il cartello verde d'uscita, con la sua luce.
- **Bivio 3: si vedono il disco e la lampada.** Il disco a strisce si vede, e così la lampada in alto, a destra della colonna. Più avanti c'è il cartello verde.
- **Corridoio delle pile: la luce verde della ciambella si vede da ogni punto.** In tutti gli scatti in avanti si vede, in fondo, la luce verde della ciambella. La strada si legge bene all'inizio, vicino all'ingresso illuminato, e vicino alle lampade sulle pile. In mezzo la fila di transenne quasi non si vede (`corridoio_2` e `corridoio_3`, mediana sotto 1): si va dritti verso il verde.

I miei valori sono più bassi di quelli di `docs/report/corridoio_20/misure.md`: lì c'erano la GI e il preset alto, qui no. Il confronto vale fra scatti presi allo stesso modo.
