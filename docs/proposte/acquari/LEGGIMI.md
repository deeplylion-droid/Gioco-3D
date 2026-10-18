# Proposta: l'aspetto dell'enigma degli acquari (18 ottobre, enigma-ambiente)

Scatti dal motore (Godot 4.7.2, sala principale vera al buio rosso del ritorno dalla tappa 7, dopo la
tappa 8, portone della torre chiuso). Nella pagina di scelta li mette il coordinatore. Non è nel gioco:
la proposta si monta al volo da `godot/proposte/acquari/proposta_acquari.gd` per gli scatti
(`godot/tests/scatti_acquari.gd`, `tools/scatti_acquari_tutti.sh`).

Fila: **giallo | miscuglio | blu**. Il miscuglio è **basso** (bordo a 0,8 m, aperto sopra: la lancia
tenuta in basso non versa più su), un po' più avanti, con 1,2 m liberi ai lati. Sotto c'è la
**valvola rossa** (avvitata alla bocca del basamento, scarico a pavimento davanti). Il **disegno a
pastello** è attaccato col nastro di carta al vetro del giallo, dal lato del miscuglio, all'altezza
degli occhi: carta sottile retroilluminata dalla luce dell'acquario, si legge anche senza torcia. Dentro gli alti c'è una luce di servizio.

## Domande per l'utente

1. **Stile** degli acquari: **A** vasche col telaio di metallo verniciato (turchese e giallo) su un
   basamento, oppure **B** grandi cilindri di vetro tra base e coperchio di acciaio rosso, con tubi e
   manometri. (`A1_*`, `B1_*`)
2. **Posizione**: **1** davanti alla serranda del magazzino, subito a nord della scia rosa: si vede
   appena esci, a 9 m (`*1_uscita`). **2** a est, a sud del portone della torre: dalla serranda non
   si vede, la nasconde la vasca centrale; si scopre a metà sala (`*2_uscita`, `*2_meta`).
3. **Il miscuglio basso** in mezzo a due alti (opzione 1, tutti gli scatti) o **tutti e tre bassi**
   (opzione 3, col disegno più piccolo sul vetro basso del giallo: `A1_vicino_tuttibassi`, `B1_vicino_tuttibassi`, da confrontare con `A1_vicino`, `B1_vicino`).
4. **Le lampade del portone**: fila di **lampadine da luna park** intorno al portone, o **due lampade
   a gabbia** ai lati (`portone_*_spente`, `portone_*_accese`).
5. **Il disegno**: va bene così, attaccato al vetro del giallo? (`A1_disegno_A`, `B1_disegno_B`)
6. **L'acqua**: gialla, blu, verde riuscito (`*1_dettaglio_verde`) e torbida sbagliata
   (`*2_dettaglio_torbido`).

Note: i modelli sono di Meshy (vasca, basamento, base e coperchio del cilindro, valvola, lampada a
gabbia); il basso dell'A è la stessa vasca tagliata in Blender, il basso del B la base del cilindro
tagliata e allargata. Il disegno è un'immagine generata usata solo come texture.
