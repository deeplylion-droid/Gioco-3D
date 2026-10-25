# Collaudo del cartellone di Jilly rifatto più rovinato (lavoro/grafica2-scelte f4a49ff0)

Il collaudo l'ha fatto la squadra enigmi, che non ha fatto il cartellone. Il 25 ottobre mattina ho guardato il cartellone con la camera del giocatore e la luce del gioco. Non ho corretto niente.

## Dove c'è

- **Il cartellone usa la texture nuova solo nel corridoio degli interni.** È la superficie con il materiale `cartellone_medusa` di `corridoio.gltf`: un rettangolo solo, largo 1,50 m e alto 2,00 m (da 0,3 a 2,3 m), sulla parete sud. Sta proprio accanto a dove il giocatore si sveglia: nella sala è centrato in (4,9; 1,3; 40,88).
- **Nella sala la texture non c'è.** I cartelloni con la mascotte di `sala_architettura.glb` (`sala_cartellone_mascotte_0` e `_1`) usano un'altra immagine, `cartellone_medusa_col`, incorporata nel GLB. Questo commit non la cambia, quindi nella sala non c'è niente da vedere.

## Come

- **Strumento**: `godot/tests/collaudo/scatti_cartellone.gd`. Trova il cartellone dal materiale e prende gli scatti col Player vero, senza zaino e senza HUD:
  - da dove passa il giocatore, arrivando dalle due parti del corridoio;
  - davanti;
  - ravvicinato;
  - i due bordi;
  - di taglio lungo il muro.
- **Dove sono gli interni**: nella posizione che hanno nella sala, con l'ambiente della sala (la sala intera renderizzata non ci sta nella memoria della macchina di prova).
- **Due luci**: com'è all'inizio del gioco e al buio dopo la sala pompe (BLACKOUT).
- **Misure**: `misura_cartellone.gd`, senza schermo, misura il cartellone contro il muro e quello che gli sta davanti. Ho analizzato anche la texture.
- **File**: gli scatti sono in `scatti/` (`inizio_*` e `buio_*`), messi insieme in `foglio.jpg`. In `texture_trasparenze_in_magenta.jpg` le parti trasparenti della texture sono colorate di magenta.

## Controlli

| Cosa | Esito | Note |
|---|---|---|
| Buchi trasparenti strani | ok | Il 25% della texture è trasparente, tutto a taglio netto (alfa 0 o 255, niente semitrasparenze). Ci sono lo strappo che attraversa il cartellone, i pezzi mancanti in alto a destra e in basso a destra, e 4 buchetti interni di 2-3 cm, uno al centro della croce sulla faccia. Attraverso gli strappi si vede il muro grigio scuro subito dietro, ed è coerente (scatti `*_3_davanti`, `*_4_ravvicinato`). |
| Bordi neri | ok | Sotto le parti trasparenti la texture tiene i colori (in media RGB 88/97/74, 0% quasi nero). Quindi i mipmap non scuriscono gli strappi, e negli scatti i bordi degli strappi non hanno righe nere. |
| Si capisce che è lei, bruciata e strappata | ok | Da 1,2 m (`buio_0_3_davanti`) si leggono: la faccia annerita con la croce e i denti a vernice bianca, gli scarabocchi, il corpo da medusa coi tentacoli, l'arcobaleno, lo strappo. Da vicino si vedono le bruciature e i puntini. |
| Pezzi staccati dal muro | nota (vedi C1) | Il cartellone è un rettangolo intero, non ha pezzi a parte. Però sta 1,6 cm davanti al muro. |

## Difetti e note

Nessun difetto nuovo dovuto alla texture nuova. Ci sono due note sulla geometria, che questo commit non tocca:

- **C1 (posizionamento, già così prima): il cartellone sta 1,6 cm davanti al muro.** Le facce del muro dietro di lui sono fino a 1,6 cm più indietro: il cartellone è a z -0,016 negli interni, il muro a 0. Negli scatti non si vede, perché il corridoio è stretto e lo si guarda quasi di fronte. Con gli strappi grandi della texture nuova, però, i bordi della carta restano sospesi a 1,6 cm dal muro. Per la regola dei collaudi ("anche 1-2 cm di distacco sono un difetto") va portato a 2-3 mm dal muro. Da correggere in `corridoio.gltf`: è la superficie del materiale `cartellone_medusa` nella mesh `corridoio_statico`.
- **C2 (nota): davanti alla parte alta del cartellone, a 2,05-2,10 m, c'è un pezzo di metallo** (`metallo_grezzo`, 3 triangoli) che sporge fino a 10 cm. È un elemento della parete che passa sopra il cartellone. Non compenetra, ma è come se il cartellone fosse stato incollato sotto quel pezzo.
- **Non è un difetto: la riga scura a circa 1,1 m.** Negli scatti davanti e ravvicinati una riga orizzontale scura attraversa il cartellone e la parte sotto è più buia. Non è nella texture e non è un decal (quelli del corridoio stanno lontano dal cartellone). È l'ombra che taglia allo stesso modo anche il muro accanto (`*_5_bordo_*`).
