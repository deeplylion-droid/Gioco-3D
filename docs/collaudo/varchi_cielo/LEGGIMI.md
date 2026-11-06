# Il cielo dai varchi della strada (6 novembre, ambienti-1)

Segnalazione dell'utente sulla 0.3.21, nel foglio `docs/collaudo/ritocchi_ambienti1/scala_strisce_dopo.jpg`: "che è quella texture grigia sulla parete? sembra un glitch".

## La porta di C3 in cima alla scala di servizio

- **Cos'è**: il rettangolo grigio-azzurro in fondo al corridoio, con le nuvole in alto e le righe in basso, è il **cielo** dell'ambiente della sala. Si vede perché quegli scatti (`tests/collaudo/pozze_giro.gd`) usano la scena di prova `tests/scene/risalita_prova.tscn`, che ha solo la Risalita: oltre la porta di C3 non c'è niente.
- **Nel gioco vero** oltre la porta c'è il corridoio C3 del raccordo (Tecnici/Ambienti/Raccordo), al buio del blackout:
  - `tests/collaudo/sonda_cielo.gd`, sala vera con la Risalita caricata: da ogni metro fra la cima della scala e la porta, 0 raggi su 36 escono; colpiscono i muri c3 del raccordo, RACCORDO_struttura e i tubi G_tubi_c3;
  - `porta_c3_prova_e_gioco.jpg` (`tests/collaudo/scatti_porta_c3.gd`), dalle stesse pose: a sinistra la scena di prova col cielo, al centro il gioco vero (corridoio C3 e Risalita, stessa luce), a destra lo stesso schiarito 8 volte solo per capire. Nel gioco vero la porta dà sul buio del corridoio.

## Il controllo del cielo su tutta la strada

`tests/controllo_cielo.gd`, nella CI dopo il controllo dei varchi. Nel gioco vero con tutte le porte aperte, lungo i tratti di `controllo_varchi.gd` (interni, sala, camera delle onde, sala pompe, risalita, infermeria, stanza delle pozze, scala di servizio, raccordo, portone della torre) più il capannone del fiume e l'infermeria, ogni metro gli occhi a 1,6 m tirano 240 raggi in tutte le direzioni. Un raggio che non incontra niente entro 150 m (collisioni e mesh vere) vede il cielo, ed è un caso da correggere. Il cielo della tempesta visto dalla cupola di vetro della sala è voluto e si conta a parte.

Il primo giro ha trovato un solo buco vero:

- **la fessura fra la camera delle onde e la sala pompe**: i due modelli lasciavano nel pavimento una fessura di 31 cm (z da 25,35 a 25,66) per tutta la larghezza; guardando in basso si vedeva il cielo. La chiude una lastra dello stesso cemento, 1 mm sotto il pavimento, con la collisione (`_chiudi_fessura_onde` in `scripts/tecnici/tecnici.gd`). Foglio: `fessura_onde_prima_dopo.jpg` (`tests/collaudo/scatti_fessura_onde.gd`), stesse pose, schiarito 5 volte.

Dopo la correzione: 217 posti controllati, 0 col cielo; 18 vedono il cielo dalla cupola di vetro (voluto).

Torre, condotte e tunnel sono scene a parte, caricate dopo: il controllo non le copre ancora.
