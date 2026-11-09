# Ricontrollo dei passi lunghi del tunnel (#149), enigmi, 9 novembre

- Branch di ambienti-2: `lavoro/tunnel-passi-lunghi` `48201c67`, che contiene anche le lampade della torre (`3effd587`).
- Confronto con la candidata 0.3.23 `f2f810a2`.
- Il branch parte da `3effd587`, che è già nella candidata. Del codice, rispetto a lì cambiano solo:
  - `sala_sottomarino.gd`, `sottomarino_arredi_a1.gd`, `sottomarino_arredi_a2.gd`: i passi spezzati, il thread, `_a_filo_del_muro`;
  - `sala_torre.gd`: l'elenco delle forme per `_raggio_fisica`;
  - `posa.gd`, `sala_principale.gd`, `oblo_lei.gd`, `riscaldamento_shader.gd`: solo stampe con `TORRE_TEMPI`.
- Ogni prova sulla candidata e sul branch, una dopo l'altra, sotto `render.lock`, con almeno 13,5 GB liberi.

## Esito: superato, con un difetto piccolo da correggere

- Il tunnel è identico, a pezzi e tutto insieme, nella scena di prova e nel gioco vero. La torre pure.
- Nessun passo della costruzione sopra i 25 ms (uno solo a 47,7 ms una volta, punto 2).
- Nel gioco tutto come nella candidata.
- Posizionamento: 0 casi da correggere. Cielo: 0.
- Il thread regge l'uscita al titolo, la morte e l'uscita dal gioco durante la costruzione. Il log è senza errori e
  senza «Lambda capture».
- **Il difetto**: simulando un compito lento nel thread e chiudendo il gioco mentre la costruzione lo aspetta, il log ha
  2 righe `ERROR: Invalid Task ID` (punto 4). Il gioco esce bene. Nel gioco vero non l'ho visto: i compiti finiscono in
  pochi millisecondi.

### 1. Il tunnel e la torre sono identici

Strumento: `godot/tests/collaudo/sonda_nodi_tunnel.gd`. Per ogni nodo scrive tutte le proprietà salvabili, non una
scelta:
- la trasformazione nel mondo (al decimo di millimetro), la visibilità, gli strati;
- le luci: colore, energia, portata, attenuazione, ombre, maschere di luce e di ombra;
- le collisioni: strati, maschere, la forma coi suoi dati;
- le mesh con i dati di ogni superficie e i materiali coi loro parametri;
- le istanze dei MultiMesh.

Le risorse si scrivono come impronta del contenuto. Il confronto lo fa `strumenti/confronta_nodi.py`. Come rumore
conta quello che cambia da solo fra due letture della stessa versione:
- le corde e i segni di Posa dei gommoni che galleggiano;
- le ossa di lei e dei bambini;
- una lampada della torre che lampeggia.

| Dove | Come si costruisce | Nodi (candidata / branch) | Diversi (oltre il rumore) |
|---|---|---|---|
| Scena di prova | a pezzi, 6 ms per fotogramma | 2844 / 2844, stesso ordine | 0 |
| Scena di prova | tutto insieme | 2844 / 2844, stesso ordine | 0 |
| Gioco vero, F9 Inseguimento | a pezzi nelle condotte, con la torre in sala | 2844 / 2844, stesso ordine | 0 (due letture, a 95 s di distanza) |
| Gioco vero, F9 Tunnel | tutto insieme, dal checkpoint 6 | 2845 / 2845, stesso ordine | 0 |
| Torre, gioco vero, F9 Inseguimento | come nel gioco | 1132 / 1132, stesso ordine | 0 (due letture) |

- Quindi posizioni, forme e luci, con strati e maschere, sono uguali in tutti e cinque i casi.
- Lo è anche dove conta il cambio di `_a_filo_del_muro`: il tunnel costruito nelle condotte, con la struttura
  dell'inseguimento in sala.
- In ogni versione, «a pezzi» e «tutto insieme» differiscono solo per lo strato 13 del riscaldamento (1036 mesh) e per
  il volume di un suono, uguali nelle due versioni.
- Una nota sullo strumento. La prima versione della sonda scriveva gli oggetti dentro elenchi e dizionari col numero
  d'istanza: per esempio il muro di `ObloLei` coi suoi materiali e le librerie delle animazioni. Così c'erano differenze
  finte. Con la seconda versione spariscono (file `confronti.txt`).
