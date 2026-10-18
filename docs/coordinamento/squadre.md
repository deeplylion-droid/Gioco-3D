# Squadre e sessioni (aggiornato il 18 ottobre)

Il coordinatore è la sessione session_01Ub9Z8mJaiFbdfRfYi8QhGz: tutte le squadre gli mandano i resoconti con send_message. Il passaggio del 16 ottobre è in `passaggio_2026-10-16.md`.

| Squadra | Sessione cloud | Branch | Lavoro in corso |
|---|---|---|---|
| grafica | session_01Q9PdaHCaFPsyZ4J69AtTTt | lavoro/grafica | blocco al primo spruzzo dello zaino (4-5 h, dalle 15:40 UTC del 18), con il merge di lavoro/enigma-logica |
| ambienti-1 | session_01E1m21YyF95ZHLwLFM1yLCv | lavoro/ambienti-1 | agnellino luminoso B fatto (1671c44, per la v0.3.6 si prende questo hash); geyser nuovo V1 mesh e V2 flipbook (11-13 h), poi i commit vanno su lavoro/ambienti-1 sopra 1671c44 |
| ambienti-2 | session_01DHF6GjuPt1SH74CXxGYGC2 | lavoro/ambienti-2 | sala della torre A fatta (764089e); sostegni dei pezzi, faretti, spessore, scatti e video della discesa (5-6 h dalle 13:40 UTC del 18) |
| enigma-logica | session_01RPrxxeJjwAgHgEzLWPXgsn | lavoro/enigma-logica | logica fatta (656bb30, CI verde); aspetta la risposta dell'utente sull'acqua chiara e i modelli |
| enigma-ambiente | session_01Jn42hE4synLdT5YNKedMqv | lavoro/enigma-ambiente | scatti della proposta degli acquari; dopo la scelta dell'utente, i modelli nella scena dell'enigma |
| mascotte (nuova) | session_01Ut6TnWfhFvUH1yfran7kFa | lavoro/mascotte | statue dello squalo e del polpo e mostro-squalo: modelli Meshy e render, per ora niente nel gioco |

## Come si fa una build

1. In un worktree, `lavoro/godot` riparte da `origin/main`. Si uniscono i branch pronti con `merge --no-ff`, poi push con `--force-with-lease`. La CI fa tutti i test su ogni branch.
2. Con la CI verde, in main: `merge --no-ff origin/lavoro/godot`, `config/version` alzata in `godot/project.godot` e `docs/release/v<versione>.md` (stesso formato delle precedenti), poi push. La CI crea la Release in circa 20 minuti.
3. Prima di ogni build, ambienti-2 può controllare con `godot/tools/dipendenze_export.gd` che nessun file escluso dall'export serva al gioco.

## Cose da sapere

- Le pagine di scelta si fanno con `tools/questionario/genera_pagina.py`. Le risposte si leggono con ArtifactData, collezione `risposte`.
- Pagine aperte: scelte del 17 ottobre (https://claude.ai/artifact/TirmdiyjMMDgHtDRNdv52f, risposte lette) e sala della torre (https://claude.ai/artifact/FmJYNYwt1R4e2yA3L12txa, risposte lette).
- L'exe Windows pesa circa 1,44 GB. Le proposte sono escluse dall'export con `exclude_filter` in `godot/export_presets.cfg`.
- Unione della torre (ambienti-2) con enigma-logica: i conflitti sono solo in `.github/workflows/build.yml`, dove vanno tenute le righe dei test di tutti e due, e nel commento del punto 5 in cima a `godot/tests/test_tappa8.gd`. Il codice si unisce da solo: il portone non si apre da solo (enigma), lo apre `apri()` e la torre si carica.

## Da chiedere all'utente dopo la v0.3.6

- Se togliere del tutto la torcia (sue parole del 18 ottobre: "la torcia sto valutando se eliminarla completamente. Chiedimelo dopo la prossiam build"). Ricordargli cosa dipende dalla torcia, per esempio il buio delle stanze.
