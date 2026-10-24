# Ricontrollo risalita e fiume (lavoro/fiume-a1b ad97ee78)

Ricontrollo fatto il 24 ottobre, dopo le correzioni di ambienti-1. Non ho corretto niente.
Gli scatti sono del motore, con i materiali piatti di COLLAUDO_SEMPLICE. La camminata all'ingresso ha i materiali veri.
Dalla ciambella ho fatto uno scatto ogni 2 m su tutti i tratti, guardando a sinistra (`_s`), a destra (`_d`) e avanti: in tutto 276 scatti.

## Esito

| Punto | Esito |
|---|---|
| Roccia della sponda sinistra, imbarco e curva verso la piazza (Imbarco 00-27) | **Risolto**: tutta roccia (`imbarco_sinistra.jpg`) |
| Roccia della sponda sinistra, tratti giusti (Giusto1 e Giusto2) | **Risolto** (`Giusto1_sinistra.jpg`, `Giusto2_sinistra.jpg`) |
| Staffa vuota in C3 | **Risolto**: non c'è più, e quella con il salvagente (m_1) è al suo posto (`c3_staffa_dopo.jpg`) |
| Sfarfallio all'ingresso | **Non si vede** (vedi sotto) |
| Controllo di posizionamento, risalita_arrivo e risalita_dopo | **Passa**: 0 casi nuovi, 16 noti, 26 eccezioni che non servono più |

## Restano, da decidere

1. **Liste grigie fra i pannelli di roccia nelle conche.** In Giusto1 17-18 e in Imbarco 26-27, a sinistra, verso la paratia, fra un pannello e l'altro si vede una lista di muro grigio liscio larga 30-50 cm, dietro i pilastri scuri (`liste_grigie_conche.jpg`). Si notano poco, ma sono buchi nella roccia, non pezzi della paratia.
2. **Pilastro grigio al bivio di Giusto2.** A destra, in Giusto2 06-11 (intorno a (-52; 75)), c'è un blocco di cemento liscio alto quanto la roccia, con la roccia ai due lati e l'apertura del ramo dietro (`pilastro_grigio_giusto2.jpg`). Può essere la testa del muro del bivio. Però è un prisma grigio liscio in mezzo alla roccia: va deciso se coprirlo.

## Muri grigi vicino alle paratie verdi, a fine tratto

Sono i muri di Giusto1 17-18 e di Giusto2 16-18 (`fine_tratti.jpg`). Intorno alla paratia verde e alla porta si leggono come il muro di cemento della conca: hanno senso. Fanno eccezione solo le liste strette del punto 1. Il muro di cemento dell'approdo con la porta (scatti c_Uscita) resta così, come avete deciso.

## Sfarfallio all'ingresso

- Ho fatto 210 fotogrammi con i materiali veri a 960×540, uno ogni 4 cm, entrando dal cancello e lungo le transenne (`cammina_ogni10.jpg`). Validi sono i primi 108: dopo, la strada che avevo tracciato entra nelle pile, per un mio errore di percorso.
- Ho cercato i pixel che cambiano e tornano com'erano fra un fotogramma e il successivo. Sono solo punti sparsi sui bordi delle texture, cioè l'aliasing del renderer software. Non ci sono macchie ferme sul pavimento sotto le transenne e le pile, né sui muri dell'ingresso (`sfarfallio_su_w060.jpg`, in verde).
- Con la sollevata di 1 mm non vedo sfarfallio. È stato misurato sul renderer software del sandbox: su una scheda vera conviene uno sguardo veloce.

## Il resto

I rami sbagliati e l'uscita sono a posto, con la ciambella verde e la roccia continua (`sbagliati_e_uscita.jpg`). La sponda destra è roccia anche sull'imbarco e su Giusto1 (`imbarco_destra.jpg`, `Giusto1_destra.jpg`).
