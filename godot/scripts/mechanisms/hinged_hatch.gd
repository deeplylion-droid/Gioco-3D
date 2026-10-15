class_name HingedHatch
extends Node3D
## Portello o cancello a cerniera: quando una delle sorgenti è accesa (turbina, pulsante...)
## ruota il nodo indicato intorno al suo perno, una volta sola (resta aperto). Il nodo è di
## solito un pezzo del modello dell'ambiente con l'origine sulla cerniera; se ha la sua
## collisione come figlia, si muove con lui.

signal opened

@export var sources: Array[PowerSource] = []
## Il pezzo da ruotare (origine sulla cerniera).
@export var target_path: NodePath
## Asse di rotazione nelle coordinate del genitore del pezzo.
@export var axis := Vector3.RIGHT
## Angolo di apertura (gradi, col segno) e durata.
@export var open_angle := -100.0
@export var open_time := 1.6

var is_open := false

var _target: Node3D
var _base := Basis.IDENTITY
var _t := 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		_base = _target.basis
	for s in sources:
		if s:
			s.powered_changed.connect(_on_source)
	add_to_group(&"persist")


func _on_source(_on: bool) -> void:
	if is_open:
		return
	for s in sources:
		if s and s.powered:
			open()
			return


func open() -> void:
	if is_open:
		return
	is_open = true
	opened.emit()


func _physics_process(delta: float) -> void:
	if not is_open or _target == null or _t >= 1.0:
		return
	_t = minf(_t + delta / maxf(open_time, 0.01), 1.0)
	# Parte piano, accelera e si ferma con un piccolo rimbalzo.
	var k := _t * _t * (3.0 - 2.0 * _t)
	k += sin(_t * PI) * 0.06 * _t
	_target.basis = Basis(axis.normalized(), deg_to_rad(open_angle) * k) * _base


func save_state() -> Dictionary:
	return {"open": is_open}


func load_state(data: Dictionary) -> void:
	if bool(data.get("open", false)):
		is_open = true
		_t = 0.999
