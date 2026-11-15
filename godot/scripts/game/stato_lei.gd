extends RefCounted
## Quello che la regola «l'acqua è sua» (AcquaDiLei) ricorda per tutta la partita: le zone dove la prima uscita
## dimostrativa c'è già stata. Senza dipendenze, così GameState.reset_progress() lo azzera con un preload senza nominare
## AcquaDiLei (come forme_tenute.gd).

## Chiave della zona (AcquaDiLei.chiave_zona) -> true.
static var dimostrate := {}


static func azzera() -> void:
	dimostrate.clear()
