# Ricontrollo dei tubi dell'inseguimento (30 ottobre)

Squadra collaudo. `lavoro/torre-0317` **55cd1279** (codice in fef550f7, CI 41043075423), confrontato con la base **446069c3**. Le due correzioni chieste dall'utente: la curva di ins_A_tubo_0 rifatta liscia e l'acqua delle vasche non più trasparente da sotto. In più: la fascia del sostegno che entrava di 4 cm in scolo_0 è stata spostata, e le tre vasche dei bivi e il bacino hanno l'acqua 10 cm più bassa (88 cm le vasche, 85 il bacino).

Giocatore vero, col renderer vero: entra nel tubo spingendo avanti e scivola fino in fondo, senza teletrasporti. Ho percorso i 7 tubi, compresi i tre scoli delle paratie sbagliate. **0 righe "ERROR: BUG," in tutti i log.**

## Difetti

Nessuno.

## Che cosa va

| Prova | Esito |
|---|---|
| ins_A_tubo_0 (`fogli/tubo_0_prima.jpg`, `tubo_0_dopo.jpg`) | la curva è liscia: prima, all'arrivo nella vasca 1, il bordo del tubo tagliava la vista con una fascia nera (scatti 014-015), ora non c'è più. Si arriva in fondo in 2,9 s invece di 3,5 s, e la camera resta al più 0,74 m dalla linea del centro (il raggio è 0,78 m). |
| Gli altri tubi (`fogli/discesa_*.jpg`) | tubo_1, tubo_2 e tubo_3 come prima: in fondo in 3,3, 3,8 e 10,0 s, senza fermarsi. Gli scoli 0, 1 e 2 come prima. |
| Arrivi in piedi e accovacciati (`fogli/arrivi_*.jpg`) | prima, accovacciati, gli occhi finivano sotto il pelo dell'acqua nelle tre vasche e nel bacino; ora restano sopra: al più vicino sono 5,1-5,6 cm sopra nelle vasche e 7,1 cm nel bacino (`sonda_occhi_tubi`: nessun occhio sotto il pelo nei tubi giusti). |
| Fascia del sostegno in scolo_0 (`fogli/scolo_0_prima_dopo.jpg`) | dagli occhi la discesa è uguale e non si vede niente che entri nel tubo. |
| Le vasche più basse non cambiano altro | bersagli verdi negli scatti come prima; `test_inseguimento` 43/43 (aspirare l'acqua, lei che passa), `test_effetti_inseguimento` 13/13, `test_inseguimento_suoni` 17/17, `test_morbidezza_inseguimento` 64/64, `test_torre` 94/94, `test_fine_titolo` 13/13. La bava rosa sul bordo della vasca 1 è uguale a prima (`arrivi_ins_A_tubo_0.jpg`, a sinistra). |
| Controllo di posizionamento | 0 casi da correggere, 0 nuovi (63 già noti). |

## Cose da sapere (non difetti del gioco)

- **Scoli 1 e 2**: la mia misura non arriva alla fine della linea, perché il fondo è un pozzo buio senza luci. Prima e dopo sono uguali.
- **scolo_0 accovacciato**: lì lei prende il giocatore (è una paratia sbagliata), quindi gli scatti sono quelli della presa, uguali a prima.
- **tubo_2, accovacciato, a sinistra**: sul muro viola si vede un'ombra scura con testa e spalle. Credo sia l'ombra del giocatore, perché lei nello scatto era nascosta. Prima non si poteva vedere, perché accovacciati gli occhi erano sott'acqua.
- **Posizionamento**: 12 eccezioni dell'elenco non si trovano più. Sono voci vecchie che si possono togliere; non è un caso da correggere.

## Come

`godot/tests/collaudo/tubi_giro.gd <cartella> <tubo>` (nuovo): un tubo dagli occhi, con uno scatto ogni 0,25 s e la misura della camera contro la parete. All'arrivo, in piedi e accovacciato, guarda avanti, a sinistra, a destra, verso la bocca del tubo e in alto. Poi `sonda_occhi_tubi.gd` di ambienti-2. Le righe dei giri e dei test sono in `log/`.
