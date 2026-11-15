extends RefCounted
## Quello che il tunnel del viaggio sottomarino ricorda per tutta la partita, senza dipendenze (GameState lo azzera
## con una partita nuova senza nominare SalaSottomarino: nominarla da un autoload compila all'avvio tutta la sua catena
## di preload, vedi forme_tenute.gd).

## Vero dopo la prima carica di lei nel tunnel (SalaSottomarino.carica_finestra_prima: la prima della partita ha la
## finestra più lunga).
static var prima_carica_fatta := false


## Una partita nuova (GameState.reset_progress).
static func azzera() -> void:
	prima_carica_fatta = false
