@tool
class_name PolaroidPhoto
extends Collectible
## Una delle Polaroid del capitolo 1 (le 10 della scaletta, P11 la pecora che brilla dell'infermeria, P12-P16 le
## nuove della proposta del 25 ottobre notte, docs/proposte/polaroid_nuove/): il modello 3D con la sua foto. Raccolta,
## si guarda da vicino (PhotoViewer) e va nella collezione. Con [member snap_to_surface] all'avvio si appoggia sulla
## superficie sotto di sé; quelle messe da codice con [method metti] le appoggia Posa.

const TEX_DIR := "res://assets/models/polaroid/texture/"
const VIEWER := preload("res://scripts/ui/photo_viewer.gd")
const SCENA := "res://scenes/props/polaroid.tscn"
## I punti dell'impronta della foto (8,8 x 10,7 cm) per Posa.appoggia_su_impronta, negli strumenti e nei test (a gioco
## avviato, con le stanze che si costruiscono a pezzi, i raggi sotto tutta la foto fanno fotogrammi lunghi): il centro,
## gli angoli e i lati.
const IMPRONTA: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.04, 0, 0.05), Vector3(-0.04, 0, 0.05), Vector3(0.04, 0, -0.05),
	Vector3(-0.04, 0, -0.05), Vector3(0.04, 0, 0), Vector3(-0.04, 0, 0), Vector3(0, 0, 0.05), Vector3(0, 0, -0.05)]

## Numero della foto (1-10, 11 la pecora che brilla dell'infermeria, 12-16 le nuove): texture Pxx.jpg.
@export_range(1, 16) var photo := 1:
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


## Una Polaroid messa da codice sotto [param padre]: [param pos] (locale, appena sopra il sostegno) e girata di
## [param gradi]. Due fotogrammi di fisica dopo, Posa (lo strumento comune) la appoggia sulla superficie che si vede
## sotto, 4 mm sopra come lo snap di sempre. Con [param posata] [param pos] è già il posto giusto, calcolato una volta
## sola con uno strumento (la P12 sul grigliato della torre, tests/posa_polaroid12.gd): niente raggi a gioco avviato.
## L'id nella collezione è "pNN".
static func metti(padre: Node3D, foto: int, pos: Vector3, gradi: float, posata := false) -> PolaroidPhoto:
	var p := (load(SCENA) as PackedScene).instantiate() as PolaroidPhoto
	p.name = "Polaroid%02d" % foto
	p.photo = foto
	p.entry_id = StringName("p%02d" % foto)
	p.snap_to_surface = false
	p.position = pos
	p.rotation_degrees.y = gradi
	padre.add_child(p)
	if not posata:
		p._appoggia.call_deferred()
	return p


func _appoggia() -> void:
	# (nelle stanze costruite a pezzi mentre si gioca, come il fiume, il pavimento può arrivare dopo: si aspetta la fine)
	var n := get_parent()
	while n:
		while &"costruita" in n and not bool(n.get(&"costruita")) and is_inside_tree():
			await get_tree().process_frame
		n = n.get_parent()
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	# (il fiume caricato a gioco avviato entra nella scena prima del suo pavimento: si riprova finché c'è, al massimo
	# 20 secondi, poi Posa dice che non c'è niente sotto)
	for i in 120:
		if not is_inside_tree():
			return
		var da := global_position + Vector3.UP * 0.05
		var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * Posa.PORTATA, Posa.STRATI)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			break
		await get_tree().create_timer(0.17, false, true).timeout
	if is_inside_tree():
		Posa.appoggia_a_terra(self, 0.004)


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
	# (senza passare dalle crepe fra due triangoli, dove un raggio solo trova il pavimento sotto: RaggioSicuro)
	var hit := RaggioSicuro.interseca(space, q)
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
		var ha: Dictionary = RaggioSicuro.interseca(space, qa)
		if not ha.is_empty():
			alza = maxf(alza, (ha.position as Vector3).y + 0.002 - angolo.y)
	global_position.y += alza


func _on_interact(by: Node) -> void:
	var viewer: CanvasLayer = VIEWER.new()
	viewer.set(&"texture", get_texture())
	get_tree().root.add_child(viewer)
	super(by)
