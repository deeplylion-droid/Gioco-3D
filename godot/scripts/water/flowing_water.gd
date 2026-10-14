@tool
class_name FlowingWater
extends WaterVolume
## Acqua che scorre (scivoli, canali): stando qui dentro il serbatoio dello zaino si ricarica
## da solo. Si può anche aspirare (riserva infinita). La grafica è provvisoria (graybox).
## L'origine è al centro del fondo; [member size] è la dimensione dell'acqua.

@export var size := Vector3(1.2, 0.15, 5.0):
	set(value):
		size = value
		_rebuild()
## Litri al secondo ricaricati nello zaino stando nell'acqua.
@export var refill_rate := 8.0
## Corrente (m/s, spazio locale x/z): per ora muove solo la grafica.
@export var flow := Vector2(0.0, -1.2)

var _vis: Node3D
var _shape_node: CollisionShape3D


func _ready() -> void:
	super()
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	if is_instance_valid(_shape_node):
		_shape_node.free()
	_shape_node = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_shape_node.shape = shape
	_shape_node.position = Vector3(0, size.y * 0.5, 0)
	add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	surface.mesh = plane
	var mat := Graybox.WATER.duplicate() as ShaderMaterial
	var world_flow := global_transform.basis * Vector3(flow.x, 0.0, flow.y) if is_inside_tree() else Vector3(flow.x, 0.0, flow.y)
	mat.set_shader_parameter(&"flow", Vector2(world_flow.x, world_flow.z))
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = Vector3(0, size.y, 0)
	_vis.add_child(surface)
