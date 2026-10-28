# L'enigma dei giocattoli nella piscina a onde (consegna del 29 ottobre)

È l'idea A scelta dall'utente il 28 ottobre (GDD, scelte del 28 ottobre), "I giocattoli al loro posto", con la sua nota: "ma facciamo che puoi spingere i giocattoli anche una volta che hai svuotato la piscina".
- Il lavoro sta sul branch `lavoro/enigma-giocattoli`, partito da `lavoro/godot` efc7352f.
- **Non va unito prima che l'utente l'abbia visto.**

## Come si gioca

Nella parte profonda della piscina a onde ci sono quattro elementi:
- **sul fondo, attorno alla botola, tre cerchi di mosaico** larghi 1 m: giallo, rosso e blu. Sono piatti che sporgono di 3 cm e scendono col peso: la serratura della botola;
- **nella pozza, tre giocattoli grandi** di gomma, mezzi pieni d'acqua, che galleggiano: la paperella gialla, il pallone rosso e la balena blu;
- **sul muro ovest della parte profonda il disegno a pastello dei bambini**, che mostra la piscina dall'alto con ogni giocattolo nel suo cerchio. Solo disegno, senza scritte;
- **le medusine luminose**, che nuotano come prima.

I passi:
1. **Si spingono i giocattoli col getto.**
   - Colpito direttamente, un giocattolo va dove va il getto.
   - L'acqua colpita vicino a lui lo porta con sé, e un muro colpito vicino lo respinge via dal muro.
   - Più sei vicino, più spinge.
   - Vicino al suo cerchio, un giocattolo che va piano ci scivola dentro da solo: non serve la precisione.
2. **Galleggiando sopra il suo cerchio** lo accende appena: il bordo di piastrelle fosforescenti.
3. **Si svuota la piscina come prima**, con 4 zainate.
4. **I giocattoli calano con l'acqua e si posano.** Chi è sul suo cerchio lo fa scendere con un tonfo: il bordo si accende tutto e il giocattolo resta lì.
5. **Scesi tutti e tre**, dagli scarichi arriva un risucchio lungo e il lampeggiante del pulsante della botola passa da giallo a verde. Colpito col getto, la botola si apre come prima.

**L'ordine è libero.** Si può anche svuotare prima e poi spingere i giocattoli sul fondo asciutto.
- Sul fondo vanno un po' più piano, ma non molto: strisciano sulle piastrelle.
- Ogni piatto scende appena il suo giocattolo ci arriva.
- Sul fondo i gonfiabili già sparsi sono ostacoli da girare.

**Se sbagli** non succede niente di grave:
- a piscina vuota coi giocattoli fuori posto, il lampeggiante resta giallo e il pulsante non si preme;
- i giocattoli si spingono anche sul fondo, quindi non c'è niente da rifare da capo.

**Durata**: 3-5 minuti.
- Il disegno: circa un minuto.
- I tre giocattoli: 1-2 minuti sull'acqua, un po' di più sul fondo.
- Lo svuotamento: 30 secondi, come prima.

## Dove sono le cose

Coordinate del mondo della sala. La botola è in x 0, z 2.0; la parte profonda va da x -7 a 7 e da z -1 a 5.

| | Cerchio | Giocattolo all'inizio |
|---|---|---|
| Paperella, giallo | (-3.9, 3.3) | (0.3, 2.5), sopra la botola |
| Pallone, rosso | (3.9, 3.3) | (4.4, -0.6) |
| Balena, blu | (-3.9, -0.1) | (-0.2, -0.8) |

Il disegno è sul muro ovest (x -6.97), all'altezza di z -0.2, fra 0,35 e 1,25 m sotto il bordo, sopra il pelo dell'acqua.

Cosa è stato tenuto libero, e come:
- **i cerchi** stanno sul fondo piano fuori dalla conca della botola, lontano dalla P5, dalle scalette, dalla ripartenza del checkpoint e dai gonfiabili;
- **i giocattoli appoggiati sul fondo** non vanno sulla P5, al piede delle scalette, sulla ripartenza e sui gonfiabili: ne scivolano giù;
- **galleggiando** ci passano sopra.

## Scatti e video

<!-- SCATTI -->

## Cosa cambia nel gioco

- `scripts/game/enigma_giocattoli.gd`: l'enigma, con il nodo `Piscina/EnigmaGiocattoli` nella sala.
  - I cerchi li appoggia sul fondo Posa, lo strumento comune.
  - Quello che si vede si disegna una volta fuori vista appena la sala è pronta, sullo strato 1<<15 (`RiscaldamentoShader.disegna_fuori_vista`), così a metà enigma non si compilano pipeline nuove.
  - Lo stato si salva coi checkpoint: dove sono i giocattoli e quali piatti sono scesi.
- `scripts/game/piscina_onde.gd`: c'è la `serratura`.
  - A piscina vuota il pulsante della botola si preme solo a serratura aperta.
  - Il lampeggiante è giallo prima e verde dopo, e verde fisso quando la botola è aperta.
  - Senza serratura funziona come prima.
- **Test**:
  - `tests/test_enigma_giocattoli.gd` risolve l'enigma nei due ordini col giocatore e il getto veri; è nella CI;
  - `test_tappe56` mette i giocattoli al loro posto con una scorciatoia prima di colpire il pulsante;
  - nel controllo di posizionamento ci sono gli stati `piscina_vuota` e `piatti_scesi`.
- **Partenze del menu di prova**: `genera_partenze_prova.gd` mette l'enigma risolto nella parte della piscina. Le partenze si rifanno dopo l'unione con le Polaroid nuove, per non far litigare i file.

## Cosa manca e da decidere

<!-- DA DECIDERE -->
