extends RefCounted
## Quello che la storia della build 0.5.0 ricorda per tutta la partita (come stato_lei.gd per la regola di lei): le cose
## che succedono una volta sola. Senza dipendenze, così GameState.reset_progress() lo azzera con un preload.

## L'agnellino ha già riempito di nuovo un colore nella stanza delle pozze (AgnellinoPozze).
static var agnellino_pozze := false


static func azzera() -> void:
	agnellino_pozze = false
