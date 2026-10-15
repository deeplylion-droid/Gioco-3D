class_name Interactable
extends Area3D
## Qualcosa che il giocatore usa guardandolo e premendo E.
## Serve una CollisionShape3D figlia. Sta sul livello fisico "interazione": il raggio
## dell'Interactor del giocatore lo trova e a schermo compare "[E] <prompt>".

signal interacted(by: Node)

## Testo a schermo, per esempio "Raccogli" o "Apri".
@export var prompt := "Usa"
@export var enabled := true
## Se vero, dopo il primo uso si disattiva.
@export var one_shot := false


func _init() -> void:
	collision_layer = Layers.INTERACTION
	collision_mask = 0
	monitoring = false


func can_interact(_by: Node) -> bool:
	return enabled


func get_prompt(_by: Node) -> String:
	return prompt


func interact(by: Node) -> void:
	if not can_interact(by):
		return
	if one_shot:
		enabled = false
	_on_interact(by)
	interacted.emit(by)


## Da ridefinire nelle sottoclassi.
func _on_interact(_by: Node) -> void:
	pass
