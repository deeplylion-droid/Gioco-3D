# Collaudo finale della 0.3.16, fase 2 (30 ottobre, notte)

Squadra collaudo. `lavoro/godot` **d4a0b294**, versione 0.3.16 (CI verde, run 40980350306). Rispetto alla fase 1
(9baa00d5) ci sono l'audio alla chiusura, le correzioni dei tentacoli a 60 fps, lei rossa nell'oblò della torre e la
nebbia viola nell'infermeria, nella sala e nel tunnel dell'inseguimento.

**Esito: va.** 0 righe "ERROR: BUG," in tutti i log. Il container si è riavviato una volta, alle 02:14, durante una prova
dell'inseguimento: rifatta, passa, e Godot non è andato oltre 2,3 GB (il riavvio non era del gioco).

## Da sapere

1. **I due tuffi di `test_morbidezza` a 60 fps** falliscono ancora come prima: 25,6 e 26,2 m/s contro un limite di 25,
   e 2 vertici a 1,4 cm. Non è una regressione: il coordinatore li ha passati a grafica per dopo la build. A 30 fps passa (44/44).
2. **La rete dell'enigma dei giocattoli con le scorciatoie** scatta ancora uguale (2 volte in `test_strada` e in
   `misura_blocchi`): l'ha presa enigmi.
3. **La nebbia della sala col renderer vero non entra in memoria**: anche ridotta è finita fuori dai 15 GB due volte. La
   nebbia della sala si vede negli scatti dello spavento, che sono nella sala, e la provano `test_zona_nebbia` e
   `test_riscaldamento_pipeline`.
4. **Lei nell'oblò della torre è più rossa della 0.3.15**: il rosso nel vetro è 105 contro 82, su 255; il fondo
   della vasca resta più scuro (`fogli/oblo_confronto.jpg`).
5. **Nelle condotte non passa più luce rossa dal muro**; resta solo la riga alta rosa, già nota (`fogli/oblo_condotte.jpg`).

## Prove

| Prova | Esito |
|---|---|
| Strada (`test_strada`) | 35/35 |
| Nebbia per zona (`test_zona_nebbia`) | 17/17 |
| Audio alla chiusura (`test_audio_chiusura`) | 6/6 |
| Tappa 8 con lo spavento e la ripartenza (`test_tappa8`) | 69/69 |
| Tentacoli a 60 fps: inseguimento (grata, scolo_2), sbuca, tunnel | 64, 18, 46: tutti ok |
| Tentacoli a 30 fps: morbidezza, inseguimento, sbuca, tunnel | 44, 64, 18, 46: tutti ok |
| test_torre, test_inseguimento, test_inseguimento_suoni, test_sottomarino_gioco | 94, 43, 17, 13 |
| test_enigma_giocattoli, test_lingua, test_menu, test_continua, test_partenze_prova | 83, 30, 73, 127, 72 |
| test_audio, test_infermeria_gioco, test_bambini_sfuggita, test_fine_titolo col tunnel | 116, 56, 41, 14 |
| Continua con morte e ripartenza dalla risalita | a 0,00 m, tutto uguale, ripartenza in 4,4 s |
| Continua con morte e ripartenza dall'inseguimento | a 0,02 m, tutto uguale, ripartenza in 7,5 s |
| Controllo di posizionamento | 0 casi da correggere |
| Blocchi lungo il capitolo (`misura_blocchi`) | 7 sopra 100 ms, come nella 0.3.15 (6-7); il peggiore scende a 658 ms. Due da 320-334 ms con 6-10 ms di lavoro del gioco e 0 nodi e pipeline: la macchina, come prima |
| Col renderer vero: `test_riscaldamento_pipeline` | 11/11, anche la nebbia nel tunnel senza compilazioni che bloccano |
| Col renderer vero: `test_oblo_leggeri` | 30/30 |
| Nebbia nell'infermeria dagli occhi (`fogli/nebbia_infermeria.jpg`) | dentro è piena subito dopo il salto della camera (come Continua), con la foschia viola; con l'opzione spenta scende piano e riaccesa torna. Il "fuori" della scena di prova è il vuoto: l'entrata a piedi non si prova |
| Nebbia nel tunnel dagli occhi (`fogli/nebbia_tunnel.jpg`) | la foschia viola dentro il tunnel, l'opzione spenta e riaccesa. Il varco trovato era ancora dentro la zona: l'entrata e l'uscita le prova `test_zona_nebbia` |
| Oblò della torre (`fogli/oblo_*`) | lei di nuovo rossa, con la luce e l'alone |
| Spavento della tappa 8 col renderer vero (`fogli/spavento.jpg`) | lei sbuca e ti prende, glitch, rosso, nero con «Tieni premuto Spazio per saltare»; 0 errori nei 5 s dopo la presa |

Strumento nuovo: `godot/tests/collaudo/nebbia_giro.gd` (una zona della nebbia dagli occhi del giocatore, entrando e
uscendo da un varco, o col salto della camera).
