# Ricontrollo delle salite di lei nelle condotte (0.3.21, scelta C; ambienti-1, 6 novembre)

Branch `lavoro/salite-lei` ebe3cb99 (mascotte). Collaudo: `godot/tests/collaudo/collaudo_salite_lei.gd`, con la logica vera del gioco (`_lei_sale` e `_lei_aggiorna` a 30 fps), la pelle vera di lei (109 mila vertici deformati dalle ossa, 6000 della mano destra) e il muro vero della vasca (collisione e mesh: la cima della vasca 3 è a -27,500 in tutte e due).

## Vasca 3 (sale_mano)

- **La mano esce prima**: sopra la cima a 0,60 s, testa e capelli a 0,63 s (da metà vasca). Dall'angolo sud-ovest (66,7; -2,2), vicino al muro basso, si vede oltre il muro e testa e mano spuntano insieme già a 0,50 s (`vasca3_dall_angolo_sud_ovest.jpg`).
- **DIFETTO: la mano entra nel bordo di 13,2 mm** per tutto il tempo che lo tiene (0,82-1,03 s), con fino a 62 vertici dentro il muro. Il punto più basso è in (69,895; -27,513; -2,159), con la cima a -27,500. La sonda di mascotte (`proposte/mascotte/sonda_mano_bordo.gd`) dava +1,8 mm perché mette la cima a CIMA = 3,485 m sopra lei, cioè a -27,515: 15 mm sotto il muro vero. Da correggere nella clip (BORDO_V3 di `tools/blender/medusa_inseguimento.py`) alzando la mano di circa 15 mm.
- Dalla parte della vasca le dita scendono oltre lo spigolo al più di 1,9 cm.
- Si gira dopo aver lasciato il bordo al più di 90 gradi al secondo.
- Ravvicinati: `vasca3_mano_sul_bordo_ravvicinati.jpg`.

## Vasca 2 (sale_puntata), dal fondo

- L'occhio punta il giocatore entro 9 gradi da 0,4 a 1,1 s (1-2 gradi a 0,53 s); poi, negli ultimi 0,45 s della salita, si scosta fino a 39 gradi, come nella posa "su" di sempre (39 gradi anche prima).
- Scatti: `vasca2_dal_fondo.jpg`.

## Tempi (uguali a prima, provati con SALITA vuota)

- Vasca 3: salita 1,10 s, su a 1,07 s, respinta 1,03 s, salto 0.
- Vasca 2: salita 1,60 s, su a 1,57 s, respinta 1,20 s, salto 2,5 cm.

## Test

- Passano: test_inseguimento, test_inseguimento_suoni, test_lei_animazioni, test_morbidezza_inseguimento a 30 fps, test_lei_discese, posizionamento (0 da correggere).
- **Non passa: test_morbidezza_inseguimento a 60 fps nella riga nuova della CI** (`SOLO=scolo_2,grata,sb1_scende,vasca_1,vasca_2`). In quest'ordine (vasca_1, vasca_2, poi scolo_2) allo scolo 2 un vertice di un tentacolo entra 1,2 cm nel muro (KO; f44, tentacolo 3, osso 6, in ins_A_struttura). Si ripete identico. Con lo scolo 2 da solo passa, e passa anche sulla base 412daf44: è lo stato dei tentacoli che resta dalle vasche prima.

## Secondo ricontrollo, lavoro/salite-lei fa3bb672 (6 novembre): superato

- **Vasca 3, la mano sul bordo**: distacco dalla cima +1,8 mm per tutta la presa (0,82-1,03 s), 0 vertici dentro il muro; dalla parte della vasca le dita scendono oltre lo spigolo di 0,4 cm. La mano esce prima (0,60 s; testa e capelli a 0,63 s).
- **Tempi uguali a prima**, anche con azzera() che riparte da capo: vasca 3 salita 1,10 s, su a 1,07, respinta 1,03 s; vasca 2 salita 1,60 s, su a 1,57, respinta 1,20 s, salto 2,5 cm. L'occhio della vasca 2 come prima.
- **CI**: test_morbidezza_inseguimento a 60 fps con la riga della CI (`SOLO=scolo_2,grata,sb1_scende,vasca_1,vasca_2`) passa; passano anche test_morbidezza_inseguimento a 30 fps completo, test_lei_discese, test_inseguimento, test_lei_animazioni.
- **La scatola nuova dello scolo 2** (`tests/collaudo/sonda_trave_scolo2.gd`, raggi sulla geometria vera): la trave sotto il piano va da x 73,800 a 74,000, scende fino a -31,700 e va da z -16,100 a -11,900. La scatola (73,8; -31,70; -16,086)-(74,0; -31,35; -11,886) la copre in x e in basso, ma in z è spostata di 1,4 cm: alla fine verso -16,1 restano scoperti 1,4 cm di trave e dall'altra parte la scatola sporge di 1,4 cm. È piccolo, e il test passa; da sistemare alla prossima rigenerazione delle forme (z da -16,10 a -11,90).
