# Squadre e sessioni (aggiornato il 22 ottobre)

Il coordinatore è la sessione session_01Ub9Z8mJaiFbdfRfYi8QhGz: tutte le squadre gli mandano i resoconti con send_message. Il passaggio del 16 ottobre è in `passaggio_2026-10-16.md`.

| Squadra | Sessione cloud | Branch | Lavoro |
|---|---|---|---|
| mascotte | session_01YWTG1mGq714ESVViUmQhYw | lavoro/lei-inseguimento | animazioni di lei per l'inseguimento fatte (88ae2ba, scatti e video in docs/report/mascotte/lei_inseguimento/); ora le aggancia lui nell'inseguimento partendo da 593d6bf, poi le rivede ambienti-2 |
| ambienti-2 | session_019HZGeneQaXJBRDNw4H3tQj | lavoro/ambienti-2-inseguimento | inseguimento A con SB1 fatto, con vasche c e strisce a (593d6bf); discesa_5_0 unita. Aspetta le animazioni di mascotte; intanto le prove dello sfondo del titolo su lavoro/ambienti-2-menu (strati A cupola e tempesta, B acqua ai suoi piedi, C pezzi della sala; scatti di B+C, A+B, A, B) |
| ambienti-1 | session_01NbNne93LWX1hZUrGWpCyL8 | lavoro/ambienti-1 | tuffo A consegnato (3df43ba); ritocco della corona (meno lamina, acqua bianca, gocce che sembrino acqua), geyser V1 fuori dall'esportazione; poi valvola_corridoio_1 e turbina_saracinesca |
| enigmi | session_01T7gXU9URJunXdQxrRAzoeN | lavoro/enigma-ambiente | fiume A con lo scivolo B, infermeria B, lettore, keycard, strada β, Polaroid della pecora: uniti per la v0.3.9 (6271159) |
| grafica | session_01CKPshjKrddtekB7nZK4rGD | lavoro/grafica | nome Jilly Jubilee unito (58cc633); prima il crash all'uscita mentre la torre si carica nel thread (CI rossa su 58cc633), poi il logo A scelto dall'utente nella schermata del titolo, com'era nella prova |

Le sessioni vecchie (grafica session_01Q9PdaHCaFPsyZ4J69AtTTt, ambienti-1 session_01E1m21YyF95ZHLwLFM1yLCv, ambienti-2 session_01DHF6GjuPt1SH74CXxGYGC2, enigma-logica session_01RPrxxeJjwAgHgEzLWPXgsn, enigma-ambiente session_01Jn42hE4synLdT5YNKedMqv, mascotte session_01Ut6TnWfhFvUH1yfran7kFa) sono ferme dal 21 ottobre: avevano conversazioni lunghissime che costavano a ogni passo. Ognuna ha lasciato un passaggio di consegne in `docs/coordinamento/passaggi/<squadra>.md` sul suo branch.

## Come si fa una build

1. In un worktree, `lavoro/godot` riparte da `origin/main`. Si uniscono i branch pronti con `merge --no-ff`, poi push con `--force-with-lease`. La CI fa tutti i test su ogni branch.
2. Con la CI verde, in main: `merge --no-ff origin/lavoro/godot`, `config/version` alzata in `godot/project.godot` e `docs/release/v<versione>.md` (stesso formato delle precedenti), poi push. La CI crea la Release in circa 40 minuti (il limite del lavoro è 60: con il test del primo uso e l'export i 30 di prima non bastavano). Mentre gira, niente push su main: un push nuovo annulla il lavoro in corso.
3. Prima di ogni build, ambienti-2 può controllare con `godot/tools/dipendenze_export.gd` che nessun file escluso dall'export serva al gioco.

## Cose da sapere

- Le pagine di scelta si fanno con `tools/questionario/genera_pagina.py`. Le risposte si leggono con ArtifactData, collezione `risposte`.
- Logo: l'utente ha scelto in chat la A del primo giro ("Senti usiamo l'A di prima"); la pagina del secondo giro D/E/F (https://claude.ai/artifact/9yswiYCFBj2TfBvVSwEQjh) è chiusa. Le proposte sono in lavoro/grafica-nome 98304dc, `docs/proposte/logo/`.
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

## Autorizzazioni dell'utente (21 ottobre, sera)

- Il coordinatore può pubblicare la v0.3.8 da solo, quando le correzioni sono pronte e tutti i test passano.
- Il coordinatore decide se il geyser V1 nel gioco va bene o se passare al tuffo di Jilly, e poi lo spiega all'utente.

## Ultima versione

- **v0.3.8** pubblicata il 22 ottobre mattina, come autorizzato dall'utente: le correzioni della prova del 19 ottobre, l'inizio con il mostro-squalo, la torcia (F, energia 1,4), statue e Jilly, la strada nella torre con le vasche, acquari doppi in P1, il controllo automatico di posizionamento nella CI. Scelte del 22 ottobre in `docs/riscontri/2026-10-22_scelte.md`.
- **v0.3.7** pubblicata il 19 ottobre alle 07:48 UTC su richiesta dell'utente (main 3abc887; exe unico 1,35 GB): schermo del monitor, fogli della scrivania, torre senza blocchi all'ingresso, riserve dei caricamenti, pacchetto più leggero.

## In lavorazione: v0.3.9

In lavoro/godot finora: griglia del controllo di posizionamento e collisioni dei tecnici (a87a7d0), fiume, infermeria, keycard, strada β e P11 (6271159), discesa_5_0 della torre (a871c43), nome Jilly Jubilee (58cc633). Da unire: il tuffo A (ambienti-1, dopo il ritocco), l'inseguimento (ambienti-2, dopo le animazioni di mascotte), la correzione del crash all'uscita e il logo A nella schermata del titolo (grafica). Le note della Release useranno i nomi nuovi dei file (JillyJubilee-windows-v0.3.9.exe e gli zip).

## Da chiedere all'utente

- Sfondo del titolo (ora "tutto nero"): l'utente ha chiesto B+C (acqua ai suoi piedi e pezzi della sala dietro) e le prove anche di A+B, A e B. Poi ha chiesto solo le due combinazioni: B+C e A+B (anche durante il lampo). Quando arrivano gli scatti di ambienti-2, pagina con le prove; nel gioco niente finché non sceglie.
- Inseguimento: nella vasca 1 la campana di lei poggia sul fondo e i tentacoli lo attraversano (salendo da -5 m passa il fondo); con l'acqua più chiara si vede. Da chiedere: pozzo di scarico nel fondo come in SB1, oppure vasca più profonda in quel punto. Poi lo fa ambienti-2. Anche le animazioni di lei vanno mostrate (scatti già fatti).
- I promemoria di Steam parlano ancora di «Splashland»: proposto di aggiornarli, nessuna risposta. Su itch l'utente deve rinominare la bozza.
