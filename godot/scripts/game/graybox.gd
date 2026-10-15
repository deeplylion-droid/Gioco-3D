@tool
class_name Graybox
## Materiali e forme semplici per i prototipi graybox (niente asset definitivi).
## I componenti (turbina, pulsante, porta...) si costruiscono la grafica provvisoria da soli:
## quando arriveranno i modelli veri si sostituisce questa parte.

const FLOOR := preload("res://assets/materials/graybox_floor.tres")
const WALL := preload("res://assets/materials/graybox_wall.tres")
const DARK := preload("res://assets/materials/graybox_dark.tres")
const WET := preload("res://assets/materials/graybox_wet.tres")
const TARGET := preload("res://assets/materials/graybox_target.tres")
const PICKUP := preload("res://assets/materials/graybox_pickup.tres")
const ENEMY := preload("res://assets/materials/graybox_enemy.tres")
const FLOAT := preload("res://assets/materials/graybox_float.tres")
const WATER := preload("res://assets/materials/water_placeholder.tres")


static func box(parent: Node, size: Vector3, pos := Vector3.ZERO, material: Material = WALL, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node, radius: float, height: float, pos := Vector3.ZERO, material: Material = DARK, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


## Materiale emissivo semplice (spie, lampade di stato).
static func lamp_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Collisione a scatola (figlia di un corpo o di un'area).
static func box_shape(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)
	return cs
