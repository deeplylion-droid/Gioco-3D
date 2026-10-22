@tool
class_name PolaroidPhoto
extends Collectible
## Una delle 10 Polaroid del capitolo 1 (nella demo ce ne sono 9: P10 stava in cima alla torre e
## torna con la sala della torre): il modello 3D con la sua foto. Raccolta, si guarda
## da vicino (PhotoViewer) e va nella collezione. Con [member snap_to_surface] all'avvio si
## appoggia sulla superficie sotto di sé.

const TEX_DIR := "res://assets/models/polaroid/texture/"
const VIEWER := preload("res://scripts/ui/photo_viewer.gd")

## Numero della foto (1-10, 11 la pecora che brilla dell'infermeria): texture Pxx.jpg.
@export_range(1, 11) var photo := 1:
	set(value):
		photo = value
		_apply()
@export var snap_to_surface := true

static var _materials := {}


func _init() -> void:
	super()
	display_name = "Polaroid"


func _ready() -> void:
	_apply()
	if Engine.is_editor_hint():
		return
	super()
	if snap_to_surface:
		_snap.call_deferred()


func get_texture() -> Texture2D:
	return load(TEX_DIR + "P%02d.jpg" % photo) as Texture2D


func _apply() -> void:
	if not is_inside_tree():
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_inst := meshes[0] as MeshInstance3D
	if mesh_inst.mesh == null:
		return
	mesh_inst.set_surface_override_material(0, _front_material(photo))
	if mesh_inst.mesh.get_surface_count() > 1:
		mesh_inst.set_surface_override_material(1, _back_material())


static func _front_material(i: int) -> StandardMaterial3D:
	var key := "P%02d" % i
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + key + ".jpg")
	m.roughness_texture = load(TEX_DIR + key + "_rugosita.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.normal_enabled = true
	m.normal_texture = load(TEX_DIR + "normale.png")
	m.normal_scale = 0.6
	# Un filo di luce propria, così si nota anche nel buio (senza sembrare una lampada).
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.06
	_materials[key] = m
	return m


static func _back_material() -> StandardMaterial3D:
	if _materials.has("retro"):
		return _materials["retro"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX_DIR + "retro.jpg")
	m.roughness_texture = load(TEX_DIR + "retro_rugosita.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	_materials["retro"] = m
	return m


func _snap() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -4.0, 0), Layers.WORLD | Layers.PROPS)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		push_warning("Polaroid %d: niente sotto su cui appoggiarsi (%s)" % [photo, global_position])
		return
	# Su una superficie in pendenza (il fondo della piscina) si inclina con lei, se no un angolo affonda.
	var n: Vector3 = hit.normal
	if n.dot(Vector3.UP) > cos(deg_to_rad(25.0)):
		global_basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, global_rotation.y)
	else:
		n = Vector3.UP
	global_position = hit.position + n * 0.004
	# Su un fondo curvo (la conca dello scarico) la pendenza del centro non basta: se un angolo entra, si alza
	# quanto serve (controllo di posizionamento del 22 ottobre, Polaroid05).
	var alza := 0.0
	for a in [Vector3(0.07, 0, 0.07), Vector3(-0.07, 0, 0.07), Vector3(0.07, 0, -0.07), Vector3(-0.07, 0, -0.07)]:
		var angolo: Vector3 = global_transform * (a as Vector3)
		var qa := PhysicsRayQueryParameters3D.create(angolo + Vector3(0, 0.3, 0), angolo + Vector3(0, -0.3, 0), Layers.WORLD | Layers.PROPS)
		var ha: Dictionary = space.intersect_ray(qa)
		if not ha.is_empty():
			alza = maxf(alza, (ha.position as Vector3).y + 0.002 - angolo.y)
	global_position.y += alza


func _on_interact(by: Node) -> void:
	var viewer: CanvasLayer = VIEWER.new()
	viewer.set(&"texture", get_texture())
	get_tree().root.add_child(viewer)
	super(by)
