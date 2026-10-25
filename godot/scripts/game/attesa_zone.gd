class_name AttesaZone
## Quando il giocatore arriva in una zona grande (le stanze della Risalita, la sala della torre, il tunnel
## sottomarino) che non ha ancora finito di caricarsi nel thread o di costruirsi a pezzi. Prima la zona si caricava e
## si costruiva tutta lì, in un fotogramma: su un PC nuovo (cache fredda) erano secondi di gioco fermo (misure del
## 25 ottobre, docs/tecnico/blocchi/misure_e_piano.md). Adesso non si blocca mai: si aspetta il thread e la
## costruzione continua a pezzi accelerati; cosa vede chi gioca intanto si decide qui, in un punto solo.
##
## Le zone dicono [method attendi] quando il giocatore è arrivato e la zona non c'è, [method pronta] quando c'è; i
## passaggi verso la zona chiedono [method passaggio_aperto].

enum Modo {
	## La zona compare appena è pronta (a pezzi, nascosta finché non c'è tutta); i passaggi restano come sono.
	PEZZI,
	## I passaggi verso la zona restano chiusi finché non è pronta (porta, portone, portello).
	PORTA,
	## Un attimo di nero con l'icona di caricamento finché la zona non è pronta.
	NERO,
}

## La scelta dell'utente (25 ottobre): la porta resta chiusa col rumore del meccanismo finché la zona non è pronta.
const MODO := Modo.PORTA

## Zona -> da quando si aspetta (ms).
static var _attese := {}
## Zona -> vero se è pronta (caricata e costruita).
static var _pronte := {}


## Il giocatore è arrivato e la zona non è pronta.
static func attendi(zona: StringName) -> void:
	if not _attese.has(zona):
		_attese[zona] = Time.get_ticks_msec()
		print("AttesaZone: %s non ancora pronta, si aspetta senza bloccare" % zona)


## La zona è pronta (o non serve più).
static func pronta(zona: StringName) -> void:
	_pronte[zona] = true
	if _attese.has(zona):
		print("AttesaZone: %s pronta dopo %d ms di attesa" % [zona, Time.get_ticks_msec() - int(_attese[zona])])
		_attese.erase(zona)


## La zona non c'è (si è tolta, o comincia a caricarsi).
static func non_pronta(zona: StringName) -> void:
	_pronte[zona] = false


static func in_attesa(zona: StringName) -> bool:
	return _attese.has(zona)


## Vero se il passaggio verso la zona si può aprire adesso.
static func passaggio_aperto(zona: StringName) -> bool:
	return MODO != Modo.PORTA or bool(_pronte.get(zona, false))


## Per i test e le ripartenze: nessuna attesa in corso.
static func azzera() -> void:
	_attese.clear()
	_pronte.clear()
