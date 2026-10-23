# Proposta: muri e macchie più calmi (23 ottobre)

Richiesta dell'utente: "alcune texture di muri mi danno fastidio perché sono troppo dettagliate [...] Me le
semplifichi un bel po?". Sul foglio numerato ha scelto **1, 4, 5 e 7**, e "ci sono anche altre macchie di ruggine
fastidiose". Il 2 (ruggine degli interni), il 3 (green_metal_rust) e il 6 (cemento del fiume) restano come sono.

**Niente è cambiato nel gioco.** Le versioni calme sono state messe solo negli scatti del collaudo
(`godot/tests/collaudo/giro_sost.gd`, che cambia le texture dopo aver caricato la scena), dagli stessi punti degli scatti
"prima". L'elenco completo dei muri e delle macchie, con dove sono e quanto coprono, è in
`docs/collaudo/texture_muri/inventario.md`.

## Come sono fatte le versioni calme

Stessa texture, stesso colore medio, stessa idea; tolto quasi tutto il dettaglio fine:

- via le macchioline e i dettagli fitti, restano solo le variazioni larghe;
- contrasto molto più basso: le variazioni larghe al 20-45% di prima, il dettaglio fine al 10-20%;
- rilievo (normal) al 35% di prima, ammorbidito;
- la scala resta quella di oggi. Solo Rust004 è più grande (0,7): ingrandendo il cemento con la rete e l'intonaco,
  le macchie diventavano più grandi e si notavano di più.

| N. | Texture | Dove si vede | Cosa cambia |
|---|---|---|---|
| 1 | Rust004 (`ambienti_tecnici/texture/Rust004_*`) | tecnici (pale, bocchette, nicchie, meccanismi della sala pompe, circa 10 m² di muro) e le due pompe della torre | contrasto al 45%, dettaglio fine al 22%, rilievo al 35%, scala 0,7 |
| 4 | Concrete042C, il cemento con la rete arrugginita (`ambienti_tecnici/texture/Concrete042C_*`) | muri bassi della camera delle onde e del raccordo (tecnici, 1400 m²), zona del personale della risalita (284 m²) | la rete resta appena accennata: contrasto al 20%, dettaglio fine all'8%, rilievo al 35% |
| 5 | cemento degli interni (`ambienti_interni/texture/cemento_*`) | solo il ribassamento nel pavimento del corridoio, 3 × 1,4 m | contrasto al 30%, dettaglio fine al 12%, rilievo al 35% |
| 7 | intonaco dell'infermeria (`infermeria/texture/intonaco_*`) | muri e soffitto dell'infermeria (81 m²) | le scrostature quasi sparite: contrasto al 25%, dettaglio fine al 10%, rilievo al 35%, ruvidità più uniforme |

## Le macchie di ruggine: cosa propongo

Per ogni tipo ho scelto se farle più calme o meno numerose:

| Macchia | Quante, dove | Proposta |
|---|---|---|
| Ruggine che esce da sotto la vernice, sui muri dei tecnici (shader dei muri `parete.gdshader`, texture `ruggine_col`) | muri a lastre e di cemento di camera delle onde, sala pompe, magazzino e raccordo (3200 m²). Quasi tutta sta **sopra i 2,25 m** (la "zona dei tubi", dove lo shader scrosta metà del muro), il resto in chiazze sparse | **meno numerose**: sopra i 2,25 m circa un terzo di prima, e le chiazze sparse dimezzate. La texture della ruggine resta com'è, perché il 2 resta. |
| Colature e sporco in basso, disegnati dallo shader su tutti i muri di interni e tecnici | tutti i muri | **più calme**: colature da 0,7 a 0,3, sporco in basso da 0,75 a 0,45 |
| Decal di ruggine colata (`decal_ruggine`), strisce di 0,5-0,8 × 1-1,8 m sotto i tubi | 14 negli interni, 14 nei tecnici | **meno numerose e più calme**: una su due, con bordi più morbidi, al 45% di coprenza e un arancio meno acceso |
| Decal di macchia scura (`decal_macchia`), a terra e sul soffitto, 1,4-2,2 m | 8 negli interni, 16 nei tecnici | **più calme**: bordi più morbidi, al 55% di coprenza |
| Colatura di ruggine sotto i tubi della sala (`macchia_ruggine_colata`, 1,2 × 0,35 m) | 36 sui muri della sala | **più calme**: stessa forma, al 45% di coprenza, arancio meno acceso. Il numero resta, perché ognuna sta sotto un tubo. |
| Colature dei muri della sala (`sala_colature`) | 77 m² sotto il cornicione | **più calme**: al 50% di coprenza, bordi più morbidi |

