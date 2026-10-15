@tool
class_name MedusaStatue
extends Node3D
## La medusa ferma come una statua sul piedistallo (scena S1, "il benvenuto").
## Carica il GLB della medusa (la posa di riposo è già la statua, con le mani giunte, in piedi
## sui tentacoli), mette lo shader "a gelatina" sulla campana, il materiale traslucido sui
## tentacoli, la pelle in vinile satinato e le ciocche lucide, e tiene i canali appena accesi. Con pulse() i canali pulsano a tempo per un attimo
## (quando parte la sigla); con wake_up() si stacca dal piedistallo (animazione "sveglia").
## L'origine del modello è sul piano d'appoggio: il nodo va messo sulla faccia del piedistallo.

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
## Materiale della campana (superficie "M_campana" della mesh Medusa).
@export var bell_material: ShaderMaterial:
	set(value):
		bell_material = value
		_rebuild()
## Materiale dei tentacoli (superficie "M_tentacoli").
@export var tentacle_material: Material:
	set(value):
		tentacle_material = value
		_rebuild()
## Altri materiali, ognuno sulle superfici del modello che hanno un materiale con lo stesso nome
## (resource_name): la pelle satinata (M_pelle), il labbro dell'orbita (M_orbita), le ciocche
## lucide e bagnate (M_ciocche).
@export var surface_materials: Array[Material] = []:
	set(value):
		surface_materials = value
		_rebuild()
## Materiali per nome del materiale del modello (per esempio "M_pelle" -> la pelle bagnata): hanno
## la precedenza sugli altri override.
@export var material_map: Dictionary = {}:
	set(value):
		material_map = value
		_rebuild()
## Altezza della statua (m) dal piano d'appoggio alla cima della testa: se è più di 0 il modello
## si scala per arrivarci, misurato dall'AABB delle sue mesh (0: il modello resta com'è).
@export var target_height := 0.0:
	set(value):
		target_height = value
		_rebuild()
## Distanza tra l'origine del nodo e le punte dei tentacoli (0: l'origine è sul piano).
@export var feet_depth := 0.0
@export_group("Campana")
## Luce dei canali da ferma: appena accesi.
@export var idle_channel_light := 0.55
## Luce dei canali al massimo della sigla.
@export var pulse_channel_light := 6.0
## Pulsazioni al secondo durante la sigla.
@export var pulse_rate := 1.6
## Moltiplica l'emissione delle vene luminose dei tentacoli (1 = come nel modello; il
## materiale deve avere emission_operator = Multiply, se no la texture si somma al bianco).
@export var tentacle_glow := 1.0

## Le mesh dentro la bocca: si vedono solo quando la fauce si apre.
const BOCCA := ["Medusa_Gola", "Medusa_Denti", "Medusa_Strappo"]
## Lo spessore della pelle strappata intorno alla fauce: colori dei vertici con la tinta della pelle.
const STRAPPO := "Medusa_Strappo"

var _instance: Node3D
var _bell: ShaderMaterial
var _pulse_left := 0.0
var _pulse_total := 1.0
var _t := 0.0


func _ready() -> void:
	_rebuild()


## I canali della campana pulsano a tempo per [param seconds] secondi.
func pulse(seconds := 6.0) -> void:
	_pulse_left = seconds
	_pulse_total = maxf(seconds, 0.01)


func get_model_instance() -> Node3D:
	return _instance


## Il riquadro (AABB) del modello nelle coordinate di questo nodo, scala compresa.
func get_model_aabb() -> AABB:
	if _instance == null:
		return AABB()
	return Transform3D(Basis.from_scale(_instance.scale), _instance.position) * _aabb_of(_instance)


