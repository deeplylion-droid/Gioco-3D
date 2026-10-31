class_name PortaStagna
extends Node3D
## La porta stagna d'uscita della stanza delle pozze (GDD, "La stanza delle pozze colorate", scelte dell'utente del 31
## ottobre): un battente d'acciaio col volantino e le chiusure, in un telaio dal bordo arrotondato, e sopra una lampada a
## gabbia rossa finché è chiusa, verde quando si apre. Si apre con [method apri], che chiama la logica dell'enigma
## (EnigmaPozze, di enigmi) a enigma risolto, e con subito vero quando si riparte da un checkpoint o dal Continua dove è
## già risolto: lo stato lo salva l'enigma.
## Coordinate: l'origine è al centro del vano, sul pavimento, nel piano della faccia del muro dalla parte della stanza;
## la stanza è verso +Z, il battente si apre verso -Z (fuori, sul pianerottolo della scala), sul cardine a -X.

## Larghezza e altezza del vano; spessore del muro (il telaio lo riveste tutto).
const LARGO := 0.9
const ALTO := 2.0
const MURO := 0.2
## Secondi per aprirsi (il suono della porta del ponte dura 3,4 s) e gradi d'apertura.
const DURATA := 2.6
const APERTURA := 100.0

## Emesso quando comincia ad aprirsi (anche con subito).
signal aperta

var e_aperta := false
var _cardine: Node3D
var _battente: AnimatableBody3D
var _luce: OmniLight3D
var _vetro: MeshInstance3D
var _t := -1.0
var _mat_rosso: StandardMaterial3D
var _mat_verde: StandardMaterial3D


func _ready() -> void:
	_costruisci()


## Apre la porta: col movimento e il suono, o con [param subito] già aperta (checkpoint, Continua).
func apri(subito := false) -> void:
	if e_aperta:
		if subito:
			_t = -1.0
			_cardine.rotation.y = deg_to_rad(APERTURA)
		return
	e_aperta = true
	_vetro.material_override = _mat_verde
	_luce.light_color = Color(0.25, 1.0, 0.35)
	aperta.emit()
	if subito:
		_cardine.rotation.y = deg_to_rad(APERTURA)
		return
	_t = 0.0
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		audio.call(&"suona", &"porta_ponte_apre", _battente)


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t = minf(_t + delta / DURATA, 1.0)
	# parte piano (le chiusure si sbloccano), poi gira e si ferma piano
	_cardine.rotation.y = deg_to_rad(APERTURA) * smoothstep(0.0, 1.0, _t)
	if _t >= 1.0:
		_t = -1.0


