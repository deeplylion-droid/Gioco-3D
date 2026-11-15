extends RefCounted
## Quello che il tunnel del viaggio sottomarino ricorda per tutta la partita, senza dipendenze (GameState lo azzera
## con una partita nuova senza nominare SalaSottomarino: nominarla da un autoload compila all'avvio tutta la sua catena
## di preload, vedi forme_tenute.gd).

## Vero dopo la prima volta che il giocatore respinge una carica di lei nel tunnel: finché è falso la carica ha la
## finestra lunga (SalaSottomarino.carica_finestra_prima). Chi muore alla prima carica riparte con la finestra lunga
## (scelta del coordinatore del 15 novembre: «vale finché il giocatore non l'ha respinta una prima volta»).
static var prima_respinta_fatta := false


## Una partita nuova (GameState.reset_progress).
static func azzera() -> void:
	prima_respinta_fatta = false
