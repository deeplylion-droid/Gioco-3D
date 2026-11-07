# Gli stendardi dei bambini nella sala delle condotte (6 novembre)

Nota dell'utente: «Lascia le vasche uguali ma aggiungi degli stendardi giganti appesi nel vuoto dietro, nella distanza, niente
disegni ai, falli come s'è fossero lenzuoli appesi e colorati dai bambini. Per il resto non toccare».

- Quattro lenzuoli di 3 x 4,5 m del club dei bambini della nave, colorati col pastello del gioco (`assets_src/stendardi/teli.py`,
  sopra `assets_src/scarabocchi/pastello.py`; niente immagini fatte con l'IA). I colori sono quelli della scatola da 12,
  un po' spenti. La firma è fatta di manine (`disegni.manina`), una per bambino, in basso. Ci sono la riga dell'umidità
  salita dal fondo, la muffa a puntini, qualche strappo e l'angolo sfilacciato.
- I soggetti, d'accordo con enigmi perché non doppino le sagome:
  1. il mare con la nave, il sole e i pesci, su stoffa bianco sporco;
  2. i bambini per mano, su stoffa azzurra;
  3. il gioco del club, coi bambini nella vasca che spruzzano il bersaglio e una Jilly piccola che fa il tifo, su
     stoffa gialla;
  4. il lenzuolo recente, con le manine nere e rosse che salgono, su stoffa rosa, lontano dalla vasca 1.
- Ogni lenzuolo è fermato con le mollette a un bastone di plastica arancio. Il bastone pende da due corde legate alle
  travi del soffitto, e ogni corda col suo nodo è un pezzo solo, stretto alla trave. Le pieghe sono vere: la cima si
  affloscia fra una molletta e l'altra e le pieghe scendono di lì (`assets_src/stendardi/stendardi.py`).
- Dove sono: ognuno accanto a una lampada appesa della sala, che lo illumina, e dove la vista dalla vasca è libera.
  Dietro le paratie erano coperti. Quali stendardi si vedono da quale vasca:
  - dalla vasca 1 l'1, a nord-ovest;
  - dalla vasca 2 il 2, a est;
  - dalla vasca 3 il 3 e il 4, a nord-ovest e a nord.
- Luce: con le lampade accanto si vedono già. Il filo di luce dei pastelli fosforescenti (0,12, come il disegno guida)
  cambiava pochissimo, quindi è spento (`StendardiInseguimento.luce`).
- Controlli:
  - in Blender, ogni pezzo sta ad almeno 25 cm da tubi, tiranti, catene e cavi delle lampade, e i fondi restano oltre i 2 m
    liberi sopra tubi, vasche e scoli;
  - posizionamento: 0 nuovi, 0 da correggere;
  - test_torre 95/95, test_inseguimento 43/43, test_strati 5/5, ripartenze oltre il portone 53/53;
  - riscaldamento delle pipeline 11/11 (il materiale dei lenzuoli è fra i campioni);
  - check_scripts 0, controlli statici 0.
- Peso: circa 7 000 triangoli in tutto, nessuna collisione (lontani e in alto), 4 texture 683x1024 compresse, circa 4 MB
  di VRAM.

Fogli: `foglio_dagli_occhi.jpg` (dagli occhi del giocatore in piedi nelle vasche, luci della sala come le trova, blackout)
e `i_quattro_lenzuoli.jpg` (le texture). La medusa grande nello scatto della vasca 2 è lei, che lo strumento non ha
nascosto: non c'entra con gli stendardi.
