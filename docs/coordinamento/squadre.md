# Squadre e sessioni (aggiornato il 19 ottobre, mattina)

Il coordinatore è la sessione session_01Ub9Z8mJaiFbdfRfYi8QhGz: tutte le squadre gli mandano i resoconti con send_message. Il passaggio del 16 ottobre è in `passaggio_2026-10-16.md`.

| Squadra | Sessione cloud | Branch | Lavoro in corso |
|---|---|---|---|
| grafica | session_01Q9PdaHCaFPsyZ4J69AtTTt | lavoro/grafica | v0.3.7: torre precaricata e costruita a pezzi senza blocchi (c2c9afd), pacchetto più leggero 1658 -> 1240 MB (42a9d35). Ora la riserva in build.yml (exe unico solo sotto 1,95 GB) e docs/tecnico/peso_build.md; poi aspetta le risposte sui punti bui |
| ambienti-1 | session_01E1m21YyF95ZHLwLFM1yLCv | lavoro/ambienti-1 | geyser: V2 flipbook rivista con la luce della sala (e642b91), toglie il punto bianco al centro; poi va nella pagina con la V1 come alternativa |
| ambienti-2 | session_01DHF6GjuPt1SH74CXxGYGC2 | lavoro/ambienti-2 | monitor e fogli della scrivania nella v0.3.7. Inseguimento I1 + SB1, giro 2 con i video (9aa6217): ultimi ritocchi 2-3 h (schiuma delle rapide, partenza B, scogli visibili, posa di A_5), poi nella pagina |
| enigma-logica | session_01RPrxxeJjwAgHgEzLWPXgsn | lavoro/enigma-logica | fiume lento e infermeria: nota e prototipi grigi fatti (8b08b31, logica approvata dall'utente). Aspetta la scelta dell'aspetto |
| enigma-ambiente | session_01Jn42hE4synLdT5YNKedMqv | lavoro/enigma-ambiente | keycard e lettore, poi fiume (d6b959e da riempire, riflessi bianchi, soffitto della A), poi infermeria (71536c3 da rifare con oggetti veri, piena, B da bambini): 18-25 h |
| mascotte | session_01Ut6TnWfhFvUH1yfran7kFa | lavoro/mascotte | rifà tutti gli scatti sulla v0.3.6 (posti delle statue e nome Jilly Jubilee) con le correzioni: testo del manifesto B, targa da vicino, insegna con le sue lampade |

## Come si fa una build

1. In un worktree, `lavoro/godot` riparte da `origin/main`. Si uniscono i branch pronti con `merge --no-ff`, poi push con `--force-with-lease`. La CI fa tutti i test su ogni branch.
2. Con la CI verde, in main: `merge --no-ff origin/lavoro/godot`, `config/version` alzata in `godot/project.godot` e `docs/release/v<versione>.md` (stesso formato delle precedenti), poi push. La CI crea la Release in circa 40 minuti (il limite del lavoro è 60: con il test del primo uso e l'export i 30 di prima non bastavano). Mentre gira, niente push su main: un push nuovo annulla il lavoro in corso.
3. Prima di ogni build, ambienti-2 può controllare con `godot/tools/dipendenze_export.gd` che nessun file escluso dall'export serva al gioco.

## Cose da sapere

- Le pagine di scelta si fanno con `tools/questionario/genera_pagina.py`. Le risposte si leggono con ArtifactData, collezione `risposte`.
- Pagine aperte: punti bui senza torcia (https://claude.ai/artifact/LeZkNfReqLPr8QhE1hZYkb) scelte del 19 ottobre (https://claude.ai/artifact/LQ5qzV1piF99XSTpJTPadn) e stanze nuove (https://claude.ai/artifact/AEqY4ZWpQC7xyTHAZD7Gsq: fiume, infermeria, lettore, keycard; enigma-ambiente 295e9c6), risposte non ancora arrivate. Le scelte del 19 ottobre (https://claude.ai/artifact/LQ5qzV1piF99XSTpJTPadn) sono lette. Quelle del 17 e 18 ottobre (scelte, torre, acquari, mascotte) sono lette e nel GDD.
- L'exe Windows pesa circa 1,44 GB. Le proposte sono escluse dall'export con `exclude_filter` in `godot/export_presets.cfg`.
- Unione della torre (ambienti-2) con enigma-logica: i conflitti sono solo in `.github/workflows/build.yml`, dove vanno tenute le righe dei test di tutti e due, e nel commento del punto 5 in cima a `godot/tests/test_tappa8.gd`. Il codice si unisce da solo: il portone non si apre da solo (enigma), lo apre `apri()` e la torre si carica.

## Pausa fino a mercoledì 21 ottobre

L'utente ha finito i crediti fino a mercoledì: il 19 ottobre alle 07:20 UTC tutte le squadre sono state fermate, con l'ordine di committare quello che avevano e di aspettare un messaggio del coordinatore. Hanno risposto tutte che il lavoro è salvato.

Le scelte del 19 ottobre sono in `docs/riscontri/2026-10-19_scelte.md` e nel GDD; i difetti trovati giocando sono in `docs/riscontri/2026-10-19_prova.md` (8 punti, con la squadra per ognuno) e vanno nella v0.3.8. Alla ripresa:
- **mascotte**: nel gioco le statue nei posti scelti (squalo A in S2, polpo A in A3, polpo B in B1); Jilly Jubilee in stile B, molto più invecchiato: targa, manifesto e insegna con le sue due lampade. Il manifesto tiene "LIVE SHOW" e gli orari (confermato dall'utente).
- **ambienti-2**: l'inseguimento A "Le condotte" con SB1 nel gioco (stima 2-3 giorni), partendo dal giro 3 (lavoro/ambienti-2 8a3b141: SB1 in agguato senza posa a T, tubo laterale nella vasca 2, lampada sulla spirale; restano le vasche un po' scure). I cartelli con le scritte vanno rifatti come disegni. Le rapide restano da parte per un altro punto; se si usano, l'insegna diventa un disegno.
- **ambienti-1**: il geyser V1 (mesh simulata) nel gioco, e via il punto bianco al centro (5f95315: cause già escluse, ripartire dalla prova col cartellone nascosto).
- **enigma-ambiente ed enigma-logica**: nel gioco, lungo la strada di risalita, il fiume lento A (giungla finta), l'infermeria B (per bambini), il lettore 1 accanto alla serranda e la keycard 1 (proposte in lavoro/enigma-ambiente 295e9c6, logica in lavoro/enigma-logica 8b08b31). La luce verde del lettore va più debole. Il fiume B (viaggio sottomarino) resta da parte: l'utente vuole che glielo si riproponga, per il viaggio di ritorno o per una sezione nuova.
- **grafica**: aspetta le risposte della pagina dei punti bui (https://claude.ai/artifact/LeZkNfReqLPr8QhE1hZYkb).
- **Regola nuova per tutti**: nei cartelli del parco solo disegni, niente scritte; fa eccezione il nome di Jilly Jubilee.

## Ultima versione

- **v0.3.7** pubblicata il 19 ottobre alle 07:48 UTC su richiesta dell'utente (main 3abc887; exe unico 1,35 GB): schermo del monitor, fogli della scrivania, torre senza blocchi all'ingresso, riserve dei caricamenti, pacchetto più leggero.

## Da chiedere all'utente

- Una pagina con: posti delle statue, nome Jilly Jubilee, lingua delle scritte del parco (le rapide sono in italiano, il manifesto di Jilly in inglese), inseguimento A/B, geyser V2/V1.
- Dopo, una seconda pagina: aspetto del fiume lento e dell'infermeria, keycard e lettore.
