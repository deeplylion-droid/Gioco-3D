@tool
class_name Ladder
extends Area3D
## Scala a pioli. Nell'area il giocatore si aggrappa camminando verso la scala (o cadendoci
## sopra) e sale con W, scende con S (o con W guardando in basso); Spazio per staccarsi.
## L'origine è alla base, al centro; la scala sale lungo +Y appoggiata a un muro dal lato -Z:
## il giocatore sta dal lato +Z. Arrivato in cima scavalca da solo il bordo.

@export var height := 3.0:
	set(value):
		height = value
		_rebuild()
@export var width := 0.7:
	set(value):
		width = value
		_rebuild()
@export var rung_spacing := 0.3:
	set(value):
		rung_spacing = value
		_rebuild()
## Se falso non disegna la scala (quando la scala vera fa parte del modello dell'ambiente).
@export var show_model := true:
	set(value):
		show_model = value
		_rebuild()

var _vis: Node3D
var _shape_node: CollisionShape3D


func _init() -> void:
	collision_layer = Layers.LADDERS
	collision_mask = 0
	monitoring = false


func _ready() -> void:
	_rebuild()


## Direzione orizzontale che esce dal muro verso il giocatore.
func get_climb_normal() -> Vector3:
	var n := global_transform.basis.z
	n.y = 0.0
	return n.normalized()


## Quota globale della cima della scala.
func get_top_y() -> float:
	return global_position.y + height


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	if is_instance_valid(_shape_node):
		_shape_node.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	for side in ([-1.0, 1.0] if show_model else []):
		Graybox.box(_vis, Vector3(0.06, height + 0.4, 0.06), Vector3(side * width * 0.5, (height + 0.4) * 0.5, 0.1), Graybox.DARK)
	var y := 0.3
	while show_model and y < height + 0.05:
		var rung := Graybox.cylinder(_vis, 0.022, width, Vector3(0, y, 0.1), Graybox.TARGET)
		rung.rotation = Vector3(0, 0, PI * 0.5)
		y += rung_spacing
	_shape_node = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.2, height + 0.4, 0.75)
	_shape_node.shape = shape
	_shape_node.position = Vector3(0, (height + 0.4) * 0.5, 0.33)
	add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
