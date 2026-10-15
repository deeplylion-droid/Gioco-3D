class_name PackPickup
extends Interactable
## Lo zaino-pompa da raccogliere (per esempio sulla rastrelliera dello stanzino dei bagnini).
## Preso, finisce sulla schiena e la pistola ad acqua compare in mano.
## Fa parte dei checkpoint: dopo una ripartenza resta preso.

## Litri nel serbatoio quando lo prendi.
@export var water_inside := 0.0
## Nodo da togliere quando viene preso (vuoto = questo nodo).
@export var remove_node: Node


func _init() -> void:
	super()
	prompt = "Prendi lo zaino-pompa"
	one_shot = true


func _ready() -> void:
	add_to_group(&"persist")
	_remove_if_taken.call_deferred()


func _remove_if_taken() -> void:
	if GameState.is_removed(self):
		var target: Node = remove_node if remove_node else self
		target.queue_free()


func _on_interact(by: Node) -> void:
	var p := by as Player
	if p == null:
		return
	p.add_item(&"zaino_pompa", 1, "Zaino-pompa")
	if p.water_pack:
		p.water_pack.set_tank_amount(water_inside)
		p.water_pack.set_equipped(true)
	GameState.mark_removed(self)
	var level := get_tree().current_scene
	if level and level.has_method(&"on_pack_taken"):
		level.call(&"on_pack_taken")
	var target: Node = remove_node if remove_node else self
	target.queue_free()
