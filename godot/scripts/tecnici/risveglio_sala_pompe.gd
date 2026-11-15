class_name RisveglioSalaPompe
extends Node
## La sala pompe (tappa 6 di docs/livello/capitolo1.md): "riaccendi le pompe" e il risveglio.
## - Tre pompe, ognuna con la sua turbina d'avviamento: si fanno girare col getto nell'ordine
##   dello schema a colori sul muro, blu → giallo → rosso. Se si sbaglia, le pompe si fermano e
##   si ricomincia. L'acqua per lo zaino si aspira dalla vasca di raccolta.
## - Per ultima la leva grande dietro la grata, da colpire col getto (prima è bloccata).
## - Il risveglio: le pompe ruggiscono, tutte le luci dell'acquapark si accendono per un secondo
##   e parte la sigla a tutto volume (GameState.Luci.FLASH); poi salta la corrente e restano le
##   rosse d'emergenza (BLACKOUT); il monitor mostra solo neve; lontano, plastica che si piega e
##   un tonfo nell'acqua; le paratie della camera delle onde si abbassano. Si esce dalla porta
##   del ponte inferiore col maniglione: il chiavistello si sfila un attimo dopo la leva
##   ([member sblocco_porta]), senza aspettare la fine del risveglio.
## Le luci le cambia GameState.imposta_luci(): un punto solo, a cui si aggancia la grafica.
## - La lezione (0.4.0, «L'acqua è sua», GDD del 15 novembre): poco dopo il tonfo, la vasca di raccolta si accende di
##   rosa da sotto per qualche secondo e dai tubi arriva per la prima volta il canto di lei: la luce passa sotto il
##   pelo, dal lato più vicino al giocatore, e se ne va. Lei non esce e non prende: un AcquaDiLei sulla vasca, non
##   letale e non automatico, fa solo [code]percorri()[/code] (la luce sott'acqua comune di mascotte; il canto lo segue
##   l'audio, CantoPrima). Una volta sola: ripartendo dal checkpoint del risveglio non si rifà.

signal pompa_avviata(indice: int)
signal sequenza_sbagliata
signal pompe_avviate
signal risveglio_iniziato
signal risveglio_finito
## Il chiavistello della porta del ponte si è sfilato (poco dopo la leva).
signal porta_sbloccata

## Le turbine d'avviamento nell'ordine dello schema (blu, giallo, rosso).
@export var turbine: Array[Turbine] = []
## Le pompe, nello stesso ordine delle turbine.
@export var pompe: Array[Pompa] = []
@export var leva: LevaGrande
@export var paratie: Array[Paratia] = []
@export var porta: PortaManiglione
@export var monitor: MonitorCrt
## Altri sbuffi di vapore che partono col ruggito (collettore, perdita).
@export var vapori: Array[NodePath] = []
## Il checkpoint di dopo il risveglio (si raggiunge da codice, alla fine).
@export var checkpoint: Checkpoint
## Da dove arrivano, lontani, la plastica che si piega e il tonfo (la vasca della medusa).
@export var punto_lontano := Vector3(0.0, 0.5, 10.0)
## Tempi del risveglio (s): flash, poi blackout; plastica, tonfo, paratie.
@export var durata_flash := 1.0
@export var attesa_plastica := 1.4
@export var attesa_tonfo := 2.6
@export var attesa_paratie := 1.2
## Secondi dalla leva allo sblocco della porta: la leva scatta in basso (LevaGrande.durata), il cavo
## tira e il chiavistello della porta si sfila con un colpo. Il resto del risveglio (blackout, rumori,
## paratie) va avanti intanto: la porta non lo aspetta (l'utente: "deve farlo in 1-2 secondi").
@export var sblocco_porta := 0.9
## La lezione: la vasca di raccolta (WaterTank) dove passa la luce rosa di lei, quanto dopo il tonfo (s), quanto dura il
## passaggio (s, senza lo spegnimento), quanto sotto il pelo passa (m; ai capi della vasca più giù, dove entra ed esce
## dai tubi) e in quanti secondi si spegne alla fine.
@export var vasca: WaterTank
@export var attesa_lezione := 1.2
@export var durata_lezione := 6.0
@export var sotto_il_pelo := 0.6
@export var sotto_il_pelo_capi := 1.1
@export var spegni_lezione := 1.5

