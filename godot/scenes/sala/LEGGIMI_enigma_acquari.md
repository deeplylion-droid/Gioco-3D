# L'enigma degli acquari: struttura della scena

`enigma_acquari.tscn` è l'enigma degli acquari della sala principale (GDD, "L'enigma degli acquari"). Lo script è `scripts/game/enigma_acquari.gd` (EnigmaAcquari). Ora ci sono forme provvisorie. La squadra enigma-ambiente mette i modelli veri **dentro** questi nodi, **senza cambiarne i nomi**, e può spostarli, ruotarli o ridimensionarli.

La radice sta nell'origine della sala: le posizioni dei figli sono quelle della sala. Gli acquari stanno a sud del portone della torre, lungo la parete est (posto provvisorio).

| Nodo | Tipo | Cosa fa |
|---|---|---|
| `AcquarioGiallo` | WaterTank (Node3D) | Acquario pieno di giallo (`fill_pigment = "giallo"`), 80 litri. Lo zaino ci aspira. Non si esaurisce (`min_fill`). Il getto non ci entra. |
| `AcquarioBlu` | WaterTank | Uguale, blu. |
| `AcquarioMisto` | WaterTank | Vuoto, 62 litri: si riempie con tre zainate. Non ci si aspira. Ora sta su un `Basamento` provvisorio (StaticBody3D). |
| `Valvola` | Node3D | La grossa valvola rossa sotto l'acquario del miscuglio. Dentro c'è `Modello`, provvisorio, e `Bersaglio`, un WaterHitbox con una sfera di 35 cm: il getto lo deve poter colpire, quindi va lasciato davanti al modello. |
| `Disegno` | Node3D | Il disegno a pastello dei bambini con il verde. Ora c'è un riquadro verde (`Modello`). |
| `LampadePortone` | Node3D | Le lampade del portone, spente finché gli acquari non compaiono. Ora ci sono `Lampada1` e `Lampada2`, ciascuna con `Modello` e `Luce` (OmniLight3D). Si possono aggiungere altre lampade e luci qui dentro: lo script accende e spegne tutto il nodo. |

## Come funziona per chi fa i modelli

- **Pareti degli acquari**: WaterTank costruisce da solo muri e superficie provvisori, in base a `inner_size` e `wall_thickness`, con l'origine al centro del fondo interno. Per usare un modello vero si mette `build_walls = false`: restano solo la superficie dell'acqua e il volume. Il modello va dentro il nodo, con il vetro e una collisione propria. `inner_size` deve corrispondere allo spazio interno del modello.
- **Colore dell'acqua**: ogni acquario ha `mix`, cioè quanta parte di ogni pigmento contiene (vedi `scripts/water/water_mix.gd`), ed emette `mix_changed(mix)` quando cambia. Con un materiale standard sulla superficie (`water_material`), il colore lo cambia WaterTank da solo. Con uno shader, si ascolta `mix_changed` e si usano `WaterMix.tinta(mix)` e `WaterMix.intensita(mix)`. I colori provvisori sono in `WaterMix.COLORI` e `WaterMix.SFUMATURA`. Le tinte possibili sono: giallo, blu, i miscugli via via fino al verde, il verde dell'enigma riuscito e il torbido.
- **Segnali dell'enigma** (EnigmaAcquari), per suoni ed effetti: `comparso`, `risolto` (acqua verde e portone che si apre), `sbagliato` (torbido), `gorgo_iniziato` (la valvola gira e l'acquario si svuota in `durata_gorgo` secondi), `ripristinato`. Il gorgo vero, cioè l'effetto e il suono, va agganciato a `gorgo_iniziato`.
- **Momenti**: tutti i figli sono nascosti e spenti, collisioni comprese, finché non si rientra dal magazzino (la serranda si apre, tappa 7). Funzionano solo dopo la tappa 8.
