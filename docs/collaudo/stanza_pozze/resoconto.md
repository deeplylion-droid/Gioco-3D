# Collaudo della stanza delle pozze colorate (31 ottobre - 1 novembre)

Squadra collaudo. Ho controllato `lavoro/stanza-pozze` **2834d4d4**:
- la stanza, la porta stagna e la scala spostata di ambienti-1;
- l'enigma e il cartello di enigmi.

Ho usato il giocatore vero coi tasti veri:
- **senza schermo**, nel gioco intero, per i test, la partenza F9 e i Continua;
- **col renderer vero**, nella Risalita della scena di prova, per gli scatti. Come dicono le regole, non carico la sala intera. L'ambiente è quello della sala senza GI e nebbia volumetrica, con le luci del blackout (le stesse del gioco a quel punto: luci 2). I colori li ho rifatti anche con GI e nebbia accese, e vengono uguali.

**Esito: 4 difetti, da passare a chi ha costruito. 0 righe "ERROR: BUG," in tutti i log.**

## Difetti

1. **Il cartello non si legge con i colori delle pozze** (enigmi, cartello e faretto). Alla luce del faretto i tre quadratini vengono scuri e spenti:
   - l'arancione sembra marrone-grigio;
   - il viola sembra blu;
   - il turchese sembra blu petrolio scuro.

   Anche il bianco della lamiera prende il verde della luce dell'uscita. Qui sotto il colore medio sullo schermo, a 0,8 m dal cartello e dalla passerella sulle pozze. Viene uguale con GI e nebbia accese (`fogli/colori_cartello_pozze.jpg`, `fogli/colori_luce_vera.jpg`).

   | | cartello nel gioco | pozza nel gioco | texture del cartello |
   |---|---|---|---|
   | viola | tinta 228°, saturazione 0,67, luminosità 0,21 | 256°, 0,62, 0,58 | 279°, 0,40, 0,62 |
   | arancione | 40°, **0,22**, 0,14 | 26°, 0,86, 0,61 | 25°, 0,69, 0,81 |
   | turchese | 190°, 0,76, 0,21 | 177°, 0,62, 0,42 | 174°, 0,65, 0,64 |
   | lamiera bianca | 154° (verde), 0,22, 0,39 | | 44°, 0,07, 0,91 |

2. **Porta stagna aperta: l'anta entra nel telaio** (ambienti-1). Il controllo della CI non guarda la stanza risolta: nello stato `risalita_dopo` l'enigma resta aperto e la porta chiusa, mentre la regola del 22 ottobre chiede anche gli stati che cambiano dopo. L'ho fatto girare io con le pozze risolte (`tests/collaudo/posiz_pozze_risolte.gd`, solo la Risalita, col blocco). Escono 8 casi nuovi, tutti sulla porta aperta (`posizionamento_risolta.txt`):
   - l'anta passa dentro il telaio per 216 cm, dal lato dei cardini;
   - due pezzi dell'anta hanno il 100% dei vertici dentro il telaio;
   - altri tre pezzi del telaio entrano nell'anta;
   - due pezzi del telaio sono "nello spazio di chi cammina, all'altezza della testa", nel vano. La porta si passa comunque, avanti e indietro.

   Scatti del cardine dalla stanza e dal pianerottolo: `fogli/porta_aperta_cardine.jpg`. Servono due cose:
   - correggere la porta;
   - aggiungere al controllo lo stato con l'enigma risolto.

3. **Scala di servizio al buio totale in cima alla seconda rampa** (ambienti-1). Salendo dalla porta stagna a C3, per circa 1,5 s (5 m) non si vede niente: 6 scatti di fila con luminosità media 0,0-0,7 su 255 e il punto più chiaro a 1-2 (`fogli/scala_su.jpg`, scatti 024-029). Prima la lampada rossa in cima stava 0,5 m dopo la fine della rampa. Ora è in fondo al tratto in piano nuovo, circa 6 m più a sud, e la seconda rampa non ha più luce.

4. **Il muro sud della stanza ha i colori dell'infermeria** (ambienti-1, coerenza). Da x -1,1 all'angolo est il muro sud è quello dell'infermeria. Dal lato delle pozze ha l'intonaco rosa e le piastrelle verdi, mentre il resto della stanza è grigio (`fogli/muro_sud_infermeria.jpg`). Se è voluto, lo decide l'utente.

## Da sapere (non difetti)