## Quante pompe sono avviate nell'ordine giusto.
var avviate := 0
## La leva è stata tirata (il risveglio è partito o è già finito).
var risvegliata := false
## Il risveglio è finito: paratie giù, porta sbloccata.
var finito := false
## La luce di lei è partita davvero nella vasca di raccolta (la lezione). Finché non parte si riprova (la lezione
## insegna la regola: c'è sempre).
var lezione_fatta := false
## Ogni quanto si riprova la lezione se la luce non può passare (s), finché non parte.
const RIPROVA_LEZIONE := 0.5
var _avvisato := false
## Dalla leva finché la luce della lezione non si è spenta: lei è qui. Chi la vuole altrove (LeiSalaAlBuio) aspetta
## (il nodo è nel gruppo [constant GRUPPO]).
var lezione_in_corso := false
const GRUPPO := &"risveglio_pompe"
signal lezione_finita
## L'acqua di lei sulla vasca di raccolta (AcquaDiLei), solo per la lezione.
var acqua_lezione: Node3D

var _vapori: Array[GPUParticles3D] = []
var _motori: Array = []


func _ready() -> void:
	add_to_group(&"persist")
	add_to_group(GRUPPO)
	for i in turbine.size():
		var t := turbine[i]
		if t:
			t.powered_changed.connect(func(on: bool):
				if on:
					_turbina_accesa(i))
	if leva:
		leva.tirata.connect(_risveglio)
		leva.colpita_bloccata.connect(func(): _suona(&"pulsante_rilasciato", leva.global_position, -4.0, 0.7))
	if porta:
		porta.scossa_bloccata.connect(func(): _suona(&"maniglione_bloccato", porta.global_position))
		porta.aperta.connect(func(): _suona(&"porta_ponte_apre", porta.global_position))
		# dietro la porta del ponte, su per il raccordo, ci sono le stanze della Risalita (caricate nel thread dal
		# checkpoint della sala pompe): con AttesaZone la porta aspetta che siano pronte (scelta dell'utente, 25 ottobre)
		porta.zona = &"risalita"
		# la zona dietro non è ancora pronta (un PC lento): il maniglione scatta e il motore delle porte lavora
		# finché la porta non si apre da sola (AttesaZone)
		var motore: Array[Node] = [null]
		porta.attesa_iniziata.connect(func():
			_suona(&"maniglione_bloccato", porta.global_position, -2.0)
			var audio := get_node_or_null(^"/root/Audio")
			if audio and motore[0] == null:
				motore[0] = audio.call(&"crea_loop", &"porta_motore_loop", porta)
				if motore[0]:
					motore[0].set(&"position", Vector3.UP * 1.2)
					motore[0].set(&"volume", 1.0))
		porta.attesa_finita.connect(func():
			if motore[0] and is_instance_valid(motore[0]):
				motore[0].queue_free()
			motore[0] = null)
	_prepara_lezione()
	for v in vapori:
		var punto := get_node_or_null(v) as Node3D
		if punto:
			var vap := Vapore.new()
			vap.portata = 1.4
			vap.altezza = 2.0
			vap.raggio = 0.2
			vap.emitting = false
			add_child(vap)
			vap.global_position = punto.global_position
			_vapori.append(vap)


func _turbina_accesa(i: int) -> void:
	if risvegliata or avviate >= pompe.size() or i < avviate:
		return
	if i == avviate:
		pompe[i].avvia()
		_motore(i, 0.45, 0.65)
		_suona(&"pompa_avvio", pompe[i].global_position)
		avviate += 1
		pompa_avviata.emit(i)
		if avviate == pompe.size():
			if leva:
				leva.sbloccata = true
			pompe_avviate.emit()
		return
	# Ordine sbagliato: le pompe si fermano e si ricomincia.
	for k in pompe.size():
		pompe[k].ferma()
		_motore(k, 0.0, 0.5)
	avviate = 0
	if leva:
		leva.sbloccata = false
	_suona(&"turbina_bloccata", turbine[i].global_position, 0.0, 0.6)
	sequenza_sbagliata.emit()


