# Collaudo v0.3.12: infermeria e acquari colorati

Collaudo della squadra ambienti-1 (zone fatte da enigmi) su `lavoro/godot` **ff9860bb**, ramo `lavoro/collaudo-a1`.

**Esito: nessun difetto.**

## Come

- Stati preparati in `godot/tests/collaudo/stati.gd`:
  - `infermeria_arrivo`, `_negatoscopio`, `_cassetto`, `_cassaforte`: blackout; poi corrente, cassetto con l'adesivo aperto, radiografia sul negatoscopio, cassaforte aperta con 4-1-7;
  - `acquari_limpidi` (= svuotati: il miscuglio vuoto, i colorati pieni), `acquari_torbidi` (miscuglio pieno torbido, la valvola gocciola), `acquari_gorgo` (fermo a metà), `acquari_risolti` (verde, portone aperto).
- Per ogni stato:
  - geometria esportata (`geometria.gd`) e distanze di ogni oggetto dall'architettura (`distanze.py`, soglia 1 cm);
  - ravvicinati di ogni oggetto piccolo (`vedute.py --tutti-piccoli --stacchi`);
  - giro dagli occhi (1,6 m) in quattro direzioni da 6-7 punti della zona.
- Gli scatti del giro sono senza la luce del collaudo (luci bianche al 40%). Quelli ravvicinati degli acquari sono con la luce, perché la sala al ritorno è troppo buia per vedere 1-2 cm.
- Controllo di posizionamento della CI su `lavoro/godot` (con la Polaroid 2 nuova): nessun caso nell'infermeria e negli acquari, 0 da correggere.

## Infermeria

- Distanze: 151-157 oggetti misurati per stato, 0 che non arrivano all'architettura.
- Polaroid sul tavolo, rotelle e simboli della cassaforte, melma sul cassetto e per terra, keycard e Polaroid nella cassaforte: tutti appoggiati o attaccati (stacchi di 0-2 mm).
- La melma segue il cassetto quando si apre, e la radiografia sta dentro il cassetto.
- Fogli: `inf_<stato>_giro.jpg`, `inf_<stato>_vicini.jpg`; dettagli `inf_polaroid.jpg`, `inf_melma_cassetto.jpg`, `inf_cassetto_aperto.jpg`, `inf_rotelle.jpg`, `inf_keycard.jpg`.

## Acquari colorati

- Distanze: 203-204 oggetti, 0 che non arrivano all'architettura.
- La valvola che gocciola (torbidi): la goccia esce dal bordo della flangia di uscita, sopra la griglia dello scarico (`acq_valvola_gocciola.jpg`). Negli altri stati non gocciola.
- Pompe, tubi, gambe e flange dei tre acquari: tutti a contatto. La lampada a gabbia sul tubo è fissata con le fascette.
- Lampade del portone: la guida è sulle staffe al muro.
- Fogli: `acq_<stato>_giro.jpg`, `acq_<stato>_vicini_luce.jpg`; dettagli `acq_valvola.jpg`, `acq_lampade_portone.jpg`, `acq_risolto_verde.jpg`.

## Note (non difetti)

- Sotto 1 cm, non visibili dal pavimento:
  - le piastre al muro delle lampade del portone sono a 5,6 mm dal muro, a 5,5 m d'altezza;
  - la curva della pompa del miscuglio è a 3,4 mm dal tubo;
  - un pezzo delle maniglie delle porte dell'infermeria è a 5 mm dalla sua placca.
- La cassaforte aperta sporge di circa mezzo metro nell'angolo nord-est dell'infermeria, all'altezza del petto. Non sta sulla strada.
- Negli acquari risolti la sala della torre dietro il portone non è caricata (`COLLAUDO_SENZA_TORRE=1`): con la torre la sala intera non entra nella memoria del renderer software. La torre ha il suo collaudo.
- In un ravvicinato (`v_Allacci_Gamba_7`) la sagoma rossa piatta è la camera troppo vicina a un oggetto, non il gioco.
