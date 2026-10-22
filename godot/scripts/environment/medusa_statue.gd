@tool
class_name MedusaStatue
extends Node3D
## La medusa ferma come una statua sul piedistallo (scena S1, "il benvenuto").
## Carica il GLB della medusa (la posa di riposo è già la statua, con le mani giunte, in piedi
## sui tentacoli), mette lo shader "a gelatina" sulla campana, il materiale traslucido sui
## tentacoli, la pelle in vinile satinato e le ciocche lucide, e tiene i canali appena accesi. Con pulse() i canali pulsano a tempo per un attimo
## (quando parte la sigla); con wake_up() si stacca dal piedistallo (animazione "sveglia"); con chiudi_occhio() la
## palpebra scende sull'occhio e dopo un po' lo riapre (l'easter egg del getto d'acqua in faccia).
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
@export_group("Occhio")
## Quanto ci mette la palpebra a chiudere l'occhio (s).
@export var durata_chiusura := 0.25
## Quanto ci mette a riaprirlo (s).
@export var durata_riapertura := 0.5

## Le mesh dentro la bocca: si vedono solo quando la fauce si apre.
const BOCCA := ["Medusa_Gola", "Medusa_Denti", "Medusa_Strappo"]
## Lo spessore della pelle strappata intorno alla fauce: colori dei vertici con la tinta della pelle.
const STRAPPO := "Medusa_Strappo"
## La palpebra (easter egg dell'occhio che si chiude): le blend shape palpebre_1 ... palpebre_N sono le tappe della
## chiusura, da usare in sequenza (LEGGIMI della medusa). A occhio aperto non si vede.
const PALPEBRE := "Medusa_Palpebre"
## Materiale della palpebra: la pelle senza texture (colore della pelle intorno all'occhio, già con la tinta).
const MATERIALE_PALPEBRE := "res://assets/models/medusa/medusa_palpebre.tres"

var _instance: Node3D
var _bell: ShaderMaterial
var _pulse_left := 0.0
var _pulse_total := 1.0
var _t := 0.0
var _palpebre: MeshInstance3D
var _tappe := PackedInt32Array()
var _chiusura := 0.0
var _tw_occhio: Tween
var _dritto: OcchioDritto
var _tw_dritto: Tween


## Tiene dritto l'osso dell'occhio (la sua posa di riposo nella testa) mentre la palpebra è chiusa: con
## influence 1 vince sulla posa dell'animazione e sullo sguardo che segue il giocatore, che girerebbero la
## cornea contro la palpebra.
class OcchioDritto extends SkeletonModifier3D:
	var osso := -1

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk and osso >= 0:
			sk.set_bone_pose_rotation(osso, sk.get_bone_rest(osso).basis.get_rotation_quaternion())


func _ready() -> void:
	_rebuild()


## I canali della campana pulsano a tempo per [param seconds] secondi.
func pulse(seconds := 6.0) -> void:
	_pulse_left = seconds
	_pulse_total = maxf(seconds, 0.01)


func get_model_instance() -> Node3D:
	return _instance


## L'easter egg dell'occhio: la palpebra scende dall'alto e chiude l'occhio in [member durata_chiusura] secondi,
## lo tiene chiuso per [param secondi] e lo riapre da sola in [member durata_riapertura] secondi. Mentre è chiuso
## l'occhio torna dritto (osso "occhio" nella posa di riposo). Chiamata di nuovo mentre è chiuso (o si chiude),
## riparte da dov'è e il tempo ricomincia.
func chiudi_occhio(secondi := 5.0) -> void:
	if _palpebre == null or _tappe.is_empty():
		return
	if _tw_occhio and _tw_occhio.is_valid():
		_tw_occhio.kill()
	_occhio_dritto(1.0, 0.08)
	_tw_occhio = create_tween()
	_tw_occhio.tween_method(_imposta_chiusura, _chiusura, 1.0, durata_chiusura * (1.0 - _chiusura))
	_tw_occhio.tween_interval(maxf(secondi, 0.0))
	_tw_occhio.tween_method(_imposta_chiusura, 1.0, 0.0, durata_riapertura) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw_occhio.tween_callback(_occhio_dritto.bind(0.0, 0.3))


