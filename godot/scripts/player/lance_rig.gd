@tool
class_name LanceRig
extends Node3D
## Lancia dello zaino-pompa in prima persona, con le mani.
## Allinea il modello 3D (GLB) in modo che il tubo punti dritto in avanti (-Z) con la punta
## nell'origine, dove sta il nodo "Muzzle" da cui esce l'acqua. Le mani (guanti) si mettono
## sull'impugnatura e sul tubo. Per cambiare aspetto basta un'altra scena con un altro modello.

## Il modello della lancia.
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		_rebuild()
## Punta della lancia (uscita dell'acqua) nelle coordinate del modello.
@export var tip_point := Vector3.ZERO:
	set(value):
		tip_point = value
		_rebuild()
## Un punto più indietro sullo stesso tubo, sempre nelle coordinate del modello.
@export var tube_point := Vector3(0, 0, 0.3):
	set(value):
		tube_point = value
		_rebuild()

@export_group("Mano destra")
@export var right_hand_scene: PackedScene:
	set(value):
		right_hand_scene = value
		_rebuild()
## Posizione (rispetto alla punta, con +Z verso chi guarda) e rotazione in gradi.
@export var right_hand_position := Vector3(0, -0.1, 0.45):
	set(value):
		right_hand_position = value
		_rebuild()
@export var right_hand_rotation := Vector3.ZERO:
	set(value):
		right_hand_rotation = value
		_rebuild()
## Specchia la mano (per usare la stessa mano a sinistra e a destra).
@export var right_hand_mirror := false:
	set(value):
		right_hand_mirror = value
		_rebuild()

@export_group("Mano sinistra")
@export var left_hand_scene: PackedScene:
	set(value):
		left_hand_scene = value
		_rebuild()
@export var left_hand_position := Vector3(0, 0, 0.2):
	set(value):
		left_hand_position = value
		_rebuild()
@export var left_hand_rotation := Vector3.ZERO:
	set(value):
		left_hand_rotation = value
		_rebuild()
@export var left_hand_mirror := false:
	set(value):
		left_hand_mirror = value
		_rebuild()

var _vis: Node3D


func _ready() -> void:
	_rebuild()


## Trasformazione che porta il modello nel sistema della lancia (punta nell'origine, avanti = -Z).
func get_alignment() -> Transform3D:
	var d := tip_point - tube_point
	if d.length_squared() < 0.000001:
		return Transform3D(Basis.IDENTITY, -tip_point)
	var r := Basis.looking_at(d.normalized(), Vector3.UP).inverse()
	return Transform3D(r, -(r * tip_point))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Modelli"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	if model_scene:
		var m := model_scene.instantiate() as Node3D
		m.transform = get_alignment()
		_vis.add_child(m)
	_add_hand(right_hand_scene, right_hand_position, right_hand_rotation, right_hand_mirror)
	_add_hand(left_hand_scene, left_hand_position, left_hand_rotation, left_hand_mirror)
	_set_layers(_vis)


func _add_hand(scene: PackedScene, pos: Vector3, rot_deg: Vector3, mirror: bool) -> void:
	if scene == null:
		return
	var h := scene.instantiate() as Node3D
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	if mirror:
		b = Basis.from_scale(Vector3(-1, 1, 1)) * b
	h.transform = Transform3D(b, pos)
	_vis.add_child(h)


## Il viewmodel sta sul livello di rendering 2 ("viewmodel") e non fa ombre strane.
func _set_layers(n: Node) -> void:
	var gi := n as GeometryInstance3D
	if gi:
		gi.layers = 2
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layers(c)
