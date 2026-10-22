# Controllo di posizionamento: istruzioni per le squadre

Il controllo cerca da solo gli oggetti messi male (regola dell'utente del 21 ottobre). Gira nella CI a ogni push e fallisce se trova un caso **nuovo**, cioè uno che non è nel file delle eccezioni.

Dal 22 ottobre è **severo** (processo approvato dall'utente "per evitare questi errori una volta per tutte"):

- si controllano anche gli oggetti grandi, come pedane, ringhiere e acquari. Restano fuori solo i pezzi d'architettura, riconosciuti dal nome (`ARCHITETTURA`: pavimenti, muri, soffitti, strutture, cupola) e quelli sopra i 30 m;
- ogni oggetto deve **toccare entro 5 mm** qualcosa che lo regge (vedi **staccato**);
- le compenetrazioni si cercano anche fra oggetti diversi della stessa scena `.tscn` e con gli spigoli che passano dentro un altro oggetto, non solo coi vertici dentro;
- tubi, cavi e catene devono avere i due capi collegati entro 1 cm;
- ogni zona si controlla anche **come la vede il giocatore più avanti**: con le parti nascoste all'inizio rese visibili (stato `tutto_visibile`) e negli stati preparati apposta (gli acquari comparsi e risolti col portone aperto). Le due versioni della stessa cosa che non si vedono mai insieme, per esempio le lampade spente e accese, non si contano come compenetrate;
- quando tutti i casi saranno chiusi, la CI fallirà anche con un solo caso `"da correggere"` (`BLOCCA_DA_CORREGGERE`, per ora spento). I casi `"voluto"` li decide l'utente: si propongono al coordinatore col motivo.

Gli elenchi per squadra del primo giro severo sono in `elenchi/`.

Negli stati ogni parte dello stato deve avere visibile almeno metà delle sue mesh (effetti esclusi): se no il controllo fallisce, perché lo stato non l'ha mostrata (così fiume e infermeria, che il gioco nasconde col giocatore lontano, non possono più restare fuori in silenzio). Quello che uno stato fa comparire nello stesso spazio di una cosa già visibile accanto (le lampadine accese sopra le spente) è una variante, non una compenetrazione.

Le mesh con lo scheletro (la medusa) si misurano nella posa in cui sono in quel giro, non in quella di riposo. Negli stati preparati (`interni_dopo`, `acquari_risolti`...) l'ingombro si guarda in tutta la scena, non solo nelle parti dello stato: così esce quello che, aprendosi, finisce nel passaggio. I casi già trovati nel giro iniziale non si ripetono.

I MultiMesh (i dettagli della sala con 6 o più copie, i led, le lamelle) si controllano una copia alla volta. Senza schermo il MultiMesh non conserva le trasformazioni: chi lo crea da codice le lascia anche nel meta `trasformazioni` (`mmi.set_meta(&"trasformazioni", array_di_Transform3D)`, vedi `dettagli_sala.gd`). Per un MultiMesh salvato in un `.res`, il meta va sulla risorsa (`mm.set_meta(...)` prima di `ResourceSaver.save`): si salva con lei. Quelli senza sono elencati nel rapporto.

Per capire perché un oggetto risulta appoggiato o staccato: `POSIZ_TOCCA=pezzo_del_nome` prima del comando stampa, per ogni oggetto col nome che lo contiene, le mesh che tocca.

Dopo aver unito un ramo con modelli nuovi, fai prima l'import (`godot --headless --path . --import`, sotto il lock): se no il controllo guarda i modelli vecchi.

In fondo al rapporto, la sezione **Copertura** dice per ogni giro (zona e stato) quanti oggetti ha controllato in ogni parte: una parte con 0 è una zona che il controllo non ha guardato. Poi elenca le parti nascoste all'inizio e se un giro con stato le ha viste. Quelle "mai controllate" vanno guardate: o si aggiunge uno stato che le mostra (come `risalita_arrivo` per il fiume e l'infermeria, che `risalita_gioco.gd` disegna solo col giocatore vicino), o, se non si vedono mai, si tolgono dalla scena. Le creature, gli effetti, l'acqua e le varianti nello stesso posto di una parte controllata (lampada accesa e spenta) sono segnati a parte.

## Lanciarlo in locale

Da `godot/`, con il lock come ogni Godot:

```
flock /home/user/tools/render.lock godot --headless --path . --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd
```

Ci mette un paio di minuti e usa circa 3 GB. Per controllare una sola scena aggiungi in fondo il nome del file: `sala_principale` oppure `sala_torre`. Le zone nuove si aggiungono alla lista `ZONE` in cima a `godot/tests/controllo_posizionamento.gd`. L'ultima riga dice `RISULTATO: ... 0 falliti` se non ci sono casi nuovi.

## Leggere il rapporto

Il controllo riscrive `docs/tecnico/posizionamento/rapporto.md`, con una tabella per zona: squadra, problema, nodo, posizione (x, y, z nel mondo) e dettaglio. Prima vengono i casi nuovi, poi quelli già noti, infine le eccezioni che non trova più. I problemi sono:

- **sospeso**: l'oggetto non ha niente a meno di 5 cm. Nessun pavimento, parete o soffitto, nessun altro oggetto o filo a cui sia attaccato.
- **staccato**: l'oggetto ha qualcosa a meno di 5 cm, ma non lo tocca: la sua forma convessa, allargata di 5 mm in tutte le direzioni, non tocca né entra in nessun'altra mesh. Contano solo le mesh vere, non le collisioni del gioco (spesso più grandi della mesh). Per esempio una sedia 1 cm sopra il pavimento, un cartello a 2 cm dal muro, una lampadina senza portalampada. Il dettaglio dice a che distanza è il primo appoggio sotto. È staccato anche un **gruppo** di oggetti che si toccano solo fra loro (la lampada e il suo vetro a 2 cm dal muro, una pila di scatoloni con quello in fondo 1 cm sopra il pavimento): ogni gruppo deve toccare un muro, il pavimento, un pezzo grande (oltre 4 m) o l'acqua. Il caso è sull'oggetto più in basso del gruppo, con gli altri nel dettaglio. Oltre alla forma convessa, che riempie i vuoti (fra il braccio di una lampada e il muro), si misura la **distanza vera** fra le mesh, come il collaudo, per gli oggetti sotto i 40 cm, per quelli con un appoggio solo e, per tutti, contro muri e strutture (pezzi oltre i 4 m). Conta come contatto un vertice a meno di 5 mm da una faccia, un vertice dentro l'appoggio o uno spigolo che passa una sua faccia (un capo infilato).
- **ingombro**: qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0,35 e 2 m sopra un pavimento dove si passa a piedi partendo dai checkpoint (non le celle dentro i muri spessi). Non contano le parti che il giocatore apre da sé (cassetti, sportelli: un Interactable con `aperto`, `open` o `aperta_ora`): sporgono come in una stanza vera. Per loro si controllano lo stesso compenetrazioni, distacchi e sospesi. Dove si sta accovacciati per forza (i tubi dell'inseguimento: i nodi con il metodo `in_tubo(piedi)`, lo stesso che usa il gioco) lo spazio controllato arriva solo a 1,05 m, l'altezza da accovacciati. Le parti che si muovono (paratie, la grata dell'inseguimento, portoni, saracinesche, serrande, cancelli: `MOBILI` nel controllo) non fanno mai da pavimento. Il dettaglio dice se è all'altezza delle gambe, del busto o della testa.
- **compenetrato**: una Polaroid, un pulsante, una porta, un cancello o un oggetto da raccogliere entra dentro un altro oggetto.
- **coperto**: lo stesso tipo di oggetto non si vede da nessuno dei punti di vista vicini, a 1-1,8 m all'altezza degli occhi. Conta anche un foglio appoggiato sopra. Il dettaglio dice cosa lo copre.
- **compenetra**: un oggetto di scena ne attraversa un altro. Conta il pieno (muri, bordi, fondi, oggetti chiusi), non il vuoto di una fossa, di una vasca o di un coperchio aperti: un punto è dentro se il raggio verso l'alto passa un numero dispari di facce, e così anche verso il basso o in almeno 3 direzioni orizzontali.
- **estremita_libera**: un tubo, un cavo, una catena o una condotta ha un capo che non è collegato a niente entro 1 cm.

## Dopo una correzione

Rilancia il controllo. Il caso finisce in fondo al rapporto, fra le eccezioni non più trovate: togli la sua voce da `godot/tests/posizionamento_eccezioni.json`.

## Segnare un caso come voluto

Se un caso è voluto, per esempio una porta aperta dove non si passa o il tubo del neon dentro la sua plafoniera, cerca la sua voce in `godot/tests/posizionamento_eccezioni.json`. Se è nuovo, copiala da `rapporto.json`. Poi cambia `stato` in `"voluto"` e scrivi in `motivo` perché va bene così:

```json
{"zona": "interni", "nodo": "Interni/Ambienti/Stanzino/porta_stanzino", "squadra": "ambienti-1",
 "problema": "ingombro", "pos": [0.53, 0.0, 32.25], "stato": "voluto",
 "motivo": "la porta resta aperta contro il muro, il giocatore non ci passa"}
```

Un caso si riconosce da zona, nodo e problema. I nodi creati da codice hanno nomi automatici, come `@MeshInstance3D@217`, che cambiano quando cambia il numero di nodi creati prima: per loro il numero non conta, e al suo posto contano la posizione, arrotondata a mezzo metro, e la `firma`, cioè il modello da cui vengono e la mesh (il file, o la classe e la misura per le mesh fatte da codice). Copia la voce dal `rapporto.json` con la sua `firma`. Le voci con stato `"da correggere"` sono casi noti, già assegnati: la CI non fallisce per loro.

## Mettere gli oggetti

Per non creare casi nuovi, gli oggetti si mettono **con un raggio sul loro sostegno vero**, non a occhio con le coordinate. Lo strumento comune è Posa, in due versioni con le stesse funzioni: una per gli script del gioco e una per i generatori Blender. Ogni funzione trova il sostegno (pavimento, muro, soffitto, gancio), mette l'oggetto a contatto e, con `lega`, lo fa figlio del sostegno, così lo segue se il sostegno si sposta. Se non trova niente, lascia l'oggetto dov'è e avvisa: il controllo lo segnalerà.

**Nel gioco**: `godot/scripts/posizionamento/posa.gd` (classe `Posa`). L'oggetto deve essere già nella scena, perché serve la fisica. Posa si appoggia alla **superficie che si vede**, non alla collisione: il raggio della fisica trova il sostegno, poi sullo stesso raggio (fino a 30 cm oltre) si cerca la prima faccia di una mesh visibile. La collisione di un muro può sporgere qualche centimetro oltre le piastrelle (nella vasca centrale 3 cm: la targa restava staccata). Se lì non c'è nessuna mesh, vale la collisione. Con `lega` l'oggetto diventa figlio della mesh colpita.

```gdscript
Posa.appoggia_a_terra(vaso)                        # l'origine del vaso sul pavimento sotto
Posa.appoggia_a_terra(cassa, 0.25, true)           # origine 25 cm sopra il fondo; diventa figlia del pavimento
Posa.fissa_al_muro(lampada, Vector3.BACK, 0.08)    # guarda verso BACK; il retro, 8 cm dietro l'origine, sul muro
Posa.fissa_al_soffitto(plafoniera, 0.1)            # la cima, 10 cm sopra l'origine, sul soffitto
Posa.appendi_a(lampadina, gancio, 0.03)            # l'attacco 3 cm sopra l'origine sul gancio; figlia del gancio
```

Le funzioni restituiscono `true` se hanno trovato il sostegno. Esempio vero: le luci di emergenza della torre (`sala_torre.gd`, `_emergenza`). Test: `godot/tests/test_posa.gd`, nella CI.

**Nei generatori Blender**: `tools/blender/posa.py`. Misura la mesh vera nel mondo, modificatori compresi, quindi non servono gli scarti a mano.

```python
import sys; sys.path.insert(0, 'tools/blender')
import posa
posa.appoggia_a_terra(sedia, lega=True)            # il punto più basso della sedia sul pavimento sotto
posa.fissa_al_muro(quadro, verso=(0, -1, 0))       # verso = la direzione verso cui guarda, fuori dal muro
posa.fissa_al_soffitto(plafoniera)
posa.appendi_a(lampada, gancio)                    # la cima della lampada sul gancio (oggetto o empty)
assert posa.tocca(sedia)                           # controllo nel generatore: tocca qualcosa entro 5 mm?
```

Restituiscono il sostegno colpito, oppure `None`. Gli oggetti di sola collisione (nome con `-col`, `_col`, `colonly`, o spenti nel render) non contano come sostegno: Posa va sulla superficie che si vede. `tocca(obj)` serve per controllare il risultato già nel generatore, prima di esportare. Test: `tools/blender/test/test_posa.py`, da lanciare con il venv di Blender sotto il lock.

**Regole pratiche**:

- prima il sostegno e poi quello che ci sta sopra. Per una pila si va dal basso: ogni pezzo con `appoggia_a_terra` sul precedente;
- dopo aver spostato un sostegno, gli oggetti legati lo seguono, quelli non legati no;
- tubi e cavi: si parte da un attacco vero e si arriva a un altro (muro, macchina, altro tubo), con i capi infilati di qualche millimetro;
- alla fine si rilancia il controllo.