## Vero mentre la palpebra copre (anche solo in parte) l'occhio.
func occhio_chiuso() -> bool:
	return _chiusura > 0.0


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
## Con [param animazione] un'altra animazione al posto di "fauce_apre" (per esempio "inseguimento/presa", che
## apre già la fauce), o vuota per lasciare quella che c'è e fare solo le vene.
func attacca(durata_vene := 0.7, animazione := &"fauce_apre") -> void:
	if _instance == null:
		return
	_mostra_bocca(true)
	var ap := _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and animazione != &"" and ap.has_animation(animazione):
		ap.play(animazione, 0.25)
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
	_prepara_palpebre()
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


## La palpebra: le sue blend shape (le tappe, in ordine) e, se i materiali per nome non dicono altro, il materiale
## di pelle senza texture (_materiale_palpebre). A occhio aperto le blend shape sono a 0: non si vede.
func _prepara_palpebre() -> void:
	for tw in [_tw_occhio, _tw_dritto]:
		if tw and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_palpebre = _instance.find_child(PALPEBRE, true, false) as MeshInstance3D
	_tappe = PackedInt32Array()
	_chiusura = 0.0
	_dritto = null
	if _palpebre == null or _palpebre.mesh == null:
		_palpebre = null
		return
	var i := 1
	while true:
		var idx := _palpebre.find_blend_shape_by_name(StringName("palpebre_%d" % i))
		if idx < 0:
			break
		_tappe.append(idx)
		i += 1
	if _palpebre.get_surface_override_material(0) == null:
		var m := _materiale_palpebre()
		if m:
			_palpebre.set_surface_override_material(0, m)
	# a riposo la geometria e' raccolta in una riga: i LOD calcolati su quella forma non valgono per la palpebra
	# chiusa, quindi resta al dettaglio pieno (e' piccola)
	_palpebre.lod_bias = 100.0


## Il materiale della palpebra quando nessun override lo sceglie (la statua: pelle asciutta).
func _materiale_palpebre() -> Material:
	return load(MATERIALE_PALPEBRE) as Material if ResourceLoader.exists(MATERIALE_PALPEBRE) else null


## Mette le blend shape della palpebra alla chiusura [param c] (0 aperto, 1 chiuso): al massimo due tappe vicine
## accese, (1 - x) e x, come medusa_palpebre.imposta_chiusura in Blender (così il bordo non passa nella cornea).
func _imposta_chiusura(c: float) -> void:
	_chiusura = clampf(c, 0.0, 1.0)
	if _palpebre == null:
		return
	var n := _tappe.size()
	var x := _chiusura * n
	var s := mini(floori(x), n)
	var fr := x - s
	for k in n:
		var w := 0.0
		if s >= n:
			w = 1.0 if k == n - 1 else 0.0
		elif k == s - 1:
			w = 1.0 - fr
		elif k == s:
			w = fr
		_palpebre.set_blend_shape_value(_tappe[k], w)


## L'occhio dritto (v = 1) o libero di seguire l'animazione e lo sguardo (v = 0), in [param t] secondi.
func _occhio_dritto(v: float, t: float) -> void:
	if _instance == null:
		return
	if _dritto == null or not is_instance_valid(_dritto):
		var sks := _instance.find_children("*", "Skeleton3D", true, false)
		var sk := sks[0] as Skeleton3D if sks.size() > 0 else null
		if sk == null or sk.find_bone("occhio") < 0:
			return
		_dritto = OcchioDritto.new()
		_dritto.name = "OcchioDritto"
		_dritto.osso = sk.find_bone("occhio")
		_dritto.influence = 0.0
		sk.add_child(_dritto)          # dopo lo sguardo (LookAtModifier3D): vince lui
	if _tw_dritto and _tw_dritto.is_valid():
		_tw_dritto.kill()
	_tw_dritto = create_tween()
	_tw_dritto.tween_property(_dritto, "influence", v, t)


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
