class_name EnigmaPozze
extends Node3D
## La stanza delle pozze colorate (GDD, "La stanza delle pozze colorate", idea e scelte dell'utente del 31 ottobre),
## dopo l'infermeria: 25 pozze quadrate in 5x5, attaccate, piene d'acqua di 5 colori, 5 pozze per colore.
## - Le pozze dello stesso colore sono collegate sotto il pavimento: aspirando con lo zaino da una pozza (almeno
##   [member litri_per_svuotare] litri) si svuotano col gorgo tutte quelle del suo colore (scelta A). Il serbatoio prende
##   il colore aspirato e quello di prima si butta da solo (WaterPack, meta "scarta_altri_colori").
## - Al terzo colore tolto si controlla (scelta A): se sono i tre disegnati a pastello sul cartello accanto alla porta
##   nord dell'infermeria ([constant GIUSTI]) la porta stagna si apre e la sua lampada passa da rossa a verde; se no si
##   accende il lampeggiante rosso, si sente lo scarico e in pochi secondi tutte le pozze si riempiono di nuovo. Non si
##   muore. Un quarto colore non si comincia finché ce ne sono tre tolti o che si stanno togliendo.
## La griglia: ogni riga e ogni colonna ha tutti e 5 i colori e due pozze dello stesso colore non si toccano, nemmeno
## in diagonale (colore = (colonna + 2 riga) mod 5); ogni colore ha pozze sul bordo, a portata dalla passerella.
## Le pozze sono WaterTank senza muri (le vasche, la passerella, la porta e le luci le fa la stanza, ambienti-1), con
## l'acqua vera dell'addon (WaterTankLink) nello stile del loro colore; il gorgo, lo scarico e il riempimento sono
## quelli delle vasche (uno scarico per colore, un carico per tutte). Lo stato si salva coi checkpoint (gruppo
## "persist"); i livelli e i colori li salvano le pozze stesse.
## L'origine è al centro della griglia, alla quota del bordo delle pozze (il piano della passerella): le colonne vanno
## lungo X, le righe lungo Z.
## Nodi della stanza che usa, se ci sono (cercati fra i fratelli, o dati qui): [member porta] (apri(subito)),
## [member lampeggiante] (le sue luci si accendono e lampeggiano) e [member checkpoint_risolto].

signal colore_cominciato(colore: String)
signal colore_tolto(colore: String)
signal risolto
signal sbagliato
signal ripristinato

enum Stato { APERTO, SBAGLIATO, RISOLTO }

const COLORI: Array[String] = [WaterMix.ARANCIONE, WaterMix.ROSA, WaterMix.VIOLA, WaterMix.TURCHESE, WaterMix.BIANCO_LATTE]
## I tre colori da togliere, quelli del cartello (scelti dalla squadra il 31 ottobre: i tre più diversi fra loro col
## pastello sul bianco del cartello; il bianco latte sul foglio bianco non si vedrebbe). Restano il rosa e il bianco latte.
const GIUSTI: Array[String] = [WaterMix.TURCHESE, WaterMix.VIOLA, WaterMix.ARANCIONE]
const STILI := {
	WaterMix.ARANCIONE: preload("res://assets/pozze_colorate/acqua_arancione.tres"),
	WaterMix.ROSA: preload("res://assets/pozze_colorate/acqua_rosa.tres"),
	WaterMix.VIOLA: preload("res://assets/pozze_colorate/acqua_viola.tres"),
	WaterMix.TURCHESE: preload("res://assets/pozze_colorate/acqua_turchese.tres"),
	WaterMix.BIANCO_LATTE: preload("res://assets/pozze_colorate/acqua_bianco_latte.tres"),
}
const ACQUA := preload("res://addons/acqua/scenes/acqua_per_vasca.tscn")
const N := 5

