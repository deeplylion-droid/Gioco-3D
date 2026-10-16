class_name KillZone
extends Area3D
## Zona mortale: il giocatore che ci entra muore (GameState.kill_player) e riparte
## dall'ultimo checkpoint. Serve una CollisionShape3D figlia.

## Causa della morte, passata alla sequenza di morte.
@export var cause: StringName = &"caduta"


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		GameState.kill_player(cause)
