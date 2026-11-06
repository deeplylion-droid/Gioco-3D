# Le sagome del club nelle condotte dell'inseguimento (enigmi, 6 novembre)

Scelte dell'utente del 6 novembre sulla pagina "Vasche delle condotte" (GDD, "Vasche delle condotte come giochi per
bambini"): **cartonati A**, le sagome in piedi del club dei bambini della nave, e **Jilly fra i disegni A**.
Branch `lavoro/sagome-club`, da `lavoro/candidata-0321` b44dfab7.

## Cosa c'è

**Il motivo.** Le condotte erano il "percorso avventura" del club dei bambini della nave: le vasche erano le tappe, i
bersagli il gioco "colpisci e apri". Ogni stagione i bambini facevano cartonati nuovi e lo staff li lasciava lì, i
vecchi coi nuovi. Poi la sala si è allagata.

**Le sagome.** Sono dodici animali del mare, quattro per vasca, alti da 55 cm a 1,3 m:
- vasca 1, la spiaggia: balena, stella marina, tartaruga, granchio;
- vasca 2, il mare aperto: pesce palla, polpo, delfino, squalo buffo;
- vasca 3, il fondo: foca con la palla, pesce a righe, razza, cavalluccio.

Come sono fatte:
- cartone ondulato da 5 mm, tagliato a mano: il contorno va a colpi di forbice, un po' storto, e sul taglio si vede il
  cartone;
- davanti, tempera bianca stesa male, col marrone che si vede ai bordi, e sopra il pastello del gioco
  (`assets_src/scarabocchi/pastello.py`), senza immagini fatte con l'IA. Dietro, il cartone nudo;
- al posto della firma, la manina del bambino in un colore suo: niente nomi, date o lettere.

**Le età.** Ce ne sono di tre:
- vecchie (balena, stella, polpo, cavalluccio, foca): colori slavati, carta ingiallita, il fondo gonfio d'acqua fino a
  una riga di marea, puntini di muffa;
- medie (tartaruga, pesce palla, delfino, razza): colori opachi, colpi, uno strappo riparato con lo scotch ingiallito;
- una nuova per vasca (granchio, squalo, pesce): colori vivi.

**Jilly fra i disegni.**
- Sul fianco della balena vecchia (vasca 1) i bambini hanno disegnato la mascotte sorridente coi pesci.
- Dentro il pesce palla (vasca 2) lei è alta, coi tentacoli lunghi sopra i bambini piccoli piccoli.
- Sul pesce nuovo (vasca 3), al posto dell'occhio del pesce, c'è il suo: grande, nero e rosso, con le ciglia.

Nessuna sagoma ha la forma di lei. Il polpo è arancio e ha le zampe allargate, così non sembra una medusa.

**Come stanno su.**
- Vasca 1 e 3: in piedi sul bordo di piastrelle, girate verso l'acqua, con la faccia a 2,5 cm dallo spigolo interno.
  Il bordo è largo 18 cm e non ci passa nessuno. Dietro c'è un puntello di cartone incollato alla schiena, col piede
  piegato sul bordo, e sul piede un mattone, accanto al puntello. Il punto più basso del taglio poggia sul bordo.
- Vasca 2: non ha bordi liberi, ma ha la passerella nord con la ringhiera. Le sagome stanno in piedi sul grigliato,
  dietro la ringhiera, contro il corrimano basso (le più alte lo toccano). Ognuna è legata con lo spago a due montanti:
  lo spago passa da due fori del cartone, uno per parte del montante, gli gira attorno stretto e si annoda dietro.

**Dove non stanno.**
- Le bocche dei tubi.
- Le paratie e i bersagli: almeno 1,4 m in pianta.
- I pali delle lampade da lavoro.
- I lati da cui sale lei: nella vasca 1 nord-ovest (la bava rosa sul bordo), nella vasca 2 est, nella vasca 3 sud.
- Le salite nuove di mascotte (la mano sul bordo della vasca 3, la salita veloce della vasca 2): **da ricontrollare
  quando entrano**.

Le sagome non hanno collisioni.

**La luce.** Un filo di luce propria nei pastelli (0,1, come il disegno guida dei giocattoli, i "pastelli
fosforescenti" già approvati), così si leggono anche lontano dalle lampade da lavoro.

## I file

- `assets_src/sagome_club/`:
  - `animali.py`: i disegni;
  - `genera.py`: le texture, il taglio e le età;
  - `posa.py`: dove stanno, i fori, il puntello, il mattone e lo spago;
  - `sagome.json`: il contorno tagliato.
- `godot/assets/sagome_club/`: le 12 texture (VRAM compresse, con mipmap) e `posa.json`.
- `godot/scripts/game/sagome_club.gd` (`SagomeClub`): le costruisce nella sala, una per passo della coda di
  costruzione. Si aggancia con una riga in `SalaInseguimento._passi()`.
- `godot/tests/test_sagome_club.gd` (in CI):
  - dodici sagome, quattro per vasca, una nuova per vasca, i tre disegni di lei;
  - girate verso l'acqua e viste dagli occhi;
  - il punto più basso entro 5 mm dal bordo o dal grigliato;
  - puntelli, mattoni e legature;
  - lontane da bocche, paratie e salite di lei;
  - nessuna collisione.
- `godot/tests/collaudo/scatti_sagome_club.gd <cartella> [giro|vicino]`: gli scatti dagli occhi in tutti gli stati e
  quelli ravvicinati. `SCATTI_LUCE=1` accende una luce di servizio sulla camera.

## Cosa ricontrollare e da dove

- **Dagli occhi, in ogni vasca**: in piedi nell'acqua, girandosi tutto intorno. Le sagome devono leggersi sotto la
  lampada da lavoro e lontano da lei. Nella vasca 2 si vedono dietro la ringhiera.
- **Stati**:
  - lei su in ogni vasca: le sagome non entrano in lei e lei non entra nelle sagome;
  - paratie aperte;
  - grata calata.
- **Da vicino**:
  - per le sagome sul bordo: il punto più basso sul bordo, il puntello attaccato alla schiena e al suo piede, il piede
    sul bordo, il mattone sul piede;
  - per quelle sulla passerella: il piede sul grigliato e lo spago attorno ai montanti, nei fori, da dietro e da
    davanti.
- **Coi bersagli nuovi di grafica-2 e gli stendardi di grafica**: che le sagome non coprano niente e che i colori e la
  manina vadano d'accordo.