Le altre macchie della sala (alghe, calcare, muffa) non sono ruggine e restano come sono.

**Da sapere, senza scatti nuovi.** Anche la texture dei muri a lastre, MetalPlates013 (tecnici 1829 m², parte alta dei
muri della risalita 581 m²), ha le sue strisce di ruggine arancio, disegnate dentro la texture. Non era sul foglio.
Se all'utente danno fastidio, si può fare calma come le altre: gli scatti si fanno solo se li vuole.

## Fogli

Ogni foglio ha quattro colonne: prima e dopo nella luce del gioco (luci al 40%, niente torcia), poi prima e dopo in
luce neutra (una luce bianca sulla camera, per vedere bene la texture). Nella luce del gioco molti muri sono quasi
neri: è il buio voluto. Dove una luce d'allarme lampeggia e i due scatti non hanno la stessa luce, c'è solo la luce
neutra.

- `foglio_texture_sole.jpg`: le texture da sole, prima e dopo.
- `foglio_1_rust004.jpg`
- `foglio_4_cemento_rete.jpg`
- `foglio_5_cemento_interni.jpg`
- `foglio_7_intonaco.jpg`
- `foglio_macchie_tecnici_interni.jpg`
- `foglio_macchie_sala.jpg`: solo com'è ora nel gioco, più le due texture prima e dopo. Lo scatto "dopo" della sala
  principale va fuori memoria sul renderer del sandbox (anche senza cupola, tre tentativi), quindi la versione calma
  della sala si vede solo sulla texture.

Nella luce del gioco alcune coppie hanno una luce un po' diversa tra prima e dopo (le luci della sala pompe e
l'allarme rosso del corridoio cambiano nel tempo): conta il confronto in luce neutra.

## Per rifare gli scatti

`docs/proposte/texture_muri/sostituzioni.json` dice cosa cambiare. Le texture calme sono in `texture_calme/` (fatte con
`tools/collaudo/texture_calma.py` e `tools/collaudo/macchia_calma.py`). La copia di prova dello shader è
`godot/tests/collaudo/parete_prova.gdshader`: un solo parametro in più, `soglia_alto`, che a 0,35 dà lo shader di oggi.
Dalla cartella `godot`:

    COLLAUDO_SOSTITUZIONI=../docs/proposte/texture_muri/sostituzioni.json COLLAUDO_GI=1 COLLAUDO_LUCI40=1 \
    xvfb-run -a -s "-screen 0 960x540x24" flock /home/user/tools/render.lock godot --path . --rendering-driver vulkan \
    --fixed-fps 60 --resolution 960x540 --script res://tests/run.gd -- res://tests/collaudo/giro_sost.gd \
    res://scenes/tecnici/tecnici.tscn inizio <cartella scatti> <lista vedute>

I fogli si fanno con `tools/collaudo/fogli_prima_dopo.py`.

## Domande per l'utente

Per ogni voce (1, 4, 5, 7 e le sei righe delle macchie): va bene così, più calma ancora, oppure meno calma?
Dopo il sì, il lavoro nel gioco è piccolo:
- si sostituiscono i file delle texture, tenendo i vecchi in `scartati/`;
- nello shader dei muri si aggiunge `soglia_alto`, come nella copia di prova;
- nei materiali dei tecnici si cambiano quattro numeri: colature, sporco in basso, scrostatura e `soglia_alto`;
- in `tecnici.gd` e `materiali_interni.gd` si cambia una riga per togliere metà delle decal di ruggine.

Il 4 cambia anche la risalita, che usa lo stesso Concrete042C.