- `test_lampade_torre_strade`: 22 controlli ok, 0 falliti, sulla candidata e sul branch.
- Gli scatti nel tunnel costruito a pezzi (foglio `1`, 15 viste: lampade tonde, gommoni, gallerie, relitto, approdo,
  portello):
  - differenza media fra candidata e branch da 0 a 0,27 su 255;
  - i pochi pixel diversi sono sui gommoni.

### 2. I tempi della costruzione (`misura_tunnel_pezzi.gd` con `TORRE_TEMPI`)

> **Correzione del 9 novembre, pomeriggio.** Questi tempi sono della scena del solo tunnel. Nel gioco vero, con la sala e
> la torre, i passi costano di più, e su `48201c67` alcuni passi nuovi sono arrivati sopra i 25 ms (`_occupati_tratto` fino
> a 36,6). Vedi `correzione_b3f71a0c/LEGGIMI.md`, «Correzione al primo ricontrollo».

| | Candidata (3 giri) | Branch (5 giri) |
|---|---|---|
| Passi sopra 20 ms | `_abisso_oblo` 79-95, `_pesci` 57-93, `_luci` 85-87, `_tartaruga` 52-69, `_approdo` 39-53, `_buco_anello` 42-51 (6 per giro), `_relitto` 27-42, `_pesce_mensola` 21-33, `_reti` 27-29, `_pezzo` 22-28, `_fine` 23-25 | `_pezzo` 20-27 (una volta 47,7), `_relitto_staffe` 22,6-24,9, `_occupati_tratto` 20,2-22,2, `_galleria` 20,5, `_tartaruga` 20,1 |
| Fotogrammi sopra 50 ms nella costruzione | 4-5 per giro (fino a 97 ms) | 0 |
| Costruito in | 3,9-4,1 s | 3,7-4,2 s |

- Nessun passo nuovo sopra i 25 ms.
- `_relitto_staffe` arriva a 24,9 ms: un po' sopra i 20-22 dichiarati, ma dentro i 25.
- `_pezzo` il branch non lo tocca. È fra i primi passi, e anche nella candidata va a 21,6-28,4 ms. Il 47,7 è successo una
  volta, nel primo giro, e non si è ripetuto negli altri quattro.
- Un fotogramma di 50 ms (1 giro su 5) cade dopo la costruzione, nel riscaldamento: non nei passi cambiati.
- I compiti dell'involucro della lampada sono sempre pronti prima della prima lampada: attesa di 0 fotogrammi in tutti
  i giri e in tutte le partite.
- **`test_attesa_zone` 5 volte di fila** (con `TORRE_TEMPI`): 6 controlli ok su 6 in tutti e 5 i giri. Il portone si
  apre dopo 7,0-7,1 s. Il fotogramma peggiore è di 39, 52, 38, 60 e 42 ms: nessuno sopra i 100 ms.

### 3. Nel gioco (senza schermo, il gioco vero)

- **La corsa intera** (`sonda_corsa_tunnel.gd`), da F9 Tunnel e da F9 Inseguimento, uguale nelle due versioni:
  - tutta la strada del tunnel, un punto ogni 3 m;
  - i checkpoint 6, 160, 300 e 445 (più quello della torre da F9 Inseguimento);
  - torre e condotte liberate dopo la prima curva;
  - due morti, dopo 100 m e dopo 300 m, con la ripartenza dal checkpoint giusto e il tunnel rifatto;
  - nel tunnel 87 luci, di cui 52 delle lampade tonde a energia 0,8 (4 × 20%), 14 gommoni e 3 gallerie;
  - il portello chiuso, la fine del capitolo e il ritorno al titolo.
- **Il fondo nero dietro la porta del bacino** (`sonda_lampo_casi.gd`, i 5 casi del collaudo del fondo):

  | Caso | Vuoto | Doppioni | Strato 13 giusto | Nero sopra il tunnel pronto |
  |---|---|---|---|---|
  | F9 Inseguimento | 0 | 0 | 1 su 1 | 9 fotogrammi (candidata 4) |
  | Morte nelle condotte | 0 | 0 | 2 su 2 | 26 fotogrammi, 0,43 s (candidata 8) |
  | Due morti di fila | 0 | 0 | 3 su 3 | 10 |
  | Continua dal bacino | 0 | 0 | 2 su 2 | 3 |
  | Dalla torre al bacino | 0 | 0 | 1 su 1 | 2 |

  - Il fondo c'è finché il tunnel non è pronto, e mai due insieme.
  - I fotogrammi di nero dopo il tunnel pronto variano da un giro all'altro. Nel ricontrollo del lampo erano 1-16, sulla
    stessa strada.

