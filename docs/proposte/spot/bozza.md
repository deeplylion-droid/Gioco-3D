# Spot della crociera Jubilee: bozza

Idea dell'utente (GDD, "Lo spot della crociera Jubilee"). Parte dopo "Nuova partita", subito prima del risveglio. Dura circa 40 secondi. È tutto girato nel gioco vero, passato nel filtro TV a tubo + VHS. Per ora è solo testo: niente scatti e niente render.

## Il testo dello speaker

Uno speaker americano anni '90, caldo e sorridente, con la sigla pulita sotto.

| # | Inglese | Italiano |
|---|---|---|
| 1 | *Wonderwave Cruises presents...* | Wonderwave Cruises presenta... |
| 2 | *...the Jubilee! The happiest ship on the seven seas!* | ...la Jubilee! La nave più felice dei sette mari! |
| 3 | *Splash into Splash Lagoon, the biggest indoor water park afloat!* | Tuffatevi nello Splash Lagoon, il più grande acquapark coperto che galleggi! |
| 4 | *Twist and turn on the Tower of Slides!* | Curve e giri sulla Torre degli Scivoli! |
| 5 | *And meet the star of the show... Jilly Jubilee!* | E conoscete la star dello spettacolo... Jilly Jubilee! |
| 6 | *Jilly loves kids. Jilly will keep them safe. Forever.* | Jilly ama i bambini. Jilly li terrà al sicuro. Per sempre. |
| 7 | *Come aboard. Stay aboard.* (lento, la voce che rallenta e si abbassa) | Salite a bordo. Restate a bordo. |

Le frasi 1-5 sono una pubblicità vera. La 6 è già un po' strana, la 7 si guasta.

## Le inquadrature

| # | Secondi | Cosa si vede | Dove nel gioco | C'è già / va fatto |
|---|---|---|---|---|
| 1 | 0-3 | Schermo blu VHS, "PLAY", poi il logo Wonderwave | Solo grafica 2D | Va fatto: logo Wonderwave (solo disegno e nome) |
| 2 | 3-8 | La cupola di vetro col cielo azzurro, poi giù sulla sala accesa | Sala principale, sotto la cupola | Sala e cupola ci sono. Va fatta la versione "accesa e pulita": luce di giorno, niente ruggine, acqua piena e chiara |
| 3 | 8-13 | Panoramica sulla piscina a onde piena, onde vere | Sala principale, piscina a onde | L'acqua c'è. Va fatta la piscina piena (nel gioco è vuota) |
| 4 | 13-19 | Camera che scende in un tubo della torre, schizzi | Torre degli scivoli | Torre e tubi ci sono. Va fatta la versione pulita e illuminata |
| 5 | 19-26 | Jilly sul piedistallo, luci da spettacolo, logo e insegna nuovi | Vasca di Jilly, sala principale | Medusa, piedistallo, insegna e logo ci sono. Vanno fatti: insegna e targa "da nuove", fari colorati, un saluto di Jilly (animazione nuova) |
| 6 | 26-32 | Primo piano di Jilly che sorride e fa ciao; la camera si avvicina troppo | Vasca di Jilly | Va fatta l'animazione del saluto. L'occhio e la palpebra ci sono (`occhio_chiude` / `occhio_riapre`) |
| 7 | 32-38 | Il nastro si guasta: tracking, colori sbavati, la sigla rallenta (`sigla_rovinata.ogg`), l'audio cala | Stessa inquadratura | Il filtro va esteso con il guasto. La sigla rovinata c'è già |
| 8 | 38-43 | **L'occhio di Jilly** riempie lo schermo e pulsa, sempre più forte | Primo piano dell'occhio | Vedi "Il finale" |
| 9 | 43 | Taglio al nero, ronzio della TV, poi il risveglio | — | C'è già: il risveglio nel corridoio |

## Il finale: l'occhio

- L'occhio di Jilly riempie lo schermo. La pupilla si allarga e si stringe a tempo con un battito che accelera.
- Sopra ci sono spirali e anelli che girano nella pupilla, rosa e viola come i suoi tentacoli, con i colori VHS che si separano a ogni battito.
- I fotogrammi saltano (frame skip) e per un attimo lo schermo va in negativo. L'audio è un ronzio basso che sale, più la sigla al contrario.
- Alla fine l'occhio si avvicina di colpo, e subito dopo c'è il nero.
- Niente sangue e niente gore: fa paura con il ritmo, l'occhio e il suono.

## Stima del lavoro

| Parte | Cosa | Stima |
|---|---|---|
| Filtro VHS + TV a tubo | Si parte dallo shader del monitor della sala pompe (`shaders/tecnici/crt.gdshader`, `tools/rigenera_schermo_crt.gd`). Va aggiunto: tracking, colori sbavati, rumore, guasto crescente, effetto ipnotico dell'occhio | 1 giorno |
| Voce dello speaker | 7 frasi in inglese, voce sintetica anni '90, con riverbero e filtro "TV" | mezza giornata, più la scelta della voce dell'utente |
| Animazioni di Jilly | Saluto sul piedistallo e occhio pulsante (blend shape della pupilla) | 1 giorno |
| Ambienti | Versione accesa e pulita di sala, cupola, piscina piena, torre e vasca di Jilly, solo per lo spot (luci, materiali puliti, acqua piena). Logo Wonderwave | 1-2 giorni |
| Montaggio | Camere, tempi, audio, passaggio al risveglio, "salta" col tasto | mezza giornata |

**Totale: circa 4-5 giorni.**

## Da decidere con l'utente

1. Il testo: va bene, o lo cambiamo?
2. La frase 7 ("Come aboard. Stay aboard."): va bene come chiusura che si guasta?
3. Le inquadrature 3 e 4 (piscina piena e torre): le teniamo tutte e due, o una sola per accorciare?
4. "Wonderwave Cruises" è un nome ancora provvisorio, e le scritte nel gioco sono ammesse solo per Jilly Jubilee. Nell'inquadratura 1 mettiamo il logo Wonderwave, o apriamo subito col logo di Jilly?
