class_name Pickup
extends Interactable
## Oggetto raccoglibile: con E finisce nell'inventario del giocatore e sparisce dalla scena.
## Fa parte dei checkpoint: dopo una morte ricompare solo se non era stato salvato.

## Identificatore usato dal codice (per esempio da una porta che chiede una chiave).
@export var item_id: StringName = &"oggetto"
## Nome mostrato a schermo.
@export var item_name := "Oggetto"
@export var quantity := 1
## Nodo da togliere quando viene raccolto (vuoto = questo nodo).
@export var remove_node: Node


func _init() -> void:
	super()
	prompt = "Raccogli"
	one_shot = true


func _ready() -> void:
	add_to_group(&"persist")
	_remove_if_already_taken.call_deferred()


func _remove_if_already_taken() -> void:
	if GameState.is_removed(self):
		var target: Node = remove_node if remove_node else self
		target.queue_free()


func get_prompt(_by: Node) -> String:
	return "%s %s" % [prompt, item_name]


func _on_interact(by: Node) -> void:
	if by.has_method("add_item"):
		by.add_item(item_id, quantity, item_name)
	GameState.mark_removed(self)
	var target: Node = remove_node if remove_node else self
	target.queue_free()
