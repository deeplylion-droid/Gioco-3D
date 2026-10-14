class_name Interactor
extends Node
## Raggio dagli occhi del giocatore: trova l'Interactable guardato e lo usa con "interact" (E).
## Il testo a schermo lo mostra l'HUD ascoltando Player.interaction_target_changed.

## Distanza massima di interazione (m).
@export var reach := 2.3
## Livelli che il raggio vede: mondo, nemici e oggetti (bloccano la vista) e interazione.
@export_flags_3d_physics var collision_mask := 29

var current: Interactable = null
var player: Player


func setup(p: Player) -> void:
	player = p


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var found := _find_target()
	if found != current:
		current = found
		player.interaction_target_changed.emit(current)
	if current and player.input_enabled and Input.is_action_just_pressed("interact"):
		current.interact(player)
		# L'oggetto può essere sparito o cambiato: aggiorna il testo al prossimo tick.
		current = null
		player.interaction_target_changed.emit(null)


func _find_target() -> Interactable:
	var aim := player.get_aim_transform()
	var from := aim.origin
	var to := from - aim.basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [player.get_rid()])
	q.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var target := hit.collider as Interactable
	if target and not target.is_queued_for_deletion() and target.can_interact(player):
		return target
	return null
