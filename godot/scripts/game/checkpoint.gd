class_name Checkpoint
extends Area3D
## Checkpoint invisibile: quando il giocatore ci entra, GameState salva lo stato.
## Mettine tanti lungo il percorso (serve una CollisionShape3D figlia).
## [member order] cresce lungo il livello (percorso lineare): un checkpoint con order più
## basso dell'ultimo raggiunto non sposta indietro il punto di ripartenza.

@export var order := 0
## Punto e direzione di ripartenza (vuoto = questo nodo). Si guarda verso il suo -Z.
@export var spawn_point: Node3D


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		GameState.reach_checkpoint(self)


func get_spawn_transform() -> Transform3D:
	var n: Node3D = spawn_point if spawn_point else self
	return n.global_transform
