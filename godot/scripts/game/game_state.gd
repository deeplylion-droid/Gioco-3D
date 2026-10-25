extends Node
## Autoload "GameState": checkpoint, salvataggio, collezionabili e morte del giocatore.
##
## Checkpoint: aree invisibili (Checkpoint) lungo il percorso. Entrandoci si salva
## un'istantanea: punto di ripartenza, inventario, acqua nello zaino, collezionabili e lo stato
## degli oggetti del gruppo "persist" (vasche, pulsanti, porte, oggetti raccolti...).
## Un oggetto "persist" implementa save_state() -> Dictionary e load_state(data).
## Gli oggetti raccolti (Pickup) vengono segnati con mark_removed() e non ricompaiono.
##
## Morte: GameState.kill_player(&"causa") da qualsiasi script (nemici, zone mortali, IA...).
## Parte la sequenza di morte (saltabile tenendo premuto Spazio, E o Invio), poi il livello
## viene ricaricato e si riparte dall'ultimo checkpoint.

signal checkpoint_reached(checkpoint_id: String)
signal player_died(cause: StringName)
signal player_respawned
signal collectible_collected(collection: StringName, entry: StringName, count: int, total: int)
## Le luci dell'acquapark sono cambiate (vedi [member luci]).
signal luci_cambiate(fase: Luci)

## Le luci di tutto l'acquapark (tappa 6, il risveglio): prima del risveglio; il flash, un
## secondo con tutte le luci accese quando ripartono le pompe; il blackout, con le sole luci
## rosse d'emergenza. È il punto unico a cui si agganciano le luci (LookSala, LookTecnici,
## LookInterni dell'addon grafica, LuciRisveglio): leggono [member luci] e ascoltano
## [signal luci_cambiate]. Si salva con i checkpoint.
enum Luci { PRIMA_DEL_RISVEGLIO, FLASH, BLACKOUT }

const SAVE_PATH := "user://salvataggio.json"
const SAVE_VERSION := 1
const DEATH_SEQUENCE_SCENE := "res://scenes/ui/death_sequence.tscn"
## Secondi massimi che la ripartenza aspetta i caricamenti nel thread (se un caricamento non finisce mai).
const ATTESA_RIPARTENZA := 60.0

## Scrive l'ultimo checkpoint su disco (per un futuro "Continua" nel menu).
@export var save_to_disk := true
## I collezionabili restano anche se si muore prima del checkpoint successivo.
@export var keep_collectibles_on_death := true

## Il giocatore del livello attuale.
var player: Player = null
var is_dying := false
## Ultima istantanea salvata (vuota = nessuna).
var snapshot: Dictionary = {}
## Causa dell'ultima morte.
var last_death_cause: StringName = &""
## Le luci dell'acquapark adesso (vedi [enum Luci]).
var luci: Luci = Luci.PRIMA_DEL_RISVEGLIO

var _removed: Dictionary = {}       # chiave persist -> true
# Lo stato degli oggetti "persist" delle parti del livello scaricate per la memoria (le stanze della
# Risalita lontane): chiave persist -> save_state(). Entra nelle istantanee e torna agli oggetti quando la
# parte si ricarica ([method parcheggia], [method ripristina]).
var _parcheggiati: Dictionary = {}
# Le parti che si stanno costruendo (a pezzi, a gioco avviato): i loro oggetti non hanno ancora lo stato giusto e
# non entrano nelle istantanee finché [method ripristina] non glielo rende.
var _in_costruzione: Array[Node] = []
var _collected: Dictionary = {}     # collezione -> { voce: true }
var _registry: Dictionary = {}      # collezione -> { voce: true }, tutte quelle viste
var _restore_pending := false
var _death_sequence: Node = null
var _ripartenza_in_corso := false
## Secondi che l'ultima ripartenza ha aspettato i caricamenti nel thread (Game.aspetta_caricamenti).
var attesa_ripartenza := 0.0


# --- Livello e giocatore ------------------------------------------------------------------

## Chiamato dal giocatore quando entra in scena.
func register_player(p: Player) -> void:
	player = p
	_on_level_ready.call_deferred()


