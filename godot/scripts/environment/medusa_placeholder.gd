@tool
class_name MedusaPlaceholder
extends Node3D
## Segnaposto della medusa come statua, fatto di forme semplici, finché non arriva il modello
## vero (sta dentro un AssetSlot: il GLB della medusa lo sostituisce).
## L'origine è dove i tentacoli toccano il piedistallo; guarda verso +Z. Alta circa 2,6 m.
## pulse(): i canali della campana pulsano per qualche secondo (quando parte la sigla).

## Luce della campana a riposo ("appena accesa").
@export var bell_glow := 0.35
@export var bell_color := Color(0.95, 0.45, 0.85)

var _bell_mat: StandardMaterial3D
var _pulse_left := 0.0
var _vis: Node3D


func _ready() -> void:
	_rebuild()


func pulse(seconds := 6.0) -> void:
	_pulse_left = seconds


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _bell_mat == null:
		return
	if _pulse_left > 0.0:
		_pulse_left -= delta
		var beat := pow(absf(sin(_pulse_left * PI * 2.2)), 3.0)
		_bell_mat.emission_energy_multiplier = bell_glow + 2.6 * beat
	else:
		_bell_mat.emission_energy_multiplier = bell_glow


func _mat(color: Color, rough := 0.3, emission := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _shape(mesh: Mesh, pos: Vector3, mat: Material, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = mat
	_vis.add_child(mi)
	return mi


## Capsula tra due punti (braccia, tentacoli).
func _limb(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = a.distance_to(b) + r * 2.0
	c.radial_segments = 12
	c.rings = 4
	var mi := _shape(c, (a + b) * 0.5, mat)
	var d := (b - a).normalized()
	var x := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, d, x.cross(d))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	var skin := _mat(Color(0.62, 0.66, 0.93), 0.22)
	var hair := _mat(Color(0.93, 0.8, 0.88), 0.4)
	var tentacle := _mat(Color(0.72, 0.12, 0.42), 0.35, 0.15)
	_bell_mat = _mat(bell_color, 0.15, bell_glow, 0.78)
	_bell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Tentacoli.
	for i in 12:
		var a := TAU * i / 12.0
		var top := Vector3(cos(a) * 0.38, 1.02, sin(a) * 0.38)
		var bottom := Vector3(cos(a + 0.25) * 0.5, 0.05, sin(a + 0.25) * 0.5)
		var mid := (top + bottom) * 0.5 + Vector3(cos(a + 1.2) * 0.08, 0, sin(a + 1.2) * 0.08)
		_limb(top, mid, 0.045, tentacle)
		_limb(mid, bottom, 0.035, tentacle)
	# Campana.
	var bell := SphereMesh.new()
	bell.radius = 0.62
	bell.height = 0.62
	bell.is_hemisphere = true
	_shape(bell, Vector3(0, 0.98, 0), _bell_mat, Vector3(1, 0.85, 1))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.56
	rim.outer_radius = 0.66
	_shape(rim, Vector3(0, 0.99, 0), _mat(Color(0.98, 0.75, 0.9), 0.3, 0.2))
	# Busto, testa, capelli, occhio.
	var torso := CapsuleMesh.new()
	torso.radius = 0.17
	torso.height = 0.8
	_shape(torso, Vector3(0, 1.72, 0), skin)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.42
	_shape(head, Vector3(0, 2.3, 0.0), skin)
	var hair_m := SphereMesh.new()
	hair_m.radius = 0.25
	hair_m.height = 0.42
	_shape(hair_m, Vector3(0, 2.38, -0.05), hair, Vector3(1.05, 1.0, 1.0))
	var eye := SphereMesh.new()
	eye.radius = 0.1
	eye.height = 0.2
	_shape(eye, Vector3(0, 2.3, 0.15), _mat(Color(0.97, 0.95, 0.95), 0.08))
	var iris := SphereMesh.new()
	iris.radius = 0.055
	iris.height = 0.11
	_shape(iris, Vector3(0, 2.3, 0.215), _mat(Color(0.95, 0.3, 0.55), 0.1, 0.6))
	var pupil := SphereMesh.new()
	pupil.radius = 0.024
	pupil.height = 0.048
	_shape(pupil, Vector3(0, 2.3, 0.262), _mat(Color(0.05, 0.02, 0.03), 0.1))
	# Braccia con le mani giunte sul petto.
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.22, 2.0, 0.0)
		var elbow := Vector3(side * 0.26, 1.72, 0.14)
		var hand := Vector3(side * 0.04, 1.86, 0.24)
		_limb(shoulder, elbow, 0.055, skin)
		_limb(elbow, hand, 0.048, skin)
	# Collisione: non si passa attraverso la statua.
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	_vis.add_child(body)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.62
	cyl.height = 2.5
	cs.shape = cyl
	cs.position = Vector3(0, 1.25, 0)
	body.add_child(cs)
