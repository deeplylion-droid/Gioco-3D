@tool
class_name AssetSlot
extends Node3D
## Posto per un modello definitivo (GLB della sala, degli oggetti, della medusa...).
## Finché [member model] è vuoto si vede il figlio "Graybox". Quando arriva il modello vero,
## basta assegnarlo a [member model] (anche dall'ispettore): il graybox si nasconde e, se
## [member replace_collision] è vero, si spegne anche la sua collisione (allora le collisioni
## devono venire dal modello, per esempio con i suffissi -col dell'importazione GLB).

## Il modello definitivo (un .glb importato o una scena .tscn).
@export var model: PackedScene:
	set(value):
		model = value
		_apply()
## Trasformazione del modello rispetto a questo nodo (per allinearlo al graybox).
@export var model_transform := Transform3D.IDENTITY:
	set(value):
		model_transform = value
		if is_instance_valid(_instance):
			_instance.transform = value
## Se vero, la collisione del graybox si spegne quando c'è il modello.
@export var replace_collision := false:
	set(value):
		replace_collision = value
		_apply()

var _instance: Node3D


func _ready() -> void:
	_apply()


## Il nodo con la grafica provvisoria.
func get_graybox() -> Node3D:
	return get_node_or_null(^"Graybox") as Node3D


func has_model() -> bool:
	return is_instance_valid(_instance)


func _apply() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_instance):
		_instance.queue_free()
		_instance = null
	var gb := get_graybox()
	if model:
		_instance = model.instantiate() as Node3D
		if _instance:
			_instance.name = "Modello"
			_instance.transform = model_transform
			add_child(_instance, false, Node.INTERNAL_MODE_BACK)
	if gb:
		gb.visible = not has_model()
		_set_collision(gb, not (has_model() and replace_collision))


static func _set_collision(node: Node, enabled: bool) -> void:
	if node is CSGShape3D:
		(node as CSGShape3D).use_collision = enabled and (node as CSGShape3D).get_meta(&"collisione", true)
	elif node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not enabled
	for c in node.get_children():
		_set_collision(c, enabled)