## La porta stagna d'uscita (apri(subito := false)); vuoto = la cerca fra i fratelli col nome PortaStagna.
@export var porta: Node
## Il lampeggiante rosso dello sbaglio; vuoto = lo cerca fra i fratelli col nome LampeggianteErrore.
@export var lampeggiante: Node3D
## Il checkpoint a enigma risolto (monitoring spento: lo raggiunge questo nodo); vuoto = lo cerca col nome
## CheckpointRisolto.
@export var checkpoint_risolto: Checkpoint

@export_group("Griglia")
## Il lato interno di una pozza (m).
@export var lato := 1.2
## Da centro a centro di due pozze vicine (m): il lato più il bordino di piastrelle.
@export var passo := 1.3
## Profondità interna delle pozze (m).
@export var profondita := 0.75
## Fin dove arriva l'acqua (frazione della profondità): 0,93 lascia circa 5 cm di bordo asciutto.
@export_range(0.5, 1.0) var pieno := 0.93
## Litri "di gioco" di una pozza piena fino al bordo (lo zaino ne tiene 20).
@export var litri_pozza := 80.0

@export_group("Regole e tempi")
## Litri da aspirare da una pozza perché si svuotino tutte quelle del suo colore.
@export var litri_per_svuotare := 2.0
## Secondi del gorgo che svuota le pozze di un colore.
@export var durata_gorgo := 3.5
## Secondi del lampeggiante, allo sbaglio, prima che le pozze comincino a riempirsi.
@export var attesa_ricarica := 1.5
## Secondi in cui le pozze vuote si riempiono di nuovo.
@export var durata_ricarica := 4.0
## Mezzo periodo del lampeggiante (s).
@export var lampeggio := 0.35

var stato := Stato.APERTO
## I colori tolti (le loro pozze sono vuote), nell'ordine.
var tolti: Array[String] = []
## I colori che si stanno svuotando adesso.
var svuotando: Array[String] = []

var _pozze: Array[WaterTank] = []
var _per_colore := {}
var _scarichi := {}
var _carico: PowerSource
var _aspirato := {}
var _t_errore := 0.0
## Vero fra load_state e la fine del caricamento (le pozze si caricano dopo): intanto non si controlla niente.
var _caricando := false
var _luci_errore: Array[Light3D] = []
var _accesi_errore: Array[Node3D] = []


## Il colore della pozza nella colonna [param colonna] e nella riga [param riga] (0..4).
static func colore_di(colonna: int, riga: int) -> String:
	return COLORI[(colonna + 2 * riga) % N]


func _ready() -> void:
	add_to_group(&"persist")
	if porta == null:
		porta = _cerca(&"PortaStagna")
	if lampeggiante == null:
		lampeggiante = _cerca(&"LampeggianteErrore") as Node3D
	if checkpoint_risolto == null:
		checkpoint_risolto = _cerca(&"CheckpointRisolto") as Checkpoint
	if checkpoint_risolto:
		checkpoint_risolto.monitoring = false
	if lampeggiante:
		for l in lampeggiante.find_children("*", "Light3D", true, false):
			_luci_errore.append(l as Light3D)
			# acceso solo nello sbaglio: il blackout non lo deve toccare
			l.set_meta(&"risveglio_ignora", true)
		var acceso := lampeggiante.get_node_or_null(^"Acceso") as Node3D
		if acceso:
			_accesi_errore.append(acceso)
	_carico = PowerSource.new()
	_carico.name = "Carico"
	add_child(_carico)
	for c in COLORI:
		var s := PowerSource.new()
		s.name = "Scarico_" + c
		add_child(s)
		_scarichi[c] = s
		_per_colore[c] = []
		_aspirato[c] = 0.0
	for riga in N:
		for colonna in N:
			_pozza(colonna, riga)
	_lampeggiante(false)


func _cerca(nome: StringName) -> Node:
	var p := get_parent()
	if p == null:
		return null
	var n := p.get_node_or_null(NodePath(String(nome)))
	return n if n else p.find_child(String(nome), true, false)