- **Grigliato quasi nero.** La passerella lontano dalle plafoniere è quasi nera, anche con GI accesa (metallo senza riflessi). Nelle viste dall'alto sembra un vuoto intorno alle pozze (`fogli/grigliato_nero.jpg`). È una questione di aspetto.
- **Lo zaino si svuota.** Arrivando dal fiume lo zaino è pieno (20 L). Alla prima pozza butta l'acqua e prende solo il colore: scende a 5 L, come vuole la scelta del 31 ottobre.
- **Il corridoio verso C3 è buio**, come prima: luminosità media 1,5-4. Si vede lei nell'oblò.

## Che cosa va

| Prova | Esito |
|---|---|
| Test (senza schermo) | test_pozze 142, test_pozze_strada 20, test_infermeria_gioco 63, test_risalita 18, test_strada 36, test_continua 127, test_partenze_prova 72, controllo_varchi 1: tutti ok |
| Posizionamento della CI col blocco | 0 nuovi, 64 noti, 0 da correggere. La stanza è controllata negli stati della Risalita (90 mesh su 142), ma con la porta chiusa |
| F9 Fiume fino alla stanza, alla scala e a C3 (`tests/collaudo/pozze_continua.gd`) | si entra dalla porta nord e si arriva sulla passerella sud, a terra, girati verso le pozze; pozze piene e porta chiusa. Poi su per la scala fino alla porta di C3 |
| Continua dal checkpoint 14 (ingresso) | sulla passerella sud, nello stesso punto dell'arrivo (3 cm), girati verso le pozze, a terra; pozze tutte piene e porta chiusa. Il colore tolto prima della chiusura torna pieno |
| Continua dal checkpoint 15 (risolta) | davanti alla porta stagna aperta, a 70 cm dal vano, girati verso la scala; turchese, viola e arancione vuote, rosa e bianco latte piene |
| Pozze piene e porta chiusa, dagli occhi (`fogli/giro_*.jpg`) | dall'infermeria si passa la porta nord. Giro della passerella nei due versi: mai fermi, niente fra 0,1 e 2 m sopra i piedi (né collisioni né mesh). La porta stagna è chiusa con la lampada rossa |
| Un colore sbagliato al terzo (turchese, viola, rosa) (`fogli/sbagliato.jpg`) | il gorgo svuota ogni colore. Al terzo la lampada lampeggia e illumina la stanza di rosso per tutto lo scarico e il riempimento (164 fotogrammi accesa), poi si spegne. Si torna a tutte piene e si può rifare |
| Risolta (turchese, viola, arancione) (`fogli/risolta.jpg`) | la porta si apre in 2,6 s e la lampada diventa verde; le tre pozze vuote mostrano il fondo di piastrelle |
| Dentro una pozza | dalla vuota (turchese) e dalla piena (rosa) si esce saltando verso la passerella (`fogli/dentro_le_pozze.jpg`) |
| Scala di servizio fino a C3 e ritorno (`fogli/scala_su.jpg`, `scala_giu.jpg`) | mai fermi, nessuna collisione sopra la testa; sopra i piedi ci sono solo i gradini davanti |
| Arredo (`fogli/ravvicinati_*.jpg`), distanza dal muro misurata sulla scatola della mesh | a 0,2 cm dal muro: quadro e sua canalina (che entra nel soffitto), cartello del pavimento bagnato (solo disegno), estintore, manometri, taniche; griglia dell'aria e retino (sui ganci) a 0 cm. Taniche, secchio e mocio poggiano a terra. Il collettore entra 3 cm nel muro nord, scende nell'angolo sud-est ed entra 3 cm nel pavimento; i due tubetti vanno dai manometri al collettore. Lampada dell'errore e plafoniere attaccate |
| Cartello e faretto | il cartello è a filo del muro (0,0 cm) e il listello si interrompe; il faretto è attaccato al soffitto, col suo cavo fino al muro. Niente davanti al cartello né alla porta stagna |

## Strumenti

In `godot/tests/collaudo/`:
- `pozze_giro.gd`: la stanza dagli occhi, a fasi:
  - giro, colori, ravvicinati, stati, scala;
  - `VERO=1` per accendere GI e nebbia;
- `pozze_continua.gd`: come `test_pozze_strada.gd`, più dove e come si riparte;
- `posiz_pozze_risolte.gd`: il controllo di posizionamento con l'enigma risolto nello stato `risalita_dopo`.
