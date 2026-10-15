@tool
class_name WaterPuddle
extends MeshInstance3D
## Pozzanghera da appoggiare sul pavimento: mesh piatta di forma irregolare (generata) con il
## materiale `materials/pozzanghera.tres` (specchio d'acqua scuro con i cerchi delle gocce).
## Con `snap_to_floor` all'avvio scende da sola sulla collisione sotto di lei.

const DEFAULT_MATERIAL := preload("res://addons/acqua/materials/pozzanghera.tres")

## Dimensioni in pianta (m), prima delle irregolarita' del contorno.
@export var size := Vector2(2.0, 1.3):
	set(v):
		size = v
		_rebuild()
## Quanto il contorno e' frastagliato (0 = ellisse).
@export_range(0.0, 0.6, 0.01) var irregularity := 0.28:
	set(v):
		irregularity = v
		_rebuild()
## Cambia la forma.
@export var shape_seed := 1:
	set(v):
		shape_seed = v
		_rebuild()
## Altezza sopra il pavimento (m).
@export var lift := 0.004:
	set(v):
		lift = v
		_rebuild()
## All'avvio cerca il pavimento sotto (raggio verso il basso fino a 2 m) e ci si appoggia.
@export var snap_to_floor := true

var _snapped := false


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material_override == null:
		material_override = DEFAULT_MATERIAL
	_rebuild()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _snapped or not snap_to_floor:
		set_physics_process(false)
		return
	_snapped = true
	set_physics_process(false)
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5)
	var hit := space.intersect_ray(q)
	if hit:
		global_position.y = (hit["position"] as Vector3).y


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(shape_seed)
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var n := 48
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var r := 1.0 + irregularity * (0.55 * sin(2.0 * a + ph[0]) + 0.35 * sin(3.0 * a + ph[1])
				+ 0.22 * sin(5.0 * a + ph[2]) + 0.12 * sin(8.0 * a + ph[3]))
		r = maxf(r, 0.25)
		ring.append(Vector3(cos(a) * size.x * 0.5 * r, lift, sin(a) * size.y * 0.5 * r))
	var c := Vector3(0.0, lift, 0.0)
	for i in n:
		var p0 := ring[i]
		var p1 := ring[(i + 1) % n]
		# Godot: facce davanti in senso orario viste da sopra
		for p in [c, p0, p1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x / maxf(size.x, 0.01) + 0.5, p.z / maxf(size.y, 0.01) + 0.5))
			st.add_vertex(p)
	mesh = st.commit()
