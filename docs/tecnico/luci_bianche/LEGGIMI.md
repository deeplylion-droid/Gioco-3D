# Luci bianche al 40% (variante di prova della v0.3.9)

Richiesta dell'utente: una variante con tutte le luci bianche al 40% e le colorate (rosse, verdi, rosa e viola di
Jilly, blu) com'erano. Scelta dell'utente: un interruttore nella stessa build (F7), niente build a parte; la torcia
non si tocca.

- `godot/scripts/game/luci_bianche.gd` (autoload `LuciBianche`, classe `VarianteLuci`). Con il fattore 1 (normale) non
  fa niente e non si collega al disegno: la build normale resta identica.
- F7 passa dal 100% al 40% e indietro; per 2 secondi in alto a destra c'è scritto "Luci 40%" o "Luci 100%" (scritta di
  prova). F1, F2 e F3 sono già usati (scene di prova, contatore FPS); F7 no.
- Partire già al 40%: l'opzione d'avvio `-- --luci-40`, o l'impostazione di progetto `gioco/luci_bianche` (0,4 con la
  feature `luci40`). Non si esportano.
- Cosa resta sempre com'era (riscontro del coordinatore): Jilly e le creature (la Medusa in tutti i suoi posti, Lei
  nell'inseguimento, bambini, agnello, squalo, statue), gli oggetti di gioco (Interactable, Polaroid, keycard, lettori,
  pulsanti, schermi, il disegno dell'indizio) e le insegne con un colore nel nome (il neon giallo, rosa, azzurro).
- Cosa scende: le Light3D bianche e bianco-calde (saturazione al più 0,30; oppure tinta fra 0,045 e 0,17, cioè fra
  arancio e giallo, e saturazione al più 0,76: le lampade da lavoro, le "luci calde", le lampadine); l'emissione dei
  materiali bianchi delle lampade vere (BaseMaterial3D con l'emissione accesa, almeno 0,3, dello stesso colore, su
  una mesh con un nome da lampada - lampada, neon, plafoniera, globo, lampadina, faro, luce... - o piccola, al più 2,5
  m, vicino a una Light3D; i materiali sono condivisi, uno per materiale); l'energia dei VoxelGI cotti (la sala, gli interni, i tecnici). La
  torcia mai.
- Come: il fattore si mette solo per il disegno. Prima di ogni fotogramma (RenderingServer.frame_pre_draw) energia =
  base × fattore, dopo il disegno (frame_post_draw) torna la base. Gli script che scrivono o leggono light_energy ed
  emission_energy_multiplier (sfarfallio, flash di luci_risveglio, bava_rosa, neon, look_sala, il fiume, il menu)
  vedono sempre i valori pieni e il fattore resta su tutto quello che si vede. Il colore si guarda a ogni fotogramma:
  una luce che diventa rossa (blackout) smette di scendere.
- Costo misurato (questa macchina lenta, a scene caricate): 0,41 ms per fotogramma con la sala intera (99 luci
  bianche, 88 materiali), 0,25 ms la torre con l'inseguimento.
- Test: `godot/tests/test_luci_bianche.gd` (nella CI). Elenco per zona: `elenco.md` qui accanto, scritto da
  `godot/proposte/mascotte/elenco_luci_bianche.gd`.