func _on_level_ready() -> void:
	if player == null or not is_instance_valid(player):
		return
	var scene := _scene_path()
	if _restore_pending and snapshot.get("scene", "") == scene:
		_restore_pending = false
		_apply_snapshot(snapshot)
		is_dying = false
		player_respawned.emit()
		if is_instance_valid(_death_sequence) and _death_sequence.has_method(&"fade_in"):
			_death_sequence.call(&"fade_in")
	elif snapshot.get("scene", "") != scene:
		# Livello nuovo: il primo checkpoint è il punto di partenza.
		_removed.clear()
		_parcheggiati.clear()
		imposta_luci(Luci.PRIMA_DEL_RISVEGLIO)
		capture_snapshot("inizio", -1, player.global_transform)


## Cambia le luci dell'acquapark (vedi [enum Luci]) e lo dice a chi ascolta.
func imposta_luci(fase: Luci) -> void:
	if fase == luci:
		return
	luci = fase
	luci_cambiate.emit(fase)


## Vero mentre il livello si sta caricando per ripartire da un checkpoint o da un salvataggio.
func is_restoring() -> bool:
	return _restore_pending


func _scene_path() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path if s else ""


## Chiave stabile di un nodo "persist": il percorso dentro la scena del livello.
func persist_key(node: Node) -> String:
	var scene := get_tree().current_scene
	if scene and (scene == node or scene.is_ancestor_of(node)):
		return String(scene.get_path_to(node))
	return String(node.get_path())


## Un oggetto tolto dal livello (per esempio raccolto) non ricompare dopo un checkpoint.
func mark_removed(node: Node) -> void:
	_removed[persist_key(node)] = true


func is_removed(node: Node) -> bool:
	return _removed.has(persist_key(node))


# --- Checkpoint ----------------------------------------------------------------------------

## Chiamato da un'area Checkpoint quando il giocatore ci entra.
func reach_checkpoint(cp: Checkpoint) -> void:
	if is_dying or player == null or not is_instance_valid(player):
		return
	var key := persist_key(cp)
	if snapshot.get("checkpoint", "") == key and snapshot.get("scene", "") == _scene_path():
		return
	if cp.order < int(snapshot.get("order", -1)) and snapshot.get("scene", "") == _scene_path():
		return
	capture_snapshot(key, cp.order, cp.get_spawn_transform())
	checkpoint_reached.emit(key)


## Salva lo stato attuale. [param spawn] è dove (e verso dove) riparte il giocatore.
func capture_snapshot(checkpoint_id: String, order: int, spawn: Transform3D) -> void:
	var objects := _parcheggiati.duplicate()
	_in_costruzione.assign(_in_costruzione.filter(func(r): return is_instance_valid(r) and r.is_inside_tree()))
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n.has_method("save_state") and not n.is_queued_for_deletion() \
				and not _in_costruzione.any(func(r): return r == n or r.is_ancestor_of(n)):
			objects[persist_key(n)] = n.save_state()
	var f := -spawn.basis.z
	var inventory := {}
	for k in player.inventory:
		inventory[String(k)] = player.inventory[k]
	snapshot = {
		"version": SAVE_VERSION,
		"scene": _scene_path(),
		"checkpoint": checkpoint_id,
		"order": order,
		"player": {
			"position": [spawn.origin.x, spawn.origin.y, spawn.origin.z],
			"yaw": atan2(-f.x, -f.z),
			"inventory": inventory,
			"water": player.water_pack.tank_amount if player.water_pack else 0.0,
			"water_mix": player.water_pack.water_mix.duplicate() if player.water_pack else {},
		},
		"objects": objects,
		"removed": _removed.keys(),
		"collectibles": _collected_to_lists(),
		# Il flash dura un secondo: chi riparte da lì lo ritrova già finito.
		"luci": int(Luci.BLACKOUT if luci == Luci.FLASH else luci),
		"time": Time.get_unix_time_from_system(),
	}
	if save_to_disk:
		_write_disk()


