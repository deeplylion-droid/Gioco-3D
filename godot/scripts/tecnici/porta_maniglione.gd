class_name PortaManiglione
extends Interactable
## La porta del ponte inferiore nella sala pompe (tappa 6): da dentro si apre col maniglione
## (tasto E). Finché le pompe non ripartono è bloccata: il maniglione sbatte e basta. Dopo il
## risveglio è l'unica uscita (le paratie della camera delle onde sono giù).
## Ruota la porta del modello (PORTA_ponte) intorno a un cardine verticale sul suo bordo; la
## collisione della porta è figlia e gira con lei (spenta durante il movimento, così non spinge
## il giocatore).

signal aperta
signal scossa_bloccata

## La porta del modello.
@export var porta_path: NodePath
## Cardine: un punto sul bordo della porta (coordinate globali al momento del _ready, prese dal
## nodo indicato) e l'angolo d'apertura (gradi intorno a +Y; positivo = verso la sala).
@export var cardine_path: NodePath
@export var angolo_apertura := 95.0
@export var durata := 1.4
## Se la porta del modello non ha una collisione sua, ne crea una (scatola come la mesh).
@export var collisione_propria := false

var bloccata := true
var is_open := false

var _porta: Node3D
var _riposo := Transform3D.IDENTITY
var _cardine := Vector3.ZERO
var _t := 0.0
var _scossa := 0.0
var _corpi: Array[CollisionObject3D] = []
var _livelli: Array[int] = []


func _ready() -> void:
	prompt = "Apri"
	add_to_group(&"persist")
	_porta = get_node_or_null(porta_path) as Node3D
	if _porta and collisione_propria and _porta is MeshInstance3D:
		var corpo := StaticBody3D.new()
		corpo.name = "CollisionePorta"
		corpo.collision_layer = Layers.WORLD
		corpo.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var bb := (_porta as MeshInstance3D).get_aabb()
		box.size = bb.size
		cs.shape = box
		cs.position = bb.get_center()
		corpo.add_child(cs)
		_porta.add_child(corpo)
	if _porta:
		_riposo = _porta.global_transform
		for c in _porta.find_children("*", "CollisionObject3D", true, false):
			_corpi.append(c as CollisionObject3D)
			_livelli.append((c as CollisionObject3D).collision_layer)
	var c := get_node_or_null(cardine_path) as Node3D
	_cardine = c.global_position if c else global_position


func can_interact(_by: Node) -> bool:
	return enabled and not is_open


func _on_interact(_by: Node) -> void:
	if bloccata:
		_scossa = 0.3
		scossa_bloccata.emit()
		return
	apri()


## Si apre (anche da codice).
func apri() -> void:
	if is_open:
		return
	is_open = true
	_t = 0.0
	for c in _corpi:
		c.collision_layer = 0
	aperta.emit()


func _physics_process(delta: float) -> void:
	if _porta == null:
		return
	if is_open and _t < 1.0:
		_t = minf(_t + delta / maxf(durata, 0.01), 1.0)
		var k := 1.0 - pow(1.0 - _t, 2.5)
		_metti(deg_to_rad(angolo_apertura) * k)
		if _t >= 1.0:
			for i in _corpi.size():
				_corpi[i].collision_layer = _livelli[i]
	elif not is_open and _scossa > 0.0:
		_scossa = maxf(_scossa - delta, 0.0)
		_metti(deg_to_rad(1.2) * sin(_scossa * 60.0) * _scossa * 3.0)


func _metti(ang: float) -> void:
	var r := Transform3D(Basis(Vector3.UP, ang), Vector3.ZERO)
	var verso_cardine := Transform3D(Basis.IDENTITY, _cardine)
	_porta.global_transform = verso_cardine * r * verso_cardine.affine_inverse() * _riposo


func save_state() -> Dictionary:
	return {"aperta": is_open, "bloccata": bloccata}


func load_state(data: Dictionary) -> void:
	bloccata = bool(data.get("bloccata", true))
	if bool(data.get("aperta", false)) and _porta:
		is_open = true
		_t = 1.0
		_metti(deg_to_rad(angolo_apertura))