func _risveglio() -> void:
	if risvegliata:
		return
	risvegliata = true
	lezione_in_corso = not lezione_fatta and acqua_lezione != null
	risveglio_iniziato.emit()
	_suona(&"cancello_fine", leva.global_position if leva else null, 0.0, 0.8)
	get_tree().create_timer(sblocco_porta, false).timeout.connect(_sblocca_porta)
	for k in pompe.size():
		pompe[k].ruggisci()
		_motore(k, 1.0, 0.95)
	for v in _vapori:
		v.emitting = true
	_suona(&"nave_gemito", pompe[pompe.size() / 2].global_position if not pompe.is_empty() else null, 2.0, 0.6)
	# Tutte le luci dell'acquapark per un secondo e la sigla a tutto volume.
	GameState.imposta_luci(GameState.Luci.FLASH)
	_suona(&"faro_acceso", null, 4.0, 0.8)
	var sigla := _suona(&"sigla_pulita", null, 4.0)
	await get_tree().create_timer(durata_flash, false).timeout
	# Salta la corrente.
	GameState.imposta_luci(GameState.Luci.BLACKOUT)
	if is_instance_valid(sigla) and sigla.has_method(&"stop"):
		sigla.call(&"stop")
	_suona(&"corrente_salta")
	if monitor:
		monitor.mostra_neve()
	await get_tree().create_timer(attesa_plastica, false).timeout
	# Lontano, sotto il rombo delle pompe: plastica che si piega a lungo, poi un tonfo.
	_suona(&"plastica_piega_lontano", punto_lontano)
	await get_tree().create_timer(attesa_tonfo, false).timeout
	_suona(&"tonfo_acqua_lontano", punto_lontano)
	# la lezione va per conto suo, intanto le paratie scendono come sempre
	get_tree().create_timer(attesa_lezione, false).timeout.connect(_lezione)
	await get_tree().create_timer(attesa_paratie, false).timeout
	for p in paratie:
		p.chiudi()
	var piu_lunga := 0.0
	for p in paratie:
		piu_lunga = maxf(piu_lunga, p.durata)
	await get_tree().create_timer(piu_lunga + 0.2, false).timeout
	_fine()


func _sblocca_porta() -> void:
	if porta and porta.bloccata:
		porta.bloccata = false
		# il chiavistello si sfila: un colpo di metallo accanto alla porta
		_suona(&"maniglione_bloccato", porta.global_position, -1.0, 0.75)
		porta_sbloccata.emit()


func _fine() -> void:
	finito = true
	if porta:
		porta.bloccata = false
	risveglio_finito.emit()
	if checkpoint:
		GameState.reach_checkpoint(checkpoint)


## Il motore di una pompa: un loop sulla pompa (0 = spento).
func _motore(i: int, volume: float, tono: float) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null or i >= pompe.size():
		return
	while _motori.size() <= i:
		_motori.append(null)
	if _motori[i] == null and volume > 0.0:
		_motori[i] = audio.call(&"crea_loop", &"pompe_ruggito_loop", pompe[i])
	var l = _motori[i]
	if l:
		l.set(&"volume", volume)
		l.set(&"tono", tono)


func _suona(nome: StringName, dove: Variant = null, db := 0.0, tono := 1.0) -> Node:
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null:
		return null
	return audio.call(&"suona", nome, dove, db, tono)


func save_state() -> Dictionary:
	return {"avviate": avviate, "finito": finito}


func load_state(data: Dictionary) -> void:
	# Un risveglio a metà riparte da prima della leva (si ripartirebbe comunque da un checkpoint
	# di prima); finito, resta finito.
	finito = bool(data.get("finito", false))
	risvegliata = finito
	avviate = clampi(int(data.get("avviate", 0)), 0, pompe.size())
	for k in pompe.size():
		if finito:
			pompe[k].ruggisci()
			_motore(k, 1.0, 0.95)
		elif k < avviate:
			pompe[k].avvia()
			_motore(k, 0.45, 0.65)
		else:
			pompe[k].ferma()
			_motore(k, 0.0, 0.5)
	if leva:
		leva.sbloccata = avviate >= pompe.size()
	for v in _vapori:
		v.emitting = finito
	if finito:
		if porta:
			porta.bloccata = false
		if monitor:
			monitor.mostra_neve()
		for p in paratie:
			p.load_state({"chiusa": true})


# --- La lezione (0.4.0) ----------------------------------------------------------------------------------------------