func _pozza(colonna: int, riga: int) -> void:
	var c := colore_di(colonna, riga)
	var t := WaterTank.new()
	t.name = "Pozza_%d_%d" % [colonna, riga]
	t.build_walls = false
	t.inner_size = Vector3(lato, profondita, lato)
	t.position = Vector3((colonna - 2) * passo, -profondita, (riga - 2) * passo)
	t.max_fill = pieno
	t.capacity_liters = litri_pozza
	t.fill_pigment = c
	t.accepts_water = false
	t.wave_amplitude = 0.01
	t.drain_time = durata_gorgo
	t.fill_time = durata_ricarica
	var scarico: Array[PowerSource] = [_scarichi[c] as PowerSource]
	t.drain_sources = scarico
	var carico: Array[PowerSource] = [_carico]
	t.fill_sources = carico
	t.fill = pieno
	t.set_meta(&"scarta_altri_colori", true)
	t.set_meta(&"colore_pozza", c)
	add_child(t)
	t.set_mix(WaterMix.pura(c))
	var acqua := ACQUA.instantiate()
	acqua.name = "Acqua"
	acqua.set(&"tank", t)
	acqua.set(&"capture_env_cubemap", false)
	# 25 pozze piccole: niente simulazione delle increspature (una per pozza costerebbe troppo)
	acqua.set(&"simulate_ripples", false)
	acqua.set(&"style", STILI[c])
	t.add_child(acqua)
	# fuori dalla tabella delle masse d'acqua dell'addon (WaterManager, al più 12: caustiche, linea bagnata, nebbia
	# sott'acqua degli altri materiali): 25 pozze ne prenderebbero il posto alle vasche e ai canali del resto del gioco.
	# Il pelo resta quello vero (riflessi, gorgo); sui fondi delle pozze non ci sono le caustiche.
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm and wm.has_method(&"unregister_body"):
		wm.call(&"unregister_body", acqua)
	_pozze.append(t)
	(_per_colore[c] as Array).append(t)


func _physics_process(delta: float) -> void:
	if _caricando:
		return
	match stato:
		Stato.APERTO:
			_controlla_aspirate()
			for c in svuotando.duplicate():
				if _vuote(c):
					_fine_svuotamento(c)
		Stato.SBAGLIATO:
			_t_errore += delta
			_lampeggiante(fmod(_t_errore, lampeggio * 2.0) < lampeggio)
			if _t_errore >= attesa_ricarica:
				_carico.powered = true
				if _piene():
					_fine_ricarica()
	_aggiorna_aspirabili()


## Una pozza aspirata: comincia a svuotarsi tutto il suo colore.
func _controlla_aspirate() -> void:
	for c in COLORI:
		if c in tolti or c in svuotando:
			continue
		var tolta := 0.0
		for t: WaterTank in _per_colore[c]:
			tolta += maxf(pieno - t.fill, 0.0) * litri_pozza
		if tolta >= litri_per_svuotare - 0.0001:
			_comincia(c)


func _comincia(c: String) -> void:
	if tolti.size() + svuotando.size() >= 3:
		return
	svuotando.append(c)
	(_scarichi[c] as PowerSource).powered = true
	colore_cominciato.emit(c)


func _vuote(c: String) -> bool:
	for t: WaterTank in _per_colore[c]:
		if t.fill > 0.001:
			return false
	return true


func _piene() -> bool:
	for t in _pozze:
		if t.fill < pieno - 0.002:
			return false
	return true


func _fine_svuotamento(c: String) -> void:
	svuotando.erase(c)
	(_scarichi[c] as PowerSource).powered = false
	for t: WaterTank in _per_colore[c]:
		t.fill = 0.0
		t.set_mix({})
	tolti.append(c)
	colore_tolto.emit(c)
	if tolti.size() >= 3:
		_valuta()


