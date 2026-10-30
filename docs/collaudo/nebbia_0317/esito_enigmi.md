# Ricontrollo nebbia 0.3.17 (lavoro/nebbia-0317 786dcf48): la parte di enigmi

Seguito di `esito_parziale.md` di ambienti-1, che ha fatto il tunnel; la luce rosa guardando avanti è passata a grafica-2. Qui ci sono piscina, infermeria, impostazioni versione 3 e nebbia spenta e riaccesa.

Scatti col renderer vero, occhi a 1,6 m, preset alto. Ogni punto è scattato tre volte: senza nebbia, con la nebbia della 0.3.16 (lo shader di 446069c3 e 20 passi) e con quella del branch. Strumento: `godot/tests/collaudo/collaudo_nebbia_0317.gd`.

**Esito:** superato, con una nota sulla piscina vuota vista da dentro. CI di 786dcf48 verde: 0 casi da correggere nel controllo di posizionamento e nessun `ERROR: BUG,`, né in CI né nei miei lanci.

## Piscina a onde: superata dal bordo, una nota da dentro

- **Dal bordo, piena e vuota**: il fondo è appena velato rispetto a senza nebbia, quasi come il pavimento della sala alla stessa distanza. Nella 0.3.16 era una vasca viola. Fogli `enigmi_piscina_piena.jpg` (con il pavimento) e `enigmi_piscina_vuota.jpg`, righe 1-3.
- **Da dentro la piscina vuota, in piedi sul fondo**, dove si gioca l'enigma dei giocattoli, la nebbia resta fitta. Guardando verso il bordo, il fondo a 3 m quasi non si vede (`enigmi_piscina_vuota.jpg`, righe 4 e 5): molto più velato del pavimento della sala visto dal pavimento. Va meglio della 0.3.16, che lì era un muro viola, ma non è "appena più velato del pavimento".
  - Il motivo: lo strato più fitto scende verso il punto visto, del 40%. Con gli occhi dentro la piscina, il raggio parte già nello strato e lo attraversa tutto.
  - Una possibile correzione: con gli occhi sotto la quota, la quota dello strato scende con gli occhi, cioè sta sul fondo su cui si cammina.
  - Da decidere con l'utente se serve: la sua richiesta era guardando dal bordo.

## Infermeria: superata (non cambia)

Strumento: `collaudo_nebbia_0317.gd infermeria`, con le lampade che sfarfallano ferme e la nebbia senza vento, così i due scatti differiscono solo per la nebbia. Fogli `enigmi_infermeria.jpg` e `enigmi_infermeria_differenze.jpg`.

| punto | pixel diversi fra 0.3.16 e 0.3.17 (≥6/255) | dove |
|---|---|---|
| ingresso | 0,1% | niente |
| porta nord | 0,1% | niente |
| lavandino | 3% (luminosità 17,3 / 17,0) | il vano della porta |
| lettino, porta sud | 6% | solo dentro il vano della porta aperta |
| pavimento | 18% | una luce che si accende e si spegne, non la nebbia: in un altro lancio l'ordine si è invertito |

Il vano della porta è un caso della scena di prova: oltre la porta non c'è niente. Nello shader nuovo, per i pixel senza niente dietro e guardando un po' in giù, lo strato sparisce: la quota scende con `min(vista, 1e3)`. Nel gioco, oltre le porte c'è il corridoio, quindi non dovrebbe vedersi. Lo segnalo come nota tecnica: se da qualche parte si vede il vuoto, lì lo strato manca.

## Impostazioni versione 3: superate

Strumento: `prova_impostazioni_v3.gd` di ambienti-1, una fase per avvio, col `settings.cfg` vero messo da parte e poi rimesso identico (md5 uguale). L'ho provata con un file della 0.3.16 (grana accesa, glow acceso, FOV 75, lingua inglese, volumi 0,6 / 0,4 / 0,7 / 0,9), una volta con la nebbia viola accesa e una spenta: 17 controlli ok su 17 per ognuna.

- La grana si spegne.
- Glow, FOV, nebbia viola, lingua e volumi restano come salvati, anche nel file.
- La versione salvata diventa 3.
- Se il giocatore riaccende la grana, resta accesa.

## Nebbia spenta e riaccesa: superata

- `prova_nebbia_spegni_accendi.gd`, 5 su 5:
  - spenta e riaccesa due volte dalle opzioni: 0 compilazioni che bloccano (surface 0, draw 0, sottofondo 0);
  - cambiando i passi (16, 24, 32) e i valori della zona (aria, alone, polvere): ancora 0.
- `test_riscaldamento_pipeline.gd` (non è in CI): 11 su 11. Accendendo la nebbia nel tunnel: surface 0, draw 0.