### 4. Il thread nuovo (`sonda_thread_tunnel.gd`, `sonda_thread_lento.gd`)

Partita F9 Inseguimento, col tunnel che si costruisce a pezzi nelle condotte.

- **Uscite durante la costruzione**, tutte riuscite. Dopo il titolo, un'altra F9 Inseguimento arriva fino al tunnel
  pronto:
  - torna al titolo a 0, 2 e 8 fotogrammi dalla partenza dei compiti, a metà dei passi e all'ultimo passo;
  - muore a 0 e 4 fotogrammi e a metà dei passi;
  - esce dal gioco a 0 e 3 fotogrammi: uscita 0.
- **Col pool dei thread occupato** da 12 lavori finti di 2,5 s, dall'inizio della partita: 5 casi, tutti riusciti. Anche
  così i compiti finiscono prima della prima lampada.
- **Con un compito lento simulato**: un compito della stessa classe, sulla stessa mesh, che nel thread dorme 8 s, così
  la costruzione deve aspettarlo davvero.
  - Senza uscire: la costruzione aspetta 7,5 s (1086 fotogrammi) senza fermare il gioco, con fotogrammi al più di
    55 ms, poi finisce. Tunnel pronto.
  - Titolo e morte: il gioco aspetta che la costruzione finisca e poi esce. Tutto bene.

    Il fotogramma di 1,7-1,8 s che si vede dopo è lo smontaggio della sala, a compito già finito. Sulla candidata non
    l'ho misurato.
  - **Uscita dal gioco (`Game.esci`)**: `Game.esci` non aspetta la costruzione. In `_exit_tree`
    (`sala_sottomarino.gd:3089`) si riaspettano anche i 2 compiti che `_finisci_involucri` aveva già aspettato, e il log
    scrive 2 volte `ERROR: Invalid Task ID`.
    - Il gioco esce bene, con codice 0, dopo aver aspettato il compito ancora aperto.
    - Correzione: in `_finisci_involucri` togliere dall'elenco ogni compito appena aspettato (per esempio
      `_involucri_lavori.pop_front()` al posto del `for`). Così `_exit_tree` aspetta solo quelli ancora aperti.
- **Log**: in tutte le partite (corse, fondo nero, thread, attesa zone, nodi), prima dell'uscita, nessun errore, nessun
  avviso e nessuna «Lambda capture». Fanno eccezione:
  - l'audio, che nella macchina di prova non c'è;
  - le risorse ancora in memoria all'uscita, che le prove chiudono di colpo: le stesse sulla candidata.

### 5. Posizionamento e cielo

- `controllo_posizionamento.gd`:
  - 0 casi nuovi, 64 già noti, 0 da correggere, uguale alla candidata;
  - i 21 casi del tunnel sono identici;
  - cambia solo il dettaglio di 3 casi «voluti» del fiume, che nella candidata ha già la correzione della riga
    (`812f163f`) e nel branch no.
- `controllo_cielo.gd` sul branch: «ok, il cielo non si vede da nessuna parte».
- Negli strumenti di posizionamento e del cielo restano gli stessi messaggi della candidata, in numero uguale. Non
  vengono da questo branch:
  - indici delle blend shape;
  - una forma Jolt vuota;
  - l'owner dei pulsanti del portello.

## Fogli e file

- `fogli/1_tunnel_a_pezzi_candidata_e_branch.jpg`: 15 viste nel tunnel costruito a pezzi, candidata a sinistra e branch
  a destra, con la differenza media.
- `confronti.txt`: i confronti dei nodi, coppia per coppia.
- `risultati.txt`: le righe chiave di tutti i log (tempi, corse, fondo nero, thread, attesa zone, posizionamento, cielo).
- Strumenti:
  - in `godot/tests/collaudo/`: `sonda_nodi_tunnel.gd`, `sonda_corsa_tunnel.gd`, `sonda_thread_tunnel.gd`,
    `sonda_thread_lento.gd`, `scatti_tunnel_pezzi.gd` (gli scatti di `scatti_sottomarino.gd` col tunnel a pezzi,
    `SCATTI_PEZZI=1`) e `sonda_lampo_casi.gd` (dal ricontrollo del lampo);
  - in `strumenti/`: `confronta_nodi.py`.
