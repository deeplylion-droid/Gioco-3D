class_name ZonaNebbiaViola
extends Area3D
## Un ambiente con la nebbia viola (NebbiaViola): quando il giocatore entra la nebbia sale piano, quando esce scende.
## La forma è quella delle sue CollisionShape3D, coi bordi sulle porte e sui passaggi; più zone insieme (ambienti
## costruiti a pezzi) valgono come una. Se il giocatore c'è già quando la zona nasce (ripartenza da un checkpoint,
## caricamento, Continua), e dopo ogni salto della camera, la zona lo vede subito con la sua geometria ([method contiene]),
## senza aspettare la fisica dell'Area3D: la nebbia è piena dal primo fotogramma visibile (collaudo del 29 ottobre).

const GRUPPO := &"zone_nebbia_viola"

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
	add_to_group(GRUPPO)
	controlla_subito()
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


## Vero se [param p] (nel mondo) è dentro una delle scatole della zona.
func contiene(p: Vector3) -> bool:
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D) or cs.disabled:
			continue
		var loc := cs.global_transform.affine_inverse() * p
		var h := (cs.shape as BoxShape3D).size * 0.5
		if absf(loc.x) <= h.x and absf(loc.y) <= h.y and absf(loc.z) <= h.z:
			return true
	return false


## Il giocatore adesso, con la geometria: dentro o fuori subito, senza dissolvenza.
func controlla_subito() -> void:
	var p := GameState.player
	if not is_inside_tree() or p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var n := Grafica.nebbia_viola
	if n:
		# (fuori: solo se c'era; la dissolvenza la decide la nebbia, che dopo un salto la salta da sé)
		var dentro := contiene(p.global_position + Vector3.UP)
		n.zona(self, dentro, dentro)


## Anche alla fine del fotogramma in cui nasce (il giocatore messo al suo posto dopo, nello stesso fotogramma).
func _controlla_subito() -> void:
	controlla_subito()


func _exit_tree() -> void:
	var n := Grafica.nebbia_viola
	if n:
		n.zona(self, false)
