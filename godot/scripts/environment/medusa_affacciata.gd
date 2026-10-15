@tool
class_name MedusaAffacciata
extends MedusaStatue
## La medusa vera affacciata alla vasca al centro della sala (v0.2.1): immersa fino al seno, le mani
## aggrappate al bordo, sbircia chi entra con l'occhio all'altezza dei suoi occhi. Animazione
## "affacciata" in ciclo (solo il respiro), aspetto bagnato (materiali in override per nome,
## material_map), l'occhio che segue il giocatore (osso "occhio", al massimo [member angolo_occhio]
## gradi) e qualche goccia che cade da dita, mento, capelli e tentacoli.
## L'origine del modello è al livello del pavimento della sala (LEGGIMI della medusa).

## L'animazione della posa, messa in ciclo e fatta partire subito.
@export var animazione: StringName = &"affacciata"
## L'osso dell'occhio: il suo asse Y è la direzione dello sguardo.
@export var osso_occhio := "occhio"
## Quanto l'occhio può girarsi dalla posa per seguirti (gradi).
@export var angolo_occhio := 15.0
## Da dove cadono le gocce (coordinate locali del nodo): dita, mento, punte dei capelli, tentacoli.
@export var punti_gocce := PackedVector3Array()

var _bersaglio: Node3D
var _occhio: LookAtModifier3D
var _gocce: Array[Node3D] = []
# Posizione e direzione dell'occhio lette a fine aggiornamento dello scheletro (con lo sguardo).
var _pos_occhio := Vector3.ZERO
var _dir_occhio := Vector3.BACK


func _dopo_rebuild() -> void:
	for g in _gocce:
		if is_instance_valid(g):
			g.queue_free()
	_gocce.clear()
	if _instance == null:
		return
	var ap := _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(animazione):
		ap.get_animation(animazione).loop_mode = Animation.LOOP_LINEAR
		ap.play(animazione)
	if Engine.is_editor_hint():
		return
	# L'occhio segue un bersaglio che sta sulla testa del giocatore (aggiornato a ogni frame).
	var skeletons := _instance.find_children("*", "Skeleton3D", true, false)
	var sk := skeletons[0] as Skeleton3D if skeletons.size() > 0 else null
	if sk and sk.find_bone(osso_occhio) >= 0:
		if _bersaglio == null:
			_bersaglio = Node3D.new()
			_bersaglio.name = "BersaglioOcchio"
			_bersaglio.top_level = true
			add_child(_bersaglio, false, Node.INTERNAL_MODE_BACK)
		_bersaglio.global_position = _occhio_globale(sk) + global_basis.z * 3.0
		_occhio = LookAtModifier3D.new()
		_occhio.name = "SguardoOcchio"
		_occhio.bone_name = osso_occhio
		_occhio.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Y
		# Lo sguardo è l'asse Y: le due rotazioni sono intorno a Z (destra-sinistra) e X (su-giù).
		_occhio.primary_rotation_axis = Vector3.AXIS_Z
		_occhio.use_secondary_rotation = true
		_occhio.use_angle_limitation = true
		_occhio.symmetry_limitation = true
		_occhio.primary_limit_angle = deg_to_rad(angolo_occhio * 2.0)
		_occhio.secondary_limit_angle = deg_to_rad(angolo_occhio * 2.0)
		_occhio.duration = 0.35
		sk.add_child(_occhio)
		_occhio.target_node = _occhio.get_path_to(_bersaglio)
		var bone := sk.find_bone(osso_occhio)
		_pos_occhio = _occhio_globale(sk)
		sk.skeleton_updated.connect(func():
			# Mentre il livello si ricarica (morte, ripartenza) lo scheletro può aggiornarsi già
			# fuori dall'albero: lì non ha una posizione nel mondo.
			if not sk.is_inside_tree():
				return
			var pose := sk.get_bone_global_pose(bone)
			_pos_occhio = sk.global_transform * pose.origin
			_dir_occhio = (sk.global_basis * pose.basis).y.normalized())
	for p in punti_gocce:
		var g := WaterDripEmitter.new()
		g.name = "Gocce"
		g.interval_min = 1.4
		g.interval_max = 4.5
		g.jitter = 0.01
		g.position = p
		add_child(g, false, Node.INTERNAL_MODE_BACK)
		_gocce.append(g)


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or _bersaglio == null:
		return
	var p := GameState.player
	if p and is_instance_valid(p):
		_bersaglio.global_position = p.camera.global_position


## Dove sta l'occhio adesso (coordinate del mondo, con lo sguardo applicato).
func get_eye_position() -> Vector3:
	return _pos_occhio


## La direzione dello sguardo adesso (asse Y dell'osso dell'occhio, nel mondo).
func get_eye_direction() -> Vector3:
	return _dir_occhio


func _occhio_globale(sk: Skeleton3D) -> Vector3:
	var b := sk.find_bone(osso_occhio)
	if b < 0:
		return sk.global_position
	return sk.global_transform * sk.get_bone_global_pose(b).origin
