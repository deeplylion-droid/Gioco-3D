# Inizio con il mostro-squalo: controllo (21-22 ottobre)

Dal gioco vero (sala principale con gli interni, preset Alto, 1280x720, 30 fps, Vulkan software),
dagli occhi del giocatore: `godot/proposte/mascotte/video_risveglio.gd`. Solo per il controllo del
coordinatore. Il video è senza audio: su questa macchina Godot non ha un driver audio e il Movie Maker
registra silenzio. I suoni ci sono e partono (lo controlla `test_interni`).

| File | Cosa |
| --- | --- |
| `1_bocca_3.3s.jpg` | la bocca spalancata addosso alla camera, gli artigli ai lati |
| `2_richiamo_5.9s.jpg` | al verso di Jilly alza la testa e si gira verso la porta |
| `3_esita_7.6s.jpg` | girato verso la porta, si volta a guardarti con il busto e il muso |
| `4_corsa_8.8s.jpg` | corre verso la porta tagliafuoco, in fondo al corridoio |
| `5_giro_testa_5.5s.jpg` | il momento in cui la testa scatta verso il richiamo (lì prima si vedeva il muro attraverso la bocca) |
| `6_corsa_9.4s.jpg` | quasi alla porta, ancora leggibile nel tratto buio |
| `risveglio_squalo_senza_audio.mp4` | la scena intera, 13,6 s |

## Correzioni del 22 ottobre (richieste del coordinatore)

- **Mascella e angoli della bocca**: il peso della mascella attorno alla bocca è una funzione armonica
  calcolata esatta (prima restava una piega netta sotto il mento) e le labbra verso gli angoli non sono più
  fisse: il taglio si apre piano verso gli angoli, niente linguette tirate tra le due labbra. Nel rig la
  parte della pelle che segue la testa sfuma liscia verso il collo (prima sotto il mento c'era un gradino
  quando la testa girava).
- **Bocca chiusa a tenuta**: la gengiva cuce il bordo del taglio con l'ingresso della sacca a cerniera, in
  due metà (sopra e sotto) più gli angoli: nessun lato scoperto (prima agli angoli si vedeva il corridoio
  attraverso la bocca, le "lucine rosse" tra i denti). Carne della sacca liscia, una sola fila di denti in
  più (con due, da vicino sembravano lastre).
- **Scatto della testa al richiamo**: da 0,22 a circa mezzo secondo (anche lo sguardo indietro
  nell'esitazione): più svelto la mesh si strappava tra un fotogramma e l'altro.
- **Corsa**: una luce morbida che illumina solo lui (livello di render suo), il corridoio resta com'è.