## L'AABB di tutte le mesh sotto [param root], nelle coordinate di [param root].
static func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for vi in root.find_children("*", "GeometryInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = vi
		while n and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * (vi as VisualInstance3D).get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## La statua si sveglia: si stacca dal piedistallo e sale (animazione "sveglia").
func wake_up() -> void:
	_mostra_bocca(true)
	var ap := _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer if _instance else null
	if ap and ap.has_animation(&"sveglia"):
		ap.play(&"sveglia")
		ap.queue(&"fluttua")


## Ti prende: la fauce si apre (animazione "fauce_apre": la pelle si strappa sotto l'occhio, gola e
## denti) e l'occhio si riempie di vene (parametro "venatura" del suo materiale, da 0 a 1, su una
## copia: le altre medusa restano calme).
func attacca(durata_vene := 0.7) -> void:
	if _instance == null:
		return
	_mostra_bocca(true)
	var ap := _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(&"fauce_apre"):
		ap.play(&"fauce_apre", 0.25)
	var occhio := _instance.find_child("Medusa_Occhio", true, false) as MeshInstance3D
	var m := occhio.get_active_material(0) as ShaderMaterial if occhio else null
	if m == null:
		return
	m = m.duplicate() as ShaderMaterial
	occhio.set_surface_override_material(0, m)
	m.set_shader_parameter(&"venatura", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter(&"venatura", v), 0.0, 1.0, durata_vene)


func _process(delta: float) -> void:
	if _bell == null:
		return
	_t += delta
	var light := idle_channel_light
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
		# Sale in fretta, pulsa e si spegne piano verso la fine.
		var p := 1.0 - _pulse_left / _pulse_total
		var env := smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.7, 1.0, p))
		var beat := 0.5 + 0.5 * sin(_t * pulse_rate * TAU)
		light = lerpf(idle_channel_light, pulse_channel_light * (0.45 + 0.55 * beat), env)
	_bell.set_shader_parameter(&"luce_canali", light)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_instance):
		_instance.queue_free()
		_instance = null
	_bell = null
	if model == null:
		return
	_instance = model.instantiate() as Node3D
	if _instance == null:
		return
	_instance.name = "Modello"
	add_child(_instance, false, Node.INTERNAL_MODE_FRONT)
	# Da statua la bocca è chiusa: gola e denti stanno dentro la testa e non si vedono. Spenti
	# finché non si sveglia, così non costano niente (sul renderer software, centinaia di MB).
	_mostra_bocca(false)
	if target_height > 0.0:
		var top := _aabb_of(_instance).end.y
		if top > 0.01:
			_instance.scale = Vector3.ONE * (target_height / top)
	if bell_material:
		_bell = bell_material.duplicate() as ShaderMaterial
		_bell.set_shader_parameter(&"pulsazione_al_secondo", 0.0)
		_bell.set_shader_parameter(&"luce_canali", idle_channel_light)
	var by_name := {}
	for m in surface_materials:
		if m:
			by_name[m.resource_name] = m
	for mi in _instance.find_children("*", "MeshInstance3D", true, false):
		# La statua riceve l'illuminazione globale ma non entra nel VoxelGI calcolato in
		# anticipo: così il calcolo non dipende dal modello della medusa.
		(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			if mat == null:
				continue
			if mat.resource_name == "M_campana" and _bell:
				(mi as MeshInstance3D).set_surface_override_material(s, _bell)
			elif mat.resource_name == "M_tentacoli" and tentacle_material:
				var tm := tentacle_material.duplicate() as Material
				if tm is BaseMaterial3D:
					(tm as BaseMaterial3D).emission_energy_multiplier *= tentacle_glow
				(mi as MeshInstance3D).set_surface_override_material(s, tm)
			elif by_name.has(mat.resource_name):
				(mi as MeshInstance3D).set_surface_override_material(s, by_name[mat.resource_name])
			if material_map.has(mat.resource_name) and material_map[mat.resource_name] is Material:
				(mi as MeshInstance3D).set_surface_override_material(s, material_map[mat.resource_name])
	_tinta_strappo()
	_dopo_rebuild()


## Il bordo della pelle strappata (Medusa_Strappo, dentro la blend shape fauce_aperta) prende la
## tinta della pelle del viso (LEGGIMI della medusa): colori dei vertici per pelle, rosa e carne.
func _tinta_strappo() -> void:
	var strappo := _instance.find_child(STRAPPO, true, false) as MeshInstance3D
	if strappo == null or strappo.mesh == null or strappo.mesh.get_surface_count() == 0:
		return
	var base := strappo.mesh.surface_get_material(0) as BaseMaterial3D
	if base == null:
		return
	var tinta := Color(0.74, 0.8, 1.0)
	var corpo := _instance.find_child("Medusa", true, false) as MeshInstance3D
	if corpo and corpo.mesh and corpo.mesh.get_surface_count() > 0:
		var pelle := corpo.get_surface_override_material(0) as BaseMaterial3D
		if pelle:
			tinta = pelle.albedo_color
	var m := base.duplicate() as BaseMaterial3D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tinta
	strappo.set_surface_override_material(0, m)


## Per le sottoclassi: il modello è appena stato creato (animazioni, ossa, effetti).
func _dopo_rebuild() -> void:
	pass


## Gola e denti (dentro la bocca chiusa) visibili o no.
func _mostra_bocca(on: bool) -> void:
	if _instance == null:
		return
	for nome in BOCCA:
		var n := _instance.find_child(nome, true, false) as Node3D
		if n:
			n.visible = on