func _acciaio(c: Color, ruvido := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.7
	m.roughness = ruvido
	return m


func _box(padre: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	padre.add_child(mi)
	return mi


func _costruisci() -> void:
	var grigio := _acciaio(Color(0.34, 0.38, 0.4))
	var scuro := _acciaio(Color(0.17, 0.19, 0.2), 0.55)
	var rosso := _acciaio(Color(0.55, 0.07, 0.05), 0.5)
	# il telaio: riveste lo spessore del muro e sporge di 8 cm sulle due facce, con la battuta
	var telaio := Node3D.new()
	telaio.name = "Telaio"
	add_child(telaio)
	var fascia := 0.12
	var prof := MURO + 0.16
	var zc := -MURO * 0.5
	for s in [-1.0, 1.0]:
		_box(telaio, Vector3(fascia, ALTO + fascia, prof), Vector3(s * (LARGO + fascia) * 0.5, (ALTO + fascia) * 0.5, zc), grigio)
	_box(telaio, Vector3(LARGO + 2.0 * fascia, fascia, prof), Vector3(0, ALTO + fascia * 0.5, zc), grigio)
	# la soglia rialzata di 6 cm, come sulle navi (si passa camminando)
	_box(telaio, Vector3(LARGO, 0.06, prof), Vector3(0, 0.03, zc), grigio)
	# il battente: sul cardine a -X, sulla faccia di fuori del muro (z -MURO), chiuso fra gli stipiti
	_cardine = Node3D.new()
	_cardine.name = "Cardine"
	_cardine.position = Vector3(-LARGO * 0.5, 0, -MURO - 0.08)
	add_child(_cardine)
	_battente = AnimatableBody3D.new()
	_battente.name = "Battente"
	_battente.sync_to_physics = false
	_cardine.add_child(_battente)
	var lb := LARGO + 0.1
	var ab := ALTO + 0.06
	var sp := 0.07
	_box(_battente, Vector3(lb, ab, sp), Vector3(lb * 0.5 - 0.05, ab * 0.5 + 0.02, -sp * 0.5), scuro)
	var f := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(lb, ab, sp)
	f.shape = bs
	f.position = Vector3(lb * 0.5 - 0.05, ab * 0.5 + 0.02, -sp * 0.5)
	_battente.add_child(f)
	# le cerniere, le sei chiusure a leva sul bordo e il volantino al centro, dalla parte della stanza e di fuori
	for y in [0.35, ALTO - 0.35]:
		_box(_battente, Vector3(0.06, 0.18, 0.1), Vector3(-0.05, y, -sp * 0.5), grigio)
	for faccia: float in [1.0, -1.0]:
		var zf := (0.0 if faccia > 0.0 else -sp) + faccia * 0.015
		for y in [0.3, ALTO * 0.5, ALTO - 0.3]:
			_box(_battente, Vector3(0.14, 0.04, 0.03), Vector3(lb - 0.16, y, zf), grigio)
		var v := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.15
		t.outer_radius = 0.18
		t.rings = 24
		t.ring_segments = 8
		v.mesh = t
		v.material_override = rosso
		v.rotation_degrees.x = 90.0
		v.position = Vector3(lb * 0.5 - 0.05, ALTO * 0.55, zf + faccia * 0.03)
		_battente.add_child(v)
		for a: float in [0.0, 60.0, 120.0]:
			var r := _box(_battente, Vector3(0.33, 0.02, 0.02), v.position, rosso)
			r.rotation_degrees.z = a
		_box(_battente, Vector3(0.05, 0.05, 0.06), v.position - Vector3(0, 0, faccia * 0.02), grigio)
	# la lampada a gabbia sopra il vano, dalla parte della stanza: rossa finché è chiusa, verde aperta
	_mat_rosso = StandardMaterial3D.new()
	_mat_rosso.albedo_color = Color(0.9, 0.12, 0.08)
	_mat_rosso.emission_enabled = true
	_mat_rosso.emission = Color(1.0, 0.12, 0.06)
	_mat_rosso.emission_energy_multiplier = 3.0
	_mat_verde = _mat_rosso.duplicate() as StandardMaterial3D
	_mat_verde.albedo_color = Color(0.15, 0.85, 0.25)
	_mat_verde.emission = Color(0.2, 1.0, 0.3)
	var lampada := Node3D.new()
	lampada.name = "Lampada"
	lampada.position = Vector3(0, ALTO + fascia + 0.16, 0.0)
	add_child(lampada)
	_box(lampada, Vector3(0.16, 0.1, 0.05), Vector3(0, 0, 0.025), grigio)
	_vetro = MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.06
	sf.height = 0.12
	_vetro.mesh = sf
	_vetro.material_override = _mat_rosso
	_vetro.position = Vector3(0, 0, 0.11)
	lampada.add_child(_vetro)
	var gabbia := CylinderMesh.new()
	gabbia.top_radius = 0.075
	gabbia.bottom_radius = 0.075
	gabbia.height = 0.01
	for k in 3:
		var g := MeshInstance3D.new()
		g.mesh = gabbia
		g.material_override = grigio
		g.rotation_degrees.x = 90.0
		g.position = Vector3(0, 0, 0.06 + k * 0.04)
		lampada.add_child(g)
	_luce = OmniLight3D.new()
	_luce.name = "Luce"
	_luce.light_color = Color(1.0, 0.15, 0.1)
	_luce.light_energy = 0.8
	_luce.omni_range = 3.0
	_luce.position = Vector3(0, 0, 0.3)
	_luce.set_meta(&"risveglio_ignora", true)
	lampada.add_child(_luce)
