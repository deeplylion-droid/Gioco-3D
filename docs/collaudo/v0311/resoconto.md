# Collaudo finale della v0.3.11

Base: `lavoro/godot` **122b7bea**. Contiene le correzioni degli interni di ambienti-1 (4984c835), le porte dell'infermeria (3192cdd5), il menu più buio, i suoni nuovi dello squalo e il controllo dei varchi. Il confronto è con la v0.3.8 e con 8371883e. Squadra collaudo, 23 ottobre.

Le posizioni sono nella scena degli interni aperta da sola. Per passare al mondo della sala si aggiungono (-9,7, 0, 40,9).

**Verdetto: non superato**, per due difetti piccoli (D1 e D2). La porta della sala pompe arriva con un altro commit e si controlla dopo.

## Difetti

| # | Che cosa | Misura | Foglio |
|---|---|---|---|
| D1 | **L'anta che sbatte finisce dentro il suo armadietto.** `armadietto_sbatte_anta` parte chiusa (rot -94) e dopo il colpo è a -175 gradi: gira verso l'interno. Sta a x 10,52…10,91 e z -5,35…-5,27, dentro il corpo di `armadietti_est_04_rosso` (x 10,5…11,0), con il 98% dei vertici dentro. Da fuori l'armadietto rosso sembra aperto senza anta. Anche su 8371883e e sulla v0.3.8. | `misure/nodi_da_8371883e.txt` | `a311_armadietto_sbatte.jpg` |
| D2 | **Il fermaporta dello stanzino non tocca la porta.** Con i raggi a y 0,12, z -9,62: muro a x 11,20, perno da 11,20 a 11,24, faccia della porta a 11,258, cioè 1,8 cm di distacco. Il tampone di gomma ha lunghezza zero. | raggi sulla geometria | `rav2.jpg` (fermaporta) |

## Da decidere

- **Soglia dello stanzino.**
  - Dentro lo spessore del muro (x 10,9…11,2) la capsula del giocatore ha 19-20 cm di gioco, cioè 9-10 cm per lato. A x 10,8 ne ha 15 per lato, a 10,6 ne ha 46.
  - Il limite sono gli stipiti del vano, largo 89 cm e uguale alla v0.3.8, non più la porta.
  - I valori sono in `misure/soglia_stanzino.txt`.
- **Celle rispetto alla v0.3.8**: 10.937 contro 12.233, senza zone staccate.
  - Le ante intere aperte a 85 gradi chiudono le corsie fra gli armadietti e le panche (ovest x 3,7…4,1, est x 10,2…10,6). Non sono passaggi obbligati.
  - Polaroid02 (armadietto ovest_11) si raggiunge a 0,44 m e si vede.
- **Retro delle ante**: è aperto. Si vede solo da 35 cm (`rav1.jpg`).

## A posto

| Punto | Esito | Foglio |
|---|---|---|
| Stanzino | Si entra (anche test_passaggi_interni). Lo zaino è a 0,24 m da una cella libera. La porta è aperta contro il muro dalla parte dello stanzino, fuori dal vano. | `s311_stanzino.jpg` |
| Ante | Tutte e 9 col pannello intero: 1,50 m², 39 × 190 cm, facce tutte dritte. Ognuna tocca il suo armadietto (0-6 mm, cerniera a pianoforte). Nessuna entra in un armadietto accanto. | `a311_*.jpg`, `dietro.jpg`, `rav1.jpg` |
| Ripartenze | Tutte e 6 libere con la capsula del giocatore. | `misure/ripartenze_e_vano.txt` |
| Asciugamani e cartello | asciugamano_2 per terra, a 5 cm dal muro sud, fuori dall'ingresso. L'asciugamano sulla panca poggia. cartello_bagnato parallelo al muro est (13 cm), per terra, fuori dalla ripartenza. Nessuno entra nel muro. | `s311_oggetti.jpg`, `rav2.jpg` |
| Infermeria | Le due ante sono parallele al muro e fuori dal vano: 15 cm per lato sulla soglia, 18 dentro e fuori. L'adesivo sopra la porta nord si vede sopra l'anta. | `s311_infermeria.jpg`, `misure/porte_infermeria.txt` |
| Squalo | La scena finisce a 11,95 s e il giocatore torna libero. Suonano la minaccia (0,82 s) e il ringhio (5,78 s) nuovi, con md5 diversi. Nel gioco sono circa 7 e 11 dB più bassi di prima. | `misure/squalo_suoni.txt` |
| Menu | Si vede, è buio fra i lampi, col lampo si vedono cupola e torre. Versione 0.3.11. | `menu_fra.jpg`, `menu_lampo_lampo.jpg` |

## Come è stato fatto

Gli strumenti sono gli stessi del confronto degli interni (`../interni_confronto/resoconto.md`), più:
- `sonda_capsula.gd`, che ora accetta una scena qualsiasi;
- `sonda_squalo.gd`: suoni dell'autoload Audio e fine della scena;
- `stati.gd`: nello stato `aperto` l'armadietto sbatte come quando ci passa il giocatore.

Il giro dagli occhi comprende i 120 scatti fissi e le 79 vedute del 22 ottobre, 89 vedute fisse delle ante, della porta e degli oggetti, e 56 ravvicinati dei contatti (le righe `spazio` di giro.gd sui punti più vicini misurati da `distanze.py`). Le distanze vere degli spogliatoi e dello stanzino: nessun oggetto oltre 1 cm, tranne il fermaporta.
