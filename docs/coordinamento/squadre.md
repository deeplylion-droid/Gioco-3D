# Squadre e sessioni (aggiornato il 18 ottobre)

Il coordinatore è la sessione session_01Ub9Z8mJaiFbdfRfYi8QhGz: tutte le squadre gli mandano i resoconti con send_message. Il passaggio del 16 ottobre è in `passaggio_2026-10-16.md`.

| Squadra | Sessione cloud | Branch | Lavoro in corso |
|---|---|---|---|
| grafica | session_01Q9PdaHCaFPsyZ4J69AtTTt | lavoro/grafica | movimento sugli scivoli fatto (8334bfc); in attesa |
| ambienti-1 | session_01E1m21YyF95ZHLwLFM1yLCv | lavoro/ambienti-1 | agnellino luminoso B fatto (1671c44); in attesa |
| ambienti-2 | session_01DHF6GjuPt1SH74CXxGYGC2 | lavoro/ambienti-2 | sala della torre A giocabile (10-12 h) |
| enigma-logica (nuova) | session_01RPrxxeJjwAgHgEzLWPXgsn | lavoro/enigma-logica | logica dell'enigma degli acquari |
| enigma-ambiente (nuova) | session_01Jn42hE4synLdT5YNKedMqv | lavoro/enigma-ambiente | proposta dell'aspetto degli acquari, poi i modelli |

## Come si fa una build

1. In un worktree, `lavoro/godot` riparte da `origin/main`. Si uniscono i branch pronti con `merge --no-ff`, poi push con `--force-with-lease`. La CI fa tutti i test su ogni branch.
2. Con la CI verde, in main: `merge --no-ff origin/lavoro/godot`, `config/version` alzata in `godot/project.godot` e `docs/release/v<versione>.md` (stesso formato delle precedenti), poi push. La CI crea la Release in circa 20 minuti.
3. Prima di ogni build, ambienti-2 può controllare con `godot/tools/dipendenze_export.gd` che nessun file escluso dall'export serva al gioco.

## Cose da sapere

- Le pagine di scelta si fanno con `tools/questionario/genera_pagina.py`. Le risposte si leggono con ArtifactData, collezione `risposte`.
- Pagine aperte: scelte del 17 ottobre (https://claude.ai/artifact/TirmdiyjMMDgHtDRNdv52f, risposte lette) e sala della torre (https://claude.ai/artifact/FmJYNYwt1R4e2yA3L12txa, risposte lette).
- L'exe Windows pesa circa 1,44 GB. Le proposte sono escluse dall'export con `exclude_filter` in `godot/export_presets.cfg`.
