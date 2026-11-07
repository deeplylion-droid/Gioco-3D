# Collaudo finale 0.3.21, seconda parte (grafica-2)

Base: `lavoro/candidata-0321` **dc83169e**, importata come la build (import e `godot_vram_textures.py` due volte). Zone controllate: dal risveglio alla risalita, fino alla scala di servizio esclusa.

**Esito: nessun difetto.**

## Come

**Misure sulle mesh vere**
- Strumenti: `geometria_risalita_g2.gd` (geometria.gd con la Risalita caricata subito) e `tools/collaudo/distanze.py`.
- Zone misurate: sala, interni, mascotte, Polaroid, acquari, infermeria, stanza delle pozze, corridoi e oblò della Risalita.
- Stati:
  - inizio, 2580 oggetti;
  - ritorno al buio (porte e cassetti aperti, negatoscopio con la radiografia), 2632 oggetti.
- Elenchi in `distanze_inizio.txt` e `distanze_ritorno.txt`.

**Giro dagli occhi**
- Punti:
  - la traccia della strada vera della squadra collaudo (`lavoro/collaudo-ritocchi` 707d076c), tratti I, S1 e la parte mia di R;
  - in più, punti fitti presi dalle celle dove si cammina, uno ogni 2,5-4 m;
  - 4 scatti per punto, con la luce bianca del collaudo sulla camera.
- Le liste sono in `liste/`.

**Da vicino**
- Gli oggetti piccoli e tutti quelli staccati: vedute di `vedute.py` negli interni e nella sala.
- Nella Risalita, righe «mira» di giro.gd per 195 oggetti piccoli, nello stato a fine risalita.

## Zone

| zona | come | scatti | esito |
|---|---|---|---|
| Risveglio, corridoio, spogliatoi, stanzino, lavapiedi, tornello | giro.gd, stato inizio, materiali veri | 164 dagli occhi + 59 da vicino (`1_interni/`) | a posto. Fischietti e asciugamani a 0-1 mm dal muro o dal pavimento; ante, soffioni, rotore del tornello e salvagente a 4-6 mm |
| Sala principale, dalla saracinesca alla statua e tutta la parte al primo passaggio | `giro_sala_parti_g2.gd` (sala per parti, vedi sotto), materiali veri | 321 + 180 con la vasca di Jilly + 14 (`2_sala/`) | a posto; il distacco più grande è 1 cm, fra due pezzi della plafoniera dell'area bimbi (`LuciSala/LuciAreaBimbi/PlafonieraBimbi`), che si toccano fra loro e sono appesi |
| Disegno guida sulla torretta col tetto blu | da terra (sud, sud-est, sud-ovest), di fronte, da vicino, le quattro fascette e di lato | 10 (`2_sala/f_disegno_01.jpg`, `f_salac_01.jpg`) | a posto: all'altezza degli occhi, si vede da terra sopra la ringhiera; le fascette girano attorno ai due corrimani |
| Corridoio del personale col cartello delle pozze, oblò, Polaroid 13 e 15 | giro.gd, stato `risalita_arrivo` | 266 (`3_risalita_arrivo/`) | a posto; cartello e faretto fissati, Polaroid a terra |
| Infermeria nei suoi stati | `risalita_arrivo` (buio, tutto chiuso) e `risalita_dopo` (luce, cassetti tirati, cassaforte aperta, negatoscopio con la radiografia) | 266 + 656 (`4_risalita_dopo/`) | a posto; cassetti, cassaforte e lastra (4 mm dal negatoscopio) a contatto |
| Stanza delle pozze nei suoi stati | pozze piene e porta chiusa; pozze risolte (viola, arancione e turchese vuote) e porta stagna aperta | nei due giri della Risalita | a posto; la porta aperta lascia libero il passaggio verso la scala |
| Corridoi della Risalita (dalla scala del fiume all'imbarco, approdo, zona del personale) | stessi due giri | come sopra | a posto |

Niente oggetti sospesi o staccati oltre 1 cm, niente compenetrazioni viste, niente ingombri sotto i 2 m sulla strada. Porte, Polaroid e pulsanti sono liberi. Non ho visto buchi o cielo dove il gioco è caricato intero.

## Cose da sapere

- **La sala intera non entra più in memoria nemmeno coi materiali semplici.** Col giro.gd di sempre il processo arriva a 12,3-12,5 GB ed è ucciso; il limite della sessione è sui 12,5 GB.
  - La parte che pesa di più è la vasca centrale con Jilly: +4 GB da sola.
  - Per questo la sala si fa per parti (`godot/tests/collaudo/giro_sala_parti_g2.gd`, come lo scatto di lei che sbuca). Si caricano solo le parti che servono, sotto una radice nuova con gli stessi nomi; ogni mesh parte spenta e si accendono solo quelle entro 22 m dalla camera.
  - Due passate: tutto senza la vasca (8,3 GB), poi i punti entro 12 m dalla vasca con la vasca (10,6 GB).
- **Il cielo e il nero in alcuni scatti vengono dallo strumento, non dal gioco.** Negli scatti per parti le zone non caricate si vedono come cielo o come nero:
  - nella sala, il passaggio della saracinesca senza gli interni (`S1_017`, `S1_018`);
  - il pozzo (`S1_022`), che è dei tecnici;
  - nella Risalita, verso il raccordo (`R_065`, `R_066`).

  Il passaggio della saracinesca è rifatto con gli interni caricati (`f_salac_01.jpg`): è chiuso, perché lo stato è inizio, e attorno non ci sono buchi.
- **Il gioco non si apre col preset di serie.** Il giro usa il preset basso, come giro.gd.
  - Le texture più leggere (oggetti piccoli a 1024) da vicino: nelle vedute ravvicinate non ci sono sfocature né texture rovinate.
  - Il confronto numerico con la 0.3.20 è nella prima parte (`finale_0321_g2/texture_0320_0321.jpg`): differenza media 0,0-0,2 su 255.
- In questi giri compaiono due «SCRIPT ERROR» di oggetti liberati (audio e `sala_principale.gd:425`): vengono dai nodi che lo strumento toglie dalla scena, non dal gioco.
- Gli oblò visti con la «mira» automatica sono presi da dietro il muro, quindi non servono. Gli oblò si vedono bene negli scatti dagli occhi (`R_074`, `R_075`, `ris010_e`).
- Strumenti nuovi nel branch:
  - stati `risalita_arrivo` e `risalita_dopo` in `tests/collaudo/stati.gd`, uguali a quelli del controllo della CI;
  - `geometria_risalita_g2.gd`;
  - `giro_sala_parti_g2.gd`, con `SCATTI_PARTI` e `SCATTI_RAGGIO`.
