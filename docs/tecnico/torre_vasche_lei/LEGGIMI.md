# Lei nelle vasche di raccolta della torre: parcheggiato

Branch `lavoro/torre-vasche-lei`, parcheggiato il 15 novembre (decisione del coordinatore): la torre è uscita dalla build 0.4.0 e il branch non entra nella candidata. Non va cancellato: chi riprende il lavoro parte da qui.

## Cosa c'è già

- `SalaTorre._raccolta_lei` e `_vasche_lei` (sala_torre.gd): un `AcquaDiLei` per vasca, l'uscita al centro sul pelo, la luce che parte dal pozzo, `vasche_avviso` 5 s. Lei prende solo chi è ancora nella vasca o sulla parte bassa della scaletta (`in_vasca`, sotto la pedana di più di `vasche_salvo_sotto`, 0,9 m). La `portata` di ogni vasca arriva oltre gli angoli (mezza diagonale + 30 cm).
- Gli interruttori: `lei_vasche` spento nel gioco, `letale_vasche` acceso, `vasche_modo` MANO.
- `tests/test_torre_vasche_lei.gd` (18 controlli), che lo accende col segnaposto intero: per le 5 vasche la luce dal pozzo e l'uscita dopo 5 s, chi risale è salvo, il giocatore nell'angolo più lontano viene preso.
- `tests/collaudo/sonda_vasche_raccolta.gd` e `tests/collaudo/sonda_tubi_vasche.gd`, le due sonde con cui sono stati presi i numeri qui sotto.

## Perché si è fermato

**L'acqua è bassa.** Le 5 vasche hanno 68 cm d'acqua e sono larghe 4,6-5,5 m. Lei intera non ci sta, e il coordinatore ha scelto l'uscita MANO (mano e tentacoli), la stessa delle pozze.

**Le vasche sono sospese.** Sono rette da due puntoni dal traliccio, con sotto una lastra di metallo da 30 cm, e il fondo della sala sta da 4 a 17 m più sotto. Senza uno scarico collegato all'acqua, lei non ha da dove passare. Lo scarico serve tondo, di circa 40 cm, uguale a quello delle pozze, col tubo che porta al pozzo.

**Lungo i tralicci il tubo non passa** (`sonda_tubi_vasche`: una sfera di 0,25 m che scende da sotto la vasca al fondo, a più di 1,2 m dai salti).
- I tralicci hanno le piattaforme a ogni livello, fino a 2,9 m dal centro, e intorno girano gli scivoli.
- Una linea libera accanto al traliccio (a meno di 1 m dalla faccia) c'è solo per le vasche 3 e 4, a 4 m dalla vasca in orizzontale.
- Per le vasche 0, 1 e 2 le linee libere stanno a 3,7-5,7 m dal traliccio.
- Linee libere fino al fondo ci sono subito sotto le vasche. Lo spostamento in orizzontale è di 0 m per la vasca 3, 0,7 m per la 2 e la 4, 1,0 m per la 1 e 3,0 m per la 0. Ma sarebbero colonne libere di 4-16 m, tenute solo ai due capi, nel vuoto dove si cade: il coordinatore le ha scartate.

**La stima.** Per farla bene va rigenerata la torre nel generatore (`tools/blender/torre_a.py`), con gli scarichi pensati lungo i tralicci: 7-10 ore. Si rifanno le GLB, quindi vanno ricontrollate le toppe salvate di torre_A, il muro dell'oblò salvato, le forme salvate e il posizionamento di tutta la torre. Il coordinatore lo proporrà all'utente come un pezzo a sé.
