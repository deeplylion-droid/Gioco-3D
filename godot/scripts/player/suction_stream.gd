class_name SuctionStream
extends MeshInstance3D
## Aspirazione dello zaino-pompa: un filo d'acqua che si stacca dalla superficie e sale fino
## all'ugello, largo in basso e sottile in alto, con le striature che corrono verso la pistola
## (shader water_stream.gdshader), più un gorgo sulla superficie da cui si aspira.

## Il nodo dell'ugello (la sua posizione di ogni frame).
var muzzle: Node3D
## Da dove si aspira (punto sulla superficie dell'acqua).
var source_point := Vector3.ZERO
var active := false

@export var points := 26
@export var radius_base := 0.075
@export var radius_top := 0.011
## Velocità delle striature verso l'ugello (m/s).
@export var flow_speed := 4.5
## Gorgo disegnato sulla superficie (spento quando l'acqua vera fa già il suo gorgo).
@export var show_swirl := false

var _mesh := ArrayMesh.new()
var _strength := 0.0
var _swirl: MeshInstance3D
var _swirl_mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water_stream.gdshader")
	m.set_shader_parameter(&"flow_speed", flow_speed)
	m.set_shader_parameter(&"streak_density", 2.2)
	m.set_shader_parameter(&"opacity_center", 0.32)
	m.set_shader_parameter(&"opacity_edge", 0.85)
	material_override = m
	_swirl = MeshInstance3D.new()
	_swirl.name = "Gorgo"
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	q.orientation = PlaneMesh.FACE_Y
	_swirl.mesh = q
	_swirl_mat = ShaderMaterial.new()
	_swirl_mat.shader = load("res://shaders/suction_swirl.gdshader")
	_swirl.material_override = _swirl_mat
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.top_level = true
	_swirl.visible = false
	add_child(_swirl)


func _process(delta: float) -> void:
	_t += delta
	_strength = move_toward(_strength, 1.0 if active else 0.0, delta * (3.5 if active else 2.5))
	_mesh.clear_surfaces()
	_swirl.visible = show_swirl and _strength > 0.01
	if _strength <= 0.01 or muzzle == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := source_point
	var b := muzzle.global_position
	var dist := a.distance_to(b)
	# Curva un po' gonfia verso l'alto: l'acqua viene tirata su e poi verso la pistola.
	var mid := a.lerp(b, 0.45) + Vector3(0, 0.12 + 0.08 * dist, 0)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var alphas := PackedFloat32Array()
	var lengths := PackedFloat32Array()
	var along := 0.0
	var prev := a
	# Il filo cresce dalla superficie verso l'ugello quando si comincia ad aspirare.
	var reach := clampf(_strength * 1.25, 0.0, 1.0)
	for i in points:
		var t := float(i) / float(points - 1) * reach
		var u := 1.0 - t
		var p := u * u * a + 2.0 * u * t * mid + t * t * b
		# Ondeggia un poco, come un filo d'acqua vero.
		var wob := sin(_t * 9.0 + t * 11.0) * 0.012 * (1.0 - t) * dist
		p += Vector3(wob, 0.0, wob * 0.6)
		along += prev.distance_to(p)
		prev = p
		pts.append(p)
		radii.append(lerpf(radius_base, radius_top, pow(t, 0.55)) * (0.6 + 0.4 * _strength))
		alphas.append(_strength * (0.55 + 0.45 * smoothstep(0.0, 0.15, t)))
		lengths.append(along)
	var arrays := RibbonArrays.new()
	arrays.add_ribbon(pts, radii, alphas, lengths, cam.global_position)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays.to_arrays())
	_swirl.global_position = a + Vector3(0, 0.012, 0)
	_swirl_mat.set_shader_parameter(&"strength", _strength)
