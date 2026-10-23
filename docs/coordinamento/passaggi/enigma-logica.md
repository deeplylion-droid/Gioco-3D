# Passaggio di enigma-logica

**Branch** `lavoro/enigma-logica`, partito da main e8987d7. L'ultimo hash del lavoro è 8b08b31, a cui si aggiunge questo file. Il branch contiene tutto: la logica degli acquari, la scelta B sull'acqua chiara, il fiume, l'infermeria, il lettore, i test e la nota approvata (`docs/proposte/fiume_infermeria/nota_logica.md`). L'utente ha scelto l'aspetto: fiume A (giungla finta), infermeria B (per bambini), lettore 1, keycard 1.

## Classi e scene
- **Colore dell'acqua**: `scripts/water/water_mix.gd` (WaterMix), un miscuglio `{pigmento: frazione}` con chiavi String, perché si salva in JSON. WaterTank ha `mix`, `fill_pigment`, `accepts_water`, `min_fill` e il segnale `mix_changed`. WaterPack ha `water_mix`, `scarta_acqua_chiara()` (scelta B: aspirando un colore butta via l'acqua chiara) e il segnale `water_mix_changed`. La finestrella della lancia e GettoPotente (getto, colonna, schizzi, nebbia) prendono la tinta.
- **Acquari**: `scripts/game/enigma_acquari.gd` (EnigmaAcquari) e `scenes/sala/enigma_acquari.tscn`, con i nodi a nomi fissi descritti nel LEGGIMI accanto. Il successo è giallo/(giallo+blu) = 0,667 ± 0,08, con al massimo il 25% di acqua chiara. Il portone della torre è in modalità `SOLO_ENIGMA` (PortoneTorre). Gli acquari compaiono quando `SerrandaMagazzino.aperta` e funzionano dopo LeiSbuca FINITA. LampadePortone ha i figli `Spente` (sempre visibili) e `Accese`.
- **Fiume**, in `scripts/mechanisms/`: FiumeLento (la ciambella, la spinta col getto da 1,2 a 3,2 m/s, la ricarica; parte solo dopo le pompe), TrattoFiume (un Path3D: `prossimo`, `paratia`, `ramo_sbagliato`, `uscita`), ParatiaFiume (il bersaglio risponde solo sul tratto che porta al bivio) e CartelloUscita (acceso se il ramo non è sbagliato). Il prototipo è `proposte/fiume/fiume_prototipo.tscn`.
- **Infermeria**: Negatoscopio (con `alimentazione` = WaterButton e la radiografia appoggiata con E), CassettoSchedario (`adesivo`, `contenuto`) e CassaforteRotelle (codice 4-1-7, `contenuto`). Il prototipo è `proposte/infermeria/infermeria_prototipo.tscn`.
- **Lettore**: LettoreTessera (rosso/verde, suoni `suono_ok`/`suono_no`). In SerrandaMagazzino c'è il campo `lettore`: se è vuoto si comporta come prima.

## Test (tutti in `.github/workflows/build.yml`)
`test_acquari` (62 controlli), `test_fiume` (35: fiume, cartelli, keycard, lettore, serranda), `test_infermeria` (22). `test_tappa8` controlla che il portone non si apra da solo. Prima di ogni push vanno fatte girare tutte le suite.

## Come si innesta nella strada di risalita (approvato)
Sala pompe → raccordo (il corridoio con le scale verso il magazzino va chiuso, con una grata o un crollo) → porta di servizio → imbarco del fiume → anello con 3 bivi → approdo con scaletta → zona del personale → infermeria → scala di servizio → magazzino → serranda con il lettore. Checkpoint all'imbarco, all'approdo, dopo ogni passo dell'infermeria e alla serranda. **Ancora da fare in sala_principale.tscn:**
- mettere il lettore in `Tecnici/Logica` e collegarlo a `SerrandaMagazzino.lettore`;
- mettere la keycard (Pickup, `item_id = keycard`) nella `CassaforteRotelle.contenuto`;
- costruire le stanze vere con le classi qui sopra.

## Trappole note
- Le classi nuove con `class_name` si registrano solo dopo `godot --headless --path godot --import`: senza, gli script danno "Could not find type".
- Nelle lambda di GDScript le variabili locali sono copie: nei test lo stato va messo in un dizionario.
- `test_audio` fallisce se uno script chiede un suono che non è nel catalogo: il lettore usa per ora `pulsante_premuto` e `maniglione_bloccato`.
- La lancia è bassa: il bordo dell'acquario del miscuglio deve stare sotto circa 0,8 m, altrimenti il getto non ci entra.
- Le tinte di giallo, blu e dei loro miscugli vengono da `WaterMix.SFUMATURA`, non da `COLORI`. I colori li decide enigma-ambiente con l'utente.
- Su llvmpipe la sala intera con il rendering si blocca nel caricamento, anche con `scatti_sala.gd`, e il Movie Maker si blocca. Per i video: `tests/video_acquari.gd`, con una scena piccola e un JPG per fotogramma, poi ffmpeg. Un Xvfb rimasto aperto tiene il `render.lock`: va chiuso.
- L'addon dell'acqua regge al massimo 12 masse d'acqua (sono 10 con i tre acquari).

## Lavori aperti
- Mettere le stanze vere nella strada di risalita, con l'aspetto scelto, e collegare lettore e keycard nella sala.
- Nella scena vera, rami sbagliati del fiume più corti, circa 15 s (nel prototipo sono 26 s).
- Il gorgo vero degli acquari (agganciato a `gorgo_iniziato`), la Polaroid vera della pecora nella cassaforte, i suoni dedicati del lettore.
