# Collaudo del 25 ottobre (mascotte): scatole colorate del fiume e poster rovinati

Versione: lavoro/godot 4559b0c3. Scatti dal motore coi materiali veri; niente corretto.

- Scatole: `scenes/risalita/fiume.tscn` da sola (la sala intera non entra in memoria), script
  `godot/tests/collaudo/scatti_scatole_fiume.gd`: le viste dalla ciambella e a piedi (ingresso, piazza, imbarco, rami,
  approdo) e 12 scatole colorate (le più vicine all'ingresso e alla piazza e altre sparse, elenco in
  `scatole_elenco.txt`), ognuna davanti, dietro e di fianco. Conteggi: 108 unità di casse, 271 di cartone, 2495 scatole
  di cartone e 757 colorate, ognuna con le sue sei facce (`_scatola_uv`).
- Poster: `godot/proposte/poster_rovinati/scatti_poster.gd` (interni e infermeria); la sala è stata fermata a 12,5 GB,
  quindi il manifesto è guardato da solo su un muro a filo (`godot/tests/collaudo/scatti_manifesto.gd`).
