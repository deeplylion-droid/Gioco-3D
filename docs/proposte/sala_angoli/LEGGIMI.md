# Sala principale: le due pile negli angoli dell'entrata

Punto 8 della prova della v0.3.2: "riempire i due angoli dalla parte della prima entrata nel salone centrale... due pile che toccano quasi il soffitto, attaccate agli angoli, una di palloni da spiaggia gonfi e sgonfi, l'altra di scatoloni di diversi colori". Solo proposta: nel gioco non è cambiato niente.

- **Scatoloni**: una catasta a gradini contro i due muri, alta circa 10 m (il soffitto è a 11,5 m). Ci sono cinque tipi di scatoloni di colori diversi, un po' rovinati e umidi, e qualcuno caduto alla base. Ogni scatolone poggia su quello sotto: niente compenetrazioni.
- **Palloni**: una pila di palloni grandi gonfi alta circa 10 m, sistemata con la simulazione fisica dentro una rete da carico fissata ai due muri (da soli a quell'altezza non starebbero su). In cima e alla base ci sono quelli sgonfi e mezzi sgonfi.
- Le pile si allargano al massimo 3,4 m lungo ciascun muro. Nell'angolo sud-ovest la serranda della risalita resta libera. Collisione semplice: una scatola per pila.

L'utente non ha detto quale pila va in quale angolo, quindi ci sono due disposizioni:
- `disposizione_1/`: palloni a sud-ovest (a sinistra entrando), scatoloni a sud-est (a destra);
- `disposizione_2/`: al contrario.

Scatti dal motore, con la luce di oggi della sala:
1. `1_entrata_verso_ovest`, `2_entrata_verso_est`: dall'entrata, verso i due angoli;
2. `3_meta_sala`: da metà sala verso l'entrata, con tutte e due le pile;
3. `4_vicino_ovest`, `5_vicino_est`: da vicino.

Tecnica: modelli Meshy in `assets_src/sala_angoli/` (`genera_angoli.py`), pile fatte da `tools/blender/sala_angoli.py` in `godot/assets/ambiente/proposte_angoli/`. Scene di prova: `godot/tests/scene/sala_angoli_1.tscn` e `_2.tscn`.
