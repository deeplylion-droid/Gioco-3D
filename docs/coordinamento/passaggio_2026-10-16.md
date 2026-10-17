# Passaggio al nuovo coordinatore (16 ottobre, sera)

La sessione di coordinamento precedente era diventata troppo lunga e quindi cara: ogni avviso degli agenti costava una rilettura di tutta la storia. L'utente ha approvato il passaggio a una sessione nuova dopo la v0.3.2. Prima di tutto leggi `CLAUDE.md`, `docs/GDD.md` e i riscontri in `docs/riscontri/`. Qui c'è solo quello che non si ricava da quei file.

## Come lavorare con l'utente

- Scrive in italiano, spesso dal telefono: rispondi in italiano, in modo breve.
- **Costi**: l'utente ha finito il piano e ha caricato 300 crediti extra. Oggi pomeriggio, con 4-5 agenti attivi, si spendevano circa 50 $ l'ora, la maggior parte nella sessione di coordinamento. Quindi:
  - fai pochi controlli periodici, solo prima delle build;
  - usa meno agenti in parallelo;
  - non svegliarti per niente.
- "Quando ti correggo qualcosa non ripropormelo uguale!!": ogni correzione si controlla con occhio critico prima di mostrarla.
- Le stime dei tempi vanno date larghe. Oggi la build è arrivata in ritardo rispetto alla stima, perché gli scatti dal motore sono lenti.
- Le risposte alle pagine di scelta si leggono con `ArtifactData`: action `list`, url della pagina, collezione `risposte`. Un documento per voce: `{stato, nota, quando}`.
- Le pagine si generano con `tools/questionario/genera_pagina.py`. L'esempio delle voci è in `voci_esempio_zaino.py`, l'uso è scritto in cima allo script. Si pubblicano con lo strumento Artifact e `capabilities: {"db": {}}`.

## Dove siamo

- **v0.3.2** pubblicata il 16 ottobre: le correzioni dei 14 punti di `docs/riscontri/2026-10-16_prova_v031.md`. Main è sopra la merge di lavoro/godot cca9f08.
- Gli scatti di controllo della v0.3.2 sono in `docs/report/controllo_v032/`. L'integratore stava aggiungendo gli ultimi: il punto 4 (portellone all'asciutto dopo il getto) e il punto 3 dalla spiaggia con la luce più forte.

## In attesa dell'utente

1. **Pagina dello zaino**: https://claude.ai/artifact/AwALohG3JD8kr43ajUn8V3. Alle 18 UTC del 16 non aveva ancora risposto.
   - **Z1, il getto**: A "manichetta" o B "potenziata". I video e il codice sono su lavoro/grafica (e8271a0, `godot/proposte/zaino/getto_potente.gd`, solo proposta). I suoni sono su main, in `assets_src/audio/proposte_getto/a|b/` e `godot/audio/anteprima/proposta_getto_*.ogg`.
   - **Z2, la lancia**: A pompiere, B cannone, C, C1 o C2. Le lance sono su lavoro/ambienti-1: 9ee5eb2 e 69d6b8a (due mani); scene in `godot/scenes/player/lance/proposte/`.
   - **Z3, una mano o due**.
   - Dopo la scelta: grafica porta nel gioco il getto scelto, ambienti-1 la lancia scelta e l'agente audio i suoni (nomi `zaino_*`, già pronti in `proposte_getto/`).
2. **Luce del portellone** (punto 3): all'utente sono stati mandati gli scatti. Se la vuole più forte bastano due valori export in `scripts/game/luce_portellone.gd`: `bagliore` ed `emissione_anello`.

## Lavori in corso

- **Strada di risalita della tappa 7** (punto 12, solo proposta). Se ne occupa la sessione cloud ambienti-1 (session_01E1m21YyF95ZHLwLFM1yLCv): due arredamenti per scale e magazzino con oggetti Meshy, più due o tre modi in cui compaiono i bambini, con scatti e video dal motore. Va mostrata all'utente con una pagina di scelta; niente nel gioco senza la sua scelta.
- **Area bimbi HD con Meshy** (task "Meshy HQ"):
  - è su lavoro/bimbi-hq 39d624c: confronti OGGI/HD in `docs/proposte/bimbi_hq/`;
  - l'agente ambiente stava facendo i 7 render Cycles da vicino, `docs/proposte/bimbi_hq/render_*.jpg`; controlla se sono arrivati sul branch;
  - in gioco, da lontano, la differenza con oggi è piccola: per la pagina servono i render;
  - le differenze sono nel resoconto di ambiente: scivolo +25 cm sopra il bordo della vasca piccola, telaio del secchio a 7,84 m, perno +36 cm, Polaroid 4 a 6,78 m;
  - il GLB pesa 48,7 MB (limite 50): se l'utente lo sceglie, prima vanno ridotte texture o triangoli;
  - i GLB 4K grezzi di Meshy scadono il 19 ottobre.
- **Più avanti**: poster grandi e volantini della crociera sulle pareti (GDD, "Da fare più avanti"). Poi l'interno della sala della torre con gli scivoli nuovi, i bambini della balconata, la Polaroid 10, l'inseguimento e il finale.

## Squadre

| Squadra | Dove | Branch | Note |
|---|---|---|---|
| grafica | sessione cloud session_01Q9PdaHCaFPsyZ4J69AtTTt | lavoro/grafica | getto e aspirazione dello zaino; aspetta la scelta Z1 |
| ambienti-1 | sessione cloud session_01E1m21YyF95ZHLwLFM1yLCv | lavoro/ambienti-1 (può pushare solo lì) | interni, lance, leva della sala pompe, strada della tappa 7 |
| ambienti-2 | sessione cloud session_01DHF6GjuPt1SH74CXxGYGC2 | lavoro/ambienti-2 (può pushare solo lì) | stanze tecniche: piscina a onde, sala pompe, cancelli stagni |
| integratore, ambiente, audio | agenti locali della sessione vecchia | lavoro/godot, lavoro/ambiente, lavoro/bimbi-hq, lavoro/audio | nella sessione nuova non ci sono: se servono, si rifanno come agenti o sessioni nuove |

- Alle sessioni cloud si scrive con `send_message`; rispondono con messaggi che arrivano come notifiche.
- Ognuna ha la sua macchina, quindi i lavori pesanti in Godot o Blender conviene farli lì.
- Nella macchina del coordinatore c'è la regola della memoria di `CLAUDE.md`: un solo Godot o Blender alla volta, sotto `flock /home/user/tools/render.lock`. Per Godot e Blender bisogna prima lanciare `bash tools/setup_ambiente.sh`.

## Come si fa una build

1. Si uniscono i branch in lavoro/godot e girano tutti i test, gli stessi della CI.
2. In main si fa `git merge --no-ff origin/lavoro/godot`, si alza `config/version` in `godot/project.godot` e si scrive `docs/release/v<versione>.md`, con lo stesso formato di v0.3.2.md e la guida "dove trovare le novità".
3. Push: la CI dura circa 20 minuti e crea la Release `v<versione>` con exe e zip per Windows e lo zip per Linux.
4. All'utente si mandano i link.

## Meshy

Il saldo è circa 13.500 crediti e si rinnovano il 15 novembre. L'utente ha detto di usarli per gli oggetti della sala che non vengono ancora da Meshy e per la sala della torre, sempre proponendoli prima con i render.
