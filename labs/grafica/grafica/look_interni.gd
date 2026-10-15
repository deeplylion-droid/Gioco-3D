class_name LookInterni
extends Node3D
## Look degli interni (corridoio del risveglio, spogliatoi, stanzino): luci a pozze,
## illuminazione globale per stanza, Environment proprio quando la camera è dentro.
## Va messo come figlio della scena degli interni (scenes/interni/luci_interni.tscn),
## separato dai modelli: chi rifà modelli e texture non tocca le luci.
##
## Cosa fa all'avvio (dopo che interni.gd ha creato i Neon e le LuceEmergenza):
## - regola per nome le luci: rosse d'emergenza più raccolte (pozze di rosso, non pareti
##   tutte rosse), neon freddi che fanno le pozze di luce, la lampada calda dello zaino;
## - crea un VoxelGI per stanza, con i dati cotti in [member cartella_gi] se ci sono;
## - quando la camera è dentro gli interni le dà [member ambiente] e [member attributi]
##   (in gioco gli interni stanno dentro la sala, che ha un Environment diverso).

@export var ambiente: Environment = preload("res://grafica/interni/ambiente_interni.tres")
@export var attributi: CameraAttributesPractical = preload("res://grafica/interni/attributi_interni.tres")
## Nodo con i modelli delle stanze (figli diretti = stanze), relativo al genitore.
@export var percorso_ambienti := NodePath("Ambienti")
## Dove stanno i dati del VoxelGI cotti (uno per stanza: <nome stanza>.res).
@export_dir var cartella_gi := ""
@export var crea_gi := true
@export_group("Luci")
@export var energia_emergenza := 1.7
@export var portata_emergenza := 4.2
@export var colore_emergenza := Color(1.0, 0.05, 0.03)
@export var energia_neon := 3.0
@export var portata_neon := 7.5
@export var colore_neon := Color(0.76, 0.98, 0.9)
@export var energia_zaino := 2.6

var _ambienti: Node3D
var _zona := AABB()
var _dentro := false
var _cam_env_prima: Environment
var _cam_attr_prima: CameraAttributes


func _ready() -> void:
	_ambienti = get_parent().get_node_or_null(percorso_ambienti) as Node3D
	# Le luci le crea interni.gd nel suo _ready, che arriva dopo quello dei figli.
	_prepara.call_deferred()


func _prepara() -> void:
	if _ambienti == null:
		push_warning("LookInterni: non trovo %s" % percorso_ambienti)
		return
	_regola_luci()
	_pozze_opache()
	for stanza in _ambienti.get_children():
		if stanza is Node3D:
			var box := _aabb(stanza)
			_zona = box if _zona.size == Vector3.ZERO else _zona.merge(box)
			if crea_gi:
				_crea_gi(stanza, box)
	_zona = _zona.grow(0.3)


func _regola_luci() -> void:
	var radice := get_parent()
	for n in radice.find_children("*", "Node3D", true, false):
		var nome := String(n.name)
		var cls: String = n.get_script().get_global_name() if n.get_script() else ""
		if cls == "LuceEmergenza":
			# Pozze di rosso raccolte attorno alla lampada: il resto della parete resta buio.
			n.set(&"colore", colore_emergenza)
			n.set(&"energia", energia_emergenza)
			n.set(&"portata", portata_emergenza)
			n.set(&"energia_nebbia", 0.7)
			for l in n.find_children("*", "OmniLight3D", true, false):
				var o := l as OmniLight3D
				o.light_color = colore_emergenza
				o.light_energy = energia_emergenza
				o.omni_range = portata_emergenza
				o.omni_attenuation = 1.8
				o.light_specular = 0.5
		elif cls == "Neon":
			# I neon fanno la luce "di lavoro": freddi, morbidi, con ombre.
			for l in n.find_children("*", "Light3D", true, false):
				var luce := l as Light3D
				luce.light_color = colore_neon
				luce.light_energy = energia_neon
				luce.light_volumetric_fog_energy = 0.25
				luce.shadow_enabled = true
				luce.shadow_blur = 1.5
				if luce is OmniLight3D:
					(luce as OmniLight3D).omni_range = portata_neon
					(luce as OmniLight3D).omni_attenuation = 1.4
			# Neon salva le energie iniziali in _ready: le aggiorniamo.
			var energie: Array[float] = []
			for l in n.find_children("*", "Light3D", true, false):
				energie.append((l as Light3D).light_energy)
			n.set(&"_energie", energie)
		elif nome == "LuceZaino" and n is SpotLight3D:
			# L'unica luce calda: lo zaino si fa notare.
			var s := n as SpotLight3D
			s.light_color = Color(1.0, 0.72, 0.42)
			s.light_energy = energia_zaino
			s.light_size = 0.08
			s.shadow_enabled = true
			s.light_volumetric_fog_energy = 0.6


