class_name DummyEnemy
extends CharacterBody3D
## Manichino di prova per il getto: cammina piano verso il giocatore; il getto lo spinge
## indietro (WaterKnockback) e per un attimo lo blocca. Non fa danni: serve solo ai test.
## È anche un esempio di come collegare un nemico al segnale "colpito dal getto".

@export var move_speed := 1.2
@export var aggro_range := 9.0
@export var stop_distance := 1.5
@export var turn_speed := 5.0
## Se più di 0: arrivato così vicino al giocatore lo uccide (GameState.kill_player).
@export var kill_distance := 0.0

var target: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var knockback: WaterKnockback = $WaterKnockback


func _ready() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node3D


func _physics_process(delta: float) -> void:
	var walk := Vector3.ZERO
	if target and is_instance_valid(target) and not knockback.is_stunned():
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if kill_distance > 0.0 and dist < kill_distance and absf(target.global_position.y - global_position.y) < 1.5:
			GameState.kill_player(&"manichino")
		if dist < aggro_range and dist > stop_distance:
			walk = to / dist * move_speed
			var want_yaw := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want_yaw, 1.0 - exp(-turn_speed * delta))
	velocity.x = walk.x + knockback.velocity.x
	velocity.z = walk.z + knockback.velocity.z
	if is_on_floor():
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
