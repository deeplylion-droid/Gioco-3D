# Collaudo delle righe rosa della torre (29 ottobre, mattina)

Squadra collaudo. `lavoro/godot` **6d9508aa** (con `lavoro/righe-torre` 91404352 di grafica-2), confrontato con
**ca4aef21**, il commit di prima. Col renderer vero (llvmpipe, 1280x720) e lo stesso giro di viste sui due commit:
`godot/tests/collaudo/righe_vere.gd`, che è la sonda di grafica (`oblo_righe_g2.gd`) senza il "prima" rifatto a mano.
Ho aggiunto 9 viste lungo la sala delle condotte (a 2,4, 4,8 e 6 m dai due lati, lo spigolo in basso e in alto,
da dietro). In tutto 28 viste nella torre e 9 negli oblò della risalita. 0 righe "ERROR: BUG,".

## Esito

- **La riga bassa rossa non c'è più**, e con lei i bordi rossi sullo spigolo delle condotte e sotto la cisterna
  (`fogli/torre_condotte_prima_dopo_1.jpg`, schiarito 3 volte). Le 7 lampade rosse della torre ora fanno ombra.
  - Prima la lancia del giocatore nelle condotte era illuminata di rosso da una lampada che sta dall'altra parte del muro.
  - Ora resta scura: anche quella era luce che passava dal muro.
- **La riga alta rosa c'è ancora, uguale.** È la riga sottile in alto nella vista "condotte altro lato", sul bordo alto
  del corpo dell'oblò (`ObloLei/Corpo`, x 40,0, y -17,6, come nella sonda 2 di grafica).
  - Stessa intensità prima e dopo: R 17 sulla riga contro 4-6 attorno, su 255 (`fogli/riga_alta_rosa_ingrandita_x3.jpg`).
  - C'è solo con la luce di lei accesa.
  - È debole: senza schiarire è una riga scura appena rosata.
- **Lei dall'oblò della torre non è uguale a prima: è meno rossa** (`fogli/lei_dalla_torre_prima_dopo.jpg`).
  - Dentro il vetro il rosso scende da 82 a 63 (-23%), il resto quasi uguale (G 37 → 35, B 36 → 35). Il muro attorno è invariato (74 → 73).
  - Succede anche a luce di lei spenta (76 → 55): il rosso che manca è quello delle lampade d'emergenza, che ora non passa più dentro la vasca.
  - La luce di lei e l'alone ci sono: il punto rosa sul mento e la luce sui capelli.
  - Ma il fondo della vasca ora è scuro invece che rossastro, e lei ha i colori suoi (rosa) invece che tinti di rosso.
  - È più giusto per la luce, ma è un cambio di aspetto di lei: da far vedere all'utente.
- **I tre oblò della risalita sono uguali a prima** in tutte le 9 viste (di fronte e di sbieco, differenza media sotto
  0,3 su 255; `fogli/risalita_oblo_prima_dopo.jpg`). I bias sono quelli di serie (0,10 e 1,00); su ca4aef21 erano 0,03 e 0,2.
