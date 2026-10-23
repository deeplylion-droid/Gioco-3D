@tool
class_name MedusaAffacciata
extends MedusaStatue
## La medusa vera affacciata alla vasca al centro della sala (v0.2.1): immersa fino al seno, le mani
## aggrappate al bordo, sbircia chi entra con l'occhio all'altezza dei suoi occhi. Animazione
## "affacciata" in ciclo (solo il respiro), aspetto bagnato (materiali in override per nome,
## material_map), l'occhio che segue il giocatore (osso "occhio", al massimo [member angolo_occhio]
## gradi) e qualche goccia che cade da dita, mento, capelli e tentacoli.
## L'origine del modello è al livello del pavimento della sala (LEGGIMI della medusa).
## Easter egg: chiudi_occhio(secondi) (della MedusaStatue) abbassa la palpebra, bagnata come la pelle.

const MATERIALE_PALPEBRE_BAGNATA := "res://assets/models/medusa/medusa_palpebre_bagnata.tres"
## Le animazioni dell'inseguimento (tools/blender/medusa_inseguimento.py): "inseguimento/<nome>".
const ANIMAZIONI_INSEGUIMENTO := "res://assets/models/medusa/medusa_inseguimento.res"

## L'animazione della posa, messa in ciclo e fatta partire subito.
@export var animazione: StringName = &"affacciata"
## L'osso dell'occhio: il suo asse Y è la direzione dello sguardo.
@export var osso_occhio := "occhio"
## Quanto l'occhio può girarsi dalla posa per seguirti (gradi).
@export var angolo_occhio := 15.0
## Aggiunge all'AnimationPlayer le animazioni dell'inseguimento ("inseguimento/sale_dall_acqua",
## "inseguimento/incombe", "inseguimento/presa", ...): vedi tools/blender/medusa_inseguimento.py.
@export var animazioni_inseguimento := false
## Quanto la testa può girarsi per seguire il giocatore, con segui_con_la_testa() (gradi).
@export var angolo_testa := 35.0
## Da dove cadono le gocce (coordinate locali del nodo): dita, mento, punte dei capelli, tentacoli.
@export var punti_gocce := PackedVector3Array()
## Se falso, ai punti_gocce non cadono gocce (i punti servono lo stesso, per esempio a LeiSbuca).
@export var gocce := true
## I tentacoli si piegano contro i muri invece di entrarci (TentacoliControIMuri, sopra l'animazione).
@export var tentacoli_contro_i_muri := false
## Con tentacoli_contro_i_muri: la posa dei tentacoli già calcolata (TentacoliControIMuri.posa_fissa), se c'è.
@export_file("*.json") var tentacoli_posa_fissa := ""

