# Da fare dopo la v0.3.12: i pezzi piccoli della torre visibili al controllo

Segnato il 24 ottobre (coordinatore: "la facciamo dopo la v0.3.12").

Il collaudo di enigmi ha trovato i cancelletti delle bocche chiuse sospesi, e il controllo di posizionamento della CI
non li vedeva. I pezzi piccoli messi sulle pedane della torre (cancelletti, grate tonde nelle bocche dei tubi,
lampade, culle) stanno dentro la mesh grande `torre_A`, sotto il nodo `TorreStruttura`. Il controllo scarta come
architettura tutto quello che ha "struttura" nel percorso, e anche i pezzi sopra i 30 m.

Da fare:
1. In `tools/blender/torre_a.py` (e `torre_proposte.py` per `cancello_partenza`), costruire questi pezzi con un
   Costruttore a parte, in un oggetto `torre_A_cancelli-col` (con la sua collisione: i cancelletti fermano il
   giocatore), nel gruppo della struttura.
2. In `godot/tests/controllo_posizionamento.gd`, un'eccezione alla regola `ARCHITETTURA` per i nomi di questi pezzi
   ("cancell", "lampad", "grata_tonda"...), così diventano oggetti e passano dai controlli sospeso e staccato al cm.
3. Rigenerare la torre, rifare il controllo f), test_torre e i ravvicinati.
