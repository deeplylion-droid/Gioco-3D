# Ricontrollo torre-fotogrammi 6aaa8373 (contro main e3104cd2)

Fatto da mascotte il 9 novembre, sul branch `lavoro/torre-fotogrammi` 6aaa8373, con main e3104cd2 per il confronto.

**Esito: SUPERATO.** Il risultato è identico a main e i fotogrammi lunghi della torre e dell'inseguimento non ci sono più. Non ho trovato difetti del branch.

## 1. Uguale a prima

- **Collisioni della struttura dell'inseguimento.** Ho confrontato l'impronta md5 di tutte le facce delle forme di collisione. Sul branch è uguale costruendo tutta insieme e a pezzi, e uguale a main: 10 forme, 68.750 facce, md5 `48445379…7ef0` in tutti e tre i casi. La scaletta del bacino si sale col giocatore vero in quattro modi (`test_scaletta_bacino` 13/13) e `test_inseguimento` è 43/43.
- **Soglia della torre.** La mappa uv e la lastra sono identiche a main: stessa mappa, 180 vertici, md5 della lastra `d9338b58…0903`, materiale `M_amb_pavimento`. La sonda è `_sonda_tf_tmp.gd`, lanciata sui due commit. Gli scatti dagli occhi sono `1_soglia_asciutta_e_bagnata.jpg`, nelle pose entrando, uscendo e da vicino. Col pavimento bagnato (WetSurfaceConverter prima della soglia) la lastra prende `M_amb_pavimento_bagnato`, letto al momento, e si legge come il pavimento accanto.
- **La torre compare quando compariva prima.** `test_fondo_porta_bacino` 20/20, `test_torre` 95/95, `test_portone_torre` 20/20. `test_torre_pezzi_uguali` 8/8.

## 2. Tempi (TORRE_TEMPI, `attesa_zone.txt`, `tempi_*.txt`)

| | main e3104cd2 | branch 6aaa8373 |
|---|---|---|
| inseguimento passo 0 (`_modello(struttura)`) | 72-78 ms (caso noto) | 1,2-1,6 ms, più 29 passi `_varco_scalette` da ≤ 7,1 ms |
| mostra torre: completa | 23,6 / 34,7 / 30,9 ms | 4,7-7,1 ms (soglia 0,5-0,8 ms) |

`test_attesa_zone` è stato lanciato tre volte di fila sul branch e tre su main:
- branch: 1 KO (108 ms) e poi 2 ok (peggiore 66 e 91 ms);
- main: 3 ok, ma col caso noto `_modello(struttura)` a 72-77 ms.

Nella prima serie sul branch:
- il primo lancio, a freddo subito dopo l'import, ha avuto quattro fotogrammi di 170-912 ms durante il caricamento nel thread, prima di qualsiasi passo della torre: sono il disco freddo, il lancio dopo è pulito;
- il terzo lancio ha avuto un fotogramma di 103 ms.

**Da sapere: i due KO sul branch (103 e 108 ms) non vengono dal branch.** Vengono dal passo 626 della costruzione della sala, una lambda anonima subito prima dei passi che chiamano Posa vicino a (31; -2,5; -4,08). È lungo uguale su main: 65-76 ms di passi in quel fotogramma su main, 53-87 ms sul branch. Su main quel fotogramma resta sotto 100 ms per poco. Sul branch, a volte, lo supera di pochi ms: in locale 2 volte su 6 lanci. Su llvmpipe è al limite. Se si vuole il test sempre verde, quel passo va spezzato in un lavoro a parte; il branch non lo tocca. In CI 42524723686 il test era verde.

Nessun altro fotogramma nuovo sopra 50 ms tra i passi della torre e dell'inseguimento.

## 3. Ripartenze

- `test_ripartenza_oltre_portone` 53/53: partenze torre, inseguimento e tunnel, e morte subito dopo.
- `test_partenze_prova` (F9) 72/72; `test_continua` 127/127.
- `test_memoria_morti` (sala): +0,01 MB per morte.
- Morti in torre e nell'inseguimento, 5 di fila, la prima a cache vuote (sonda `_sonda_morti_torre_tmp.gd`, `morti_branch.txt` e `morti_main.txt`). Su branch e main la memoria resta ferma (+0,00/+0,01 MB per morte). Le cache restano a 10 forme e 1 mappa: le chiavi sono stabili e non crescono. C'è +1 oggetto per morte, uguale su main: non viene dal branch. Il fotogramma più lungo della ripresa (sotto il nero) è 1,3-1,7 s, sia sul branch che su main.

## 4. Posizionamento e cielo

`controllo_posizionamento`: 0 nuovi, 64 già noti, 0 da correggere. `controllo_cielo`: il cielo non si vede da nessuna parte.

## Note sul codice (nessuna blocca)

- `_varco_forme`: se la forma non ha `resource_path`, la chiave usa l'id dell'istanza. Con il GLB in memoria è sempre lo stesso: le cache sono rimaste a 10 voci dopo 10 morti.
- Se la torre si completa prima che `prepara_uv_pavimento` abbia finito, `_uv_pavimento` calcola tutto subito, con lo stesso risultato, e il calcolo a pezzi poi riscrive lo stesso valore. È corretto. Non è mai successo nei test.
- In `test_torre_pezzi_uguali` il materiale di confronto è sempre la superficie 0. Va bene finché il pavimento ha una superficie sola.