func _apply_snapshot(s: Dictionary) -> void:
	imposta_luci(clampi(int(s.get("luci", 0)), 0, Luci.BLACKOUT) as Luci)
	_removed.clear()
	for k in s.get("removed", []):
		_removed[String(k)] = true
	var objects: Dictionary = s.get("objects", {})
	# quelli che non ci sono (una parte scaricata) li riprende la parte quando si ricarica
	_parcheggiati = objects.duplicate()
	for n in get_tree().get_nodes_in_group(&"persist"):
		var key := persist_key(n)
		_parcheggiati.erase(key)
		if _removed.has(key):
			n.queue_free()
		elif objects.has(key) and n.has_method("load_state"):
			n.load_state(objects[key])
	var ps: Dictionary = s.get("player", {})
	if player and not ps.is_empty():
		var p: Array = ps.get("position", [0, 0, 0])
		player.teleport(Vector3(p[0], p[1], p[2]), float(ps.get("yaw", 0.0)), 0.0)
		player.inventory.clear()
		var inv: Dictionary = ps.get("inventory", {})
		for k in inv:
			player.inventory[StringName(k)] = int(inv[k])
		if player.water_pack:
			var pack := player.water_pack
			pack.set_equipped(pack.start_equipped or player.has_item(&"zaino_pompa"), false)
			pack.set_tank_amount(float(ps.get("water", pack.tank_amount)))
			pack.set_water_mix(ps.get("water_mix", {}))
		player.input_enabled = true


## Una parte del livello sta per essere scaricata (per la memoria): lo stato dei suoi oggetti "persist" resta
## qui, entra nelle istantanee e torna agli oggetti con [method ripristina] quando la parte si ricarica.
func parcheggia(radice: Node) -> void:
	for n in get_tree().get_nodes_in_group(&"persist"):
		if (n == radice or radice.is_ancestor_of(n)) and n.has_method("save_state") and not n.is_queued_for_deletion():
			_parcheggiati[persist_key(n)] = n.save_state()


## Una parte del livello che entra nella scena e si costruisce a pezzi: fino a [method ripristina] i suoi oggetti
## non entrano nelle istantanee (resta lo stato parcheggiato).
func in_costruzione(radice: Node) -> void:
	if not radice in _in_costruzione:
		_in_costruzione.append(radice)


## Una parte del livello caricata di nuovo (o per la prima volta dopo una ripartenza): i suoi oggetti
## "persist" riprendono lo stato parcheggiato o quello dell'istantanea, e quelli tolti non ricompaiono.
func ripristina(radice: Node) -> void:
	_in_costruzione.erase(radice)
	if not is_instance_valid(radice) or not radice.is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group(&"persist"):
		if n != radice and not radice.is_ancestor_of(n):
			continue
		var key := persist_key(n)
		if _removed.has(key):
			n.queue_free()
		elif _parcheggiati.has(key) and n.has_method("load_state"):
			n.load_state(_parcheggiati[key])
		_parcheggiati.erase(key)


# --- Morte e ripartenza --------------------------------------------------------------------

## Uccide il giocatore: si può chiamare da qualsiasi script. [param cause] serve per scegliere
## in futuro la scena di morte giusta (per esempio &"medusa", &"caduta").
func kill_player(cause: StringName = &"generico") -> void:
	if is_dying or player == null or not is_instance_valid(player):
		return
	is_dying = true
	last_death_cause = cause
	player.input_enabled = false
	player_died.emit(cause)
	var seq: Node = load(DEATH_SEQUENCE_SCENE).instantiate()
	seq.set(&"cause", cause)
	add_child(seq)
	_death_sequence = seq
	seq.connect(&"finished", _on_death_sequence_finished, CONNECT_ONE_SHOT)


func _on_death_sequence_finished(_skipped: bool) -> void:
	respawn()


