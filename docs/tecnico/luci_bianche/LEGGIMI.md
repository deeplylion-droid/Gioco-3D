# Luci bianche al 40%

Provate come variante nella v0.3.9, con il tasto F7. Scelta dell'utente del 23 ottobre, giocando la v0.3.11: "le luci a
40% vanno bene quindi via la scelta e restano così". Ora sono la luce normale del gioco: tutte le luci bianche al 40%,
le colorate (rosse, verdi, rosa e viola di Jilly, blu) com'erano. Niente tasto F7 e niente scritta "Luci 40%/100%".
La torcia non c'è più (stessa decisione).

- `godot/scripts/game/luci_bianche.gd` (autoload `LuciBianche`, classe `VarianteLuci`). Il fattore viene
  dall'impostazione di progetto `gioco/luci_bianche` (0,4).
- Gli strumenti che vogliono le luci piene (confronti, misure) chiamano `LuciBianche.imposta(1.0)`: con il fattore 1
  non fa niente e non si collega al disegno.
- Il test è `godot/tests/test_luci_bianche.gd` ("la luce normale" in CI).
- Cosa resta sempre com'era (riscontro del coordinatore): Jilly e le creature (la Medusa in tutti i suoi posti, Lei
  nell'inseguimento, bambini, agnello, squalo, statue), gli oggetti di gioco (Interactable, Polaroid, keycard, lettori,
  pulsanti, schermi) e le insegne con un colore nel nome (il neon giallo, rosa, azzurro).
- Cosa scende anche se non è una lampada: il disegno sul vetro dell'acquario (`disegno_carta`; l'utente: "abbassalo
  pure"). Le lampade del portone dell'enigma acquari scendono (si leggono lo stesso accese o spente).
- Cosa scende: le Light3D bianche e bianco-calde (saturazione al più 0,30; oppure tinta fra 0,045 e 0,17, cioè fra
  arancio e giallo, e saturazione al più 0,76: le lampade da lavoro, le "luci calde", le lampadine); l'emissione dei
  materiali bianchi delle lampade vere (BaseMaterial3D con l'emissione accesa, almeno 0,3, dello stesso colore, su
  una mesh con un nome da lampada - lampada, neon, plafoniera, globo, lampadina, faro, luce... - o piccola, al più 2,5
  m, vicino a una Light3D; i materiali sono condivisi, uno per materiale); l'energia dei VoxelGI cotti (la sala, gli interni, i tecnici).
- Come: il fattore si mette solo per il disegno. Prima di ogni fotogramma (RenderingServer.frame_pre_draw) energia =
  base × fattore, dopo il disegno (frame_post_draw) torna la base. Gli script che scrivono o leggono light_energy ed
  emission_energy_multiplier (sfarfallio, flash di luci_risveglio, bava_rosa, neon, look_sala, il fiume, il menu)
  vedono sempre i valori pieni e il fattore resta su tutto quello che si vede. Il colore si guarda a ogni fotogramma:
  una luce che diventa rossa (blackout) smette di scendere.
- Costo misurato (questa macchina lenta, a scene caricate): 0,41 ms per fotogramma con la sala intera (99 luci
  bianche, 88 materiali), 0,25 ms la torre con l'inseguimento.
- Test: `godot/tests/test_luci_bianche.gd` (nella CI). Elenco per zona: `elenco.md` qui accanto, scritto da
  `godot/proposte/mascotte/elenco_luci_bianche.gd`.