## L'acqua di lei sulla vasca di raccolta: non letale, non automatica, con un punto d'uscita al centro (il motore lo
## vuole; lei qui non esce mai, perché si usa solo percorri() senza alla_fine).
func _prepara_lezione() -> void:
	if vasca == null:
		return
	var script := load("res://scripts/creature/acqua_di_lei.gd") as Script
	if script == null:
		return
	acqua_lezione = script.new() as Node3D
	acqua_lezione.name = "AcquaDiLeiLezione"
	acqua_lezione.set(&"letale", false)
	acqua_lezione.set(&"automatica", false)
	# (spenta finché non parte la lezione e di nuovo dopo: il suo canto arriva con la luce e se ne va con lei,
	# poi la sala pompe tace; decisione del coordinatore del 15 novembre)
	acqua_lezione.set(&"abilitata", false)
	var centro := Marker3D.new()
	centro.name = "Centro"
	acqua_lezione.add_child(centro)
	vasca.add_child(acqua_lezione)
	acqua_lezione.global_transform = vasca.global_transform
	centro.global_position = Vector3(vasca.global_position.x, vasca.get_surface_global_y(), vasca.global_position.z)
	acqua_lezione.set(&"pelo", vasca.get_surface_global_y())
	acqua_lezione.set(&"punti_uscita", [centro] as Array[Node3D])


## Il percorso della luce, nel mondo: dentro dal tubo a un capo della vasca (più giù), su fino a [member sotto_il_pelo]
## nel punto della vasca più vicino al giocatore, via dall'altro capo (di nuovo giù). Lungo il lato lungo della vasca.
func percorso_lezione() -> PackedVector3Array:
	var punti := PackedVector3Array()
	if vasca == null:
		return punti
	var lungo := vasca.inner_size.x >= vasca.inner_size.z
	var mezzo := (vasca.inner_size.x if lungo else vasca.inner_size.z) * 0.5 - 0.35
	var asse := vasca.global_basis.x.normalized() if lungo else vasca.global_basis.z.normalized()
	var c := vasca.global_position
	var pelo := vasca.get_surface_global_y()
	var g := GameState.player as Node3D
	# entra dal capo più lontano dal giocatore, passa nel punto della vasca più vicino a lui, esce dall'altro capo
	var vicino := 0.0
	if g and is_instance_valid(g):
		vicino = clampf((g.global_position - c).dot(asse), -mezzo * 0.6, mezzo * 0.6)
	var verso := 1.0 if vicino >= 0.0 else -1.0
	var a := c - asse * mezzo * verso
	var b := c + asse * mezzo * verso
	a.y = pelo - sotto_il_pelo_capi
	b.y = pelo - sotto_il_pelo_capi
	var m := c + asse * vicino
	m.y = pelo - sotto_il_pelo
	punti.append(a)
	punti.append(m)
	punti.append(b)
	return punti


func _lezione() -> void:
	if lezione_fatta or acqua_lezione == null or not is_instance_valid(acqua_lezione) or not is_inside_tree():
		if lezione_fatta or acqua_lezione == null:
			_fine_lezione()
		return
	if not acqua_lezione.has_method(&"percorri"):
		push_warning("RisveglioSalaPompe: AcquaDiLei senza percorri(): niente lezione")
		_fine_lezione()
		return
	# accesa solo per partire; se il motore dice di no (lei altrove, un bambino in vista, il giocatore fuori dalla
	# sala) si spegne di nuovo e si riprova fra [constant RIPROVA_LEZIONE] s, senza rinunciare
	acqua_lezione.set(&"abilitata", true)
	var punti := percorso_lezione()
	var lunghezza := 0.0
	for i in range(1, punti.size()):
		lunghezza += punti[i].distance_to(punti[i - 1])
	var ok := bool(acqua_lezione.call(&"percorri", punti, lunghezza / maxf(durata_lezione, 0.1), null, spegni_lezione))
	if not ok:
		acqua_lezione.set(&"abilitata", false)
		if not _avvisato:
			_avvisato = true
			print("RisveglioSalaPompe: la luce di lei non può ancora passare nella vasca di raccolta, si riprova")
		get_tree().create_timer(RIPROVA_LEZIONE, false).timeout.connect(_lezione)
		return
	lezione_fatta = true
	acqua_lezione.connect(&"percorso_finito", _fine_lezione, CONNECT_ONE_SHOT)


func _fine_lezione() -> void:
	if acqua_lezione and is_instance_valid(acqua_lezione):
		acqua_lezione.set(&"abilitata", false)
	if lezione_in_corso:
		lezione_in_corso = false
		lezione_finita.emit()
