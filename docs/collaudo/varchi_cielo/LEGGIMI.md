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

## Dopo il ricontrollo del collaudo (lavoro/collaudo-ritocchi 3286a7c1)

### Gli angoli della giunzione camera delle onde - sala pompe

- Fra la camera e la sala pompe c'è un corridoio largo 2,6 m (x ±1,3): pavimento a -9,05, soffitto a -6,25, da z 25,66 a 29,5.
- La "fossa" a x ±1,5 non è parte della sala. È il vuoto fuori dai muri del corridoio, e il giocatore non ci arriva.
- I raggi del collaudo partivano da lì e uscivano dalla stessa fessura della lastra, sui due lati (x da ±1,3 a ±2,5, dal pavimento al soffitto del corridoio).
- **Chiusa** con due lastre di cemento dentro la fessura, `muro_giunzione_onde_ovest` ed `_est` in `_chiudi_fessura_onde` di `scripts/tecnici/tecnici.gd`:
  - stanno 2 cm dietro le facce dei muri (niente facce sovrapposte);
  - dalla strada non si vedono.
- Con lo strumento del collaudo (`cielo_angoli_onde.gd`, gioco vero) ora vanno nel cielo **0 raggi su 6048**; prima erano 100.

### Il portone della torre

Gli scatti sono del gioco a parti (la sala e la torre, col guscio tolto come nel gioco): `tests/collaudo/scatti_portone_torre.gd`.

- **In basso: fessura vera, chiusa.**
  - Quando la torre si carica, la sala toglie il guscio provvisorio. Sulla soglia, fra il bordo del pavimento della sala (x 20,01) e il grigliato della torre (x 20,19), resta una fessura per tutto il vano (z da -16,5 a -13,5).
  - Nello scatto si vede la striscia di cielo azzurro con le nuvole lungo il grigliato.
  - La chiude una lastra 1,5 cm sotto il pavimento, coperta ai due bordi, con la collisione: `SalaPrincipale.chiudi_soglia_torre`, chiamata in `_completa_torre`.
  - Foglio: `soglia_portone_prima_dopo.jpg`.
- **In alto: la torre è aperta in cima. Da decidere, non toccata.**
  - Dai checkpoint NEm3 e NOm12, e con un raggio dal portone, guardando in su si vede il cielo scuro sopra le bandierine.
  - Lungo quei raggi non c'è nessun triangolo di nessuna mesh, né della torre né della sala.
  - Fogli: `torre_aperta_in_cima.jpg` e `torre_aperta_in_cima_schiarito.jpg` (schiarito 6 volte: si vedono le nuvole e le bandierine in controluce).
  - Il modello è di ambienti-2; se va chiusa in cima lo decide l'utente.

### Il controllo del cielo

- Ora guarda anche la torre: caricata come nel gioco (guscio tolto), aspetta che sia costruita del tutto, poi tira i raggi dagli occhi di ognuno degli 11 checkpoint.
- Lì il cielo verso l'alto (raggi che salgono più di 0,3) si stampa a parte e non fa fallire, finché l'utente non decide.
- Le fessure sottili non contano: una crepa fra due pezzi di un modello, dove dei raggi vicini a mezzo grado ne escono meno di 3 su 8.
- Esito: 228 posti, 0 col cielo; 18 vedono la cupola di vetro (voluto); 0 fessure sottili; 5 raggi verso l'alto nella torre.
