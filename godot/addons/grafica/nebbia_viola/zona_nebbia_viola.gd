class_name ZonaNebbiaViola
extends Area3D
## Un ambiente con la nebbia viola (NebbiaViola): quando il giocatore entra la nebbia sale piano, quando esce scende.
## La forma è quella delle sue CollisionShape3D, coi bordi sulle porte e sui passaggi; più zone insieme (ambienti
## costruiti a pezzi) valgono come una. Se il giocatore c'è già quando la zona nasce (ripartenza da un checkpoint,
## caricamento), la nebbia è subito piena.

## Il pavimento della zona (y): la nebbia è più fitta lì vicino.
@export var quota := 0.0
## Dove cercare le lampade per l'alone (vuoto: il genitore della zona).
@export var luci: Array[NodePath] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2   # il giocatore
	body_entered.connect(_entra.bind(true))
	body_exited.connect(_entra.bind(false))
	_controlla_subito.call_deferred()


## I nodi sotto cui stanno le lampade della zona.
func radici_luci() -> Array[Node]:
	var out: Array[Node] = []
	if luci.is_empty():
		out.append(get_parent())
	for np in luci:
		var n := get_node_or_null(np)
		if n:
			out.append(n)
	return out


func _entra(corpo: Node3D, dentro: bool, subito := false) -> void:
	if corpo != GameState.player:
		return
	var n := Grafica.nebbia_viola
	if n:
		n.zona(self, dentro, subito)


## Dopo due fotogrammi di fisica: il giocatore già dentro conta subito.
func _controlla_subito() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree() and is_instance_valid(GameState.player) and overlaps_body(GameState.player):
		_entra(GameState.player, true, true)


func _exit_tree() -> void:
	var n := Grafica.nebbia_viola
	if n:
		n.zona(self, false)
