class_name KidSighting
extends Node3D
## Momento B5 del capitolo 1: mentre sali sulla torre, un lampo illumina la balconata
## dall'altra parte della sala e si vede una fila di bambini immobili, tutti girati verso di
## te. Al lampo dopo non c'è più nessuno. Succede una volta sola; non si possono raggiungere.

signal seen

## I modelli dei bambini (si alternano lungo la fila).
@export var models: Array[PackedScene] = []
## Dove stanno (coordinate globali, piedi a terra).
@export var spots := PackedVector3Array()
## L'area che fa partire il momento (il giocatore sulla torre).
@export var trigger: Area3D
@export var storm: Tempesta
## Se il giocatore arriva più vicino di così, spariscono subito.
@export var vanish_distance := 9.0

var _kids: Array[Node3D] = []
var _done := false
var _armed := false


func _ready() -> void:
	if trigger:
		trigger.body_entered.connect(_on_trigger)
	if storm == null:
		_find_storm.call_deferred()


func _find_storm() -> void:
	var found := get_tree().root.find_children("*", "Tempesta", true, false)
	if found.size() > 0:
		storm = found[0] as Tempesta


func _on_trigger(body: Node3D) -> void:
	if _done or not (body is Player):
		return
	_done = true
	var player := body as Player
	for i in spots.size():
		if models.is_empty():
			break
		var kid := models[i % models.size()].instantiate() as Node3D
		kid.name = "Bambino%d" % (i + 1)
		add_child(kid)
		kid.global_position = spots[i]
		# Girati verso di te, con il viso un po' storto: uno diverso dall'altro.
		var to := player.global_position - spots[i]
		kid.rotation = Vector3(0.0, atan2(to.x, to.z) + randf_range(-0.12, 0.12), randf_range(-0.05, 0.05))
		_kids.append(kid)
	seen.emit()
	if storm:
		storm.lampo_ora(1.4, 0.4)
		# Il lampo dopo li porta via.
		get_tree().create_timer(1.6, false).timeout.connect(func(): _armed = true)
		storm.lampo.connect(_on_next_flash)


func _on_next_flash(_intensity: float) -> void:
	if _armed:
		_vanish()


func _process(_delta: float) -> void:
	if _kids.is_empty() or GameState.player == null:
		return
	for k in _kids:
		if is_instance_valid(k) and k.global_position.distance_to(GameState.player.global_position) < vanish_distance:
			_vanish()
			return


func _vanish() -> void:
	for k in _kids:
		if is_instance_valid(k):
			k.queue_free()
	_kids.clear()
	if storm and storm.lampo.is_connected(_on_next_flash):
		storm.lampo.disconnect(_on_next_flash)
