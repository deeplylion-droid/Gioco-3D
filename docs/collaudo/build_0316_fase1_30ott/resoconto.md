# Collaudo finale della 0.3.16, fase 1 (29-30 ottobre, notte)

Squadra collaudo. `lavoro/godot` **9baa00d5** (CI verde, run 40947772851). Dentro ci sono: bambini di sfuggita, enigma dei giocattoli, scarabocchi, Polaroid 11-16, cuore e ritmo, effetti dell'inseguimento, inglese, portone della torre, raggi robusti, tentacoli più leggeri e controllo delle texture.

Giocatore vero con i tasti veri (come col controller), zone costruite a pezzi col riscaldamento come nel gioco, salvataggi in una cartella dei dati tutta loro. **0 righe "ERROR: BUG," in tutti i log**, senza schermo e col renderer vero.

## Difetti, dal più grave

1. **Tentacoli di lei a 60 fps** (`test_morbidezza`: 3 controlli KO; `test_morbidezza_inseguimento`: 2 KO). A 30 fps, come nella CI, passano.
   - `test_morbidezza`: scatti nei due tuffi, fino a 26,2 m/s più veloci della posa; nel secondo tuffo 2 vertici della pelle dentro il mondo, al più 1,4 cm.
   - `test_morbidezza_inseguimento`: a scolo_2, 4 vertici della pelle dentro la sala, al più 4 cm; alla grata uno scatto di 35,3 m/s sopra la posa.
   - Sono le correzioni unite dopo (0c6f6761): si riprovano nella fase 2.
2. **Da guardare, bassa: la rete di sicurezza dell'enigma dei giocattoli scatta con le scorciatoie.**
   - Succede in `test_strada`, `misura_blocchi` e `test_audio`, dove la piscina vuota e il portello aperti sono messi con una scorciatoia.
   - Quando la torre finisce di caricare, il raggio trova una superficie 0,06-1 m sopra la paperella e la balena, che sono sul fondo. Le crede sotto il fondo e le rimette alla partenza; la balena per 6 fotogrammi di fila (`log/blocchi.log`).
   - Nell'enigma vero, nei due ordini (83/83), non scatta mai. L'ha presa enigmi.
3. **Blocchi**: `misura_blocchi` conta 9 fotogrammi sopra 100 ms dopo l'avvio, contro 6-7 su c0bd9c75.
   - Il peggiore è sempre quello noto da 742 ms.
   - I 6 in più (110-157 ms) cadono mentre si costruisce la torre, nei fotogrammi del punto 2.
   - La CI non ha un limite su questo numero; si ricontrolla nella fase 2.

## Cose da sapere (non difetti del gioco)

- **Il titolo diceva "demo 0.3.15"**: la versione è già cambiata in d4a0b294.
- **Gli scarabocchi della risalita e del fiume**, nel rosso del buio, si vedono appena. Sono attaccati al muro come gli altri: è una questione di aspetto.
- **P2, P3, P5, P8 e P10**: per la mia sonda sono come nel collaudo del 28 ottobre, niente di nuovo.
  - P2 sta nell'armadietto e P3 sulla bacheca, in verticale.
  - P5 e P8 sono a 4-11 mm dalla mesh sotto, come prima.
  - P10 dal punto della sonda non si raggiunge, ma `test_polaroid` e la strada la raccolgono.
- **`test_torre_ingresso` va lanciato col renderer vero**: senza schermo fallisce apposta. Col renderer vero passa: 5/5.
- **`polaroid_libere.gd`** è una libreria dei test, non un test: l'ho lanciata per sbaglio.

## Che cosa va

| Prova | Esito |
|---|---|
| Strada dal risveglio alla torre (`test_strada`) | 35/35 |
| Enigma dei giocattoli nei due ordini (`test_enigma_giocattoli`) | 83/83 |
| Le 16 Polaroid, negli stati inizio, ritorno e risolto, e nelle partenze | come il 28 ottobre; `test_polaroid` 5/5 |
| Continua da risalita, torre, inseguimento e tunnel (dopo un crash vero) | checkpoint giusto, a 0,00-0,02 m dal posto salvato; zaino, acqua, inventario, Polaroid e luci uguali |
| Morte e ripartenza in ognuna delle quattro | ripartiti dal checkpoint in 4,9 s (risalita), 8,4 (torre), 8,4 (inseguimento), 9,7 (tunnel), in piedi |
| Partenze F9: risalita, fiume, torre, inseguimento, tunnel | arrivate in 7,0-8,0 s ai loro checkpoint |
| test_continua, test_partenze_prova, test_menu, test_lingua | 127, 72, 72, 29: tutti ok |
| test_inseguimento, test_effetti_inseguimento, test_torre, test_portone_torre | 43, 13, 94, 20 |
| test_bambini_sfuggita, test_bambini_passi, test_agnellino, test_raggi_crepa | 41, 16, 12, 10 |
| test_morbidezza_tunnel, test_sottomarino_gioco, test_risalita, test_infermeria_gioco, test_fiume_gioco | 46, 13, 15, 56, 31 |
| test_tappa7, test_tappa8, test_acquari, test_interni, test_audio, test_posa, test_scivoli | 50, 69, 83, 52, 116, 14, 26 |
| Fine del capitolo dopo il tunnel (`test_fine_titolo`, FINE_TUNNEL=1) | 14/14 |
| Memoria con le morti (`test_memoria_morti`) | 2/2 |
| Controllo di posizionamento | 0 casi da correggere |
| I 18 muri degli scarabocchi (`verifica_muri`) | tutti OK: piatti, nessuna mesh dentro la decal, niente di vietato vicino |
| Col renderer vero: `test_riscaldamento_pipeline`, `test_oblo_leggeri` | 9/9, 30/30: nessuna compilazione che blocca |
| Inglese col renderer vero (`fogli/inglese_*`) | titolo, le 7 schede delle opzioni e i comandi tutti in inglese, nessun testo tagliato |
| Scarabocchi da vicino e dagli occhi, i 18 (`fogli/scarabocchi_*`) | stanno sul muro e seguono le piastrelle, niente staccato o sospeso |
| Polaroid nuove P12-P16 e l'enigma (`fogli/polaroid_nuove_e_enigma.jpg`) | appoggiate al loro posto |
| Giocattoli e piatti da vicino (`fogli/giocattoli_vicino.jpg`) | sul fondo e sui piatti, piatti scesi e no, palloni e paperelle sulla spiaggia: niente sospeso |
| Partita intera del tunnel col renderer vero (`fogli/tunnel_partita_intera.jpg`) | SB1, attraversamenti, gallerie, approdo, schianto, nero; 6 getti, 6 respinte, 0 prese (9 morsi, 8 nella 0.3.15) |

## Come

Script in `godot/tests/collaudo/`: `sonda_continua.gd`, `sonda_blocchi.gd`, `sonda_polaroid.gd`, `partita_tunnel.gd`, `polaroid_nitide.gd`. Nuovo: `inglese_scatti.gd` (titolo, opzioni e comandi in inglese col renderer vero). Per gli scarabocchi `tests/strumenti/scatti_muri.gd` (MURI=scelti.json, SCARABOCCHI=1) e `verifica_muri.gd`. I log principali sono in `log/`.