## Ricarica il livello e riparte dall'ultimo checkpoint. Non mentre si esce dal gioco (Game.esci): la sala
## ricaricata richiederebbe di nuovo la torre nel thread, e l'uscita la troverebbe a metà.
## Prima, a schermo nero, la sala si ferma (non comincia altro) e si aspetta che i caricamenti nel thread e i suoi lavori
## a metà siano finiti, più due fotogrammi disegnati (Game.aspetta_caricamenti; crash della v0.3.14 dopo il primo spavento).
func respawn() -> void:
	if Game.uscendo or _ripartenza_in_corso:
		return
	_ripartenza_in_corso = true
	var sala := get_tree().current_scene
	attesa_ripartenza = await Game.aspetta_caricamenti(sala, ATTESA_RIPARTENZA)
	_ripartenza_in_corso = false
	if attesa_ripartenza > 0.05:
		print("Ripartenza: aspettati i caricamenti nel thread per %.1f s" % attesa_ripartenza)
	# (intanto si è usciti dal gioco o si è tornati al titolo: non si riparte)
	if Game.uscendo or Game.tornando_al_titolo or not is_instance_valid(sala) or get_tree().current_scene != sala:
		return
	if not keep_collectibles_on_death:
		_collected = _lists_to_collected(snapshot.get("collectibles", {}))
	# Gli oggetti raccolti dopo il checkpoint tornano al loro posto.
	_removed.clear()
	for k in snapshot.get("removed", []):
		_removed[String(k)] = true
	player = null
	if snapshot.is_empty():
		is_dying = false
		get_tree().reload_current_scene()
		return
	_restore_pending = true
	var scene: String = snapshot.get("scene", "")
	var current := get_tree().current_scene
	if current and current.scene_file_path == scene:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene)


# --- Collezionabili (per esempio le Polaroid) ----------------------------------------------

## Ogni collezionabile si registra quando entra in scena: così si conosce il totale.
func register_collectible(collection: StringName, entry: StringName) -> void:
	if not _registry.has(collection):
		_registry[collection] = {}
	_registry[collection][entry] = true


func has_collectible(collection: StringName, entry: StringName) -> bool:
	return _collected.has(collection) and _collected[collection].has(entry)


func collect(collection: StringName, entry: StringName) -> void:
	if has_collectible(collection, entry):
		return
	register_collectible(collection, entry)
	if not _collected.has(collection):
		_collected[collection] = {}
	_collected[collection][entry] = true
	if keep_collectibles_on_death and not snapshot.is_empty():
		snapshot["collectibles"] = _collected_to_lists()
		if save_to_disk:
			_write_disk()
	collectible_collected.emit(collection, entry, get_collected_count(collection), get_total(collection))


func get_collected_count(collection: StringName) -> int:
	return _collected[collection].size() if _collected.has(collection) else 0


## Totale conosciuto della collezione (quelle registrate nei livelli visti finora).
func get_total(collection: StringName) -> int:
	return _registry[collection].size() if _registry.has(collection) else 0


func _collected_to_lists() -> Dictionary:
	var out := {}
	for c in _collected:
		out[String(c)] = (_collected[c] as Dictionary).keys().map(func(e): return String(e))
	return out


func _lists_to_collected(data: Dictionary) -> Dictionary:
	var out := {}
	for c in data:
		var d := {}
		for e in data[c]:
			d[StringName(e)] = true
		out[StringName(c)] = d
	return out


# --- Disco ---------------------------------------------------------------------------------

func _write_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Salvataggio non riuscito: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(snapshot, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Riprende dal salvataggio su disco (per un futuro "Continua" nel menu).
func continue_from_disk() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	prepara_ripresa(data)
	get_tree().change_scene_to_file(snapshot.get("scene", ""))
	return true


## Prepara la ripresa da un'istantanea [param data] (un salvataggio, o una partenza del menu di prova): come dopo una
## morte, al prossimo livello che si apre con la sua scena si riparte dal suo checkpoint, con lo stato, l'inventario,
## le luci e i collezionabili dell'istantanea. Chi la chiama poi apre la scena (direttamente o col caricamento).
func prepara_ripresa(data: Dictionary) -> void:
	reset_progress()
	snapshot = data
	_collected = _lists_to_collected(snapshot.get("collectibles", {}))
	_removed.clear()
	for k in snapshot.get("removed", []):
		_removed[String(k)] = true
	_restore_pending = true


## Azzera i progressi in memoria (nuova partita). Il file su disco viene sovrascritto
## al primo checkpoint.
func reset_progress() -> void:
	snapshot = {}
	_removed.clear()
	_parcheggiati.clear()
	_collected.clear()
	_restore_pending = false
	is_dying = false
	imposta_luci(Luci.PRIMA_DEL_RISVEGLIO)
