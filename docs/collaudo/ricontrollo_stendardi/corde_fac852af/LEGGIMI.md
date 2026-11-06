# Ricontrollo delle corde degli stendardi A (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/stendardi-inseguimento`, punta `fac852af`. Le correzioni sono in `92ca5e71` e
  `fe61733b`.
- Le misure le ho prese sulla GLB della punta:
  - `misure_da_vicino.txt`, come nei ricontrolli prima;
  - `misure_corde.txt`, pezzo per pezzo, con `misure_corde.py`.
- Gli scatti sono di `ricontrollo_stendardi.gd vicino`, con `SOLO_GIRI=1` e `SCATTI_LUCE=1`: i giri di ogni corda e
  l'asola, davanti e dietro.

## Esito: passa

- **Le 6 corde in mezzo alla stoffa** (stendardo 1 a x 44 e 48, stendardo 4 a x 68 e 72, la corda "m" degli
  stendardi 2 e 3).
  - Nessuna compenetrazione: 0 coppie di triangoli che si intersecano con il bastone, la piega o la stoffa.
  - Ogni pezzo della corda vicino al bastone, cioè giri, nodo e codino, sta fra 0,4 e 6,9 mm dal bastone o dalla
    piega: i giri sono appoggiati e nessun pezzo si stacca di più di 2 cm.
  - Dagli scatti (foglio 5) i giri si vedono interi, sopra la piega.
- **Asola.**
  - La piega è aperta solo sotto il bastone, nei punti delle corde: i raggi dall'asse senza stoffa sono solo lì, fra 30
    e 60 gradi sotto l'orizzontale, davanti e dietro, 6 cm di larghezza.
  - La corda ci passa a 6,5-9,5 mm dai bordi, senza toccarli.
  - I bordi sono dritti e puliti (foglio 5, "asola davanti/dietro").
  - Nota estetica, non un difetto: da vicino si vede una finestrella squadrata scura, con dentro il bastone arancione.
    È più grande della corda: 6 x 2,25 cm, contro 1 cm di corda.
- **Codini**: corti, aderenti al bastone o alla piega, senza capi nel vuoto, anche alle corde dei capi (foglio 5b).
  - Le corde ai capi degli stendardi 2 e 3 affondano ancora 3,5 mm nel bastone nudo coi giri, come prima. Sembrano
    legate strette: per me va bene.
- **Il resto non è cambiato.** Da `5091913a` sono cambiati solo le corde e le pieghe, per le asole.
  - Stoffa, bastoni e mollette hanno gli stessi vertici.
  - Le mollette restano a 0,45 mm dalla piega, senza compenetrazioni.
  - La cima della stoffa resta sul bordo della piega (0 mm).
  - Le corde restano ad almeno 7,7 cm da ogni molletta.
  - I golfari restano 1,2 cm dentro le travi.

## Fogli

5. `5_corde_in_mezzo_e_asole.jpg`: i giri e le asole, sugli stendardi 1, 2, 3 e 4.
5b. `5b_corde_ai_capi.jpg`: le corde ai capi degli stendardi 2 e 3, coi codini.
