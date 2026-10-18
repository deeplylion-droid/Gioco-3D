class_name EnigmaAcquari
extends Node3D
## L'enigma degli acquari nella sala principale (GDD, "L'enigma degli acquari", 18 ottobre).
## Tre acquari: uno giallo pieno, uno blu pieno e uno vuoto per il miscuglio. Con lo zaino aspiri
## dai due colorati e versi nel vuoto: l'acqua si mescola per litri (WaterMix) e si vede cambiare
## mentre lo riempi. Pieno con giallo e blu circa 2 a 1 (due zainate di giallo e una di blu) diventa
## verde e il portone della torre si apre ([member portone], PortoneTorre con SOLO_ENIGMA). Pieno
## con il colore sbagliato diventa torbido: la valvola rossa sotto, colpita col getto, lo svuota col
## gorgo e riempie di nuovo i due colorati. I colorati non si esauriscono (WaterTank.min_fill).
## I momenti:
## - al primo passaggio nella sala gli acquari non ci sono e le lampade del portone sono spente;
## - rientrando dal magazzino (tappa 7, la [member serranda] si è aperta) compaiono e le lampade si
##   accendono;
## - funzionano solo dopo la tappa 8 ([member tappa8] FINITA), quando lei se n'è andata.
## Lo stato si salva con i checkpoint; i livelli e i colori li salvano gli acquari stessi.
## I nodi figli hanno nomi fissi (vedi scenes/sala/LEGGIMI_enigma_acquari.md): i modelli veri li mette
## dentro enigma-ambiente, senza cambiarne i nomi.

signal comparso
signal risolto
signal sbagliato
signal gorgo_iniziato
signal ripristinato

enum Stato { APERTO, TORBIDO, GORGO, RISOLTO }

## Il portone della sala della torre: lo apre solo l'enigma.
@export var portone: Node
## La tappa 8 (LeiSbuca): gli acquari funzionano solo quando è FINITA.
@export var tappa8: Node
## La serranda del magazzino (tappa 7): quando è aperta sei rientrato nella sala e gli acquari ci sono.
@export var serranda: Node

@export_group("Regole")
## Parte di giallo sul totale di giallo e blu che fa il verde (2 a 1).
@export var giallo_giusto := 2.0 / 3.0
## Quanto si può sbagliare la parte di giallo: 0,08 vuol dire da 0,59 a 0,75 (3 a 1 è già torbido,
## 1 a 1 pure; due zainate e una un po' meno piene vanno bene).
@export var tolleranza := 0.08
## Quanta acqua chiara (quella che avevi già nello zaino) può esserci nel miscuglio.
@export var chiara_massima := 0.25
## Litri che servono sulla valvola per farla girare.
@export var litri_valvola := 0.6

@export_group("Tempi")
## Secondi del gorgo che svuota l'acquario del miscuglio.
@export var durata_gorgo := 4.0
## Secondi in cui i due acquari colorati tornano pieni (insieme al gorgo).
@export var durata_ricarica := 4.0

var stato := Stato.APERTO
var comparsi := false
var attivi := false

var _giallo: WaterTank
var _blu: WaterTank
var _misto: WaterTank
var _valvola_presa := 0.0
var _parti_giallo := 0.0


func _ready() -> void:
	add_to_group(&"persist")
	_giallo = $AcquarioGiallo as WaterTank
	_blu = $AcquarioBlu as WaterTank
	_misto = $AcquarioMisto as WaterTank
	_misto.suckable = false
	_giallo.accepts_water = false
	_blu.accepts_water = false
	var bersaglio := get_node_or_null(^"Valvola/Bersaglio") as WaterHitbox
	if bersaglio:
		bersaglio.water_hit.connect(_on_valvola)
	for l in find_children("*", "Light3D", true, false):
		# Le lampade del portone si accendono al buio: il blackout non le deve spegnere.
		l.set_meta(&"risveglio_ignora", true)
	_mostra(false)
	_aggiorna()


## Vero se lei è andata via (tappa 8 finita) o se non c'è la tappa 8.
func tappa8_finita() -> bool:
	if tappa8 == null or not (&"fase" in tappa8):
		return true
	var s: Script = tappa8.get_script()
	var finita = s.get_script_constant_map().get("Fase", {}).get("FINITA") if s else null
	return finita == null or tappa8.get(&"fase") == finita


func _rientrato() -> bool:
	return serranda != null and bool(serranda.get(&"aperta"))


