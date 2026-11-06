# Ritocchi degli enigmi per la 0.3.21 (enigmi, 6 novembre)

Le scelte dell'utente del 4 novembre sulla pagina "Ritocchi del capitolo 1" (GDD, "Dopo la 0.3.20: correzioni e ritocchi del
capitolo 1"). Branch `lavoro/ritocchi-enigmi-0321`, da `lavoro/godot` 67719e8c.

## Cosa è cambiato

1. **Cartello delle pozze (scelta B).** Non è più nell'infermeria: è nel corridoio del personale, quello fra l'approdo
   del fiume e l'infermeria, con l'oblò di lei. Sta sul muro est, di fronte all'oblò, dalla parte del capannone, a 18 cm
   dall'angolo e a circa 2,5 m dalla porta dell'infermeria. Chi arriva dall'approdo lo ha subito a destra. Ha il suo
   faretto bianco a soffitto, più stretto (11°) e con l'ombra, così la luce non passa il muro. L'infermeria è tornata
   senza cartello e senza faretto. Le luci colorate vicine non prendono il cartello (vedi
   `docs/tecnico/pozze_colorate/LEGGIMI.md`):
   - la lampada rossa del corridoio;
   - quelle del capannone, senza ombre, che passavano il muro;
   - quelle dell'infermeria;
   - la luce rosa di lei negli oblò.

   Così i quadratini hanno i colori delle pozze.
   - Scatti prima e dopo: `cartello_corridoio_prima_dopo.jpg`. La luce del corridoio cambia solo sul cartello e in un
     alone stretto attorno; pavimento, soffitto, oblò e porte sono uguali.
2. **Album delle Polaroid (A).** Nel menu di pausa c'è la voce "Polaroid": 16 cornici in due file da otto, nell'ordine
   delle foto, col contatore "n su 16".
   - Le trovate mostrano la foto e, scelte, si riaprono grandi; chiudendole si resta nell'album, in pausa.
   - Le altre sono cornici vuote, senza indizi.
   - Funziona con mouse, tastiera e joypad (A apre, B chiude), in italiano e in inglese.
   - Il HUD, raccogliendo, dice "Polaroid: n su 16".
   - Il salvataggio è quello di prima.
3. **Cassaforte (A).** Un clic metallico a ogni cifra, diverso per ogni rotella. Col codice giusto suona il "fatto
   giusto", poi il chiavistello, e lo sportello si apre girando col cigolio, invece di scattare aperto. Col codice
   sbagliato non succede altro.
4. **Dischi del fiume (A).** Quando il getto gira una paratia, il disco suona come un gong di lamiera. Le due chiuse
   del bivio, mentre si muovono, suonano motore e catene (lo stesso suono delle paratie della camera delle onde) e, quando
   arrivano, il colpo sordo.
5. **"Fatto giusto" (A).** Il jingle della botola accorciato a tre note un po' stonate, dal punto dell'enigma:
   - acquari: l'acquario del miscuglio;
   - giocattoli: la botola;
   - pozze;
   - cassaforte.

   Non suona riprendendo da un checkpoint.
6. **Disegno guida dei giocattoli.** Non è più sul muro della piscina a onde: è su un cartoncino di 1,0 x 0,86 m legato
   con quattro fascette alla ringhiera sud della pedana verde della struttura di gioco dell'area bimbi (la torre col tetto
   blu, accanto alla scala della P4).
   - È appoggiato ai due corrimani e sta all'altezza degli occhi: il piano tocca la faccia davanti dei tubi e ne resta
     staccato al massimo 2,3 mm dove i tubi rientrano.
   - Le fascette (ricontrollo di ambienti-1 del 6 novembre) sono anelli veri: ognuna esce da un foro del cartoncino
     (6 mm sotto il corrimano alto, o sopra il basso), passa davanti fino al bordo, lo scavalca e gira attorno al tubo,
     stretta a 0,3 mm, con la testa della chiusura dietro. Larghe 4,5 mm, spesse 1,3. Stanno fra le sbarre, a 44 cm dal
     centro. La forma dei tubi è misurata sui triangoli della mesh: niente entra nel tubo né nel cartoncino fuori dai
     fori. Scatti da davanti e da dietro: `fascette_davanti_dietro.jpg`.
   - Da sud e da sud-est si vede intero; da sud-ovest lo copre il fungo.
   - Il coordinatore ha approvato il punto il 6 novembre: `disegno_giocattoli_struttura.jpg`.

## Cosa ricontrollare e da dove

- **Corridoio del personale** (Risalita: x da -36 a -34, z da 48,1 a 50,7, pavimento a -5,4). Da guardare:
  - entrando dalla porta del personale dell'approdo, e dalla porta dell'infermeria guardando indietro;
  - il cartello a contatto col muro, il faretto col cavo fino alla scatola sul muro, e la Polaroid 15 per terra sotto il
    cartello, che non dev'essere coperta;
  - i colori dei quadratini, con lei affacciata all'oblò e dopo;
  - stati: prima e dopo le pompe; partenza F9 "fiume".
- **Infermeria**: il muro nord a ovest della porta nord, dove stava il cartello: niente cartello, niente faretto, il
  listello continuo.
- **Cassaforte**: girare le rotelle, provare un codice sbagliato, poi 4-1-7 (sportello che si apre col suono, la keycard e
  la P11 si prendono). Riprendere dal checkpoint: aperta, senza suoni.
- **Fiume**: dalla ciambella, colpire i dischi dei tre bivi; ascoltare il gong, il motore delle chiuse e il colpo in fondo.
  Morendo o ripartendo con le chiuse da girare, le chiuse si rimettono a posto col loro suono.
- **"Fatto giusto"**: risolvere acquari, giocattoli, pozze e cassaforte; riprendere ognuno da risolto (non deve suonare).
- **Album**: dal menu di pausa, in italiano e in inglese, con mouse, tastiera e joypad; con 0, alcune e 16 Polaroid.
- **Area bimbi della sala** (la struttura: x da -18,3 a -9,7, z da -20,7 a -14,3). Da guardare:
  - il cartoncino dal percorso a sud, da sud-est e da vicino, con le fascette, anche da dietro, dalla pedana verde;
  - la P4 sul pianerottolo in cima alla scala, che non dev'essere coperta;
  - il muro ovest della parte profonda della piscina a onde, senza il disegno;
  - stati: piscina piena e vuota (tappa 5).

## Strumenti

- `godot/tests/collaudo/scatti_corridoio_personale.gd <cartella> [prima|dopo]`: gli scatti del corridoio ("prima" toglie il
  cartello).
- `godot/tests/collaudo/colori_cartello_pozze.gd <cartella> [varianti]`: i colori del cartello contro quelli delle pozze;
  stampa anche le luci colorate che arrivano al cartello. La variante "senza_colorate" serve da riferimento.
- `godot/tests/collaudo/scatti_disegno_torre.gd <cartella> [giro|disegno|fascette] [prima|blackout]`: la sala per parti, il
  giro attorno alla struttura, le viste del disegno e le fascette da vicino.