## Pozze d'acqua opache e lucidissime, appena sopra il pavimento. Erano trasparenti: in
## Godot i trasparenti non ricevono gli SSR e riflettevano solo il VoxelGI, sfocato e con
## i bordi del poligono ("forme fantasma" sul pavimento). Opache, riflettono netto.
func _pozze_opache() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.045, 0.045)
	m.roughness = 0.05
	m.metallic = 0.0
	m.metallic_specular = 0.6
	for n in _ambienti.find_children("acqua_pozz*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y += 0.003   # niente z-fighting con il pavimento


func _crea_gi(stanza: Node3D, box: AABB) -> void:
	var gi := VoxelGI.new()
	gi.name = "GI_" + stanza.name
	gi.size = box.size + Vector3.ONE * 0.4
	gi.subdiv = VoxelGI.SUBDIV_128
	var file := cartella_gi.path_join(String(stanza.name) + ".res")
	if cartella_gi != "" and ResourceLoader.exists(file):
		gi.data = load(file)
		gi.set_meta("grafica_bake_automatico", false)
	gi.set_meta("stanza", stanza)
	if gi.data == null:
		gi.set_meta("grafica_bake_automatico", false)  # il bake generico cercherebbe nei figli sbagliati
	add_child(gi)
	gi.global_position = box.get_center()
	if gi.data == null and is_instance_valid(Grafica) and int(Grafica.valore("gi")) == 1:
		gi.bake(stanza)  # senza dati cotti: calcolo all'avvio (lento, solo per le prove)


## Calcola i dati del VoxelGI di ogni stanza e li salva in cartella_gi (da lanciare una
## volta, a luci a posto; vedi tests/cuoci_gi_interni.gd).
func cuoci_gi() -> void:
	DirAccess.make_dir_recursive_absolute(cartella_gi)
	# Le lampade emissive non vanno "cotte" nel GI: la loro luce la fanno le Light3D, che
	# il VoxelGI segue in tempo reale. Cotte, resterebbero accese anche al buio.
	var spente := _spegni_emissioni()
	for gi in find_children("GI_*", "VoxelGI", false, false):
		var v := gi as VoxelGI
		v.bake(v.get_meta("stanza"))   # la geometria sta nella stanza, non tra i figli di LookInterni
		var file := cartella_gi.path_join(String(v.name).trim_prefix("GI_") + ".res")
		print("GI ", v.name, " celle ", v.data.get_octree_cells().size(), " dati ", v.data.get_data_cells().size(),
			" -> ", file, " ", ResourceSaver.save(v.data, file))
	_ripristina_emissioni(spente)


## Toglie l'emissione a tutte le superfici emissive degli interni; restituisce cosa ripristinare.
func _spegni_emissioni() -> Array:
	var fatte := []
	for n in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
				var copia := mat.duplicate() as BaseMaterial3D
				copia.emission_enabled = false
				fatte.append([mi, i, mi.get_surface_override_material(i)])
				mi.set_surface_override_material(i, copia)
	return fatte


func _ripristina_emissioni(fatte: Array) -> void:
	for f in fatte:
		(f[0] as MeshInstance3D).set_surface_override_material(f[1], f[2])


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _zona.size == Vector3.ZERO:
		return
	var dentro := _zona.has_point(cam.global_position)
	if dentro == _dentro:
		return
	_dentro = dentro
	if dentro:
		_cam_env_prima = cam.environment
		_cam_attr_prima = cam.attributes
		cam.environment = ambiente
		cam.attributes = attributi
	else:
		cam.environment = _cam_env_prima
		cam.attributes = _cam_attr_prima
	if is_instance_valid(Grafica):
		Grafica.aggiorna_environment()


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	return box
