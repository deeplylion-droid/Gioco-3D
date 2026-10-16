# Splash Lagoon (titolo provvisorio)

Gioco horror in prima persona, del genere "mascot horror": ti svegli a bordo di una nave da crociera per famiglie degli anni '90, abbandonata, e nell'acquapark coperto ti aspetta la sua mascotte.

Lo facciamo con Godot 4, Blender e Meshy.

- Decisioni di progetto: [docs/GDD.md](docs/GDD.md)
- Immagini concept approvate: [docs/concept/](docs/concept/)
- Note per chi ci lavora con Claude: [CLAUDE.md](CLAUDE.md)

## Importare il progetto Godot

Dopo un clone o un merge che porta GLB nuovi: `bash tools/godot_importa.sh`. Fa come la CI: importa,
mette in VRAM compressa le texture estratte dai GLB (`tools/godot_vram_textures.py`) e reimporta.
Senza il passaggio in mezzo le texture estratte restano non compresse e il gioco usa gigabyte di
memoria video in più.
