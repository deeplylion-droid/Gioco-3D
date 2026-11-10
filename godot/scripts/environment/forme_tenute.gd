extends RefCounted
## Le forme ferme del tunnel tenute fra le ripartenze dal tunnel (FormeTunnel.prepara): [impronta, forme], o vuoto.
## A parte da FormeTunnel e senza dipendenze, perché GameState (un autoload) le lascia con una partita nuova: un
## riferimento a FormeTunnel dall'autoload compilava con lui SalaSottomarino e il suo preload di bambino_agnello.tscn
## già all'avvio, coi materiali del bambino caricati prima del tempo («Parameter "material" is null» del renderer finto
## nei test dei bambini e in test_partenze_prova; ricontrollo di mascotte del 10 novembre).

static var dati: Array = []


static func lascia() -> void:
	dati = []
