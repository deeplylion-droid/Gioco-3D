class_name ZonaNebbiaViola
extends Area3D
## Un ambiente con la nebbia viola (NebbiaViolaProva): quando il giocatore entra la nebbia sale piano, quando esce scende.
## La forma è quella delle sue CollisionShape3D; più zone insieme (ambienti costruiti a pezzi) valgono come una.
## Se il giocatore c'è già quando la zona nasce (ripartenza da un checkpoint), la nebbia è subito piena.


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2   # il giocatore
	body_entered.connect(_entra.bind(true))
	body_exited.connect(_entra.bind(false))
	_controlla_subito.call_deferred()


func _entra(corpo: Node3D, dentro: bool, subito := false) -> void:
	if corpo != GameState.player:
		return
	var n := get_tree().get_first_node_in_group(&"nebbia_viola") as NebbiaViolaProva
	if n:
		n.zona(self, dentro, subito)


## Dopo un fotogramma di fisica: il giocatore già dentro conta subito.
func _controlla_subito() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(GameState.player) and overlaps_body(GameState.player):
		_entra(GameState.player, true, true)


func _exit_tree() -> void:
	var n := get_tree().get_first_node_in_group(&"nebbia_viola") as NebbiaViolaProva if is_inside_tree() else null
	if n:
		n.zona(self, false)