## Vero se i colori tolti sono proprio quelli del cartello.
func giusti_tolti() -> bool:
	if tolti.size() != GIUSTI.size():
		return false
	for c in GIUSTI:
		if not c in tolti:
			return false
	return true


func _valuta() -> void:
	if giusti_tolti():
		stato = Stato.RISOLTO
		_apri_porta(false)
		if checkpoint_risolto and checkpoint_risolto.is_inside_tree():
			GameState.reach_checkpoint.call_deferred(checkpoint_risolto)
		risolto.emit()
	else:
		stato = Stato.SBAGLIATO
		_t_errore = 0.0
		_lampeggiante(true)
		Audio.suona(&"vasca_svuotata", global_position)
		sbagliato.emit()


func _fine_ricarica() -> void:
	_carico.powered = false
	for t in _pozze:
		t.fill = pieno
		t.set_mix(WaterMix.pura(t.fill_pigment))
	tolti.clear()
	svuotando.clear()
	for c in COLORI:
		(_scarichi[c] as PowerSource).powered = false
	stato = Stato.APERTO
	_lampeggiante(false)
	ripristinato.emit()


## Si aspira solo dalle pozze che, aspirate, contano: non mentre si riempiono di nuovo, non da quelle già vuote, e un
## quarto colore no.
func _aggiorna_aspirabili() -> void:
	var pieni := tolti.size() + svuotando.size() >= 3
	for t in _pozze:
		var c: String = t.fill_pigment
		var si := stato == Stato.APERTO and not (c in tolti) and (c in svuotando or not pieni)
		if si != t.suckable:
			t.suckable = si
			if si:
				t.add_to_group(&"water_sources")
			else:
				t.remove_from_group(&"water_sources")


func _apri_porta(subito: bool) -> void:
	if porta and porta.has_method(&"apri"):
		porta.call(&"apri", subito)


func _lampeggiante(on: bool) -> void:
	for l in _luci_errore:
		if is_instance_valid(l):
			l.visible = on
	for a in _accesi_errore:
		if is_instance_valid(a):
			a.visible = on


## Le pozze, per i test.
func pozze() -> Array[WaterTank]:
	return _pozze


## Le pozze del colore [param c], per i test.
func pozze_del_colore(c: String) -> Array:
	return _per_colore.get(c, [])


# --- Checkpoint -------------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"stato": int(stato), "tolti": tolti.duplicate(), "svuotando": svuotando.duplicate()}


func load_state(data: Dictionary) -> void:
	stato = clampi(int(data.get("stato", 0)), 0, Stato.RISOLTO) as Stato
	tolti.clear()
	for c in data.get("tolti", []):
		if String(c) in COLORI and not String(c) in tolti:
			tolti.append(String(c))
	svuotando.clear()
	for c in data.get("svuotando", []):
		if String(c) in COLORI and not String(c) in tolti and not String(c) in svuotando:
			svuotando.append(String(c))
	for c in COLORI:
		(_scarichi[c] as PowerSource).powered = false
	_carico.powered = false
	_lampeggiante(false)
	# Le pozze si caricano dopo questo nodo (sono sue figlie): quello che era a metà si finisce dopo.
	_caricando = true
	_dopo_caricamento.call_deferred()


func _dopo_caricamento() -> void:
	_caricando = false
	match stato:
		Stato.RISOLTO:
			for c in GIUSTI:
				for t: WaterTank in _per_colore[c]:
					t.fill = 0.0
					t.set_mix({})
			_apri_porta(true)
		Stato.SBAGLIATO:
			# uno sbaglio a metà riparte già ricaricato
			_fine_ricarica()
		Stato.APERTO:
			# un colore che si stava svuotando riparte già vuoto
			for c in COLORI:
				for t: WaterTank in _per_colore[c]:
					if c in tolti or c in svuotando:
						t.fill = 0.0
						t.set_mix({})
					else:
						t.fill = pieno
						t.set_mix(WaterMix.pura(c))
			for c in svuotando.duplicate():
				_fine_svuotamento(c)
