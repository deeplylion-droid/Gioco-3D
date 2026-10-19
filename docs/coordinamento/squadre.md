# Squadre e sessioni (aggiornato il 19 ottobre)

Il coordinatore è la sessione session_01Ub9Z8mJaiFbdfRfYi8QhGz: tutte le squadre gli mandano i resoconti con send_message. Il passaggio del 16 ottobre è in `passaggio_2026-10-16.md`.

| Squadra | Sessione cloud | Branch | Lavoro in corso |
|---|---|---|---|
| grafica | session_01Q9PdaHCaFPsyZ4J69AtTTt | lavoro/grafica | v0.3.6 fatta (cfffdf5: niente torcia, lampada bianca e luce rossa, menu). Ora controlla lo slot 1 dei gorghi dell'addon acqua (`WaterBody.set_flow(1, ...)`), poi aspetta le risposte sui punti bui |
| ambienti-1 | session_01E1m21YyF95ZHLwLFM1yLCv | lavoro/ambienti-1 | geyser nuovo: V1 mesh corretta e V2 flipbook, acqua non trasparente; video in registrazione per il confronto |
| ambienti-2 | session_01DHF6GjuPt1SH74CXxGYGC2 | lavoro/ambienti-2 | torre in v0.3.6. Ora lo schermo del monitor CRT (per la v0.3.7), poi la proposta dell'inseguimento rifatta: ambienti pieni, B1 meno buio, B come rapide e non come fiume lento |
| enigma-logica | session_01RPrxxeJjwAgHgEzLWPXgsn | lavoro/enigma-logica | fiume lento e infermeria: nota e prototipi grigi fatti (8b08b31, logica approvata dall'utente). Aspetta la scelta dell'aspetto |
| enigma-ambiente | session_01Jn42hE4synLdT5YNKedMqv | lavoro/enigma-ambiente | acquari in v0.3.6 (e9e7fad). Ora le proposte d'aspetto del fiume lento e dell'infermeria (2 aspetti ciascuno, keycard e lettore) |
| mascotte | session_01Ut6TnWfhFvUH1yfran7kFa | lavoro/mascotte | statue di squalo e polpo e mostro-squalo fatti. Ora gli scatti dei 9 posti senza torcia e le proposte del nome Jilly Jubilee (logo, targa, manifesti, insegna) |

## Come si fa una build

1. In un worktree, `lavoro/godot` riparte da `origin/main`. Si uniscono i branch pronti con `merge --no-ff`, poi push con `--force-with-lease`. La CI fa tutti i test su ogni branch.
2. Con la CI verde, in main: `merge --no-ff origin/lavoro/godot`, `config/version` alzata in `godot/project.godot` e `docs/release/v<versione>.md` (stesso formato delle precedenti), poi push. La CI crea la Release in circa 40 minuti (il limite del lavoro è 60: con il test del primo uso e l'export i 30 di prima non bastavano). Mentre gira, niente push su main: un push nuovo annulla il lavoro in corso.
3. Prima di ogni build, ambienti-2 può controllare con `godot/tools/dipendenze_export.gd` che nessun file escluso dall'export serva al gioco.

## Cose da sapere

- Le pagine di scelta si fanno con `tools/questionario/genera_pagina.py`. Le risposte si leggono con ArtifactData, collezione `risposte`.
- Pagine aperte: punti bui senza torcia (https://claude.ai/artifact/LeZkNfReqLPr8QhE1hZYkb), risposte non ancora arrivate. Quelle del 17 e 18 ottobre (scelte, torre, acquari, mascotte) sono lette e nel GDD.
- L'exe Windows pesa circa 1,44 GB. Le proposte sono escluse dall'export con `exclude_filter` in `godot/export_presets.cfg`.
- Unione della torre (ambienti-2) con enigma-logica: i conflitti sono solo in `.github/workflows/build.yml`, dove vanno tenute le righe dei test di tutti e due, e nel commento del punto 5 in cima a `godot/tests/test_tappa8.gd`. Il codice si unisce da solo: il portone non si apre da solo (enigma), lo apre `apri()` e la torre si carica.

## Da chiedere all'utente

- La v0.3.7 con lo schermo del monitor sistemato, quando ambienti-2 l'ha finito.
- Le proposte in arrivo: geyser V1 e V2, inseguimento rifatto, posti delle statue e nome Jilly Jubilee, aspetto del fiume lento e dell'infermeria.
