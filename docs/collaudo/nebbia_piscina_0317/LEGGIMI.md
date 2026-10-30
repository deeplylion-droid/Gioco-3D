# Ricontrollo della nebbia dentro la piscina a onde vuota (30 ottobre sera)

Ricontrollo di mascotte su `lavoro/nebbia-0317` di grafica-2: lo strato fitto della nebbia viola scende dove poggiano i
piedi del giocatore (uniforme `fondo`). Confronto di tre stati: prima (la nebbia di `a6cb3c0b`, cioè di `lavoro/godot`),
`786dcf48` e `8489402d`, che ha la stessa nebbia di `2b02a09f` e in più il controllo sul giocatore liberato.

**Esito: superato.**

## Scatti dal motore, dagli occhi del giocatore in piedi sul fondo

Strumento: `godot/tests/collaudo/scatti_piscina_vuota.gd`. Carica la sala a parti, svuota la pozza e mette la nebbia
viola della sala; ogni scatto è fatto con la nebbia piena. L'ultimo scatto è dal pavimento della sala, per confronto.

- `1_dal_fondo_tre_stati.jpg`: tutti gli scatti, uno stato per riga.
- `2_disegno_muro_ovest_e_pavimento.jpg`: lo scatto verso il disegno sul muro ovest e quello dal pavimento della sala,
  nei tre stati. Qui al posto di `8489402d` c'è `2b02a09f`: la nebbia è la stessa.

Cosa si vede:
- **prima** e con `786dcf48`, dal fondo tutto resta in un blu scuro uniforme: i cerchi si vedono appena, il disegno sul
  muro ovest è una macchia;
- con `8489402d` dal fondo si leggono i cerchi, il loro bordo e il disegno sul muro ovest, e si vedono le piastrelle del
  fondo e il muro della piscina;
- la nebbia attorno è come quella in piedi sul pavimento della sala, appena di più;
- lo scatto dal pavimento della sala è uguale nei tre stati.

Nella vista del pallone `2b02a09f` è più chiaro di `8489402d`, in due giri uguali. Il codice della nebbia è lo stesso, e il
resto della scena è più scuro anche fuori dalla nebbia. Probabilmente è il lampeggiante dell'enigma vicino al pallone,
acceso o spento nell'istante dello scatto. Le altre viste cambiano di poco da un giro all'altro, per le lampade che
sfarfallano.

## Dinamica col giocatore vero, senza schermo

Strumento: `godot/tests/collaudo/nebbia_fondo_dinamica.gd`, su `8489402d`. Risultato: 10 controlli ok, 0 falliti.
Nessun `SCRIPT ERROR`.

- **Sul pavimento** lo strato sta ai piedi, a 0.
- **Discesa.** Il giocatore va avanti dal bordo est e cade nella piscina vuota:
  - mentre è in aria, il punto che lo strato segue non cambia;
  - toccato il fondo, lo strato scende da -0,16 a -2,00 in circa 0,6 s, al più 5 cm per fotogramma: senza salti.
- **Salto** di 1,04 m sul fondo: lo strato non cambia (1 mm).
- **Accovacciato**, con gli occhi a 0,92 m: lo strato non cambia (1 mm).
- **Sul fondo** lo strato segue i piedi anche camminando sulle pendenze, entro 1 cm.
- **Risalita.** Lo strato sale al più di 5 cm per fotogramma e sul pavimento torna ai piedi.
  - Col mio controller, in cima alla scaletta est il giocatore non scavalca e torna giù. Così la risalita l'ho fatta
    portando il giocatore a passi verso il pavimento, a fisica ferma.
  - **Da guardare a parte (è la scaletta, non la nebbia):** dalla piscina vuota la scaletta est fa uscire? Il test
    dell'enigma dei giocattoli non sale le scalette.