func _physics_process(delta: float) -> void:
	_aggiorna()
	match stato:
		Stato.APERTO:
			if attivi and _misto.fill >= _misto.max_fill - 0.002:
				_valuta()
		Stato.GORGO:
			_misto.fill = maxf(_misto.fill - delta / maxf(durata_gorgo, 0.01), 0.0)
			for t in [_giallo, _blu]:
				t.fill = minf(t.fill + delta * t.max_fill / maxf(durata_ricarica, 0.01), t.max_fill)
			if _misto.fill <= 0.0 and _giallo.fill >= _giallo.max_fill and _blu.fill >= _blu.max_fill:
				_fine_gorgo()
	_valvola_presa = maxf(_valvola_presa - delta * 0.5, 0.0)


func _aggiorna() -> void:
	# Senza serranda (scene di prova) compaiono con la tappa 8.
	var c := (_rientrato() if serranda else tappa8_finita()) or stato == Stato.RISOLTO
	if c != comparsi:
		_mostra(c)
		if c:
			comparso.emit()
	attivi = comparsi and tappa8_finita()
	_giallo.suckable = attivi and stato != Stato.GORGO
	_blu.suckable = attivi and stato != Stato.GORGO
	_misto.accepts_water = attivi and stato == Stato.APERTO


func _mostra(on: bool) -> void:
	comparsi = on
	for n in get_children():
		var n3 := n as Node3D
		if n3 == null:
			continue
		# Le lampade del portone con le versioni spenta e accesa: le spente si vedono sempre ("prima
		# spente, poi accese"), si accendono solo quelle di Accese.
		var accese := n3.get_node_or_null(^"Accese") as Node3D if n3.name == &"LampadePortone" else null
		if accese:
			n3.visible = true
			n3.process_mode = Node.PROCESS_MODE_INHERIT
			accese.visible = on
			continue
		n3.visible = on
		# Nascosti non hanno collisioni né bersagli.
		n3.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for t in [_giallo, _blu, _misto]:
		for g in [&"water_catchers", &"water_sources"]:
			if on and (g != &"water_sources" or t != _misto):
				t.add_to_group(g)
			else:
				t.remove_from_group(g)


## L'acquario del miscuglio è pieno: verde o torbido.
func _valuta() -> void:
	var m := _misto.mix
	var g := WaterMix.frazione(m, WaterMix.GIALLO)
	var b := WaterMix.frazione(m, WaterMix.BLU)
	var altro := WaterMix.intensita(m) - g - b
	_parti_giallo = g / (g + b) if g + b > 0.0 else 0.0
	var giusto := g + b >= 1.0 - chiara_massima and altro < 0.02 \
		and absf(_parti_giallo - giallo_giusto) <= tolleranza
	if giusto:
		stato = Stato.RISOLTO
		_misto.set_mix(WaterMix.pura(WaterMix.VERDE))
		if portone and portone.has_method(&"apri"):
			portone.call(&"apri")
		risolto.emit()
	else:
		stato = Stato.TORBIDO
		_misto.set_mix(WaterMix.pura(WaterMix.TORBIDA))
		sbagliato.emit()


## La parte di giallo dell'ultimo miscuglio valutato (per i test).
func parte_di_giallo() -> float:
	return _parti_giallo


func _on_valvola(litri: float, _punto: Vector3, _dir: Vector3) -> void:
	if not attivi or not (stato == Stato.APERTO or stato == Stato.TORBIDO) or _misto.fill <= 0.001:
		return
	_valvola_presa += litri
	if _valvola_presa >= litri_valvola:
		_valvola_presa = 0.0
		svuota()


## La valvola: l'acquario del miscuglio si svuota col gorgo e i colorati tornano pieni.
func svuota() -> void:
	if stato == Stato.RISOLTO or stato == Stato.GORGO:
		return
	stato = Stato.GORGO
	gorgo_iniziato.emit()


func _fine_gorgo() -> void:
	_misto.fill = 0.0
	_misto.set_mix({})
	for t in [_giallo, _blu]:
		t.fill = t.max_fill
		t.set_mix(WaterMix.pura(t.fill_pigment))
	stato = Stato.APERTO
	ripristinato.emit()


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"stato": int(stato)}


func load_state(data: Dictionary) -> void:
	stato = clampi(int(data.get("stato", 0)), 0, Stato.RISOLTO) as Stato
	_valvola_presa = 0.0
	# Un gorgo a metà riparte già finito (gli acquari si caricano dopo questo nodo: lo finisce dopo).
	if stato == Stato.GORGO:
		_fine_gorgo.call_deferred()
	_aggiorna()
