# Collaudo dei raggi nella crepa (29 ottobre)

Squadra collaudo. Confronto fra `lavoro/godot` **1d9ecf41** (prima) e `lavoro/raggi-crepa` **436b27c2** (dopo), che fa
passare da RaggioSicuro i 7 raggi che cercano un appoggio.

**Esito: va. Fuori dalla crepa non cambia niente, e nel gioco di adesso non si muove niente.** 0 righe "ERROR: BUG,".
test_raggi_crepa 10/10, test_torre 94/94.

## 1. Posizioni finali

`godot/tests/collaudo/confronto_raggi.gd` apre la sala intera negli stati **inizio**, **ritorno** e **risolto**, con la
risalita e la torre caricate, e scrive in un JSON le posizioni. `confronta_raggi.py` confronta i due commit e mostra
ogni differenza sopra 1 mm (i confronti sono in `confronti/`).

| Cosa | Inizio | Ritorno | Risolto |
|---|---|---|---|
| 16 Polaroid (posizione e rotazione) | 0,000 mm | 0,000 mm | 0,000 mm |
| Griglia del fondo delle medusine (57x39, 2223 punti) e punto più profondo | 0 punti diversi | 0 | 0 |
| Bave rosa (1 all'inizio, 6 dopo: scia del ritorno e inseguimento), tutti i vertici | 0 vertici diversi | 0 | 0 |
| Tutti i Node3D del livello (11.255-11.308) | 32 a 1,0-1,1 mm: i gommoni del tunnel che galleggiano | solo rumore | solo rumore |

- **Rumore**: due giri dello stesso commit (`confronti/rumore_*.txt`) muovono già luci della sala che dondolano,
  superfici dell'acqua, la medusa, i gommoni, le tre pompe che vibrano (8-15 mm) e una goccia della scia che cade
  (60-196 mm). Sono le stesse cose che cambiano fra prima e dopo: nessun nodo si sposta per i raggi.
- **Pozze e galleggianti**: nel gioco non ce ne sono (0 WaterPuddle, 0 WaterBobber in tutti e tre gli stati). Ci sono
  solo nei livelli di prova, quindi su questi due non c'è niente da confrontare nel gioco. Anche le gocce (Gocce) sono
  solo nello sfondo del menu.
- Quindi oggi nessuno dei punti del gioco cade su una crepa. La correzione serve per quando ci cadono, come il
  giocattolo del ricontrollo di ambienti-2.

## 2. Controllo di posizionamento

Uguale sui due commit: 0 casi nuovi, 63 già noti, 12 eccezioni non più trovate, 0 da correggere; 2 controlli ok su 2.

## 3. Prestazioni (headless, CPU)

| Misura | Prima | Dopo |
|---|---|---|
| Griglia delle medusine (`_costruisci_griglia`, 30 volte, mediana di due giri alternati) | 9,3 e 9,4 ms | 12,7 e 10,1 ms |
| Appoggio di una Polaroid (`_snap`) | 0,003 ms | 0,003-0,004 ms |
| Posa._raggio, 2000 raggi sparsi nella sala | 14,3-14,8 s (7,2 ms l'uno) | 15,6-15,7 s (7,8 ms l'uno) |
| Torre a pezzi: fotogramma più carico (3 giri) | 59, 68, 54 ms | 63, 46, 67 ms |
| Torre a pezzi: passo delle Polaroid (3 giri) | 9,4, 12,1, 9,2 ms | 12,7, 8,3, 12,0 ms |
| Strada del capitolo (`misura_blocchi`): fotogrammi sopra 100 ms, il peggiore | 7, 740 ms | 6, 697 ms |

- **Griglia delle medusine:** sale di circa 1-3 ms, per il passaggio in più che cerca i punti sospetti. È un fotogramma solo, quando la sala si apre, ed è dentro le oscillazioni della macchina (fra 8,2 e 16,1 ms nello stesso commit).
- **Posa:** sale di circa 0,6 ms a raggio, l'8%. Quasi tutto il costo di Posa è la ricerca della mesh, non la fisica.
- **Il resto:** dentro il rumore. Nella torre un passo che la correzione non tocca (il modello dell'inseguimento) va da 117 a 177 ms fra due giri.

Il confronto del "prima" si è fermato una volta a metà del controllo di posizionamento, perché lo spazio su disco della sessione era finito. L'ho rifatto dopo aver liberato spazio: i risultati sopra sono tutti di giri completi.
