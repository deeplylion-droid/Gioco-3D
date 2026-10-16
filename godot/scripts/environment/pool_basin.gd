@tool
class_name PoolBasin
extends StaticBody3D
## Vasca di una piscina con il fondo "a profilo": spiaggia in pendenza e parte profonda.
## Genera mesh e collisione da [member profile]: punti (z locale, profondità) in ordine di z.
## L'origine è al centro, all'altezza del bordo (y = 0); la vasca è larga [member width] in x.
## Grafica provvisoria: il modello vero della piscina arriverà dall'agente ambiente.

@export var width := 13.0:
	set(value):
		width = value
		_rebuild()
@export var profile := PackedVector2Array([Vector2(-11.5, 0.0), Vector2(-3.5, 1.2), Vector2(4.0, 2.4), Vector2(11.5, 2.4)]):
	set(value):
		profile = value
		_rebuild()
@export var floor_material: Material:
	set(value):
		floor_material = value
		_rebuild()
@export var wall_material: Material:
	set(value):
		wall_material = value
		_rebuild()

var _mesh_node: MeshInstance3D
var _shape_node: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_rebuild()


## Profondità del fondo alla z locale indicata.
func depth_at(z: float) -> float:
	if profile.is_empty():
		return 0.0
	if z <= profile[0].x:
		return profile[0].y
	for i in range(1, profile.size()):
		if z <= profile[i].x:
			var a := profile[i - 1]
			var b := profile[i]
			return lerpf(a.y, b.y, (z - a.x) / maxf(b.x - a.x, 0.0001))
	return profile[profile.size() - 1].y


func _rebuild() -> void:
	if not is_inside_tree() or profile.size() < 2:
		return
	if is_instance_valid(_mesh_node):
		_mesh_node.free()
	if is_instance_valid(_shape_node):
		_shape_node.free()
	var hw := width * 0.5
	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in range(1, profile.size()):
		var a := profile[i - 1]
		var b := profile[i]
		# Fondo (faccia verso l'alto).
		var p0 := Vector3(-hw, -a.y, a.x)
		var p1 := Vector3(hw, -a.y, a.x)
		var p2 := Vector3(hw, -b.y, b.x)
		var p3 := Vector3(-hw, -b.y, b.x)
		_quad(floor_st, faces, p0, p1, p2, p3)
		# Pareti laterali (facce verso l'interno).
		_quad(wall_st, faces, Vector3(-hw, 0, b.x), Vector3(-hw, 0, a.x), Vector3(-hw, -a.y, a.x), Vector3(-hw, -b.y, b.x))
		_quad(wall_st, faces, Vector3(hw, 0, a.x), Vector3(hw, 0, b.x), Vector3(hw, -b.y, b.x), Vector3(hw, -a.y, a.x))
	# Parete di fondo, dalla parte profonda.
	var last := profile[profile.size() - 1]
	if last.y > 0.01:
		_quad(wall_st, faces, Vector3(hw, 0, last.x), Vector3(-hw, 0, last.x), Vector3(-hw, -last.y, last.x), Vector3(hw, -last.y, last.x))
	var first := profile[0]
	if first.y > 0.01:
		_quad(wall_st, faces, Vector3(-hw, 0, first.x), Vector3(hw, 0, first.x), Vector3(hw, -first.y, first.x), Vector3(-hw, -first.y, first.x))
	var mesh := ArrayMesh.new()
	floor_st.generate_normals()
	floor_st.commit(mesh)
	mesh.surface_set_material(0, floor_material)
	wall_st.generate_normals()
	wall_st.commit(mesh)
	mesh.surface_set_material(1, wall_material)
	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "Vasca"
	_mesh_node.mesh = mesh
	add_child(_mesh_node, false, Node.INTERNAL_MODE_FRONT)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = shape
	add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)


## Quadrilatero p0-p1-p2-p3 in senso orario visto dalla faccia (convenzione di Godot).
func _quad(st: SurfaceTool, faces: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	for v in [p0, p1, p2, p0, p2, p3]:
		st.add_vertex(v)
		faces.append(v)