var _bersaglio: Node3D
var _occhio: LookAtModifier3D
var _testa: LookAtModifier3D
var _tw_testa: Tween
var _gocce: Array[Node3D] = []
var _tentacoli: TentacoliControIMuri
var _esclusi_tentacoli: Array[RID] = []
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
	if ap and animazioni_inseguimento and not ap.has_animation_library(&"inseguimento") \
			and ResourceLoader.exists(ANIMAZIONI_INSEGUIMENTO):
		ap.add_animation_library(&"inseguimento", load(ANIMAZIONI_INSEGUIMENTO) as AnimationLibrary)
	if ap and ap.has_animation(animazione):
		ap.get_animation(animazione).loop_mode = Animation.LOOP_LINEAR
		ap.play(animazione)
	if Engine.is_editor_hint():
		return
	# L'occhio segue un bersaglio che sta sulla testa del giocatore (aggiornato a ogni frame).
	var skeletons := _instance.find_children("*", "Skeleton3D", true, false)
	var sk := skeletons[0] as Skeleton3D if skeletons.size() > 0 else null
	if sk and tentacoli_contro_i_muri:
		_tentacoli = TentacoliControIMuri.new()
		_tentacoli.name = "TentacoliControIMuri"
		_tentacoli.esclusi = _esclusi_tentacoli
		_tentacoli.posa_fissa = tentacoli_posa_fissa
		sk.add_child(_tentacoli)
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
		# la testa che segue il giocatore (spenta: segui_con_la_testa); prima dell'occhio
		if sk.find_bone("testa") >= 0:
			_testa = LookAtModifier3D.new()
			_testa.name = "SguardoTesta"
			_testa.bone_name = "testa"
			# l'osso della testa va dal collo alla cima: il viso guarda lungo l'asse dell'osso più vicino a
			# +Z (lei guarda verso +Z), e gira a destra e sinistra intorno a quello più vicino all'alto
			var rb := sk.get_bone_global_rest(sk.find_bone("testa")).basis
			var av := _asse(rb, Vector3.BACK)
			_testa.forward_axis = [SkeletonModifier3D.BONE_AXIS_PLUS_X, SkeletonModifier3D.BONE_AXIS_MINUS_X,
				SkeletonModifier3D.BONE_AXIS_PLUS_Y, SkeletonModifier3D.BONE_AXIS_MINUS_Y,
				SkeletonModifier3D.BONE_AXIS_PLUS_Z, SkeletonModifier3D.BONE_AXIS_MINUS_Z][av.x * 2 + (0 if av.y > 0 else 1)]
			_testa.primary_rotation_axis = _asse(rb, Vector3.UP).x as Vector3.Axis
			_testa.use_secondary_rotation = true
			_testa.use_angle_limitation = true
			_testa.symmetry_limitation = true
			_testa.primary_limit_angle = deg_to_rad(angolo_testa * 2.0)
			_testa.secondary_limit_angle = deg_to_rad(angolo_testa * 2.0)
			_testa.duration = 0.4
			_testa.influence = 0.0
			_testa.active = false
			sk.add_child(_testa)
			sk.move_child(_testa, _occhio.get_index())
			_testa.target_node = _testa.get_path_to(_bersaglio)
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
	for p in (punti_gocce if gocce else PackedVector3Array()):
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


## L'asse dell'osso (0 x, 1 y, 2 z) più allineato a [param dir], e il verso (+1 o -1).
static func _asse(b: Basis, dir: Vector3) -> Vector2i:
	var migliore := Vector2i(0, 1)
	var massimo := -1.0
	for i in 3:
		var d := b[i].normalized().dot(dir)
		if absf(d) > massimo:
			massimo = absf(d)
			migliore = Vector2i(i, 1 if d > 0.0 else -1)
	return migliore


## La testa segue il giocatore (con l'animazione "inseguimento/incombe"): [param quanto] da 0 (la testa
## dell'animazione) a 1, in [param secondi].
func segui_con_la_testa(quanto := 1.0, secondi := 0.4) -> void:
	if _testa == null:
		return
	if _tw_testa:
		_tw_testa.kill()
	_testa.active = true
	_tw_testa = create_tween()
	_tw_testa.tween_property(_testa, "influence", clampf(quanto, 0.0, 1.0), maxf(secondi, 0.01))
	if quanto <= 0.0:
		_tw_testa.tween_callback(func(): _testa.active = false)


## Nella vasca la palpebra è bagnata come la pelle (se material_map non sceglie un altro "M_palpebre").
func _materiale_palpebre() -> Material:
	if ResourceLoader.exists(MATERIALE_PALPEBRE_BAGNATA):
		return load(MATERIALE_PALPEBRE_BAGNATA) as Material
	return super._materiale_palpebre()


## Dove sta l'occhio adesso (coordinate del mondo, con lo sguardo applicato).
## I tentacoli non si piegano contro questa collisione (per esempio un coperchio invisibile).
func escludi_dai_tentacoli(rid: RID) -> void:
	if not _esclusi_tentacoli.has(rid):
		_esclusi_tentacoli.append(rid)


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
